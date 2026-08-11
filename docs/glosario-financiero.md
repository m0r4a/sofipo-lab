# Glosario financiero

Este laboratorio usa vocabulario de banca popular mexicana. Para cada término que aparece en los ejercicios vas a encontrar cuatro cosas: qué significa en palabras simples, cómo se calcula **en este esquema** (con qué tablas y columnas), un ejemplo con números, y por qué funciona así.

Antes de entrar, dos convenciones que aplican a todo el laboratorio:

- **Los datos son sintéticos.** Los identificadores tipo CURP, RFC y CLABE tienen un formato posible, pero son inválidos: no corresponden a personas reales ni pasan los dígitos verificadores oficiales.

- **El dinero se guarda en `NUMERIC(18,2)`, nunca en `float`.** Un `float` no puede representar 0.10 exactamente, y en finanzas los centavos tienen que cuadrar al centavo *badum tsss*.

## 1. Crédito

### Principal (monto originado)
Es lo que se presta el día del desembolso. Vive en `core.credito.monto_originado`.

Es la base de todo el crédito, y dos cosas dependen de él: los intereses se calculan sobre el saldo que va quedando de este monto, y la suma del capital de todas las cuotas tiene que devolver exactamente este número.

### Saldo insoluto
Es el capital que todavía se debe en un momento dado. Solo cuenta el principal pendiente, no los intereses futuros.

En la tabla `core.amortizacion` es la columna `saldo_final`: el saldo que queda **después** de aplicar cada cuota. En la última cuota es `0`.

Ejemplo: prestas 10,000. Tras la primera cuota amortizaste 300 de capital, así que el saldo insoluto es 9,700. Los intereses del segundo mes se calculan sobre esos 9,700, no sobre los 10,000 originales.

### Amortización
Amortizar es devolver el crédito en pagos periódicos. La tabla `core.amortizacion` es el plan **planeado** de esos pagos: una fila por cuota, con su fecha de vencimiento y cuánto de esa cuota es capital y cuánto es interés.

Ojo con una distinción clave del laboratorio: `core.amortizacion` es lo que **se debía** pagar y `core.pago` es lo que **se pagó** en realidad. Casi nunca coinciden, y justo de esa diferencia salen la mora y la cobranza (es como pagar menos de lo que debes a la fecha de corte de tu tarjeta de crédito).

### Sistema francés (cuota fija)
Es el método de amortización que usa este laboratorio, y su rasgo central es que la cuota mensual es **fija** durante todo el crédito. Lo que sí cambia mes a mes es la composición de esa cuota: al principio casi todo es interés y poco capital, y al final, casi todo capital y poco interés.

La cuota se calcula con esta fórmula, donde `P` es el principal, `i` la tasa mensual (la anual entre 12) y `n` el número de meses:

```
cuota = P · i / (1 − (1 + i)^(−n))
```

El desglose se arma mes a mes con tres pasos:

1. Interés del período = saldo actual × `i`.
2. Capital del período = cuota − interés.
3. Nuevo saldo = saldo actual − capital.

Ejemplo con `P = 10,000`, tasa anual 48% (`i = 0.04` mensual), `n = 12`:

```
cuota = 10000 · 0.04 / (1 − 1.04^(−12)) ≈ 1065.52

Cuota 1: interés = 10000·0.04   = 400.00 ; capital = 665.52 ; saldo = 9334.48
Cuota 2: interés =  9334.48·0.04 = 373.38 ; capital = 692.14 ; saldo = 8642.34
...
Cuota 12: el saldo llega a 0.
```

Fíjate en el patrón: el interés baja cada mes (373.38 < 400.00) porque el saldo baja, y como la cuota es fija, el capital sube para compensar. Así se comporta el sistema francés.

En este esquema el plan se genera con un CTE recursivo (ver `sql/41_semilla_masiva.sql`) y el ejercicio **E48** te pide reconstruirlo desde cero. Un detalle de redondeo: la suma de las cuotas casi nunca da el principal al centavo exacto, así que el laboratorio absorbe el sobrante en el capital de la última cuota, de modo que `sum(capital) = monto_originado` cuadre exacto.

> [!NOTE]
> **¿Qué es un CTE?** Un CTE (*Common Table Expression*) es una tabla temporal con nombre que defines al principio de una consulta con `WITH nombre AS (...)` y luego usas como si fuera una tabla más. Sirve para partir una query larga en pasos con nombre, en lugar de anidar subconsultas dentro de subconsultas. Un CTE **recursivo** además se refiere a sí mismo: arranca con una fila inicial y va generando la siguiente a partir de la anterior, hasta que se detiene. Encaja natural con la amortización, donde cada cuota se calcula a partir del saldo que dejó la cuota anterior, y con cualquier estructura de árbol, como el catálogo de cuentas (ver la sección 7).

### Cuota (exigible)
Es el pago programado de un período, en `core.amortizacion.cuota`: "lo exigible" ese mes. La columna generada `total_periodo` es `capital + interes` y debe igualar a la cuota (salvo el redondeo del último período).

### Desglose capital / interés
Cada cuota se parte en dos: la parte que reduce el principal (`capital`) y la parte que es el costo del dinero (`interes`). Distinguirlas es importante en varios ejercicios, porque contablemente van a cuentas distintas: el capital baja la cartera y el interés es ingreso.

### Vencimiento y plazo (loan maturity)
Son dos cosas relacionadas pero distintas:

- El **plazo** (`core.credito.plazo_meses`) es cuántas cuotas mensuales dura el crédito.
- El **vencimiento** de una cuota (`amortizacion.fecha_vencimiento`) es el día en que esa cuota es exigible.

El vencimiento del crédito completo es el de su última cuota: la fecha en que, si todo salió bien, queda liquidado. Cuando una cuota pasa su vencimiento sin pagarse, empieza a contar la mora (ver más abajo).

### Tasa nominal anual vs tasa efectiva del período
La **tasa nominal anual** (`producto_credito.tasa_nominal_anual`, `credito.tasa_pactada`) se guarda como fracción: `0.4800` es 48% anual. La **tasa del período** (mensual) es esa nominal entre 12: `0.48 / 12 = 0.04`.

No la confundas con la **tasa efectiva anual**, que sí considera la capitalización. Si cobras 4% mensual, en un año no acabas en 48% sino en `1.04^12 − 1 ≈ 60.1%`. El laboratorio calcula los intereses con la tasa mensual `nominal/12`, que es la práctica común de la cuota francesa.

### CAT (Costo Anual Total)
Es la medida que en México resume el costo real de un crédito para el cliente: junta intereses, comisiones y seguros en una sola tasa anual, para que puedas comparar productos entre sí. Aquí se menciona como concepto y no se pide calcularlo exacto (la fórmula oficial es más compleja que una tasa simple).

### Comisión por apertura, seguro, IVA sobre intereses
- **Comisión por apertura** (`producto_credito.comision_apertura`, una fracción del monto): un cobro único al momento de desembolsar.
- **Seguro de vida**: cubre el saldo si el acreditado fallece. En este proyecto solo lo uso conceptualmente.
- **IVA sobre intereses**: cuando los intereses de un crédito causan IVA (16%), este recae **sobre el interés**, no sobre el capital. Si una cuota lleva 400 de interés, el IVA sería `400 × 0.16 = 64`. El capital no causa IVA.

## 2. Cobranza y riesgo

### Días de mora / atraso (DPD, *days past due*)
Son los días que han pasado desde que venció la cuota impaga más antigua sin que se pague.

En este esquema se calculan así: por cada crédito tomas la cuota más vieja que ya venció (`amortizacion.fecha_vencimiento < lab.reloj()`) y que no tiene ninguna aplicación de pago, y le restas la fecha de "hoy" (`lab.reloj()`).

```
dpd = lab.reloj()::date − min(fecha_vencimiento de cuotas vencidas sin pago)
```

Los ejercicios **E21** y **E22** construyen esto. El "hoy" es fijo (`lab.reloj()` = 2026-01-01) para que el cálculo siempre dé el mismo resultado.

### Cartera vigente vs vencida
- **Vigente**: el crédito está al corriente, o con un atraso menor al umbral.
- **Vencida**: pasó el umbral de mora. Para crédito de consumo el umbral típico es **90 días**.

En `core.credito.estado` esto se refleja en cinco valores: `vigente`, `atrasado` (1 a 89 días), `vencido` (90+), `castigado` (irrecuperable) y `liquidado` (pagado por completo).

### Buckets de antigüedad (aging)
Es agrupar la cartera por rangos de días de mora: `0` (al corriente), `1-29`, `30-59`, `60-89` y `90+`. Es la foto estándar de la calidad de la cartera y la base de las estimaciones preventivas. El ejercicio **E21** arma estos buckets.

¿Por qué en rangos y no día por día? Porque para reservar y reportar lo que importa es el tramo de riesgo, no el día exacto. Un crédito con 45 días de atraso y otro con 50 se tratan igual (los dos caen en el bucket 30 a 59).

### Provisión / estimación preventiva
Es una reserva contable que reconoce, por adelantado, que parte de la cartera no se va a cobrar. Va en proporción al riesgo: mientras más vieja es la mora, mayor es el porcentaje que se reserva. En el plan de cuentas aparece como `1300 Estimación preventiva para riesgos` (de naturaleza acreedora, porque resta al activo) y su gasto en `5200`.

### IMOR (Índice de Morosidad)
Es la proporción de cartera vencida sobre la cartera total:

```
IMOR = cartera vencida / cartera total
```

Es el indicador de "salud de cartera" del que más se suele hablar. Puedes calcularlo por sucursal, por producto o por cosecha para ver dónde se concentra el problema.

### Cosecha (vintage)
Es agrupar los créditos por su **mes de originación** y seguir cómo se comportan con el tiempo. La idea: los créditos otorgados el mismo mes forman una "cosecha", y comparar cosechas revela si el criterio con que se prestaba empeoró en cierta época.

En este laboratorio hay cosechas deliberadamente peores (agosto y septiembre de 2022), y el ejercicio **E45** las descubre. Es un caso ideal para window functions, porque comparas cada cosecha contra el resto.

### Pago parcial, anticipado, reestructura, castigo
- **Pago parcial**: el cliente abona menos que la cuota. En los datos, cerca del 8% de los pagos son parciales.
- **Pago anticipado**: paga de más o antes de tiempo, adelantando capital.
- **Reestructura**: el crédito original se cierra y nace uno nuevo con mejores condiciones, que apunta al anterior por `credito.credito_origen_id`.
- **Castigo (*write-off*)**: la institución da por perdido el crédito y lo saca de la cartera activa. En `estado` queda como `castigado`.

## 3. Captación

La SOFIPO no solo presta dinero: también **capta** depósitos del público. De ahí sale todo el bloque de `cuenta_captacion`, `movimiento_captacion`, `pago_rendimiento` y `transferencia`.

### Captación
Son los depósitos que el público deja en la institución. Para la institución son un pasivo (dinero que les debe a sus clientes), y por eso las cuentas de captación viven contablemente en `2100 Captación`.

### Depósito a la vista vs a plazo (PRLV)
- **A la vista** (`cuenta_captacion.tipo = 'vista'`): el cliente puede retirar cuando quiera. A cambio, paga poco o nada de rendimiento.
- **A plazo** (`tipo = 'plazo'`), también llamado **PRLV** (Pagaré con Rendimiento Liquidable al Vencimiento): el cliente se compromete a no retirar durante un plazo (28, 91 días...) a cambio de una tasa mayor. Los esquemas `PRLV 28 días` y `PRLV 91 días` están en `esquema_rendimiento`.

¿Por qué el plazo paga más? Porque la institución puede usar ese dinero con seguridad durante todo el plazo, así que te "premian" por no moverlo.

### Interés devengado vs interés pagado
Es una distinción pequeña, pero puede ser importante:
- **Devengado**: el interés que se va **generando** día a día y se acumula, aunque todavía no se pague.
- **Pagado**: el interés que efectivamente se **acredita** a la cuenta en la fecha de corte.

Un PRLV a 91 días devenga interés todos los días, pero lo **paga** hasta el vencimiento. Es la misma idea que separa `core.amortizacion` (lo devengado/planeado) de `core.pago` (lo efectivamente movido) del lado del crédito.

### Pago de rendimientos
Es el acto de **acreditar** a la cuenta el interés que generó el ahorro, y vive en `core.pago_rendimiento`. Cada fila tiene cuatro campos que conviene leer juntos:

- `saldo_promedio`: el saldo sobre el que se calculó.
- `rendimiento_bruto`: el interés antes de impuestos, = `saldo_promedio × tasa_anual / períodos`.
- `isr_retenido`: la retención de ISR (ver abajo).
- `rendimiento_neto`: lo que efectivamente entra a la cuenta, = `bruto − isr`.

La relación `rendimiento_neto = rendimiento_bruto - isr_retenido` está garantizada por un CHECK en la tabla.

**Retención de ISR sobre rendimientos.** En México, los intereses que pagan los bancos causan ISR. La institución lo **retiene**: lo descuenta del rendimiento y lo entera al SAT por cuenta del ahorrador. En la vida real esa retención se calcula sobre el capital con una tasa anual que fija la ley; aquí lo voy a simplificar a un 20% del rendimiento bruto, salvo en los esquemas marcados `isr_exento`. Contablemente, ese ISR retenido se le debe al SAT, así que va a la cuenta `2301 ISR retenido por pagar`. El ejercicio del módulo de captación te hace distinguir bruto, retención y neto.

## 4. Tarjetas

### Tarjeta de débito vs crédito
- **Débito** (`tarjeta.tipo = 'debito'`): gasta directamente el dinero de una cuenta de captación (`tarjeta.cuenta_captacion_id`). No hay préstamo, y si no hay saldo, la compra se rechaza.
- **Crédito** (`tipo = 'credito'`): gasta contra una **línea revolvente** con un límite (`tarjeta.limite_credito`), ligada a un crédito (`tarjeta.credito_id`). Aquí el banco presta primero y cobra después.

> [!NOTE]
> Un CHECK en la tabla obliga a que una tarjeta de débito tenga cuenta y una de crédito tenga límite.

### PAN, BIN y últimos cuatro
El **PAN** (*Primary Account Number*) es el número largo de la tarjeta. **Nunca se guarda completo** por seguridad: aquí solo se conservan el **BIN** (`tarjeta.bin`, los primeros 6 dígitos, que identifican al emisor y al producto) y los `ultimos_cuatro`. Es la práctica estándar de la industria de pagos.

### Autorización (como en ISO 8583)
Cada intento de compra o retiro con tarjeta genera una **autorización**, en `core.autorizacion_tarjeta`. ISO 8583 es el estándar de mensajería de las redes de tarjetas, y de ahí vienen campos como:

- `modo_entrada`: cómo se leyó la tarjeta (`chip`, `contactless`, `banda`, `ecommerce`, `atm`).
- `resultado`: `aprobada`, `rechazada` o `reversada`.
- `motivo_rechazo`: por qué se rechazó (`fondos_insuficientes`, `limite_excedido`, `tarjeta_bloqueada`).

Analizar aprobaciones contra rechazos, o el gasto por giro de comercio, aparece en varios ejercicios de agregación.

### MCC (Merchant Category Code)
Es un código de 4 dígitos (ISO 18245) que clasifica el giro del comercio: `5411` supermercados, `5541` gasolineras, `5812` restaurantes. Vive en `core.cat_mcc` y cada autorización lo referencia. Sirve para entender **en qué** gasta la gente.

## 5. Pagos y transferencias electrónicas

### SPEI
Es el **Sistema de Pagos Electrónicos Interbancarios** de Banxico: la red que mueve dinero entre bancos en México casi en tiempo real. Cuando haces una transferencia entre bancos, viaja por SPEI.

### STP
**STP** (Sistema de Transferencias y Pagos) es una empresa que da **acceso a SPEI** a instituciones que no se conectan directamente a Banxico. Muchas fintech y SOFIPOs operan SPEI **a través de STP**.

En `core.transferencia.rail`, el valor te dice por dónde salió cada transferencia:
- `STP`: salió por el riel de STP hacia SPEI.
- `SPEI`: conexión directa.
- `interno`: entre dos cuentas de la misma institución, sin salir a la red.

### CLABE
La **CLABE** (Clave Bancaria Estandarizada) es el número de cuenta interbancario de 18 dígitos que identifica de forma única una cuenta en México. Es lo que tecleas para recibir una transferencia. Vive en `cuenta_captacion.clabe` y en `transferencia.clabe_ordenante` / `clabe_beneficiario`.

### Clave de rastreo
Es un identificador que cada participante le asigna a una transferencia, único **por día**. Sirve para conciliar: si tu contraparte dice "te mandé el dinero", le pides la clave de rastreo y la buscas. En el esquema, `transferencia` tiene una restricción UNIQUE sobre `(institucion_id, clave_rastreo, ts_operacion)` que refleja esa unicidad.

### CODI
Es el Cobro Digital de Banxico: un esquema para cobrar con QR o NFC, montado **sobre** SPEI. En `transferencia.tipo_pago` se distingue `SPEI` (transferencia clásica) de `CODI`.

### Conciliación
Es cotejar dos fuentes que deberían coincidir (por ejemplo, lo que registramos nosotros contra el estado de cuenta del banco) y encontrar lo que falta o sobra en cada lado. Es el uso *natural* de `FULL OUTER JOIN`; el ejercicio **E11** lo practica conciliando pagos contra aplicaciones.

## 6. Identificadores de persona

### CURP
La **Clave Única de Registro de Población**: 18 caracteres que identifican a una persona en México (iniciales, fecha de nacimiento, sexo, entidad y dígitos de control). Aquí está en `cliente.curp`, sintética (falsa) y única por cliente, con formato posible pero **inválido** (no trae el dígito verificador real).

### RFC
El **Registro Federal de Contribuyentes**: la clave fiscal, 13 caracteres para persona física. En `cliente.rfc` es sintético y **opcional** (algunos clientes lo tienen en NULL, porque no siempre se captura). Esa nulabilidad a propósito da material para ejercicios de `COUNT(col)` vs `COUNT(*)`.

## 7. Contabilidad

### Asiento (póliza)
Un **asiento** es el registro completo de una operación en la contabilidad. La idea es sencilla: cada vez que pasa algo con dinero (se desembolsa un crédito, entra un pago, se cobran intereses) hay que anotarlo, y esa anotación no es un solo número sino un conjunto de renglones que van juntos y describen el movimiento por completo.

En este esquema el asiento vive en dos tablas. `core.asiento` es el **encabezado**: qué operación fue y cuándo. `core.movimiento_contable` guarda sus **renglones**, y cada renglón dice qué cuenta se afecta y por cuánto. Así que un asiento no es una fila suelta, es el grupo de renglones que comparten el mismo encabezado. Esto importa para lo que sigue: las reglas fuertes de la contabilidad (que todo cuadre) son sobre el grupo entero, no sobre un renglón aislado.

### Partida doble
El principio contable base: todo asiento tiene **cargos** y **abonos** que suman igual. Dicho simple, todo movimiento tiene dos caras: de dónde salió el dinero y a dónde llegó. No puede entrar por un lado sin salir o registrarse por otro. En `core.movimiento_contable`, cada renglón es o cargo o abono (nunca ambos, garantizado con CHECK), y la suma de los cargos de un asiento debe igualar la de los abonos.

Que cada asiento **cuadre** no se puede exigir con un CHECK simple (ya que es una condición sobre el grupo de rows, no sobre uno). Es un invariante verificable con una query, y el ejercicio **E20** encuentra el asiento sembrado que no cuadra.

### Cuenta contable, catálogo de cuentas, naturaleza
- **Cuenta contable** (`core.cuenta_contable`): cada concepto donde se registra dinero (Caja, Bancos, Cartera vigente...).
- **Catálogo de cuentas**: el árbol completo. Es jerárquico (`padre_id`), lo que lo hace un caso natural de CTE recursivo (ejercicio **E46**).
- **Naturaleza**: **deudora** (aumenta con cargos: activos y gastos) o **acreedora** (aumenta con abonos: pasivos, capital e ingresos). Determina de qué lado "crece" la cuenta.

### Cargo y abono
"Debe" y "haber" son solo los nombres tradicionales de los dos lados de un asiento: el debe a la izquierda, el haber a la derecha. No significan "lo que se debe"; son etiquetas de posición. Cargar es anotar en el debe, abonar es anotar en el haber. Qué lado hace crecer una cuenta depende de su naturaleza (ver arriba).

- **Cargo** (al debe): aumenta activos y gastos, disminuye pasivos.
- **Abono** (al haber): aumenta pasivos, capital e ingresos, disminuye activos.

Ejemplo del asiento de un desembolso en este laboratorio: se **carga** `1101 Cartera vigente` (nace el activo del préstamo) y se **abona** `1202 Bancos` (sale el efectivo). Los dos montos son iguales, y por eso el asiento cuadra.

## De vuelta a los datos

Cada término de arriba tiene un lugar concreto en el modelo. Si quieres ver dónde vive cada uno, `docs/modelo-datos.md` tiene el diccionario completo y el diagrama, y en `psql` un `\d+ core.credito` (o cualquier tabla) te muestra los comentarios columna por columna sin salir de la terminal.
