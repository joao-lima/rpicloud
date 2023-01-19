#!/bin/bash

coordinator_ip=$1
workload=$2
recordcount=$3
workers_count=$4
exe=$5
r_factor=$6
b_size=$7
f_size=$8
commutative=$9

################### USED ONLY FOR CALIBRATION #######################

DATABASE="ycsb"
PG_PASS="postgres"
PG_USER="postgres"

# Auxiliary functions
execute_query(){
    local query=$1
    local host=$2
    PGPASSWORD=$PG_PASS psql -h $host \
                             -U $PG_USER \
                             -d $DATABASE \
                             -c "$query"
}

SQL_SET_FETCH="\
    ALTER DATABASE $DATABASE 
    SET citus.limit_clause_row_fetch_count TO $f_size;"

SQL_SET_COMMUTATIVE="\
    ALTER DATABASE $DATABASE 
    SET citus.all_modifications_commutative TO on;"


# Set the fetch size to the database
echo "Setting the fetch size = $f_size to database"
execute_query "$SQL_SET_FETCH" $coordinator_ip


if [ $commutative = "on" ]
then
    # Enable commutativity in all queries
    echo "Enable commutativity in all queries"
    execute_query "$SQL_SET_COMMUTATIVE" $coordinator_ip
fi
####################################################################


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

echo "[RUN Script] workers_count:$workers_count workload:$workload recordcount:$recordcount exec:$exe"

$YCSB_HOME/bin/ycsb run jdbc -s \
-P $YCSB_HOME/workloads/workload$workload \
-P $JDBC_HOME/conf/db.properties \
-cp $CLASSPATH \
-p recordcount=$recordcount \
-p operationcount=10000 \
> /ycsb_outputs/citus-out-$workers_count-$recordcount-$workload-$exe-rf$r_factor-bs$b_size-fs$f_size-commutative-$commutative.txt 2>&1

chmod 777 /ycsb_outputs/citus-out-$workers_count-$recordcount-$workload-$exe-rf$r_factor-bs$b_size-fs$f_size-commutative-$commutative.txt

echo "[RUN Script] Finished!"