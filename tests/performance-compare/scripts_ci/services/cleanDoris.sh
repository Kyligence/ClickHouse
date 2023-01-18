#!/bin/bash

if [ $# -ne 1 ];then
        echo "Usage: ./cleanDoris.sh key_file"
        exit 1
fi

key_file=$1
#<< EOF
echo "$(date '+%F %T'): Doris clean work start!"
ansible --key-file ${key_file} driver -m shell -a "mysql -h 127.0.0.1 -P9030 -uroot -e 'drop database if exists tpch100_doris_external FORCE;drop database if exists tpch1000_doris_external FORCE;'"
ansible --key-file ${key_file} driver -m shell -a "${doris_fe_home}/bin/stop_fe.sh --daemon"
ansible --key-file ${key_file} workers -m shell -a "${doris_be_home}/bin/stop_be.sh --daemon"
ansible --key-file ${key_file} driver -m shell -a "${doris_fe_home}/apache_hdfs_broker/bin/stop_broker.sh --daemon"
echo "$(date '+%F %T'): Doris clean work done!"
#EOF
