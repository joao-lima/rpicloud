/* main table schema */
CREATE TABLE pessoa(
    id_pessoa SERIAL NOT NULL,
    nome TEXT
) PARTITION BY HASH (id_pessoa);

/* master shard */
CREATE TABLE pessoa_shard_01 PARTITION OF pessoa FOR VALUES WITH (modulus 2, remainder 0));

/* shard servers (workers) */
CREATE TABLE pessoa_shard_02(
    id_pessoa INTEGER NOT NULL,
    nome TEXT
);