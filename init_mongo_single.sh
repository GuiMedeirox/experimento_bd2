#!/usr/bin/env bash
#
# init_mongo_single.sh
# -------------------
# Inicializa o replica set do MongoDB standalone (mongo_single)
#
# Uso:
#   1) docker compose up -d
#   2) bash init_mongo_single.sh
#

set -euo pipefail

echo "🚀 Inicializando replica set do MongoDB standalone..."

# Aguarda o MongoDB ficar disponível
echo "⏳ Aguardando mongo_single:27017 ficar disponível..."
until docker exec mongo_single mongosh --quiet --port 27017 --eval "db.adminCommand('ping')" >/dev/null 2>&1; do
  sleep 2
done
echo "✅ mongo_single está pronto."

# Inicializa o replica set (se ainda não inicializado)
echo "🔧 Configurando replica set rs0..."
docker exec mongo_single mongosh --port 27017 <<'JS'
try {
  if (!rs.status().ok) {
    rs.initiate({
      _id: "rs0",
      members: [
        { _id: 0, host: "mongo_single:27017" }
      ]
    });
    print("✅ Replica set rs0 inicializado com sucesso!");
  } else {
    print("ℹ️  Replica set rs0 já estava inicializado.");
  }
} catch (e) {
  print("❌ Erro ao inicializar replica set:", e);
}
JS

# Aguarda o replica set ficar estável
echo "⏳ Aguardando replica set ficar estável..."
for i in {1..30}; do
  if docker exec mongo_single mongosh --quiet --port 27017 --eval "rs.status().ok" 2>/dev/null | grep -q "true"; then
    echo "✅ Replica set está estável!"
    break
  fi
  echo "⏳ Aguardando... ($i/30)"
  sleep 2
done

echo -e "\n🎉 MongoDB standalone configurado e pronto para uso!"
echo "📊 Conecte em: localhost:27027" 