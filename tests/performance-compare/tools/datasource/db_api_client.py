import os
import sys
import time
from abc import abstractmethod, ABCMeta

from common import config
from datasource import statement

log = config.log


def init_stmt(dialect):
    stmts = {}

    if dialect == "":
        return stmts

    root_path = os.path.join(config.SQL_PATH, dialect)
    if not os.path.exists(root_path):
        return stmts

    for file_name in os.listdir(root_path):
        full_path = os.path.join(root_path, file_name)
        if os.path.isfile(full_path) and file_name.endswith(".sql"):
            with open(full_path, "r") as file:
                stmts[file_name[:-len(".sql")]] = file.read()

    return stmts


class DBApiClient(metaclass=ABCMeta):
    def __init__(self, environment):
        self.stmt = None
        self.stmt_sort_by_name = []
        self.env = environment
        self.create_table_sql = statement.Tpch().create_table_sql(self)
        try:
            self.connection = self.create_connection()
            self.create_table()
        except Exception as e:
            log.error(e)
            sys.exit(-1)
        self.setup_statement()

    def setup_statement(self):
        if not config.ONLY_CREATE_TABLE:
            self.stmt = init_stmt(config.DEFAULT_DIALECT)
            if config.DEFAULT_DIALECT != config.DIALECT:
                other = init_stmt(config.DIALECT)
                for k in other:
                    if k in self.stmt:
                        if other[k].startswith("skip"):
                            self.stmt.pop(k, "")
                        else:
                            self.stmt[k] = other[k]
            self.stmt_sort_by_name = list(self.stmt.keys())
            self.stmt_sort_by_name.sort()

    @abstractmethod
    def create_connection(self):
        pass

    def query(self):
        for name in self.stmt_sort_by_name:
            self.locust_statistic(name, self.stmt[name])

    def locust_statistic(self, name, stmt):
        request_meta = {
            "request_type": "python",
            "name": name,
            "start_time": time.time(),
            "response_length": 0,
            "exception": None,
            "context": None,
            "response": None,
        }
        log.info("Running statement {}".format(name))
        start_perf_counter = time.perf_counter()
        try:
            request_meta["response"] = self.execute(stmt)
            request_meta["response_length"] = len(request_meta["response"])
        except Exception as e:
            log.error(e)
            request_meta["exception"] = e
        request_meta["response_time"] = int((time.perf_counter() - start_perf_counter) * 1000 * 1000)  # ns
        self.env.events.request.fire(**request_meta)
        return request_meta["response"]

    def execute(self, stmt):
        cursor = self.connection.cursor()
        cursor.execute(stmt)
        cursor.close()
        return "success"

    def create_table(self):
        for create_sql in self.create_table_sql:
            try:
                self.execute(create_sql)
            except Exception as e:
                log.error(e)

    def trans_column_type(self, origin_type):
        return origin_type.name

    def trans_column_nullable(self, nullable):
        if nullable:
            return " NOT "
        else:
            return " NOT NULL "

    def trans_column_default_value(self, default_value):
        if default_value == "":
            return ""
        else:
            return " default {} ".format(default_value)

    def random_column(self):
        return ""

    def engine_sql(self):
        return ""

    # @abstractmethod
    def order_by_sql(self, order_by_column):
        return ""

    def shard_by_sql(self, shard_by_column):
        return ""

    def location_sql(self, location_uri):
        return ""

    def other_sql(self, table):
        return ""

    def pre_create_table(self):
        return []
