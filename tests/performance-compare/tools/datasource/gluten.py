from common import config
from datasource import hive

ENGINE = "gluten"


class GlutenDBApiClient(hive.HiveDBApiClient):
    def engine_sql(self):
        if config.DATA_FORMAT == "parquet":
            return """USING PARQUET
            TBLPROPERTIES (engine='Parquet')"""

        return """USING clickhouse
            TBLPROPERTIES (engine='MergeTree')"""

    def location_sql(self, location_uri):
        return " LOCATION '{}'".format(location_uri)

    def trans_column_nullable(self, nullable):
        if nullable:
            return " "
        else:
            return " NOT NULL "
