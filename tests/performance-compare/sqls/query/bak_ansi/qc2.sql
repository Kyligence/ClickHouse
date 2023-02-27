SELECT min(aaa), min(bbb), min(sum_base_price)
from (
SELECT
    l_partkey,
    min(l_partkey) as aaa,
    min(l_suppkey) as bbb,
    sum(l_extendedprice) AS sum_base_price
FROM
    lineitem
GROUP BY
    l_partkey
ORDER BY
    l_partkey) as a;
