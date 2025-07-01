#!/usr/bin/env bash
mode=${1:-single}   # single ou sharded
uri="mongodb://localhost:$([ "$mode" = "single" ] && echo 27027 || echo 27017)"

# Mede throughput de insert
python load_mongo.py --total 500000 --uri "$uri" | tee "insert_$mode.log"

# Coleta estatísticas rápidas
echo "Estatísticas do MongoDB $mode:" > "stat_$mode.json"
docker exec $(docker ps -q -f name=mongo_single) mongosh --quiet --eval "db.stats()" >> "stat_$mode.json" 2>/dev/null || echo "Erro ao coletar stats" >> "stat_$mode.json"
docker stats --no-stream | tee "resources_$mode.txt"

# Salva contagem de chunks (só faz sentido p/ cluster)
if [ "$mode" = "sharded" ]; then
  docker exec mongos mongosh --quiet --eval \
    'db.getSiblingDB("config").chunks.aggregate([{ $group:{ _id:"$shard", cnt:{ $sum:1 } } }]).forEach(printjson)' \
    | tee "chunks_$mode.txt"
fi

