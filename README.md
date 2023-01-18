# Cluster Kubernetes Raspberry Pi 4

## Storage

Usa o [Local Path Provisioner](https://github.com/rancher/local-path-provisioner) para criar pastas locais em cada nó do cluster. Caso contrário, seria preciso criar uma pasta para cada nó.

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