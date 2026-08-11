-- Llaves foráneas e índices, después de la carga de datos.

-- Se crean aquí (no en el DDL) porque validar FKs y mantener índices durante un bulk
-- insert es mucho más caro que construirlos de una vez al final.

-- Políticas ON DELETE.
--   * RESTRICT en todo lo financiero y contable, nada se borra en cascada.
--   * CASCADE solo donde se podría quizá justificar, como cliente_direccion (dato dependiente).
--   * SET NULL en ops.peticion.credito_id, la telemetría tiene que sobrevivir al crédito.

-- Dos índices se omiten a propósito para el módulo 8 (información más abajo)
\timing on

-- FKs core
ALTER TABLE core.empleado
  ADD CONSTRAINT fk_empleado_sucursal FOREIGN KEY (sucursal_id) REFERENCES core.sucursal(id) ON DELETE RESTRICT,
  ADD CONSTRAINT fk_empleado_jefe     FOREIGN KEY (jefe_id)     REFERENCES core.empleado(id) ON DELETE RESTRICT;

ALTER TABLE core.cliente_direccion
  ADD CONSTRAINT fk_direccion_cliente FOREIGN KEY (cliente_id) REFERENCES core.cliente(id) ON DELETE CASCADE;

ALTER TABLE core.credito
  ADD CONSTRAINT fk_credito_cliente  FOREIGN KEY (cliente_id)        REFERENCES core.cliente(id)          ON DELETE RESTRICT,
  ADD CONSTRAINT fk_credito_producto FOREIGN KEY (producto_id)       REFERENCES core.producto_credito(id) ON DELETE RESTRICT,
  ADD CONSTRAINT fk_credito_sucursal FOREIGN KEY (sucursal_id)       REFERENCES core.sucursal(id)         ON DELETE RESTRICT,
  ADD CONSTRAINT fk_credito_empleado FOREIGN KEY (empleado_id)       REFERENCES core.empleado(id)         ON DELETE RESTRICT,
  ADD CONSTRAINT fk_credito_origen   FOREIGN KEY (credito_origen_id) REFERENCES core.credito(id)          ON DELETE RESTRICT;

ALTER TABLE core.amortizacion
  ADD CONSTRAINT fk_amortizacion_credito FOREIGN KEY (credito_id) REFERENCES core.credito(id) ON DELETE RESTRICT;

ALTER TABLE core.pago
  ADD CONSTRAINT fk_pago_credito FOREIGN KEY (credito_id) REFERENCES core.credito(id) ON DELETE RESTRICT;

ALTER TABLE core.aplicacion_pago
  ADD CONSTRAINT fk_aplicacion_pago         FOREIGN KEY (pago_id)         REFERENCES core.pago(id)         ON DELETE RESTRICT,
  ADD CONSTRAINT fk_aplicacion_amortizacion FOREIGN KEY (amortizacion_id) REFERENCES core.amortizacion(id) ON DELETE RESTRICT;

ALTER TABLE core.credito_estado_hist
  ADD CONSTRAINT fk_ceh_credito FOREIGN KEY (credito_id) REFERENCES core.credito(id) ON DELETE RESTRICT;

ALTER TABLE core.cuenta_captacion
  ADD CONSTRAINT fk_cuentacap_cliente FOREIGN KEY (cliente_id)             REFERENCES core.cliente(id)             ON DELETE RESTRICT,
  ADD CONSTRAINT fk_cuentacap_esquema FOREIGN KEY (esquema_rendimiento_id) REFERENCES core.esquema_rendimiento(id) ON DELETE RESTRICT;

ALTER TABLE core.movimiento_captacion
  ADD CONSTRAINT fk_movcap_cuenta FOREIGN KEY (cuenta_id) REFERENCES core.cuenta_captacion(id) ON DELETE RESTRICT;

ALTER TABLE core.pago_rendimiento
  ADD CONSTRAINT fk_rend_cuenta FOREIGN KEY (cuenta_id) REFERENCES core.cuenta_captacion(id) ON DELETE RESTRICT;

ALTER TABLE core.transferencia
  ADD CONSTRAINT fk_transf_cuenta     FOREIGN KEY (cuenta_captacion_id) REFERENCES core.cuenta_captacion(id)    ON DELETE RESTRICT,
  ADD CONSTRAINT fk_transf_institucion FOREIGN KEY (institucion_id)     REFERENCES core.cat_institucion_spei(id) ON DELETE RESTRICT;

ALTER TABLE core.tarjeta
  ADD CONSTRAINT fk_tarjeta_cliente FOREIGN KEY (cliente_id)          REFERENCES core.cliente(id)          ON DELETE RESTRICT,
  ADD CONSTRAINT fk_tarjeta_cuenta  FOREIGN KEY (cuenta_captacion_id) REFERENCES core.cuenta_captacion(id) ON DELETE RESTRICT,
  ADD CONSTRAINT fk_tarjeta_credito FOREIGN KEY (credito_id)          REFERENCES core.credito(id)          ON DELETE RESTRICT;

ALTER TABLE core.autorizacion_tarjeta
  ADD CONSTRAINT fk_aut_tarjeta FOREIGN KEY (tarjeta_id) REFERENCES core.tarjeta(id) ON DELETE RESTRICT,
  ADD CONSTRAINT fk_aut_mcc     FOREIGN KEY (mcc_id)     REFERENCES core.cat_mcc(id) ON DELETE RESTRICT;

ALTER TABLE core.cuenta_contable
  ADD CONSTRAINT fk_cuentacont_padre FOREIGN KEY (padre_id) REFERENCES core.cuenta_contable(id) ON DELETE RESTRICT;

ALTER TABLE core.movimiento_contable
  ADD CONSTRAINT fk_movcont_asiento FOREIGN KEY (asiento_id) REFERENCES core.asiento(id)         ON DELETE RESTRICT,
  ADD CONSTRAINT fk_movcont_cuenta  FOREIGN KEY (cuenta_id)  REFERENCES core.cuenta_contable(id) ON DELETE RESTRICT;

-- FKs ops
ALTER TABLE ops.despliegue
  ADD CONSTRAINT fk_despliegue_servicio FOREIGN KEY (servicio_id) REFERENCES ops.servicio(id) ON DELETE RESTRICT;
ALTER TABLE ops.peticion
  ADD CONSTRAINT fk_peticion_servicio FOREIGN KEY (servicio_id) REFERENCES ops.servicio(id)  ON DELETE RESTRICT,
  ADD CONSTRAINT fk_peticion_credito  FOREIGN KEY (credito_id)  REFERENCES core.credito(id)  ON DELETE SET NULL;
ALTER TABLE ops.incidente
  ADD CONSTRAINT fk_incidente_servicio FOREIGN KEY (servicio_id) REFERENCES ops.servicio(id) ON DELETE RESTRICT;
ALTER TABLE ops.metrica_muestra
  ADD CONSTRAINT fk_metrica_servicio FOREIGN KEY (servicio_id) REFERENCES ops.servicio(id) ON DELETE RESTRICT;

-- Índices
-- (Las UNIQUE de amortizacion(credito_id,num_cuota) y movimiento_captacion(cuenta_id,folio)
--  ya indexan su columna líder y no se duplican.)

CREATE INDEX ix_credito_cliente      ON core.credito(cliente_id);
CREATE INDEX ix_credito_sucursal     ON core.credito(sucursal_id);
CREATE INDEX ix_credito_empleado     ON core.credito(empleado_id);
CREATE INDEX ix_credito_producto     ON core.credito(producto_id);
CREATE INDEX ix_credito_originacion  ON core.credito(fecha_originacion);
CREATE INDEX ix_credito_estado       ON core.credito(estado);

-- OMITIDO A PROPÓSITO para el ejercicio E58
-- No se crea el índice core.pago(credito_id). La búsqueda de pagos por crédito
-- provoca un Seq Scan costoso, y el ejercicio E58 pide detectarlo y proponer el índice.
-- CREATE INDEX ix_pago_credito ON core.pago(credito_id);

CREATE INDEX ix_aplicacion_pago         ON core.aplicacion_pago(pago_id);
CREATE INDEX ix_aplicacion_amortizacion ON core.aplicacion_pago(amortizacion_id);

CREATE INDEX ix_cuentacap_cliente   ON core.cuenta_captacion(cliente_id);
CREATE INDEX ix_rend_cuenta         ON core.pago_rendimiento(cuenta_id);
CREATE INDEX ix_transf_cuenta       ON core.transferencia(cuenta_captacion_id);
CREATE INDEX ix_transf_institucion  ON core.transferencia(institucion_id);
CREATE INDEX ix_tarjeta_cliente     ON core.tarjeta(cliente_id);
CREATE INDEX ix_tarjeta_cuenta      ON core.tarjeta(cuenta_captacion_id);
CREATE INDEX ix_tarjeta_credito     ON core.tarjeta(credito_id);
CREATE INDEX ix_aut_tarjeta         ON core.autorizacion_tarjeta(tarjeta_id);
CREATE INDEX ix_aut_mcc             ON core.autorizacion_tarjeta(mcc_id);
CREATE INDEX ix_movcont_asiento     ON core.movimiento_contable(asiento_id);
CREATE INDEX ix_movcont_cuenta      ON core.movimiento_contable(cuenta_id);
CREATE INDEX ix_cuentacont_padre    ON core.cuenta_contable(padre_id);

CREATE INDEX ix_despliegue_servicio ON ops.despliegue(servicio_id);
CREATE INDEX ix_peticion_servicio   ON ops.peticion(servicio_id);
CREATE INDEX ix_peticion_ts         ON ops.peticion(ts);
CREATE INDEX ix_incidente_servicio  ON ops.incidente(servicio_id);
CREATE INDEX ix_metrica_servicio    ON ops.metrica_muestra(servicio_id);

-- OMITIDO A PROPÓSITO para el ejercicio E60
-- No se crea el índice compuesto ops.peticion(credito_id, ts). El ejercicio E60
-- pide compararlo contra dos índices simples y medir el efecto de ANALYZE.
-- CREATE INDEX ix_peticion_credito_ts ON ops.peticion(credito_id, ts);
