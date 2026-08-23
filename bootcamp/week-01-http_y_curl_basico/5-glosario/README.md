# 📖 Glosario — Semana 01

Términos de esta semana, A-Z. El nombre real en inglés va entre paréntesis
cuando es el que se usa en la práctica. Los flags llevan la versión mínima de
curl **solo si no son universales**; los que no la llevan existen desde
siempre.

---

## A

**Antipatrón** — Solución que funciona a corto plazo y crea un problema mayor.
En este bootcamp, el arquetipo es `-k`: hace que el comando funcione hoy y te
deja sin verificación de certificado para siempre.

## C

**Cliente (client)** — Quien inicia la comunicación HTTP. Aquí, curl.

**Código de estado (status code)** — Número de tres dígitos con el que el
servidor resume el resultado. El primer dígito da la familia: 1xx informativo,
2xx éxito, 3xx redirección, 4xx error del cliente, 5xx error del servidor.

**Código de salida (exit code)** — El número con el que termina un proceso.
El de curl dice si **pudo hablar** con el servidor, no si el servidor dijo que
sí. Los de esta semana: 0, 1, 3, 6, 7, 22, 28.

**`Content-Length`** — Header de respuesta con el tamaño del cuerpo en bytes.
No siempre está: con `Transfer-Encoding: chunked` no existe.

**`Content-Type`** — Header que dice qué es el cuerpo (`application/json`,
`text/html`). Sin él, el otro extremo tiene que adivinar.

**Cuerpo (body)** — Los datos de un mensaje HTTP, separados de los headers por
una línea vacía.

**curl** — Herramienta de línea de comandos para transferir datos con URLs.
Habla más de veinte protocolos; aquí se usa para HTTP y HTTPS.

## F

**Feature** — Capacidad compilada dentro de tu binario (`HTTP2`, `brotli`,
`IDN`). Se listan en `Features:` de `curl --version`. No confundir con los
protocolos.

**Fragmento (fragment)** — Lo que va detrás de `#` en una URL. **No viaja al
servidor**: lo usa solo el cliente.

## H

**Header** — Par `Nombre: valor` con metadatos de la petición o de la respuesta.
El nombre no distingue mayúsculas; el valor sí.

**Host** — Header obligatorio en HTTP/1.1 con el dominio al que va la petición.
Es lo que permite servir muchos dominios desde una sola IP.

**HTTP** — HyperText Transfer Protocol. Protocolo de petición y respuesta, **sin
estado**: cada petición es independiente de la anterior.

**HTTPS** — HTTP sobre TLS. Puerto 443 por defecto. Se trata en la Semana 05.

## L

**`Location`** — Header de respuesta que acompaña a un 3xx e indica a dónde ir.
curl no lo sigue salvo que se lo pidas con `-L`.

**libcurl** — La biblioteca que hace el trabajo. El comando `curl` es una capa
fina por encima. Por eso los códigos de error son "de libcurl".

## M

**Método (method)** — El verbo de la petición: `GET`, `POST`, `HEAD`… curl usa
`GET` mientras no le digas otra cosa.

## P

**Path** — La ruta al recurso dentro del servidor. Empieza por `/`.

**Petición (request)** — El mensaje que el cliente envía: línea de petición,
headers y, opcionalmente, cuerpo.

**Protocolo (protocol)** — Esquema de URL que tu curl entiende (`http`, `ftp`,
`smtp`). Se listan en `Protocols:` de `curl --version`.

**Puerto (port)** — El número detrás de los dos puntos en la URL. Si no está, se
usa el del esquema: 80 para `http`, 443 para `https`.

## Q

**Query string** — Lo que va detrás del `?` en una URL, en pares
`clave=valor` separados por `&`. Viaja al servidor y queda en sus logs: nunca
pongas ahí una credencial.

## R

**Redirección (redirect)** — Respuesta 3xx que dice que el recurso está en otra
URL. Se sigue con `-L`.

**Respuesta (response)** — El mensaje que devuelve el servidor: status line,
headers y, opcionalmente, cuerpo.

## S

**Servidor (server)** — Quien recibe la petición y responde.

**Sin estado (stateless)** — Propiedad de HTTP: el servidor no recuerda nada de
tu petición anterior. Todo lo que parece memoria —sesiones, cookies— se
reconstruye en cada petición.

## T

**Traza (trace)** — La salida de `-v` o de `--trace-ascii`. Va por **stderr**,
no por stdout: por eso hace falta `2>&1` para pasarla por un pipe.

## U

**URL** — Uniform Resource Locator. Sus partes:
`esquema://usuario@host:puerto/path?query#fragmento`.

## Flags de esta semana

| Flag | Nombre largo | Desde | Qué hace |
|---|---|:--:|---|
| `-v` | `--verbose` | universal | Traza de la petición, por stderr |
| `-i` | `--include` | universal | Incluye los headers de respuesta en la salida |
| `-I` | `--head` | universal | Hace un HEAD: solo headers, sin cuerpo |
| `-D` | `--dump-header` | universal | Vuelca los headers de respuesta a un archivo (`-` = stdout) |
| `-o` | `--output` | universal | Guarda el cuerpo en el archivo que digas |
| `-O` | `--remote-name` | universal | Guarda con el nombre que venga en la URL |
| `-s` | `--silent` | universal | Sin barra de progreso… y sin mensajes de error |
| `-S` | `--show-error` | universal | Devuelve los mensajes de error que `-s` calló |
| `-L` | `--location` | universal | Sigue las redirecciones |
| `-w` | `--write-out` | universal | Imprime variables de la transferencia al terminar |
| `-G` | `--get` | universal | Manda los `--data-*` en la query string en vez de en el cuerpo |
| `-A` | `--user-agent` | universal | Atajo de `-H 'User-Agent: …'` |
| `-H` | `--header` | universal | Añade, sustituye o suprime un header |
| `-f` | `--fail` | universal | Sale con 22 ante 4xx/5xx, descartando el cuerpo |
| — | `--fail-with-body` | **7.76** | Como `--fail`, pero conserva el cuerpo del error |
| `-m` | `--max-time` | universal | Límite de tiempo para la transferencia entera |
| — | `--connect-timeout` | 7.7 | Límite solo para establecer la conexión |
| — | `--retry` | 7.12.3 | Reintenta ante errores transitorios |
| — | `--compressed` | 7.10 | Pide la respuesta comprimida y la descomprime |
| — | `--data-urlencode` | 7.18.0 | Codifica un valor para meterlo en una URL |
| — | `--trace-ascii` | 7.9.7 | Traza completa, byte a byte, en texto |
| — | `--help all` | 7.73 | Lista **todas** las opciones, no el resumen |
| `-k` | `--insecure` | 7.10 | **Antipatrón.** Desactiva la verificación del certificado |

Versiones completas en
[`docs/versiones-de-curl.md`](../../../docs/versiones-de-curl.md).

## Variables de `--write-out` de esta semana

| Variable | Qué devuelve |
|---|---|
| `%{http_code}` | El código de estado. `%{response_code}` es sinónimo exacto |
| `%{time_total}` | Segundos que tardó la transferencia entera |
| `%{time_connect}` | Segundos hasta establecer la conexión TCP |
| `%{time_starttransfer}` | Segundos hasta el primer byte de la respuesta |
| `%{size_download}` | Bytes del cuerpo recibido |
| `%{num_redirects}` | Cuántas redirecciones se siguieron |
| `%{num_headers}` | Cuántos headers devolvió el servidor |
| `%{url_effective}` | La URL final, después de seguir las redirecciones |
| `%{content_type}` | El `Content-Type` de la respuesta |
| `%{json}` | Todas las variables a la vez, en JSON (7.70+) |

> `%{total_time}` y `%{status_code}` **no existen**. Son los dos errores de
> tecleo más frecuentes.

---

Todos estos términos se acumulan en el
[glosario global](../../../docs/glosario-global.md).

[← Volver a la Semana 01](../README.md)
