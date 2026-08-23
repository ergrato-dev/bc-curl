# 🎩 Trucos de curl

Lo que no viene en el manpage, o viene enterrado en la línea 4.000.

Este archivo es **acumulativo**: cada semana añade su sección al terminar. Es la
unión de las secciones `## 🎩 Trucos y atajos` de los README de cada semana. Si
un truco difiere entre los dos sitios, **gana el README de la semana**; el skill
`sincronizar-trucos` mantiene los dos lados de acuerdo.

Vuelve aquí al cerrar cada semana: crece contigo.

---

## Antes de empezar

Tres cosas que sirven las diez semanas:

| Truco | Cómo |
|---|---|
| Ver **todas** las opciones, no el resumen | `curl --help all` — `curl --help` a secas solo enseña las más comunes |
| El manual completo sin salir de la terminal | `curl --manual \| less` |
| Saber qué sabe hacer tu binario | `curl --version` — `Protocols:` es lo que habla, `Features:` es lo que se compiló |

---

## Semana 01 — HTTP y curl básico

| Truco | Cómo |
|---|---|
| Ver **todas** las opciones, no el resumen | `curl --help all`. `curl --help` a secas enseña 17 líneas de 245 |
| El manual completo sin salir de la terminal | `curl --manual \| less`. Son ~5.000 líneas y responde casi todo |
| Buscar una opción por lo que hace, no por su nombre | `curl --help all \| grep -i timeout` |
| Saber si tu curl habla un protocolo | `curl --version` — `Protocols:` lo que habla, `Features:` lo que se compiló |
| Solo el código de estado, nada más | `curl -s -o /dev/null -w '%{http_code}\n' URL` |
| Toda la información de la transferencia en JSON | `curl -s -o /dev/null -w '%{json}' URL \| jq` (7.70+) |
| Ver la petición **sin** enviar el cuerpo de la respuesta | `curl -I URL` hace un HEAD; `curl -s -o /dev/null -D - URL` hace un GET real y enseña solo los headers |
| Repetir la última URL sin volver a escribirla | `!!` en bash, o `!curl` para el último comando que empezó por curl |
| Que un fallo de red no se confunda con un HTML vacío | `curl -sS URL`: `-s` calla la barra de progreso, `-S` deja pasar los errores |
| Quitar uno de los headers que curl pone solo | `-H 'Accept:'` — valor vacío con dos puntos lo **suprime**; con punto y coma (`-H 'Accept;'`) lo manda vacío |
| Filtrar la traza de `-v` con `grep` | `curl -sv URL 2>&1 \| grep -E '^[<>]'`. Sin `2>&1` no funciona: la traza va por stderr |
| Contar los headers de la respuesta sin leerlos | `curl -s -o /dev/null -w '%{num_headers}\n' URL` |
| Provocar cualquier código de estado | `http://localhost:8080/status/418`. Acepta hasta los raros |
| Ver la cadena de redirecciones entera | `curl -sL -o /dev/null -D - URL \| grep -iE '^(HTTP\|Location)'` |
| Las categorías de la ayuda, cuando no sabes ni cómo se llama | `curl --help category`, y luego `curl --help connection` |

## Semana 02 — Métodos HTTP, headers y JSON

| Truco | Cómo |
|---|---|
| Mandar un cuerpo desde **stdin** sin archivo intermedio | `... \| curl -d @- URL`. La `@-` significa "el cuerpo lo lees de la entrada estándar" |
| Construir el JSON sin pelearte con las comillas | `jq -n --arg n ada '{nombre:$n}' \| curl -H 'Content-Type: application/json' -d @- URL`. `jq` escapa por ti |
| JSON desde un archivo **sin corromperlo** | `--data-binary @cuerpo.json`. Con `-d @cuerpo.json` curl **quita los saltos de línea** |
| Los tres flags de JSON en uno | `--json '{"a":1}'` (7.82+) = `-d` + `-H 'Content-Type: application/json'` + `-H 'Accept: application/json'` |
| Query string con espacios y `&` bien codificados | `curl -G --data-urlencode 'q=hola mundo&x' URL`. El `-G` lo mueve del cuerpo a la query |
| Saber qué método salió de verdad | `curl -s -o /dev/null -w '%{method}\n' -T archivo URL` (7.72+). Delata el método que pusieron los flags |
| Ver qué headers llegaron al servidor, no cuáles creías mandar | `curl -s http://localhost:8080/headers \| jq .headers` |
| Meter los headers en un archivo y sacar el token de `ps` | `curl -H @cabeceras.txt URL` (7.55+). Un header por línea, y `chmod 600` |
| Mandar un header **vacío** frente a **suprimirlo** | `-H 'Accept;'` lo manda vacío; `-H 'Accept:'` lo quita del todo. Punto y coma frente a dos puntos |
| Preguntar qué métodos acepta un endpoint antes de escribir | `curl -s --request OPTIONS -D - -o /dev/null URL \| grep -iE '^(allow\|access-control-allow-methods)'`. Si el servidor no contesta ninguno de los dos, provoca un 405 y lee su `Allow:` |
| Ver la URL del recurso recién creado | `curl -s -o /dev/null -D - -d '...' URL \| grep -i '^location'` |
| Encadenar varias peticiones en una sola invocación | `curl URL1 --next -d 'a=1' URL2`. Reutiliza la conexión y los flags se reinician en cada `--next` |
| Todos los headers de respuesta como JSON | `curl -s -o /dev/null -w '%{header_json}' URL \| jq` (**7.83+**; en 7.81 usa `-D -`) |
| Comprobar el `Content-Type` que devolvió la API | `curl -s -o /dev/null -w '%{content_type}\n' URL` |

## Semana 03 — Autenticación básica

_Pendiente._

## Semana 04 — Archivos, formularios y multipart

_Pendiente._

## Semana 05 — SSL/TLS, cookies y redirects

_Pendiente._

## Semana 06 — Output, debug y configuración

_Pendiente._

## Semana 07 — Scripting bash con curl

_Pendiente._

## Semana 08 — OAuth2 y autenticación avanzada

_Pendiente._

## Semana 09 — HTTP/2, paralelismo y rendimiento

_Pendiente._

## Semana 10 — Proyecto final

_Pendiente._

---

[← Volver a la documentación](README.md)
