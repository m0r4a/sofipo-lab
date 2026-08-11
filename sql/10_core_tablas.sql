-- DDL del esquema de negocio (core).

-- Convenciones:
--   * Llaves sustitutas con bigint GENERATED ALWAYS AS IDENTITY (nunca SERIAL).
--   * Dinero en numeric(18,2). Tasas en numeric(6,4) como fracción (0.3600 = 36%).
--   * Instantes en timestamptz. Fechas de calendario en date.
--
-- Las llaves foráneas NO se van a declarar aquí, se agregan en 50_indices.sql después de
-- la carga de datos, con las políticas de ON DELETE. Las validaciones de FKs durante un bulk insert
-- son pesadas y construirlas una vez al final es más barato. Pero sí pondré las PK,
-- CHECK, UNIQUE, columnas generadas y el EXCLUDE, porque son el contrato de
-- integridad de los datos.

CREATE TABLE IF NOT EXISTS core.sucursal (
  id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo         text NOT NULL UNIQUE,
  nombre         text NOT NULL,
  ciudad         text,
  estado         text,
  fecha_apertura date NOT NULL,
  fecha_cierre   date,
  CONSTRAINT ck_sucursal_cierre CHECK (fecha_cierre IS NULL OR fecha_cierre >= fecha_apertura)
);

CREATE TABLE IF NOT EXISTS core.empleado (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sucursal_id   bigint NOT NULL,
  jefe_id       bigint,
  nombre        text NOT NULL,
  puesto        text,
  fecha_ingreso date NOT NULL,
  activo        boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS core.cliente (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  curp             text NOT NULL UNIQUE,       -- 18 chars, es info falsa, es inválida a propósito
  rfc              text,                        -- 13 chars, es también falso y puede faltar
  nombre           text NOT NULL,
  fecha_nacimiento date NOT NULL,
  ingreso_mensual  numeric(18,2),              -- NULL a propósito en parte de los clientes
  fecha_alta       date NOT NULL,
  CONSTRAINT ck_cliente_ingreso CHECK (ingreso_mensual IS NULL OR ingreso_mensual >= 0)
);

CREATE TABLE IF NOT EXISTS core.cliente_direccion (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cliente_id   bigint NOT NULL,
  calle        text,
  ciudad       text,
  estado       text,
  cp           text,
  es_principal boolean NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS core.producto_credito (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo             text NOT NULL UNIQUE,
  nombre             text NOT NULL,
  tasa_nominal_anual numeric(6,4) NOT NULL,
  plazo_min          int NOT NULL,
  plazo_max          int NOT NULL,
  monto_min          numeric(18,2) NOT NULL,
  monto_max          numeric(18,2) NOT NULL,
  comision_apertura  numeric(6,4) NOT NULL DEFAULT 0,
  CONSTRAINT ck_producto_tasa  CHECK (tasa_nominal_anual > 0 AND tasa_nominal_anual < 2.0),
  CONSTRAINT ck_producto_plazo CHECK (plazo_min >= 1 AND plazo_max >= plazo_min),
  CONSTRAINT ck_producto_monto CHECK (monto_min > 0 AND monto_max >= monto_min)
);

CREATE TABLE IF NOT EXISTS core.credito (
  id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cliente_id        bigint NOT NULL,
  producto_id       bigint NOT NULL,
  sucursal_id       bigint NOT NULL,
  empleado_id       bigint NOT NULL,
  credito_origen_id bigint,                    -- si es reestructura, apunta al crédito anterior
  monto_originado   numeric(18,2) NOT NULL,
  tasa_pactada      numeric(6,4) NOT NULL,
  plazo_meses       int NOT NULL,
  fecha_originacion date NOT NULL,
  estado            text NOT NULL,
  CONSTRAINT ck_credito_monto  CHECK (monto_originado > 0),
  CONSTRAINT ck_credito_tasa   CHECK (tasa_pactada > 0 AND tasa_pactada < 2.0),
  CONSTRAINT ck_credito_plazo  CHECK (plazo_meses >= 1),
  CONSTRAINT ck_credito_estado CHECK (estado IN ('vigente','atrasado','vencido','castigado','liquidado'))
);

CREATE TABLE IF NOT EXISTS core.amortizacion (
  id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  credito_id        bigint NOT NULL,
  num_cuota         int NOT NULL,
  fecha_vencimiento date NOT NULL,
  cuota             numeric(18,2) NOT NULL,
  capital           numeric(18,2) NOT NULL,
  interes           numeric(18,2) NOT NULL,
  saldo_final       numeric(18,2) NOT NULL,
  -- Es una columna generada. El total del período es siempre capital + interés.
  total_periodo     numeric(18,2) GENERATED ALWAYS AS (capital + interes) STORED,
  CONSTRAINT uq_amortizacion_cuota UNIQUE (credito_id, num_cuota),
  CONSTRAINT ck_amortizacion_cuota   CHECK (num_cuota >= 1),
  CONSTRAINT ck_amortizacion_capital CHECK (capital >= 0),
  CONSTRAINT ck_amortizacion_interes CHECK (interes >= 0)
);

-- Dinero que entra del acreditado. Un pago no toca las cuotas directamente y su
-- reparto entre renglones de amortización vive en core.aplicacion_pago.
CREATE TABLE IF NOT EXISTS core.pago (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  credito_id bigint NOT NULL,
  fecha_pago timestamptz NOT NULL,
  monto      numeric(18,2) NOT NULL,
  canal      text,
  referencia text,                            -- los duplicados por error repiten referencia
  CONSTRAINT ck_pago_monto CHECK (monto > 0),
  CONSTRAINT ck_pago_canal CHECK (canal IS NULL OR canal IN ('ventanilla','app','transferencia','domiciliacion'))
);

CREATE TABLE IF NOT EXISTS core.aplicacion_pago (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  pago_id            bigint NOT NULL,
  amortizacion_id    bigint NOT NULL,
  monto_aplicado     numeric(18,2) NOT NULL,
  aplicado_a_capital numeric(18,2) NOT NULL DEFAULT 0,
  aplicado_a_interes numeric(18,2) NOT NULL DEFAULT 0,
  CONSTRAINT ck_aplicacion_monto CHECK (monto_aplicado > 0),
  CONSTRAINT ck_aplicacion_desglose CHECK (aplicado_a_capital >= 0 AND aplicado_a_interes >= 0)
);

-- Un renglón por cada periodo en que el crédito tuvo un estado. El estado vigente
-- es el del periodo abierto (valido_hasta NULL). El EXCLUDE de abajo es lo que
-- impide que los periodos de un mismo crédito se traslapen.
CREATE TABLE IF NOT EXISTS core.credito_estado_hist (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  credito_id   bigint NOT NULL,
  estado       text NOT NULL,
  valido_desde timestamptz NOT NULL,
  valido_hasta timestamptz,                   -- NULL significa que el periodo es abierto
  CONSTRAINT ck_ceh_estado CHECK (estado IN ('vigente','atrasado','vencido','castigado','liquidado')),
  CONSTRAINT ck_ceh_rango  CHECK (valido_hasta IS NULL OR valido_hasta > valido_desde),
  -- Impide que un mismo crédito tenga dos períodos de estado que se traslapen en el
  -- tiempo. tstzrange con límite superior NULL = "hasta infinito".
  CONSTRAINT ex_ceh_sin_traslape EXCLUDE USING gist (
    credito_id WITH =,
    tstzrange(valido_desde, valido_hasta) WITH &&
  )
);

-- Aquí están los parámetros con que se calcula el interés de una cuenta, como la
-- tasa, la periodicidad y si son 360 o 365 días. cuenta_captacion lo referencia y
-- si la cuenta no lo trae, no genera rendimiento.
CREATE TABLE IF NOT EXISTS core.esquema_rendimiento (
  id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre            text NOT NULL,
  tasa_anual        numeric(6,4) NOT NULL,
  periodicidad_pago text NOT NULL,
  dias_base         int NOT NULL,             -- 360 o 365 (convención de conteo de días)
  isr_exento        boolean NOT NULL DEFAULT false,
  CONSTRAINT ck_esquema_tasa  CHECK (tasa_anual >= 0 AND tasa_anual < 2.0),
  CONSTRAINT ck_esquema_perio CHECK (periodicidad_pago IN ('diaria','mensual','al_vencimiento')),
  CONSTRAINT ck_esquema_dias  CHECK (dias_base IN (360, 365))
);

-- Cuentas de depósito del cliente. Una cuenta 'vista' está disponible y una 'plazo'
-- queda comprometida. El saldo de esta tabla es un acumulado y los depósitos y retiros
-- que lo mueven están en core.movimiento_captacion.
CREATE TABLE IF NOT EXISTS core.cuenta_captacion (
  id                     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cliente_id             bigint NOT NULL,
  clabe                  text NOT NULL UNIQUE, -- 18 dígitos, también falsa
  tipo                   text NOT NULL,
  saldo                  numeric(18,2) NOT NULL DEFAULT 0,
  esquema_rendimiento_id bigint,              -- NULL si la cuenta no genera rendimientos
  fecha_apertura         date NOT NULL,
  CONSTRAINT ck_cuentacap_tipo CHECK (tipo IN ('vista','plazo'))
);

-- Cada alta o baja de saldo de una cuenta. El folio es consecutivo por cuenta y no
-- global, y por eso el UNIQUE es (cuenta_id, folio) y no solo folio.
CREATE TABLE IF NOT EXISTS core.movimiento_captacion (
  id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cuenta_id bigint NOT NULL,
  folio     bigint NOT NULL,
  fecha     timestamptz NOT NULL,
  tipo      text NOT NULL,
  monto     numeric(18,2) NOT NULL,
  CONSTRAINT uq_movcap_folio UNIQUE (cuenta_id, folio),
  CONSTRAINT ck_movcap_tipo  CHECK (tipo IN ('deposito','retiro')),
  CONSTRAINT ck_movcap_monto CHECK (monto > 0)
);

-- Interés que el banco paga sobre la captación, al revés de core.pago. Guarda todo el
-- cálculo, como los días, el saldo promedio, el bruto, el ISR retenido y el neto. El
-- CHECK obliga a que el neto sea el bruto menos el ISR, así no entra un desglose que
-- no cuadre.
CREATE TABLE IF NOT EXISTS core.pago_rendimiento (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cuenta_id        bigint NOT NULL,
  fecha            date NOT NULL,
  dias_computados  int NOT NULL,
  saldo_promedio   numeric(18,2) NOT NULL,
  rendimiento_bruto numeric(18,2) NOT NULL,
  isr_retenido     numeric(18,2) NOT NULL DEFAULT 0,
  rendimiento_neto numeric(18,2) NOT NULL,
  CONSTRAINT ck_rend_dias  CHECK (dias_computados > 0),
  CONSTRAINT ck_rend_isr   CHECK (isr_retenido >= 0),
  -- El neto es siempre bruto menos la retención de ISR.
  CONSTRAINT ck_rend_neto  CHECK (rendimiento_neto = rendimiento_bruto - isr_retenido)
);

-- Participantes de SPEI. core.transferencia apunta aquí
-- vía institucion_id. Las banderas permite_* sirven para simular rechazos.
CREATE TABLE IF NOT EXISTS core.cat_institucion_spei (
  id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  clave                 text NOT NULL UNIQUE,  -- clave del participante SPEI, suponiendo que es banco y no usa STP.
  participante          text NOT NULL,
  abm_code              text,
  permite_transferencia boolean NOT NULL DEFAULT true,
  permite_deposito      boolean NOT NULL DEFAULT true
);

-- Catálogo MCC del estándar ISO 18245, que clasifica el giro del comercio. Lo consume
-- core.autorizacion_tarjeta.mcc_id para saber en qué se gastó.
CREATE TABLE IF NOT EXISTS core.cat_mcc (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  mcc         text NOT NULL UNIQUE,           -- 4 dígitos según el ISO 18245
  descripcion text NOT NULL,
  giro        text
);

-- Cada renglón es una sola pata, 'enviada' o 'recibida'. cuenta_captacion_id es
-- siempre nuestro lado y la contraparte va en los campos clabe_, nombre_ y rfc_curp_.
-- Una recibida deja el ordenante en clabe_ordenante y una enviada, el beneficiario.
CREATE TABLE IF NOT EXISTS core.transferencia (
  id                   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cuenta_captacion_id  bigint NOT NULL,        -- el lado interno (nuestra cuenta)
  direccion            text NOT NULL,
  rail                 text NOT NULL,
  clabe_ordenante      text,
  clabe_beneficiario   text,
  institucion_id       bigint,                 -- banco contraparte (cat_institucion_spei)
  nombre_contraparte   text,
  rfc_curp_contraparte text,
  monto                numeric(18,2) NOT NULL,
  clave_rastreo        text NOT NULL,
  tipo_pago            text NOT NULL,
  estado               text NOT NULL,
  ts_operacion         timestamptz NOT NULL,
  fecha_liquidacion    timestamptz,
  CONSTRAINT ck_transf_direccion CHECK (direccion IN ('enviada','recibida')),
  CONSTRAINT ck_transf_rail      CHECK (rail IN ('SPEI','STP','interno')),
  CONSTRAINT ck_transf_tipo      CHECK (tipo_pago IN ('SPEI','CODI')),
  CONSTRAINT ck_transf_estado    CHECK (estado IN ('liquidada','devuelta','pendiente')),
  CONSTRAINT ck_transf_monto     CHECK (monto > 0),
  -- La misma llave que se usa de verdad. Un participante no repite clave de
  -- rastreo el mismo día. La expresión ts_operacion::date se indexa como UNIQUE.
  CONSTRAINT uq_transf_rastreo UNIQUE (institucion_id, clave_rastreo, ts_operacion)
);

-- Débito y crédito estarán en la misma tabla, así que la columna de fondeo depende
-- del tipo. Una de débito descuenta de cuenta_captacion_id y una de crédito consume
-- limite_credito, y eso lo obliga ck_tarjeta_fondeo. Nunca se guarda el PAN completo,
-- solo el BIN y los últimos cuatro.
CREATE TABLE IF NOT EXISTS core.tarjeta (
  id                     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cliente_id             bigint NOT NULL,
  cuenta_captacion_id    bigint,              -- débito, cuenta de la que descuenta
  credito_id             bigint,              -- crédito, línea revolvente asociada
  tipo                   text NOT NULL,
  marca                  text NOT NULL,
  bin                    text,                -- primeros 6 dígitos
  ultimos_cuatro         text,               -- nunca se guarda el PAN completo
  nombre_tarjetahabiente text,
  fecha_activacion       date,
  fecha_expiracion       text,               -- formato MM/YY
  estado                 text NOT NULL,
  manufactura            text,
  limite_credito         numeric(18,2),      -- solo tarjetas de crédito
  CONSTRAINT ck_tarjeta_tipo   CHECK (tipo IN ('debito','credito')),
  CONSTRAINT ck_tarjeta_marca  CHECK (marca IN ('visa','mastercard','carnet')),
  CONSTRAINT ck_tarjeta_estado CHECK (estado IN ('init','activa','bloqueada','expirada','cancelada')),
  CONSTRAINT ck_tarjeta_manuf  CHECK (manufactura IS NULL OR manufactura IN ('fisica','virtual')),
  -- Una tarjeta de débito debe apuntar a una cuenta y una de crédito, a un límite.
  CONSTRAINT ck_tarjeta_fondeo CHECK (
    (tipo = 'debito'  AND cuenta_captacion_id IS NOT NULL) OR
    (tipo = 'credito' AND limite_credito IS NOT NULL)
  )
);

-- Autorizaciones de tarjeta (como en ISO 8583)
CREATE TABLE IF NOT EXISTS core.autorizacion_tarjeta (
  id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tarjeta_id     bigint NOT NULL,
  ts             timestamptz NOT NULL,
  monto          numeric(18,2) NOT NULL,
  comercio       text,
  mcc_id         bigint,
  modo_entrada   text,
  tipo           text NOT NULL,
  resultado      text NOT NULL,
  motivo_rechazo text,                        -- NULL salvo que resultado = rechazada
  CONSTRAINT ck_aut_monto     CHECK (monto > 0),
  CONSTRAINT ck_aut_modo      CHECK (modo_entrada IS NULL OR modo_entrada IN ('chip','banda','contactless','ecommerce','atm')),
  CONSTRAINT ck_aut_tipo      CHECK (tipo IN ('compra','retiro_atm','devolucion')),
  CONSTRAINT ck_aut_resultado CHECK (resultado IN ('aprobada','rechazada','reversada')),
  CONSTRAINT ck_aut_rechazo   CHECK (
    (resultado = 'rechazada' AND motivo_rechazo IS NOT NULL) OR
    (resultado <> 'rechazada' AND motivo_rechazo IS NULL)
  )
);

-- Plan de cuentas jerárquico. padre_id apunta a otra fila de esta misma tabla y las
-- cuentas raíz lo traen en NULL. Recorrerlo hacia arriba y hacia abajo es el caso de
-- WITH RECURSIVE del curso.
CREATE TABLE IF NOT EXISTS core.cuenta_contable (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo     text NOT NULL UNIQUE,
  nombre     text NOT NULL,
  padre_id   bigint,                          -- NULL en las cuentas raíz (segundo caso recursivo)
  naturaleza text NOT NULL,
  CONSTRAINT ck_cuentacont_nat CHECK (naturaleza IN ('deudora','acreedora'))
);

-- Encabezado de la póliza, con la fecha, el concepto y de dónde salió (origen). El
-- detalle con cargos y abonos está en core.movimiento_contable, un asiento a muchos
-- renglones.
CREATE TABLE IF NOT EXISTS core.asiento (
  id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fecha    timestamptz NOT NULL,
  concepto text,
  origen   text
);

-- Renglones de cada asiento. Cada uno pega en una cuenta_contable con un cargo o un
-- abono, como dice el CHECK de partida doble de más abajo.
CREATE TABLE IF NOT EXISTS core.movimiento_contable (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  asiento_id bigint NOT NULL,
  cuenta_id  bigint NOT NULL,
  cargo      numeric(18,2) NOT NULL DEFAULT 0,
  abono      numeric(18,2) NOT NULL DEFAULT 0,
  -- Partida doble a nivel renglón, o es cargo, o es abono, nunca ambos ni ninguno.
  -- Que el asiento COMPLETO cuadre (sum(cargo)=sum(abono)) es invariante de query,
  -- no de CHECK, y es el ejercicio E20.
  CONSTRAINT ck_movcont_partida CHECK (
    (cargo = 0 AND abono > 0) OR (cargo > 0 AND abono = 0)
  )
);

-- Tasa de referencia diaria (TIIE), con huecos en fines de semana
CREATE TABLE IF NOT EXISTS core.tasa_referencia (
  fecha date PRIMARY KEY,
  tiie  numeric(6,4) NOT NULL,
  CONSTRAINT ck_tasaref_tiie CHECK (tiie > 0)
);
