#!/usr/bin/env bash
#
# init_mongo_cluster_fixed.sh
# ---------------------------
# Versão corrigida do script de inicialização do cluster sharded.
# Executa toda a configuração do cluster sharded definido no docker-compose.yml.
#
# Uso:
#   1) docker compose up -d
#   2) bash init_mongo_cluster_fixed.sh
#

set -euo pipefail

# Função utilitária para esperar um serviço Mongo responder ping
wait_for_mongo() {
  local container=$1
  local port=$2
  echo "⏳ Aguardando $container:$port ficar disponível..."
  until docker exec "$container" mongosh --quiet --port "$port" --eval "db.adminCommand('ping')" >/dev/null 2>&1; do
    sleep 2
  done
  echo "✅ $container está pronto."
}

# Função para verificar se replica set já está inicializado
is_replica_set_initialized() {
  local container=$1
  local port=$2
  docker exec "$container" mongosh --quiet --port "$port" --eval "rs.status().ok" 2>/dev/null || echo "false"
}

echo "🚀 Iniciando configuração do cluster MongoDB sharded..."

# 1. Espera Config Servers
echo "📋 Aguardando config servers..."
for cfg in cfg1 cfg2 cfg3; do
  wait_for_mongo "$cfg" 27019
done

# 2. Inicializa replica set dos Config Servers
echo "🔧 Inicializando replica set cfgRS..."
if [ "$(is_replica_set_initialized cfg1 27019)" != "true" ]; then
  echo "   Inicializando replica set dos config servers..."
  docker exec cfg1 mongosh --port 27019 --eval "
    rs.initiate({
      _id: 'cfgRS',
      configsvr: true,
      members: [
        { _id: 0, host: 'cfg1:27019' },
        { _id: 1, host: 'cfg2:27019' },
        { _id: 2, host: 'cfg3:27019' }
      ]
    })
  "
  echo "   Aguardando replica set dos config servers ficar pronto..."
  sleep 10
else
  echo "   ✅ Replica set cfgRS já está inicializado."
fi

# 3. Espera e inicializa shards
echo "📦 Configurando shards..."
for i in 1 2 3; do
  wait_for_mongo "shard${i}" 27018
  echo "   Inicializando replica set shard${i}RS..."
  if [ "$(is_replica_set_initialized shard${i} 27018)" != "true" ]; then
    docker exec "shard${i}" mongosh --port 27018 --eval "
      rs.initiate({
        _id: 'shard${i}RS',
        members: [{ _id: 0, host: 'shard${i}:27018' }]
      })
    "
    echo "   Aguardando replica set shard${i}RS ficar pronto..."
    sleep 5
  else
    echo "   ✅ Replica set shard${i}RS já está inicializado."
  fi
done

# 4. Aguarda mongos ficar disponível
echo "🌐 Aguardando mongos ficar disponível..."
wait_for_mongo "mongos" 27017

# 5. Adiciona shards e habilita sharding
echo "🔗 Configurando sharding..."
docker exec mongos mongosh --eval "
// Adiciona shards
const shards = [
  'shard1RS/shard1:27018',
  'shard2RS/shard2:27018', 
  'shard3RS/shard3:27018'
];

shards.forEach(shard => {
  try {
    sh.addShard(shard);
    print('✅ Shard adicionado: ' + shard);
  } catch (e) {
    if (e.message.includes('already exists')) {
      print('ℹ️  Shard já existe: ' + shard);
    } else {
      print('❌ Erro ao adicionar shard ' + shard + ': ' + e.message);
    }
  }
});

// Habilita sharding na database
try {
  sh.enableSharding('experimento');
  print('✅ Sharding habilitado na database experimento');
} catch (e) {
  if (e.message.includes('already enabled')) {
    print('ℹ️  Sharding já está habilitado na database experimento');
  } else {
    print('❌ Erro ao habilitar sharding: ' + e.message);
  }
}

// Sharda a coleção
try {
  sh.shardCollection('experimento.registros', { _id: 'hashed' });
  print('✅ Coleção experimento.registros shardada');
} catch (e) {
  if (e.message.includes('already sharded')) {
    print('ℹ️  Coleção experimento.registros já está shardada');
  } else {
    print('❌ Erro ao shardar coleção: ' + e.message);
  }
}

print('\\n📊 Status final do cluster:');
printjson(sh.status());
"

echo -e "\n🎉 Cluster sharded configurado com sucesso!"
echo "📝 Para conectar ao cluster: mongosh mongodb://localhost:27017"
echo "📝 Para conectar ao MongoDB single: mongosh mongodb://localhost:27027" 