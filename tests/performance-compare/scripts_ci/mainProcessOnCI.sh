#!/bin/bash
#this script contains main process,running on ci vm
#basic environment/services preparation and locust perf test scripts are all called on cloud vms,not on local ci vm for permission casue(need run sudo to config ansible and run apt-get install)
echo "$(date '+%F %T'): begin perf test!"

#get config from conf file
echo "$(date '+%F %T'): source common variable, file mainProcessOnCI.conf"
main_script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${main_script_dir}/mainProcessOnCI.conf


driver_host=''
private_driver_host=''
private_worker_hosts='' #comma seperated string list

#start remote cloud vms,suppose CI VM has secret key to access cloud vms
echo "$(date '+%F %T'): start hdfs and cloud vms!"
if [ ${run_mode} = "aws" ];then
	echo "$(date '+%F %T'): test run on aws"

  if [ ${need_prepare_emr} -eq 1 ];then
	  bash ${main_script_dir}/startAWSEMR.sh ${local_key_file} ${emr_namenode_user} ${emr_start_waiting_time_s}
	  if [ $? -ne 0 ];then
          	echo "$(date '+%F %T'): start cloud hdfs failed!"
          	exit 1
	  fi
	  namenode_ip=$(cat /tmp/namenode_ip)


	  #get data from s3 and load to hdfs
	  echo "$(date '+%F %T'): download data from s3 on namenode and upload to hdfs"
	  echo "bash ${main_script_dir}/prepareTestData.sh ${local_key_file} ${namenode_ip} ${emr_namenode_user} ${local_aws_config_dir} ${s3_data_source_home} ${namenode_data_tmp} ${data_type}"
	  bash ${main_script_dir}/prepareTestData.sh ${local_key_file} ${namenode_ip} ${emr_namenode_user} ${local_aws_config_dir} ${s3_data_source_home} ${namenode_data_tmp} ${data_type}
	  echo "$(date '+%F %T'): prepare data ready"
  fi

  export namenode_ip=$(cat /tmp/namenode_ip)
  export private_namenode_ip=$(cat /tmp/private_namenode_ip)
  export private_datanode_ip=$(cat /tmp/private_datanode_ip)
  export emr_cluster_id=$(cat /tmp/emr_cluster_id)
  export private_all_emr_node_ip=$(cat /tmp/private_all_emr_node_ip) #comma seperated list


	bash ${main_script_dir}/startAWSVMs.sh
	#check status,to be done
	driver_host=$(bash ${main_script_dir}/getAWSVmIP.sh public driver)
	private_driver_host=$(bash ${main_script_dir}/getAWSVmIP.sh private driver)
	private_worker_hosts=$(bash ${main_script_dir}/getAWSVmIP.sh  private workers)
elif [ ${run_mode} = "gcp" ];then
	echo "$(date '+%F %T'): test run on gcp,to be done"
	exit 0
else
	echo "$(date '+%F %T'): not support test run mode ${run_mode}"
	exit 1
fi




echo "$(date '+%F %T'): driver_host:${driver_host} private_driver_host:${private_driver_host} private_worker_hosts:${private_worker_hosts}"



#put secret pem(key file) to driver host.First remove then upload,or there will be a "Permission denied" error
echo "$(date '+%F %T'): put secret pem(key file) to driver host.First remove then upload"
ssh -o StrictHostKeyChecking=no -i ${local_key_file} ${cloud_vm_user}@${driver_host} "ls -hl ${key_file}"
scp -i ${local_key_file} ${local_key_file} ${cloud_vm_user}@${driver_host}:${key_file}

#copy emr id file to driver host for timely cluster shutting down control
scp -i ${local_key_file}  /tmp/emr_cluster_id ${cloud_vm_user}@${driver_host}:/tmp/

#get all newly updated scripts into script_home
echo "$(date '+%F %T'): get all newly updated scripts into script_home"
ssh -i ${local_key_file} ${cloud_vm_user}@${driver_host} "rm -rf ${script_home};mkdir -p ${script_home}"
#copy scripts from ci local to remote driver vm
scp -i ${local_key_file} -r ${local_script_home}/* ${cloud_vm_user}@${driver_host}:${script_home}/
if [ $? -ne 0 ];then
	echo "$(date '+%F %T'): shell script upload to driver failed!"
	exit 1
fi
ssh -i ${local_key_file} ${cloud_vm_user}@${driver_host} "chmod u+x ${script_home}/*.sh"

echo "$(date '+%F %T'): get all newly updated locust scripts into locust_home"
ssh -i ${local_key_file} ${cloud_vm_user}@${driver_host} "rm -rf ${locust_home};mkdir -p ${locust_home}"
scp -i ${local_key_file} -r ${local_locust_home}/* ${cloud_vm_user}@${driver_host}:${locust_home}/
if [ $? -ne 0 ];then
        echo "$(date '+%F %T'): locust script upload to driver failed!"
        exit 1
fi

#copy sqls to driver
echo "$(date '+%F %T'): copy sqls to driver"
ssh -i ${local_key_file} ${cloud_vm_user}@${driver_host} "rm -rf ${sqls_home};mkdir -p ${sqls_home}"
scp -i ${local_key_file} -r ${local_sqls_home}/* ${cloud_vm_user}@${driver_host}:${sqls_home}/


#do setup basic env,all ops are on driver host
echo "$(date '+%F %T'): do setup basic env,all ops are on driver host"

#make an all ip list seperated by comma
private_all_ip=${private_driver_host}","${private_worker_hosts}","${private_all_emr_node_ip}


#need loop,because ssh may fail again!
loop=0
while true
do
	let loop++

	ssh -i ${local_key_file} ${cloud_vm_user}@${driver_host}  << EOF
	cd ${script_home}

	#check if need to setup mysql
	bash ./setupMysql.sh
  if [ \$? -ne 0 ];then
    exit 1
  fi

	#check if need to setup ansible and make a config
	echo "bash ./setupAnsible.sh ${key_file} ${private_driver_host} ${private_worker_hosts} ${private_all_emr_node_ip} ${cloud_vm_user} ${emr_namenode_user}"
	bash ./setupAnsible.sh ${key_file} ${private_driver_host} ${private_worker_hosts} ${private_all_emr_node_ip} ${cloud_vm_user} ${emr_namenode_user}
	if [ \$? -ne 0 ];then
		exit 1
	fi

	#check if need to setup java env
	bash ./setupJava.sh ${key_file}
	if [ \$? -ne 0 ];then
        	exit 1
	fi

	bash ./setupMonitor.sh ${key_file} ${cloud_vm_user} ${monitor_home_subfix} ${private_driver_host} ${private_worker_hosts} ${private_namenode_ip} ${private_datanode_ip}

	#check if need to setup s3client env,tbd

	#check if need to setup locust env
	sudo apt-get install -y python3-pip
	sudo apt-get install -y libsasl2-dev
	pip install -i https://pypi.tuna.tsinghua.edu.cn/simple -r ${locust_home}/requirements.txt

	#pull up conbench service 
EOF


	if [ $? -eq 0 ];then
		echo "$(date '+%F %T'): basic env setup done"
		break
	elif [ ${loop} -ge 5 ];then
		echo "$(date '+%F %T'): basic env setup wrong"
		exit 1
	else
	  continue
	fi
done



#service test loop start
echo "$(date '+%F %T'): service test loop start"

for sv in ${service[@]}
do
	echo "$(date '+%F %T'): service to test is ${sv}"
	source ${main_script_dir}/services/var${sv}.conf

	#copy gluten jar and libch.so to driver
	ls -hl ${main_script_dir}/services/uploadPackage${sv}.sh
	if [ $? -eq 0 ];then
	  bash ${main_script_dir}/services/uploadPackage${sv}.sh ${local_key_file} ${cloud_vm_user} ${driver_host}
	fi



  now_time=$(date "+%Y_%m_%d_%H_%M_%S")
	ssh -i ${local_key_file} ${cloud_vm_user}@${driver_host}  << EOF
	cd ${script_home}
	source var${sv}.conf
	bash ./clean${sv}.sh ${key_file}
	#check if need to setup spark and start service
	bash ./setup${sv}.sh ${key_file} ${private_driver_host} ${private_worker_hosts}

	if [ \$? -ne 0 ];then
		echo setup wrong
		cd ${script_home}
		bash ./clean${sv}.sh ${key_file}
    exit 1
	fi

	#read;sleep 10000

	#call locust script,tbd
	echo "$(date '+%F %T'): call locust script"
	cd ${script_home}
	mkdir -p ${result_home}/${sv}_${now_time}
	mkdir -p ${result_home}/${sv}_${now_time}_inner
	echo "bash ./runLocust${sv}.sh ${sqls_home} ${private_namenode_ip} ${iteration} ${result_home}/${sv}_${now_time} ${private_driver_host} ${locust_home} ${spark_home} ${emr_namenode_user}"
  bash ./runLocust${sv}.sh ${sqls_home} ${private_namenode_ip} ${iteration} ${result_home}/${sv}_${now_time} ${private_driver_host} ${locust_home} ${spark_home} ${emr_namenode_user}
	if [ \$? -ne 0 ];then
		cd ${script_home}
		bash ./clean${sv}.sh ${key_file}
    exit 1
	fi

  #read;sleep 10000

	#clean work
	if [ ${clean_env_when_service_done} -eq 1 ];then
	  cd ${script_home}
	  bash ./clean${sv}.sh ${key_file}
	  if [ \$? -ne 0 ];then
        	exit 1
	  fi
	fi

EOF
	if [ $? -ne 0 ];then
		echo "$(date '+%F %T'): service ${sv} test wrong,exit"
		break
	fi
	echo "$(date '+%F %T'): service ${sv} test is done"
	echo ""
	echo ""

done #service test loop done

#upload all results to conbench,tbd
echo "$(date '+%F %T'): upload result to conbench"

#shutdown cloud vms using ansible plugin,suppose CI VM has secret key to access cloud vms ,tbd
echo "$(date '+%F %T'): shutdown cloud vms and hdfs cluster!"
if [ ${run_mode} = "aws" ];then
	emr_cluster_id=$(cat /tmp/emr_cluster_id)
	#bash ${main_script_dir}/stopAWSVMs.sh
	#bash ${main_script_dir}/stopAWSEMR.sh ${emr_cluster_id}
elif [ ${run_mode} = "gcp" ];then
	echo "$(date '+%F %T'): stop vms on gcp to be done"
else
	echo "$(date '+%F %T'): stop failed,not supported run mode:${run_mode}"
fi

echo "$(date '+%F %T'): end perf test!"
