# Rúbrica de evaluación — Semana 06

> Output, debug y configuración. Se evalúa que sepas hacer hablar a curl sin
> que hable de más: el cuerpo limpio en stdout, el diagnóstico en stderr, cada
> milisegundo en su fase, ninguna credencial en una traza y ningún `.curlrc`
> decidiendo por tu script.

---

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales |
| 💪 Desempeño | 40% | Las 4 prácticas, con sus entregables .md y salida real de tu máquina |
| 📦 Producto | 30% | `api-toolkit.sh`: 60 pts de autograding + 40 pts de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio. Un toolkit que tacha las
trazas no compensa no saber por qué una traza `--trace-ascii` no se tacha con el
mismo filtro.

---

## 🧠 Conocimiento (30%)

| # | Pregunta |
|:--:|---|
| 1 | Un comando que en la terminal no enseña el medidor de progreso llena de tablas el log del cron. ¿Por qué? ¿Qué diferencia hay entre arreglarlo con `-s`, con `-sS` y con `2>/dev/null`? |
| 2 | Un script extrae el `ETag` con `grep -i '^etag' \| cut -d' ' -f2` y la comparación con el valor guardado falla siempre, aunque al imprimirlo parezca igual. ¿Qué tiene la variable? ¿Qué más puede fallar si la petición lleva `-L`? |
| 3 | `curl -w '%{status_code}'` devuelve una cadena vacía y el script sale con 0. ¿Por qué no falla curl? ¿Qué ventaja tiene `%{json}` con `jq` frente a una lista de variables separadas por espacios? |
| 4 | `time_starttransfer` de una petición HTTPS vale 0,8 s. ¿Es lo que tarda el servidor? ¿Cómo lo calcularías, y por qué la misma fórmula da un negativo sobre HTTP? |
| 5 | Dos endpoints tardan 1 s de `time_total`. En uno, `time_starttransfer` es 0,99 s; en el otro, 0,01 s. ¿Qué pasa en cada uno y a qué equipo le mandarías el ticket? |
| 6 | Una petición falla con 7. Sin mirar el mensaje, ¿qué líneas esperas encontrar en la traza `-v` y cuáles no? ¿En qué se diferencia de la traza de un 60? ¿Y de la de un 401? |
| 7 | Has tachado `Authorization` en una traza `-v` y la pegas en un ticket. ¿Qué tres cosas más pueden dar acceso a tu cuenta desde esa traza? ¿Por qué la de la línea de petición no se puede tachar sin perder la traza? |
| 8 | Tu script funciona en tu máquina y en la de un compañero `jq` falla con `Invalid numeric literal`. El script es el mismo. ¿Qué sospechas y cómo lo confirmas en un comando? ¿Por qué `curl -sS -q` no lo arregla y `curl -q -sS` sí? |
| 9 | Un `.curlrc` tiene `max-time = 5`, `header = "X-Equipo: a"` y `location`. Tu comando añade `--max-time 30 -H 'X-Equipo: b'`. ¿Qué tiempo máximo, qué headers y qué política de redirects tiene la petición? ¿Cuál de las tres es la peligrosa? |
| 10 | ¿Por qué `printf 'header = "Authorization: Bearer %s"\n' "$API_TOKEN" \| curl -K - URL` no deja el token en `ps`, y `curl -H "Authorization: Bearer $API_TOKEN" URL` sí, si en los dos casos el token viene de una variable? ¿Dónde **sí** aparece en los dos? |

<details>
<summary><strong>Respuestas</strong></summary>

**1.** curl solo dibuja el medidor cuando **stdout no es una terminal**: en
pantalla lo destrozaría el cuerpo. En la terminal el cuerpo va a la pantalla y
no hay tabla; en el cron stdout está redirigido y la tabla aparece en stderr,
que acaba en el log. `-s` quita la tabla **y** los mensajes de error: el día que
falle, el log no dirá nada. `2>/dev/null` hace lo mismo y además tira la traza
si la hubiera. `-sS` (o `--no-progress-meter`) quita solo la tabla y deja el
`curl: (7) ...`: silencio cuando va bien, motivo cuando va mal.

**2.** Tiene un **`\r`** al final: las líneas de la cabecera HTTP terminan en CR
LF y curl las entrega tal cual. `abc123\r` no es `abc123`. Se arregla con
`tr -d '\r'` antes de nada. Con `-L` hay además **un bloque de headers por
respuesta**: el `grep` puede devolver el `ETag` del redirect, o dos líneas. Hay
que quedarse con la última coincidencia, o usar `%header{etag}` (7.84+), que
lee la última respuesta y ya quita el `\r`. Y la comparación del nombre tiene
que ser sin mayúsculas: el servidor puede escribir `Etag`.

**3.** Porque `-w` trata una variable desconocida como un aviso, no como un
error: escribe `unknown --write-out variable` en stderr y sigue, y la
transferencia salió bien, así que sale con 0. El script recibe una cadena vacía
y concluye lo que no es. `%{json}` imprime todas las variables reales con su
valor; si pides a `jq` un campo que no existe, devuelve `null` y con `jq -e`
falla. Además, un campo con espacios (`errormsg`) no rompe la lectura como
rompería un `read` de siete campos separados por espacios.

**4.** No. `time_starttransfer` es un **instante acumulado**: incluye DNS,
conexión TCP y handshake TLS. Lo del servidor es `time_starttransfer -
time_appconnect`. Sobre HTTP no hay TLS y `time_appconnect` vale **0**, no lo
mismo que `time_connect`: la resta `time_appconnect - time_connect` da negativo y
`time_starttransfer - time_appconnect` incluye la conexión entera. La regla:
si `time_appconnect` es 0, la fase TLS termina donde terminó la conexión.

**5.** En el primero, el primer byte llega casi al final: el tiempo se fue
**esperando al servidor**, la fase servidor. Es del backend: base de datos,
colas, cálculo. En el segundo, el primer byte llega enseguida y el resto del
segundo es **transferencia**: el cuerpo es grande, la red lenta, o el servidor
manda en streaming poco a poco. Es de quien decide el tamaño de la respuesta o
de la red. Mismo `time_total`, dos tickets distintos.

**6.** Un 7 es TCP: espero `* Trying ...` y `* connect to ... failed`, y
**ninguna** `* Connected`, ninguna `>` y ninguna `<`. En un 60 sí hay `*
Connected` (TCP funcionó) y líneas del handshake TLS, pero ninguna `>`: se
cortó antes de hablar HTTP, con `* SSL certificate problem`. En un 401 la
traza está **completa**: `>` con la petición (y el `Authorization`, si se
mandó) y `< HTTP/1.1 401`. El fallo no es de curl ni de la red: la API rechazó
la credencial, y la traza demuestra que llegó a enviarse.

**7.** Las **cookies** en `> Cookie:`, en `< Set-Cookie:` y en las líneas `*
Added cookie` del motor de cookies; un **header propio** de API key como
`X-API-Key`; y cualquier credencial en la **query string**, que sale en la
línea `> GET /ruta?token=...`. Además el usuario en `* Server auth using
Basic with user`. La línea de petición no se puede tachar porque es la que dice
qué endpoint se pidió: sin ella la traza no sirve. La conclusión es la regla
de siempre: ningún secreto va en la URL.

**8.** Un `.curlrc` en su máquina con `include` (o `-i`): curl pone los headers
delante del JSON y `jq` se atraganta con `HTTP/1.1`. Se confirma repitiendo
con `curl -q` delante: si cambia, era el `.curlrc`. `-q` solo funciona como
**primer argumento** porque curl decide si lee el `.curlrc` antes de procesar
el resto de la línea de comandos; en segunda posición ya lo ha leído, y lo
ignora sin avisar.

**9.** `--max-time 30`: es de valor único y gana el último, el del comando.
Headers: **los dos**, `X-Equipo: a` y `X-Equipo: b`, porque `-H` se acumula. Y
**sigue los redirects**: `location` es un interruptor que el comando no apaga
salvo con `--no-location`. La peligrosa es la tercera: nadie escribe
`--no-location` por si acaso, y seguir un redirect cambia a dónde llega la
petición y qué se reenvía (Semana 05). La segunda también muerde: dos valores
del mismo header suelen acabar en un error difícil de leer.

**10.** En `-H "...$API_TOKEN"` la shell **expande** la variable antes de
ejecutar curl: el token es parte del argv de curl, y el argv de cualquier
proceso lo ve cualquier usuario con `ps` o `/proc/PID/cmdline`. En la versión
con `printf`, `printf` es un **builtin** de bash: no crea un proceso con
argumentos; el token viaja por un pipe en memoria y curl solo tiene `-K -` en
su argv. En los dos casos **sí** aparece en la traza `-v`, porque el header
viaja, y en el historial solo queda `$API_TOKEN`, el nombre de la variable.

</details>

---

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Leer una traza | `salida.md` con la tabla de flujos y los headers separados del cuerpo; `traza.md` con la traza sana anotada y los cinco fallos localizados con su línea y su código; `traza-compartible.txt` sin token ni cookie | 10 |
| 02 — Medir con `--write-out` | `fases.md` con el formato en archivo, cuerpo y código separados, las fases de HTTP y HTTPS con su suma, `tls=0` explicado, `/delay` frente a `/drip` y una función `fases` que no da negativos ante un fallo | 10 |
| 03 — `.curlrc` sin romper scripts | `curlrc.md` con el script roto por `include`, el arreglo con `-q` en primera posición, la tabla de precedencia comprobada, el orden del `-K` y la credencial por stdin sin aparecer en `ps` | 10 |
| 04 — Métricas de un endpoint | `metricas.md` con tasa de error, p50, p95, máximo y media de cien peticiones, la fase culpable de `/delay/0.3`, la petición fallida registrada y la agrupación por endpoint | 10 |

---

## 📦 Producto (30%)

### Verificable por el autograding — 60 puntos

| Comprobación | Puntos |
|---|:--:|
| `toolkit-ejecutable` | 2 |
| `toolkit-sin-todos` | 2 |
| `toolkit-red-sigue` | 2 |
| `toolkit-ignora-curlrc` | 5 |
| `toolkit-user-agent` | 2 |
| `toolkit-timing-fases` | 4 |
| `toolkit-timing-sin-tls` | 4 |
| `toolkit-timing-con-tls` | 3 |
| `toolkit-stdout-limpio` | 4 |
| `toolkit-metricas-una-por-peticion` | 3 |
| `toolkit-metricas-campos` | 4 |
| `toolkit-metricas-sin-query` | 4 |
| `toolkit-metricas-fallo-de-red` | 4 |
| `toolkit-verbose-traza` | 3 |
| `toolkit-verbose-tacha-token` | 6 |
| `toolkit-verbose-tacha-apikey` | 5 |
| `toolkit-shellcheck` | 3 |
| **Total** | **60** |

### Calidad — 40 puntos

| Criterio | Qué se mira | Puntos |
|---|---|:--:|
| Un solo punto de ejecución | Nadie llama a `curl` fuera de `lanzar_curl`; `--disable` es su primer argumento; `--dry-run` lo enseña | 7 |
| El código de curl sobrevive | `lanzar_curl` devuelve el código de curl, no el del filtro; `fallo_de_red` sigue saltando con 6, 7, 28, 60 | 6 |
| Tachado completo | `Authorization`, `Proxy-Authorization`, `Cookie`, `Set-Cookie`, el header de `API_KEY_HEADER` y las líneas `* Added/Replaced cookie`, sin distinguir mayúsculas y portable a macOS (sin `sed -I`) | 7 |
| Temporal protegido | La traza sin tachar vive en un archivo con 600, creado con `umask 077` y borrado en `limpiar` | 5 |
| Fases correctas | `fases` acota a cero, `tls` es 0 sin TLS, servidor y transferencia son 0 sin primer byte; las seis suman el total | 5 |
| Métricas bien construidas | `jq -cn` con `--arg` y `--argjson`, `>>`, query string fuera, `000` convertido a 0, medida antes de salir | 5 |
| Documentación de salida | La cabecera explica `--verbose`, `--timing`, `METRICS_FILE` y que el `~/.curlrc` no se lee | 5 |
| **Total** | | **40** |

### Penalizaciones

| Situación | Deducción |
|---|---|
| Una traza, un `METRICS_FILE` o un temporal con una credencial real comiteado, aunque sea en el histórico | **−30** y hay que rotarla ya |
| Un `-k` o `--insecure` en la entrega | **−20** |
| `--verbose` enseña el token o la API key en claro | −15 |
| `--trace` o `--trace-ascii` en el código del toolkit | −10 |
| El temporal de la traza se crea con la umask por defecto (644) | −8 |
| La traza o los tiempos van a stdout y rompen el pipe | −8 |
| Alguna llamada a curl sin `--disable` | −6 |
| El JSON de métricas montado con `printf` y comillas | −5 |
| La query string en `METRICS_FILE` | −5 |
| Mensajes de error en stdout | −4 |
| `shellcheck -S warning` con avisos | −5 |

Las dos primeras no son puntos: son la diferencia entre una herramienta que se
puede usar para depurar en producción y una que convierte cada depuración en
una fuga. Esta semana enseña a mirar dentro sin dejar la puerta abierta; una
traza con el token en el repositorio es lo contrario.

---

[← README de la Semana 06](README.md)
