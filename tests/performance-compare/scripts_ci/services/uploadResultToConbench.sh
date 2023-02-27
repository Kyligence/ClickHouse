#!/bin/ksh

sudo apt install -y curl

#GlutenWithCHStandard_2023_01_15_18_03_24/
result_dir=$(cat /tmp/result_dir)
if [ -z "${result_dir}" ];then
  echo "$(date '+%F %T'): result dir not found,upload failed"
  exit 160
fi



raw_token=$(curl -i -X 'POST' \
  'http://ec2-161-189-50-52.cn-northwest-1.compute.amazonaws.com.cn:5000/api/login/' \
  -H 'accept: */*' \
  -H 'Content-Type: application/json' \
  -d '{
  "email": "liang.huang@kyligence.io",
  "password": "123456",
  "remember_me": true
}'|grep remember_token)


raw_token_sub1=$(echo ${raw_token#*: })

login_token=$(echo ${raw_token_sub1%%;*})


cd "${result_dir}"|| exit 160

chbackend_cids="chbackend:"
cat chbackend_commit_ids | while read line
do
  chbackend_cids=${chbackend_cids}${line}","
done

gluten_cids="gluten:"
cat gluten_commit_ids | while read line
do
  gluten_cids=${gluten_cids}${line}","
done

commit_ids=${chbackend_cids}"        "${gluten_cids}


run_id=$(date +%Y-%m-%d)

batch_id=""
# change detail batchid
trigger_method=$(cat /tmp/trigger)
if [ "${trigger_method}" == "event" ];then
  batch_id=${run_id}_b_event_triggered_$(date "+%H:%M:%S")
  commit_ids="PR        "${commit_ids}
elif [ "${trigger_method}" == "timer" ];then
  batch_id=${run_id}_b1
fi

year=$(date +%Y)
run_trend_id=${year}
timestamp=$(date "+%Y-%m-%d %H:%M:%S")

# load detail csv
declare -A detail_map
while read line
do
  detail_map[${line%%,*}]=${line#*,}
  # echo ${detail_map[${line%%,*}]}
done < detail.csv

# load agg csv
total_time=0
cat aggregated.csv | while read line
do
  query=${line%%,*}
  if [ ${query} == "name" ];then
    continue
  fi
  # echo "query:${query}"
  # echo "detail data:"${detail_map[${query}]}

  data=${line#*,}
  data_arr=(${data//,/ })
  avg=${data_arr[1]}  # put median into avg,so as to let conbench to show "mean" value with median in fact
  median=${data_arr[1]}
  min=${data_arr[2]}
  max=${data_arr[3]}


  total_time=$((${total_time} + ${avg}))

  # gen single run benchmarks
  curl -X 'POST' \
    'http://ec2-161-189-50-52.cn-northwest-1.compute.amazonaws.com.cn:5000/api/benchmarks/' \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json' \
    -H "Cookie: ${login_token}" \
      -d "{
      \"batch_id\": \"${batch_id}\",
      \"cluster_info\": {
        \"info\": {},
        \"name\": \"\",
        \"optional_info\": {}
      },
      \"context\": {\"benchmark_language\":\"scala & c++\"},
      \"github\": {
        \"branch\": \"main\",
        \"commit\": \"${commit_ids}\",
        \"pr_number\": 0,
        \"repository\": \"oap-project/gluten\"
      },
      \"info\": {},
      \"is_step_change\": true,
      \"optional_benchmark_info\": {},
      \"run_id\": \"${run_id}\",
      \"run_name\": \"${run_id}\",
      \"run_reason\": \"${run_id} single run,time scheduled test\",
      \"stats\": {
        \"data\": [
          ${detail_map[${query}]}
        ],
        \"iqr\": 0,
        \"iterations\": 3,
        \"max\": ${max},
        \"mean\": ${avg},
        \"median\": ${median},
        \"min\": ${min},
        \"q1\": 0,
        \"q3\": 0,
        \"stdev\": 0,
        \"time_unit\": \"ms\",
        \"times\": [
          1
        ],
        \"unit\": \"ms\"
      },
      \"tags\": {\"name\":\"${batch_id}\", \"display\":\"${query}\"},
      \"timestamp\": \"${timestamp}\",
      \"validation\": {}
    }"

    # gen yearly query trend benchmarks
    curl -X 'POST' \
          'http://ec2-161-189-50-52.cn-northwest-1.compute.amazonaws.com.cn:5000/api/benchmarks/' \
          -H 'accept: application/json' \
          -H 'Content-Type: application/json' \
          -H "Cookie: ${login_token}" \
            -d "{
            \"batch_id\": \"${run_trend_id}_trend_${query}\",
            \"cluster_info\": {
              \"info\": {},
              \"name\": \"\",
              \"optional_info\": {}
            },
            \"context\": {\"benchmark_language\":\"scala & c++\"},
            \"github\": {
              \"branch\": \"main\",
              \"commit\": \"${commit_ids}\",
              \"pr_number\": 0,
              \"repository\": \"oap-project/gluten\"
            },
            \"info\": {},
            \"is_step_change\": true,
            \"optional_benchmark_info\": {},
            \"run_id\": \"${run_trend_id}\",
            \"run_name\": \"${run_trend_id}\",
            \"run_reason\": \"${year} query response trend\",
            \"stats\": {
              \"data\": [
                ${detail_map[${query}]}
              ],
              \"iqr\": 0,
              \"iterations\": 3,
              \"max\": ${max},
              \"mean\": ${avg},
              \"median\": ${median},
              \"min\": ${min},
              \"q1\": 0,
              \"q3\": 0,
              \"stdev\": 0,
              \"time_unit\": \"ms\",
              \"times\": [
                1
              ],
              \"unit\": \"ms\"
            },
            \"tags\": {\"name\":\"${run_trend_id}_trend_${query}\", \"display\":\"${timestamp}\"},
            \"timestamp\": \"${timestamp}\",
            \"validation\": {}
          }"

done

echo "total_time:"${total_time}

# get total time and put it into a special "total time batch" of this year
curl -X 'POST' \
          'http://ec2-161-189-50-52.cn-northwest-1.compute.amazonaws.com.cn:5000/api/benchmarks/' \
          -H 'accept: application/json' \
          -H 'Content-Type: application/json' \
          -H "Cookie: ${login_token}" \
            -d "{
            \"batch_id\": \"${run_trend_id}_trend_total\",
            \"cluster_info\": {
              \"info\": {},
              \"name\": \"\",
              \"optional_info\": {}
            },
            \"context\": {\"benchmark_language\":\"scala & c++\"},
            \"github\": {
              \"branch\": \"main\",
              \"commit\": \"${commit_ids}\",
              \"pr_number\": 0,
              \"repository\": \"oap-project/gluten\"
            },
            \"info\": {},
            \"is_step_change\": true,
            \"optional_benchmark_info\": {},
            \"run_id\": \"${run_trend_id}\",
            \"run_name\": \"${run_trend_id}\",
            \"run_reason\": \"query response trend\",
            \"stats\": {
              \"data\": [
                ${total_time}
              ],
              \"iqr\": 0,
              \"iterations\": 3,
              \"max\": ${total_time},
              \"mean\": ${total_time},
              \"median\": ${total_time},
              \"min\": ${total_time},
              \"q1\": 0,
              \"q3\": 0,
              \"stdev\": 0,
              \"time_unit\": \"ms\",
              \"times\": [
                1
              ],
              \"unit\": \"ms\"
            },
            \"tags\": {\"name\":\"${run_trend_id}_trend_total\", \"display\":\"${timestamp}\"},
            \"timestamp\": \"${timestamp}\",
            \"validation\": {}
          }"
