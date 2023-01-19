#!/bin/bash

docker run --name ycsb --network=citus-net -v /home/lferreira/Dropbox/YCSB-outputs:/ycsb_outputs -v /home/lferreira/Repositórios/YCSB_Benchmark_Docker/scripts:/scripts -v /home/lferreira/Repositórios/YCSB_Benchmark_Docker/hbase-conf/hbase-site.xml:/opt/hbase-2.2.7-client/conf/hbase-site.xml -dt lucasfs/ycsb-benchmark bash
