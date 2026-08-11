-- COMMENT ON del esquema ops.

COMMENT ON TABLE  ops.servicio IS 'Microservicios del core bancario, con su equipo dueño y criticidad.';
COMMENT ON COLUMN ops.servicio.nombre IS 'Nombre del servicio.';
COMMENT ON COLUMN ops.servicio.equipo IS 'Equipo responsable del servicio.';
COMMENT ON COLUMN ops.servicio.criticidad IS 'Qué tan crítico es, ya sea baja, media, alta o critica.';

COMMENT ON TABLE  ops.despliegue IS 'Releases de cada servicio. Un despliegue puede venir antes de un incidente, y esa es la base del módulo de correlación.';
COMMENT ON COLUMN ops.despliegue.servicio_id IS 'Servicio desplegado.';
COMMENT ON COLUMN ops.despliegue.version IS 'Versión liberada.';
COMMENT ON COLUMN ops.despliegue.ts IS 'Instante del despliegue.';
COMMENT ON COLUMN ops.despliegue.autor IS 'Quién liberó.';
COMMENT ON COLUMN ops.despliegue.rollback IS 'Si el despliegue fue una reversión de otro.';

COMMENT ON TABLE  ops.peticion IS 'Muestreo de peticiones HTTP. duracion_ms y status permiten medir latencia y errores, y credito_id liga la petición con el negocio.';
COMMENT ON COLUMN ops.peticion.servicio_id IS 'Servicio que atendió la petición.';
COMMENT ON COLUMN ops.peticion.ruta IS 'Ruta o endpoint solicitado.';
COMMENT ON COLUMN ops.peticion.metodo IS 'Método HTTP (GET, POST, ...).';
COMMENT ON COLUMN ops.peticion.status IS 'Código de estado HTTP. status >= 500 indica error del servidor.';
COMMENT ON COLUMN ops.peticion.duracion_ms IS 'Duración de la petición en milisegundos. Base de los percentiles de latencia.';
COMMENT ON COLUMN ops.peticion.ts IS 'Instante de la petición.';
COMMENT ON COLUMN ops.peticion.credito_id IS 'Crédito asociado (p. ej. un desembolso). NULL en peticiones no ligadas a un crédito.';

COMMENT ON TABLE  ops.incidente IS 'Incidentes operativos. Uno permanece abierto (fin NULL) a propósito.';
COMMENT ON COLUMN ops.incidente.servicio_id IS 'Servicio afectado.';
COMMENT ON COLUMN ops.incidente.inicio IS 'Instante de inicio del incidente.';
COMMENT ON COLUMN ops.incidente.fin IS 'Instante de cierre. NULL si sigue abierto.';
COMMENT ON COLUMN ops.incidente.severidad IS 'sev1 (peor) a sev3.';
COMMENT ON COLUMN ops.incidente.descripcion IS 'Resumen del incidente.';

COMMENT ON TABLE  ops.metrica_muestra IS 'Serie de métricas del sistema a granularidad de 1 minuto.';
COMMENT ON COLUMN ops.metrica_muestra.servicio_id IS 'Servicio al que pertenece la métrica.';
COMMENT ON COLUMN ops.metrica_muestra.nombre IS 'Nombre de la métrica (cpu, memoria, rps, ...).';
COMMENT ON COLUMN ops.metrica_muestra.valor IS 'Valor observado.';
COMMENT ON COLUMN ops.metrica_muestra.ts IS 'Instante de la muestra.';

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
    WHERE c.table_schema = 'ops' AND d.description IS NULL
  LOOP
    EXECUTE format('COMMENT ON COLUMN ops.%I.%I IS %L',
      r.table_name, r.column_name,
      'Identificador sustituto (bigint IDENTITY). Llave primaria interna.');
  END LOOP;
END $$;
