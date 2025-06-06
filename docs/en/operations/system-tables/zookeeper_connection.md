---
slug: /en/operations/system-tables/zookeeper_connection
---
#zookeeper_connection

This table does not exist if ZooKeeper is not configured. The 'system.zookeeper_connection' table shows current connections to ZooKeeper (including auxiliary ZooKeepers). Each row shows information about one connection.

Columns:

-   `name` ([String](../../sql-reference/data-types/string.md)) — ZooKeeper cluster's name.
-   `host` ([String](../../sql-reference/data-types/string.md)) — The hostname/IP of the ZooKeeper node that ClickHouse connected to.
-   `port` ([String](../../sql-reference/data-types/string.md)) — The port of the ZooKeeper node that ClickHouse connected to.
-   `index` ([UInt8](../../sql-reference/data-types/int-uint.md)) — The index of the ZooKeeper node that ClickHouse connected to. The index is from ZooKeeper config.
-   `connected_time` ([String](../../sql-reference/data-types/string.md)) — When the connection was established
-   `is_expired` ([UInt8](../../sql-reference/data-types/int-uint.md)) — Is the current connection expired.
-   `keeper_api_version` ([String](../../sql-reference/data-types/string.md)) — Keeper API version.
-   `client_id` ([UInt64](../../sql-reference/data-types/int-uint.md)) — Session id of the connection.

Example:

``` sql
SELECT * FROM system.zookeeper_connection;
```

``` text
┌─name──────────────┬─host─────────┬─port─┬─index─┬──────connected_time─┬─is_expired─┬─keeper_api_version─┬──────────client_id─┐
│ default_zookeeper │ 127.0.0.1    │ 2181 │     0 │ 2023-05-19 14:30:16 │          0 │                  0 │ 216349144108826660 │
└───────────────────┴──────────────┴──────┴───────┴─────────────────────┴────────────┴────────────────────┴────────────────────┘
```
