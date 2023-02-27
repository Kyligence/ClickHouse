#!/bin/bash

if [ $# -ne 6 ];then
        echo "Usage: ./setupAnsible.sh key_file driver_host worker_hosts all_emr_node_ip cloud_vm_user emr_namenode_user"
        exit 1
fi

echo "$(date '+%F %T'): ansible setup begin"
sudo apt-get update -y


#python >= 2.7
which python3
if [ $? -ne 0 ];then
        echo "$(date '+%F %T'): Python3 not found!Have a check!"
        exit 100
fi

sudo apt-get install -y ansible

DRIVER_HOST=$2
WORKER_HOSTS=$3

OLD_IFS="$IFS"
IFS=","
wHostsArr=(${WORKER_HOSTS})


#setup ansible host config
echo "$(date '+%F %T'): setup ansible host config"
sudo chmod a+w /etc/ansible/hosts
#config tcluster:driver+workers
echo -e "[tcluster]\n${DRIVER_HOST}" > /etc/ansible/hosts
for worker in ${wHostsArr[@]}
do	
	echo -e "${worker}" >> /etc/ansible/hosts
done

#config driver
echo -e "\n[driver]\n${DRIVER_HOST}" >> /etc/ansible/hosts
#config workers
echo -e "\n[workers]" >> /etc/ansible/hosts
for worker in ${wHostsArr[@]}
do
        echo -e "${worker}" >> /etc/ansible/hosts
done

#config all:driver+workers+emr
cloud_vm_user=$5
emr_namenode_user=$6
echo -e "\n[exporter]\n${DRIVER_HOST} ansible_user=${cloud_vm_user}" >> /etc/ansible/hosts
for worker in ${wHostsArr[@]}
do
	echo -e "${worker} ansible_user=${cloud_vm_user}" >> /etc/ansible/hosts
done
all_emr_node_ip=$4 #comma seperated list
emrHostsArr=(${all_emr_node_ip})
for emr_node in ${emrHostsArr[@]}
do
	echo -e "${emr_node} ansible_user=${emr_namenode_user}" >> /etc/ansible/hosts
done



IFS="${OLD_IFS}"

sudo sed -i 's/#host_key_checking = False/host_key_checking = False/' /etc/ansible/ansible.cfg

#check if ansible works well
key_file=$1
echo "$(date '+%F %T'): check if ansible works well"
ansible --key-file ${key_file} exporter -m shell -a "ls -hl"

if [ $? -ne 0 ];then
	echo "$(date '+%F %T'): Ansible not setup well!Have a check!"
	exit 101
fi

echo "$(date '+%F %T'): ansible setup end"
