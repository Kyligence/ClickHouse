import logging

from common import config
from datasource import mysql

logger = logging.getLogger()

ENGINE = "doris"


class DorisDBApiClient(mysql.MysqlDBApiClient):

    def shard_by_sql(self, shard_cols):
        if config.EXTERNAL_PATH != "":
            return ""
        return "DISTRIBUTED BY HASH(" + ','.join(shard_cols) + ") BUCKETS 24"

    def other_sql(self, table):
        if config.EXTERNAL_PATH != "":
            return """
            properties (
            "hive.metastore.uris" = "{}",
            "table" = "{}",
            "database" = "{}"
            )
            """.format(config.METASTORE_URIS, table.name, config.CONNECTION_DATABASE)
        return """
        PROPERTIES(
        "replication_num" = "1",
        "in_memory" = "false",
        "storage_format" = "DEFAULT"
        )"""

    def random_column(self):
        return " random_key int default uuid(), "

    def engine_sql(self):
        if config.EXTERNAL_PATH != "":
            return "ENGINE=hive"
        return " ENGINE=OLAP "

    def trans_column_nullable(self, nullable):
        if nullable or config.EXTERNAL_PATH != "":
            return " NULL "
        else:
            return " NOT NULL "

    def pre_create_table(self):
        pre_sql = []
        return pre_sql
