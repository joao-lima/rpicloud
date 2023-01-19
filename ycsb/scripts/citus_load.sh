#!/bin/bash

coordinator_ip=$1
workload=$2
recordcount=$3
workers_count=$4
r_factor=$5
b_size=$6
f_size=$7

# db_conf="# Properties file that contains database connection information.
# db.driver=org.postgresql.Driver
# db.url=jdbc:postgresql://$coordinator_ip:5432/ycsb?sslmode=disable
# db.user=postgres
# db.passwd=postgres
# "

db_conf="# Properties file that contains database connection information.
db.driver=org.postgresql.Driver
db.url=jdbc:postgresql://$coordinator_ip:5432/ycsb?reWriteBatchedInserts=true
db.user=postgres
db.passwd=postgres
db.batchsize=$b_size
jdbc.fetchsize=$f_size
jdbc.batchupdateapi=true
jdbc.autocommit=false
"

rm $JDBC_HOME/conf/db.properties
echo -e "$db_conf" > $JDBC_HOME/conf/db.properties
sleep 10

echo "[LOAD Script] Call shard_table.sh script to create usertable sharded"
/scripts/citus_create_table.sh postgres postgres $coordinator_ip $workers_count $r_factor $f_size

echo "[LOAD Script] Wait 3 min until cluster state stabilizes..."
sleep 180

echo "[LOAD Script] Performing load..."
$YCSB_HOME/bin/ycsb load jdbc -s \
-P $YCSB_HOME/workloads/workload$workload \
-P $JDBC_HOME/conf/db.properties \
-cp $CLASSPATH \
-p recordcount=$recordcount \
-p operationcount=10000 \
> /ycsb_outputs/citus-out-load-$workers_count-$recordcount-$workload-rf$r_factor-bs$b_size-fs$f_size.txt 2>&1

chmod 777 /ycsb_outputs/citus-out-load-$workers_count-$recordcount-$workload-rf$r_factor-bs$b_size-fs$f_size.txt

echo "[LOAD Script] Load finished!"
