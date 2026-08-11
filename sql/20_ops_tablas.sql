-- DDL del esquema de telemetría (ops).

-- La idea es que este es un módulo "avanzado" y opcional para correlacionar el negocio (core) con el comportamiento
-- del sistema. Esto es más para mi que para el laboratorio en general. Las FKs se agregan en 50_indices.sql tras la carga.

-- Los microservicios del core bancario. Todo lo demás de ops (despliegues, peticiones,
-- incidentes y métricas) cuelga de aquí por servicio_id.
CREATE TABLE IF NOT EXISTS ops.servicio (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre     text NOT NULL UNIQUE,
  equipo     text,
  criticidad text,
  CONSTRAINT ck_servicio_crit CHECK (criticidad IS NULL OR criticidad IN ('baja','media','alta','critica'))
);

-- Cada release de un servicio. rollback marca si fue una reversión, y un despliegue
-- suele venir antes de un incidente, que es la base del módulo de correlación.
CREATE TABLE IF NOT EXISTS ops.despliegue (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  servicio_id bigint NOT NULL,
  version     text,
  ts          timestamptz NOT NULL,
  autor       text,
  rollback    boolean NOT NULL DEFAULT false
);

-- Muestreo de peticiones HTTP. status y duracion_ms dan errores y latencia, y credito_id
-- liga la petición con un crédito del negocio cuando aplica.
CREATE TABLE IF NOT EXISTS ops.peticion (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  servicio_id bigint NOT NULL,
  ruta        text,
  metodo      text,
  status      int,
  duracion_ms numeric,
  ts          timestamptz NOT NULL,
  credito_id  bigint,                         -- NULL salvo peticiones ligadas a un crédito
  CONSTRAINT ck_peticion_status CHECK (status IS NULL OR (status >= 100 AND status < 600))
);

-- Incidentes operativos por servicio. Un fin en NULL significa que sigue abierto.
CREATE TABLE IF NOT EXISTS ops.incidente (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  servicio_id bigint NOT NULL,
  inicio      timestamptz NOT NULL,
  fin         timestamptz,                    -- NULL si sigue abierto
  severidad   text,
  descripcion text,
  CONSTRAINT ck_incidente_sev   CHECK (severidad IS NULL OR severidad IN ('sev1','sev2','sev3')),
  CONSTRAINT ck_incidente_rango CHECK (fin IS NULL OR fin >= inicio)
);

-- Métricas del sistema muestreadas cada minuto, una serie temporal por servicio.
CREATE TABLE IF NOT EXISTS ops.metrica_muestra (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  servicio_id bigint NOT NULL,
  nombre      text,
  valor       numeric,
  ts          timestamptz NOT NULL
);
