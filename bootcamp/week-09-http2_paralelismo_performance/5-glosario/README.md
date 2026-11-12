# Glosario — Semana 09

Términos de rendimiento, HTTP/2, paralelismo, caché y concurrencia que
aparecen esta semana. El término real en inglés va entre paréntesis, y los
flags que no son universales llevan **su versión mínima**. Los términos de
todo el bootcamp están en
[`docs/glosario-global.md`](../../../docs/glosario-global.md).

---

## 0-9

**101 Switching Protocols** · Respuesta con la que el servidor acepta el
`Upgrade`. curl 7.81 la recibe, pero no sabe seguir hablando WebSocket.

**304 Not Modified** · Respuesta a una petición condicional cuando la versión
no cambió. Sin cuerpo: el cliente sirve el que tenía.

## A

**ALPN** (*Application-Layer Protocol Negotiation*) · Extensión de TLS con la
que cliente y servidor eligen la versión de HTTP dentro del handshake, sin
ningún viaje extra. curl ofrece `h2` y `http/1.1`.

**`alt-svc`** · Cabecera con la que un servidor anuncia que también sirve otro
protocolo o puerto: `h3=":8443"; ma=2592000`. `--alt-svc` (7.64.1+) la guarda
en un archivo.

## B

**`bench`** · Subcomando de la capa 9: N GET con un solo curl en paralelo, y
un resumen con min, media, p95, max, reutilización y errores.

## C

**Caché condicional** · Guardar una respuesta con su ETag y, la siguiente vez,
preguntar si sigue valiendo. Ahorra el cuerpo, no el viaje.

**`Cache-Control: max-age`** · Cuántos segundos vale una respuesta sin volver a
preguntar. El toolkit no lo usa: solo revalida.

**Cerrojo** (*lock*) · Mecanismo para que solo un proceso a la vez entre en
una sección. En bash, `flock`.

**Condición de carrera** (*race condition*) · Fallo que depende de en qué
orden se ejecutan dos procesos. Ocho procesos que ven a la vez el token
caducado y lo renuevan ocho veces.

**Conexión persistente** (*persistent connection*, *keep-alive*) · Conexión
HTTP que sigue abierta después de la respuesta, para la siguiente petición. Por
defecto en HTTP/1.1.

## E

**ETag** (*entity tag*) · Etiqueta que el servidor pone a cada versión de un
recurso. Con `W/` delante es **débil**: semánticamente igual, aunque los bytes
cambien.

**`--etag-compare`** (7.68.0+) · Lee un ETag de un archivo y lo manda como
`If-None-Match`. Si el archivo está vacío, manda `""`.

**`--etag-save`** (7.68.0+) · Guarda el ETag de la respuesta en un archivo. No
guarda el cuerpo con él.

## F

**`flock`** · Orden de util-linux que coge un cerrojo del kernel sobre un
archivo. `-w N` espera como mucho N segundos; `-n` no espera. No viene en
macOS.

**Frame** · Unidad binaria de HTTP/2: `HEADERS`, `DATA`, `SETTINGS`,
`GOAWAY`… Cada uno lleva el número de su stream.

## H

**h2c** · HTTP/2 sin TLS. Casi ningún servidor público lo sirve; el go-httpbin
del laboratorio tampoco.

**Head-of-line blocking** · Lo que espera detrás de algo lento. En HTTP/1.1,
una petición detrás de otra; en HTTP/2, todos los streams detrás de un paquete
TCP perdido.

**HPACK** · Compresión de cabeceras de HTTP/2: una cabecera repetida viaja
entera una vez y después como un índice.

**HTTP/2** · Versión binaria y multiplexada de HTTP (RFC 9113). curl la ofrece
por defecto en `https://` desde la 7.62.0.

**HTTP/3** · HTTP sobre QUIC, sobre UDP (RFC 9114). `--http3` (7.66.0+) solo
funciona si curl se compiló con soporte: `HTTP3` en `Features:`.

**`--http1.1`** (7.33.0+) · Fuerza HTTP/1.1. Para comparar con HTTP/2.

**`--http2`** (7.33.0+) · En `https://`, lo mismo que sin nada. En `http://`,
pide el cambio con `Upgrade: h2c`.

**`--http2-prior-knowledge`** (7.49.0+) · Habla HTTP/2 desde el primer byte,
sin negociar. Contra un servidor que no lo sabe, curl sale con 52.

**`%{http_version}`** (7.50.0+) · Variable de `-w`: la versión de HTTP que se
usó de verdad, `1.1`, `2` o `3`.

## I

**`If-Modified-Since`** · Petición condicional por fecha. curl la manda con
`-z` / `--time-cond`.

**`If-None-Match`** · Petición condicional por ETag: "dame el recurso solo si
ya no es esta versión".

## L

**Latencia** (*latency*, RTT) · Lo que tarda un paquete en ir y volver. En una
API manda más que el ancho de banda.

## M

**Media** (*mean*) · La suma entre N. Un solo valor extremo la arrastra.

**Mediana** (p50) · El valor del medio de la lista ordenada. No la mueve un
valor extremo.

**Multiplexación** · Varias peticiones intercaladas a la vez en una misma
conexión. Lo que hace HTTP/2.

## N

**`--next`, `-:`** (7.36.0+) · Separa operaciones con opciones distintas en
un mismo curl. La conexión se reutiliza igual.

**`--no-keepalive`** (7.18.0+) · Apaga las sondas de keepalive de **TCP**. No
cierra la conexión persistente de HTTP.

**`%{num_connects}`** (7.12.3+) · Variable de `-w`: conexiones nuevas que abrió
esa transferencia. 1 si abrió, 0 si reutilizó.

## P

**p95** · El valor que deja por debajo al 95 % de las muestras. Por rango
(*nearest-rank*), la posición ⌈N × 0,95⌉ de la lista ordenada. Con 10
muestras es el max.

**`-Z`, `--parallel`** (7.66.0+) · Lanza las transferencias a la vez.

**`--parallel-immediate`** (7.68.0+) · Abre conexiones nuevas sin esperar a
ver si puede multiplexar. Sí en `http://`; no en `https://`.

**`--parallel-max`** (7.66.0+) · Máximo de transferencias simultáneas con
`-Z`. Por defecto, 50.

**Prueba de carga** (*load test*) · Miles de peticiones para ver cuándo se
rompe un servidor. No es lo que hace `bench`, y nunca sin permiso.

## Q

**QUIC** · Transporte sobre UDP con TLS 1.3 dentro (RFC 9000). Entrega por
stream: un paquete perdido solo frena al suyo.

## R

**`--rate`** (7.84.0+) · Limita las transferencias por unidad de tiempo. No
existe en 7.81: allí el freno es `--parallel-max`.

**Revalidar** · Preguntar al servidor si lo que tienes sigue valiendo, con
`If-None-Match` o `If-Modified-Since`.

## S

**Stream** · Una petición y su respuesta dentro de una conexión HTTP/2, con su
número: 1, 3, 5… si los abre el cliente.

## T

**`-z`, `--time-cond`** · Manda `If-Modified-Since` con una fecha, o con la
fecha de modificación de un archivo.

## U

**`Upgrade`** · Cabecera con la que el cliente pide cambiar de protocolo en la
misma conexión: `h2c` o `websocket`.

**`%{urlnum}`** (7.75.0+) · Variable de `-w`: la posición (desde 0) de la URL
en la línea. Con `-Z` las líneas llegan en orden de terminación.

## W

**WebSocket** · Canal bidireccional que empieza como una petición HTTP/1.1 y
cambia de protocolo con un 101 (RFC 6455). curl habla `ws://` desde la 7.86.0
(experimental) y por defecto desde la 8.11.0.

---

| Anterior | Siguiente |
|---|---|
| [Recursos](../4-recursos/README.md) | [README de la Semana 09](../README.md) |

[← Glosario global del bootcamp](../../../docs/glosario-global.md)
