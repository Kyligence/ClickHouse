#!/bin/bash

#this script run on namenode on which awscli is already configured
if [ $# -ne 7 ];then
        echo "Usage: ./prepareTestData.sh local_key_file namenode_ip emr_namenode_user local_aws_config_dir s3_data_source_home namenode_data_tmp data_type"
        exit 1
fi

local_key_file=$1
namenode_ip=$2
emr_namenode_user=$3
local_aws_config_dir=$4
s3_data_source_home=$5
namenode_data_tmp=$6
data_type=$7

#echo "$(date '+%F %T'): install awscli"
#sudo yum install -y aws-cli

echo "$(date '+%F %T'): upload awscli config file"
scp -i ${local_key_file} -r ${local_aws_config_dir} ${emr_namenode_user}@${namenode_ip}:~/


#down load data
echo "$(date '+%F %T'):down load data"
if [[ "${data_type[@]}" =~ "tpch100" ]] ; then
	echo "$(date '+%F %T'): download tpch100 parquet"
	ssh -i ${local_key_file} ${emr_namenode_user}@${namenode_ip} << EOF
	mkdir -p ${namenode_data_tmp}/tpch-data-sf100
	aws s3 cp --recursive ${s3_data_source_home}/tpch-data-sf100 ${namenode_data_tmp}/tpch-data-sf100
	echo "tpch100 upload to hdfs..."
	/usr/bin/hdfs dfs -put ${namenode_data_tmp}/tpch-data-sf100 /tmp/

	mkdir -p ${namenode_data_tmp}/tpch-data-sf100-null
	aws s3 cp --recursive ${s3_data_source_home}/tpch-data-sf100-null ${namenode_data_tmp}/tpch-data-sf100-null
	echo "tpch100-null upload to hdfs..."
	/usr/bin/hdfs dfs -put ${namenode_data_tmp}/tpch-data-sf100-null /tmp/

EOF
fi

if [[ "${data_type[@]}" =~ "tpch1000" ]] ; then
	echo "$(date '+%F %T'): download tpch1000 parquet"
	ssh -i ${local_key_file} ${emr_namenode_user}@${namenode_ip} << EOF
	mkdir -p ${namenode_data_tmp}/tpch-data-sf1000
	time aws s3 cp --recursive ${s3_data_source_home}/tpch-data-sf1000 ${namenode_data_tmp}/tpch-data-sf1000
	echo "upload data to hdfs"
	time /usr/bin/hdfs dfs -put ${namenode_data_tmp}/tpch-data-sf1000 /tmp/
EOF
fi

echo "$(date '+%F %T'): prepare data done"
