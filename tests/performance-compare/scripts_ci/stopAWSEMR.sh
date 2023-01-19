#!/bin/bash

if [ $# -ne 1 ];then
        echo "Usage: ./stopAWSEMR.sh emr_cluster_id"
        exit 1
fi

emr_cluster_id=$1

aws emr modify-cluster-attributes --cluster-id ${emr_cluster_id} --no-termination-protected
aws emr terminate-clusters --cluster-ids ${emr_cluster_id}
echo "$(date '+%F %T'): emr ${emr_cluster_id} destroyed"
