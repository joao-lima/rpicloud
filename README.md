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