#!/bin/bash

if [ $# -ne 8 ];then
        echo "Usage: ./runLocustClickhouse.sh sqls_home private_namenode_ip iteration result_dir private_driver_host locust_home spark_home emr_namenode_user"
        exit 1
fi

sqls_home=$1
private_namenode_ip=$2
iteration=$3
result_dir=$4
private_driver_host=$5
locust_home=$6
spark_home=$7

#call locust script,tbd
echo "$(date '+%F %T'): call call locust script"
# clickhouse query
echo "$(date '+%F %T'): Clickhouse make query test"
python3 ${locust_home}/statistic.py --iterations ${iteration} --sql-path ${sqls_home} --dialect clickhouse --engine clickhouse --output-dir ${result_dir} \
        -p 9000 --host ${private_driver_host} --user default --database tpch100_dist \
        --data-format mergetree --drop-table-before-create False

