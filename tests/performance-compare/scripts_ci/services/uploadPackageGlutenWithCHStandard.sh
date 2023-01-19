#!/bin/bash

if [ $# -ne 3 ];then
        echo "Usage: ./uploadPackageFromCIGlutenWithCHStandard.sh local_key_file cloud_vm_user driver_host"
        exit 1
fi

local_key_file=$1
cloud_vm_user=$2
driver_host=$3

#copy gluten jar and libch.so to driver
echo "$(date '+%F %T'): copy gluten jar and libch.so to driver"
ssh -i ${local_key_file} ${cloud_vm_user}@${driver_host} "ls -hl ${gluten_standard_jar}"
if [ $? -ne 0 ];then
	echo "$(date '+%F %T'): ${gluten_standard_jar} does not exist,need upload to driver!"
	scp -i ${local_key_file} ${local_gluten_standard_jar} ${cloud_vm_user}@${driver_host}:${gluten_standard_jar}
fi

ssh -i ${local_key_file} ${cloud_vm_user}@${driver_host} "ls -hl ${libch_standard_so}"
if [ $? -ne 0 ];then
	echo "$(date '+%F %T'): ${libch_standard_so} does not exist,need upload to driver!"
	scp -i ${local_key_file} ${local_libch_standard_so} ${cloud_vm_user}@${driver_host}:${libch_standard_so}
fi

#copy hive-site.xml and hive jars from emr hive home
#namenode_ip=$(cat /tmp/namenode_ip)
#scp -i ${local_key_file} ${local_key_file} ${emr_namenode_user}@${namenode_ip}:${namenode_key_file}
#ssh -i ${local_key_file} ${local_key_file} ${emr_namenode_user}@${namenode_ip} <<  EOF
#scp -i ~/
#EOF




