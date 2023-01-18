#!/bin/bash

key_file=$1
echo "$(date '+%F %T'): Clickhouse setup begin"
#todo
ansible --key-file ${key_file} tcluster -m shell -a "sudo service clickhouse-server restart"
sleep 20

echo "$(date '+%F %T'): Clickhouse setup well!"
