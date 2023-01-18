select /*+SET_VAR(exec_mem_limit=8589934592, parallel_fragment_exec_instance_num=4,runtime_bloom_filter_size=4194304) */
    cntrycode,
    count(*) AS numcust,
    sum(c_acctbal) AS totacctbal
FROM (
    SELECT
        substring(c_phone , 1 , 2) AS cntrycode,
        c_acctbal
    FROM
        customer
    WHERE
        substring(c_phone , 1 , 2) IN ('13', '31', '23', '29', '30', '18', '17')
        AND c_acctbal > (
            SELECT
                avg(c_acctbal)
            FROM
                customer
            WHERE
                c_acctbal > 0.00
                AND substring(c_phone , 1 , 2) IN ('13', '31', '23', '29', '30', '18', '17'))
            AND NOT EXISTS (
                SELECT
                    *
                FROM
                    orders
                WHERE
                    o_custkey = c_custkey)) AS custsale
GROUP BY
    cntrycode
ORDER BY
    cntrycode;
