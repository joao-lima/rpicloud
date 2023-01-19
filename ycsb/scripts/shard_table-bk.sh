#!/bin/bash

execute_query(){
    local query=$1
    local host=$2
    PGPASSWORD=$PG_PASS psql -h $host \
                             -U $PG_USER \
                             -d $DATABASE \
                             -c "$query"
}

PG_USER=$1
PG_PASS=$2
MASTER_IP=$3
NODE_COUNT=$4

DATABASE="ycsb"
TABLE_NAME="usertable"
SHARD_SERVICE="shard"

echo "Executing shard_table script..."

SQL_DROP="DROP TABLE IF EXISTS $TABLE_NAME;"

SQL_CREATE_TABLE="\
    CREATE TABLE $TABLE_NAME(
    YCSB_KEY VARCHAR (255),
    FIELD0 TEXT, FIELD1 TEXT,
    FIELD2 TEXT, FIELD3 TEXT,
    FIELD4 TEXT, FIELD5 TEXT,
    FIELD6 TEXT, FIELD7 TEXT,
    FIELD8 TEXT, FIELD9 TEXT) 
    PARTITION BY HASH (YCSB_KEY);"


MASTER_SHARD_NAME=$TABLE_NAME"_shard_00"
SQL_MASTER_SHARD="\
    CREATE TABLE $MASTER_SHARD_NAME 
    PARTITION OF $TABLE_NAME 
    FOR VALUES WITH (modulus $NODE_COUNT, remainder 0);"

# Drop usertable if exists
echo "Drop usertable if exists on MASTER node [ $MASTER_IP ]"
execute_query "$SQL_DROP" $MASTER_IP

# Create patitioned usertable
echo "Create patitioned usertable on MASTER node [ $MASTER_IP ]"
execute_query "$SQL_CREATE_TABLE" $MASTER_IP

# Create Master shard
echo "Create Master shard table on MASTER node [ $MASTER_IP ]"
execute_query "$SQL_MASTER_SHARD" $MASTER_IP

tasks_ips=( `getent hosts tasks.$SHARD_SERVICE | awk '{print $1}'` )
echo "Shard nodes IP list:"
getent hosts tasks.$SHARD_SERVICE | awk '{print $1}'

shard_n=0
for ip in "${tasks_ips[@]}"
do
    ((shard_n++))

    SQL_GET_SHARD="\
        SELECT replace(srvname, 'shard_', '') as name 
        FROM pg_foreign_server 
        WHERE srvname not like '%master%' 
            AND srvoptions[2] = 'host=$ip';"
    
    query_result=$(execute_query "$SQL_GET_SHARD" $MASTER_IP | grep '^ [0-9]')
    shard=${query_result//[[:blank:]]/}

    NODE_SHARD_NAME=$TABLE_NAME"_shard_"$shard
    SQL_DROP_SHARD="DROP TABLE IF EXISTS $NODE_SHARD_NAME;"
    SQL_NODE_SHARD="\
        CREATE TABLE $NODE_SHARD_NAME(
        YCSB_KEY VARCHAR (255),
        FIELD0 TEXT, FIELD1 TEXT,
        FIELD2 TEXT, FIELD3 TEXT,
        FIELD4 TEXT, FIELD5 TEXT,
        FIELD6 TEXT, FIELD7 TEXT,
        FIELD8 TEXT, FIELD9 TEXT);"

    echo "Drop shard table on SHARD node [ $ip ]"
    execute_query "$SQL_DROP_SHARD" $ip

    echo "Create shard table on SHARD node [ $ip ]"
    execute_query "$SQL_NODE_SHARD" $ip

    SQL_DROP_FT="DROP FOREIGN TABLE IF EXISTS $NODE_SHARD_NAME;"
    SQL_FOREIGN_TABLE="\
        CREATE FOREIGN TABLE $NODE_SHARD_NAME 
        PARTITION OF $TABLE_NAME 
        FOR VALUES WITH (modulus $NODE_COUNT, remainder $shard_n) 
        SERVER shard_$shard;"

    echo "Drop foreign table [ $NODE_SHARD_NAME ] on MASTER node [ $MASTER_IP ]"
    execute_query "$SQL_DROP_FT" $MASTER_IP
    
    echo "Create foreign table [ $NODE_SHARD_NAME ] on MASTER node [ $MASTER_IP ]"
    execute_query "$SQL_FOREIGN_TABLE" $MASTER_IP

done
