-- Infraestructura del laboratorio (esquema lab), tiene reloj fijo, catálogo de
-- ejercicios, registro de intentos y motor de verificación. Se ejecuta antes de la
-- generación de datos porque el reloj fijo se usa para calcular antigüedades de
-- forma determinista (para poder calcular esto de los hashes).

-- El reloj tiene que estar FIJO, todos los cálculos de "hoy" (antigüedad, días de mora, edad) usan esta función
-- y nunca un now(). Así el seed es determinista y la misma seed produce los mismos datos.

CREATE OR REPLACE FUNCTION lab.reloj() RETURNS timestamptz
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT TIMESTAMPTZ '2026-01-01 00:00:00-06' $$;

COMMENT ON FUNCTION lab.reloj() IS 'Reloj fijo del laboratorio (2026-01-01). Reemplaza a now() en la generación de datos para que todo sea reproducible.';

CREATE TABLE IF NOT EXISTS lab.ejercicio (
  codigo         text PRIMARY KEY,            -- 'E01'..'E60'
  modulo         int  NOT NULL,
  titulo         text NOT NULL,
  enunciado      text NOT NULL,
  pista          text,
  columnas_esp   text,                        -- contrato de salida legible
  orden_importa  boolean NOT NULL DEFAULT false,
  validacion     text NOT NULL DEFAULT 'hash', -- 'hash' o 'manual'
  hash_esperado  text,                        -- se calcula durante el seed
  filas_esperadas int,                        -- idem
  firma_columnas text,                        -- idem (nombre y tipo de cada columna)
  dificultad     int,                         -- 1..5
  pistas_pedidas int NOT NULL DEFAULT 0,
  CONSTRAINT ck_ej_validacion CHECK (validacion IN ('hash','manual'))
);
COMMENT ON TABLE lab.ejercicio IS 'Catálogo de los 60 ejercicios, con enunciado, contrato de columnas, pista y valor esperado (hash) calculado durante el seed.';

CREATE TABLE IF NOT EXISTS lab.intento (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo      text NOT NULL,
  ts          timestamptz NOT NULL DEFAULT now(),  -- aquí now() sí, se va usar como bitácora y no como dato del dominio
  correcto    boolean,
  sql_enviado text,
  ms          numeric
);
COMMENT ON TABLE lab.intento IS 'Bitácora de cada verificación, correcta o no. Alimenta lab.progreso().';

-- Helper que evalúa un SQL y devuelve (hash, filas, firma de columnas).
-- Materializa el resultado en una tabla temporal, de la que se leen conteo,
-- columnas y contenido canónico. Lanza excepción si el SQL falla (la maneja quien llama).
CREATE OR REPLACE FUNCTION lab._evaluar(p_sql text, p_orden boolean)
  RETURNS TABLE(h text, n_filas int, firma text)
  LANGUAGE plpgsql AS
$$
DECLARE
  sql_limpio text := regexp_replace(p_sql, ';\s*$', '');  -- quita el punto y coma final
BEGIN
  PERFORM set_config('client_min_messages', 'warning', true);  -- calla el NOTICE del DROP IF EXISTS
  DROP TABLE IF EXISTS _lab_res;
  EXECUTE format('CREATE TEMP TABLE _lab_res AS %s', sql_limpio);

  SELECT string_agg(column_name || ':' || data_type, ',' ORDER BY ordinal_position)
    INTO firma
  FROM information_schema.columns
  WHERE table_name = '_lab_res' AND table_schema LIKE 'pg_temp%';

  EXECUTE 'SELECT count(*)::int FROM _lab_res' INTO n_filas;

  IF p_orden THEN
    EXECUTE 'SELECT md5(coalesce(string_agg(rn || ''|'' || fila, chr(10) ORDER BY rn), ''''))
             FROM (SELECT row_number() OVER () AS rn, _lab_res::text AS fila FROM _lab_res) s'
      INTO h;
  ELSE
    EXECUTE 'SELECT md5(coalesce(string_agg(fila, chr(10) ORDER BY fila), ''''))
             FROM (SELECT _lab_res::text AS fila FROM _lab_res) s'
      INTO h;
  END IF;

  DROP TABLE IF EXISTS _lab_res;
  RETURN NEXT;
END $$;

-- Calcula y almacena el valor esperado de un ejercicio (usado en el seed)
CREATE OR REPLACE FUNCTION lab.calcular_esperado(p_codigo text, p_sql text)
  RETURNS void LANGUAGE plpgsql AS
$$
DECLARE ej lab.ejercicio; r record;
BEGIN
  SELECT * INTO ej FROM lab.ejercicio WHERE codigo = p_codigo;
  IF NOT FOUND THEN RAISE EXCEPTION 'Ejercicio % no existe', p_codigo; END IF;
  IF ej.validacion = 'manual' THEN RETURN; END IF;

  SELECT * INTO r FROM lab._evaluar(p_sql, ej.orden_importa);
  UPDATE lab.ejercicio
     SET hash_esperado = r.h, filas_esperadas = r.n_filas, firma_columnas = r.firma
   WHERE codigo = p_codigo;
END $$;

-- Motor de verificación
CREATE OR REPLACE FUNCTION lab.verificar(p_codigo text, p_sql text)
  RETURNS text LANGUAGE plpgsql AS
$$
DECLARE
  ej lab.ejercicio;
  t0 timestamptz;
  dur_ms numeric;
  r record;
  ok boolean;
BEGIN
  SELECT * INTO ej FROM lab.ejercicio WHERE codigo = p_codigo;
  IF NOT FOUND THEN
    RETURN format('No existe el ejercicio %s.', p_codigo);
  END IF;

  IF ej.validacion = 'manual' THEN
    RETURN format('Ejercicio %s: se valida a mano (respuesta en palabras). No hay hash que comparar.', p_codigo);
  END IF;

  t0 := clock_timestamp();
  BEGIN
    SELECT * INTO r FROM lab._evaluar(p_sql, ej.orden_importa);
  EXCEPTION WHEN OTHERS THEN
    dur_ms := 1000 * extract(epoch FROM clock_timestamp() - t0);
    INSERT INTO lab.intento(codigo, correcto, sql_enviado, ms)
      VALUES (p_codigo, false, p_sql, dur_ms);
    RETURN format('✗ Error de SQL [%s]: %s', SQLSTATE, SQLERRM);
  END;
  dur_ms := 1000 * extract(epoch FROM clock_timestamp() - t0);

  ok := (r.h = ej.hash_esperado);
  INSERT INTO lab.intento(codigo, correcto, sql_enviado, ms)
    VALUES (p_codigo, ok, p_sql, dur_ms);

  IF ok THEN
    RETURN format('✓ Correcto (%s ms, %s filas).', round(dur_ms, 1), r.n_filas);
  ELSIF r.firma IS DISTINCT FROM ej.firma_columnas THEN
    RETURN format('✗ Columnas distintas.%s  Esperado: %s%s  Obtenido: %s',
                  chr(10), ej.firma_columnas, chr(10), r.firma);
  ELSIF r.n_filas <> ej.filas_esperadas THEN
    RETURN format('✗ Número de filas: esperado %s, obtenido %s. Suele ser un JOIN que sobra o falta, o un filtro.',
                  ej.filas_esperadas, r.n_filas);
  ELSE
    RETURN '✗ Mismas columnas y mismo número de filas, pero el contenido difiere. Revisa redondeo (::numeric(18,2)), tipos y, si el orden importa, el ORDER BY.';
  END IF;
END $$;

-- Ayuda
CREATE OR REPLACE FUNCTION lab.pista(p_codigo text) RETURNS text
  LANGUAGE plpgsql AS
$$
DECLARE p text;
BEGIN
  UPDATE lab.ejercicio SET pistas_pedidas = pistas_pedidas + 1
   WHERE codigo = p_codigo
   RETURNING pista INTO p;
  IF NOT FOUND THEN RETURN format('No existe el ejercicio %s.', p_codigo); END IF;
  RETURN coalesce(p, 'Este ejercicio no tiene pista.');
END $$;

CREATE OR REPLACE FUNCTION lab.enunciado(p_codigo text) RETURNS text
  LANGUAGE sql AS
$$
  SELECT format(E'[%s] %s (módulo %s, dificultad %s)\n\n%s\n\nColumnas esperadas: %s\n\nConceptos de negocio: docs/glosario-financiero.md (en tu terminal: just glosario <término>)',
                codigo, titulo, modulo, dificultad, enunciado, coalesce(columnas_esp, '(libre)'))
  FROM lab.ejercicio WHERE codigo = p_codigo;
$$;

CREATE OR REPLACE FUNCTION lab.progreso()
  RETURNS TABLE(modulo int, resueltos bigint, total bigint, intentos bigint, avance text)
  LANGUAGE sql AS
$$
  SELECT e.modulo,
         count(*) FILTER (WHERE s.resuelto)                              AS resueltos,
         count(*)                                                        AS total,
         coalesce(sum(s.n_intentos), 0)                                  AS intentos,
         to_char(100.0 * count(*) FILTER (WHERE s.resuelto) / count(*), 'FM990.0') || '%' AS avance
  FROM lab.ejercicio e
  LEFT JOIN LATERAL (
    SELECT bool_or(i.correcto) AS resuelto, count(*) AS n_intentos
    FROM lab.intento i WHERE i.codigo = e.codigo
  ) s ON true
  GROUP BY e.modulo
  ORDER BY e.modulo;
$$;

CREATE OR REPLACE FUNCTION lab.siguiente()
  RETURNS TABLE(codigo text, modulo int, dificultad int, titulo text)
  LANGUAGE sql AS
$$
  SELECT e.codigo, e.modulo, e.dificultad, e.titulo
  FROM lab.ejercicio e
  WHERE e.validacion = 'hash'
    AND NOT EXISTS (SELECT 1 FROM lab.intento i WHERE i.codigo = e.codigo AND i.correcto)
  ORDER BY e.dificultad, e.codigo
  LIMIT 1;
$$;
