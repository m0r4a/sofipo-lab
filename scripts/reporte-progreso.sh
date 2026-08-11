#!/usr/bin/env bash
# Muestra el avance de la persona tomando el
# curso llamando a lab.progreso().

# Lo usa `just progreso`.
set -euo pipefail

CONTAINER="${1:-sofipo-db}"
USER="${POSTGRES_USER:-sofipo}"
DB="${POSTGRES_DB:-sofipo}"

docker exec -i "$CONTAINER" psql -U "$USER" -d "$DB" -P pager=off \
  -c "SELECT * FROM lab.progreso();"
