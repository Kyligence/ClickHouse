#!/bin/bash


ROOT_PATH=$(cd `dirname -- $0` && pwd -P)
echo workers:$3

key_file=$1
DRIVER_HOST=$2
WORKER_HOSTS=$3
echo $WORKER_HOSTS
OLD_IFS="$IFS"
IFS=","
WORKER_HOSTS_ARR=(${WORKER_HOSTS})
IFS="${OLD_IFS}"


# install fe
ansible-playbook --key-file ${key_file} fe-playbook.yml --extra-vars "install_dir=${STARROCKS_INSTALL_HOME} starrock_version=${STARROCKS_VERSION} JAVA_HOME=${JAVA_HOME}"

if [ $? -ne 0 ];then
	echo "$(date '+%F %T'): Starrocks fe install failed! Have a check!"
	exit 120
fi


ansible-playbook --key-file ${key_file} be-playbook.yml --skip-tags clean --extra-vars "install_dir=${STARROCKS_INSTALL_HOME} starrock_version=${STARROCKS_VERSION} JAVA_HOME=${JAVA_HOME}"

if [ $? -ne 0 ];then
        echo "$(date '+%F %T'): Starrocks be install failed! Have a check!"
        exit 121
fi


for worker in ${WORKER_HOSTS_ARR[@]}
do
	echo "Add starrocks be ${worker}"
	mysql -h ${DRIVER_HOST} -P9030 -uroot -e "ALTER SYSTEM ADD BACKEND \"${worker}:9050\";"
	if [ $? -ne 0 ];then
		echo "$(date '+%F %T'): Starrocks add be ${worker} failed! Have a check!"
		exit 122
	fi
done

sleep 10

alive_cnt=`mysql -h ${DRIVER_HOST} -P9030 -uroot -e "SHOW PROC '/backends'\G"|grep "Alive: true"|wc -l`

if [ ${#WORKER_HOSTS_ARR[*]} -ne $alive_cnt ];then
	echo "$(date '+%F %T'): Starrocks not alive all! Have a check!"
	exit 123
fi

echo "$(date '+%F %T'): Starrocks create databases"
mysql -h ${DRIVER_HOST} -P9030 -uroot -e "create database if not exists tpch100_sr_external;create database if not exists tpch100_sr_null_external;"
mysql -h ${DRIVER_HOST} -P9030 -uroot -e "create database if not exists tpch100_sr;create database if not exists tpch100_sr_null;"


# install broker
ansible-playbook --key-file ${key_file} broker-playbook.yml --extra-vars "install_dir=${STARROCKS_INSTALL_HOME} starrock_version=${STARROCKS_VERSION} JAVA_HOME=${JAVA_HOME}"
if [ $? -ne 0 ];then
        echo "$(date '+%F %T'): Starrocks broker install failed! Have a check!"
        exit 124
fi

for worker in ${WORKER_HOSTS_ARR[@]}
do
	echo "Add starrocks broker ${worker}"
	mysql -h ${DRIVER_HOST} -P9030 -uroot -e "ALTER SYSTEM ADD BROKER broker_gluten \"${worker}:8000\";"
	if [ $? -ne 0 ];then
		echo "$(date '+%F %T'): Starrocks add broker ${worker} failed! Have a check!"
		exit 125
	fi
  let brid++
done

sleep 10

alive_cnt=`mysql -h ${DRIVER_HOST} -P9030 -uroot -e "SHOW PROC '/brokers'\G"|grep "Alive: true"|wc -l`

if [ ${#WORKER_HOSTS_ARR[*]} -ne $alive_cnt ];then
	echo "$(date '+%F %T'): Starrocks broker not alive all! Have a check!"
	exit 126
fi

echo "$(date '+%F %T'): Starrocks is installed."

