drop table if exists test;

set allow_suspicious_low_cardinality_types = 1;

CREATE TABLE test
(
    `timestamp` DateTime,
    `latitude` Nullable(Float32) CODEC(Gorilla, ZSTD(1)),
    `longitude` Nullable(Float32) CODEC(Gorilla, ZSTD(1)),
    `xxxx1` LowCardinality(UInt8),
    `xxxx2` LowCardinality(Nullable(Int16)),
    `xxxx3` LowCardinality(Nullable(Int16)),
    `xxxx4` Nullable(Int32),
    `xxxx5` LowCardinality(Nullable(Int32)),
    `xxxx6` Nullable(Int32),
    `xxxx7` Nullable(Int32),
    `xxxx8` LowCardinality(Int32),
    `xxxx9` LowCardinality(Nullable(Int16)),
    `xxxx10` LowCardinality(Nullable(Int16)),
    `xxxx11` LowCardinality(Nullable(Int16)),
    `xxxx12` LowCardinality(String),
    `xxxx13` Nullable(Float32),
    `xxxx14` LowCardinality(String),
    `xxxx15` LowCardinality(Nullable(String)),
    `xxxx16` LowCardinality(String),
    `xxxx17` LowCardinality(String),
    `xxxx18` FixedString(19),
    `xxxx19` FixedString(17),
    `xxxx20` LowCardinality(UInt8),
    `xxxx21` LowCardinality(Nullable(Int16)),
    `xxxx22` LowCardinality(Nullable(Int16)),
    `xxxx23` LowCardinality(Nullable(Int16)),
    `xxxx24` LowCardinality(Nullable(Int16)),
    `xxxx25` LowCardinality(Nullable(Int16)),
    `xxxx26` LowCardinality(Nullable(Int16)),
    `xxxx27` Nullable(Float32),
    `xxxx28` LowCardinality(Nullable(String)),
    `xxxx29` LowCardinality(String),
    `xxxx30` LowCardinality(String),
    `xxxx31` LowCardinality(Nullable(String)),
    `xxxx32` UInt64,
    PROJECTION cumsum_projection_simple
    (
        SELECT
            xxxx1,
            toStartOfInterval(timestamp, toIntervalMonth(1)),
            toStartOfWeek(timestamp, 8),
            toStartOfInterval(timestamp, toIntervalDay(1)),
            xxxx17,
            xxxx16,
            xxxx14,
            xxxx9,
            xxxx10,
            xxxx21,
            xxxx22,
            xxxx11,
            sum(multiIf(xxxx21 IS NULL, 0, 1)),
            sum(multiIf(xxxx22 IS NULL, 0, 1)),
            sum(multiIf(xxxx23 IS NULL, 0, 1)),
            max(toStartOfInterval(timestamp, toIntervalDay(1))),
            max(CAST(CAST(toStartOfInterval(timestamp, toIntervalDay(1)), 'Nullable(DATE)'), 'Nullable(TIMESTAMP)')),
            min(toStartOfInterval(timestamp, toIntervalDay(1))),
            min(CAST(CAST(toStartOfInterval(timestamp, toIntervalDay(1)), 'Nullable(DATE)'), 'Nullable(TIMESTAMP)')),
            count(),
            sum(1),
            COUNTDistinct(xxxx16),
            COUNTDistinct(xxxx31),
            COUNTDistinct(xxxx14),
            COUNTDistinct(CAST(toStartOfInterval(timestamp, toIntervalDay(1)), 'Nullable(DATE)'))
        GROUP BY
            xxxx1,
            toStartOfInterval(timestamp, toIntervalMonth(1)),
            toStartOfWeek(timestamp, 8),
            toStartOfInterval(timestamp, toIntervalDay(1)),
            xxxx1,
            toStartOfInterval(timestamp, toIntervalMonth(1)),
            toStartOfWeek(timestamp, 8),
            toStartOfInterval(timestamp, toIntervalDay(1)),
            xxxx17,
            xxxx16,
            xxxx14,
            xxxx9,
            xxxx10,
            xxxx21,
            xxxx22,
            xxxx11
    )
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(timestamp)
ORDER BY (xxxx17, xxxx14, xxxx16, toStartOfDay(timestamp), left(xxxx19, 10), timestamp);

INSERT INTO test SELECT * replace 1 as xxxx16 replace 1 as xxxx1 replace '2022-02-02 01:00:00' as timestamp replace 'Airtel' as xxxx14 FROM generateRandom() LIMIT 100;
INSERT INTO test SELECT * replace 1 as xxxx16 replace 1 as xxxx1 replace '2022-02-02 01:00:00' as timestamp replace 'BSNL' as xxxx14 FROM generateRandom() LIMIT 100;
INSERT INTO test SELECT * replace 1 as xxxx16 replace 1 as xxxx1 replace '2022-02-02 01:00:00' as timestamp replace 'xxx' as xxxx14 FROM generateRandom() LIMIT 100;

select sum(1) from test where toStartOfInterval(timestamp, INTERVAL 1 day) >= TIMESTAMP '2022-02-01 01:00:00' and xxxx14 in ('Airtel', 'BSNL') and xxxx1 = 1 GROUP BY xxxx16;

drop table test;
