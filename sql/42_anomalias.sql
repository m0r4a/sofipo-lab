-- Anomalías didácticas deliberadas.
--
-- Estas anomalías se insertan a propósito y no se documentan en docs/, el alumno
-- debe descubrirlas. Cada una alimenta uno o más ejercicios. Aquí, en el código, sí
-- se explican para quien mantiene el laboratorio.
--
-- Determinista y sin random(). Objetivos elegidos por id fijo.

-- (1) Dos clientes con NOMBRE idéntico y CURP distinta.
--     Agrupar por nombre en vez de por id da conteos y sumas incorrectos.
INSERT INTO core.cliente (curp, rfc, nombre, fecha_nacimiento, ingreso_mensual, fecha_alta) VALUES
  ('GAPJ800101HDFXXX01', 'GAPJ800101AA1', 'Jorge García Nombre Repetido', DATE '1980-01-01', 15000, DATE '2021-03-01'),
  ('GAPJ800101HDFXXX02', 'GAPJ800101BB2', 'Jorge García Nombre Repetido', DATE '1985-07-15', 22000, DATE '2022-09-10');

-- (2) Un cliente con ESPACIOS al inicio y al final del nombre.
--     Un filtro con = falla y trim() funciona.
INSERT INTO core.cliente (curp, rfc, nombre, fecha_nacimiento, ingreso_mensual, fecha_alta) VALUES
  ('SPCE900202MDFXXX03', NULL, '  Cliente Con Espacios  ', DATE '1990-02-02', 9000, DATE '2023-01-20');

-- (3) Pagos SIN aplicación registrada (huérfanos lógicos).
--     Existen en pago pero no tienen filas en aplicacion_pago.
--     Un INNER JOIN de pago con aplicacion_pago los esconde y hay que buscarlos con NOT EXISTS.
INSERT INTO core.pago (credito_id, fecha_pago, monto, canal, referencia)
SELECT 1, TIMESTAMPTZ '2024-05-10 10:00:00-06', 500.00, 'ventanilla', 'HUERFANO-' || g
FROM generate_series(1, 5) g;

-- (4) Una cuota con aplicación DUPLICADA.
--     Se duplica una fila existente de aplicacion_pago. Si sumas monto_aplicado por
--     cuota sin cuidado, la cifra queda inflada. Elegimos la primera aplicación.
INSERT INTO core.aplicacion_pago (pago_id, amortizacion_id, monto_aplicado, aplicado_a_capital, aplicado_a_interes)
SELECT pago_id, amortizacion_id, monto_aplicado, aplicado_a_capital, aplicado_a_interes
FROM core.aplicacion_pago ORDER BY id LIMIT 1;

-- (5) Un asiento contable que NO cuadra (sum(cargo) <> sum(abono)).
--     Lo detecta el ejercicio de partida doble (E20).
WITH a AS (
  INSERT INTO core.asiento (fecha, concepto, origen)
  VALUES (TIMESTAMPTZ '2024-07-01 09:00:00-06', 'Asiento descuadrado (anomalía)', 'ajuste')
  RETURNING id
)
INSERT INTO core.movimiento_contable (asiento_id, cuenta_id, cargo, abono)
SELECT a.id, cc.id, m.cargo, m.abono
FROM a
CROSS JOIN LATERAL (VALUES
  ((SELECT id FROM core.cuenta_contable WHERE codigo='1202'), 1000.00::numeric, 0::numeric),
  ((SELECT id FROM core.cuenta_contable WHERE codigo='4100'), 0::numeric, 900.00::numeric)  -- falta 100
) m(cuenta_ref, cargo, abono)
JOIN core.cuenta_contable cc ON cc.id = m.cuenta_ref;

-- (6) Pagos en la FRONTERA DE ZONA HORARIA (cerca de medianoche local).
--     23:45 hora de México cae al día siguiente en UTC, así que date_trunc con y sin
--     AT TIME ZONE dan días distintos.
INSERT INTO core.pago (credito_id, fecha_pago, monto, canal, referencia) VALUES
  (2, TIMESTAMPTZ '2024-06-15 23:45:00-06', 1000.00, 'app', 'TZ-BORDE-1'),
  (2, TIMESTAMPTZ '2024-06-16 00:15:00-06', 1000.00, 'app', 'TZ-BORDE-2');

-- (7) Una muestra de métrica con VALOR NEGATIVO (sin sentido físico).
--     ops.metrica_muestra.valor no tiene CHECK de rango a propósito, un recordatorio
--     de validar rangos. (Las tasas de crédito/TIIE sí están protegidas por CHECK,
--     así que la anomalía de "valor negativo" vive aquí, donde es insertable.)
INSERT INTO ops.metrica_muestra (servicio_id, nombre, valor, ts)
SELECT id, 'latencia_p50', -42.00, TIMESTAMPTZ '2025-06-15 12:00:00-06'
FROM ops.servicio WHERE nombre = 'api-creditos';

-- Otras anomalías ya existen por construcción y no se insertan aquí.
--   * SUC-039 sin créditos (LEFT JOIN la revela). Viene de 40 y 41.
--   * Clientes sin crédito y créditos con ingreso NULL. Viene de 41.
--   * ~0.3% de pagos parciales o duplicados por comportamiento. Viene de 41.
