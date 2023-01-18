#!/bin/bash

if [ $# -ne 8 ];then
        echo "Usage: ./runLocustGlutenWithCHStandard.sh sqls_home private_namenode_ip iteration result_dir private_driver_host locust_home spark_home emr_namenode_user"
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
if [ ${gluten_run_mode} -eq 1 ];then
  if [ ${column_nullable} == "False" ];then
    echo "$(date '+%F %T'): GlutenWithCHStandard create external table and make query test"
    python3 ${locust_home}/statistic.py --iterations ${iteration} --sql-path ${sqls_home} --dialect gluten --engine gluten --output-dir ${result_dir} \
        -p 10000 --host ${private_driver_host} --user root --database tpch100_external --external-path hdfs://${private_namenode_ip}:8020/tmp/tpch-data-sf100 \
        --data-format parquet --drop-table-before-create True --column-nullable False
  else
    echo "$(date '+%F %T'): GlutenWithCHStandard create external nullable table and make query test"
    python3 ${locust_home}/statistic.py --iterations ${iteration} --sql-path ${sqls_home} --dialect gluten --engine gluten --output-dir ${result_dir} \
        -p 10000 --host ${private_driver_host} --user root --database tpch100_null_external --external-path hdfs://${private_namenode_ip}:8020/tmp/tpch-data-sf100-null \
        --data-format parquet --drop-table-before-create True --column-nullable True
  fi
fi

if [ ${gluten_run_mode} -eq 2 ];then
  if [ ${column_nullable} == "False" ];then
    echo "$(date '+%F %T'): GlutenWithCHStandard create inner mergetree table"
    python3 ${locust_home}/statistic.py --iterations ${iteration} --sql-path ${sqls_home} --dialect gluten --engine gluten --output-dir ${result_dir}"_inner" \
        -p 10000 --host ${private_driver_host} --user root --database tpch100 --external-path ${data_home}/tpch100_ch_data/notnull \
        --data-format mergetree --create-table-only True --drop-table-before-create True --column-nullable False

    #sleep 10000
  echo "$(date '+%F %T'): GlutenWithCHStandard copy metadata to all workers"

  for table in $(ls -A ${data_home}/tpch100_ch_data/notnull)
  do
    echo "$(date '+%F %T'): copy metadata of table ${table}"
    ansible --key-file ${key_file} workers  -m copy -a "src=${data_home}/tpch100_ch_data/notnull/${table}/_metadata_log dest=${data_home}/tpch100_ch_data/notnull/${table}/"
  done
  # sleep 10000
  echo "$(date '+%F %T'): GlutenWithCHStandard make query test"
  python3 ${locust_home}/statistic.py --iterations ${iteration} --sql-path ${sqls_home} --dialect gluten --engine gluten --output-dir ${result_dir}"_inner" \
        -p 10000 --host ${private_driver_host} --user root --database tpch100 --external-path ${data_home}/tpch100_ch_data/notnull \
        --data-format mergetree --column-nullable False
  else
    echo "$(date '+%F %T'): GlutenWithCHStandard create inner mergertree table nullable and make query"
    python3 ${locust_home}/statistic.py --iterations ${iteration} --sql-path ${sqls_home} --dialect gluten --engine gluten --output-dir ${result_dir}"_inner" \
        -p 10000 --host ${private_driver_host} --user root --database tpch100_null --external-path ${data_home}/tpch100_ch_data/nullable \
        --data-format mergetree --drop-table-before-create False --column-nullable True
  fi
fi

if [ ${gluten_run_mode} -eq 3 ];then
    echo "$(date '+%F %T'): GlutenWithCHStandard create inner parquet table and make query test"
    python3 ${locust_home}/statistic.py --iterations ${iteration} --sql-path ${sqls_home} --dialect gluten --engine gluten --output-dir ${result_dir} \
        -p 10000 --host ${private_driver_host} --user root --database tpch100_parquet --external-path file:///${data_home}/tpch-data-sf100 \
        --data-format parquet --drop-table-before-create True --column-nullable False
fi


if [ ${gluten_run_mode} -eq 4 ];then
  echo "$(date '+%F %T'): GlutenWithCHStandard only create external parquet table not null,not query"
  python3 ${locust_home}/statistic.py --iterations ${iteration} --sql-path ${sqls_home} --dialect gluten --engine gluten --output-dir ${result_dir} \
        -p 10000 --host ${private_driver_host} --user root --database tpch100_external --external-path hdfs://${private_namenode_ip}:8020/tmp/tpch-data-sf100 \
        --data-format parquet --create-table-only True --drop-table-before-create True --column-nullable False
  echo "$(date '+%F %T'): GlutenWithCHStandard only create external parquet table nullable,not query"
  python3 ${locust_home}/statistic.py --iterations ${iteration} --sql-path ${sqls_home} --dialect gluten --engine gluten --output-dir ${result_dir} \
        -p 10000 --host ${private_driver_host} --user root --database tpch100_null_external --external-path hdfs://${private_namenode_ip}:8020/tmp/tpch-data-sf100-null \
        --data-format parquet --create-table-only True --drop-table-before-create True --column-nullable True

  echo "$(date '+%F %T'): GlutenWithCHStandard only create inner mergertree table not null,not query"
  python3 ${locust_home}/statistic.py --iterations ${iteration} --sql-path ${sqls_home} --dialect gluten --engine gluten --output-dir ${result_dir}"_inner" \
        -p 10000 --host ${private_driver_host} --user root --database tpch100 --external-path ${data_home}/tpch100_ch_data/notnull \
        --data-format mergetree --create-table-only True --drop-table-before-create True --column-nullable False
  echo "$(date '+%F %T'): GlutenWithCHStandard copy metadata to all workers"

  for table in $(ls -A ${data_home}/tpch100_ch_data/notnull)
  do
    echo "$(date '+%F %T'): copy metadata of table ${table}"
    ansible --key-file ${key_file} workers  -m copy -a "src=${data_home}/tpch100_ch_data/notnull/${table}/_metadata_log dest=${data_home}/tpch100_ch_data/notnull/${table}/"
  done

  echo "$(date '+%F %T'): GlutenWithCHStandard only create inner mergertree table nullable,not query"
  python3 ${locust_home}/statistic.py --iterations ${iteration} --sql-path ${sqls_home} --dialect gluten --engine gluten --output-dir ${result_dir}"_inner" \
        -p 10000 --host ${private_driver_host} --user root --database tpch100_null --external-path ${data_home}/tpch100_ch_data/nullable \
        --data-format mergetree --create-table-only True --drop-table-before-create False --column-nullable True

  echo "$(date '+%F %T'): GlutenWithCHStandard only create inner parquet table not null,not query"
  python3 ${locust_home}/statistic.py --iterations ${iteration} --sql-path ${sqls_home} --dialect gluten --engine gluten --output-dir ${result_dir} \
        -p 10000 --host ${private_driver_host} --user root --database tpch100_parquet --external-path file:///${data_home}/tpch-data-sf100 \
        --data-format parquet --create-table-only True --drop-table-before-create True --column-nullable False
fi

