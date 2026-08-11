#!/usr/bin/env bash
# Muestra el glosario financiero desde la terminal, sin abrir el archivo.
# Sin argumento: lista los términos (índice).
# Con un término: imprime la o las secciones que lo mencionan.
#   bash scripts/glosario.sh mora
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
GLOSARIO="$DIR/docs/glosario-financiero.md"
TERMINO="${1:-}"

if [ ! -f "$GLOSARIO" ]; then
  echo "No se encontró docs/glosario-financiero.md" >&2
  exit 1
fi

if [ -z "$TERMINO" ]; then
  echo "Glosario financiero. Términos disponibles:"
  echo
  grep -E '^#{2,3} ' "$GLOSARIO" | sed -E 's/^## /\n/; s/^### /  - /'
  echo
  echo "Uso: just glosario <término>   (por ejemplo: just glosario mora)"
  exit 0
fi

awk -v term="$TERMINO" '
  BEGIN { t = tolower(term) }
  /^#{2,3} / {
    if (buf != "" && hit) { printf "%s", buf; found = 1 }
    buf = $0 "\n"
    hit = (index(tolower($0), t) > 0)
    next
  }
  { buf = buf $0 "\n"; if (index(tolower($0), t) > 0) hit = 1 }
  END {
    if (buf != "" && hit) { printf "%s", buf; found = 1 }
    if (!found) print "Sin coincidencias para \"" term "\". Prueba: just glosario   (para ver el índice)."
  }
' "$GLOSARIO"
