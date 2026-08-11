-- Catálogo de los 60 ejercicios y sus respuestas de referencia.

-- Este archivo contiene las soluciones de referencia, que se usan para calcular el hash
-- esperado durante la seed. En la tabla lab.ejercicio solo se guarda el hash, nunca
-- el texto de la solución. Abrir este archivo es decisión TUYA, sé sincero contigo mismo.

-- Los enunciados están en lenguaje de negocio, piden un resultado y no dicen cómo quieren el SQL.
-- El contrato de columnas (nombres y tipos exactos) es parte del
-- enunciado. El motor compara nombres, tipos y valores.

-- "Hoy" en los ejercicios es lab.reloj() (2026-01-01), no now().
\set ON_ERROR_STOP on

TRUNCATE lab.ejercicio CASCADE;

-- Módulo 0 (Reconocimiento)

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E01',0,'Inventario de filas',
 'Para orientarte, devuelve el número de filas de las tablas cliente, credito, pago y cuenta_captacion. Una fila por tabla.',
 'Un SELECT count(*) por tabla, unidos con UNION ALL. Etiqueta cada uno con el nombre de la tabla.',
 'tabla text, filas bigint', false, 'hash', 1);
SELECT lab.calcular_esperado('E01', $sol$
  SELECT 'cliente'::text AS tabla, count(*) AS filas FROM core.cliente
  UNION ALL SELECT 'credito', count(*) FROM core.credito
  UNION ALL SELECT 'pago', count(*) FROM core.pago
  UNION ALL SELECT 'cuenta_captacion', count(*) FROM core.cuenta_captacion
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E02',0,'Ventana de originación',
 'Cual es la fecha del primer y del último crédito originado.',
 'min() y max() sobre fecha_originacion.',
 'primera date, ultima date', false, 'hash', 1);
SELECT lab.calcular_esperado('E02', $sol$
  SELECT min(fecha_originacion)::date AS primera, max(fecha_originacion)::date AS ultima FROM core.credito
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E03',0,'Conteos rápidos',
 'Cuantos clientes, productos de crédito y sucursales hay. Una sola fila con tres columnas.',
 'Tres subconsultas escalares, o tres count(*) de tablas distintas.',
 'clientes bigint, productos bigint, sucursales bigint', false, 'hash', 1);
SELECT lab.calcular_esperado('E03', $sol$
  SELECT (SELECT count(*) FROM core.cliente) AS clientes,
         (SELECT count(*) FROM core.producto_credito) AS productos,
         (SELECT count(*) FROM core.sucursal) AS sucursales
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E04',0,'Qué es aplicacion_pago',
 'Explica con tus propias palabras qué representa la tabla aplicacion_pago y por qué existe en vez de una simple llave de pago a cuota. Este ejercicio se revisa a mano, no por hash.',
 'Piensa en un pago que cubre varias cuotas, y en una cuota que se paga con varios pagos.',
 '(respuesta en texto libre)', false, 'manual', 1);

-- Módulo 1 (Joins)

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E05',1,'Créditos con cliente y sucursal',
 'Lista cada crédito con el nombre de su cliente y el nombre de su sucursal.',
 'Dos joins, credito a cliente y credito a sucursal.',
 'credito_id bigint, cliente text, sucursal text', false, 'hash', 1);
SELECT lab.calcular_esperado('E05', $sol$
  SELECT c.id AS credito_id, cl.nombre AS cliente, s.nombre AS sucursal
  FROM core.credito c
  JOIN core.cliente cl ON cl.id = c.cliente_id
  JOIN core.sucursal s ON s.id = c.sucursal_id
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E06',1,'Sucursales sin colocación',
 'Que sucursales no colocaron ni un solo crédito durante el trimestre pasado (del 1 de octubre al 31 de diciembre de 2025).',
 'Piensa en una sucursal para la que NO EXISTE un crédito en ese rango de fechas.',
 'sucursal_id bigint, sucursal text', false, 'hash', 2);
SELECT lab.calcular_esperado('E06', $sol$
  SELECT s.id AS sucursal_id, s.nombre AS sucursal
  FROM core.sucursal s
  WHERE NOT EXISTS (
    SELECT 1 FROM core.credito c
    WHERE c.sucursal_id = s.id
      AND c.fecha_originacion >= DATE '2025-10-01'
      AND c.fecha_originacion <  DATE '2026-01-01')
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E07',1,'Clientes sin crédito',
 'Que clientes nunca han tenido un crédito.',
 'Un anti-join, o sea clientes para los que no existe ningún crédito.',
 'cliente_id bigint, cliente text', false, 'hash', 2);
SELECT lab.calcular_esperado('E07', $sol$
  SELECT cl.id AS cliente_id, cl.nombre AS cliente
  FROM core.cliente cl
  WHERE NOT EXISTS (SELECT 1 FROM core.credito c WHERE c.cliente_id = cl.id)
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E08',1,'Cadena crédito a domicilio',
 'Para cada crédito, muestra el nombre del cliente, la ciudad de su domicilio principal y el nombre de la sucursal. Si el cliente no tiene domicilio principal, la ciudad debe quedar en NULL (no pierdas el crédito).',
 'La sucursal y el cliente son joins normales. El domicilio principal es un LEFT JOIN con la condición es_principal dentro del ON.',
 'credito_id bigint, cliente text, ciudad_domicilio text, sucursal text', false, 'hash', 2);
SELECT lab.calcular_esperado('E08', $sol$
  SELECT c.id AS credito_id, cl.nombre AS cliente, d.ciudad AS ciudad_domicilio, s.nombre AS sucursal
  FROM core.credito c
  JOIN core.cliente cl ON cl.id = c.cliente_id
  LEFT JOIN core.cliente_direccion d ON d.cliente_id = cl.id AND d.es_principal
  JOIN core.sucursal s ON s.id = c.sucursal_id
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E09',1,'Filtro sobre la tabla derecha',
 'Lista TODOS los clientes con la ciudad de su domicilio principal, incluyendo a los que no tienen ningún domicilio (ciudad en NULL). Cuida no convertir sin querer el LEFT JOIN en INNER.',
 'Si pones d.ciudad en el WHERE, descartas los NULL y pierdes a los clientes sin domicilio. Mantén el LEFT JOIN limpio.',
 'cliente_id bigint, ciudad text', false, 'hash', 2);
SELECT lab.calcular_esperado('E09', $sol$
  SELECT cl.id AS cliente_id, d.ciudad AS ciudad
  FROM core.cliente cl
  LEFT JOIN core.cliente_direccion d ON d.cliente_id = cl.id AND d.es_principal
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E10',1,'Cada empleado y su jefe',
 'Muestra el nombre de cada empleado y el nombre de su jefe directo. El director no tiene jefe, así que su columna jefe debe quedar en NULL.',
 'Un self-join de empleado consigo mismo por jefe_id, con LEFT JOIN para conservar al director.',
 'empleado text, jefe text', false, 'hash', 2);
SELECT lab.calcular_esperado('E10', $sol$
  SELECT e.nombre AS empleado, j.nombre AS jefe
  FROM core.empleado e
  LEFT JOIN core.empleado j ON j.id = e.jefe_id
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E11',1,'Conciliación pago vs aplicación',
 'Usando una conciliación entre pago y aplicacion_pago, cuenta cuántos pagos no tienen ninguna aplicación registrada y cuántas aplicaciones no tienen pago. Una sola fila.',
 'Un FULL OUTER JOIN entre pago y aplicacion_pago, y cuenta con FILTER los casos en que falta cada lado.',
 'pagos_sin_aplicacion bigint, aplicaciones_sin_pago bigint', false, 'hash', 2);
SELECT lab.calcular_esperado('E11', $sol$
  SELECT count(*) FILTER (WHERE ap.id IS NULL) AS pagos_sin_aplicacion,
         count(*) FILTER (WHERE p.id IS NULL) AS aplicaciones_sin_pago
  FROM core.pago p
  FULL OUTER JOIN core.aplicacion_pago ap ON ap.pago_id = p.id
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E12',1,'Colocación por asesor',
 'Cuantos créditos colocó cada asesor, incluyendo a los asesores que no colocaron ninguno (deben aparecer con cero).',
 'LEFT JOIN de empleado (solo asesores) a credito, y count() de la columna del crédito, no count(*).',
 'asesor text, num_creditos bigint', false, 'hash', 2);
SELECT lab.calcular_esperado('E12', $sol$
  SELECT e.nombre AS asesor, count(c.id) AS num_creditos
  FROM core.empleado e
  LEFT JOIN core.credito c ON c.empleado_id = e.id
  WHERE e.puesto = 'asesor'
  GROUP BY e.id, e.nombre
$sol$);

-- Módulo 2 (Agregación)

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E13',2,'Originación por mes',
 'Suma el monto originado por mes de originación. Devuelve el primer día del mes y el monto, ::numeric(18,2).',
 'date_trunc por mes y sum() del monto.',
 'mes date, monto_originado numeric(18,2)', false, 'hash', 2);
SELECT lab.calcular_esperado('E13', $sol$
  SELECT date_trunc('month', fecha_originacion)::date AS mes,
         sum(monto_originado)::numeric(18,2) AS monto_originado
  FROM core.credito GROUP BY 1
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E14',2,'Sucursales muy activas',
 'Que sucursales colocaron más de 800 créditos en total.',
 'GROUP BY sucursal y filtra el conteo con HAVING, no con WHERE.',
 'sucursal_id bigint, num_creditos bigint', false, 'hash', 2);
SELECT lab.calcular_esperado('E14', $sol$
  SELECT sucursal_id, count(*) AS num_creditos
  FROM core.credito GROUP BY sucursal_id HAVING count(*) > 800
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E15',2,'Tres formas de contar',
 'Devuelve, para la tabla cliente, el total de filas, cuántos tienen ingreso capturado, y cuántos valores de ingreso distintos existen.',
 'count(*) cuenta filas, count(columna) ignora NULL y count(DISTINCT columna) cuenta valores únicos.',
 'total bigint, con_ingreso bigint, ingresos_distintos bigint', false, 'hash', 2);
SELECT lab.calcular_esperado('E15', $sol$
  SELECT count(*) AS total,
         count(ingreso_mensual) AS con_ingreso,
         count(DISTINCT ingreso_mensual) AS ingresos_distintos
  FROM core.cliente
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E16',2,'Monto y ticket por producto',
 'Por producto (su código), el monto total colocado y el ticket promedio, ambos ::numeric(18,2).',
 'sum() y avg() del monto, agrupando por producto.',
 'producto text, monto_total numeric(18,2), ticket_promedio numeric(18,2)', false, 'hash', 2);
SELECT lab.calcular_esperado('E16', $sol$
  SELECT pc.codigo AS producto,
         sum(c.monto_originado)::numeric(18,2) AS monto_total,
         avg(c.monto_originado)::numeric(18,2) AS ticket_promedio
  FROM core.credito c JOIN core.producto_credito pc ON pc.id = c.producto_id
  GROUP BY pc.codigo
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E17',2,'Monto por sucursal sin inflar',
 'Suma el monto originado por sucursal. Cuidado, si unes con pagos para traer de paso info de pago, cada crédito se multiplica por sus pagos y la suma queda inflada. Devuelve el monto correcto.',
 'No necesitas la tabla pago para esto. Suma directamente sobre credito.',
 'sucursal_id bigint, monto_originado numeric(18,2)', false, 'hash', 2);
SELECT lab.calcular_esperado('E17', $sol$
  SELECT sucursal_id, sum(monto_originado)::numeric(18,2) AS monto_originado
  FROM core.credito GROUP BY sucursal_id
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E18',2,'Cartera por estado en columnas',
 'Cuenta los créditos de cada estado, pero en una sola fila con una columna por estado, que son vigente, atrasado, vencido, castigado y liquidado.',
 'count(*) FILTER (WHERE estado = ...) una vez por estado.',
 'vigente bigint, atrasado bigint, vencido bigint, castigado bigint, liquidado bigint', false, 'hash', 2);
SELECT lab.calcular_esperado('E18', $sol$
  SELECT count(*) FILTER (WHERE estado='vigente')   AS vigente,
         count(*) FILTER (WHERE estado='atrasado')  AS atrasado,
         count(*) FILTER (WHERE estado='vencido')   AS vencido,
         count(*) FILTER (WHERE estado='castigado') AS castigado,
         count(*) FILTER (WHERE estado='liquidado') AS liquidado
  FROM core.credito
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E19',2,'Ingreso promedio por sucursal',
 'El ingreso mensual promedio de los clientes acreditados por cada sucursal, ::numeric(18,2). Los clientes sin ingreso declarado simplemente no cuentan para el promedio.',
 'avg() ignora los NULL por sí solo, no los conviertas a cero.',
 'sucursal_id bigint, ingreso_promedio numeric(18,2)', false, 'hash', 2);
SELECT lab.calcular_esperado('E19', $sol$
  SELECT c.sucursal_id, avg(cl.ingreso_mensual)::numeric(18,2) AS ingreso_promedio
  FROM core.credito c JOIN core.cliente cl ON cl.id = c.cliente_id
  GROUP BY c.sucursal_id
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E20',2,'El asiento que no cuadra',
 'Por partida doble, en cada asiento la suma de cargos debe igualar la suma de abonos. Encuentra el asiento donde no cuadra y muestra sus totales.',
 'Agrupa movimiento_contable por asiento y filtra con HAVING donde sum(cargo) <> sum(abono).',
 'asiento_id bigint, total_cargo numeric(18,2), total_abono numeric(18,2)', false, 'hash', 2);
SELECT lab.calcular_esperado('E20', $sol$
  SELECT asiento_id,
         sum(cargo)::numeric(18,2) AS total_cargo,
         sum(abono)::numeric(18,2) AS total_abono
  FROM core.movimiento_contable
  GROUP BY asiento_id HAVING sum(cargo) <> sum(abono)
$sol$);

-- Módulo 3 (Condicional y fechas)

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E21',3,'Cubetas de aging',
 'Clasifica cada crédito en una cubeta de antigüedad según los días de atraso de su cuota impaga más antigua ya vencida (usa lab.reloj() como hoy), con 0 (al corriente), 1-29, 30-59, 60-89 y 90+. Cuenta cuántos créditos hay en cada cubeta. Una cuota se considera impaga si no tiene ninguna fila en aplicacion_pago.',
 'Primero, por crédito, la fecha de vencimiento más antigua entre las cuotas vencidas y sin aplicación. De ahí salen los días de atraso, y luego un CASE arma las cubetas.',
 'cubeta text, num_creditos bigint', false, 'hash', 3);
SELECT lab.calcular_esperado('E21', $sol$
  WITH imp AS (
    SELECT a.credito_id, (lab.reloj()::date - min(a.fecha_vencimiento)) AS dpd
    FROM core.amortizacion a
    WHERE a.fecha_vencimiento < lab.reloj()::date
      AND NOT EXISTS (SELECT 1 FROM core.aplicacion_pago ap WHERE ap.amortizacion_id = a.id)
    GROUP BY a.credito_id
  )
  SELECT CASE WHEN i.dpd IS NULL OR i.dpd <= 0 THEN '0'
              WHEN i.dpd < 30 THEN '1-29'
              WHEN i.dpd < 60 THEN '30-59'
              WHEN i.dpd < 90 THEN '60-89'
              ELSE '90+' END AS cubeta,
         count(*) AS num_creditos
  FROM core.credito c LEFT JOIN imp i ON i.credito_id = c.id
  GROUP BY 1
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E22',3,'El más moroso por sucursal',
 'Por sucursal, los días de atraso del crédito más moroso (el mayor atraso de una cuota impaga vencida, usando lab.reloj()). Solo sucursales con al menos un crédito con atraso.',
 'Reutiliza la idea del atraso por crédito y toma el máximo por sucursal.',
 'sucursal_id bigint, max_dpd integer', false, 'hash', 3);
SELECT lab.calcular_esperado('E22', $sol$
  WITH imp AS (
    SELECT a.credito_id, (lab.reloj()::date - min(a.fecha_vencimiento)) AS dpd
    FROM core.amortizacion a
    WHERE a.fecha_vencimiento < lab.reloj()::date
      AND NOT EXISTS (SELECT 1 FROM core.aplicacion_pago ap WHERE ap.amortizacion_id = a.id)
    GROUP BY a.credito_id
  )
  SELECT c.sucursal_id, max(i.dpd) AS max_dpd
  FROM core.credito c JOIN imp i ON i.credito_id = c.id
  GROUP BY c.sucursal_id
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E23',3,'El nulo y el promedio',
 'Devuelve el ingreso mensual promedio de los clientes de dos formas, ignorando los nulos, y tratando los nulos como cero. Ambos ::numeric(18,2), en una sola fila.',
 'avg(col) ignora NULL y avg(coalesce(col,0)) los cuenta como cero. El segundo baja el promedio.',
 'promedio_ignorando_nulos numeric(18,2), promedio_nulos_como_cero numeric(18,2)', false, 'hash', 2);
SELECT lab.calcular_esperado('E23', $sol$
  SELECT avg(ingreso_mensual)::numeric(18,2) AS promedio_ignorando_nulos,
         avg(coalesce(ingreso_mensual,0))::numeric(18,2) AS promedio_nulos_como_cero
  FROM core.cliente
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E24',3,'Edad al originar',
 'Para cada crédito, la edad del cliente (en años cumplidos) al momento de originar el crédito.',
 'age(fecha_originacion, fecha_nacimiento) da un intervalo, extrae los años.',
 'credito_id bigint, edad_anios integer', false, 'hash', 3);
SELECT lab.calcular_esperado('E24', $sol$
  SELECT c.id AS credito_id,
         extract(year FROM age(c.fecha_originacion, cl.fecha_nacimiento))::int AS edad_anios
  FROM core.credito c JOIN core.cliente cl ON cl.id = c.cliente_id
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E25',3,'Colocación diaria de agosto 2025',
 'Cuantos créditos se originaron cada día de agosto de 2025. Incluye los días sin ningún crédito (con cero), del 1 al 31.',
 'Genera la serie de días con generate_series y haz LEFT JOIN a credito por fecha.',
 'dia date, num_creditos bigint', false, 'hash', 3);
SELECT lab.calcular_esperado('E25', $sol$
  SELECT d::date AS dia, count(c.id) AS num_creditos
  FROM generate_series(DATE '2025-08-01', DATE '2025-08-31', INTERVAL '1 day') d
  LEFT JOIN core.credito c ON c.fecha_originacion = d::date
  GROUP BY d::date
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E26',3,'TIIE rellenando fines de semana',
 'La TIIE solo tiene dato en días hábiles. Devuelve, para cada día de enero de 2025, la TIIE vigente ese día (la del último día hábil con dato, arrastrada hacia adelante).',
 'Para cada día genera la serie. La tasa vigente es la del último registro de tasa_referencia con fecha menor o igual.',
 'dia date, tiie numeric(6,4)', false, 'hash', 3);
SELECT lab.calcular_esperado('E26', $sol$
  SELECT d::date AS dia,
         (SELECT tr.tiie FROM core.tasa_referencia tr
          WHERE tr.fecha <= d::date ORDER BY tr.fecha DESC LIMIT 1) AS tiie
  FROM generate_series(DATE '2025-01-01', DATE '2025-01-31', INTERVAL '1 day') d
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E27',3,'El día depende de la zona',
 'Los pagos con referencia que empieza en TZ-BORDE se registraron cerca de la medianoche. Muestra, para cada uno, en qué día cae según la hora local (America/Mexico_City) y según UTC. Veras que no siempre coinciden.',
 'Convierte fecha_pago AT TIME ZONE a cada zona y quédate con la parte date.',
 'referencia text, dia_local date, dia_utc date', false, 'hash', 3);
SELECT lab.calcular_esperado('E27', $sol$
  SELECT referencia,
         (fecha_pago AT TIME ZONE 'America/Mexico_City')::date AS dia_local,
         (fecha_pago AT TIME ZONE 'UTC')::date AS dia_utc
  FROM core.pago WHERE referencia LIKE 'TZ-BORDE%'
$sol$);

-- Módulo 4 (Subconsultas y CTEs)

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E28',4,'Ingreso sobre el promedio',
 'Que clientes tienen un ingreso mensual mayor al promedio general de ingresos.',
 'Una subconsulta escalar calcula el promedio, compáralo en el WHERE.',
 'cliente_id bigint, ingreso_mensual numeric(18,2)', false, 'hash', 3);
SELECT lab.calcular_esperado('E28', $sol$
  SELECT id AS cliente_id, ingreso_mensual
  FROM core.cliente
  WHERE ingreso_mensual > (SELECT avg(ingreso_mensual) FROM core.cliente)
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E29',4,'Créditos con pago',
 'Que créditos han recibido al menos un pago. Devuelve solo su id.',
 'EXISTS es más natural que un JOIN con DISTINCT aquí.',
 'credito_id bigint', false, 'hash', 3);
SELECT lab.calcular_esperado('E29', $sol$
  SELECT c.id AS credito_id FROM core.credito c
  WHERE EXISTS (SELECT 1 FROM core.pago p WHERE p.credito_id = c.id)
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E30',4,'Créditos sin ningún pago',
 'Que créditos nunca han recibido un pago.',
 'NOT EXISTS.',
 'credito_id bigint', false, 'hash', 3);
SELECT lab.calcular_esperado('E30', $sol$
  SELECT c.id AS credito_id FROM core.credito c
  WHERE NOT EXISTS (SELECT 1 FROM core.pago p WHERE p.credito_id = c.id)
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E31',4,'NOT IN con NULLs',
 'Queremos contar los clientes que NO son el origen de ninguna reestructura, es decir, cuyo id no aparece en credito.credito_origen_id. Como esa columna puede ser NULL, un NOT IN daría cero por sorpresa. Devuelve el conteo correcto.',
 'NOT IN contra una lista con NULLs no devuelve nada. Usa NOT EXISTS.',
 'clientes bigint', false, 'hash', 3);
SELECT lab.calcular_esperado('E31', $sol$
  SELECT count(*) AS clientes FROM core.cliente cl
  WHERE NOT EXISTS (SELECT 1 FROM core.credito c WHERE c.credito_origen_id = cl.id)
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E32',4,'Cartera vencida por sucursal (WITH)',
 'Cuantos créditos en estado vencido o castigado tiene cada sucursal. Resuélvelo apoyándote en un WITH.',
 'Un CTE con los créditos vencidos, y luego el conteo por sucursal.',
 'sucursal_id bigint, num_vencidos bigint', false, 'hash', 3);
SELECT lab.calcular_esperado('E32', $sol$
  WITH vencidos AS (
    SELECT sucursal_id FROM core.credito WHERE estado IN ('vencido','castigado'))
  SELECT sucursal_id, count(*) AS num_vencidos FROM vencidos GROUP BY sucursal_id
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E33',4,'CTEs encadenados',
 'Por producto, el ticket promedio de los créditos vencidos o castigados, pero solo para productos con más de 100 créditos en ese estado. Encadena varios CTE para que se lea paso a paso.',
 'Un CTE filtra los malos, otro agrega por producto, otro filtra por conteo.',
 'producto text, num_vencidos bigint, ticket_promedio numeric(18,2)', false, 'hash', 3);
SELECT lab.calcular_esperado('E33', $sol$
  WITH malos AS (
    SELECT producto_id, monto_originado FROM core.credito WHERE estado IN ('vencido','castigado')),
  agg AS (
    SELECT producto_id, count(*) AS n, avg(monto_originado) AS tk FROM malos GROUP BY producto_id),
  filt AS (SELECT * FROM agg WHERE n > 100)
  SELECT pc.codigo AS producto, f.n AS num_vencidos, f.tk::numeric(18,2) AS ticket_promedio
  FROM filt f JOIN core.producto_credito pc ON pc.id = f.producto_id
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E34',4,'Morosidad por cosecha (CTE)',
 'Por mes de originación, el porcentaje de créditos que terminaron mal (vencido o castigado), ::numeric(6,2). Usa un CTE como tabla de trabajo.',
 'Marca cada crédito como malo o no en un CTE, y luego agrega por mes.',
 'mes date, pct_malo numeric(6,2)', false, 'hash', 3);
SELECT lab.calcular_esperado('E34', $sol$
  WITH base AS (
    SELECT date_trunc('month', fecha_originacion)::date AS mes,
           (estado IN ('vencido','castigado')) AS malo
    FROM core.credito)
  SELECT mes, (100.0 * count(*) FILTER (WHERE malo) / count(*))::numeric(6,2) AS pct_malo
  FROM base GROUP BY mes
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E35',4,'Sucursales sobre el promedio',
 'Con un WITH que agregue el monto total colocado por sucursal, devuelve las sucursales cuyo monto supera el promedio de monto por sucursal. (Desde PG12 un CTE ya no es barrera de optimización, y MATERIALIZED o NOT MATERIALIZED lo controlan.)',
 'El WITH calcula monto por sucursal, y el SELECT externo compara contra el promedio de esos montos.',
 'sucursal_id bigint, monto_total numeric(18,2)', false, 'hash', 3);
SELECT lab.calcular_esperado('E35', $sol$
  WITH s AS (SELECT sucursal_id, sum(monto_originado) AS m FROM core.credito GROUP BY sucursal_id)
  SELECT sucursal_id, m::numeric(18,2) AS monto_total FROM s WHERE m > (SELECT avg(m) FROM s)
$sol$);

-- Módulo 5 (Window functions)

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E36',5,'El pago más reciente por crédito',
 'Para cada crédito con pagos, su pago más reciente (id y monto). Ante empate de fecha, el de mayor id.',
 'Numera los pagos por crédito con row_number() ordenando por fecha descendente, y quédate con el 1.',
 'credito_id bigint, pago_id bigint, monto numeric(18,2)', false, 'hash', 3);
SELECT lab.calcular_esperado('E36', $sol$
  SELECT credito_id, pago_id, monto FROM (
    SELECT p.credito_id, p.id AS pago_id, p.monto,
           row_number() OVER (PARTITION BY p.credito_id ORDER BY p.fecha_pago DESC, p.id DESC) AS rn
    FROM core.pago p) x
  WHERE rn = 1
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E37',5,'Ranking de asesores',
 'Por asesor, cuántos créditos colocó y su posición en el ranking, calculada de dos formas, dejando huecos tras los empates y sin dejarlos.',
 'rank() deja huecos y dense_rank() no. Ambos ordenando por el conteo descendente.',
 'asesor text, num_creditos bigint, rank_con_huecos bigint, rank_sin_huecos bigint', false, 'hash', 3);
SELECT lab.calcular_esperado('E37', $sol$
  SELECT e.nombre AS asesor, count(c.id) AS num_creditos,
         rank()       OVER (ORDER BY count(c.id) DESC) AS rank_con_huecos,
         dense_rank() OVER (ORDER BY count(c.id) DESC) AS rank_sin_huecos
  FROM core.empleado e LEFT JOIN core.credito c ON c.empleado_id = e.id
  WHERE e.puesto = 'asesor'
  GROUP BY e.id, e.nombre
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E38',5,'Mejor asesor por sucursal',
 'El asesor que más colocó dentro de cada sucursal (id y conteo). Ante empate, el de menor id de empleado.',
 'Particiona por sucursal y ordena por conteo, y row_number = 1 da el mejor de cada grupo.',
 'sucursal_id bigint, asesor text, num_creditos bigint', false, 'hash', 4);
SELECT lab.calcular_esperado('E38', $sol$
  SELECT sucursal_id, asesor, num_creditos FROM (
    SELECT e.sucursal_id, e.nombre AS asesor, count(c.id) AS num_creditos,
           row_number() OVER (PARTITION BY e.sucursal_id ORDER BY count(c.id) DESC, e.id) AS rn
    FROM core.empleado e LEFT JOIN core.credito c ON c.empleado_id = e.id
    WHERE e.puesto = 'asesor'
    GROUP BY e.sucursal_id, e.id, e.nombre) x
  WHERE rn = 1
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E39',5,'Variación mensual de TIIE',
 'Por mes, la TIIE promedio y su variación respecto al mes anterior (::numeric(6,4)). El primer mes no tiene mes previo, así que su variación queda en NULL.',
 'Promedia la TIIE por mes en un CTE, y usa lag() para traer el valor del mes anterior.',
 'mes date, tiie_prom numeric(6,4), variacion numeric(6,4)', false, 'hash', 3);
SELECT lab.calcular_esperado('E39', $sol$
  WITH m AS (SELECT date_trunc('month', fecha)::date AS mes, avg(tiie)::numeric(6,4) AS t
             FROM core.tasa_referencia GROUP BY 1)
  SELECT mes, t AS tiie_prom, (t - lag(t) OVER (ORDER BY mes))::numeric(6,4) AS variacion FROM m
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E40',5,'Saldo acumulado de una cuenta',
 'Para la cuenta de captación con id 1, muestra cada movimiento (por folio) con su importe con signo (depósito positivo, retiro negativo) y el saldo acumulado hasta ese folio. El orden importa.',
 'Una suma con ventana, sum(...) OVER (ORDER BY folio). El importe con signo sale de un CASE por tipo.',
 'folio bigint, movimiento numeric(18,2), saldo_acumulado numeric(18,2)', true, 'hash', 3);
SELECT lab.calcular_esperado('E40', $sol$
  SELECT folio,
         (CASE WHEN tipo='deposito' THEN monto ELSE -monto END)::numeric(18,2) AS movimiento,
         (sum(CASE WHEN tipo='deposito' THEN monto ELSE -monto END) OVER (ORDER BY folio))::numeric(18,2) AS saldo_acumulado
  FROM core.movimiento_captacion WHERE cuenta_id = 1
  ORDER BY folio
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E41',5,'Media móvil de 7 días',
 'Colocación diaria de créditos en 2025 (incluyendo días con cero) y su media móvil de 7 días (día actual y los 6 anteriores), ::numeric(18,2). El orden importa.',
 'Primero la serie diaria completa con generate_series y LEFT JOIN, luego avg() OVER con ROWS BETWEEN 6 PRECEDING AND CURRENT ROW.',
 'dia date, colocacion bigint, media_movil_7d numeric(18,2)', true, 'hash', 4);
SELECT lab.calcular_esperado('E41', $sol$
  WITH dias AS (
    SELECT d::date AS dia, count(c.id) AS colocacion
    FROM generate_series(DATE '2025-01-01', DATE '2025-12-31', INTERVAL '1 day') d
    LEFT JOIN core.credito c ON c.fecha_originacion = d::date
    GROUP BY d::date)
  SELECT dia, colocacion,
         (avg(colocacion) OVER (ORDER BY dia ROWS BETWEEN 6 PRECEDING AND CURRENT ROW))::numeric(18,2) AS media_movil_7d
  FROM dias ORDER BY dia
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E42',5,'Deciles de riesgo',
 'Reparte todos los créditos en 10 grupos (deciles) según sus días de atraso (0 si están al corriente), ordenados de menos a más atraso. Por decil, cuántos créditos y el atraso mínimo y máximo.',
 'ntile(10) OVER (ORDER BY dpd) asigna el decil, luego agregas por decil.',
 'decil integer, num_creditos bigint, min_dpd integer, max_dpd integer', false, 'hash', 4);
SELECT lab.calcular_esperado('E42', $sol$
  WITH imp AS (
    SELECT a.credito_id, (lab.reloj()::date - min(a.fecha_vencimiento)) AS dpd
    FROM core.amortizacion a
    WHERE a.fecha_vencimiento < lab.reloj()::date
      AND NOT EXISTS (SELECT 1 FROM core.aplicacion_pago ap WHERE ap.amortizacion_id = a.id)
    GROUP BY a.credito_id),
  allc AS (SELECT c.id AS credito_id, coalesce(i.dpd, 0) AS dpd
           FROM core.credito c LEFT JOIN imp i ON i.credito_id = c.id),
  d AS (SELECT credito_id, dpd, ntile(10) OVER (ORDER BY dpd) AS decil FROM allc)
  SELECT decil, count(*) AS num_creditos, min(dpd)::int AS min_dpd, max(dpd)::int AS max_dpd
  FROM d GROUP BY decil
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E43',5,'Primer y último pago (frame)',
 'Para cada crédito con pagos, el monto de su primer y su último pago (por fecha, desempatando por id). Cuidado con el frame por defecto de last_value.',
 'first_value y last_value sobre la misma ventana, pero last_value necesita un frame que llegue hasta UNBOUNDED FOLLOWING.',
 'credito_id bigint, primer_pago numeric(18,2), ultimo_pago numeric(18,2)', false, 'hash', 4);
SELECT lab.calcular_esperado('E43', $sol$
  SELECT DISTINCT credito_id,
         first_value(monto) OVER w AS primer_pago,
         last_value(monto)  OVER w AS ultimo_pago
  FROM core.pago
  WINDOW w AS (PARTITION BY credito_id ORDER BY fecha_pago, id
               ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E44',5,'Último pago con DISTINCT ON',
 'El último pago de cada crédito (id y monto), resuelto con la extensión DISTINCT ON de Postgres.',
 'DISTINCT ON (credito_id) con ORDER BY credito_id, fecha_pago DESC.',
 'credito_id bigint, pago_id bigint, monto numeric(18,2)', false, 'hash', 4);
SELECT lab.calcular_esperado('E44', $sol$
  SELECT DISTINCT ON (credito_id) credito_id, id AS pago_id, monto
  FROM core.pago ORDER BY credito_id, fecha_pago DESC, id DESC
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E45',5,'Cosechas: peor a mejor',
 'Por mes de originación (cohorte), el número de créditos, el porcentaje que terminó mal (vencido o castigado, ::numeric(6,2)) y su posición en un ranking de peor a mejor tasa de mora. Este ejercicio descubre qué cosechas se comportaron peor.',
 'Agrega por cohorte en un CTE, y usa rank() OVER (ORDER BY tasa_mala DESC) para ordenarlas.',
 'cohorte date, num_creditos bigint, pct_malo numeric(6,2), rank_peor bigint', false, 'hash', 4);
SELECT lab.calcular_esperado('E45', $sol$
  WITH coh AS (
    SELECT date_trunc('month', fecha_originacion)::date AS cohorte,
           count(*) AS n,
           count(*) FILTER (WHERE estado IN ('vencido','castigado')) AS malos
    FROM core.credito GROUP BY 1)
  SELECT cohorte, n AS num_creditos,
         (100.0 * malos / n)::numeric(6,2) AS pct_malo,
         rank() OVER (ORDER BY (1.0 * malos / n) DESC) AS rank_peor
  FROM coh
$sol$);

-- Módulo 6 (Avanzado)

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E46',6,'Plan de cuentas aplanado',
 'Aplana el catálogo de cuentas contables mostrando, por cuenta, su código, nombre, nivel (las raíces son nivel 1) y su ruta desde la raíz separada por " > ".',
 'CTE recursivo. El caso base son las cuentas con padre_id NULL, y el paso recursivo une los hijos y concatena código y nivel.',
 'codigo text, nombre text, nivel integer, ruta text', false, 'hash', 4);
SELECT lab.calcular_esperado('E46', $sol$
  WITH RECURSIVE t AS (
    SELECT id, codigo, nombre, padre_id, 1 AS nivel, codigo::text AS ruta
    FROM core.cuenta_contable WHERE padre_id IS NULL
    UNION ALL
    SELECT c.id, c.codigo, c.nombre, c.padre_id, t.nivel + 1, t.ruta || ' > ' || c.codigo
    FROM core.cuenta_contable c JOIN t ON c.padre_id = t.id)
  SELECT codigo, nombre, nivel, ruta FROM t
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E47',6,'Cadena de mando',
 'Para el asesor con el id más pequeño, reconstruye su cadena de mando hacia arriba hasta el director, con nivel (1 = el propio asesor), nombre y puesto. El orden importa (de abajo hacia arriba).',
 'CTE recursivo que arranca en el asesor y sube por jefe_id.',
 'nivel integer, nombre text, puesto text', true, 'hash', 4);
SELECT lab.calcular_esperado('E47', $sol$
  WITH RECURSIVE cadena AS (
    SELECT id, nombre, puesto, jefe_id, 1 AS nivel
    FROM core.empleado WHERE id = (SELECT min(id) FROM core.empleado WHERE puesto = 'asesor')
    UNION ALL
    SELECT e.id, e.nombre, e.puesto, e.jefe_id, cadena.nivel + 1
    FROM core.empleado e JOIN cadena ON e.id = cadena.jefe_id)
  SELECT nivel, nombre, puesto FROM cadena ORDER BY nivel
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E48',6,'Reconstruir la amortización',
 'Reconstruye desde cero (sin leer core.amortizacion) el plan de pagos del crédito 1 por el sistema francés, con num_cuota, cuota, capital, interés y saldo tras la cuota, todos ::numeric(18,2). El orden importa.',
 'CTE recursivo sobre el saldo. La cuota es fija, el interés del período es saldo*i, el capital es cuota menos interés y el saldo baja.',
 'num_cuota integer, cuota numeric(18,2), capital numeric(18,2), interes numeric(18,2), saldo numeric(18,2)', true, 'hash', 4);
SELECT lab.calcular_esperado('E48', $sol$
  WITH RECURSIVE p AS (
    SELECT monto_originado AS p0, tasa_pactada / 12.0 AS i, plazo_meses AS n,
           round(monto_originado * (tasa_pactada/12.0) / (1 - power(1 + tasa_pactada/12.0, -plazo_meses)), 2) AS cuota
    FROM core.credito WHERE id = 1),
  s AS (
    SELECT 1 AS num_cuota, cuota, round(p0*i,2) AS interes,
           round(cuota - round(p0*i,2),2) AS capital,
           round(p0 - (cuota - round(p0*i,2)),2) AS saldo, i, n, cuota AS cuota0
    FROM p
    UNION ALL
    SELECT num_cuota+1, cuota0, round(saldo*i,2),
           round(cuota0 - round(saldo*i,2),2),
           round(saldo - (cuota0 - round(saldo*i,2)),2), i, n, cuota0
    FROM s WHERE num_cuota < n)
  SELECT num_cuota, cuota::numeric(18,2), capital::numeric(18,2),
         interes::numeric(18,2), saldo::numeric(18,2) AS saldo
  FROM s ORDER BY num_cuota
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E49',6,'Top 3 pagos por crédito',
 'Los tres pagos más grandes de cada crédito (id del pago y monto). Ante empate de monto, el de menor id.',
 'Con un CROSS JOIN LATERAL que traiga los 3 pagos mayores por crédito (ORDER BY monto DESC LIMIT 3), o con row_number() y rn<=3. Ambos dan el mismo resultado.',
 'credito_id bigint, pago_id bigint, monto numeric(18,2)', false, 'hash', 4);
-- La solución de referencia usa una ventana (una sola pasada) porque el índice
-- pago(credito_id) se omitió a propósito (E58) y el LATERAL sería lentísimo aquí.
-- El resultado es idéntico al del LATERAL.
SELECT lab.calcular_esperado('E49', $sol$
  SELECT credito_id, pago_id, monto FROM (
    SELECT p.credito_id, p.id AS pago_id, p.monto,
           row_number() OVER (PARTITION BY p.credito_id ORDER BY p.monto DESC, p.id) AS rn
    FROM core.pago p) x
  WHERE rn <= 3
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E50',6,'Balanza con subtotales',
 'Suma los cargos y abonos por naturaleza de cuenta (deudora/acreedora), agregando además un renglón de gran total (naturaleza en NULL). Montos ::numeric(18,2).',
 'GROUP BY ROLLUP(naturaleza) añade el renglón de total general.',
 'naturaleza text, total_cargo numeric(18,2), total_abono numeric(18,2)', false, 'hash', 4);
SELECT lab.calcular_esperado('E50', $sol$
  SELECT cc.naturaleza,
         sum(mc.cargo)::numeric(18,2) AS total_cargo,
         sum(mc.abono)::numeric(18,2) AS total_abono
  FROM core.movimiento_contable mc JOIN core.cuenta_contable cc ON cc.id = mc.cuenta_id
  GROUP BY ROLLUP (cc.naturaleza)
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E51',6,'Pagos de un crédito como JSON',
 'Para el crédito 1, arma un único arreglo JSON con sus pagos, cada elemento con las llaves pago_id y monto, ordenados por pago_id.',
 'jsonb_agg(jsonb_build_object(...) ORDER BY id) agrupando por crédito.',
 'credito_id bigint, pagos jsonb', false, 'hash', 4);
SELECT lab.calcular_esperado('E51', $sol$
  SELECT credito_id,
         jsonb_agg(jsonb_build_object('pago_id', id, 'monto', monto) ORDER BY id) AS pagos
  FROM core.pago WHERE credito_id = 1 GROUP BY credito_id
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E52',6,'Qué actualizaría un upsert',
 'Antes de castigar cartera, queremos ver qué créditos tocaría un UPDATE. Devuelve los créditos con más de 180 días de atraso que aún no están castigados, junto al estado nuevo que les pondríamos (castigado). No ejecutes el UPDATE, solo devuelve el conjunto que afectaría.',
 'Es el SELECT que va detrás de un UPDATE ... FROM, reutiliza el atraso por crédito y filtra dpd > 180 y estado <> castigado.',
 'credito_id bigint, estado_nuevo text', false, 'hash', 4);
SELECT lab.calcular_esperado('E52', $sol$
  WITH imp AS (
    SELECT a.credito_id, (lab.reloj()::date - min(a.fecha_vencimiento)) AS dpd
    FROM core.amortizacion a
    WHERE a.fecha_vencimiento < lab.reloj()::date
      AND NOT EXISTS (SELECT 1 FROM core.aplicacion_pago ap WHERE ap.amortizacion_id = a.id)
    GROUP BY a.credito_id)
  SELECT c.id AS credito_id, 'castigado'::text AS estado_nuevo
  FROM core.credito c JOIN imp i ON i.credito_id = c.id
  WHERE i.dpd > 180 AND c.estado <> 'castigado'
$sol$);

-- Módulo 7 (Correlación negocio ↔ sistema)

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E53',7,'Peticiones ligadas a un crédito',
 'Por servicio, cuántas peticiones HTTP quedaron asociadas a un crédito (tienen credito_id). Solo los servicios que tienen alguna.',
 'Filtra las peticiones con credito_id no nulo y agrupa por servicio.',
 'servicio text, num_peticiones_con_credito bigint', false, 'hash', 4);
SELECT lab.calcular_esperado('E53', $sol$
  SELECT s.nombre AS servicio, count(*) AS num_peticiones_con_credito
  FROM ops.peticion p JOIN ops.servicio s ON s.id = p.servicio_id
  WHERE p.credito_id IS NOT NULL
  GROUP BY s.nombre
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E54',7,'Latencia p95 por servicio y hora',
 'Para el 1 de junio de 2024, el percentil 95 de la duración (ms, ::numeric(18,2)) por servicio y hora. (Compara mentalmente con histogram_quantile de Prometheus, aquí el percentil es exacto, no estimado por buckets.)',
 'percentile_cont(0.95) WITHIN GROUP (ORDER BY duracion_ms), agrupando por servicio y por date_trunc de hora.',
 'servicio text, hora timestamptz, p95_ms numeric(18,2)', false, 'hash', 4);
SELECT lab.calcular_esperado('E54', $sol$
  SELECT s.nombre AS servicio, date_trunc('hour', p.ts) AS hora,
         percentile_cont(0.95) WITHIN GROUP (ORDER BY p.duracion_ms)::numeric(18,2) AS p95_ms
  FROM ops.peticion p JOIN ops.servicio s ON s.id = p.servicio_id
  WHERE p.ts >= TIMESTAMPTZ '2024-06-01 00:00:00-06'
    AND p.ts <  TIMESTAMPTZ '2024-06-02 00:00:00-06'
  GROUP BY s.nombre, date_trunc('hour', p.ts)
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E55',7,'Tasa de error por ventana de 5 min',
 'Entre las 00:00 y las 06:00 del 1 de junio de 2024, agrupa las peticiones en ventanas de 5 minutos y devuelve, por ventana, el total, cuántas fueron error (status >= 500) y el porcentaje de error (::numeric(6,2)).',
 'date_bin(''5 minutes'', ts, un origen) forma las ventanas, y cuenta con FILTER los status altos.',
 'ventana timestamptz, total bigint, errores bigint, pct_error numeric(6,2)', false, 'hash', 4);
SELECT lab.calcular_esperado('E55', $sol$
  SELECT date_bin('5 minutes', p.ts, TIMESTAMPTZ '2024-01-01 00:00:00-06') AS ventana,
         count(*) AS total,
         count(*) FILTER (WHERE p.status >= 500) AS errores,
         (100.0 * count(*) FILTER (WHERE p.status >= 500) / count(*))::numeric(6,2) AS pct_error
  FROM ops.peticion p
  WHERE p.ts >= TIMESTAMPTZ '2024-06-01 00:00:00-06'
    AND p.ts <  TIMESTAMPTZ '2024-06-01 06:00:00-06'
  GROUP BY 1
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E56',7,'El despliegue previo a cada incidente',
 'Para cada incidente, el último despliegue del mismo servicio ocurrido antes (o justo al inicio) del incidente, con id del incidente, servicio, inicio, y versión y fecha de ese despliegue. Si no hubo despliegue previo, esos campos quedan en NULL.',
 'Un LATERAL que, por incidente, trae el despliegue del mismo servicio con ts <= inicio, ordenado por ts DESC LIMIT 1.',
 'incidente_id bigint, servicio text, inicio timestamptz, despliegue_version text, despliegue_ts timestamptz', false, 'hash', 4);
SELECT lab.calcular_esperado('E56', $sol$
  SELECT i.id AS incidente_id, s.nombre AS servicio, i.inicio,
         d.version AS despliegue_version, d.ts AS despliegue_ts
  FROM ops.incidente i
  JOIN ops.servicio s ON s.id = i.servicio_id
  LEFT JOIN LATERAL (
    SELECT dd.version, dd.ts FROM ops.despliegue dd
    WHERE dd.servicio_id = i.servicio_id AND dd.ts <= i.inicio
    ORDER BY dd.ts DESC LIMIT 1) d ON true
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E57',7,'Impacto de negocio de las fallas',
 'Durante junio de 2024, cuántas peticiones ligadas a un crédito fallaron (status >= 500) y cuál es el monto originado total de esos créditos afectados (::numeric(18,2)). Una sola fila.',
 'Une peticion con credito por credito_id, filtra por error y por el mes, y suma el monto de los créditos.',
 'peticiones_fallidas bigint, monto_afectado numeric(18,2)', false, 'hash', 4);
SELECT lab.calcular_esperado('E57', $sol$
  SELECT count(*) AS peticiones_fallidas,
         coalesce(sum(c.monto_originado), 0)::numeric(18,2) AS monto_afectado
  FROM ops.peticion p JOIN core.credito c ON c.id = p.credito_id
  WHERE p.status >= 500
    AND p.ts >= TIMESTAMPTZ '2024-06-01 00:00:00-06'
    AND p.ts <  TIMESTAMPTZ '2024-07-01 00:00:00-06'
$sol$);

-- Módulo 8 (Rendimiento)

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E58',8,'El Seq Scan de los pagos',
 'Devuelve el total pagado del crédito 100 (::numeric(18,2)). Corre EXPLAIN (ANALYZE, BUFFERS) sobre tu consulta y veras un Seq Scan de core.pago porque falta el índice pago(credito_id). Crea el índice, vuelve a medir y compara (esa parte se evalúa a mano), y el número debe ser correcto.',
 'sum(monto) filtrando por credito_id. El aprendizaje está en el plan, ya que CREATE INDEX ... ON core.pago(credito_id) elimina el Seq Scan.',
 'total_pagado numeric(18,2)', false, 'hash', 5);
SELECT lab.calcular_esperado('E58', $sol$
  SELECT coalesce(sum(monto), 0)::numeric(18,2) AS total_pagado
  FROM core.pago WHERE credito_id = 100
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E59',8,'Reescribir sin cambiar el resultado',
 'Los 10 créditos con mayor monto originado (id y monto), desempatando por id ascendente. El orden importa. Escribe la consulta más eficiente que se te ocurra, el resultado debe ser exactamente este.',
 'ORDER BY monto DESC, id ASC con LIMIT 10. Con el índice adecuado ni siquiera hace falta ordenar todo.',
 'credito_id bigint, monto_originado numeric(18,2)', true, 'hash', 5);
SELECT lab.calcular_esperado('E59', $sol$
  SELECT id AS credito_id, monto_originado
  FROM core.credito ORDER BY monto_originado DESC, id ASC LIMIT 10
$sol$);

INSERT INTO lab.ejercicio (codigo,modulo,titulo,enunciado,pista,columnas_esp,orden_importa,validacion,dificultad) VALUES
('E60',8,'Índice compuesto vs dos simples',
 'La consulta que cruza ops.peticion por credito_id y ts no tiene índice (se omitió a propósito). Experimenta un poco, mide un filtro por credito_id y ts con EXPLAIN, crea un índice compuesto ops.peticion(credito_id, ts) y dos simples por separado, compara los planes, y observa cómo cambia todo si ejecutas ANALYZE antes y después. Este ejercicio se valida a mano (no hay hash), escribe tus hallazgos.',
 'Un índice compuesto (credito_id, ts) sirve para el filtro combinado, y dos simples obligan a un BitmapAnd. ANALYZE actualiza las estadísticas que el planeador usa para decidir.',
 '(hallazgos en texto libre)', false, 'manual', 5);
