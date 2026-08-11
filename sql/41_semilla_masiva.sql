-- Generación paramétrica por SCALE, en SQL puro.
--
-- Estrategia (spec §6.1).
--   * setseed(0.42) y sin paralelismo para determinismo total.
--   * Tablas grandes en UNLOGGED durante la carga y se vuelven LOGGED en 99.
--   * Todo con INSERT ... SELECT ... FROM generate_series. Sin bucles fila a fila.
--   * Índices y FKs se crean después (50). Aquí solo se insertan datos.
--   * "Hoy" = lab.reloj() (fijo), nunca now().
--
-- Aleatoriedad por fila. Una subconsulta o LATERAL que llama random() sin
-- referenciar la fila externa se evalúa una sola vez (InitPlan) y colapsa a un único
-- valor. Para forzar la evaluación por fila se referencia la llave externa `g`
-- (p. ej. ORDER BY (g + random())). random() directo en el SELECT de nivel superior
-- sí es por fila.
--
-- Escala que se lee con  -v scale=N  (default 1). Cardinalidades ~ lineales en N.
\timing on
\set scale :scale
SET max_parallel_workers_per_gather = 0;   -- random() en workers no es reproducible
SELECT setseed(0.42);

ALTER TABLE core.amortizacion         SET UNLOGGED;
ALTER TABLE core.pago                 SET UNLOGGED;
ALTER TABLE core.aplicacion_pago      SET UNLOGGED;
ALTER TABLE core.movimiento_contable  SET UNLOGGED;
ALTER TABLE core.asiento              SET UNLOGGED;
ALTER TABLE core.movimiento_captacion SET UNLOGGED;
ALTER TABLE core.autorizacion_tarjeta SET UNLOGGED;
ALTER TABLE ops.peticion              SET UNLOGGED;
ALTER TABLE ops.metrica_muestra       SET UNLOGGED;

-- Clientes
INSERT INTO core.cliente (curp, rfc, nombre, fecha_nacimiento, ingreso_mensual, fecha_alta)
SELECT
  left(regexp_replace(upper(nom), '[^A-Z]', '', 'g') || 'XXXX', 4)
    || to_char(fnac, 'YYMMDD') || lpad(g::text, 8, '0'),
  CASE WHEN random() < 0.15 THEN NULL
       ELSE left(regexp_replace(upper(nom), '[^A-Z]', '', 'g') || 'XXX', 4)
            || to_char(fnac, 'YYMMDD') || lpad((g % 1000)::text, 3, '0') END,
  nom, fnac,
  CASE WHEN random() < 0.15 THEN NULL
       ELSE round((4000 + 60000 * power(random(), 3))::numeric, 2) END,
  DATE '2020-06-01' + (random() * 2000)::int
FROM generate_series(1, 20000 * :scale) g
CROSS JOIN LATERAL (
  SELECT
    (ARRAY['Juan','María','José','Guadalupe','Francisco','Verónica','Luis','Ana','Miguel','Rosa','Carlos','Laura','Jorge','Patricia','Ricardo','Elena','Fernando','Sofía','Roberto','Andrea'])[1 + (g % 20)]
    || ' ' ||
    (ARRAY['García','Hernández','López','González','Rodríguez','Pérez','Sánchez','Ramírez','Cruz','Flores','Gómez','Díaz','Reyes','Morales','Jiménez','Torres','Vázquez','Mendoza','Castillo','Romero'])[1 + ((g / 7) % 20)] AS nom,
    DATE '1960-01-01' + (random() * 16000)::int AS fnac
) v;

-- Domicilios
-- 0..3 por cliente (~1.3 promedio). random() en el WHERE es por fila (c,k).
INSERT INTO core.cliente_direccion (cliente_id, calle, ciudad, estado, cp, es_principal)
SELECT c.id,
       'Calle ' || (1 + (c.id % 200)) || ' #' || (1 + (c.id * 7 % 900)),
       (ARRAY['CDMX','Guadalajara','Monterrey','Puebla','Querétaro','Mérida'])[1 + (c.id % 6)],
       (ARRAY['CDMX','Jalisco','Nuevo León','Puebla','Querétaro','Yucatán'])[1 + (c.id % 6)],
       lpad(((c.id * 13) % 99999 + 1)::text, 5, '0'),
       (k = 1)
FROM core.cliente c
CROSS JOIN generate_series(1, 3) k
-- El predicado DEBE depender de c.id. Si solo dependiera de k, el planeador lo
-- empuja al generate_series y lo evalúa una vez (todos los clientes iguales).
-- Un hash de (c.id, k) da un pseudoaleatorio por fila, determinista y no empujable.
WHERE (abs(hashint8(c.id * 3 + k)) % 1000) / 1000.0
      < (CASE k WHEN 1 THEN 0.85 WHEN 2 THEN 0.35 ELSE 0.10 END);

-- Créditos
-- Todos los LATERAL referencian g (o s.suc_id), así que la aleatoriedad es por fila.
INSERT INTO core.credito
  (cliente_id, producto_id, sucursal_id, empleado_id, credito_origen_id,
   monto_originado, tasa_pactada, plazo_meses, fecha_originacion, estado)
SELECT
  1 + floor(random() * (20000 * :scale))::int,
  p.prod_id, s.suc_id, a.ase_id, NULL,
  round((p.monto_min + (p.monto_max - p.monto_min) * power(random(), 3))::numeric, 2),
  p.tasa_nominal_anual,
  -- plazo dentro del rango, múltiplos de 6, sesgado a plazos largos (power<1)
  greatest(p.plazo_min, least(p.plazo_max,
    6 * greatest(1, round((p.plazo_min + (p.plazo_max - p.plazo_min) * power(random(), 0.6)) / 6.0)::int))),
  make_date(2021 + floor(r.ry * 5)::int,
            CASE WHEN r.rm < 0.05 THEN 1  WHEN r.rm < 0.11 THEN 2  WHEN r.rm < 0.19 THEN 3
                 WHEN r.rm < 0.27 THEN 4  WHEN r.rm < 0.36 THEN 5  WHEN r.rm < 0.44 THEN 6
                 WHEN r.rm < 0.53 THEN 7  WHEN r.rm < 0.65 THEN 8  WHEN r.rm < 0.74 THEN 9
                 WHEN r.rm < 0.82 THEN 10 WHEN r.rm < 0.90 THEN 11 ELSE 12 END,
            1 + floor(r.rd * 28)::int),
  'vigente'
FROM generate_series(1, 30000 * :scale) g
CROSS JOIN LATERAL (SELECT id AS prod_id, monto_min, monto_max, plazo_min, plazo_max, tasa_nominal_anual
                    FROM core.producto_credito ORDER BY (g + random()) LIMIT 1) p
CROSS JOIN LATERAL (SELECT id AS suc_id FROM core.sucursal
                    WHERE codigo <> 'SUC-039' ORDER BY (g + random()) LIMIT 1) s
CROSS JOIN LATERAL (SELECT id AS ase_id FROM core.empleado
                    WHERE sucursal_id = s.suc_id AND puesto = 'asesor'
                    ORDER BY (g + random()) LIMIT 1) a
CROSS JOIN LATERAL (SELECT g AS gg, random() AS ry, random() AS rm, random() AS rd) r;

-- Comportamiento por crédito (tabla temporal)
DROP TABLE IF EXISTS _beh;
CREATE TEMP TABLE _beh AS
WITH base AS (
  SELECT c.id AS credito_id, c.plazo_meses, c.fecha_originacion,
         (extract(year FROM age(lab.reloj()::date, c.fecha_originacion)) * 12
          + extract(month FROM age(lab.reloj()::date, c.fecha_originacion)))::int AS age_meses,
         pc.codigo AS prod, cl.ingreso_mensual,
         to_char(c.fecha_originacion, 'YYYY-MM') AS cohorte, c.sucursal_id
  FROM core.credito c
  JOIN core.producto_credito pc ON pc.id = c.producto_id
  JOIN core.cliente cl ON cl.id = c.cliente_id
),
riesgo AS (
  SELECT b.*,
    least(0.90, greatest(0.02,
      (CASE prod WHEN 'MIC' THEN 0.35 WHEN 'CON' THEN 0.30 WHEN 'PER' THEN 0.22
                 WHEN 'PYM' THEN 0.15 WHEN 'NOM' THEN 0.10 ELSE 0.08 END)
      + (CASE WHEN ingreso_mensual IS NULL THEN 0.05
              WHEN ingreso_mensual < 8000 THEN 0.10 ELSE 0.00 END)
      + (CASE WHEN cohorte IN ('2022-08','2022-09') THEN 0.15 ELSE 0.00 END)  -- cosecha mala
      + (CASE WHEN sucursal_id % 7 = 0 THEN 0.05 ELSE 0.00 END)
    )) AS riesgo
  FROM base b
),
perfilado AS (
  SELECT r.*,
    CASE WHEN random() >= riesgo * 2 THEN 'bueno'
         WHEN random() >= riesgo     THEN 'moroso_leve'
         ELSE 'incumplido' END AS perfil
  FROM riesgo r
)
SELECT credito_id, plazo_meses, fecha_originacion, age_meses, riesgo, perfil,
       CASE
         WHEN perfil = 'bueno'       THEN least(age_meses, plazo_meses)
         WHEN perfil = 'moroso_leve' THEN greatest(0, least(age_meses, plazo_meses) - (1 + floor(random()*3)::int))
         WHEN cohorte = '2023-01'    THEN 3   -- patrón limpio, se detienen en la 3ª cuota
         ELSE 1 + floor(random()*4)::int
       END AS n_pagadas
FROM perfilado;

-- Estado del crédito según comportamiento.
UPDATE core.credito c SET estado = e.estado
FROM (
  SELECT b.credito_id,
    CASE
      WHEN b.n_pagadas >= b.plazo_meses THEN 'liquidado'
      WHEN b.n_pagadas >= b.age_meses   THEN 'vigente'
      ELSE (
        SELECT CASE
          WHEN d <= 0  THEN 'vigente'
          WHEN d < 90  THEN 'atrasado'
          WHEN d < 180 THEN 'vencido'
          WHEN b.perfil = 'incumplido' THEN 'castigado'
          ELSE 'vencido'
        END
        FROM (SELECT (lab.reloj()::date
                     - (b.fecha_originacion + ((b.n_pagadas + 1) * INTERVAL '1 month'))::date) AS d) dd
      )
    END AS estado
  FROM _beh b
) e
WHERE c.id = e.credito_id;

-- Amortización
INSERT INTO core.amortizacion
  (credito_id, num_cuota, fecha_vencimiento, cuota, capital, interes, saldo_final)
WITH RECURSIVE param AS (
  SELECT c.id AS credito_id, c.monto_originado AS p0, c.tasa_pactada / 12.0 AS i,
         c.plazo_meses AS n, c.fecha_originacion AS f0,
         round(c.monto_originado * (c.tasa_pactada / 12.0)
               / (1 - power(1 + c.tasa_pactada / 12.0, -c.plazo_meses)), 2) AS cuota
  FROM core.credito c
),
sched AS (
  SELECT credito_id, 1 AS num_cuota, cuota,
         round(p0 * i, 2) AS interes,
         round(cuota - round(p0 * i, 2), 2) AS capital,
         round(p0 - (cuota - round(p0 * i, 2)), 2) AS saldo_final,
         (f0 + INTERVAL '1 month')::date AS fecha_venc,
         i, n, cuota AS cuota0, f0
  FROM param
  UNION ALL
  SELECT credito_id, num_cuota + 1, cuota0,
         round(saldo_final * i, 2),
         round(cuota0 - round(saldo_final * i, 2), 2),
         round(saldo_final - (cuota0 - round(saldo_final * i, 2)), 2),
         (f0 + ((num_cuota + 1) * INTERVAL '1 month'))::date,
         i, n, cuota0, f0
  FROM sched WHERE num_cuota < n
)
SELECT credito_id, num_cuota, fecha_venc, cuota, capital, interes, saldo_final
FROM sched;

UPDATE core.amortizacion a
SET capital = a.capital + a.saldo_final, saldo_final = 0
FROM core.credito c
WHERE c.id = a.credito_id AND a.num_cuota = c.plazo_meses;

-- Pagos
INSERT INTO core.pago (credito_id, fecha_pago, monto, canal, referencia)
SELECT a.credito_id,
       (a.fecha_vencimiento
         + (CASE b.perfil WHEN 'bueno' THEN (random()*3)::int
                          WHEN 'moroso_leve' THEN (5 + random()*25)::int
                          ELSE (random()*10)::int END) * INTERVAL '1 day')::timestamptz,
       CASE WHEN random() < 0.08 THEN round(a.cuota * 0.6, 2) ELSE a.cuota END,
       (ARRAY['ventanilla','app','transferencia','domiciliacion'])[1 + floor(random()*4)::int],
       'PG-' || a.credito_id || '-' || a.num_cuota
FROM core.amortizacion a
JOIN _beh b ON b.credito_id = a.credito_id
WHERE a.num_cuota <= b.n_pagadas;

-- Aplicación de pagos
INSERT INTO core.aplicacion_pago
  (pago_id, amortizacion_id, monto_aplicado, aplicado_a_capital, aplicado_a_interes)
SELECT p.id, a.id, p.monto,
       round(p.monto * a.capital / a.cuota, 2),
       round(p.monto - round(p.monto * a.capital / a.cuota, 2), 2)
FROM core.pago p
JOIN core.amortizacion a
  ON a.credito_id = p.credito_id
 AND a.num_cuota = split_part(p.referencia, '-', 3)::int
WHERE a.cuota > 0;

INSERT INTO core.aplicacion_pago
  (pago_id, amortizacion_id, monto_aplicado, aplicado_a_capital, aplicado_a_interes)
SELECT p.id, a2.id, round(a2.cuota * 0.15, 2), round(a2.cuota * 0.15, 2), 0
FROM core.pago p
JOIN core.amortizacion a
  ON a.credito_id = p.credito_id AND a.num_cuota = split_part(p.referencia, '-', 3)::int
JOIN core.amortizacion a2
  ON a2.credito_id = p.credito_id AND a2.num_cuota = a.num_cuota + 1
WHERE random() < 0.15 AND a2.cuota > 0;

-- Historial de estado
INSERT INTO core.credito_estado_hist (credito_id, estado, valido_desde, valido_hasta)
SELECT c.id, 'vigente', c.fecha_originacion::timestamptz,
       CASE WHEN c.estado = 'vigente' THEN NULL
            ELSE (c.fecha_originacion + (b.n_pagadas + 1) * INTERVAL '1 month')::timestamptz END
FROM core.credito c JOIN _beh b ON b.credito_id = c.id;

INSERT INTO core.credito_estado_hist (credito_id, estado, valido_desde, valido_hasta)
SELECT c.id, c.estado, (c.fecha_originacion + (b.n_pagadas + 1) * INTERVAL '1 month')::timestamptz, NULL
FROM core.credito c JOIN _beh b ON b.credito_id = c.id
WHERE c.estado <> 'vigente';

-- Captación
INSERT INTO core.cuenta_captacion (cliente_id, clabe, tipo, saldo, esquema_rendimiento_id, fecha_apertura)
SELECT 1 + floor(random() * (20000 * :scale))::int,
       '6461' || lpad(g::text, 14, '0'),
       CASE WHEN random() < 0.7 THEN 'vista' ELSE 'plazo' END,
       round((500 + 80000 * power(random(), 2.5))::numeric, 2),
       CASE WHEN random() < 0.2 THEN NULL
            ELSE (SELECT id FROM core.esquema_rendimiento ORDER BY (g + random()) LIMIT 1) END,
       DATE '2020-06-01' + (random() * 2000)::int
FROM generate_series(1, 8000 * :scale) g;

INSERT INTO core.movimiento_captacion (cuenta_id, folio, fecha, tipo, monto)
SELECT cc.id, k,
       (cc.fecha_apertura + (random() * (lab.reloj()::date - cc.fecha_apertura))::int)::timestamptz,
       CASE WHEN random() < 0.55 THEN 'deposito' ELSE 'retiro' END,
       round((100 + 15000 * power(random(), 2))::numeric, 2)
FROM core.cuenta_captacion cc
CROSS JOIN generate_series(1, 30) k;

-- Pago de rendimientos trimestral con retención de ISR simplificada (20% del bruto).
INSERT INTO core.pago_rendimiento
  (cuenta_id, fecha, dias_computados, saldo_promedio, rendimiento_bruto, isr_retenido, rendimiento_neto)
SELECT cc.id, m::date, 90, cc.saldo,
       b.bruto,
       CASE WHEN er.isr_exento THEN 0 ELSE round(b.bruto * 0.20, 2) END,
       b.bruto - CASE WHEN er.isr_exento THEN 0 ELSE round(b.bruto * 0.20, 2) END
FROM core.cuenta_captacion cc
JOIN core.esquema_rendimiento er ON er.id = cc.esquema_rendimiento_id
CROSS JOIN LATERAL generate_series(
  date_trunc('month', cc.fecha_apertura::timestamp) + INTERVAL '1 month',
  date_trunc('month', lab.reloj()), INTERVAL '3 month') m
CROSS JOIN LATERAL (SELECT round(cc.saldo * er.tasa_anual / 4, 2) AS bruto) b
WHERE cc.esquema_rendimiento_id IS NOT NULL AND cc.saldo > 0;

-- Transferencias SPEI/STP
INSERT INTO core.transferencia
  (cuenta_captacion_id, direccion, rail, clabe_ordenante, clabe_beneficiario,
   institucion_id, nombre_contraparte, rfc_curp_contraparte, monto, clave_rastreo,
   tipo_pago, estado, ts_operacion, fecha_liquidacion)
SELECT cc.id,
       CASE WHEN random() < 0.5 THEN 'enviada' ELSE 'recibida' END,
       (ARRAY['SPEI','SPEI','SPEI','STP','interno'])[1 + floor(random()*5)::int],
       cc.clabe,
       ins.clave || lpad((g % 100000000000)::text, 11, '0'),
       ins.ins_id, 'Contraparte ' || (g % 5000), NULL,
       round((50 + 25000 * power(random(), 2))::numeric, 2),
       upper(left(md5(cc.id::text || '-' || g::text), 12)),
       CASE WHEN random() < 0.9 THEN 'SPEI' ELSE 'CODI' END,
       (ARRAY['liquidada','liquidada','liquidada','devuelta','pendiente'])[1 + floor(random()*5)::int],
       t.ts,
       CASE WHEN random() < 0.85 THEN t.ts + (random()*60)::int * INTERVAL '1 second' ELSE NULL END
FROM core.cuenta_captacion cc
CROSS JOIN generate_series(1, 5) g
CROSS JOIN LATERAL (SELECT id AS ins_id, clave FROM core.cat_institucion_spei
                    ORDER BY (cc.id + g + random()) LIMIT 1) ins
CROSS JOIN LATERAL (SELECT (cc.id + g) AS k,
                    (cc.fecha_apertura + (random() * (lab.reloj()::date - cc.fecha_apertura))::int)::timestamptz AS ts) t;

-- Tarjetas
INSERT INTO core.tarjeta
  (cliente_id, cuenta_captacion_id, credito_id, tipo, marca, bin, ultimos_cuatro,
   nombre_tarjetahabiente, fecha_activacion, fecha_expiracion, estado, manufactura, limite_credito)
SELECT cc.cliente_id, cc.id, NULL, 'debito',
       (ARRAY['visa','mastercard','carnet'])[1 + floor(random()*3)::int],
       (ARRAY['411111','515555','558888'])[1 + floor(random()*3)::int],
       lpad(floor(random()*10000)::int::text, 4, '0'),
       cl.nombre, cc.fecha_apertura + (random()*30)::int,
       to_char(cc.fecha_apertura + INTERVAL '4 years', 'MM/YY'),
       (ARRAY['activa','activa','activa','bloqueada'])[1 + floor(random()*4)::int],
       CASE WHEN random() < 0.8 THEN 'fisica' ELSE 'virtual' END,
       NULL
FROM core.cuenta_captacion cc JOIN core.cliente cl ON cl.id = cc.cliente_id;

INSERT INTO core.tarjeta
  (cliente_id, cuenta_captacion_id, credito_id, tipo, marca, bin, ultimos_cuatro,
   nombre_tarjetahabiente, fecha_activacion, fecha_expiracion, estado, manufactura, limite_credito)
SELECT c.cliente_id, NULL, c.id, 'credito',
       (ARRAY['visa','mastercard'])[1 + floor(random()*2)::int],
       (ARRAY['455555','522222'])[1 + floor(random()*2)::int],
       lpad(floor(random()*10000)::int::text, 4, '0'),
       cl.nombre, c.fecha_originacion + (random()*30)::int,
       to_char(c.fecha_originacion + INTERVAL '3 years', 'MM/YY'),
       'activa', 'fisica',
       round((5000 + 50000 * power(random(), 2))::numeric, 2)
FROM core.credito c JOIN core.cliente cl ON cl.id = c.cliente_id
WHERE random() < 0.10;

-- Autorizaciones de tarjeta
INSERT INTO core.autorizacion_tarjeta
  (tarjeta_id, ts, monto, comercio, mcc_id, modo_entrada, tipo, resultado, motivo_rechazo)
SELECT t.id,
       (coalesce(t.fecha_activacion, DATE '2023-01-01')
         + (random() * greatest(1, lab.reloj()::date - coalesce(t.fecha_activacion, DATE '2023-01-01')))::int)::timestamptz
         + (random()*86400)::int * INTERVAL '1 second',
       round((30 + 3000 * power(random(), 2.5))::numeric, 2),
       'Comercio ' || (g % 3000),
       mc.mcc_id,
       (ARRAY['chip','contactless','ecommerce','banda','atm'])[1 + floor(random()*5)::int],
       CASE WHEN x.r1 < 0.15 THEN 'retiro_atm' WHEN x.r1 < 0.18 THEN 'devolucion' ELSE 'compra' END,
       CASE WHEN x.r2 < 0.08 THEN 'rechazada' WHEN x.r2 < 0.09 THEN 'reversada' ELSE 'aprobada' END,
       CASE WHEN x.r2 < 0.08
            THEN (ARRAY['fondos_insuficientes','limite_excedido','tarjeta_bloqueada'])[1 + floor(random()*3)::int]
            ELSE NULL END
FROM core.tarjeta t
CROSS JOIN generate_series(1, 20) g
-- Referenciar t.id Y g (par único por fila) evita que el LATERAL se cachee por g.
CROSS JOIN LATERAL (SELECT id AS mcc_id FROM core.cat_mcc ORDER BY (t.id + g + random()) LIMIT 1) mc
CROSS JOIN LATERAL (SELECT (t.id + g) AS k, random() AS r1, random() AS r2) x;

-- Contabilidad
WITH ins AS (
  INSERT INTO core.asiento (fecha, concepto, origen)
  SELECT c.fecha_originacion::timestamptz, 'Originación crédito ' || c.id, 'originacion'
  FROM core.credito c
  RETURNING id, concepto
)
INSERT INTO core.movimiento_contable (asiento_id, cuenta_id, cargo, abono)
SELECT ins.id, cc.id, mov.cargo, mov.abono
FROM ins
JOIN core.credito c ON c.id = split_part(ins.concepto, ' ', 3)::int
CROSS JOIN LATERAL (VALUES
  ((SELECT id FROM core.cuenta_contable WHERE codigo='1101'), c.monto_originado, 0::numeric),
  ((SELECT id FROM core.cuenta_contable WHERE codigo='1202'), 0::numeric, c.monto_originado)
) mov(cuenta_ref, cargo, abono)
JOIN core.cuenta_contable cc ON cc.id = mov.cuenta_ref;

WITH ins AS (
  INSERT INTO core.asiento (fecha, concepto, origen)
  SELECT p.fecha_pago, 'Pago ' || p.id, 'pago'
  FROM core.pago p
  RETURNING id, concepto
)
INSERT INTO core.movimiento_contable (asiento_id, cuenta_id, cargo, abono)
SELECT ins.id, cc.id, mov.cargo, mov.abono
FROM ins
JOIN core.pago p ON p.id = split_part(ins.concepto, ' ', 2)::int
CROSS JOIN LATERAL (
  SELECT round(p.monto * 0.7, 2) AS cap, p.monto - round(p.monto * 0.7, 2) AS intx
) d
CROSS JOIN LATERAL (VALUES
  ((SELECT id FROM core.cuenta_contable WHERE codigo='1202'), p.monto, 0::numeric),
  ((SELECT id FROM core.cuenta_contable WHERE codigo='1101'), 0::numeric, d.cap),
  ((SELECT id FROM core.cuenta_contable WHERE codigo='4100'), 0::numeric, d.intx)
) mov(cuenta_ref, cargo, abono)
JOIN core.cuenta_contable cc ON cc.id = mov.cuenta_ref;

-- Ops, telemetría
INSERT INTO ops.servicio (nombre, equipo, criticidad) VALUES
  ('api-creditos','core','critica'), ('api-pagos','core','critica'),
  ('api-captacion','core','alta'),   ('api-tarjetas','tarjetas','critica'),
  ('api-spei','pagos','critica'),    ('auth','plataforma','critica'),
  ('notificaciones','plataforma','media'), ('reportes','datos','baja'),
  ('api-clientes','core','alta'),    ('gateway','plataforma','critica'),
  ('batch-nocturno','datos','media'),('webhooks','integraciones','baja');

INSERT INTO ops.despliegue (servicio_id, version, ts, autor, rollback)
SELECT s.id, 'v' || (1 + g % 40) || '.' || (g % 10) || '.0',
       (DATE '2021-01-01' + (random()*1825)::int)::timestamptz + (random()*86400)::int * INTERVAL '1 second',
       (ARRAY['ana','luis','sofia','carlos','marta'])[1 + floor(random()*5)::int],
       random() < 0.1
FROM ops.servicio s CROSS JOIN generate_series(1, 25) g;

INSERT INTO ops.incidente (servicio_id, inicio, fin, severidad, descripcion)
SELECT s.id, t.ini,
       CASE WHEN g = 1 AND s.nombre = 'api-creditos' THEN NULL
            ELSE t.ini + (30 + random()*240)::int * INTERVAL '1 minute' END,
       (ARRAY['sev1','sev2','sev3'])[1 + floor(random()*3)::int],
       'Incidente en ' || s.nombre
FROM ops.servicio s
CROSS JOIN generate_series(1, 3) g
CROSS JOIN LATERAL (SELECT (s.id + g) AS k,
                    (DATE '2021-06-01' + (random()*1600)::int)::timestamptz
                          + (random()*86400)::int * INTERVAL '1 second' AS ini) t;

INSERT INTO ops.peticion (servicio_id, ruta, metodo, status, duracion_ms, ts, credito_id)
SELECT s.id,
       (ARRAY['/v1/creditos','/v1/pagos','/v1/saldo','/v1/transferencias','/health'])[1 + floor(random()*5)::int],
       (ARRAY['GET','POST','GET','GET','POST'])[1 + floor(random()*5)::int],
       CASE WHEN random() < 0.02 THEN 500 WHEN random() < 0.01 THEN 404 ELSE 200 END,
       round((5 + 400 * power(random(), 3))::numeric, 1),
       (DATE '2024-01-01' + (random()*730)::int)::timestamptz + (random()*86400)::int * INTERVAL '1 second',
       CASE WHEN s.nombre IN ('api-creditos','api-pagos') AND random() < 0.5
            THEN 1 + floor(random() * (30000 * :scale))::int ELSE NULL END
FROM ops.servicio s
CROSS JOIN generate_series(1, (208000 * :scale)) g;

INSERT INTO ops.metrica_muestra (servicio_id, nombre, valor, ts)
SELECT s.id,
       (ARRAY['cpu','memoria','rps','latencia_p50'])[1 + floor(random()*4)::int],
       round((random()*100)::numeric, 2),
       (DATE '2025-06-01')::timestamptz + (g % 44640) * INTERVAL '1 minute'
FROM ops.servicio s
CROSS JOIN generate_series(1, (167000 * :scale)) g;
