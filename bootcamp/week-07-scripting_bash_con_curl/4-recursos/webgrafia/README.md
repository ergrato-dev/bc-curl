# Webgrafía — Semana 07

_Comprobado el 11 de noviembre de 2026._

## Referencia de curl

| Recurso | Por qué vale la pena |
|---|---|
| [manpage de curl](https://curl.se/docs/manpage.html) | La fuente. Antes de escribir un flag que «suena bien», búscalo aquí |
| [Exit codes](https://curl.se/docs/manpage.html#EXIT) | La tabla completa de códigos de salida. La teoría 01 solo cubre los de HTTP |
| [`-f, --fail`](https://curl.se/docs/manpage.html#-f) | Incluye la advertencia de que no es a prueba de fallos con 401 y 407 |
| [`--fail-with-body`](https://curl.se/docs/manpage.html#--fail-with-body) | 7.76+. La opción de todo ejemplo de producción del bootcamp |
| [`--retry`](https://curl.se/docs/manpage.html#--retry) | Qué es un error transitorio, el backoff y el `Retry-After` |
| [`-D, --dump-header`](https://curl.se/docs/manpage.html#-D) | Headers a un archivo, uno por respuesta |
| [libcurl — Error codes](https://curl.se/libcurl/c/libcurl-errors.html) | La descripción larga de cada código: el mismo número que devuelve la herramienta |
| [Using curl to automate HTTP jobs](https://curl.se/docs/httpscripting.html) | El tutorial oficial de scripting HTTP con curl |
| [Daniel Stenberg — `--fail-with-body`](https://daniel.haxx.se/blog/2021/02/11/curl-fail-with-body/) | El anuncio de la opción, con el porqué |

## Bash

| Recurso | Por qué vale la pena |
|---|---|
| [The Set Builtin](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html) | Lo que hacen exactamente `-e`, `-u` y `-o pipefail`, incluidos los contextos donde `-e` se ignora |
| [Pipelines](https://www.gnu.org/software/bash/manual/html_node/Pipelines.html) | `PIPESTATUS` y `pipefail` en el manual |
| [Exit Status](https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html) | Qué códigos reserva el shell: 126, 127 y 128+N |
| [BashFAQ/105 — Why doesn't set -e do what I expected?](https://mywiki.wooledge.org/BashFAQ/105) | La lista de sorpresas de `-e`, con ejemplos. Por qué no basta con ponerlo |
| [ShellCheck SC2155](https://www.shellcheck.net/wiki/SC2155) | `local x=$(...)` oculta el código de salida |
| [`sysexits.h` — FreeBSD](https://man.freebsd.org/cgi/man.cgi?query=sysexits) | Los códigos 64 a 78 con su significado. De ahí salen el 69, el 75 y el 77 del toolkit |
| [Exit Codes With Special Meanings](https://tldp.org/LDP/abs/html/exitcodes.html) | Qué números evitar al diseñar los códigos de tu script |

## jq

| Recurso | Por qué vale la pena |
|---|---|
| [jq Manual 1.6](https://jqlang.github.io/jq/manual/v1.6/) | La versión de Ubuntu 22.04. `-e`, `--arg`, `--argjson`, `-s` |
| [jq Manual 1.7](https://jqlang.github.io/jq/manual/v1.7/) | La versión actual. Compara con la 1.6 si un script se comporta distinto |
| [jq 1.7 — Release notes](https://github.com/jqlang/jq/releases/tag/jq-1.7) | La lista de cambios de comportamiento respecto a la 1.6 |

## Paginación y rate limit

| Recurso | Por qué vale la pena |
|---|---|
| [RFC 8288 — Web Linking](https://www.rfc-editor.org/rfc/rfc8288) | La definición del header `Link` y de `rel` |
| [GitHub — Using pagination](https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api) | Paginación con `Link` en una API real, con `per_page` y sus límites |
| [Slack — Pagination](https://api.slack.com/apis/pagination) | El estilo cursor, explicado por quien lo usa, y por qué lo prefieren al offset |
| [RFC 9110 — Retry-After](https://www.rfc-editor.org/rfc/rfc9110#field.retry-after) | Las dos formas del header: segundos o fecha |
| [RFC 6585 — 429 Too Many Requests](https://www.rfc-editor.org/rfc/rfc6585#section-4) | La definición del 429, en media página |
| [GitHub — Rate limits for the REST API](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api) | Los `x-ratelimit-*`, el cupo con y sin token, y qué hacer al agotarlo |
| [AWS — Exponential Backoff And Jitter](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/) | Simulaciones que enseñan por qué el backoff sin azar sigue saturando |
| [Stripe — Idempotent requests](https://docs.stripe.com/api/idempotent_requests) | Cómo se reintenta un `POST` sin crear el recurso dos veces |

---

| Anterior | Siguiente |
|---|---|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
