import argparse
import sys

from common import config
from core import locust_test

parser = argparse.ArgumentParser(description='command line arguments')
parser.add_argument('--iterations', '-i', type=int,
                    help='Iteration limit , stops Locust after a certain number of task iterations', required=False,
                    default=1)
parser.add_argument('--output-dir', '-o', type=str, help='', required=True)
parser.add_argument('--engine', "-e", type=str, help='used connection engine, eg. mysql, clickhouse, hive, starrocks',
                    required=True)
parser.add_argument('--sql-path', type=str, help='sql full path which search sql dialect. eg. /temp', required=True)
parser.add_argument('--dialect', type=str,
                    help='dialect. Will find sql in {sql-path}/{dialect}/. Support starrocks, clickhouse, ansi',
                    default="ansi")
parser.add_argument('--host', type=str, help='host', required=False,
                    default="localhost")
parser.add_argument('--port', '-p', type=int, help='port', required=False,
                    default=80)
parser.add_argument('--user', '-u', type=str, help='user', required=False,
                    default="")
parser.add_argument('--password', type=str, help='password', required=False,
                    default="")
parser.add_argument('--database', "-d", type=str, help='database', required=False,
                    default="default")
parser.add_argument('--external-path', type=str, help='If not empty, it will query with external tables.',
                    required=False, default="")
parser.add_argument('--metastore-uris', type=str, help='', required=False)
parser.add_argument('--drop-table-before-create', type=str, help='drop table before create', required=False, default="false")
parser.add_argument('--create-table-only', type=str, help='Will not running queries', required=False, default="false")
parser.add_argument('--data-format', type=str, help='mergetree or parquet', required=False, default="parquet")
parser.add_argument('--column-nullable', type=str, help='allow column null', required=False, default="false")




if __name__ == "__main__":
    args = vars(parser.parse_args())
    sys.argv = [sys.argv[0]]
    config.ITERATIONS = args["iterations"]
    config.OUTPUT_FILE = args["output_dir"]
    config.SQL_PATH = args["sql_path"]
    config.CONNECTION_HOST = args["host"]
    config.CONNECTION_PORT = args["port"]
    config.CONNECTION_USER = args["user"]
    config.CONNECTION_PASSWORD = args["password"]
    config.CONNECTION_DATABASE = args["database"]
    config.ENGINE = args["engine"]
    config.DIALECT = args["dialect"]
    config.EXTERNAL_PATH = args["external_path"]
    config.METASTORE_URIS = args["metastore_uris"]
    config.DATA_FORMAT = args["data_format"]

    if args["create_table_only"].lower() == "true":
        config.ONLY_CREATE_TABLE = True
    else:
        config.ONLY_CREATE_TABLE = False

    if args["drop_table_before_create"].lower() == "true":
        config.DROP_TABLE_BEFORE_CREATE = True
    else:
        config.DROP_TABLE_BEFORE_CREATE = False

    if args["column_nullable"].lower() == "true":
        config.COLUMN_NULLABLE= True
    else:
        config.COLUMN_NULLABLE = False

    locust_test.run()
