# Glosario — Semana 06

Términos de salida, `--write-out`, trazas, métricas y configuración que
aparecen esta semana. El término real en inglés va entre paréntesis, y los
flags y variables que no son universales llevan **su versión mínima**. Los
términos de todo el bootcamp están en
[`docs/glosario-global.md`](../../../docs/glosario-global.md).

---

## B

**Builtin** · Orden que ejecuta el propio shell sin crear un proceso.
`printf` y `echo` lo son en bash y zsh: por eso
`printf ... "$API_TOKEN" | curl -K -` no deja el token en `ps`.

## C

**CR LF** (*carriage return, line feed*) · `\r\n`, el final de línea de los
headers HTTP/1.1. curl los entrega con el `\r`: hay que quitarlo con
`tr -d '\r'` antes de comparar un valor.

**`CURL_HOME`** · Variable de entorno: si existe, curl busca el `.curlrc` en
`$CURL_HOME/.curlrc` antes que en ningún otro sitio. La forma limpia de probar
un `.curlrc` sin tocar el tuyo.

**`.curlrc`** · Archivo de configuración que curl lee antes de cada comando, si
lo encuentra. Mismo formato que un `-K`. Cómodo en la terminal; en un script,
se ignora con `-q`.

## D

**`-D`, `--dump-header`** · Escribe los headers de la respuesta en un archivo
(`-D -`: stdout) y deja el cuerpo donde estaba. Con `-L`, un bloque por
respuesta.

**`-q`, `--disable`** · No leer ningún `.curlrc`. **Solo funciona como primer
argumento**; en otra posición se ignora sin avisar.

## E

**`%{errormsg}`** (7.75+) · El mensaje de error de curl, vacío si no lo hubo.

**`%{exitcode}`** (7.75+) · El código de salida de curl, dentro de `-w`.

## F

**Fase** (*phase*) · Cada tramo de una petición: dns, tcp, tls, servidor y
transferencia. Se calcula restando dos instantes `time_*` consecutivos.

## H

**`%header{nombre}`** (7.84+) · El valor de un header de la última respuesta,
sin `\r` y sin distinguir mayúsculas. Sin llaves alrededor de `header`. En 7.81
no da error: imprime el texto literal.

**`%{header_json}`** (7.83+) · Todos los headers de la última respuesta como un
objeto JSON, cada valor en un array.

## I

**Instante** · Lo que mide cada variable `time_*`: segundos desde el principio
de la petición, acumulados. No es una duración.

## J

**JSON Lines** · Un objeto JSON por línea. Se añade con `>>`, se lee con `jq`,
y un archivo cortado a medias sigue siendo válido hasta la última línea
completa. El formato de `METRICS_FILE`.

**`%{json}`** (7.70+) · Todas las variables de `-w` como un objeto JSON. En él,
el código de un fallo es `0`, no `000`.

## K

**`-K`, `--config`** · Lee opciones de un archivo, que se aplican en la
posición del `-K`. `-K -` las lee de stdin.

## L

**`--libcurl ARCHIVO`** · Escribe el programa en C equivalente al comando, con
cada opción que curl aplicó, también las del `.curlrc`.

## M

**Mediana** (*p50*) · El valor que deja la mitad de las medidas por debajo.
Describe la petición típica; la media no, si hay valores extremos.

**Medidor de progreso** (*progress meter*) · La tabla que curl dibuja en stderr
cuando stdout **no** es una terminal. `-s` o `--no-progress-meter` la apagan.

**`MULTIOS`** · Opción de zsh, activa por defecto: varias redirecciones del
mismo descriptor duplican la salida. Por eso `2>&1 >/dev/null` en zsh no deja
solo stderr.

## N

**`--no-progress-meter`** (7.67+) · Apaga solo el medidor, no los errores. El
equivalente explícito de `-sS`.

## O

**`%{onerror}`** (7.75+) · Lo que le sigue en el formato de `-w` solo se imprime
si la transferencia falló.

## P

**p95** (*percentil 95*) · El valor por debajo del cual está el 95 % de las
medidas: lo que sufre uno de cada veinte usuarios.

## S

**`-S`, `--show-error`** · Con `-s`, devuelve los mensajes de error. `-sS` es la
combinación de los scripts.

**`--stderr ARCHIVO`** · Manda a ese archivo todo lo que curl escribiría en
stderr, desde dentro de curl.

**`%{stderr}` / `%{stdout}`** · Dentro de `-w`, cambian el flujo al que va lo
que viene detrás.

**stdout / stderr** · Las dos salidas de un proceso. En curl, stdout lleva el
cuerpo (y `-w`, y `-i`); stderr, el medidor, los errores y la traza `-v`.

## T

**Tachar** (*redact*) · Sustituir el valor de un header de credencial por
`<REDACTADO>` en una traza, dejando el nombre. Lo hace `redactar_traza`.

**`time_*`** · Las variables de tiempo de `-w`: `time_namelookup`,
`time_connect`, `time_appconnect` (0 sin TLS), `time_pretransfer`,
`time_starttransfer`, `time_total` y `time_redirect`. Todas instantes.

**`--trace ARCHIVO`** · Traza completa con volcado hexadecimal: cada byte
enviado y recibido, cuerpo incluido.

**`--trace-ascii ARCHIVO`** · Como `--trace`, en texto. Los bytes no imprimibles
salen como `.`.

**`--trace-config`** (8.3+) · Enciende la traza de componentes internos (`tls`,
`http/2`, `all`...).

**`--trace-ids`** (8.2+) · Antepone los números de transferencia y conexión a
cada línea de la traza.

**`--trace-time`** · Pone la hora, con microsegundos, delante de cada línea de
`-v` o de una traza.

**TTFB** (*time to first byte*) · Tiempo hasta el primer byte de la respuesta:
`time_starttransfer`. Incluye DNS, TCP y TLS; lo del servidor es la diferencia
con `time_appconnect`.

## U

**User-Agent** · Header con el que el cliente se identifica. curl manda
`curl/VERSION`; el toolkit, `api-toolkit/VERSION`, para que sus peticiones se
distingan en los logs del servidor.

## V

**`-v`, `--verbose`** · Traza de la conversación en stderr: `*` lo que hace
curl, `>` lo que envía, `<` lo que recibe, `{` `}` bloques de datos.

**`--variable`** (8.3+) · Define una variable de curl; `%NOMBRE` la lee del
entorno. Se usa con `--expand-url`, `--expand-header` y compañía. En 7.81:
`option --variable: is unknown`.

## W

**`-w`, `--write-out`** · Imprime una plantilla con datos de la transferencia al
terminar, también cuando falla. Solo vale el último. Con `@archivo`, los saltos
de línea reales del archivo se ignoran.

## X

**`XDG_CONFIG_HOME`** (7.73+) · Segundo sitio donde curl busca su configuración.
El nombre del archivo cambió: 7.81 lee `.curlrc`, 8.17 lee `curlrc`.

---

| Anterior | Siguiente |
|---|---|
| [Recursos](../4-recursos/README.md) | [README de la Semana 06](../README.md) |

[← Glosario global del bootcamp](../../../docs/glosario-global.md)
