#!/bin/bash

#install awscli
#In production env awscli and its config is included in docker image
echo "$(date '+%F %T'): install awscli"
sudo apt install -y awscli
echo "$(date '+%F %T'): check awscli config file"
ls -hl ~/.aws/credentials
if [ $? -ne 0 ];then
	echo "$(date '+%F %T'): awscli config file not exists!"
	exit 110
fi

echo "$(date '+%F %T'): start driver ${driver_instance_id}"
aws ec2 start-instances --instance-ids ${driver_instance_id}
if [ $? -ne 0 ];then
        echo "$(date '+%F %T'): driver start failed"
        exit 110
fi

OLD_IFS="$IFS"
IFS=","
workerIdsArr=(${workers_instance_ids})

for workerId in ${workerIdsArr[@]}
do
        echo "$(date '+%F %T'): start worker ${workerId}"
	aws ec2 start-instances --instance-ids ${workerId}
	if [ $? -ne 0 ];then
	        echo "$(date '+%F %T'): worker start failed"
        	exit 110
	fi
done


IFS="${OLD_IFS}"


sleep ${vm_start_waiting_time_s}
