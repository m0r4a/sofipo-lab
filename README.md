# sofipo-lab

Un laboratorio de PostgreSQL para practicar SQL sobre un dominio de banca popular mexicana (una SOFIPO): crédito, captación, tarjetas, transferencias SPEI y contabilidad de partida doble. Incluye además un esquema de telemetría del sistema (`ops`) para practicar la correlación entre negocio y operación.

Lo armé para practicar y lo comparto por si le sirve a alguien más. Son 60 ejercicios en 9 módulos de dificultad que va incrementando. Cada uno se corrige solo contra un hash, sin darte la solución. El laboratorio genera ~8.8 millones de filas que son deterministas con SQL puro, así que no necesitas datos externos ni conexión a nada.

## Tabla de contenidos

- [¿Qué es esto?](#qué-es-esto)
- [Requisitos](#requisitos)
- [Quickstart](#quickstart)
- [Cómo resolver un ejercicio](#cómo-resolver-un-ejercicio)
- [El "contrato" de salida](#el-contrato-de-salida)
- [Hay 9 módulos](#hay-9-módulos)
- [El dominio de datos](#el-dominio-de-datos)
- [Comandos (`just`)](#comandos-just)
- [Atajos dentro de `psql`](#atajos-dentro-de-psql)
- [Escala](#escala)
- [Determinismo y reproducibilidad](#determinismo-y-reproducibilidad)
- [Mapa del repositorio](#mapa-del-repositorio)
- [Documentación](#documentación)
- [Soluciones de referencia](#soluciones-de-referencia)
- [Problemas comunes](#problemas-comunes)
- [Notas de diseño](#notas-de-diseño)
- [Licencia](#licencia)

## ¿Qué es esto?

Un entorno "autocontenido" para aprender SQL practicando sobre datos que se parecen a los de un sistema bancario. Todo corre en un contenedor de PostgreSQL 18, tú escribes consultas y el laboratorio las califica.

Hay 3 piezas:

- **El dominio (`core`)**: el negocio de una SOFIPO. Clientes, créditos y su plan de amortización, pagos, captación (ahorro), tarjetas, transferencias y contabilidad. Es donde vive casi todo el temario.

- **La telemetría (`ops`)**: peticiones HTTP, despliegues, incidentes y métricas del sistema. Un módulo opcional para cruzar el negocio con la operación (por ejemplo, si un despliegue coincidió con desembolsos fallidos).

- **El laboratorio (`lab`)**: el catálogo de ejercicios, el registro de intentos y el motor que verifica tus respuestas.

Cada ejercicio pide un resultado en lenguaje de negocio (no nombra la construcción SQL). Escribes tu consulta, la verificas, y el motor te dice si el resultado coincide o en qué difiere. Los datos son 100% sintéticos: los identificadores como CURP, RFC y CLABE tienen formatos "correctos" pero son inválidos.

## Requisitos

- Docker con Compose v2 (`docker compose`).
- [`just`](https://github.com/casey/just) (el ejecutor de tareas).


> [!NOTE]
>No necesitas `psql` en tu máquina, todo corre dentro del contenedor.

PostgreSQL 18 se expone en el puerto `5433` del host (configurable) para no chocar con un Postgres local en el `5432`.

## Quickstart

```bash
cp .env.example .env     # esta es configuración por defecto (puerto 5433, SCALE=1)
just up                  # levanta PostgreSQL 18 y espera a que esté listo
just seed                # crea el esquema y genera los datos (~1 min)
just siguiente           # muestra el primer ejercicio
just psql                # abre una sesión interactiva (opcional)
```

Para reconstruir todo desde cero en cualquier momento: `just reset`.

## Cómo resolver un ejercicio

El ciclo de resolver un ejercicio desde la CLI se ve masomenos así:

1. **Mira cuál ejercicio sigue.** `just siguiente` te da el próximo ejercicio sin resolver. `just enunciado E05` muestra el enunciado completo y las columnas que debe devolver tu consulta.

2. **Entiende el vocabulario.** Si un término de negocio no te suena (mora, cartera vencida, cosecha, partida doble...), `just glosario <término>` te lo explica sin salir de la terminal. Sin argumento, `just glosario` lista todos los términos.

3. **Pide una pista** si la necesitas: `just pista E05` te ayuda sin darte la respuesta.

4. **Escribe tu consulta** en `respuestas/E05.sql`. Esa carpeta es para ti, ahí van todas las respuestas.

5. **Verifica:**
   ```bash
   just check E05
   ```

   Respuestas posibles:
   - `✓ Correcto (12.3 ms, 30000 filas)`: la respuesta coincide, con el tiempo que tardó.
   - `✗ Número de filas: esperado 30000, obtenido 29999`: te falta o te sobra una fila (habría que revisar el join o el filtro).
   - `✗ Columnas distintas`: el nombre o el tipo de alguna columna no coincide con el contrato.
   - `✗ Mismas filas y columnas pero el contenido difiere`: revisa redondeo, tipos y orden.
   - `✗ Error de SQL [42P01]: ...`: tu consulta no compiló, el mensaje dice por qué.

> No siempre está mal usar emojis

6. **Avanza.** `just progreso` muestra cuánto llevas por módulo.

## El "contrato" de salida

El motor compara tu resultado con el esperado convirtiendo cada fila a texto y sacando un hash. Eso significa que **el formato importa**: dos respuestas "correctas de negocio" pueden diferir por un tipo o un redondeo. Para evitarlo, cada enunciado fija el contrato y tú tienes que respetarlo:

- Todo **importe** se pide como `::numeric(18,2)`.
- Todo **porcentaje** como `::numeric(6,2)`.
- Toda **fecha** como `::date`.
- Los nombres de columna son **exactamente** los del enunciado.
- Si el enunciado dice "el orden importa", agrega el `ORDER BY`, si no, el orden da igual (el motor igual lo ordena, pero tú no lo tienes que hacer).

Ejemplo de una respuesta que falla **solo por formato** y su corrección:

```sql
-- Falla porque el monto está sin redondear (más de 2 decimales) y columna la columna está mal nombrada.
SELECT producto_id, avg(monto_originado) AS promedio
FROM core.credito GROUP BY producto_id;

-- Esta es correcta ya que el tipo y nombre están según el contrato
SELECT pc.codigo AS producto, avg(c.monto_originado)::numeric(18,2) AS ticket_promedio
FROM core.credito c JOIN core.producto_credito pc ON pc.id = c.producto_id
GROUP BY pc.codigo;
```

## Hay 9 módulos

La dificultad crece módulo a módulo, **cada uno asume el anterior**. La ruta completa toma entre 15 y 25 horas según el punto de partida. El detalle de cada módulo, con los temas y los errores comúnes, está en [`docs/plan-estudio.md`](docs/plan-estudio.md).

| Módulo | Tema | Ejercicios | Dificultad |
|---|---|---|---|
| 0 | Reconocimiento: orientarte en el esquema | E01-E04 | 1 |
| 1 | Joins: `INNER`, `LEFT`, anti-join, self-join, `FULL OUTER` | E05-E12 | 1-2 |
| 2 | Agregación: `GROUP BY`, `HAVING`, `FILTER`, el join que infla un `SUM` | E13-E20 | 2 |
| 3 | Lógica condicional y fechas: `CASE`, nulos, `generate_series`, zona horaria | E21-E27 | 2-3 |
| 4 | Subconsultas y CTEs: `EXISTS`, `NOT IN` con nulos, `WITH`, `MATERIALIZED` | E28-E35 | 3 |
| 5 | Window functions: ranking, `LAG`/`LEAD`, acumulados, `NTILE`, `DISTINCT ON`, cosechas | E36-E45 | 3-4 |
| 6 | Avanzado: CTE recursivo, `LATERAL`, `ROLLUP`, JSON, `UPDATE ... FROM` | E46-E52 | 4 |
| 7 | Correlación negocio ↔ sistema: latencia, tasa de error, despliegues e incidentes | E53-E57 | 4 |
| 8 | Rendimiento: `EXPLAIN (ANALYZE, BUFFERS)`, índices y reescrituras | E58-E60 | 5 |

Solo dos ejercicios se revisan a mano (no por hash): E04 (explicar una tabla con tus palabras) y E60 (comparar planes de ejecución). Los otros 58 se califican por hash.

## El dominio de datos

Hay tres esquemas. El diccionario completo, con los dos diagramas entidad-relación y las decisiones de diseño, está en [`docs/modelo-datos.md`](docs/modelo-datos.md). Los conceptos de negocio están explicados en [`docs/glosario-financiero.md`](docs/glosario-financiero.md).

**`core` (23 tablas): el negocio.**

- Crédito: `producto_credito`, `credito`, `amortizacion` (el plan de pagos por sistema francés), `pago`, `aplicacion_pago` (cómo se reparte cada pago entre cuotas), `credito_estado_hist`.
- Personas y red: `cliente`, `cliente_direccion`, `sucursal`, `empleado` (con jerarquía).
- Captación: `cuenta_captacion`, `movimiento_captacion`, `esquema_rendimiento`, `pago_rendimiento`.
- Tarjetas y pagos: `tarjeta`, `autorizacion_tarjeta`, `transferencia`, más los catálogos `cat_mcc` y `cat_institucion_spei`.
- Contabilidad: `cuenta_contable` (jerárquica), `asiento`, `movimiento_contable`, y la serie diaria de `tasa_referencia` (TIIE).

**`ops` (5 tablas): la telemetría.** `servicio`, `despliegue`, `peticion` (con un `credito_id` opcional que la une al negocio), `incidente` y `metrica_muestra`.

**`lab`: la infraestructura del laboratorio.** `ejercicio`, `intento` y las funciones `lab.verificar`, `lab.pista`, `lab.enunciado`, `lab.progreso`, `lab.siguiente` y `lab.reloj`.

Dentro de `psql`, `\d+ core.credito` (o cualquier tabla) muestra la tabla con el comentario de cada columna sin salir de la terminal.

## Comandos (`just`)

`just` sin argumentos lista todas las recetas.

| Receta | Qué hace |
|---|---|
| `just up` | Levanta el contenedor y espera a que la base esté lista |
| `just down` | Detiene el contenedor conservando los datos |
| `just nuke` | Detiene y **borra** el volumen de datos (pide confirmación) |
| `just seed` | Ejecuta todo `sql/` en orden. Avisa si ya hay datos |
| `just reset` | `nuke` + `up` + `seed` en un comando |
| `just psql` | Sesión interactiva de `psql` |
| `just siguiente` | Muestra el siguiente ejercicio sin resolver |
| `just enunciado E12` | Muestra el enunciado completo de un ejercicio |
| `just pista E12` | Muestra la pista del ejercicio |
| `just glosario mora` | Consulta el glosario financiero (sin término: el índice) |
| `just check E12` | Verifica tu respuesta en `respuestas/E12.sql` |
| `just progreso` | Tu avance por módulo |
| `just tamano` | Tamaño por tabla e índice y total |
| `just explain ruta.sql` | `EXPLAIN (ANALYZE, BUFFERS)` de un archivo |
| `just slow` | Top 15 de consultas por tiempo total |
| `just logs` | Sigue los logs del contenedor |

## Atajos dentro de `psql`

`just psql` carga un `.psqlrc` con:

- `:pr` muestra tu progreso.
- `:sig` muestra el siguiente ejercicio sin resolver.
- `:lento` muestra las consultas más lentas registradas.

Y obvio, los de base: `\d` lista objetos, `\dt` tablas, `\d+ core.credito` una tabla con sus comentarios, `\?` la ayuda de meta-comandos.

## Escala

El tamaño lo controla `SCALE` en `.env` (por defecto 1). Con `SCALE=1` el conjunto completo con índices ocupa ~1.1 GB y se genera en ~1 minuto. `SCALE=2` y `SCALE=3` multiplican las tablas grandes. El seed **aborta** si `SCALE` supera `SCALE_MAX` (por defecto 3), como red de seguridad para no llenar el disco.

Personalmente me parece interesante hacer una escala más grande, ya que ahí sí se nota la diferencia en rendimiento, pero lo dejo a discreción de cada quién.

## Determinismo y reproducibilidad

El mismo seed produce siempre exactamente los mismos datos. Eso permite que la corrección por hash funcione en cualquier máquina. Hay 3 componentes que hacen esto posible:

- **Reloj fijo:** todo cálculo de "hoy" (antigüedad, días de mora, edad) usa `lab.reloj()` = `2026-01-01`, jamás `now()`.
- **Seed fijo:** cada archivo que usa `random()` llama a `setseed(0.42)` al inicio.
- **Sin paralelismo** durante la generación, porque `random()` en workers paralelos no es reproducible.

Como verificación, el md5 de todos los hashes de ejercicios es estable entre reconstrucciones:

```bash
docker exec -i sofipo-db psql -U sofipo -d sofipo -tA -c \
 "SELECT count(*), md5(string_agg(codigo||'='||hash_esperado,',' ORDER BY codigo)) \
  FROM lab.ejercicio WHERE hash_esperado IS NOT NULL;"
# esperado: 58 | ebdf9a96e93e17893e2df3bcabb9eb58
```

## Mapa del repositorio

```
sofipo-lab/
├── README.md                 # este archivo
├── justfile                  # todas las recetas (just <receta>)
├── compose.yaml              # el servicio PostgreSQL
├── config/postgresql.conf    # tuning + pg_stat_statements + auto_explain
├── docs/                     # glosario, modelo de datos, plan de estudio, recetario, rendimiento
├── scripts/                  # utilidades que usan las recetas
├── respuestas/               # AQUÍ se escriben las consultas (E01.sql, E02.sql, ...)
└── sql/                      # el seed, en orden numérico
```

Los archivos de `sql/` corren en este orden (lo fija el `justfile`):

- `00_extensiones`, `01_esquemas`: extensiones y los esquemas core/ops/lab.
- `10_core_tablas` + `11_core_comentarios`: tablas del negocio y sus comentarios.
- `20_ops_tablas` + `21_ops_comentarios`: telemetría y sus comentarios.
- `30_lab_infra`: reloj fijo, catálogo de ejercicios y motor de verificación.
- `40_semilla_catalogos`: datos fijos (productos, sucursales, empleados, TIIE, catálogos).
- `41_semilla_masiva`: la generación grande (clientes, créditos, pagos, contabilidad, ops).
- `42_anomalias`: anomalías didácticas deliberadas para descubrir en los ejercicios.
- `50_indices`: llaves foráneas e índices (después de la carga). Dos índices se omiten a propósito para el módulo 8.
- `51_vistas`: vistas de apoyo y una materializada.
- `60_ejercicios`: los 60 enunciados y las soluciones de referencia.
- `99_analyze`: revierte tablas a LOGGED, `ANALYZE` y reporte de tamaños.

## Documentación

En `docs/`:

- [`glosario-financiero.md`](docs/glosario-financiero.md): cada término de negocio, qué es, cómo se calcula aquí y por qué. Si no tienes experiencia trabajando en el sector financiero deberías empezar por aquí.
- [`modelo-datos.md`](docs/modelo-datos.md): los dos diagramas entidad-relación y las decisiones de diseño del esquema.
- [`plan-estudio.md`](docs/plan-estudio.md): guía módulo por módulo y una tabla de errores comúnes.
- [`recetario-sql.md`](docs/recetario-sql.md): patrones reutilizables (top-N por grupo, rellenar huecos de fechas, media móvil...) con un ejemplo mínimo cada uno.
- [`notas-rendimiento.md`](docs/notas-rendimiento.md): cómo leer un plan de ejecución, para el módulo 8.

## Soluciones de referencia

Las soluciones viven en [`sql/60_ejercicios.sql`](sql/60_ejercicios.sql), junto a cada enunciado. En la base de datos solo se guarda el hash, nunca el texto de la solución, así que no te la vas a encontrar por accidente al explorar `lab.ejercicio`. Al final tú decides si abrir el archivo o no, trata de resolverlo antes de ver la respuesta.

## Problemas comunes

- **El puerto 5433 está ocupado.** Cambia `HOST_PORT` en `.env` y `just down && just up`.
- **`just seed` dice que ya hay datos.** El seed no es acumulable; usa `just reset` para reconstruir desde cero.
- **Un seed se interrumpió a medias.** `just reset` limpia y vuelve a empezar de forma determinista.
- **Quieres empezar de cero.** `just nuke` (confirma con `si`) borra el volumen; luego `just up && just seed`.
- **Quieres inspeccionar los datos en disco.** Pon `PGDATA_MODE=bind` en `.env` antes del primer `up`: los datos quedan en `./data/pgdata`. Cambiar de modo exige `just nuke` primero.

## Notas de diseño

Algunas decisiones que explican cómo está armado el laboratorio (`docs/modelo-datos.md`):

- **Dinero en `NUMERIC(18,2)`, nunca `float`**; instantes en `TIMESTAMPTZ`, llaves primarias con `GENERATED ALWAYS AS IDENTITY`.
- **Las llaves foráneas y los índices se crean después de la carga** (`50_indices.sql`), no en el DDL: validar FKs y mantener índices durante una carga masiva es mucho más caro.
- **Dos índices se omiten a propósito** para el módulo 8, de modo que puedas encontrar el `Seq Scan` costoso y proponer el índice.
- **Datos sucios a propósito** (nombres duplicados, pagos huérfanos, un asiento descuadrado, pagos en la frontera de zona horaria) sembradas para que varios ejercicios las descubran.

## Licencia

MIT. Ver [`LICENSE`](LICENSE).
