#!/bin/bash


if [ $# -ne 2 ];then
        echo "Usage: ./compareResult.sh target_dir standard_dir"
        exit 1
fi

target_dir=$1
standard_dir=$2

#todo:check ch env

echo "$(date '+%F %T'): create a template table in ch if not exists"
clickhouse-client -mn --query="CREATE TABLE IF NOT EXISTS default.template (
    name String,
    avg_response_time Float64,
    median_response_time Float64,
    min_response_time Float64,
    max_response_time Float64
)
ENGINE = MergeTree
ORDER BY tuple()
SETTINGS index_granularity = 8192;"

echo "$(date '+%F %T'): create target table in ch"
clickhouse-client -mn --query="drop table if exists target;create table target as template;"
cd ${target_dir}
cat aggregated.csv | clickhouse-client --query="INSERT INTO target FORMAT CSV" --input_format_allow_errors_num 1

echo "$(date '+%F %T'): create standard table in ch"
clickhouse-client -mn --query="drop table if exists standard;create table standard as template;"
cd ${standard_dir}
cat aggregated.csv | clickhouse-client --query="INSERT INTO standard FORMAT CSV" --input_format_allow_errors_num 1

clickhouse-client -mn --query="
select a.name as query , a.min_response_time as targetTime, b.min_response_time as standardTime,
targetTime/standardTime as targetTime_to_standardTime_ratio
from target a join standard b on a.name=b.name order by a.name format PrettyCompact;
select sum(targetTime) as sumTargetTime, sum(standardTime) as sumstandardTime,
sumTargetTime/sumstandardTime as sumTargetTime_to_sumstandardTime_ratio from
(select a.name as query , a.min_response_time as targetTime, b.min_response_time as standardTime,
targetTime/standardTime as targetTime_to_standardTime_ratio
from target a join standard b on a.name=b.name order by a.name) c format PrettyCompact;"
