-- Extensiones requeridas. Tiene que ser idempotente (que se pueda re-ejecutar sin error).

-- btree_gist permite usar operadores de igualdad (=) de tipos escalares como
-- bigint DENTRO de una restricción EXCLUDE junto con operadores de rango (&&).
-- Lo necesita el EXCLUDE de core.credito_estado_hist (mismo crédito + traslape).
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- pg_stat_statements agrega métricas por consulta (tiempo, llamadas, filas).
-- La librería ya se precarga vía shared_preload_libraries en postgresql.conf, y
-- esto solo registra la vista y funciones en la base. Lo usa `just slow` y el módulo 8.
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
