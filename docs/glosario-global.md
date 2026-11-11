# Glosario global

Todos los términos del bootcamp, A-Z. Es la unión de los glosarios de cada
semana; el de la semana es la fuente de verdad y este el índice.

Formato de una entrada:

```
**Término** (english name) — definición en una o dos frases. `--flag` desde 7.NN.
```

- El **término** va en español cuando existe, con el nombre real en inglés entre
  paréntesis si es el que se usa en la práctica.
- Si es un flag posterior a **7.81**, se anota la versión mínima. La tabla
  completa está en [versiones-de-curl.md](versiones-de-curl.md).
- Una entrada por concepto. Si necesitas una "y", son dos entradas.

Este archivo es **acumulativo**: cada semana añade sus términos al cerrarse.

---

## A

**Antipatrón** — Solución que funciona hoy y crea un problema mayor mañana. El
arquetipo del bootcamp es `-k`. _(S01)_

**`Accept-Ranges`** — Header con el que el servidor anuncia que acepta rangos. Es un anuncio, no una garantía. _(S04)_

**ALPN** (Application-Layer Protocol Negotiation) — Extensión de TLS con la que cliente y servidor acuerdan HTTP/2 o HTTP/1.1 dentro del handshake. _(S05)_

## B
**Boundary** — Cadena aleatoria que separa las partes de un cuerpo multipart. La genera curl; no se escribe a mano. _(S04)_

**Backoff exponencial** (exponential backoff) — Esperar entre reintentos un tiempo que se dobla cada vez, con un tope. Lo hace `--retry`; un bucle propio le suma azar (jitter). _(S07)_

## C

**Cliente** (client) — Quien inicia la comunicación HTTP. En este bootcamp,
curl. _(S01)_

**Código de estado** (status code) — Número de tres dígitos con el que el
servidor resume el resultado. El primer dígito da la familia. _(S01)_

**Código de salida** (exit code) — El número con el que termina el proceso
`curl`. Dice si pudo hablar con el servidor, **no** si el servidor dijo que sí.
Cada fase tiene el suyo: 6 DNS, 7 conexión, 28 timeout, 60 certificado.
_(S01, S07)_

**`Content-Length`** — Header con el tamaño del cuerpo en bytes. No existe
cuando la respuesta va en trozos (`Transfer-Encoding: chunked`). _(S01)_

**`Content-Type`** — Header que declara qué es el cuerpo del mensaje. _(S01)_

**Cuerpo** (body) — Los datos del mensaje, separados de los headers por una
línea vacía. _(S01)_

**curl** — Herramienta de línea de comandos para transferir datos con URLs.
_(S01)_

**Chunked** (Transfer-Encoding: chunked) — Cuerpo enviado en trozos sin tamaño previo. Lo usa `-T -`. _(S04)_

**`Content-Disposition`** — Header que propone un nombre de archivo en una respuesta, o da el `name` de una parte multipart. _(S04)_

**`Content-Range`** — Header de un `206` que dice qué bytes lleva y de qué total. _(S04)_

**CA** (Certificate Authority) — Entidad que firma certificados. Un certificado vale si su cadena llega a una CA de confianza. _(S05)_

**Cadena de confianza** (chain of trust) — Servidor, intermedia y raíz. La raíz no viaja: el cliente tiene que tenerla. _(S05)_

**Cookie de sesión** (session cookie) — Cookie sin `Expires` ni `Max-Age`; en el tarro, caducidad `0`. `-j` la descarta al leer. _(S05)_

**CR LF** — `\r\n`, el final de línea de los headers HTTP/1.1. curl entrega el `\r`: `tr -d '\r'` antes de comparar un valor. _(S06)_

**`.curlrc`** — Configuración que curl lee antes de cada comando: `$CURL_HOME/.curlrc`, luego `$XDG_CONFIG_HOME` (7.73+), luego `~/.curlrc`. Un script la ignora con `-q`. _(S06)_

## D
**`--data-urlencode`** — Codifica el valor de un campo de formulario antes de enviarlo. _(S04)_

**`--disable`** (`-q`) — No leer ningún `.curlrc`. Solo funciona como **primer** argumento; en otra posición se ignora sin avisar. _(S06)_

## F

**Fase** (phase) — Tramo de una petición: dns, tcp, tls, servidor, transferencia. Se calcula restando dos instantes `time_*`; sin TLS, `time_appconnect` vale 0. _(S06)_

**Feature** — Capacidad compilada dentro del binario (`HTTP2`, `brotli`). Se
listan en `Features:` de `curl --version`. _(S01)_

**Fragmento** (fragment) — Lo que sigue al `#` en una URL. No viaja al
servidor. _(S01)_

**`--fail-with-body`** — Sale con 22 ante un 4xx/5xx, como `--fail`, pero conserva el cuerpo del error. Desde 7.76; en 7.81 no se combina con `--fail`. _(S07)_

## H

**Header** — Par `Nombre: valor` con metadatos. El nombre no distingue
mayúsculas; el valor sí. _(S01)_

**`Host`** — Header obligatorio en HTTP/1.1 con el dominio de destino. _(S01)_

**HTTP** — Protocolo de petición y respuesta, sin estado. _(S01)_

**HTTPS** — HTTP sobre TLS, puerto 443 por defecto. _(S01)_

## I

**Idempotente** (idempotent) — Que repetirlo da el mismo resultado: `GET`, `PUT`, `DELETE`. Decide qué se puede reintentar. _(S05)_

## J

**JSON Lines** — Un objeto JSON por línea. Se añade con `>>` y se lee con `jq -s`. El formato de las métricas del toolkit. _(S06)_

**Jitter** — Azar sumado a la espera de un reintento para que muchos clientes que fallaron a la vez no vuelvan a la vez. _(S07)_

## L

**libcurl** — La biblioteca que hace el trabajo; `curl` es la capa de línea de
comandos por encima. _(S01)_

**`Location`** — Header que acompaña a un 3xx e indica a dónde ir. Solo se sigue
con `-L`. _(S01)_

**`Link`** — Header de RFC 8288 con enlaces relacionados. En paginación, `<URL>; rel="next"` apunta a la página siguiente; su ausencia es el final. _(S07)_

## M

**Método** (method) — El verbo de la petición: `GET`, `POST`, `HEAD`… _(S01)_

**Multipart** (`multipart/form-data`) — Cuerpo dividido en partes con cabeceras propias y contenido sin codificar. Lo que manda `-F`. _(S04)_

**mTLS** (mutual TLS) — TLS en el que también el cliente presenta certificado, con `--cert` y `--key`. Sin él: código 56. _(S05)_

**Motor de cookies** (cookie engine) — Lo que guarda y devuelve cookies dentro de un comando. Apagado hasta usar `-b` o `-c`. _(S05)_

**Medidor de progreso** (progress meter) — Tabla que curl escribe en stderr solo cuando stdout no es una terminal. `--no-progress-meter` desde 7.67. _(S06)_

## O
**`--output-dir`** — Directorio de destino de `-O`. `--output-dir` desde 7.73. _(S04)_

## P

**Path** — La ruta al recurso dentro del servidor. _(S01)_

**Petición** (request) — Mensaje del cliente: línea de petición, headers y
cuerpo opcional. _(S01)_

**Protocolo** (protocol) — Esquema de URL que curl entiende. Se listan en
`Protocols:` de `curl --version`. _(S01)_

**Puerto** (port) — El número tras los dos puntos en la URL. Por defecto, el del
esquema. _(S01)_

**`.part`** — Archivo de una descarga en curso; se renombra al destino solo cuando está completo y verificado. _(S04)_

**Petición de rango** (range request) — Petición que pide solo una parte de un recurso con `Range`. _(S04)_

**Percentil** (percentile) — p50 (mediana) y p95: el valor por debajo del cual está el 50 % o el 95 % de las medidas. Describen la latencia mejor que la media. _(S06)_

**Paginación** (pagination) — Repartir un listado en varias respuestas: por página, por desplazamiento, por cursor o con `Link`. Se para cuando la API lo dice, nunca "hasta que falle". _(S07)_

**`pipefail`** — Opción de bash: una tubería sale con el último código distinto de 0, no con el del último comando. Sin ella, `curl | jq` esconde el fallo de curl. _(S07)_

## Q

**Query string** — Lo que sigue al `?` en la URL, en pares `clave=valor`. Queda
en los logs del servidor: nunca una credencial. _(S01)_

## R

**Redirección** (redirect) — Respuesta 3xx que apunta a otra URL. _(S01)_

**Respuesta** (response) — Mensaje del servidor: status line, headers y cuerpo
opcional. _(S01)_

**`--remove-on-error`** — Borra el archivo de salida si la transferencia falla. `--remove-on-error` desde 7.83. _(S04)_

**Rate limit** — Cupo de peticiones por intervalo. Superarlo da 429 (GitHub, a veces 403), y la API suele decir cuánto queda en `x-ratelimit-*`. _(S07)_

**`Retry-After`** — Header de un 429 o un 503 con cuándo volver: segundos o fecha HTTP. `--retry` lo respeta desde 7.66. _(S07)_

## S

**Servidor** (server) — Quien recibe la petición y responde. _(S01)_

**Sin estado** (stateless) — El servidor no recuerda la petición anterior.
_(S01)_

**SHA-256** — Hash de 64 caracteres hexadecimales; un bit distinto lo cambia entero. Lo que cierra la verificación de una descarga. _(S04)_

**SNI** (Server Name Indication) — Nombre que el cliente manda en el handshake para que el servidor elija certificado. _(S05)_

**subjectAltName** (SAN) — Campo del certificado con los nombres para los que vale. El único que miran los clientes actuales. _(S05)_

**`sysexits.h`** — Códigos de salida con nombre, del 64 al 78. El toolkit usa 69 (`EX_UNAVAILABLE`), 75 (`EX_TEMPFAIL`) y 77 (`EX_NOPERM`). _(S07)_

## T

**Traza** (trace) — La salida de `-v` (por **stderr**) o de `--trace-ascii` (a un
archivo, o a stdout con `-`). Antes de compartirla se tacha. _(S01, S06)_

**Tachar** (redact) — Sustituir el valor de un header de credencial o sesión por
`<REDACTADO>` en una traza, dejando el nombre. _(S06)_

**TTFB** (time to first byte) — `time_starttransfer`. Incluye DNS, TCP y TLS; lo del servidor es la diferencia con `time_appconnect`. _(S06)_

**Tarro de cookies** (cookie jar) — Archivo de cookies en formato Netscape que escribe `-c` y lee `-b`. Permisos 600. _(S05)_

**Transitorio** (transient error) — Error que `--retry` reintenta: timeout, 408, 429, 500, 502, 503, 504. `--retry-connrefused` desde 7.52, `--retry-all-errors` desde 7.71. _(S05)_

## U

**URL** — `esquema://usuario@host:puerto/path?query#fragmento`. _(S01)_

**Urlencoded** (`application/x-www-form-urlencoded`) — Formato de formulario con `&`, `+` y `%XX`. Lo que manda `-d`. _(S04)_

**User-Agent** — Header con el que el cliente se identifica. Un script propio se presenta con el suyo, no con `curl/VERSION`. _(S06)_

## W

**`--write-out`** (`-w`) — Imprime variables de la transferencia al terminar:
`%{http_code}`, `%{time_total}`, `%{json}` (7.70+). `%{total_time}` y
`%{status_code}` no existen. Una variable inexistente sale vacía y con código 0. Con `@archivo`, los saltos de línea reales se ignoran. _(S01, S06)_

## X

**`XDG_CONFIG_HOME`** — Segundo sitio donde curl busca su configuración, desde 7.73. 7.81 lee ahí `.curlrc`; 8.17, `curlrc`. _(S06)_

---

[← Volver a la documentación](README.md)
