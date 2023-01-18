#!/bin/bash


if [ $# -ne 3 ];then
        echo "Usage: ./setupVanillaSparkOptimized.sh key_file spark_master_ip worker_ips"
        exit 1
fi

echo "$(date '+%F %T'): setup VanillaSpark service"

key_file=$1
spark_master_ip=$2

#spark version is a variable
ansible --key-file ${key_file} tcluster -m shell -a "mkdir -p ${spark_base}"

#setup spark node
echo "$(date '+%F %T'): setup spark node environment"
if [ ! -d "${spark_home}" ];then 
	echo "$(date '+%F %T'): Spark not found,start downloading" 
	cd ${spark_base}
	ls -hl ~/${spark_subdir}.tgz
	if [ $? -ne 0 ];then
		wget ${spark_bin_url}
	else
		cp ~/${spark_subdir}.tgz ./
	fi
	#dispatch to all nodes
	ansible --key-file ${key_file} workers -m copy -a "src=${spark_subdir}.tgz dest=${spark_base}"
	ansible --key-file ${key_file} tcluster -m shell -a "cd ${spark_base};rm -rf ${spark_home};tar -xzvf ${spark_subdir}.tgz"
	# ansible --key-file ${key_file} tcluster -m shell -a "cd ${spark_home}/jars;rm -f protobuf-java-2.5.0.jar;wget https://repo1.maven.org/maven2/com/google/protobuf/protobuf-java/3.13.0/protobuf-java-3.13.0.jar;wget https://repo1.maven.org/maven2/io/delta/delta-core_2.12/1.2.1/delta-core_2.12-1.2.1.jar;wget https://repo1.maven.org/maven2/io/delta/delta-storage/1.2.1/delta-storage-1.2.1.jar"
	
fi

# ansible --key-file ${key_file} tcluster -m shell -a "rm -f ${spark_home}/jars/gluten*.jar"
# ansible --key-file ${key_file} tcluster -m copy -a "src=${gluten_standard_jar} dest=${spark_home}/jars/"
# ansible --key-file ${key_file} workers  -m copy -a "src=${libch_standard_so} dest=${libch_standard_so}"


#start master
echo "$(date '+%F %T'): start master"
cd ${spark_home}
./sbin/start-master.sh -h ${spark_master_ip}

#start workers
echo "$(date '+%F %T'): start workers"
ansible --key-file ${key_file} workers -m shell -a "cd ${spark_home};./sbin/start-worker.sh spark://${spark_master_ip}:7077"

spark_event_logs="${spark_home}/spark_event_logs"
ansible --key-file ${key_file} tcluster -m shell -a "mkdir -p ${spark_event_logs}"
echo "$(date '+%F %T'): start thrift server"
#start thrift server
./sbin/start-thriftserver.sh \
  --master spark://${spark_master_ip}:7077 --deploy-mode client \
  --driver-memory 8g --driver-cores 3 \
  --total-executor-cores 45 --executor-memory 30g --executor-cores 15 \
  --conf spark.driver.memoryOverhead=4G \
  --conf spark.serializer=org.apache.spark.serializer.JavaSerializer \
  --conf spark.default.parallelism=45 \
  --conf spark.sql.shuffle.partitions=90 \
  --conf spark.sql.planMerge.ignorePushedDataFilters=true \
  --conf spark.sql.optimizer.partialAggregationOptimization.enabled=true \
  --conf spark.sql.aggregate.adaptivePartialAggregationThreshold=60000 \
  --conf spark.sql.optimizer.runtime.bloomFilter.applicationSideScanSizeThreshold=0 \
  --conf spark.sql.autoBroadcastJoinThreshold=-1


#start spark history server
export SPARK_HISTORY_OPTS=" -Dspark.history.ui.port=12222 -Dspark.history.fs.logDirectory=file://${spark_event_logs} -Dspark.history.retainedApplications=200 -Dspark.history.fs.update.interval=30s"
echo "$(date '+%F %T'): start history server"
./sbin/start-history-server.sh

#use beeline do a connection test
echo "$(date '+%F %T'): do a connect test"
sleep 10
./bin/beeline -u jdbc:hive2://${spark_master_ip}:10000/ -n root -e "create database if not exists tpch100_external;create database if not exists tpch1000_external;"
if [ $? -ne 0 ];then
	sleep 15
	./bin/beeline -u jdbc:hive2://${spark_master_ip}:10000/ -n root -e "create database if not exists tpch100_external;create database if not exists tpch1000_external;"
	if [ $? -ne 0 ];then
		echo "$(date '+%F %T'): Spark not launched!Have a check!"
		exit 102
	fi
fi


echo "$(date '+%F %T'): VanillaSpark service is on"
