#!/bin/bash

echo "$(date '+%F %T'): driver ${driver_instance_id} is long running,no stop"
#aws ec2 stop-instances --instance-ids ${driver_instance_id}
#if [ $? -ne 0 ];then
#        echo "$(date '+%F %T'): driver stop failed"
#        exit 111
#fi

OLD_IFS="$IFS"
IFS=","
workerIdsArr=(${workers_instance_ids})

for workerId in ${workerIdsArr[@]}
do
        echo "$(date '+%F %T'): stop worker ${workerId}"
	aws ec2 stop-instances --instance-ids ${workerId}
	if [ $? -ne 0 ];then
        echo "$(date '+%F %T'): worker stop failed"
        exit 111
fi
done


IFS="${OLD_IFS}"



