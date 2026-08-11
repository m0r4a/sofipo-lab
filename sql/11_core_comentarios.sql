-- COMMENT ON de todo el esquema core, para cada tabla y cada columna.

-- Los comentarios explican el porqué o el matiz de negocio, sin repetir el nombre.
-- `\d+ tabla` en psql basta para orientarse. docs/modelo-datos.md se mantiene a
-- partir de estos comentarios.

-- sucursal
COMMENT ON TABLE  core.sucursal IS 'Sucursales de la SOFIPO. Incluye a propósito una sin créditos y una cerrada, para ejercicios de LEFT JOIN.';
COMMENT ON COLUMN core.sucursal.codigo IS 'Clave corta de negocio de la sucursal (p. ej. SUC-001), estable y legible.';
COMMENT ON COLUMN core.sucursal.nombre IS 'Nombre comercial de la sucursal.';
COMMENT ON COLUMN core.sucursal.ciudad IS 'Ciudad donde opera la sucursal.';
COMMENT ON COLUMN core.sucursal.estado IS 'Entidad federativa de la sucursal.';
COMMENT ON COLUMN core.sucursal.fecha_apertura IS 'Fecha en que la sucursal empezó a operar.';
COMMENT ON COLUMN core.sucursal.fecha_cierre IS 'Fecha de cierre, NULL si sigue abierta. Distingue sucursales vigentes de cerradas.';

-- empleado
COMMENT ON TABLE  core.empleado IS 'Asesores de crédito y su cadena de mando. jefe_id se auto-referencia para formar la jerarquía.';
COMMENT ON COLUMN core.empleado.sucursal_id IS 'Sucursal a la que está adscrito el empleado.';
COMMENT ON COLUMN core.empleado.jefe_id IS 'Jefe directo (otro empleado). NULL solo en la cúpula y es la base del CTE recursivo de cadena de mando.';
COMMENT ON COLUMN core.empleado.nombre IS 'Nombre completo del empleado.';
COMMENT ON COLUMN core.empleado.puesto IS 'Puesto del empleado, como asesor, gerente o director.';
COMMENT ON COLUMN core.empleado.fecha_ingreso IS 'Fecha de ingreso a la institución.';
COMMENT ON COLUMN core.empleado.activo IS 'Si el empleado sigue trabajando aquí.';

-- cliente
COMMENT ON TABLE  core.cliente IS 'Personas que reciben crédito y/o abren cuentas de captación. Datos 100% sintéticos.';
COMMENT ON COLUMN core.cliente.curp IS 'CURP sintética de 18 caracteres, con formato plausible pero inválido. Única por cliente.';
COMMENT ON COLUMN core.cliente.rfc IS 'RFC sintético de 13 caracteres. Puede faltar (NULL) en clientes sin registro fiscal capturado.';
COMMENT ON COLUMN core.cliente.nombre IS 'Nombre del cliente. Hay dos clientes con nombre idéntico y CURP distinta a propósito.';
COMMENT ON COLUMN core.cliente.fecha_nacimiento IS 'Fecha de nacimiento. Se usa para calcular la edad al originar.';
COMMENT ON COLUMN core.cliente.ingreso_mensual IS 'Ingreso mensual declarado. NULL a propósito en parte de la base, y sirve de material para COUNT(col) frente a COUNT(*) y AVG.';
COMMENT ON COLUMN core.cliente.fecha_alta IS 'Fecha en que el cliente fue dado de alta.';

-- cliente_direccion
COMMENT ON TABLE  core.cliente_direccion IS 'Domicilios del cliente (uno a muchos). Un cliente puede tener 0, 1 o varios, y sirve para LEFT JOIN y DISTINCT ON.';
COMMENT ON COLUMN core.cliente_direccion.cliente_id IS 'Cliente dueño del domicilio.';
COMMENT ON COLUMN core.cliente_direccion.calle IS 'Calle y número del domicilio.';
COMMENT ON COLUMN core.cliente_direccion.ciudad IS 'Ciudad del domicilio.';
COMMENT ON COLUMN core.cliente_direccion.estado IS 'Entidad federativa del domicilio.';
COMMENT ON COLUMN core.cliente_direccion.cp IS 'Código postal.';
COMMENT ON COLUMN core.cliente_direccion.es_principal IS 'Marca el domicilio principal cuando hay varios.';

-- producto_credito
COMMENT ON TABLE  core.producto_credito IS 'Catálogo de productos de crédito, con sus rangos de plazo, monto, tasa y comisión.';
COMMENT ON COLUMN core.producto_credito.codigo IS 'Clave corta del producto.';
COMMENT ON COLUMN core.producto_credito.nombre IS 'Nombre comercial del producto.';
COMMENT ON COLUMN core.producto_credito.tasa_nominal_anual IS 'Tasa nominal anual como fracción (0.3600 = 36%). No es la tasa efectiva, ver el glosario.';
COMMENT ON COLUMN core.producto_credito.plazo_min IS 'Plazo mínimo en meses.';
COMMENT ON COLUMN core.producto_credito.plazo_max IS 'Plazo máximo en meses.';
COMMENT ON COLUMN core.producto_credito.monto_min IS 'Monto mínimo financiable.';
COMMENT ON COLUMN core.producto_credito.monto_max IS 'Monto máximo financiable.';
COMMENT ON COLUMN core.producto_credito.comision_apertura IS 'Comisión por apertura como fracción del monto originado.';

-- credito
COMMENT ON TABLE  core.credito IS 'Créditos otorgados. Es la cabecera del préstamo y el detalle de cuotas vive en amortizacion.';
COMMENT ON COLUMN core.credito.cliente_id IS 'Cliente acreditado.';
COMMENT ON COLUMN core.credito.producto_id IS 'Producto bajo el que se otorgó.';
COMMENT ON COLUMN core.credito.sucursal_id IS 'Sucursal que colocó el crédito.';
COMMENT ON COLUMN core.credito.empleado_id IS 'Asesor que colocó el crédito.';
COMMENT ON COLUMN core.credito.credito_origen_id IS 'Si es una reestructura, apunta al crédito anterior que se cerró. NULL en créditos originales.';
COMMENT ON COLUMN core.credito.monto_originado IS 'Principal prestado al desembolsar. La suma del capital de todas las cuotas debe igualar este monto.';
COMMENT ON COLUMN core.credito.tasa_pactada IS 'Tasa nominal anual pactada como fracción. Puede diferir de la del producto por promociones.';
COMMENT ON COLUMN core.credito.plazo_meses IS 'Número de cuotas mensuales pactadas.';
COMMENT ON COLUMN core.credito.fecha_originacion IS 'Fecha de desembolso. Base del análisis de cosechas (vintage).';
COMMENT ON COLUMN core.credito.estado IS 'Estado actual del crédito, que puede ser vigente, atrasado, vencido, castigado o liquidado. El historial completo está en credito_estado_hist.';

-- amortizacion
COMMENT ON TABLE  core.amortizacion IS 'Plan de pagos PLANEADO por el sistema francés (cuota fija). Una fila por cuota. Es la tabla más grande.';
COMMENT ON COLUMN core.amortizacion.credito_id IS 'Crédito al que pertenece la cuota.';
COMMENT ON COLUMN core.amortizacion.num_cuota IS 'Número de cuota dentro del crédito, empezando en 1.';
COMMENT ON COLUMN core.amortizacion.fecha_vencimiento IS 'Fecha en que la cuota es exigible.';
COMMENT ON COLUMN core.amortizacion.cuota IS 'Pago programado del período (capital + interés). Fijo en el sistema francés.';
COMMENT ON COLUMN core.amortizacion.capital IS 'Parte de la cuota que amortiza principal. Crece con el tiempo.';
COMMENT ON COLUMN core.amortizacion.interes IS 'Parte de la cuota que paga interés. Decrece con el tiempo.';
COMMENT ON COLUMN core.amortizacion.saldo_final IS 'Saldo insoluto tras aplicar esta cuota. En la última cuota es 0.';
COMMENT ON COLUMN core.amortizacion.total_periodo IS 'Columna generada como capital + interes. Debe igualar a cuota salvo el redondeo del último período.';

-- pago
COMMENT ON TABLE  core.pago IS 'Pagos RECIBIDOS del cliente. Incluye pagos parciales, anticipados y duplicados por error.';
COMMENT ON COLUMN core.pago.credito_id IS 'Crédito al que se abona el pago.';
COMMENT ON COLUMN core.pago.fecha_pago IS 'Instante en que se recibió el pago (timestamptz para ejercicios de zona horaria).';
COMMENT ON COLUMN core.pago.monto IS 'Importe recibido. Puede ser menor (parcial) o mayor (anticipado) a la cuota.';
COMMENT ON COLUMN core.pago.canal IS 'Canal de pago, como ventanilla, app, transferencia o domiciliacion.';
COMMENT ON COLUMN core.pago.referencia IS 'Referencia del pago. Los duplicados por error repiten la misma referencia y esa es la pista para detectarlos.';

-- aplicacion_pago
COMMENT ON TABLE  core.aplicacion_pago IS 'Cómo se repartió cada pago entre cuotas (muchos a muchos entre pago y amortizacion). Un pago puede cubrir varias cuotas y una cuota recibir varios pagos.';
COMMENT ON COLUMN core.aplicacion_pago.pago_id IS 'Pago del que proviene el importe aplicado.';
COMMENT ON COLUMN core.aplicacion_pago.amortizacion_id IS 'Cuota a la que se aplicó el importe.';
COMMENT ON COLUMN core.aplicacion_pago.monto_aplicado IS 'Importe del pago aplicado a esta cuota.';
COMMENT ON COLUMN core.aplicacion_pago.aplicado_a_capital IS 'Parte del importe que redujo capital.';
COMMENT ON COLUMN core.aplicacion_pago.aplicado_a_interes IS 'Parte del importe que cubrió interés.';

-- credito_estado_hist
COMMENT ON TABLE  core.credito_estado_hist IS 'Historial temporal de estados del crédito. El EXCLUDE impide traslape de períodos del mismo crédito.';
COMMENT ON COLUMN core.credito_estado_hist.credito_id IS 'Crédito cuyo estado se registra.';
COMMENT ON COLUMN core.credito_estado_hist.estado IS 'Estado vigente durante el período.';
COMMENT ON COLUMN core.credito_estado_hist.valido_desde IS 'Inicio del período de vigencia del estado.';
COMMENT ON COLUMN core.credito_estado_hist.valido_hasta IS 'Fin del período. NULL indica el estado actual (período abierto).';

-- esquema_rendimiento
COMMENT ON TABLE  core.esquema_rendimiento IS 'Configuraciones de rendimiento aplicables a cuentas de captación (tasa, periodicidad, base de días, exención de ISR).';
COMMENT ON COLUMN core.esquema_rendimiento.nombre IS 'Nombre del esquema (p. ej. Ahorro Plus, PRLV 28 días).';
COMMENT ON COLUMN core.esquema_rendimiento.tasa_anual IS 'Tasa anual bruta de rendimiento como fracción.';
COMMENT ON COLUMN core.esquema_rendimiento.periodicidad_pago IS 'Cada cuánto se pagan rendimientos, que puede ser diaria, mensual o al_vencimiento.';
COMMENT ON COLUMN core.esquema_rendimiento.dias_base IS 'Convención de conteo de días del año, 360 o 365. Afecta el cálculo del interés devengado.';
COMMENT ON COLUMN core.esquema_rendimiento.isr_exento IS 'Si el rendimiento está exento de retención de ISR.';

-- cuenta_captacion
COMMENT ON TABLE  core.cuenta_captacion IS 'Cuentas de ahorro (vista) y a plazo (PRLV). La SOFIPO capta depósitos además de prestar.';
COMMENT ON COLUMN core.cuenta_captacion.cliente_id IS 'Cliente titular de la cuenta.';
COMMENT ON COLUMN core.cuenta_captacion.clabe IS 'CLABE interbancaria de 18 dígitos, sintética. Identifica la cuenta en transferencias SPEI.';
COMMENT ON COLUMN core.cuenta_captacion.tipo IS 'vista (disponibilidad inmediata) o plazo (retiro al vencimiento).';
COMMENT ON COLUMN core.cuenta_captacion.saldo IS 'Saldo actual de la cuenta.';
COMMENT ON COLUMN core.cuenta_captacion.esquema_rendimiento_id IS 'Esquema de rendimiento aplicado. NULL si la cuenta no genera rendimientos.';
COMMENT ON COLUMN core.cuenta_captacion.fecha_apertura IS 'Fecha de apertura de la cuenta.';

-- movimiento_captacion
COMMENT ON TABLE  core.movimiento_captacion IS 'Depósitos y retiros de las cuentas de captación. Serie temporal por cuenta.';
COMMENT ON COLUMN core.movimiento_captacion.cuenta_id IS 'Cuenta de captación afectada.';
COMMENT ON COLUMN core.movimiento_captacion.folio IS 'Consecutivo del movimiento dentro de la cuenta. Único por (cuenta, folio).';
COMMENT ON COLUMN core.movimiento_captacion.fecha IS 'Instante del movimiento.';
COMMENT ON COLUMN core.movimiento_captacion.tipo IS 'deposito (entra dinero) o retiro (sale dinero).';
COMMENT ON COLUMN core.movimiento_captacion.monto IS 'Importe del movimiento, siempre positivo. El signo lo da el tipo.';

-- pago_rendimiento
COMMENT ON TABLE  core.pago_rendimiento IS 'Pago de rendimientos, o sea el interés devengado que se acredita periódicamente a la cuenta, ya con la retención de ISR aplicada.';
COMMENT ON COLUMN core.pago_rendimiento.cuenta_id IS 'Cuenta de captación a la que se pagan rendimientos.';
COMMENT ON COLUMN core.pago_rendimiento.fecha IS 'Fecha en que se acreditó el rendimiento.';
COMMENT ON COLUMN core.pago_rendimiento.dias_computados IS 'Días del período sobre los que se calculó el rendimiento.';
COMMENT ON COLUMN core.pago_rendimiento.saldo_promedio IS 'Saldo promedio del período usado como base de cálculo.';
COMMENT ON COLUMN core.pago_rendimiento.rendimiento_bruto IS 'Interés bruto generado antes de impuestos.';
COMMENT ON COLUMN core.pago_rendimiento.isr_retenido IS 'ISR retenido sobre el rendimiento. Es 0 si el esquema es exento.';
COMMENT ON COLUMN core.pago_rendimiento.rendimiento_neto IS 'Rendimiento efectivamente abonado, o sea el bruto menos el ISR retenido.';

-- cat_institucion_spei
COMMENT ON TABLE  core.cat_institucion_spei IS 'Catálogo de instituciones participantes en SPEI (bancos contraparte de las transferencias).';
COMMENT ON COLUMN core.cat_institucion_spei.clave IS 'Clave del participante SPEI (identificador Banxico).';
COMMENT ON COLUMN core.cat_institucion_spei.participante IS 'Nombre del banco o institución.';
COMMENT ON COLUMN core.cat_institucion_spei.abm_code IS 'Código ABM del participante.';
COMMENT ON COLUMN core.cat_institucion_spei.permite_transferencia IS 'Si la institución acepta transferencias salientes.';
COMMENT ON COLUMN core.cat_institucion_spei.permite_deposito IS 'Si la institución acepta depósitos entrantes.';

-- cat_mcc
COMMENT ON TABLE  core.cat_mcc IS 'Catálogo de códigos de categoría de comercio (MCC, ISO 18245) usados en las autorizaciones de tarjeta.';
COMMENT ON COLUMN core.cat_mcc.mcc IS 'Código MCC de 4 dígitos (p. ej. 5411 = supermercados).';
COMMENT ON COLUMN core.cat_mcc.descripcion IS 'Descripción legible del giro del comercio.';
COMMENT ON COLUMN core.cat_mcc.giro IS 'Agrupación de negocio de más alto nivel.';

-- transferencia
COMMENT ON TABLE  core.transferencia IS 'Transferencias electrónicas SPEI/STP, enviadas y recibidas. Caso natural de conciliación y de FULL OUTER JOIN.';
COMMENT ON COLUMN core.transferencia.cuenta_captacion_id IS 'Cuenta interna involucrada (la nuestra), sea origen o destino.';
COMMENT ON COLUMN core.transferencia.direccion IS 'enviada (sale dinero de nuestra cuenta) o recibida (entra).';
COMMENT ON COLUMN core.transferencia.rail IS 'Riel de liquidación. Puede ser SPEI (directo Banxico), STP (proveedor que da acceso a SPEI) o interno (entre cuentas propias).';
COMMENT ON COLUMN core.transferencia.clabe_ordenante IS 'CLABE de 18 dígitos de quien ordena la transferencia.';
COMMENT ON COLUMN core.transferencia.clabe_beneficiario IS 'CLABE de 18 dígitos de quien recibe.';
COMMENT ON COLUMN core.transferencia.institucion_id IS 'Institución contraparte (cat_institucion_spei).';
COMMENT ON COLUMN core.transferencia.nombre_contraparte IS 'Nombre del ordenante o beneficiario externo.';
COMMENT ON COLUMN core.transferencia.rfc_curp_contraparte IS 'RFC o CURP de la contraparte. Puede faltar.';
COMMENT ON COLUMN core.transferencia.monto IS 'Importe transferido.';
COMMENT ON COLUMN core.transferencia.clave_rastreo IS 'Clave de rastreo única del participante por día. Sirve para conciliar contra el estado de cuenta del banco.';
COMMENT ON COLUMN core.transferencia.tipo_pago IS 'SPEI (transferencia clásica) o CODI (cobro con QR/NFC sobre SPEI).';
COMMENT ON COLUMN core.transferencia.estado IS 'liquidada, devuelta o pendiente.';
COMMENT ON COLUMN core.transferencia.ts_operacion IS 'Instante en que se operó la transferencia.';
COMMENT ON COLUMN core.transferencia.fecha_liquidacion IS 'Instante de liquidación. NULL mientras está pendiente.';

-- tarjeta
COMMENT ON TABLE  core.tarjeta IS 'Tarjetas de débito y crédito. La de débito descuenta de una cuenta de captación y la de crédito consume una línea revolvente.';
COMMENT ON COLUMN core.tarjeta.cliente_id IS 'Cliente titular de la tarjeta.';
COMMENT ON COLUMN core.tarjeta.cuenta_captacion_id IS 'Cuenta de la que fondea una tarjeta de débito. NULL en tarjetas de crédito.';
COMMENT ON COLUMN core.tarjeta.credito_id IS 'Línea de crédito revolvente asociada a una tarjeta de crédito. NULL en tarjetas de débito.';
COMMENT ON COLUMN core.tarjeta.tipo IS 'debito o credito.';
COMMENT ON COLUMN core.tarjeta.marca IS 'Marca de la red, como visa, mastercard o carnet.';
COMMENT ON COLUMN core.tarjeta.bin IS 'Primeros 6 dígitos (Bank Identification Number). Identifican emisor y producto.';
COMMENT ON COLUMN core.tarjeta.ultimos_cuatro IS 'Últimos 4 dígitos del PAN. El número completo nunca se almacena.';
COMMENT ON COLUMN core.tarjeta.nombre_tarjetahabiente IS 'Nombre impreso en la tarjeta.';
COMMENT ON COLUMN core.tarjeta.fecha_activacion IS 'Fecha de activación. NULL si aún no se activa.';
COMMENT ON COLUMN core.tarjeta.fecha_expiracion IS 'Vigencia en formato MM/YY.';
COMMENT ON COLUMN core.tarjeta.estado IS 'init, activa, bloqueada, expirada o cancelada.';
COMMENT ON COLUMN core.tarjeta.manufactura IS 'fisica o virtual.';
COMMENT ON COLUMN core.tarjeta.limite_credito IS 'Línea autorizada en tarjetas de crédito. NULL en débito.';

-- autorizacion_tarjeta
COMMENT ON TABLE  core.autorizacion_tarjeta IS 'Autorizaciones de tarjeta al estilo ISO 8583. Es cada intento de compra o retiro, ya sea aprobado, rechazado o reversado.';
COMMENT ON COLUMN core.autorizacion_tarjeta.tarjeta_id IS 'Tarjeta que originó la autorización.';
COMMENT ON COLUMN core.autorizacion_tarjeta.ts IS 'Instante de la autorización.';
COMMENT ON COLUMN core.autorizacion_tarjeta.monto IS 'Importe solicitado en la autorización.';
COMMENT ON COLUMN core.autorizacion_tarjeta.comercio IS 'Nombre del comercio (o cajero) donde se usó.';
COMMENT ON COLUMN core.autorizacion_tarjeta.mcc_id IS 'Categoría del comercio (cat_mcc). Permite analizar el gasto por giro.';
COMMENT ON COLUMN core.autorizacion_tarjeta.modo_entrada IS 'Cómo se capturó la tarjeta, ya sea chip, banda, contactless, ecommerce o atm.';
COMMENT ON COLUMN core.autorizacion_tarjeta.tipo IS 'compra, retiro_atm o devolucion.';
COMMENT ON COLUMN core.autorizacion_tarjeta.resultado IS 'aprobada, rechazada o reversada.';
COMMENT ON COLUMN core.autorizacion_tarjeta.motivo_rechazo IS 'Motivo si fue rechazada (fondos_insuficientes, limite_excedido, tarjeta_bloqueada...). NULL en otro caso.';

-- cuenta_contable
COMMENT ON TABLE  core.cuenta_contable IS 'Catálogo jerárquico de cuentas contables. padre_id forma el árbol y es la base de un CTE recursivo.';
COMMENT ON COLUMN core.cuenta_contable.codigo IS 'Código contable (p. ej. 1000, 1100, 1101). El prefijo indica el nivel.';
COMMENT ON COLUMN core.cuenta_contable.nombre IS 'Nombre de la cuenta.';
COMMENT ON COLUMN core.cuenta_contable.padre_id IS 'Cuenta padre. NULL en las cuentas raíz.';
COMMENT ON COLUMN core.cuenta_contable.naturaleza IS 'deudora (aumenta con cargos) o acreedora (aumenta con abonos).';

-- asiento
COMMENT ON TABLE  core.asiento IS 'Encabezado de póliza contable. Sus renglones (cargos y abonos) están en movimiento_contable y deben cuadrar.';
COMMENT ON COLUMN core.asiento.fecha IS 'Fecha contable del asiento.';
COMMENT ON COLUMN core.asiento.concepto IS 'Descripción del asiento.';
COMMENT ON COLUMN core.asiento.origen IS 'Proceso que generó el asiento, como originacion, pago, provision o rendimiento.';

-- movimiento_contable
COMMENT ON TABLE  core.movimiento_contable IS 'Renglones de los asientos. Por partida doble, la suma de cargos debe igualar la de abonos en cada asiento (invariante del ejercicio E20).';
COMMENT ON COLUMN core.movimiento_contable.asiento_id IS 'Asiento al que pertenece el renglón.';
COMMENT ON COLUMN core.movimiento_contable.cuenta_id IS 'Cuenta contable afectada.';
COMMENT ON COLUMN core.movimiento_contable.cargo IS 'Importe al debe. Un renglón es cargo o abono, nunca ambos.';
COMMENT ON COLUMN core.movimiento_contable.abono IS 'Importe al haber. Un renglón es cargo o abono, nunca ambos.';

-- tasa_referencia
COMMENT ON TABLE  core.tasa_referencia IS 'TIIE diaria. Solo días hábiles, así que tiene huecos en fines de semana y festivos, material para rellenar series y para LAG/LEAD.';
COMMENT ON COLUMN core.tasa_referencia.fecha IS 'Día hábil de la tasa.';
COMMENT ON COLUMN core.tasa_referencia.tiie IS 'Tasa de Interés Interbancaria de Equilibrio, como fracción anual.';

-- Llaves sustitutas. Comentario uniforme para toda columna que aún no tenga uno.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.table_name, c.column_name
    FROM information_schema.columns c
    LEFT JOIN pg_description d
      ON d.objoid = (quote_ident(c.table_schema)||'.'||quote_ident(c.table_name))::regclass
     AND d.objsubid = c.ordinal_position
    WHERE c.table_schema = 'core' AND d.description IS NULL
  LOOP
    EXECUTE format('COMMENT ON COLUMN core.%I.%I IS %L',
      r.table_name, r.column_name,
      'Identificador sustituto (bigint IDENTITY). Llave primaria interna.');
  END LOOP;
END $$;
