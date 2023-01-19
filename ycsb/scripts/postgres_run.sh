#!/bin/bash

node_ip=$1
workload=$2
recordcount=$3
replicas=$4
exe=$5
b_size=$6
f_size=$7

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
sleep 10

echo "[RUN Script] shards_count:$shards_count workload:$workload recordcount:$recordcount exec:$exe"
$YCSB_HOME/bin/ycsb run jdbc -s -P $YCSB_HOME/workloads/workload$workload -P $JDBC_HOME/conf/db.properties -cp $CLASSPATH -p recordcount=$recordcount -p operationcount=10000 > /ycsb_outputs/postgres-out-$shards_count-$recordcount-$workload-$exe-bs$b_size-fs$f_size.txt 2>&1
chmod 777 /ycsb_outputs/postgres-out-$shards_count-$recordcount-$workload-$exe-bs$b_size-fs$f_size.txt

echo "[RUN Script] Finished!"