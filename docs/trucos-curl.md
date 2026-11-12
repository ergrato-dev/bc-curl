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

| Truco | Cómo |
|---|---|
| Que curl **pregunte** la password en vez de escribirla | `curl -u usuario URL`. Sin los `:pass`, curl la pide por terminal y no queda en `ps` ni en el historial |
| Ver el header `Authorization` que curl genera de verdad | `curl -u user:password -o /dev/null -v URL 2>&1 \| grep -i '^> authorization'` |
| Saber qué esquema pide un servidor antes de intentar nada | `curl -s -o /dev/null -D - URL \| grep -i '^www-authenticate'` |
| Meter la credencial en un archivo de opciones de curl | `printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" > f; chmod 600 f; curl --config f URL` |
| Mandar un Bearer sin construir el header a mano | `curl --oauth2-bearer "$TOKEN" URL` (**7.61+**). Sigue yendo en el argv: en un script, `--config` |
| Que curl elija el esquema que pida el servidor | `curl --anyauth -u user:password URL`. Cuesta una petición extra: la primera se manda sin credencial, solo para leer el reto |
| Evitar esa petición extra cuando ya sabes el esquema | `curl --basic -u user:password URL`. Manda la credencial de entrada, sin esperar el 401 |
| Decodificar el payload de un JWT sin instalar nada | `cut -d. -f2 <<<"$JWT" \| tr '_-' '/+' \| base64 -d 2>/dev/null \| jq` — y si se queja, es el relleno: `(4 - len % 4) % 4` signos `=` |
| Saber si un JWT ya caducó, en una línea | `[ "$(date +%s)" -lt "$exp" ] && echo vigente \|\| echo caducado` |
| Comprobar que un secreto **no** está en la línea de comandos | Lanza la petición contra `/delay/3` en segundo plano y mira: `ps -eo args \| grep '^curl '` |
| Que un archivo de credenciales nazca ya con permisos 600 | `(umask 077; printf '...' > cred.txt)`. `chmod` después deja una ventana en la que es legible |
| Diferenciar "no me conozco" de "no me dejas" en un script | Código de salida propio para el 401/403. `77` es `EX_NOPERM` en `sysexits.h`, y no colisiona con los de curl |
| Descartar el `.curlrc` como causa de un fallo raro | `curl -q ...`. Un `--digest` olvidado ahí convierte todos tus comandos Basic en Digest |
| Contar las peticiones que gasta de verdad un esquema | `curl -s FLAG -u u:p -o /dev/null -v URL 2>&1 \| grep -c '^> GET'`. `--basic` da 1, `--anyauth` da 2 |
| Distinguir un JWT de un token opaco sin decodificar nada | `[ "$(tr -cd '.' <<<"$TOKEN" \| wc -c)" -eq 2 ] && echo JWT \|\| echo opaco` |

## Semana 04 — Archivos, formularios y multipart

| Truco | Cómo |
|---|---|
| Saber con qué nombre guardó curl el archivo | `curl -sOJ -w '%{filename_effective}\n' URL`. Con `-J` el nombre lo decide el servidor, no la URL |
| Ver el tamaño de un recurso sin descargarlo | `curl -sI URL \| grep -i '^content-length'`. Si no aparece, el servidor no lo sabe de antemano y `--max-filesize` no podrá cortar a priori |
| Saber si un servidor acepta rangos antes de reanudar | `curl -sI URL \| grep -i '^accept-ranges'`. `bytes` = sí; ausente o `none` = `-C -` fallará con el 33 |
| Descargar solo el principio de un archivo para mirar qué es | `curl -s -r 0-15 URL \| xxd`. Los primeros bytes son la firma: `%PDF`, `PK` (zip), `\x89PNG` |
| Que el 404 no deje un archivo vacío en 7.81, sin `--remove-on-error` | `curl -fsS -o f URL \|\| rm -f f`. `--remove-on-error` es 7.83+ y hace exactamente eso |
| Bajar varias URLs guardando cada una con su nombre | `curl --remote-name-all URL1 URL2 URL3`. Equivale a poner un `-O` delante de cada una |
| Mandar un campo de formulario que empieza por `@` sin que curl lea un archivo | `curl --form-string 'twitter=@usuario' URL`. Con `-F` curl intentaría abrir el archivo `usuario` |
| Subir un archivo cuyo nombre lleva `;` o `,` | `curl -F 'doc=@"informe;v2.pdf"' URL`. Sin comillas, curl corta en el `;` e intenta abrir `informe`: el 26 en el mejor caso, el archivo equivocado en el peor |
| Ver el multipart exacto que curl va a enviar | `curl -s -F 'a=1' -F 'f=@archivo' http://localhost:8080/post \| jq -r .data`. El `data` de `/post` es el cuerpo crudo |
| Subir desde un pipe sin archivo intermedio | `tar cz dir \| curl -T - URL`. Sin tamaño conocido, curl usa `Transfer-Encoding: chunked` |
| Quitar la espera del `Expect: 100-continue` en subidas grandes | `curl -H 'Expect:' -T grande.bin URL`. El header vacío lo suprime; útil cuando el servidor no contesta el `100` y curl espera 1 s |
| Medir a qué velocidad subiste | `curl -s -T f -o /dev/null -w '%{size_upload} B a %{speed_upload} B/s\n' URL` |

## Semana 05 — SSL/TLS, cookies y redirects

| Truco | Cómo |
|---|---|
| Ver qué CAs usa tu curl por defecto | `curl -sv https://host/ -o /dev/null 2>&1 \| grep -E 'CAfile\|CApath'`. En Ubuntu, `--cacert` cambia el CAfile pero el CApath sigue |
| Confiar **solo** en tu CA, sea cual sea el curl | `curl --cacert ca.pem --capath /dev/null URL`. Sin el `--capath`, el curl de Ubuntu sigue aceptando las CAs públicas |
| Ver el certificado que presenta un servidor | `openssl s_client -connect host:443 -servername host </dev/null 2>/dev/null \| openssl x509 -noout -subject -issuer -enddate -ext subjectAltName` |
| Avisar antes de que caduque un certificado | `... \| openssl x509 -noout -checkend 1209600`. Sale con 1 si caduca en menos de 14 días |
| Probar un nodo concreto de un balanceador | `curl --resolve host:443:10.0.0.5 https://host/`. La URL no cambia: el SNI y la verificación siguen siendo los de `host` |
| Comprobar que un certificado y una clave casan | `openssl x509 -in c.crt -noout -pubkey \| openssl dgst -sha256` y `openssl pkey -in c.key -pubout \| openssl dgst -sha256`: las dos huellas iguales |
| La frase de una clave cifrada sin que salga en `ps` | `pass = "..."` en un archivo con permisos 600, y `--config archivo`. Nunca `--pass` ni `--cert c.pem:frase` |
| Encender el motor de cookies sin mandar ninguna | `curl -L -b '' URL`. Sin él, la cookie que fija un login con redirect se pierde en el salto |
| Leer el tarro sin perder las cookies `HttpOnly` | `awk -F'\t' 'NF == 7 { print $6 "=" $7 }' tarro.txt`. Un `grep -v '^#'` se lleva las líneas `#HttpOnly_` |
| Ver a dónde lleva un redirect sin seguirlo | `curl -s -o /dev/null -w '%{redirect_url}\n' URL` |
| `--proto-redir` en zsh | `--proto-redir '=https'`, con comillas. Sin ellas, zsh lo expande y falla con `zsh: https not found` |
| Distinguir los dos timeouts | El mensaje del 28: `Connection timeout after` es `--connect-timeout`; `Operation timed out after` es `--max-time` |

## Semana 06 — Output, debug y configuración

| Truco | Cómo |
|---|---|
| Ver de un vistazo todo lo que `-w` sabe | `curl -s -o /dev/null -w '%{json}' URL \| jq .` (7.70+). Cuarenta campos con su valor real, sin abrir el manual |
| El formato de `-w` en un archivo | `curl -w @formato.txt URL`. Ojo: curl **ignora** los saltos de línea reales del archivo; cada línea tiene que acabar en un `\n` escrito |
| Que `-w` escriba en stderr y no ensucie el cuerpo | `-w '%{stderr}%{http_code}\n'`. Lo que sigue a `%{stderr}` va a stderr; `%{stdout}` vuelve |
| Una línea solo cuando algo falla | `-w '%{onerror}error %{exitcode}: %{errormsg}\n'` (7.75+). Si la transferencia salió bien, no imprime nada |
| Leer un header sin el `\r` que rompe las comparaciones | `curl -s -D - -o /dev/null URL \| tr -d '\r' \| awk -F': ' 'tolower($1) == "etag" { print $2 }'`. Con 7.84+: `-w '%header{etag}'` |
| Saber qué paso de la traza es el lento | `curl -v --trace-time URL`. Cada línea lleva la hora con microsegundos |
| Ver el cuerpo que enviaste, byte a byte | `curl --trace-ascii - -o /dev/null -d @datos.json URL`. La traza va a stdout; el cuerpo de la respuesta, a `/dev/null` |
| Pasar de un comando curl a código C | `curl --libcurl prog.c URL`. Escribe el programa equivalente con cada opción que usó |
| Comprobar si un `.curlrc` te está cambiando el comando | Repite con `curl -q ...`. Si cambia el resultado, el `.curlrc` estaba interviniendo |
| Probar un `.curlrc` sin tocar el tuyo | `CURL_HOME=/tmp/prueba curl URL`. curl busca primero en `$CURL_HOME/.curlrc` |
| Una credencial en un `-K` sin escribirla en disco | `printf 'header = "Authorization: Bearer %s"\n' "$API_TOKEN" \| curl -K - URL` |
| `2>&1 >/dev/null` en zsh | No hace lo mismo que en bash: zsh duplica stdout a los dos sitios (`MULTIOS`) y el cuerpo vuelve a salir. Usa `2>traza.txt >/dev/null` o ejecútalo con `bash -c` |

## Semana 07 — Scripting bash con curl

| Truco | Cómo |
|---|---|
| Recoger el código de curl con `set -e` activo | `rc=0; curl ... \|\| rc=$?`. Con `curl ...; rc=$?`, el script aborta antes de llegar a la asignación |
| Saber qué comando de una tubería falló | `echo "${PIPESTATUS[@]}"` justo después de la tubería: un código por comando |
| El cuerpo del error sin perder el `exit` distinto de 0 | `--fail-with-body` (7.76+). En 7.81 no se combina con `--fail`: juntos salen con 2 |
| Un solo cuerpo aunque curl reintente | `-o archivo`, nunca capturar stdout. curl trunca el archivo antes de cada intento; stdout no lo puede truncar |
| El header de la respuesta final, no el del primer intento | `tr -d '\r' < cab.txt \| awk '/^HTTP\// { v = "" } tolower($1) == "retry-after:" { v = $2 } END { print v }'`. Cada línea `HTTP/` empieza un bloque |
| Que jq falle si falta un campo | `jq -e -r .campo`. Sin `-e`, un campo que no existe llega como la cadena `null` |
| Construir JSON con valores del shell | `jq -n --arg nombre "$nombre" '{nombre: $nombre}'`. Nunca pegando texto entre comillas |
| Juntar varias listas JSON en una | `jq -s 'add // []' paginas.jsonl`. El `// []` cubre el caso sin ninguna página |
| Sacar el `rel="next"` de un `Link` | `tr ',' '\n' \| awk '/rel="next"/ { if (match($0, /<[^>]*>/)) print substr($0, RSTART + 1, RLENGTH - 2) }'` |
| Azar en una espera con aritmética entera | `ms=$(( (1000 << intento) + RANDOM % 1000 )); sleep "$((ms / 1000)).$(printf '%03d' $((ms % 1000)))"` |
| `curl \| head` aborta un script con `pipefail` | curl sale con 23 al encontrarse la tubería cerrada. Guarda la respuesta en un archivo y aplica `head` al archivo |
| `-o /dev/null` con `--retry` en 7.81 | Si el cuerpo no está vacío, el reintento sale con `(23) Failed to truncate file`. Usa `-o` a un temporal |

## Semana 08 — OAuth2 y autenticación avanzada

| Truco | Cómo |
|---|---|
| Descubrir los endpoints de un servidor OAuth2 sin leer su documentación | `curl -s https://servidor/.well-known/openid-configuration \| jq '{token_endpoint, authorization_endpoint, revocation_endpoint, jwks_uri}'` |
| Un campo de formulario sin escaparlo a mano | `--data-urlencode 'scope=leer escribir'` codifica el espacio (`+` en 7.81) y cualquier `&` o `=` del valor. Con `-d`, un `&` dentro del valor parte el campo en dos |
| Mandar un valor secreto codificado sin ponerlo en la línea | `printf %s "$TOKEN" \| curl --data-urlencode token@- ...`. `nombre@-` lee el valor de stdin y lo codifica; `@-` a secas codificaría también el `=` |
| El secreto del cliente fuera de `ps` | Una línea `user = "id:secreto"` en un `--config` temporal con permisos 600. `-u id:secreto` lo deja en `/proc/PID/cmdline` |
| Leer un JWT sin herramientas | `cut -d. -f2 <<<"$JWT" \| tr '_-' '/+' \| base64 -d 2>/dev/null \| jq .` (añade `=` hasta que la longitud sea múltiplo de 4 si `base64` se queja) |
| Calcular un `code_challenge` S256 | `printf %s "$VERIFIER" \| openssl dgst -sha256 -binary \| base64 \| tr '+/' '-_' \| tr -d '='` |
| El código de una redirección sin seguirla | `curl -s -o /dev/null -w '%{redirect_url}' URL`. El `code` va en la query de esa URL |
| Saber si un token sigue vivo según el servidor | `POST /introspect` con `token=...`: `{"active": true, ...}`. Más fiable que leer el `exp`, y cuesta una petición |
| Convertir `expires_in` en algo que siga valiendo dentro de una hora | `jq --argjson ahora "$(date +%s)" '.expires_at = $ahora + .expires_in'`. Guarda el instante, no la duración |
| Comprobar la caducidad sin decodificar el token | `[ "$(date +%s)" -ge $(( expires_at - 30 )) ]`. El margen cubre el reloj desajustado y el viaje de la petición |

## Semana 09 — HTTP/2, paralelismo y rendimiento

_Pendiente._

## Semana 10 — Proyecto final

_Pendiente._

---

[← Volver a la documentación](README.md)
