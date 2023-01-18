select /*+SET_VAR(exec_mem_limit=8589934592, parallel_fragment_exec_instance_num=8, enable_vectorized_engine=true, batch_size=4096, disable_join_reorder=true, enable_cost_based_join_reorder=true, enable_projection=true, runtime_filter_mode=OFF) */
    100.00 * sum(
        CASE WHEN p_type LIKE 'PROMO%' THEN
            l_extendedprice * (1 - l_discount)
        ELSE
            0
        END) / sum(l_extendedprice * (1 - l_discount)) AS promo_revenue
FROM
    lineitem,
    part
WHERE
    l_partkey = p_partkey
    AND l_shipdate >= date'1995-09-01'
    AND l_shipdate < date'1995-09-01' + interval 1 month;
