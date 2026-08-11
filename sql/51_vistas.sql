-- Vistas de apoyo y una vista materializada. Son ayudas de consulta, no soluciones
-- de ejercicios. Se crean tras los índices.

-- Resumen de pagos por crédito, cuántos pagos y cuánto se ha recibido.
CREATE OR REPLACE VIEW core.v_credito_pagos AS
SELECT c.id AS credito_id,
       c.monto_originado,
       count(p.id)              AS num_pagos,
       coalesce(sum(p.monto),0) AS total_pagado
FROM core.credito c
LEFT JOIN core.pago p ON p.credito_id = c.id
GROUP BY c.id, c.monto_originado;
COMMENT ON VIEW core.v_credito_pagos IS 'Por crédito, el número de pagos recibidos y el monto total pagado (LEFT JOIN para no perder créditos sin pagos).';

-- Saldo de cada cuenta de captación calculado desde sus movimientos.
CREATE OR REPLACE VIEW core.v_saldo_cuenta AS
SELECT cc.id AS cuenta_id,
       cc.clabe,
       cc.saldo AS saldo_registrado,
       coalesce(sum(CASE WHEN m.tipo = 'deposito' THEN m.monto
                         WHEN m.tipo = 'retiro'   THEN -m.monto END), 0) AS saldo_calculado
FROM core.cuenta_captacion cc
LEFT JOIN core.movimiento_captacion m ON m.cuenta_id = cc.id
GROUP BY cc.id, cc.clabe, cc.saldo;
COMMENT ON VIEW core.v_saldo_cuenta IS 'Saldo por cuenta calculado desde los movimientos (deposito suma, retiro resta), junto al saldo registrado.';

-- Último pago de cada crédito (patrón DISTINCT ON, útil como referencia rápida).
CREATE OR REPLACE VIEW core.v_ultimo_pago AS
SELECT DISTINCT ON (p.credito_id)
       p.credito_id, p.id AS pago_id, p.fecha_pago, p.monto, p.canal
FROM core.pago p
ORDER BY p.credito_id, p.fecha_pago DESC;
COMMENT ON VIEW core.v_ultimo_pago IS 'El pago más reciente de cada crédito, vía DISTINCT ON.';

-- Materializada con la originación mensual por producto. Cara de recalcular y útil para
-- reportes, se refresca con REFRESH MATERIALIZED VIEW.
CREATE MATERIALIZED VIEW IF NOT EXISTS core.mv_originacion_mensual AS
SELECT date_trunc('month', c.fecha_originacion)::date AS mes,
       pc.codigo AS producto,
       count(*)               AS num_creditos,
       sum(c.monto_originado) AS monto_originado
FROM core.credito c
JOIN core.producto_credito pc ON pc.id = c.producto_id
GROUP BY 1, 2
WITH DATA;
COMMENT ON MATERIALIZED VIEW core.mv_originacion_mensual IS 'Colocación (número y monto) por mes y producto. Refrescar con REFRESH MATERIALIZED VIEW.';

CREATE UNIQUE INDEX ix_mv_originacion ON core.mv_originacion_mensual(mes, producto);
