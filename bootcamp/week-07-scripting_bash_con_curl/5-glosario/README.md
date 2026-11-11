# Glosario — Semana 07

Términos de códigos de salida, scripts bash, jq, paginación, reintentos y rate
limit que aparecen esta semana. El término real en inglés va entre paréntesis,
y los flags que no son universales llevan **su versión mínima**. Los términos
de todo el bootcamp están en
[`docs/glosario-global.md`](../../../docs/glosario-global.md).

---

## B

**Backoff exponencial** (*exponential backoff*) · Esperar entre reintentos un
tiempo que se dobla cada vez (1, 2, 4, 8 s...), con un tope. Es lo que hace
`--retry`.

## C

**Código de salida** (*exit status*) · El número entre 0 y 255 con el que
termina un proceso. 0 es éxito. El shell lo guarda en `$?`.

**Cursor** · Estilo de paginación en el que la API devuelve un valor opaco
(`next_cursor`) que hay que pasar tal cual en la petición siguiente.

## E

**`EX_TEMPFAIL`** · El código 75 de `sysexits.h`: fallo temporal, repetir más
tarde puede funcionar. El toolkit lo usa para 429, 502, 503 y 504.

**`errexit`** · El nombre largo de `set -e`: abortar cuando un comando falla.
No actúa en la condición de un `if`, en un `&&` o `||` salvo el último comando,
ni tras un `!`.

## F

**`--fail`, `-f`** · Sale con 22 ante una respuesta 400 o mayor, y no escribe
el cuerpo. No es a prueba de fallos con 401 y 407.

**`--fail-early`** · Con varias URLs en la misma línea, para en la primera que
falle.

**`--fail-with-body`** (7.76+) · Como `--fail`, pero escribe el cuerpo del
error. En 7.81 no se combina con `--fail`: juntos salen con 2.

## I

**Idempotente** (*idempotent*) · Que repetirlo deja el servidor igual que
hacerlo una vez. `GET`, `PUT` y `DELETE` lo son; `POST`, no. Solo lo
idempotente se reintenta sin más.

**`inherit_errexit`** (bash 4.4+) · `shopt` que hace que `$(...)` herede el
`set -e` del script.

## J

**Jitter** · El azar que se suma a una espera para que muchos clientes que
fallaron a la vez no reintenten a la vez.

**`jq -e`** (*exit status*) · Hace que el código de salida de jq dependa del
último resultado: 1 si es `false` o `null`, 4 si no hubo ninguno. En jq 1.6, una
entrada vacía sale con 0.

**`jq -s`** (*slurp*) · Lee todas las entradas y las mete en un array. Con
`add`, junta varias listas en una.

## L

**`Link`** · Header de RFC 8288 con enlaces relacionados con la respuesta. En
paginación: `<URL>; rel="next"`, y también `prev`, `first` y `last`, en
cualquier orden.

## M

**`MAX_PAGINAS`** · El freno de `fetch-all`: cuántas páginas pide como mucho
antes de fallar. Evita el bucle infinito de un `next` que apunta a sí mismo.

## N

**`nounset`** · El nombre largo de `set -u`: abortar al usar una variable que
no existe. `${VAR:-}` da una cadena vacía en su lugar.

## P

**Paginación** (*pagination*) · Repartir un listado en varias respuestas. Por
número de página, por desplazamiento, por cursor o con `Link`.

**`pipefail`** · Opción de bash: una tubería sale con el último código distinto
de 0 de sus comandos, no con el del último comando.

**`PIPESTATUS`** · Array de bash con el código de cada comando de la última
tubería. En zsh, `pipestatus`.

## R

**Rate limit** · El cupo de peticiones que una API te permite en un intervalo.
Al superarlo responde 429 (GitHub, a veces 403).

**`rel="next"`** · La relación del `Link` que apunta a la página siguiente. Su
ausencia es el final del listado.

**`--retry N`** · Reintenta hasta N veces un error transitorio: timeout, 408,
429, 500, 502, 503, 504. Esperas de 1, 2, 4... segundos, o lo que diga
`Retry-After` (7.66+).

**`--retry-all-errors`** (7.71+) · Reintenta cualquier fallo. La documentación lo
desaconseja por defecto.

**`--retry-connrefused`** (7.52+) · Cuenta la conexión rechazada (7) como error
transitorio.

**`--retry-delay S`** · Espera fija de S segundos entre reintentos, sin backoff.

**`--retry-max-time S`** · No empieza un reintento si ya han pasado S segundos.
La espera en curso no se corta.

**`Retry-After`** · Header que dice cuándo volver tras un 429 o un 503, en
segundos o como fecha HTTP.

## S

**`sysexits.h`** · Convención de los BSD para códigos de salida con nombre, del
64 al 78. Está en `/usr/include/` de cualquier Linux.

## T

**Transitorio** (*transient*) · Error que puede no repetirse si se reintenta:
un timeout, un 503. Lo contrario de un 404, que dará lo mismo siempre.

**`trap ... EXIT`** · Ejecuta un comando al salir el script por cualquier
motivo, también por un `set -e`. Para borrar temporales.

## X

**`x-ratelimit-*`** · Headers de GitHub (y de otras APIs, con nombres
parecidos) con el cupo: `limit`, `remaining`, `used` y `reset` (epoch).

---

| Anterior | Siguiente |
|---|---|
| [Recursos](../4-recursos/README.md) | [README de la Semana 07](../README.md) |

[← Glosario global del bootcamp](../../../docs/glosario-global.md)
