#!/bin/bash

#TODO: Ajustar remoção das foreign tables
node_ip=$1
workload=$2
recordcount=$3
replicas=$4

db_conf="# Properties file that contains database connection information.

# jdbc.fetchsize=20
db.driver=org.postgresql.Driver
db.url=jdbc:postgresql://$node_ip:5432/ycsb
db.user=postgres
db.passwd=postgres
" 

rm $JDBC_HOME/conf/db.properties
echo -e "$db_conf" > $JDBC_HOME/conf/db.properties

echo "[LOAD Script] Dropping table usertable"
PGPASSWORD=postgres psql -h $node_ip -U postgres -d ycsb -c "DROP TABLE IF EXISTS usertable;"

sleep 5 

echo "[LOAD Script] Recreating table usertable"
java -cp $JDBC_HOME/lib/jdbc-binding-$YCSB_VERSION-SNAPSHOT.jar:$JDBC_HOME/lib/postgresql-42.2.14.jar site.ycsb.db.JdbcDBCreateTable -P $JDBC_HOME/conf/db.properties -n usertable

sleep 5

echo "[LOAD Script] Performing load..."
$YCSB_HOME/bin/ycsb load jdbc -s -P $YCSB_HOME/workloads/workload$workload -P $JDBC_HOME/conf/db.properties -cp $CLASSPATH -p recordcount=$recordcount -p operationcount=10000 > /ycsb_output/out-load-$replicas-$recordcount-$workload.txt 2>&1

chmod 777 /ycsb_output/out-load-$replicas-$recordcount-$workload.txt

echo "[LOAD Script] Load finished!"