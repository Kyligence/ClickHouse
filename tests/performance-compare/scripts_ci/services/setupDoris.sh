#!/bin/bash


if [ $# -ne 3 ];then
        echo "Usage: ./setupDoris.sh key_file spark_master_ip worker_ips"
        exit 1
fi

key_file=$1
DRIVER_HOST=$2

WORKER_HOSTS=$3
echo $WORKER_HOSTS
OLD_IFS="$IFS"
IFS=","
WORKER_HOSTS_ARR=(${WORKER_HOSTS})
IFS="${OLD_IFS}"



echo "$(date '+%F %T'): setup doris fe"
if [ ! -d "${doris_fe_home}" ];then
  cd ${doris_home}
  tar -xJf apache-doris-fe-${doris_version}.tar.xz
fi
. /etc/profile
cd ${doris_fe_home}
./bin/stop_fe.sh
rm -rf ./doris-meta/*
./bin/start_fe.sh --daemon
sleep 20
mysql -h ${DRIVER_HOST} -P9030 -uroot -e "show frontends\G"
if [ $? -ne 0 ];then
	echo "$(date '+%F %T'): Doris fe setup failed! Have a check!"
	exit 150
fi

echo "$(date '+%F %T'): setup doris be"
if [ ! -d "${doris_be_home}" ];then
  cd ${doris_home}
  tar -xJf apache-doris-be-${doris_version}.tar.xz
fi
ls ${doris_be_home}/lib/java-udf*.jar
if [ $? -ne 0 ];then
	cd ${doris_home}
	tar -xJf apache-doris-java-udf-jar-with-dependencies-${doris_version}.tar.xz
	cp apache-doris-java-udf-jar-with-dependencies-${doris_version}/*.jar {doris_be_home}/lib/
fi

rm -rf ${doris_be_home}/storage/*

ansible --key-file ${key_file} tcluster -m shell -a "mkdir -p ${doris_be_home};cd ${doris_be_home};./bin/stop_be.sh"
ansible --key-file ${key_file} workers -m shell -a "rm -rf ${doris_be_home}/storage/*"
# ansible --key-file ${key_file} workers -m copy -a "src=${doris_be_home} dest=${doris_home}/"
ansible --key-file ${key_file} workers -m shell -a "cd ${doris_be_home};chmod u+x ./bin/*.sh"
ansible --key-file ${key_file} workers -m shell -a ". /etc/profile;sudo sysctl -w vm.max_map_count=2000000;cd ${doris_be_home};./bin/start_be.sh --daemon"
sleep 20

for worker in ${WORKER_HOSTS_ARR[@]}
do
	echo "Add doris be ${worker}"
	mysql -h ${DRIVER_HOST} -P9030 -uroot -e "ALTER SYSTEM ADD BACKEND \"${worker}:9050\";"
	if [ $? -ne 0 ];then
		echo "$(date '+%F %T'): Doris add be ${worker} failed! Have a check!"
		exit 152
	fi
done

sleep 10

alive_cnt=`mysql -h ${DRIVER_HOST} -P9030 -uroot -e "SHOW PROC '/backends'\G"|grep "Alive: true"|wc -l`

if [ ${#WORKER_HOSTS_ARR[*]} -ne $alive_cnt ];then
	echo "$(date '+%F %T'): Doris not alive all! Have a check!"
	exit 153
fi

echo "$(date '+%F %T'): Doris create databases"
mysql -h ${DRIVER_HOST} -P9030 -uroot -e "create database if not exists tpch100_doris_external;create database if not exists tpch1000_doris_external;"
mysql -h ${DRIVER_HOST} -P9030 -uroot -e "create database if not exists tpch100_doris;create database if not exists tpch1000_doris;"

mysql -h ${DRIVER_HOST} -P9030 -uroot -e "set global exec_mem_limit = 64G;"
mysql -h ${DRIVER_HOST} -P9030 -uroot -e 'ADMIN SET FRONTEND CONFIG ("max_bytes_per_broker_scanner" = "50368709120");'

# install broker
bash ${doris_fe_home}/apache_hdfs_broker/bin/start_broker.sh  --daemon
if [ $? -ne 0 ];then
        echo "$(date '+%F %T'): Doris broker install failed! Have a check!"
        exit 154
fi

echo "Add doris broker ${DRIVER_HOST}"
mysql -h ${DRIVER_HOST} -P9030 -uroot -e "ALTER SYSTEM ADD BROKER broker_gluten \"${DRIVER_HOST}:8000\";"
if [ $? -ne 0 ];then
	echo "$(date '+%F %T'): Doris add broker ${DRIVER_HOST} failed! Have a check!"
	exit 155
fi


sleep 10

alive_cnt=`mysql -h ${DRIVER_HOST} -P9030 -uroot -e "SHOW PROC '/brokers'\G"|grep "Alive: true"|wc -l`

if [ 1 -ne $alive_cnt ];then
	echo "$(date '+%F %T'): Doris broker not alive all! Have a check!"
	exit 156
fi

echo "$(date '+%F %T'): Doris is installed."

