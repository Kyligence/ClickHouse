from pyhive import hive

from common import config
from datasource import db_api_client

ENGINE = "hive"


class HiveDBApiClient(db_api_client.DBApiClient):
    def __init__(self, environment):
        super().__init__(environment)

    def create_connection(self):
        if config.CONNECTION_PASSWORD == "":
            return hive.Connection(database=config.CONNECTION_DATABASE, username=config.CONNECTION_USER,
                                   host=config.CONNECTION_HOST,
                                   port=config.CONNECTION_PORT)
        else:
            return hive.Connection(database=config.CONNECTION_DATABASE, username=config.CONNECTION_USER,
                                   password=config.CONNECTION_PASSWORD,
                                   host=config.CONNECTION_HOST,
                                   port=config.CONNECTION_PORT)

    def location_sql(self, location_uri):
        if location_uri == "":
            return ""

        return """
          STORED AS PARQUET
          LOCATION
              '{}'
          """.format(location_uri)

    def trans_column_nullable(self, nullable):
        return ""
