import logging
import sys

from common import config
from datasource import clickhouse
from datasource import gluten
from datasource import hive
from datasource import mysql
from datasource import starrocks
from datasource import doris

def get_client(environment):
    client = str.lower(config.ENGINE)
    if client == str.lower(clickhouse.ENGINE):
        return clickhouse.ClickhouseDBApiClient(environment)
    elif client == str.lower(hive.ENGINE):
        return hive.HiveDBApiClient(environment)
    elif client == str.lower(mysql.ENGINE):
        return mysql.MysqlDBApiClient(environment)
    elif client == str.lower(gluten.ENGINE):
        return gluten.GlutenDBApiClient(environment)
    elif client == str.lower(starrocks.ENGINE):
        return starrocks.StarrocksDBApiClient(environment)
    elif client == str.lower(doris.ENGINE):
        return doris.DorisDBApiClient(environment)
    else:
        logging.getLogger("Engine").error("Engine {} not support", client)
        sys.exit(10)
