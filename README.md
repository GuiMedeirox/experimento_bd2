experimento massa envolvendo mongodb e escalabilidade horizontal, vai dar pra ver como fica filé usar sharding e nao sobrecarregar o humilde banco com 1 milhao de requisicoes

## Pré-requisitos

* Docker e Docker Compose instalados
* Python 3.8+ com pacotes: `pymongo`, `faker`
* Terminal / CLI (Linux, macOS, Windows WSL)

---

## Arquivos fornecidos

| Arquivo                 | Descrição                                                    |
| ----------------------- | ------------------------------------------------------------ |
| `docker-compose.yml`    | Configuração do cluster sharded + Mongo single para baseline |
| `init_mongo_cluster.sh` | Script para configurar automaticamente o cluster sharded     |
| `load_mongo_sharded.py` | Script Python para gerar carga massiva no MongoDB            |
| `metrics.sh`            | Script para coletar métricas dos testes (single e sharded)   |

---

## Passo a passo para rodar o experimento

### 1. Subir todos os containers

```bash
docker-compose up -d
```

Isso sobe o cluster sharded (config servers, shards e mongos) e também um MongoDB standalone (single) para comparação.

---

### 2. Inicializar o cluster sharded

```bash
bash init_mongo_cluster.sh
```

Esse script:

* Inicia os replica sets dos config servers e shards
* Configura o `mongos` com os shards
* Habilita o sharding na base `experimento` e coleção `registros`

---

### 3. Rodar teste baseline no Mongo single

```bash
bash metrics.sh single
```

Isso:

* Insere documentos no Mongo standalone (`mongo_single`, porta 27027)
* Coleta métricas básicas (throughput, uso de CPU/memória, etc.)

---

### 4. Rodar teste no cluster sharded

```bash
bash metrics.sh sharded
```

Isso:

* Insere documentos via `mongos` (porta 27017)
* Coleta métricas similares para comparação

---

### 5. Analisar resultados

Os logs gerados estarão na pasta atual:

| Arquivo                 | Conteúdo                           |
| ----------------------- | ---------------------------------- |
| `insert_single.log`     | Throughput inserção (single)       |
| `insert_sharded.log`    | Throughput inserção (sharded)      |
| `stat_single.json`      | Estatísticas do Mongo standalone   |
| `stat_sharded.json`     | Estatísticas do Mongo cluster      |
| `resources_single.txt`  | Uso CPU/memória containers single  |
| `resources_sharded.txt` | Uso CPU/memória containers sharded |
| `chunks_sharded.txt`    | Distribuição de chunks no cluster  |

Você pode abrir esses arquivos em editores de texto ou importar para planilhas para comparar métricas.

---

## Dicas finais

* Recomendamos testar com diferentes volumes de dados alterando o parâmetro `--total` em `metrics.sh`.
* Se quiser mais detalhamento, ajuste o script Python para medir latência de leitura.
* Para limpar os dados e recomeçar, basta parar os containers, remover volumes e subir novamente.


