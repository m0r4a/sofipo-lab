#!/usr/bin/env bash
# Reporta el tamaño en disco por tabla e índice y el total del clúster.
# Lo usa `just tamano`. Sale con código != 0 si el total supera un umbral (que es opcional)
set -euo pipefail

CONTAINER="${1:-sofipo-db}"
USER="${POSTGRES_USER:-sofipo}"
DB="${POSTGRES_DB:-sofipo}"

docker exec -i "$CONTAINER" psql -U "$USER" -d "$DB" -P pager=off <<'SQL'
\echo '-- Tamaño por tabla (heap + índices + TOAST), esquemas core y ops --'
SELECT
  n.nspname                                        AS esquema,
  c.relname                                        AS tabla,
  pg_size_pretty(pg_total_relation_size(c.oid))    AS total,
  pg_size_pretty(pg_relation_size(c.oid))          AS solo_heap,
  pg_size_pretty(pg_indexes_size(c.oid))           AS indices
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname IN ('core','ops','lab')
ORDER BY pg_total_relation_size(c.oid) DESC;

\echo ''
\echo '-- Total del clúster --'
SELECT pg_size_pretty(pg_database_size(current_database())) AS tamano_base;
SQL
