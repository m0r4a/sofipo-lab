-- Aquí están los tres esquemas del laboratorio.

-- core es el negocio bancario (clientes, créditos, captación, tarjetas,
--       transferencias, contabilidad). Es la mayoría del "curso".
CREATE SCHEMA IF NOT EXISTS core;

-- ops es la telemetría del propio sistema (peticiones HTTP, despliegues, incidentes,
--      métricas). Es un módulo opcional, yo lo usaré porque es mi rama de trabajo, correlacionas negocio y sistema.
CREATE SCHEMA IF NOT EXISTS ops;

-- lab es la infraestructura del laboratorio (catálogo de ejercicios, intentos,
--      funciones de verificación y ayuda). No es parte de lo bancario pero sí del proyecto.
CREATE SCHEMA IF NOT EXISTS lab;
