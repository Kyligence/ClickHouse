







### 创建hive表
```shell
python statistic.py \
--engine hive \
-p 10000 \
--host 192.168.198.97 \
--user root \
--database information_schema \
--external-path \
hdfs://emr-header-1.cluster-49146:9000/user/hive/warehouse/tpch_hive_orc.db/lineitem \
--metastore-uris thrift://10.10.44.98:9083 \
--create-table-only True
```

### 运行gluten sql
包含创建表
```shell
python statistic.py \
--iterations 10
--sql-path /home/admin123/Documents/work/code/Clickhouse-Dev/tests/performance-compare/sqls \
--dialect hive \
--engine gluten \
--output-dir /home/admin123/Documents/work/code/Clickhouse-Dev/tests/performance-compare \
-p 10000 \
--host 192.168.198.97 \
--user root \
--database information_schema \
--external-path hdfs://emr-header-1.cluster-49146:9000/user/hive/warehouse/tpch_hive_orc.db/lineitem  \
--metastore-uris thrift://10.10.44.98:9083

```


### 运行starrocks sql
包含创建表
```shell
python statistic.py \
--iterations 10
--sql-path /home/admin123/Documents/work/code/Clickhouse-Dev/tests/performance-compare/sqls \
--dialect starrocks \
--engine starrocks \
--output-dir /home/admin123/Documents/work/code/Clickhouse-Dev/tests/performance-compare \
-p 10000 \
--host 192.168.198.97 \
--user root \
--database information_schema \
--external-path hdfs://emr-header-1.cluster-49146:9000/user/hive/warehouse/tpch_hive_orc.db/lineitem  \
--metastore-uris thrift://10.10.44.98:9083

```
