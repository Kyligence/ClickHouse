SELECT min(aaa), min(bbb), min(sum_qty), min(sum_base_price),
       min(sum_disc_price), min(sum_charge),
       min(avg_qty), min(avg_price), min(avg_disc),
       min(count_order) from (
SELECT
    l_partkey,
    min(l_partkey) as aaa,
    min(l_suppkey) as bbb,
    sum(l_quantity) AS sum_qty,
    sum(l_extendedprice) AS sum_base_price,
    sum(l_extendedprice * (1 - l_discount)) AS sum_disc_price,
    sum(l_extendedprice * (1 - l_discount) * (1 + l_tax)) AS sum_charge,
    avg(l_quantity) AS avg_qty,
    avg(l_extendedprice) AS avg_price,
    avg(l_discount) AS avg_disc,
    count(*) AS count_order
FROM
    lineitem
GROUP BY
    l_partkey
ORDER BY
    l_partkey) as a;
