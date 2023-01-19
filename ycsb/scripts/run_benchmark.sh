#!/bin/bash

# workload from where data will be load
dataload=a
taskwait=70

for replicas in 1 2 4 6
do
    for rcount in 1000
    do
        # rm cassandra stack
        echo "[Run Benchmark] Removing cassandra stack..."
        docker stack rm cassandra

        # clear cassandra diretories
        echo "[Run Benchmark] Cleaning up cassandra storage directories..."
        ~/pi-cluster/cls_cassandra.sh

        # sleep 2 min
        echo "[Run Benchmark] Pause to stabilize cluster..."
        sleep 60

        echo "[Run Benchmark] Deploy new cassandra stack with $replicas replicas..."
        if [ $replicas -eq 1 ]
        then
            # deploy cassandra stack
            docker stack deploy -c docker-compose-seed.yml cassandra

        elif [ $replicas -eq 2 ]
        then
            # deploy cassandra stack
            docker stack deploy -c docker-compose.yml cassandra

        else
            # deploy cassandra stack
            docker stack deploy -c docker-compose.yml cassandra
            # scale cassandra stack
            echo "[Run Benchmark] Scaling cassandra nodes..."
            docker service scale cassandra_node=$(($replicas-1))
        fi
        # wait until cluster stabilizes
        echo "[Run Benchmark] Waiting until cluster state stabilizes..."
        sleep $((($taskwait * $replicas) + 60))
        
        echo "[Load Script] Getting a node ip..."
        node_ip=`docker container exec -t ycsb getent hosts tasks.seed | awk '{print $1}'| head -n 1`
        echo "[Load Script] Node ip: $node_ip"

        # run load script on container
        echo "[Run Benchmark] Executing load script..."
        docker container exec ycsb ./load.sh $node_ip $dataload $rcount $replicas
        echo "[Run Benchmark] Pause to stabilize cluster..."
        sleep 60

        for wload in a b c d
        do
            for exe in {1..10}
            do
            	echo "[Run Benchmark] Executing the run script for workload ( $wload )..."
            	docker container exec ycsb ./execute.sh $node_ip $wload $rcount $replicas $exe
                sleep 3
            done
            echo "[Run Benchmark] Pause to stabilize cluster..."
            sleep 60
        done
    done
done
echo "[Run Benchmark] Benchmark execution completed!"
