# Cluster Kubernetes Raspberry Pi 4

## Arquitetura

O cluster tem 15 nós no total:
- 1 nós de acesso rpicloud (16.0.0.10) que está no cluster. A pasta do usuário `pi` está em um disco SSD de 1TB. Este tem 4GB de RAM.
- 14 nós de processamento do master rpi01 (16.0.0.11) até o rpi14 (16.0.0.24). Cada um tem um disco SSD 1TB na pasta `/mnt/storage`. Os nós tem 2GB de RAM.

O nó de acesso é o `rpicloud`:
```
$ ssh pi@rpicloud
```

O nó `rpicloud` acessa qualquer nó por SSH e tem acesso ao cluster pelo comando `kubectl`:
```
pi@rpicloud:~ $ kubectl get nodes
NAME       STATUS     ROLES                  AGE     VERSION
rpi14      NotReady   <none>                 4d14h   v1.25.4+k3s1
rpi02      Ready      <none>                 4d14h   v1.25.4+k3s1
rpi03      Ready      <none>                 4d14h   v1.25.4+k3s1
rpi10      Ready      <none>                 4d14h   v1.25.4+k3s1
rpi08      Ready      <none>                 4d14h   v1.25.4+k3s1
rpicloud   Ready      <none>                 20h     v1.25.5+k3s2
rpi01      Ready      control-plane,master   6d2h    v1.25.4+k3s1
rpi07      Ready      <none>                 4d14h   v1.25.4+k3s1
rpi05      Ready      <none>                 3d16h   v1.25.4+k3s1
rpi06      Ready      <none>                 4d14h   v1.25.4+k3s1
rpi12      Ready      <none>                 4d14h   v1.25.4+k3s1
rpi11      Ready      <none>                 4d14h   v1.25.4+k3s1
rpi13      Ready      <none>                 4d14h   v1.25.4+k3s1
rpi09      Ready      <none>                 4d14h   v1.25.4+k3s1
rpi04      Ready      <none>                 4d14h   v1.25.4+k3s1
```

## Dashboard

O [dashboard](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/) está acessível localmente no cluster. Primeiro, é preciso criar um proxy para acessar no `rpicloud`:
```
pi@rpicloud:~ $ kubectl proxy
Starting to serve on 127.0.0.1:8001
```
Depois precisamos criar uma ponte SSH para o host local com:
```
$ ssh -L 8001:127.0.0.1:8001 pi@rpicloud 
```
O dashboard fica no endereço http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/ onde precisamos de um token de acesso criado com o comando:
```
pi@rpicloud:~ $ kubectl -n kubernetes-dashboard create token admin-user
```


## Cassandra cluster

O [cluster Cassandra](https://kubernetes.io/docs/tutorials/stateful-application/cassandra/) 

Primeiro é preciso criar um serviço *headless* [cassandra-service.yaml](./cassandra/cassandra-service.yaml) para criar os pods de execução:
```
apiVersion: v1
kind: Service
metadata:
  labels:
    app: cassandra
  name: cassandra
spec:
  clusterIP: None
  ports:
  - port: 9042
  selector:
    app: cassandra
```

O comando para o serviço é:
```
pi@rpicloud:~ $ kubectl apply -f cassandra/cassandra-service.yaml 
```

Em seguida, o arquivo [cassandra-statefulset.yaml](./cassandra/cassandra-statefulset.yaml) criar os pods do Cassandra:
```
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: cassandra
  labels:
    app: cassandra
spec:
  serviceName: cassandra
  replicas: 13
  selector:
    matchLabels:
      app: cassandra
  template:
    metadata:
      labels:
        app: cassandra
    spec:
      terminationGracePeriodSeconds: 1800
      containers:
      - name: cassandra
        image: cassandra:4
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 7000
          name: intra-node
        - containerPort: 7001
          name: tls-intra-node
        - containerPort: 7199
          name: jmx
        - containerPort: 9042
          name: cql
        securityContext:
          capabilities:
            add:
              - IPC_LOCK
        lifecycle:
          preStop:
            exec:
              command: 
              - /bin/sh
              - -c
              - nodetool drain
        env:
          - name: MAX_HEAP_SIZE
            value: 512M
          - name: HEAP_NEWSIZE
            value: 100M
          - name: CASSANDRA_SEEDS
            value: "cassandra-0.cassandra.default.svc.cluster.local"
          - name: CASSANDRA_CLUSTER_NAME
            value: "K8Demo"
          - name: CASSANDRA_DC
            value: "DC1-K8Demo"
          - name: CASSANDRA_RACK
            value: "Rack1-K8Demo"
          - name: POD_IP
            valueFrom:
              fieldRef:
                fieldPath: status.podIP
        readinessProbe:
          exec:
            command:
              - /bin/bash
              - -c 
              - 'if [[ $(nodetool status | grep $POD_IP) == *"UN"* ]]; then exit 0; else exit 1; fi'
          initialDelaySeconds: 60
          timeoutSeconds: 60
        # These volume mounts are persistent. They are like inline claims,
        # but not exactly because the names need to match exactly one of
        # the stateful pod golumes.
        volumeMounts:
        - name: cassandra-data
          mountPath: /var/lib/cassandra
  # These are converted to volume claims by the controller
  # and mounted at the paths mentioned above.
  # do not use these in production until ssd GCEPersistentDisk or other ssd pd
  volumeClaimTemplates:
  - metadata:
      name: cassandra-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: local-path
      resources:
        requests:
          storage: 128Gi
```


O pod `cassandra-0.cassandra.default.svc.cluster.local` é o *seed* do cluster Cassandra responsável por iniciar o [protocolo de anel](https://cassandra.apache.org/_/glossary.html) dentro do cluster.

O comando dos pods é:
```
pi@rpicloud:~ $ kubectl create -f cassandra/cassandra-statefulset.yaml
```

Verifique o estado dos pods:
```
pi@rpicloud:~ $ kubectl get pods -l="app=cassandra"
NAME           READY   STATUS    RESTARTS   AGE
cassandra-0    1/1     Running   0          70m
cassandra-1    1/1     Running   0          69m
cassandra-2    1/1     Running   0          67m
cassandra-3    1/1     Running   0          66m
cassandra-4    1/1     Running   0          64m
cassandra-5    1/1     Running   0          63m
cassandra-6    1/1     Running   0          61m
cassandra-7    1/1     Running   0          60m
cassandra-8    1/1     Running   0          58m
cassandra-9    1/1     Running   0          56m
cassandra-10   1/1     Running   0          55m
cassandra-11   1/1     Running   0          53m
cassandra-12   1/1     Running   0          51m
```
E quantos pods foram criados:
```
pi@rpicloud:~ $ kubectl get statefulset cassandra
NAME        READY   AGE
cassandra   13/13   14m
```

Também verifique o estado do cluster Cassandra com:
```
pi@rpicloud:~ $ kubectl exec -it cassandra-0 -- nodetool status
Datacenter: datacenter1
=======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address      Load        Tokens  Owns (effective)  Host ID                               Rack 
UN  10.42.21.26  165.1 KiB   16      15.2%             0ab13a52-9b06-406b-b6b4-e40c741550af  rack1
UN  10.42.15.23  132.07 KiB  16      15.8%             3f70234a-a0af-4fb0-89fe-98dd171f83df  rack1
UN  10.42.23.20  70.24 KiB   16      16.0%             9f4a580f-c14d-4bb0-8a32-bf5c208444f4  rack1
UN  10.42.19.27  131.96 KiB  16      16.1%             99056488-4726-4fb7-ae17-b02442714673  rack1
UN  10.42.1.25   70.25 KiB   16      15.8%             9556c5c6-516b-41bf-b6b6-433cd576f0bc  rack1
UN  10.42.24.23  70.23 KiB   16      16.0%             9411c879-b3ed-4ff8-bd32-cbeb9d6ff32a  rack1
UN  10.42.22.33  131.97 KiB  16      15.9%             707f27d2-b106-4bea-be87-21bc4be13a9e  rack1
UN  10.42.14.20  70.23 KiB   16      15.4%             79ffc760-6469-4e9c-ad3f-3ee7f2ff602f  rack1
UN  10.42.17.23  70.23 KiB   16      14.3%             4c0cd6f7-1d99-4026-b49d-ca1285f5a6a4  rack1
UN  10.42.20.20  137.25 KiB  16      14.0%             4a9b72bf-39ac-4d60-b32b-a7e0701c9cc6  rack1
UN  10.42.0.36   70.25 KiB   16      15.2%             bc3c133b-49fa-4b3e-9a77-6df97ed9695f  rack1
UN  10.42.16.20  70.25 KiB   16      15.3%             318c4e08-a814-4a31-84ff-2312b22451a4  rack1
UN  10.42.18.26  137.5 KiB   16      14.9%             6ea118bc-d38d-4be5-8c75-35d501edda7f  rack1
```

A remoção dos pods pode ser feita pelo comando:
```
kubectl delete -f cassandra/cassandra-statefulset.yaml
```
Para remover os volumes de armazenamento criados pelo Cassandra:
```
pi@rpicloud:~ $ kubectl delete persistentvolumeclaim -l app=cassandra
```

Se precisar dos IPs no cluster:
```
pi@rpicloud:~ $ kubectl get pods --output=wide
NAME             READY   STATUS    RESTARTS   AGE    IP            NODE       NOMINATED NODE   READINESS GATES
ycsb-benchmark   1/1     Running   0          116m   10.42.2.38    rpicloud   <none>           <none>
cassandra-0      1/1     Running   0          68m    10.42.21.26   rpi10      <none>           <none>
cassandra-1      1/1     Running   0          67m    10.42.20.20   rpi09      <none>           <none>
cassandra-2      1/1     Running   0          65m    10.42.22.33   rpi11      <none>           <none>
cassandra-3      1/1     Running   0          64m    10.42.18.26   rpi07      <none>           <none>
cassandra-4      1/1     Running   0          62m    10.42.15.23   rpi03      <none>           <none>
cassandra-5      1/1     Running   0          61m    10.42.19.27   rpi08      <none>           <none>
cassandra-6      1/1     Running   0          59m    10.42.14.20   rpi02      <none>           <none>
cassandra-7      1/1     Running   0          57m    10.42.24.23   rpi13      <none>           <none>
cassandra-8      1/1     Running   0          56m    10.42.17.23   rpi06      <none>           <none>
cassandra-9      1/1     Running   0          54m    10.42.1.25    rpi05      <none>           <none>
cassandra-10     1/1     Running   0          53m    10.42.23.20   rpi12      <none>           <none>
cassandra-11     1/1     Running   0          51m    10.42.16.20   rpi04      <none>           <none>
cassandra-12     1/1     Running   0          49m    10.42.0.36    rpi01      <none>           <none>

```

Se ainda ficou na dúvida com relação o que acontece no pod use o comando para ver o log:
```
pi@rpicloud:~ $ kubectl get logs cassandra-12
```

## Imagens Docker customizadas

Kubernetes é compatível com imagens Docker mas é precisa alguns passos para usar uma imagem criada localmente com Docker. Por exemplo, a imagem do benchmark usado foi criada do arquivo [Dockerfile](./ycsb/Docker/Dockerfile)
```
pi@rpicloud:~ $ docker build -t ycsb-benchmark  ./ycsb/Docker
```

O cluster tem um container Docker de imagens para servir as imagens ao Kubernetes descrito em [k3s-docker_docker-compose-registry.yaml](./registry/k3s-docker_docker-compose-registry.yaml):
```
version: '3'
services:
  registry.local:
    image: "registry:2"
    ports:
    - 5000:5000
```

O comando executado foi:
```
pi@rpicloud:~ $ docker-compose -f ./registry/k3s-docker_docker-compose-registry.yaml up -d
```

O nó precisa de configurações do arquivo `/etc/docker/daemon.json`:
```
{
        "allow-nondistributable-artifacts": ["127.0.0.1:5000"],
        "insecure-registries" : [ "127.0.0.1:5000" ]
}
```

Basta reiniciar o Docker:
```
pi@rpicloud:~ $ sudo systemctl restart docker
```

Por fim registramos a imagem local no container Docker de imagens:
```
pi@rpicloud:~ $ docker tag ycsb-benchmark 127.0.0.1:5000/ycsb-benchmark
pi@rpicloud:~ $ docker push 127.0.0.1:5000/ycsb-benchmark
```

O teste para verificar se a imagem existe localmente é rodar um pod:
```
pi@rpicloud:~ $ kubectl run bench -i --tty --rm --image 127.0.0.1:5000/ycsb-benchmark -- bash
If you don't see a command prompt, try pressing enter.
root@bench:/# 
```

Não é possível montar diretórios com o comando `kubectl`. Portanto, olhe a seção sobre rodar o benchmark YCSB para detalhes.

## Benchmark YCSB

O trabalho tem um [repositório original](https://github.com/lucas-fs/YCSB_Benchmark_Docker) com as instruções em Docker. Para rodar o benchmark, vamos criar uma imagem Docker e rodar no cluster Kubernetes.

O arquivo [benchmark.yml](./ycsb/benchmark.yml) cria um pod para rodar os benchmark. A linha `nodeName` restringe o pod no nó local `rpicloud` e faz com que fique fora do cluster de teste.
```
apiVersion: v1
kind: Pod
metadata:
  name: ycsb-benchmark
  labels:
    name: ycsb-benchmark
spec:
  nodeName: rpicloud
  containers:
    - image: 127.0.0.1:5000/ycsb-benchmark
      name: ycsb-benchmark
      volumeMounts:
      - mountPath: /ycsb_outputs
        name: output
      - mountPath: /scripts
        name: scripts
      imagePullPolicy: Never
      command: [ "sleep" ]
      args: [ "infinity" ]
      resources:
        requests:
          memory: "3Gi"
  restartPolicy: Never
  volumes:
  - name: scripts
    hostPath:
      path: /home/pi/ycsb/scripts
      type: Directory
  - name: output
    hostPath:
      path: /home/pi/ycsb/out
      type: Directory
```
Esse pod irá rodar no nó `rpicloud`:
```
pi@rpicloud:~ $ kubectl create -f benchmark.yml
```

Abra um terminal dentro do pod:
```
pi@rpicloud:~/ycsb $ kubectl exec -i --tty ycsb-benchmark  -- bash
root@ycsb-benchmark:/#
```

Basta carregar os dados para um workload específico. Por exemplo, conectar no seed `cassandra-0.cassandra.default.svc.cluster.local` para carregar o workload `a`, `100000` registros, `13` nós e `3` replicas:
```
root@ycsb-benchmark:/# /scripts/cassandra_load.sh cassandra-0.cassandra.default.svc.cluster.local a 100000 13 3
```

Verifique a execução olhando para os dados da tabela criada especialmente o campo `Space used`:
```
pi@rpicloud:~ $ kubectl exec -it cassandra-0 -- nodetool cfstats -- ycsb.usertable
Total number of tables: 45
----------------
Keyspace : ycsb
        Read Count: 0
        Read Latency: NaN ms
        Write Count: 22662
        Write Latency: 0.0746256729326626 ms
        Pending Flushes: 0
                Table: usertable
                SSTable count: 1
                Old SSTable count: 0
                Space used (live): 20419481
                Space used (total): 20419481
                Space used by snapshots (total): 0
                Off heap memory used (total): 38238
                SSTable Compression Ratio: 0.9938585064328254
                Number of partitions (estimate): 22661
                Memtable cell count: 3960
                Memtable data size: 4708440
                Memtable off heap memory used: 0
                Memtable switch count: 1
                Local read count: 0
                Local read latency: NaN ms
                Local write count: 22662
                Local write latency: 0.070 ms
                Pending flushes: 0
                Percent repaired: 0.0
                Bytes repaired: 0.000KiB
                Bytes unrepaired: 19.012MiB
                Bytes pending repair: 0.000KiB
                Bloom filter false positives: 0
                Bloom filter false ratio: 0.00000
                Bloom filter space used: 23392
                Bloom filter off heap memory used: 23384
                Index summary off heap memory used: 5118
                Compression metadata off heap memory used: 9736
                Compacted partition minimum bytes: 925
                Compacted partition maximum bytes: 1109
                Compacted partition mean bytes: 1109
                Average live cells per slice (last five minutes): NaN
                Maximum live cells per slice (last five minutes): 0
                Average tombstones per slice (last five minutes): NaN
                Maximum tombstones per slice (last five minutes): 0
                Dropped Mutations: 0
                Droppable tombstone ratio: 0.00000

----------------
```
Ou os logs de execução do carregamento:
```
pi@rpicloud:~ $ cat ycsb/out/out-load-13-100000-rf3-a.txt 
```

A  execução do benchmark para medidas pode ser por exemplo:
```
root@ycsb-benchmark:/# /scripts/cassandra_run.sh cassandra-0.cassandra.default.svc.cluster.local a 100000 13 1 3
root@ycsb-benchmark:/# /scripts/cassandra_run.sh cassandra-0.cassandra.default.svc.cluster.local a 100000 13 2 3
```
Onde o penúltimo argumento é o número da repetição salvo no arquivo:
```
pi@rpicloud:~ $ cat ycsb/out/out-13-100000-rf3-a-1.txt 
```

## Storage

O cluster usa o [Local Path Provisioner](https://github.com/rancher/local-path-provisioner) para criar pastas locais em cada nó do cluster. Caso contrário, seria preciso criar uma pasta para cada nó.

O arquivo [local-path-storage.yaml](./storage/local-path-storage.yaml) cria o serviço de armazenamento no k3s.

O exemplo abaixo ([teste-pod.yaml](./storage/teste-pod.yaml)) cria um volume persistente:
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-path-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 128Mi
```
Um exemplo de pod ([teste-pod.yaml](./storage/teste-pod.yaml)) que usa esse armazenamento:
```
apiVersion: v1
kind: Pod
metadata:
  name: volume-test
spec:
  containers:
  - name: volume-test
    image: nginx:stable-alpine
    imagePullPolicy: IfNotPresent
    volumeMounts:
    - name: volv
      mountPath: /data
    ports:
    - containerPort: 80
  volumes:
  - name: volv
    persistentVolumeClaim:
      claimName: local-path-pvc
```
O armazenamento será criado em cada nó físico que o pod executar.

