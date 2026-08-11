-- Los datos tienen que ser fijos (y no depender de SCALE), como productos, esquemas de rendimiento,
-- catálogos SPEI/MCC, plan de cuentas, sucursales, empleados (con jerarquía) y la
-- serie diaria de TIIE.

-- Tiene que ser determinista, uso setseed(0.42) al inicio. La misma semilla produce lo mismo.
-- Cambiar esta semilla cambia TODOS los datos y por tanto los hashes esperados.

\timing on
SELECT setseed(0.42);

-- Productos de crédito
INSERT INTO core.producto_credito
  (codigo, nombre, tasa_nominal_anual, plazo_min, plazo_max, monto_min, monto_max, comision_apertura)
VALUES
  ('PER', 'Crédito Personal',      0.4800, 6,  36,  5000,   150000, 0.0300),
  ('NOM', 'Crédito de Nómina',     0.3200, 6,  48,  8000,   300000, 0.0200),
  ('PYM', 'Crédito PyME',          0.2800, 12, 60,  50000,  2000000,0.0250),
  ('AUT', 'Crédito Automotriz',    0.1900, 12, 72,  80000,  800000, 0.0150),
  ('CON', 'Crédito de Consumo',    0.5500, 3,  24,  2000,   60000,  0.0350),
  ('MIC', 'Microcrédito Grupal',   0.6500, 4,  16,  1500,   30000,  0.0400);

-- Esquemas de rendimiento (captación)
INSERT INTO core.esquema_rendimiento (nombre, tasa_anual, periodicidad_pago, dias_base, isr_exento)
VALUES
  ('Ahorro Vista',      0.0300, 'mensual',        365, false),
  ('Ahorro Plus',       0.0650, 'mensual',        360, false),
  ('PRLV 28 días',      0.0925, 'al_vencimiento', 360, false),
  ('PRLV 91 días',      0.1050, 'al_vencimiento', 360, false);

-- Catálogo de instituciones SPEI (bancos reales, datos públicos)
INSERT INTO core.cat_institucion_spei (clave, participante, abm_code, permite_transferencia, permite_deposito)
VALUES
  ('40002','BANAMEX','002',   true,true), ('40012','BBVA MEXICO','012', true,true),
  ('40014','SANTANDER','014', true,true), ('40021','HSBC','021',        true,true),
  ('40036','INBURSA','036',   true,true), ('40044','SCOTIABANK','044',  true,true),
  ('40072','BANORTE','072',   true,true), ('40127','AZTECA','127',      true,true),
  ('40137','BANCOPPEL','137', true,true), ('40147','BANKAOOL','147',    true,true),
  ('40158','MIFEL','158',     true,true), ('40130','COMPARTAMOS','130', true,true),
  ('40638','NVIO','638',      true,true), ('90646','STP','646',         true,true);

-- Catálogo MCC
INSERT INTO core.cat_mcc (mcc, descripcion, giro) VALUES
  ('5411','Supermercados','Abarrotes'),        ('5541','Gasolineras','Combustible'),
  ('5812','Restaurantes','Alimentos'),         ('5814','Comida rápida','Alimentos'),
  ('5912','Farmacias','Salud'),                ('5311','Tiendas departamentales','Retail'),
  ('4111','Transporte urbano','Transporte'),   ('4814','Telecomunicaciones','Servicios'),
  ('5999','Comercio misceláneo','Retail'),     ('6011','Retiro en cajero','Efectivo'),
  ('5732','Electrónica','Retail'),             ('5651','Ropa','Retail'),
  ('7011','Hoteles','Viajes'),                 ('4900','Servicios (agua/luz)','Servicios'),
  ('8062','Hospitales','Salud'),               ('5942','Librerías','Retail'),
  ('5921','Vinos y licores','Alimentos'),      ('4121','Taxis y apps de viaje','Transporte'),
  ('5661','Zapaterías','Retail'),              ('7832','Cines','Entretenimiento');

-- Plan de cuentas contables (jerárquico)
-- Raíces (padre NULL)
INSERT INTO core.cuenta_contable (codigo, nombre, naturaleza, padre_id) VALUES
  ('1000','Activo','deudora',NULL), ('2000','Pasivo','acreedora',NULL),
  ('3000','Capital','acreedora',NULL), ('4000','Ingresos','acreedora',NULL),
  ('5000','Gastos','deudora',NULL);
-- Nivel 2 y 3 (padre por código)
INSERT INTO core.cuenta_contable (codigo, nombre, naturaleza, padre_id)
SELECT v.codigo, v.nombre, v.naturaleza, p.id
FROM (VALUES
  ('1100','Cartera de crédito','deudora','1000'),
  ('1200','Disponibilidades','deudora','1000'),
  ('1300','Estimación preventiva para riesgos','acreedora','1000'),
  ('2100','Captación','acreedora','2000'),
  ('2200','Acreedores diversos','acreedora','2000'),
  ('2300','Impuestos por pagar','acreedora','2000'),
  ('3100','Capital social','acreedora','3000'),
  ('3200','Resultado del ejercicio','acreedora','3000'),
  ('4100','Ingresos por intereses','acreedora','4000'),
  ('4200','Comisiones cobradas','acreedora','4000'),
  ('5100','Gastos por intereses (rendimientos)','deudora','5000'),
  ('5200','Estimación preventiva (gasto)','deudora','5000'),
  ('5300','Gastos de administración','deudora','5000')
) v(codigo,nombre,naturaleza,padre_codigo)
JOIN core.cuenta_contable p ON p.codigo = v.padre_codigo;

INSERT INTO core.cuenta_contable (codigo, nombre, naturaleza, padre_id)
SELECT v.codigo, v.nombre, v.naturaleza, p.id
FROM (VALUES
  ('1101','Cartera vigente','deudora','1100'),
  ('1102','Cartera vencida','deudora','1100'),
  ('1201','Caja','deudora','1200'),
  ('1202','Bancos','deudora','1200'),
  ('2101','Depósitos a la vista','acreedora','2100'),
  ('2102','Depósitos a plazo','acreedora','2100'),
  ('2301','ISR retenido por pagar','acreedora','2300'),
  ('2302','IVA por pagar','acreedora','2300')
) v(codigo,nombre,naturaleza,padre_codigo)
JOIN core.cuenta_contable p ON p.codigo = v.padre_codigo;

-- Sucursales (40 fijas)
-- SUC-040 queda cerrada (fecha_cierre no nula). SUC-039 se dejará SIN créditos
-- en la generación masiva (41). Ambas son material didáctico para LEFT JOIN.
INSERT INTO core.sucursal (codigo, nombre, ciudad, estado, fecha_apertura, fecha_cierre)
SELECT
  'SUC-' || lpad(g::text, 3, '0'),
  'Sucursal ' || (ARRAY['Centro','Norte','Sur','Reforma','Insurgentes','Polanco','Roma','Del Valle','Satélite','Coyoacán'])[1 + (g % 10)],
  (ARRAY['CDMX','Guadalajara','Monterrey','Puebla','Querétaro','Mérida','Tijuana','León','Toluca','Cancún'])[1 + (g % 10)],
  (ARRAY['CDMX','Jalisco','Nuevo León','Puebla','Querétaro','Yucatán','Baja California','Guanajuato','México','Quintana Roo'])[1 + (g % 10)],
  DATE '2015-01-01' + (random() * 2190)::int,
  CASE WHEN g = 40 THEN DATE '2024-06-30' ELSE NULL END
FROM generate_series(1, 40) g;

-- Empleados (400 en jerarquía de director, gerente y asesor)
-- Wave 1, el director (jefe NULL).
INSERT INTO core.empleado (sucursal_id, jefe_id, nombre, puesto, fecha_ingreso, activo)
SELECT (SELECT id FROM core.sucursal ORDER BY id LIMIT 1), NULL,
       'Alejandra Ríos', 'director', DATE '2015-02-01', true;

-- Wave 2, un gerente por sucursal, reporta al director.
INSERT INTO core.empleado (sucursal_id, jefe_id, nombre, puesto, fecha_ingreso, activo)
SELECT s.id,
       (SELECT id FROM core.empleado WHERE puesto='director'),
       'Gerente ' || (ARRAY['García','Hernández','López','Martínez','Pérez','Sánchez','Ramírez','Torres','Flores','Vargas'])[1 + (s.id % 10)] || ' ' || s.codigo,
       'gerente',
       DATE '2016-01-01' + (random() * 1460)::int, true
FROM core.sucursal s;

-- Wave 3, asesores hasta llegar a 400, reportando al gerente de su sucursal.
WITH suc AS (SELECT id, row_number() OVER (ORDER BY id) AS rn, count(*) OVER () AS total FROM core.sucursal),
     ger AS (SELECT id, sucursal_id FROM core.empleado WHERE puesto='gerente')
INSERT INTO core.empleado (sucursal_id, jefe_id, nombre, puesto, fecha_ingreso, activo)
SELECT su.id, ger.id,
       (ARRAY['Juan','María','José','Guadalupe','Francisco','Verónica','Luis','Ana','Miguel','Rosa','Carlos','Laura','Jorge','Patricia','Ricardo'])[1 + (n % 15)]
         || ' ' ||
       (ARRAY['García','Hernández','López','González','Rodríguez','Pérez','Sánchez','Ramírez','Cruz','Flores','Gómez','Díaz','Reyes','Morales','Jiménez'])[1 + ((n / 3) % 15)],
       'asesor',
       DATE '2018-01-01' + (random() * 2200)::int,
       (random() > 0.05)
FROM generate_series(1, 359) n
JOIN suc su ON su.rn = 1 + (n % su.total)
JOIN ger ON ger.sucursal_id = su.id;

-- TIIE diaria (solo días hábiles, con huecos en fines de semana y festivos)
-- Trayectoria aproximada que sube de ~4.25% (2021) a ~11.25% (mediados de 2023) y
-- baja ligeramente hacia 2025. Ruido pequeño para que LAG/LEAD tenga variación.
INSERT INTO core.tasa_referencia (fecha, tiie)
SELECT d::date,
  round((
    CASE WHEN d::date < DATE '2023-06-01'
      THEN 0.0425 + (d::date - DATE '2021-01-01')::numeric / (DATE '2023-06-01' - DATE '2021-01-01') * (0.1125 - 0.0425)
      ELSE 0.1125 + (d::date - DATE '2023-06-01')::numeric / (DATE '2025-12-31' - DATE '2023-06-01') * (0.1000 - 0.1125)
    END
    + (random() - 0.5) * 0.001
  )::numeric, 4)
FROM generate_series(DATE '2021-01-01', DATE '2025-12-31', INTERVAL '1 day') d
WHERE extract(isodow FROM d) < 6              -- lunes a viernes
  AND to_char(d, 'MM-DD') NOT IN             -- festivos de calendario fijo
      ('01-01','02-05','03-21','05-01','09-16','11-20','12-25');
