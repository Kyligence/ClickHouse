SELECT
    o_orderpriority,
    count(*) AS order_count
FROM
(
    SELECT l_orderkey
    FROM lineitem
    WHERE l_commitdate < l_receiptdate
) AS l
GLOBAL INNER JOIN
(
    SELECT
        o_orderpriority,
        o_orderkey
    FROM orders
    WHERE (o_orderdate >= toDate('1993-07-01')) AND (o_orderdate < (toDate('1993-07-01') + toIntervalMonth(3)))
) AS o ON l.l_orderkey = o.o_orderkey
GROUP BY o_orderpriority
ORDER BY o_orderpriority ASC
