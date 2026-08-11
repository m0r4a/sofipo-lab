# Notas de rendimiento

Estas notas son para el módulo 8, y se ha trabajado sobre ellas para que no necesites ser un DBA para entenderlo.

La idea principal es: cuando le mandas una consulta a PostgreSQL, la base **no** la corre tal como la escribiste. Primero decide *cómo* va a buscar los datos: por dónde empezar, si conviene usar un índice o leer la tabla entera, en qué orden unir las tablas. A esa decisión se le llama **plan de ejecución**, y la toma un componente llamado **planner** (el que planea). `EXPLAIN` te muestra ese plan, y con él entiendes por qué una consulta va rápida o lenta.

La configuración ya viene lista: `track_io_timing` está activo (para ver tiempos reales de lectura de disco) y `auto_explain` guarda el plan de cualquier consulta que tarde más de 500 ms, sin que tengas que pedirlo a mano.

## Cómo pedir un plan

Pones `EXPLAIN` delante de tu consulta y, en vez de los resultados, te devuelve el plan:

```sql
EXPLAIN                       -- solo el plan estimado, no ejecuta
EXPLAIN (ANALYZE)             -- ejecuta y mide tiempos reales
EXPLAIN (ANALYZE, BUFFERS)    -- además, páginas leídas de caché vs disco
```

Desde la terminal, sobre un archivo: `just explain respuestas/E58.sql`.

Cuidado: `EXPLAIN ANALYZE` **ejecuta** la consulta de verdad. En un `SELECT` no pasa nada, pero en un `UPDATE` o `DELETE` sí modifica los datos. Si te preocupa, envuélvelo en una transacción y haz `ROLLBACK` al final para deshacerlo.

## Los números de cada nodo

Aquí conviene aclarar la palabra **nodo**, porque en otros contextos significa un servidor o una instancia de una aplicación (un nodo de un clúster, por ejemplo). En un plan de ejecución no es eso. Aquí un nodo es simplemente **un paso del plan**: una operación concreta, como "leer la tabla pago", "usar un índice" o "unir dos tablas".

El plan es el conjunto de esos pasos encajados unos dentro de otros, donde la salida de un nodo alimenta al de arriba. Cada nodo viene con unos números entre paréntesis:

```
Seq Scan on pago  (cost=0.00..9876.00 rows=502149 width=20)
                  (actual time=0.01..40.2 rows=502149 loops=1)
```

- **`cost`**: la estimación del planner, en una unidad inventada suya (no son segundos). El primer número es el costo de arranque (hasta la primera fila), el segundo es el costo total. Sirve para comparar un plan contra otro, no para leerlo como tiempo.
- **`rows`**: cuántas filas el planner **cree** que va a sacar de ese nodo.
- **`width`**: cuántos bytes ocupa en promedio cada fila.
- **`actual time`**: el tiempo real (arranque .. total) en milisegundos. Solo aparece con `ANALYZE`, porque hay que ejecutar la consulta para poder medirlo.
- **`rows` (en la línea `actual`)**: cuántas filas salieron de verdad.
- **`loops`**: cuántas veces se ejecutó ese nodo. Ojo: el `actual time` es **por cada vuelta**, así que multiplícalo por `loops` para el total.

## La señal más importante

Es el descuadre más grande entre las **filas que el planner estimó** y las **reales**.

¿Por qué importa tanto? Porque el planner elige el plan basándose en su estimación. Si cree que un nodo devuelve 10 filas y en realidad devuelve 500,000, va a elegir un plan equivocado: por ejemplo, un `Nested Loop` que tenía todo el sentido para 10 filas pero es horrible para medio millón. Casi siempre la causa es que sus estadísticas (el "censo" que PostgreSQL guarda de cada tabla) están viejas, y la solución es refrescarlas con `ANALYZE tabla`. El ejercicio E60 te ayuda a ver este efecto en vivo.

## Nodos que vas a encontrar

Un plan combina dos tipos de operación: **cómo lee cada tabla** (los "scan") y **cómo une dos tablas** (los "join"). Estas son las que más vas a ver.

Formas de leer una tabla:

- **`Seq Scan`** (lectura secuencial): lee la tabla entera de principio a fin. No es malo en sí: si necesitas la mayoría de las filas, recorrerlas todas de corrido es lo más rápido. Es malo cuando buscas pocas filas y existe (o debería existir) un índice. El ejercicio E58 te enseña a detectarlo: buscar pagos por `credito_id` hace un `Seq Scan` porque ese índice se omitió a propósito.
- **`Index Scan`**: usa un índice para ir directo a las filas que busca, como cuando buscas una palabra en el índice al final de un libro en lugar de hojear página por página. Bueno cuando traes pocas filas.
- **`Index Only Scan`**: ni siquiera abre la tabla, porque el índice ya trae todo lo que pediste. Lo mejor cuando se puede.
- **`Bitmap Heap Scan`** (con su `Bitmap Index Scan`): un punto intermedio. Primero junta en el índice todas las coincidencias y luego lee la tabla una sola vez, en orden físico. Bueno para "muchas filas, pero no todas".

Formas de unir dos tablas:

- **`Nested Loop`**: por cada fila de un lado, busca sus parejas en el otro. Excelente si el lado de afuera tiene pocas filas y el de adentro está indexado; terrible si el de afuera es grande, porque repite la búsqueda demasiadas veces.
- **`Hash Join`**: arma una tabla de búsqueda rápida (un "hash") con un lado y luego pasa el otro por ella. Es la opción normal para unir dos conjuntos grandes.
- **`Merge Join`**: une dos listas que ya vienen ordenadas, avanzando por las dos a la par. Bueno cuando ambos lados ya están ordenados (o hay índices que dan ese orden gratis).

## Qué mira `BUFFERS`

PostgreSQL no lee fila por fila, sino en bloques de 8 KB llamados **páginas**. Con la opción `BUFFERS`, cada nodo te dice de dónde salieron esas páginas:

- **`shared hit`**: la página ya estaba en la memoria de PostgreSQL (su caché). Rápido, no tocó el disco.
- **`shared read`**: hubo que ir a traerla del disco (o de la caché del sistema operativo). Más lento.

Si ves muchos `read` donde esperabas `hit`, suele significar que los datos no caben en la memoria que PostgreSQL reserva para ellos (`shared_buffers`), o que el plan está leyendo más de lo que necesita.

## Cuándo un `Seq Scan` es lo correcto

Leer la tabla entera no siempre es el problema. Si vas a usar, digamos, más del 10 a 20% de una tabla, el `Seq Scan` suele ganar: leerla de corrido es barato, y andar saltando de un lado a otro con un índice para traer tantas filas sale más caro. No "arregles" un `Seq Scan` que en realidad ya es la mejor opción. La pregunta correcta no es "¿usa índice?", sino "¿cuántas filas necesita y cuántas está tocando para conseguirlas?".

## Herramientas del laboratorio

- **`pg_stat_statements`** va sumando estadísticas de cada consulta a lo largo del tiempo. `just slow` te da el top 15 por tiempo total acumulado: ideal para encontrar la consulta que, sumando todas sus corridas, más cuesta (no siempre es la más lenta de una sola vez).
- **`auto_explain`** guarda solo el plan de las consultas lentas en el log, sin que tú lo pidas. Lo lees con `just logs`.

## Un flujo de trabajo para el módulo 8

1. Corre la consulta con `EXPLAIN (ANALYZE, BUFFERS)` y anota el tiempo y el nodo que más pesa.
2. Si ves un `Seq Scan` que recorre muchas filas para traer pocas, crea el índice candidato.
3. Vuelve a medir. Compara `cost`, tiempo real y `buffers` contra la versión anterior.
4. Si el plan no cambió como esperabas, corre `ANALYZE` y repite: quizá el planner estaba decidiendo con estadísticas viejas.
5. Quédate con la versión más rápida solo si el resultado es **idéntico** (mismo hash). Rápido pero equivocado no cuenta.
