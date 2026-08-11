# Recetario SQL

Patrones reutilizables con un ejemplo mínimo sobre este esquema. La idea es que lo consultes **después**, cuando ya no estés estudiando y solo quieras acordarte de "cómo era el top-N por grupo". Cada receta es independiente, cópiala y adáptala.

Salta con el índice: cada entrada dice en una línea qué hace, para que encuentres la que necesitas sin leerlas todas.

## Índice

- [Rellenar huecos de fechas](#rellenar-huecos-de-fechas): una serie diaria completa, sin saltarse los días en cero.
- [Arrastrar el último valor conocido (carry forward)](#arrastrar-el-último-valor-conocido-carry-forward): rellenar los días sin dato con el último valor disponible.
- [Ventanas de tiempo (date_bin)](#ventanas-de-tiempo-date_bin): agrupar marcas de tiempo en buckets de N minutos.
- [Top-N por grupo](#top-n-por-grupo): los N registros más grandes de cada grupo.
- [Media móvil](#media-móvil): el promedio de los últimos N puntos.
- [Suma acumulada (running total)](#suma-acumulada-running-total): un saldo que se va acumulando fila por fila.
- [Deduplicar: el último de cada grupo (DISTINCT ON)](#deduplicar-el-último-de-cada-grupo-distinct-on): quedarte con una sola fila por grupo.
- [Buckets con CASE](#buckets-con-case): clasificar valores en rangos con etiqueta.
- [Pivote con FILTER](#pivote-con-filter): una columna por categoría, en una sola fila.
- [Aplanar una jerarquía (CTE recursivo)](#aplanar-una-jerarquía-cte-recursivo): recorrer un árbol padre/hijo y traer nivel y ruta.
- [Upsert (INSERT ON CONFLICT)](#upsert-insert-on-conflict): insertar, o actualizar si la fila ya existe.
- [Actualizar desde otra tabla (UPDATE FROM)](#actualizar-desde-otra-tabla-update-from): actualizar filas con datos de otra consulta.
- [Percentiles](#percentiles): calcular el p95 (y similares) exacto.

## Rellenar huecos de fechas

Una serie diaria completa, incluidos los días de cero:

```sql
SELECT d::date AS dia, count(c.id) AS colocacion
FROM generate_series(DATE '2025-08-01', DATE '2025-08-31', INTERVAL '1 day') d
LEFT JOIN core.credito c ON c.fecha_originacion = d::date
GROUP BY d::date
ORDER BY dia;
```

La clave es que la serie manda: el `LEFT JOIN` conserva los días sin filas en la tabla.

## Arrastrar el último valor conocido (carry forward)

Rellenar los días sin dato (fines de semana en la TIIE) con el último valor disponible:

```sql
SELECT d::date AS dia,
       (SELECT tr.tiie FROM core.tasa_referencia tr
        WHERE tr.fecha <= d::date ORDER BY tr.fecha DESC LIMIT 1) AS tiie
FROM generate_series(DATE '2025-01-01', DATE '2025-01-31', INTERVAL '1 day') d;
```

## Ventanas de tiempo (date_bin)

Agrupar en buckets de 5 minutos:

```sql
SELECT date_bin('5 minutes', ts, TIMESTAMPTZ '2024-01-01 00:00:00-06') AS ventana,
       count(*) AS n
FROM ops.peticion
GROUP BY 1;
```

El tercer argumento es el origen desde el que se cuentan los buckets.

## Top-N por grupo

Los 3 pagos más grandes de cada crédito. Con window function (una sola pasada, sin depender de índices):

```sql
SELECT credito_id, pago_id, monto FROM (
  SELECT credito_id, id AS pago_id, monto,
         row_number() OVER (PARTITION BY credito_id ORDER BY monto DESC, id) AS rn
  FROM core.pago) x
WHERE rn <= 3;
```

Con `LATERAL`, más legible cuando hay un índice que lo respalde:

```sql
SELECT c.id AS credito_id, t.id AS pago_id, t.monto
FROM core.credito c
CROSS JOIN LATERAL (
  SELECT id, monto FROM core.pago p
  WHERE p.credito_id = c.id ORDER BY monto DESC, id LIMIT 3) t;
```

## Media móvil

Promedio de los últimos 7 puntos (el actual y los 6 anteriores):

```sql
SELECT dia, colocacion,
       avg(colocacion) OVER (ORDER BY dia ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS media_7d
FROM (/* tu serie diaria */) s;
```

## Suma acumulada (running total)

Un saldo que crece (o baja) fila por fila conforme avanzas:

```sql
SELECT folio,
       sum(CASE WHEN tipo='deposito' THEN monto ELSE -monto END)
         OVER (ORDER BY folio) AS saldo_acumulado
FROM core.movimiento_captacion
WHERE cuenta_id = 1
ORDER BY folio;
```

## Deduplicar: el último de cada grupo (DISTINCT ON)

El último pago de cada crédito, extensión propia de Postgres:

```sql
SELECT DISTINCT ON (credito_id) credito_id, id AS pago_id, monto
FROM core.pago
ORDER BY credito_id, fecha_pago DESC, id DESC;
```

La columna de `DISTINCT ON` debe ir primero en el `ORDER BY`; el resto del `ORDER BY` decide **cuál** fila de cada grupo te quedas.

## Buckets con CASE

Clasificar por rangos:

```sql
SELECT CASE WHEN dpd <= 0  THEN '0'
            WHEN dpd < 30  THEN '1-29'
            WHEN dpd < 60  THEN '30-59'
            WHEN dpd < 90  THEN '60-89'
            ELSE '90+' END AS cubeta,
       count(*) AS n
FROM (SELECT 45 AS dpd) x   -- reemplaza por tu cálculo de días de atraso
GROUP BY 1;
```

Para rangos numéricos regulares, `width_bucket(valor, min, max, n)` reparte en `n` buckets de igual ancho sin escribir el `CASE`.

## Pivote con FILTER

Una columna por categoría, en una fila:

```sql
SELECT count(*) FILTER (WHERE estado='vigente')   AS vigente,
       count(*) FILTER (WHERE estado='vencido')   AS vencido,
       count(*) FILTER (WHERE estado='liquidado') AS liquidado
FROM core.credito;
```

`FILTER` es más limpio que `sum(CASE WHEN ... THEN 1 ELSE 0 END)` y funciona con cualquier agregado.

## Aplanar una jerarquía (CTE recursivo)

Recorrer un árbol y traer nivel y ruta:

```sql
WITH RECURSIVE t AS (
  SELECT id, codigo, nombre, 1 AS nivel, codigo::text AS ruta
  FROM core.cuenta_contable WHERE padre_id IS NULL
  UNION ALL
  SELECT c.id, c.codigo, c.nombre, t.nivel+1, t.ruta || ' > ' || c.codigo
  FROM core.cuenta_contable c JOIN t ON c.padre_id = t.id)
SELECT * FROM t;
```

El caso base son las raíces (`padre_id IS NULL`); el paso recursivo une los hijos. Para subir en vez de bajar (de una hoja hacia la raíz), invierte la condición del join a `c.id = t.jefe_id`.

## Upsert (INSERT ON CONFLICT)

Insertar o actualizar si ya existe:

```sql
INSERT INTO core.cuenta_captacion (cliente_id, clabe, tipo, saldo, fecha_apertura)
VALUES (1, '646100000000009999', 'vista', 100, DATE '2025-01-01')
ON CONFLICT (clabe) DO UPDATE SET saldo = EXCLUDED.saldo;
```

`EXCLUDED` es la fila que se intentó insertar. Requiere una restricción única sobre la columna del `ON CONFLICT`.

## Actualizar desde otra tabla (UPDATE FROM)

Actualizar filas de una tabla con datos calculados en otra consulta:

```sql
UPDATE core.credito c
SET estado = 'castigado'
FROM (SELECT credito_id FROM /* tu cálculo de mora > 180 días */) m
WHERE c.id = m.credito_id AND c.estado <> 'castigado';
```

Antes de correr un `UPDATE` así, prueba el `SELECT` de las filas que afectaría. Es exactamente lo que pide el ejercicio E52.

## Percentiles

El percentil 95 de la latencia, exacto (no estimado por buckets):

```sql
SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY duracion_ms) AS p95
FROM ops.peticion;
```

`percentile_cont` interpola; `percentile_disc` devuelve un valor real de la muestra.
