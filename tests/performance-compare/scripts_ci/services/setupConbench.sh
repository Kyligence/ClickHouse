#!/bin/bash

ps -ef|grep "flask run -h 0.0.0.0 -p 5000"|grep -v grep
if [ $? -eq 0 ];then
  echo "$(date '+%F %T'): conbench service ready,no need to setup"
  exit 0
fi

if [ ! -d ~/glutenTest/conbench/workspace/conbench ];then
  mkdir -p ~/glutenTest/conbench
  cd ~/glutenTest/conbench
  mkdir -p envs
  mkdir -p workspace
  cd envs
  sudo apt install -y python3.8-venv
  python3 -m venv conbench
  source conbench/bin/activate
  cd ~/glutenTest/conbench/workspace/
  git clone https://github.com/conbench/conbench.git
  cd ~/glutenTest/conbench/workspace/conbench
  pip install -i https://pypi.tuna.tsinghua.edu.cn/simple conbench[server]
fi

sudo apt install -y postgresql
sudo service postgresql start
sudo systemctl enable postgresql


sudo su postgres << EOF
psql << EOFSUB
CREATE DATABASE conbench_test;
CREATE DATABASE conbench_prod;
CREATE USER ubuntu;
ALTER USER ubuntu PASSWORD '123456';
CREATE DATABASE conbench_test OWNER ubuntu;
CREATE DATABASE conbench_prod OWNER ubuntu;
GRANT ALL PRIVILEGES ON DATABASE conbench_test TO ubuntu;
GRANT ALL PRIVILEGES ON DATABASE conbench_prod TO ubuntu;
\c conbench_prod
ALTER TABLE commit ALTER COLUMN sha TYPE varchar(4096);
EOFSUB
EOF

source ~/glutenTest/conbench/envs/conbench/bin/activate
cd ~/glutenTest/conbench/workspace/conbench
export CONBENCH_INTENDED_BASE_URL="http://localhost:5000/"
export DB_PASSWORD=123456

nohup flask run -h 0.0.0.0 -p 5000 > conbench.log 2>&1 &





