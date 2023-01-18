# from locust import HttpUser, task, run_single_user

import gevent
import locust_plugins
from configargparse import Namespace
from locust import User, task
from locust.env import Environment
from locust.stats import stats_printer, stats_history

from common import config
from common import csv
from datasource import factory

log = config.log


# from gevent import monkey
# monkey.patch_all(thread=False)

class ABUser(User):
    abstract = True

    def __init__(self, environment):
        super().__init__(environment)
        self.client = factory.get_client(environment)


# The real user class that will be instantiated and run by Locust
# This is the only thing that is actually specific to the service that we are testing.
class GlutenUser(ABUser):
    def __init__(self, environment):
        super().__init__(environment)
        self.client = factory.get_client(environment)
        self.client.create_connection()

    @task
    def query(self):
        if config.ONLY_CREATE_TABLE:
            log.info("Skip running queries")
        else:
            self.client.query()


# if launched directly, e.g. "python3 debugging.py", not "locust -f debugging.py"
def run():
    # setup Environment and Runner
    env = Environment(user_classes=[GlutenUser], events=locust_plugins.events,
                      parsed_options=Namespace(num_users=1, spawn_rate=1, iterations=config.ITERATIONS,
                                               stats_history_enabled=True,
                                               console_stats_interval=5, ips=None,
                                               tags=None, exclude_tags=None))
    # env.parsed_options["iterations"] = config.ITERATIONS
    runner = env.create_local_runner()
    # env.runner.target_user_classes_count =1
    # start a WebUI instance
    env.create_web_ui("127.0.0.1", 8098)

    # start a greenlet that periodically outputs the current stats
    gevent.spawn(stats_printer(env.stats))

    # start a greenlet that save current stats to history
    gevent.spawn(stats_history, env.runner)

    # start the test
    env.runner.start(1, spawn_rate=1)
    # in 60 seconds stop the runner
    # gevent.spawn_later(1, lambda: env.runner.quit())
    # wait for the greenlets
    env.runner.greenlet.join()

    if config.OUTPUT_FILE != "":
        csv.write_result(config.OUTPUT_FILE, env.stats.entries)

    # stop the web server for good measures
    env.web_ui.stop()
