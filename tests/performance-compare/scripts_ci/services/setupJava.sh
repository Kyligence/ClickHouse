#!/bin/bash

if [ $# -ne 1 ];then
	echo "Usage: ./setupJava.sh key_file"
	exit 1
fi

echo "$(date '+%F %T'): java setup begin"

key_file=$1

ansible --key-file ${key_file} tcluster -m shell -a "sudo apt-get install -y openjdk-8-jdk"


grep "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" /etc/profile
if [ $? -ne 0 ];then
	ansible --key-file ${key_file} tcluster -m shell -a "echo 'export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64' | sudo tee -a /etc/profile"
fi

#check java setup and JAVA_HOME
ansible --key-file ${key_file} tcluster -m shell -a "java -version"
if [ $? -ne 0 ];then
	echo "$(date '+%F %T'): java not setup well!Have a check!"
	exit 103
fi

echo "$(date '+%F %T'): java setup well!"
