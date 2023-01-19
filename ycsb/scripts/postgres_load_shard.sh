#!/bin/bash

node_ip=$1
workload=$2
recordcount=$3
replicas=$4
b_size=$5
f_size=$6

coordinator_node=$(getent hosts tasks.coordinator | awk '{print $1}'| head -n 1)
shard_nodes=(`getent hosts tasks.shard | awk '{print $1}'`)
port="5432"

db_url="jdbc:postgresql://$coordinator_node:$port/ycsb;"
shards_count=${#shard_nodes[@]}

for (( i=0; i<$shards_count-1; i++ ))
do
    db_url+="jdbc:postgresql://${shard_nodes[$i]}:$port/ycsb;"
done
db_url+="jdbc:postgresql://${shard_nodes[$i]}:$port/ycsb"

db_conf="# Properties file that contains database connection information.
db.driver=org.postgresql.Driver
db.url=$db_url
db.user=postgres
db.passwd=postgres
db.batchsize=$b_size
jdbc.fetchsize=$f_size
jdbc.batchupdateapi=true
jdbc.autocommit=false
"

# db_conf="# Properties file that contains database connection information.
# db.driver=org.postgresql.Driver
# db.url=jdbc:postgresql://$node_ip:5432/ycsb?reWriteBatchedInserts=true
# db.user=postgres
# db.passwd=postgres
# db.batchsize=$b_size
# jdbc.fetchsize=$f_size
# jdbc.batchupdateapi=true
# jdbc.autocommit=false
# "

# db_conf="# Properties file that contains database connection information.
# db.driver=org.postgresql.Driver
# db.url=jdbc:postgresql://$node_ip:5432/ycsb?reWriteBatchedInserts=true
# db.user=postgres
# db.passwd=postgres
# db.batchsize=$b_size
# jdbc.batchupdateapi=true
# "

rm $JDBC_HOME/conf/db.properties
echo -e "$db_conf" > $JDBC_HOME/conf/db.properties

echo "[LOAD Script] Call shard_table.sh script to create usertable sharded"
/scripts/shard_table.sh postgres postgres $node_ip $shards_count
# echo "[LOAD Script] Wait 2 min until cluster state stabilizes..."
# sleep 120

echo "[LOAD Script] Performing load..."
$YCSB_HOME/bin/ycsb load jdbc -s -P $YCSB_HOME/workloads/workload$workload -P $JDBC_HOME/conf/db.properties -cp $CLASSPATH -p recordcount=$recordcount -p operationcount=10000 > /ycsb_outputs/postgres-out-load-$shards_count-$recordcount-$workload-bs$b_size-fs$f_size.txt 2>&1

chmod 777 /ycsb_outputs/postgres-out-load-$shards_count-$recordcount-$workload-bs$b_size-fs$f_size.txt

echo "[LOAD Script] Load finished!"
