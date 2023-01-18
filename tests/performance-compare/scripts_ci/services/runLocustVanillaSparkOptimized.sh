#!/bin/bash

if [ $# -ne 8 ];then
        echo "Usage: ./runLocustVanillaSparkOptimized.sh sqls_home private_namenode_ip iteration result_dir private_driver_host locust_home spark_home emr_user"
        exit 1
fi

#bash ./runLocustVanillaSparkOptimized.sh /home/ubuntu/glutenTest/sqls/query 172.31.17.38 1 /home/ubuntu/glutenTest/result/VanillaSpark_2022_11_16_16_13_24 172.31.23.71 /home/ubuntu/glutenTest/locust /home/ubuntu/glutenTest/spark/spark-3.2.2-bin-hadoop2.7 ec2-user


sqls_home=$1
private_namenode_ip=$2
iteration=$3
result_dir=$4
private_driver_host=$5
locust_home=$6
spark_home=$7

#call locust script,tbd
echo "$(date '+%F %T'): call call locust script"
# starrocks create table 2 and query
echo "$(date '+%F %T'): VanillaSpark create external table and make query test"
python3 ${locust_home}/statistic.py --iterations ${iteration} --sql-path ${sqls_home} --dialect gluten --engine gluten --output-dir ${result_dir} \
        -p 10000 --host ${private_driver_host} --user root --database tpch100_external --external-path hdfs://${private_namenode_ip}:8020/tmp/tpch-data-sf100 \
        --data-format parquet --drop-table-before-create True
