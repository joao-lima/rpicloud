#!/bin/bash

workload=$1
recordcount=$2
replicas=$3

# Define aux var to splits count (10*regionservers number)
n_splits=14

# Create Table
echo -e "create 'usertable', 'family', {SPLITS => (1..$n_splits).map {|i| \"user#{1000+i*(9999-1000)/$n_splits}\"}}" | hbase shell -n &
status_code=$?
if [ ${status_code} -ne 0 ]; then
 echo "Create table failed! status: ${status_code}"
fi

# # Create Table
# hbase org.apache.hadoop.hbase.util.RegionSplitter usertable HexStringSplit -c $(($replicas - 1)) -f family

# Wait for cluster stabilizes
sleep 300

# Perform YCSB Load
echo "[LOAD Script] Performing load..."

ycsb load hbase2 -s \
-P $YCSB_HOME/workloads/workload$workload \
-cp /$HBASE_HOME/conf \
-p table=usertable \
-p columnfamily=family \
-p recordcount=$recordcount \
-p operationcount=10000 \
-p fieldcount=10 \
-p fieldlength=100 \
-p core_workload_insertion_retry_limit=100 \
-p core_workload_insertion_retry_interval=10 \
> /ycsb_outputs/hbase-out-load-$replicas-$recordcount-$workload.txt 2>&1

chmod 777 /ycsb_outputs/hbase-out-load-$replicas-$recordcount-$workload.txt

echo "[Load Script] Load finished!"
