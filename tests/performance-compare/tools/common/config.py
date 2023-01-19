import logging

LOG_FORMAT = "%(asctime)s - %(levelname)s - %(message)s"
DATE_FORMAT = "%m/%d/%Y %H:%M:%S %p"
logging.basicConfig(level=logging.DEBUG, format=LOG_FORMAT, datefmt=DATE_FORMAT)

log = logging.getLogger()

CONNECTION_HOST = ""
CONNECTION_PORT = 80
CONNECTION_USER = ""
CONNECTION_PASSWORD = ""
CONNECTION_DATABASE = ""

SQL_PATH = ""
DIALECT = ""
DEFAULT_DIALECT = "ansi"

ITERATIONS = 10
OUTPUT_FILE = ""

ENGINE = ""
EXTERNAL_PATH = ""
METASTORE_URIS = ""

DROP_TABLE_BEFORE_CREATE = False
ONLY_CREATE_TABLE = False

DATA_FORMAT = "parquet"
COLUMN_NULLABLE = False
