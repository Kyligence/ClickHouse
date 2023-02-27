#!/bin/bash

if [ $# -ne 1 ];then
        echo "Usage: ./cleanStarrocks.sh key_file"
        exit 1
fi

key_file=$1
#<< EOF
echo "$(date '+%F %T'): Starrocks clean work start!"
ansible --key-file ${key_file} driver -m shell -a "mysql -h 127.0.0.1 -P9030 -uroot -e 'drop database if exists tpch100_sr_external FORCE;drop database if exists tpch100_sr_null_external FORCE;'"
ansible --key-file ${key_file} driver -m shell -a "${STARROCKS_INSTALL_HOME}/StarRocks-${STARROCKS_VERSION}/fe/bin/stop_fe.sh --daemon"
ansible --key-file ${key_file} workers -m shell -a "${STARROCKS_INSTALL_HOME}/StarRocks-${STARROCKS_VERSION}/be/bin/stop_be.sh --daemon"
ansible --key-file ${key_file} workers -m shell -a "${STARROCKS_INSTALL_HOME}/StarRocks-${STARROCKS_VERSION}/apache_hdfs_broker/bin/stop_broker.sh --daemon"
echo "$(date '+%F %T'): Starrocks clean work done!"
#EOF
