#!/bin/bash

if [ $# -ne 3 ];then
        echo "Usage: ./startAWSEMR.sh local_key_file emr_namenode_user emr_start_waiting_time_s"
        exit 1
fi

local_key_file=$1
emr_namenode_user=$2
emr_start_waiting_time_s=$3

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

echo "$(date '+%F %T'): start EMR"
#emr_cluster_id=`aws emr create-cluster --termination-protected --applications Name=Hadoop Name=Hive --tags 'Cost Center=OS' 'Project=OS' 'CRR=202211020004' 'Owner=liang.huang@kyligence.io' --ec2-attributes '{"KeyName":"ckops-awscn","InstanceProfile":"EMR_EC2_DefaultRole","SubnetId":"subnet-54657c2c","EmrManagedSlaveSecurityGroup":"sg-00b7e517b44936807","EmrManagedMasterSecurityGroup":"sg-00b7e517b44936807"}' --release-label emr-5.11.4 --log-uri 's3n://aws-logs-472319870699-cn-northwest-1/elasticmapreduce/' --instance-groups '[{"InstanceCount":3,"EbsConfiguration":{"EbsBlockDeviceConfigs":[{"VolumeSpecification":{"SizeInGB":512,"VolumeType":"gp2"},"VolumesPerInstance":1}],"EbsOptimized":true},"InstanceGroupType":"CORE","InstanceType":"m4.xlarge","Name":"datanode"},{"InstanceCount":1,"EbsConfiguration":{"EbsBlockDeviceConfigs":[{"VolumeSpecification":{"SizeInGB":512,"VolumeType":"gp2"},"VolumesPerInstance":1}],"EbsOptimized":true},"InstanceGroupType":"MASTER","InstanceType":"m4.2xlarge","Name":"namenode"}]' --auto-scaling-role EMR_AutoScaling_DefaultRole --ebs-root-volume-size 64 --service-role EMR_DefaultRole --enable-debugging --name 'kylin-glutenTest' --scale-down-behavior TERMINATE_AT_TASK_COMPLETION --region cn-northwest-1|awk '{print $2}'`
emr_cluster_id=`aws emr create-cluster --termination-protected --applications Name=Hadoop Name=Hive --tags 'Cost Center=OS' 'Project=OS' 'CRR=CRR20230109000015' 'Owner=liang.huang@kyligence.io' --ec2-attributes '{"KeyName":"ckops-awscn","InstanceProfile":"EMR_EC2_DefaultRole","SubnetId":"subnet-54657c2c","EmrManagedSlaveSecurityGroup":"sg-00b7e517b44936807","EmrManagedMasterSecurityGroup":"sg-00b7e517b44936807"}' --release-label emr-5.36.0 --log-uri 's3n://aws-logs-472319870699-cn-northwest-1/elasticmapreduce/' --instance-groups '[{"InstanceCount":3,"EbsConfiguration":{"EbsBlockDeviceConfigs":[{"VolumeSpecification":{"SizeInGB":512,"VolumeType":"gp2"},"VolumesPerInstance":1}],"EbsOptimized":true},"InstanceGroupType":"CORE","InstanceType":"m5.2xlarge","Name":"datanode"},{"InstanceCount":1,"EbsConfiguration":{"EbsBlockDeviceConfigs":[{"VolumeSpecification":{"SizeInGB":512,"VolumeType":"gp2"},"VolumesPerInstance":1}],"EbsOptimized":true},"InstanceGroupType":"MASTER","InstanceType":"m5.4xlarge","Name":"namenode"}]' --auto-scaling-role EMR_AutoScaling_DefaultRole --ebs-root-volume-size 64 --service-role EMR_DefaultRole --enable-debugging --name 'kylin-glutenTest' --scale-down-behavior TERMINATE_AT_TASK_COMPLETION --region cn-northwest-1|awk '{print $2}'`

echo "$(date '+%F %T'): waiting for EMR ${emr_cluster_id} start"
echo -e ${emr_cluster_id} > /tmp/emr_cluster_id #used when destroy emr at last of test

loop=0
private_namenode_ip=''
namenode_ip=''
while true
do
	let loop++
	sleep ${emr_start_waiting_time_s}
	namenode_ip_arr=(`aws emr list-instances --cluster-id ${emr_cluster_id}|grep 4xlarge|awk '{print $8,$10}'`)
	#172.31.24.198 43.192.54.37
	private_namenode_ip=${namenode_ip_arr[0]}
	namenode_ip=${namenode_ip_arr[1]}
	echo "$(date '+%F %T'): namenode ip:${private_namenode_ip} ${namenode_ip}"
	if [ -n "${namenode_ip}" ] || [ ${loop} -ge 10 ];then
		break
	fi
	echo "$(date '+%F %T'): still waiting for EMR ${emr_cluster_id} start"
done


echo -e ${private_namenode_ip} > /tmp/private_namenode_ip #used for spark create table
echo -e ${namenode_ip} > /tmp/namenode_ip #used for connecting namenode when data preparation

echo -e `aws emr list-instances --cluster-id ${emr_cluster_id}|grep xlarge|awk '{print $8}'` > /tmp/private_all_emr_node_ip
private_all_emr_node_ip=(`cat /tmp/private_all_emr_node_ip`)
private_all_emr_node_ip_list=''
private_datanode_ip_list=''
for emr_node in ${private_all_emr_node_ip[@]}
do
  private_all_emr_node_ip_list=${emr_node}","${private_all_emr_node_ip_list}

  if [ ${emr_node} != ${private_namenode_ip} ];then
    private_datanode_ip_list=${emr_node}","${private_datanode_ip_list}
  fi
done
echo -ne ${private_all_emr_node_ip_list%?} > /tmp/private_all_emr_node_ip
echo -ne ${private_datanode_ip_list%?} > /tmp/private_datanode_ip

echo "$(date '+%F %T'): hdfs health check!"
sleep ${emr_start_waiting_time_s}
ssh -o StrictHostKeyChecking=no -i ${local_key_file} ${emr_namenode_user}@${namenode_ip} << EOF
iter=0
while true
do
	let iter++
	/usr/bin/hdfs dfs -ls /
	if [ \$? -ne 0 ];then
		if [ \${iter} -ge 10 ];then
			exit 1
		else
			echo "$(date '+%F %T'): still waiting for EMR ${emr_cluster_id} hdfs service ready"
			sleep ${emr_start_waiting_time_s}
		fi
	else
		break
	fi
done
EOF

if [ $? -ne 0 ];then
	echo "$(date '+%F %T'): hdfs not well,just destroy and exit"
	aws emr modify-cluster-attributes --cluster-id ${emr_cluster_id} --no-termination-protected
	aws emr terminate-clusters --cluster-ids ${emr_cluster_id}
	exit 114
else
	echo "$(date '+%F %T'): hdfs is healthy"
fi

