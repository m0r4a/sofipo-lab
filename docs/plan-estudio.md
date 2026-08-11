# Plan de estudio

Nueve módulos de dificultad estrictamente creciente. No saltes: cada uno asume el anterior. La ruta completa toma entre 15 y 25 horas según tu punto de partida. Resuelve en `respuestas/` y verifica con `just check`.

Recuerda: "hoy" en los ejercicios es `lab.reloj()` (2026-01-01), no la fecha real. Y el vocabulario de negocio está en `docs/glosario-financiero.md`, o con `just glosario <término>` desde la terminal.

## Módulo 0: Reconocimiento (E01-E04, dificultad 1)

Antes de consultar hay que orientarse: cuántas filas hay, en qué rango de fechas, cuántos valores distintos. Aquí aprendes a moverte con `\d`, `\dt`, `\d+` y a leer los comentarios de las tablas, que son tu mapa.

El ejercicio E04 no tiene hash: te pide explicar con tus palabras qué es `aplicacion_pago`, porque si entiendes esa tabla, entendiste el modelo.

**Tiempo:** 30 a 45 min.

## Módulo 1: Joins (E05-E12, dificultad 1-2)

El primer módulo con joins. La diferencia entre `INNER` y `LEFT` **cambia la respuesta**: un `INNER JOIN` esconde la sucursal que no colocó créditos; un `LEFT JOIN` la muestra. Aprendes el anti-join (`LEFT JOIN ... WHERE b.id IS NULL`, o `NOT EXISTS`) para encontrar ausencias, el self-join para la jerarquía de empleados, y el `FULL OUTER JOIN` para conciliar dos fuentes.

Un error clásico tiene ejercicio propio (E09): poner una condición sobre la tabla derecha en el `WHERE` convierte tu `LEFT JOIN` en `INNER` y pierdes justo las filas que querías conservar. La condición va en el `ON`, no en el `WHERE`.

**Tiempo:** 2 a 3 h.

## Módulo 2: Agregación (E13-E20, dificultad 2)

`GROUP BY`, y la diferencia entre `WHERE` (filtra filas antes de agrupar) y `HAVING` (filtra grupos después). Aquí aparece un error común: sumar sobre un join que multiplica filas. Si unes `credito` con `pago` y sumas `monto_originado`, cada crédito se cuenta tantas veces como pagos tenga, y la cifra queda inflada. El ejercicio E17 pide evitarlo.

También: `COUNT(*)` vs `COUNT(columna)` vs `COUNT(DISTINCT columna)`, y `FILTER (WHERE ...)` como forma limpia de pivotar (una columna por estado en una sola fila).

**Tiempo:** 2 a 3 h.

## Módulo 3: Lógica condicional y fechas (E21-E27, dificultad 2-3)

Aquí conviertes datos crudos en reportes. `CASE` para armar buckets de mora, `COALESCE` y `NULLIF` para manejar los nulos, y aritmética de fechas con `age()`, `date_trunc` y `EXTRACT`.

El patrón principal es `generate_series` para rellenar los días sin actividad: sin él, un reporte diario "salta" los días de cero, y eso aplica a cualquier serie temporal (y a Grafana). Cierra con la frontera de zona horaria, donde la respuesta ingenua cae un día equivocado.

**Tiempo:** 2 a 3 h.

## Módulo 4: Subconsultas y CTEs (E28-E35, dificultad 3)

Subconsulta escalar, `IN`, `EXISTS`, correlacionada, y por qué `NOT IN` con NULLs falla (basta un NULL en la lista para que no devuelva nada; usa `NOT EXISTS`). Tu primer `WITH`, y CTEs encadenados que convierten una consulta anidada ilegible en pasos que se leen de arriba a abajo. Nota importante: desde PostgreSQL 12 un CTE ya no es una barrera de optimización por defecto; `MATERIALIZED` / `NOT MATERIALIZED` te dejan controlarlo cuando importa.

**Tiempo:** 2 a 3 h.

## Módulo 5: Window functions (E36-E45, dificultad 3-4)

El módulo de las window functions, y trae varias. `ROW_NUMBER`, `RANK` y `DENSE_RANK` con su diferencia (qué hacen con los empates). `PARTITION BY` para calcular "dentro de cada grupo". `LAG`/`LEAD` para variación mes a mes. Suma acumulada y media móvil con marcos de ventana (`ROWS BETWEEN ...`), donde el marco por defecto de `LAST_VALUE` es un error común. `NTILE` para deciles de riesgo, y el `DISTINCT ON` de Postgres para "el último de cada grupo".

El ejercicio E45 analiza cosechas y muestra qué meses de originación se comportaron peor: el patrón está sembrado en los datos y solo aparece con estas herramientas.

**Tiempo:** 4 a 5 h.

## Módulo 6: Avanzado (E46-E52, dificultad 4)

El cajón de herramientas pesadas. CTE recursivo sobre jerarquías (el plan de cuentas y la cadena de mando) y para reconstruir un plan de amortización desde cero. `LATERAL` para top-N por grupo. `GROUPING SETS`/`ROLLUP`/`CUBE` para subtotales contables. Agregación de JSON con `jsonb_agg`.

Cierra con el patrón detrás de un `UPDATE ... FROM` o un upsert, resuelto como el `SELECT` de las filas que se afectarían (sin mutar, para que el laboratorio siga siendo determinista).

**Tiempo:** 3 a 4 h.

## Módulo 7: Correlación negocio ↔ sistema (E53-E57, dificultad 4)

Aquí cruzas el negocio con la telemetría del sistema. Unes `ops.peticion` con `core.credito`, calculas percentiles de latencia con `percentile_cont` (y ves por qué el percentil exacto difiere del estimado por buckets de Prometheus), mides tasa de error por ventana de tiempo, y cruzas despliegues con incidentes.

El ejercicio final cuantifica el impacto de una falla: cuántos desembolsos fallaron y por cuánto dinero.

**Tiempo:** 2 a 3 h.

## Módulo 8: Rendimiento (E58-E60, dificultad 5)

Leer `EXPLAIN (ANALYZE, BUFFERS)`. Encontrar un `Seq Scan` costoso y el índice que lo elimina (el laboratorio deja dos rutas sin índice a propósito). Reescribir una consulta lenta manteniendo el resultado idéntico. Comparar un índice compuesto contra dos simples, y ver cómo `ANALYZE` cambia las decisiones del planner. La guía completa está en `docs/notas-rendimiento.md`.

**Tiempo:** 2 a 3 h.

## Tabla de errores clásicos

| Síntoma | Causa | Corrección |
|---|---|---|
| El total sale enorme, muchas veces lo esperado | `SUM` sobre un join que multiplica filas | Agrega en una subconsulta antes de unir, o no unas la tabla que multiplica |
| Un `LEFT JOIN` devuelve las mismas filas que un `INNER` | Condición sobre la tabla derecha en el `WHERE` | Muévela al `ON` |
| `NOT IN (subconsulta)` no devuelve nada | La subconsulta contiene NULLs | Usa `NOT EXISTS` |
| El promedio baja al "arreglar" los nulos | `avg(coalesce(col,0))` cuenta los nulos como cero | Si quieres ignorarlos, deja `avg(col)` a secas |
| Un reporte diario "salta" días | No hay fila para los días sin actividad | `generate_series` de fechas + `LEFT JOIN` |
| El día de un registro cambia según quién lo mire | Truncar un `timestamptz` sin fijar la zona | `AT TIME ZONE` explícito |
| `LAST_VALUE` devuelve el valor de la fila actual | Marco de ventana por defecto (hasta la fila actual) | `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` |
| `just check` dice "contenido difiere" con filas y columnas correctas | Redondeo o tipo fuera del contrato | Aplica `::numeric(18,2)` / `::date` según el enunciado |
| `just check` dice "columnas distintas" | Nombre o tipo de columna no coincide | Alias exacto del contrato |
| El resultado cambia entre corridas | Dependes del orden físico sin `ORDER BY` | Ordena explícitamente cuando el orden importa |
