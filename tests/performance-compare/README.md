# 性能测试工具

本工具可在云上测试gluten、vanilla spark、starrocks、clickhouse的性能，其中clickhouse部分处于需求变化中，暂时是半完成状态；
另外暂时屏蔽掉了关闭ec2和emr部分的调用，方便我们测试后能检查日志和下次测试复用emr上的数据；
通过git clone https://github.com/loneylee/ClickHouse/tree/benchmark 获取；
工具脚本工程在ClickHouse/tests/performance-compare下面。

## quick start

本地运行scripts_ci下的mainProcessOnCI.sh即可开始测试，前提是配置好scripts_ci/mainProcessOnCI.conf、scripts_ci/services/var*.conf（有四个，每种服务对应一个配置文件）
下面我们会关注可能变动比较频繁的项

### scripts_ci/mainProcessOnCI.conf
主脚本的配置文件

* export need_prepare_emr=1

  1代表性能测试前需要重新开启一个emr集群并导入数据，一般用于emr还没有开启过的case；0代表不需要开新的emr，测试直接使用已有的emr，脚本会从本地/tmp/emr_cluster_id、/tmp/private_all_emr_node_ip、/tmp/namenode_ip
里获取emr集群信息，一般用于上次测试已经开启了emr，本次想节省时间直接复用的case

* export driver_instance_id="i-0ca8a1a24f3c2c698"

  Ec2 driver instance id，生成好的parquet和mergetree数据，放在driver的/home/ubuntu/glutenTest/data下，目前没有和所有worker端同步

* export workers_instance_ids="i-0836efc374c3dd363,i-028c7c6346d360419,i-08ebcd0d97c7eb348"

  Ec2 worker instance ids，如果想单节点测试，这里可以写一个driver instance的id就行了，比如export workers_instance_ids="i-0ca8a1a24f3c2c698"

* export local_key_file="/home/lhuang/ckops-awscn.pem"

  访问ec2实例的私钥，如果没有请向管理员索要

* export local_script_home="/home/lhuang/glutenTest/ClickHouse/tests/performance-compare/scripts_ci/services"

  本地需要上传到ec2实例上的脚本文件父目录，文件已经在ClickHouse/tests/performance-compare/scripts_ci/services里准备好了

* export local_locust_home="/home/lhuang/glutenTest/ClickHouse/tests/performance-compare/tools"

  本地需要上传到ec2实例上的locust脚本文件父目录，文件已经在ClickHouse/tests/performance-compare/tools里准备好了

* export local_sqls_home="/home/lhuang/glutenTest/ClickHouse/tests/performance-compare/sqls/query"

  本地需要上传到ec2实例上的sql脚本文件父目录，文件已经在ClickHouse/tests/performance-compare/sqls/query里准备好了

* export local_aws_config_dir="/home/lhuang/.aws"

  访问aws s3的密钥文件，如果没有请向管理员索要

* export iteration=1

  测试的轮次数

* export result_home=/home/ubuntu/glutenTest/result

  测试结果存放在driver端的父目录地址

* export service=(GlutenWithCHStandard)

  测试的服务类别列表，比如要连续测试几种，可以这样写，export service=(Starrocks GlutenWithCHStandard VanillaSpark Clickhouse)
clickhouse暂时是半自动化，driver和worker上都安装好了clickhouse，已经建好了表并导入了数据

* export clean_env_when_service_done=0

  1表示在完成一种服务测试后，需要做实例清理工作，已方便下一种服务的测试，一般用于完全自动化模式；0表示不需要实例清理，一般用于需要人工查看和试验的场景


### scripts_ci/services/varGlutenWithCHStandard.conf
测试gluten的配置文件

* export local_gluten_standard_jar="/home/lhuang/gluten-1.0.0-SNAPSHOT-jar-with-dependencies.jar"

  放在本地的gluten jar包，如果driver端没有这个jar包（放在ubuntu用户的家目录下），就会从本地重新上传。这里是为了节省半手工测试的时间，后面完全自动化的时候这里会改成每次都上传

* export local_libch_standard_so="/home/lhuang/libch.so"

  放在本地的libch包，如果driver端没有这个包（放在ubuntu用户的家目录下），就会从本地重新上传。这里是为了节省半手工测试的时间，后面完全自动化的时候这里会改成每次都上传

* export inner_table=1

  1表示测试内表；0表示测试外表

* export column_nullable="False"

  False表示测试not null；True表示测试nullable


### scripts_ci/services/varStarrocks.conf
测试starrocks的配置文件
* export inner_table=1

  1表示测试内表；0表示测试外表

* export column_nullable="True"

  False表示测试not null；True表示测试nullable

## 注意事项
* ClickHouse/tests/performance-compare/sqls/query/ansi 里的查询会自动运行
* ClickHouse/tests/performance-compare/tools/datasource/statement.py 开头的数组会控制建表的数量，TABLE_NAMES = ["customer", "lineitem", "nation", "orders", "part", "partsupp", "region", "supplier"]
