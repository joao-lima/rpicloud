# Executar benchmarks no Cassandra com YCSB

### 1. Deploy da stack do Cassandra

### 2. Executar Docker container do YCSB

Conectar o container do YCSB na mesma rede de overlay que a stack do Cassandra está conectada

```
docker run --name ycsb --network=cassandra-net -dt lucasfs/ycsb-benchmark bash
```

### 3. Criar keyspace e a tabela para o benchmark

Para criar o keyspace `ycsb`, e a tabela `usertable`:

    cqlsh> create keyspace ycsb
        WITH REPLICATION = {'class' : 'SimpleStrategy', 'replication_factor': 3 };

    cqlsh> USE ycsb;

    cqlsh> create table usertable (
        y_id varchar primary key,
        field0 varchar,
        field1 varchar,
        field2 varchar,
        field3 varchar,
        field4 varchar,
        field5 varchar,
        field6 varchar,
        field7 varchar,
        field8 varchar,
        field9 varchar);

**Note que as configurações para `replication_factor` e os "`consistency levels`" afetam no desempenho do Cassandra.**

### 4. Load do datasset para o benchmark:

```
ycsb load cassandra-cql -s -p hosts="15.0.0.1" -P $YCSB_HOME/workloads/workloada -cp $CLASSPATH
```

Se as seguintes mensagens forem apresentadas:

```
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
```

Estão faltando alguns .jars dos quais o benchmark depende. 

Baixe a última versão estável do [slf](http://www.slf4j.org/download.html)
e copie os aquivos *slf4j-simple-1.7.7.jar* e *slf4j-api-1.7.7.jar* para o diretório do ycsb
e os inclua no parâmetro de classpath (-cp) no momento da execução.

```
ycsb load cassandra-cql -p hosts="15.0.0.1" -P workloads/workloada -cp $YCSB_HOME/slf4j-api-1.7.30.jar:$YCSB_HOME/slf4j-simple-1.7.30.jar
```

### 5. Execute o benchmark para os `workloads` desejados
