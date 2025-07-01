#!/usr/bin/env python3
"""
load_mongo_sharded.py – gera carga massiva para MongoDB (single ou sharded)

Uso básico:
    pip install pymongo faker
    python load_mongo_sharded.py --total 1000000 --batch 1000 \
        --uri mongodb://localhost:27017
"""

import time, random, argparse
from faker import Faker
from pymongo import MongoClient, InsertOne
from pymongo.errors import BulkWriteError


def gen_docs(fake, n):
    for _ in range(n):
        yield {
            "user_id": fake.uuid4(),
            "timestamp": fake.date_time_this_year(),
            "valor": round(random.random() * 1000, 2),
            "status": random.choice(["PENDENTE", "PROCESSADO", "FALHA"]),
        }


def main():
    p = argparse.ArgumentParser("Gerador de carga para MongoDB sharded")
    p.add_argument("--uri", default="mongodb://localhost:27017")
    p.add_argument("--db", default="experimento")
    p.add_argument("--coll", default="registros")
    p.add_argument("--total", type=int, default=1_000_000)
    p.add_argument("--batch", type=int, default=1_000)
    p.add_argument("--seed", type=int)
    args = p.parse_args()

    if args.seed is not None:
        random.seed(args.seed)

    fake = Faker()
    col = MongoClient(args.uri)[args.db][args.coll]

    print(f"Inserindo {args.total:,} docs em {args.uri}…")
    start = time.perf_counter()
    ops, inserted = [], 0

    try:
        for doc in gen_docs(fake, args.total):
            ops.append(InsertOne(doc))
            if len(ops) == args.batch:
                col.bulk_write(ops, ordered=False)
                inserted += len(ops)
                ops.clear()
        if ops:
            col.bulk_write(ops, ordered=False)
            inserted += len(ops)
    except BulkWriteError as e:
        print("BulkWriteError:", e.details)
    finally:
        elapsed = time.perf_counter() - start
        rate = inserted / elapsed if elapsed else 0
        print(f"Feito: {inserted:,} docs em {elapsed:.2f}s  (~{rate:,.0f} docs/s)")


if __name__ == "__main__":
    main()
