create database if not exists tpch100;
use tpch100;

create table if not exists customer ( c_custkey     bigint,
                             c_name        varchar(25) ,
                             c_address     varchar(40) ,
                             c_nationkey   bigint,
                             c_phone       char(15) ,
                             c_acctbal     decimal(15,2)   ,
                             c_mktsegment  char(10) ,
                             c_comment     varchar(117) )engine=MergeTree order by (c_custkey,c_name);


create table if not exists lineitem ( l_orderkey    bigint,
                             l_partkey     bigint,
                             l_suppkey     bigint,
                             l_linenumber  bigint,
                             l_quantity    decimal(15,2) ,
                             l_extendedprice  decimal(15,2) ,
                             l_discount    decimal(15,2) ,
                             l_tax         decimal(15,2) ,
                             l_returnflag  char(1) ,
                             l_linestatus  char(1) ,
                             l_shipdate    date ,
                             l_commitdate  date ,
                             l_receiptdate date ,
                             l_shipinstruct char(25) ,
                             l_shipmode     char(10) ,
                             l_comment      varchar(44) )engine=MergeTree
order by (l_shipdate,l_returnflag,l_linestatus);

create table if not exists nation  ( n_nationkey  bigint,
                            n_name       char(25) ,
                            n_regionkey  bigint,
                            n_comment    varchar(152))engine=MergeTree order by (n_name,n_regionkey);

create table if not exists region  ( r_regionkey  bigint,
                            r_name       char(25) ,
                            r_comment    varchar(152))engine=MergeTree order by (r_name);


create table if not exists part  ( p_partkey     bigint,
                          p_name        varchar(55) ,
                          p_mfgr        char(25) ,
                          p_brand       char(10) ,
                          p_type        varchar(25) ,
                          p_size        bigint,
                          p_container   char(10) ,
                          p_retailprice decimal(15,2) ,
                          p_comment     varchar(23)  )engine=MergeTree order by (p_name,p_mfgr);

create table if not exists supplier ( s_suppkey     bigint,
                             s_name        char(25) ,
                             s_address     varchar(40) ,
                             s_nationkey   bigint,
                             s_phone       char(15) ,
                             s_acctbal     decimal(15,2) ,
                             s_comment     varchar(101) )engine=MergeTree order by (s_suppkey,s_name);


create table if not exists partsupp ( ps_partkey     bigint,
                             ps_suppkey     bigint,
                             ps_availqty    bigint,
                             ps_supplycost  decimal(15,2)  ,
                             ps_comment     varchar(199)  )engine=MergeTree order by (ps_partkey,ps_suppkey);

create table if not exists orders  ( o_orderkey       bigint,
                           o_custkey        bigint,
                           o_orderstatus    char(1) ,
                           o_totalprice     decimal(15,2) ,
                           o_orderdate      date ,
                           o_orderpriority  char(15) ,
                           o_clerk          char(15) ,
                           o_shippriority   bigint,
                           o_comment        varchar(79) )engine=MergeTree order by (o_orderkey,o_custkey);


