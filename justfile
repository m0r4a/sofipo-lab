# Laboratorio SQL de una SOFIPO. `just` sin argumentos lista las recetas.
# Requiere `just` (https://github.com/casey/just).

# Carga .env automáticamente (equivalente a lo que hace docker compose).
set dotenv-load := true
set shell := ["bash", "-uc"]

container      := "sofipo-db"
postgres_user  := env_var_or_default("POSTGRES_USER", "sofipo")
postgres_db    := env_var_or_default("POSTGRES_DB", "sofipo")
host_port      := env_var_or_default("HOST_PORT", "5433")
scale          := env_var_or_default("SCALE", "1")
scale_max      := env_var_or_default("SCALE_MAX", "3")
pgdata_mode    := env_var_or_default("PGDATA_MODE", "volume")

# En modo bind se añade el override de compose, en modo volume, solo el base.
compose := if pgdata_mode == "bind" { "docker compose -f compose.yaml -f compose.bind.yaml" } else { "docker compose -f compose.yaml" }

# psql dentro del contenedor, no interactivo, parando al primer error.
psql := "docker exec -i " + container + " psql -v ON_ERROR_STOP=1 -U " + postgres_user + " -d " + postgres_db

# Orden explícito de los archivos del seed (no dependemos del glob).
sql_files := "sql/00_extensiones.sql sql/01_esquemas.sql sql/10_core_tablas.sql sql/11_core_comentarios.sql sql/20_ops_tablas.sql sql/21_ops_comentarios.sql sql/30_lab_infra.sql sql/40_semilla_catalogos.sql sql/41_semilla_masiva.sql sql/42_anomalias.sql sql/50_indices.sql sql/51_vistas.sql sql/60_ejercicios.sql sql/99_analyze.sql"

# Lista las recetas disponibles.
default:
    @just --list --unsorted
    @echo ""
    @echo "Variables: SCALE={{scale}} (tope {{scale_max}}), HOST_PORT={{host_port}}, PGDATA_MODE={{pgdata_mode}}"

# Levanta el contenedor y espera a que la db esté lista.
up:
    {{compose}} up -d
    POSTGRES_USER={{postgres_user}} POSTGRES_DB={{postgres_db}} bash scripts/esperar-db.sh {{container}}

# Detiene el contenedor conservando los datos.
down:
    {{compose}} down

# Detiene Y BORRA el volumen de datos (pide confirmación).
nuke:
    #!/usr/bin/env bash
    set -euo pipefail
    printf "Esto BORRA todos los datos del laboratorio. Escribe 'si' para confirmar: "
    read respuesta
    if [ "$respuesta" = "si" ]; then
      {{compose}} down -v
      echo ">> Volumen eliminado."
    else
      echo ">> Cancelado. No se borró nada."
    fi

# Ejecuta todo sql/ en orden (es idempotente, avisa si ya hay datos).
seed:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{scale}}" -gt "{{scale_max}}" ]; then
      echo "!! SCALE={{scale}} excede SCALE_MAX={{scale_max}}. Con 10 GB de disco puede tronar."
      echo "   Sube SCALE_MAX en .env si de verdad lo quieres, bajo tu responsabilidad."
      exit 1
    fi
    ya=$(docker exec -i {{container}} psql -tAq -U {{postgres_user}} -d {{postgres_db}} \
      -c "SELECT CASE WHEN to_regclass('core.credito') IS NULL THEN 0 ELSE (SELECT count(*) FROM core.credito) END" 2>/dev/null || echo 0)
    if [ "$ya" -gt 0 ]; then
      echo "!! Ya hay $ya créditos cargados. El seed no es acumulable."
      echo "   Usa 'just reset' para reconstruir desde cero."
      exit 1
    fi
    echo ">> Sembrando con SCALE={{scale}}..."
    inicio=$(date +%s)
    for f in {{sql_files}}; do
      echo ">> Ejecutando $f"
      docker exec -i {{container}} psql -v ON_ERROR_STOP=1 -v scale={{scale}} \
        -U {{postgres_user}} -d {{postgres_db}} < "$f"
    done
    fin=$(date +%s)
    echo ">> Seed completo en $((fin - inicio))s."
    echo ">> Tamaño final:"
    POSTGRES_USER={{postgres_user}} POSTGRES_DB={{postgres_db}} bash scripts/medir-tamano.sh {{container}} | tail -n 4

# nuke + up + seed en un solo comando. es decir, borrar todo, levantar y generar seeds
reset: nuke up seed

# Sesión interactiva de psql (aplica sql/.psqlrc).
psql:
    docker exec -it -e PSQLRC=/sql/.psqlrc {{container}} psql -U {{postgres_user}} -d {{postgres_db}}

# Verifica un ejercicio: just check E12 (lee la carpeta respuestas/E12.sql).
check ej:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "respuestas/{{ej}}.sql" ]; then
      echo "No existe respuestas/{{ej}}.sql. Escribe ahí tu consulta."
      exit 1
    fi
    printf "SELECT lab.verificar('%s', \$VERI\$\n%s\n\$VERI\$);\n" "{{ej}}" "$(cat respuestas/{{ej}}.sql)" \
      | {{psql}} -tA

# Tabla de avance: resueltos, intentos, % por módulo.
progreso:
    POSTGRES_USER={{postgres_user}} POSTGRES_DB={{postgres_db}} bash scripts/reporte-progreso.sh {{container}}

# Tamaño por tabla e índice y total del clúster.
tamano:
    POSTGRES_USER={{postgres_user}} POSTGRES_DB={{postgres_db}} bash scripts/medir-tamano.sh {{container}}

# EXPLAIN (ANALYZE, BUFFERS) de un archivo: just explain ruta.sql.
explain q:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{q}}" ]; then echo "No existe {{q}}"; exit 1; fi
    printf "EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)\n%s\n" "$(cat {{q}})" | {{psql}}

# Top 15 de pg_stat_statements por tiempo total.
slow:
    {{psql}} -P pager=off -c "SELECT round(total_exec_time::numeric,1) AS ms_total, calls, round(mean_exec_time::numeric,2) AS ms_media, left(regexp_replace(query, '\s+', ' ', 'g'), 90) AS consulta FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 15;"

# Muestra la pista de un ejercicio: just pista E12.
pista ej:
    {{psql}} -tA -c "SELECT lab.pista('{{ej}}');"

# Muestra el enunciado completo de un ejercicio: just enunciado E05.
enunciado ej:
    {{psql}} -tA -c "SELECT lab.enunciado('{{ej}}');"

# Muestra el siguiente ejercicio sin resolver.
siguiente:
    {{psql}} -c "SELECT * FROM lab.siguiente();"

# Consulta el glosario financiero: just glosario mora (sin término, muestra el índice).
glosario termino="":
    bash scripts/glosario.sh "{{termino}}"

# Sigue los logs del contenedor.
logs:
    {{compose}} logs -f db
