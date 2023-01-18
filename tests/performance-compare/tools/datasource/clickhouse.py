import logging

from clickhouse_driver import dbapi

from datasource import db_api_client

from common import config

logger = logging.getLogger()

ENGINE = "clickhouse"


class ClickhouseDBApiClient(db_api_client.DBApiClient):

    def __init__(self, environment):
        super().__init__(environment)

    def create_connection(self):
        return dbapi.connect(database=config.CONNECTION_DATABASE, user=config.CONNECTION_USER,
                             password=config.CONNECTION_PASSWORD, host=config.CONNECTION_HOST,
                             port=config.CONNECTION_PORT)

    def engine_sql(self):
        return " ENGINE=MergeTree() "

    def order_by_sql(self, order_by_column):
        if order_by_column == "" and len(order_by_column) == 0:
            return " ORDER BY tuple() "

        return " ORDER BY ( " + ",".join(order_by_column) + ") "

    def trans_column_nullable(self, nullable):
        return ""
