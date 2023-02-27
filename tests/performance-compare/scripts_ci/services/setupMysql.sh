#!/bin/bash
echo "$(date '+%F %T'): mysql setup begin"
#sudo apt-get install -y mysql-server
sudo apt install -y mysql-client
sudo apt install -y libmysqlclient-dev

sleep 10

#check mysql setup
sudo mysql -h localhost  -u root -e "select 1"
if [ $? -ne 0 ];then
	echo "$(date '+%F %T'): mysql not setup well!Have a check!"
	exit 103
fi

echo "$(date '+%F %T'): mysql setup well!"
