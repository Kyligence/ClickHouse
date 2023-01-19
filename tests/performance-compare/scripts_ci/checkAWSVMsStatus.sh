#!/bin/bash
#to be done...........................
#
getIP(){
	id=$1
	ip=$2
	if [ ${ip} = "public" ];then
		return $(aws ec2 describe-instances --instance-id ${id}|grep ASSOCIATION|awk '{print $4}'|head -n1)
	elif [ ${ip} = "private" ];then
        	return $(aws ec2 describe-instances --instance-id ${id}|grep PRIVATEIPADDRESSES|awk '{print $4}')
	else
        	return 'none'
	fi

}


if [ $# -ne 2 ];then
	echo "Usage: ./getAWSVmIP.sh ip_type(public/private) node_type(driver/workers)"
        exit 1
fi

ip_type=$1
node_type=$2

if [ ${node_type} = "driver" ];then
	getIP ${driver_instance_id} ${ip_type}
elif [ ${node_type} = "workers" ];then
	OLD_IFS="$IFS"
	IFS=","
	workerIdsArr=(${workers_instance_ids})
	
	worker_hosts=''

	for workerId in ${workerIdsArr[@]}
	do
		worker_hosts=$(getIP ${workerId} ${ip_type})","${worker_hosts}
	done
	IFS="${OLD_IFS}"
	echo -ne ${worker_hosts%?}
else
	echo "$(date '+%F %T'): not support node_type ${node_type}"
	exit 112
fi
