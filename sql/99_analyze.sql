-- Cierre del seed.
--   - Revierte a LOGGED las tablas que se cargaron como UNLOGGED.
--   - ANALYZE para estadísticas frescas, así el planeador elige bien (módulo 8).
--   - Reporte de tamaños.
\timing on

-- De UNLOGGED a LOGGED (reescribe cada tabla generando WAL una sola vez).
-- EL ORDEN IMPORTA. Una tabla LOGGED no puede referenciar (FK) a una UNLOGGED, así que
-- las referenciadas (asiento, pago, amortizacion) se convierten ANTES que las que
-- las referencian (movimiento_contable, aplicacion_pago).
ALTER TABLE core.amortizacion         SET LOGGED;
ALTER TABLE core.pago                 SET LOGGED;
ALTER TABLE core.asiento              SET LOGGED;
ALTER TABLE core.aplicacion_pago      SET LOGGED;
ALTER TABLE core.movimiento_contable  SET LOGGED;
ALTER TABLE core.movimiento_captacion SET LOGGED;
ALTER TABLE core.autorizacion_tarjeta SET LOGGED;
ALTER TABLE ops.peticion              SET LOGGED;
ALTER TABLE ops.metrica_muestra       SET LOGGED;

-- Estadísticas. Sin esta info el planner no tiene datos para elegir buenos planes.
ANALYZE;

-- 3. Reporte de tamaños por tabla e índice.
\echo '-- Tamaño por tabla (heap + índices + TOAST) --'
SELECT n.nspname AS esquema, c.relname AS tabla,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS total,
       pg_size_pretty(pg_relation_size(c.oid))       AS heap,
       pg_size_pretty(pg_indexes_size(c.oid))        AS indices
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r' AND n.nspname IN ('core','ops','lab')
ORDER BY pg_total_relation_size(c.oid) DESC
LIMIT 12;

\echo '-- Total de la base --'
SELECT pg_size_pretty(pg_database_size(current_database())) AS tamano_total;
