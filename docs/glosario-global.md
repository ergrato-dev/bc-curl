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

## C

**Cliente** (client) — Quien inicia la comunicación HTTP. En este bootcamp,
curl. _(S01)_

**Código de estado** (status code) — Número de tres dígitos con el que el
servidor resume el resultado. El primer dígito da la familia. _(S01)_

**Código de salida** (exit code) — El número con el que termina el proceso
`curl`. Dice si pudo hablar con el servidor, **no** si el servidor dijo que sí.
_(S01)_

**`Content-Length`** — Header con el tamaño del cuerpo en bytes. No existe
cuando la respuesta va en trozos (`Transfer-Encoding: chunked`). _(S01)_

**`Content-Type`** — Header que declara qué es el cuerpo del mensaje. _(S01)_

**Cuerpo** (body) — Los datos del mensaje, separados de los headers por una
línea vacía. _(S01)_

**curl** — Herramienta de línea de comandos para transferir datos con URLs.
_(S01)_

## F

**Feature** — Capacidad compilada dentro del binario (`HTTP2`, `brotli`). Se
listan en `Features:` de `curl --version`. _(S01)_

**Fragmento** (fragment) — Lo que sigue al `#` en una URL. No viaja al
servidor. _(S01)_

## H

**Header** — Par `Nombre: valor` con metadatos. El nombre no distingue
mayúsculas; el valor sí. _(S01)_

**`Host`** — Header obligatorio en HTTP/1.1 con el dominio de destino. _(S01)_

**HTTP** — Protocolo de petición y respuesta, sin estado. _(S01)_

**HTTPS** — HTTP sobre TLS, puerto 443 por defecto. _(S01)_

## L

**libcurl** — La biblioteca que hace el trabajo; `curl` es la capa de línea de
comandos por encima. _(S01)_

**`Location`** — Header que acompaña a un 3xx e indica a dónde ir. Solo se sigue
con `-L`. _(S01)_

## M

**Método** (method) — El verbo de la petición: `GET`, `POST`, `HEAD`… _(S01)_

## P

**Path** — La ruta al recurso dentro del servidor. _(S01)_

**Petición** (request) — Mensaje del cliente: línea de petición, headers y
cuerpo opcional. _(S01)_

**Protocolo** (protocol) — Esquema de URL que curl entiende. Se listan en
`Protocols:` de `curl --version`. _(S01)_

**Puerto** (port) — El número tras los dos puntos en la URL. Por defecto, el del
esquema. _(S01)_

## Q

**Query string** — Lo que sigue al `?` en la URL, en pares `clave=valor`. Queda
en los logs del servidor: nunca una credencial. _(S01)_

## R

**Redirección** (redirect) — Respuesta 3xx que apunta a otra URL. _(S01)_

**Respuesta** (response) — Mensaje del servidor: status line, headers y cuerpo
opcional. _(S01)_

## S

**Servidor** (server) — Quien recibe la petición y responde. _(S01)_

**Sin estado** (stateless) — El servidor no recuerda la petición anterior.
_(S01)_

## T

**Traza** (trace) — La salida de `-v` o `--trace-ascii`. Va por **stderr**.
_(S01)_

## U

**URL** — `esquema://usuario@host:puerto/path?query#fragmento`. _(S01)_

## W

**`--write-out`** (`-w`) — Imprime variables de la transferencia al terminar:
`%{http_code}`, `%{time_total}`, `%{json}` (7.70+). `%{total_time}` y
`%{status_code}` no existen. _(S01)_

---

[← Volver a la documentación](README.md)
