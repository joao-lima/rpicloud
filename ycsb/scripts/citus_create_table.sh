#!/bin/bash

# Config variables
PG_USER=$1
PG_PASS=$2
COORDINATOR_IP=$3
WORKERS_COUNT=$4
REPLICATION=$5
F_SIZE=$6

DATABASE="ycsb"
TABLE_NAME="usertable"
TABLE_PK="ycsb_key"

# Auxiliary functions
execute_query(){
    local query=$1
    local host=$2
    PGPASSWORD=$PG_PASS psql -h $host \
                             -U $PG_USER \
                             -d $DATABASE \
                             -c "$query"
}

# === SQL Queries === #

SQL_GET_WORKERS="\
    SELECT node_name FROM citus_get_active_worker_nodes();"

SQL_SET_COMMUTATIVE="\
    ALTER DATABASE $DATABASE 
    SET citus.all_modifications_commutative TO on;"

SQL_SET_REPLICATION="\
    ALTER DATABASE $DATABASE 
    SET citus.shard_replication_factor = $REPLICATION;"

SQL_SET_FETCH="\
    ALTER DATABASE $DATABASE 
    SET citus.limit_clause_row_fetch_count TO $F_SIZE;"

SQL_DROP="DROP TABLE IF EXISTS $TABLE_NAME;"

SQL_CREATE_TABLE="\
    CREATE TABLE $TABLE_NAME(
    YCSB_KEY VARCHAR (255),
    FIELD0 TEXT, FIELD1 TEXT,
    FIELD2 TEXT, FIELD3 TEXT,
    FIELD4 TEXT, FIELD5 TEXT,
    FIELD6 TEXT, FIELD7 TEXT,
    FIELD8 TEXT, FIELD9 TEXT
    );"

SQL_DISTRIBUTED_TABLE="\
    SELECT create_distributed_table('$TABLE_NAME', '$TABLE_PK');"

# === Start script === #

echo "Executing citus_create_table script..."

# Make sure that all worker nodes are active in cluster
echo "Wait until all $WORKERS_COUNT worker nodes be active in cluster"

active_workers=$(execute_query "$SQL_GET_WORKERS" $COORDINATOR_IP | grep row | tr -cd '[[:digit:]]')

while [[ "$active_workers" != "$WORKERS_COUNT" ]]
do
    active_workers=$(execute_query "$SQL_GET_WORKERS" $COORDINATOR_IP | grep row | tr -cd '[[:digit:]]')
    echo "Currently active workers = $active_workers"
    sleep 2
done
echo "Active workers = $active_workers -> expected workers count = $WORKERS_COUNT"

echo "Wait 2 minutes before start queries" 
sleep 120

# Set the replication factor to the database
echo "Setting the replication factor to database"
execute_query "$SQL_SET_REPLICATION" $COORDINATOR_IP

# # Enable commutativity in all queries
# echo "Enable commutativity in all queries"
# execute_query "$SQL_SET_COMMUTATIVE" $COORDINATOR_IP

# Set the fetch size to the database
echo "Setting the fetch size to database"
execute_query "$SQL_SET_FETCH" $COORDINATOR_IP

# Drop usertable if exists
echo "Drop usertable if exists"
execute_query "$SQL_DROP" $COORDINATOR_IP

# Create patitioned usertable
echo "Create usertable"
execute_query "$SQL_CREATE_TABLE" $COORDINATOR_IP

# Create the distributed table
echo "Create the distributed table"
execute_query "$SQL_DISTRIBUTED_TABLE" $COORDINATOR_IP

