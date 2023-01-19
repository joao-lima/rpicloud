#!/bin/bash

workload=$1
recordcount=$2
replicas=$3
exe=$4

echo "[RUN Script] replicas:$replicas workload:$workload \
recordcount:$recordcount exec:$exe"

ycsb run hbase2 -s \
-P $YCSB_HOME/workloads/workload$workload \
-cp /$HBASE_HOME/conf \
-p table=usertable \
-p columnfamily=family \
-p recordcount=$recordcount \
-p operationcount=10000 \
> /ycsb_outputs/hbase-out-$replicas-$recordcount-$workload-$exe.txt 2>&1

chmod 777 /ycsb_outputs/hbase-out-$replicas-$recordcount-$workload-$exe.txt

echo "[RUN Script] Finished!"
