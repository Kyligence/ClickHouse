#!/bin/bash

if [ $# -ne 1 ];then
        echo "Usage: ./cleanStarrocks.sh key_file"
        exit 1
fi

key_file=$1

echo "$(date '+%F %T'): Starrocks clean work start!"
<< EOF
ansible --key-file ${key_file} driver -m shell -a "jps|awk '{print \$1}'|xargs kill -9"
ansible --key-file ${key_file} workers -m shell -a "jps|grep -i worker|awk '{print \$1}'|xargs kill -9"
ansible --key-file ${key_file} driver -m shell -a "ps -ef|grep test.py|grep -v grep|awk '{print \$2}'|xargs kill -9"

ansible --key-file ${key_file} tcluster -m shell -a "ps -ef|grep java|grep -v grep"
sevice_exists=$?
ansible --key-file ${key_file} tcluster -m shell -a "ps -ef|grep test.py|grep -v grep"
locust_exists=$?

if [ ${sevice_exists} -ne 0 ] && [ ${locust_exists} -ne 0 ];then
	echo "$(date '+%F %T'): GlutenWithCHStandar clean work done!"
	exit 0
else
	echo "$(date '+%F %T'): GlutenWithCHStandard clean work not done!"
	exit 103
fi
EOF
