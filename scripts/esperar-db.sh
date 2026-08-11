#!/usr/bin/env bash
# Espera a que el Postgres dentro del contenedor acepte conexiones.
# Usa el healthcheck de compose y también hace un pg_isready directo
# para cubrir el caso de un `just seed` inmediato tras `just up`.
set -euo pipefail

CONTAINER="${1:-sofipo-db}"
USER="${POSTGRES_USER:-sofipo}"
DB="${POSTGRES_DB:-sofipo}"
INTENTOS="${2:-30}"

echo "Esperando a que $CONTAINER acepte conexiones..."
for i in $(seq 1 "$INTENTOS"); do
  if docker exec "$CONTAINER" pg_isready -U "$USER" -d "$DB" >/dev/null 2>&1; then
    echo "Base lista tras ${i} intento(s)."
    exit 0
  fi
  sleep 1
done

echo "La base no respondió tras ${INTENTOS}s. Revisa 'just logs'." >&2
exit 1
