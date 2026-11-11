# Semana 06 — Output, debug y configuración

> Hasta ahora, cuando curl fallaba, mirabas el código de salida y adivinabas.
> Esta semana aprendes a hacerle hablar: qué envió, qué le contestaron, dónde
> se fue cada milisegundo y qué configuración estaba leyendo sin que lo
> supieras. Una herramienta que no se deja observar no se puede operar.

---

## 🎯 Objetivos de la Semana

Al terminar serás capaz de:

- Decir qué escribe curl en stdout y qué en stderr, y mantener el cuerpo limpio para el siguiente comando del pipe
- Separar los headers de la respuesta del cuerpo con `-D`, y leer un header concreto sin romperlo con el `\r` final
- Extraer de una petición cualquier dato con `--write-out`: código, tamaños, URL final, código de salida y mensaje de error
- Medir cada fase de una petición (DNS, TCP, TLS, servidor, transferencia) y decir cuál es la lenta
- Leer una traza `-v` y señalar la línea exacta donde falló la petición, sin filtrar la credencial al compartirla
- Usar `--trace-ascii` y `--trace-time` cuando `-v` no enseña lo suficiente
- Escribir un `.curlrc`, saber en qué orden lo busca curl y por qué un script tiene que ignorarlo con `-q`
- Llevar la configuración de una tarea en un archivo `-K`, incluida la credencial leída de stdin

---

## 📋 Prerrequisitos

- **Semana 05 completada**: `api-toolkit.sh` con `construir_red` y `./scripts/verificar-semana.sh 05` en verde
- **El laboratorio levantado**: `./scripts/start.sh`. Esta semana usa el httpbin (8080) y el frontal HTTPS (8443) con `docs/lab-ca.pem` exportada
- **`jq` instalado**: `jq --version`. La práctica 04 agrega métricas con él
- **Leer las fases de una petición**: la teoría 07 de la Semana 05 ya presentó `time_connect` y `time_starttransfer`; aquí se usan a fondo
- **Tu versión de curl a mano**: `curl --version | head -1`. Esta semana aparecen `%header{nombre}` (7.84+), `--trace-ids` (8.2+), `--trace-config` y `--variable` (8.3+); en 7.81 no existen y se da la alternativa
- **No tener un `~/.curlrc` que no conozcas**: `ls -l ~/.curlrc`. Si existe, léelo antes de empezar; la práctica 03 explica por qué

---

## 🗂️ Estructura de la Semana

```
week-06-output_debug_configuracion/
├── README.md                  # Este archivo
├── rubrica-evaluacion.md      # Cómo se evalúa
├── checks.json                # Las 18 comprobaciones automáticas
├── 0-assets/                  # Diagramas
├── 1-teoria/                  # 8 archivos, un concepto cada uno
├── 2-practicas/               # 4 prácticas sobre el laboratorio
├── 3-proyecto/                # La capa 6 de api-toolkit: observable
├── 4-recursos/                # Libros, vídeos y enlaces
└── 5-glosario/                # Términos de esta semana
```

---

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01 — stdout y stderr](1-teoria/01-stdout-y-stderr.md) | Qué va a cada flujo, `-s`, `-S`, `--no-progress-meter`, `-o`, `--stderr` y el cuerpo limpio para el pipe | 15 min |
| [02 — Los headers de la respuesta](1-teoria/02-headers-de-la-respuesta.md) | `-i`, `-I`, `-D`, separar headers y cuerpo, el `\r` final, varias respuestas en un archivo, `%header{}` | 15 min |
| [03 — `--write-out`](1-teoria/03-write-out.md) | El formato, las variables que importan, `@archivo`, `%{stderr}`, `%{json}`, `%{onerror}` y la salida cuando falla | 15 min |
| [04 — Medir las fases](1-teoria/04-medir-las-fases.md) | Los `time_*` acumulados, de instantes a duraciones, qué fase delata qué problema, la varianza | 15 min |
| [05 — Leer una traza `-v`](1-teoria/05-leer-una-traza-verbose.md) | Las tres marcas, dónde aparece cada fallo, qué filtra la traza y cómo tacharla | 15 min |
| [06 — `--trace` y `--trace-ascii`](1-teoria/06-trace-y-trace-ascii.md) | Cuándo `-v` no basta, los bytes del cuerpo, `--trace-time`, `--trace-ids`, `--libcurl` | 15 min |
| [07 — El archivo `.curlrc`](1-teoria/07-el-archivo-curlrc.md) | El formato, el orden de búsqueda, qué poner y qué no, `-q` y por qué un script lo necesita | 15 min |
| [08 — Configuración por tarea](1-teoria/08-configuracion-por-tarea.md) | `-K archivo`, `-K -` con la credencial por stdin, el orden de precedencia, `--variable` | 15 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01 — Leer una traza](2-practicas/01-leer-una-traza.md) | Una traza sana línea a línea, cinco fallos localizados en la traza, la credencial tachada y el cuerpo con `--trace-ascii` | 50 min |
| [02 — Medir con `--write-out`](2-practicas/02-medir-con-write-out.md) | Un formato en archivo, las fases de HTTP y HTTPS, duraciones con awk, `%{json}` y la medida de un fallo | 50 min |
| [03 — `.curlrc` sin romper scripts](2-practicas/03-curlrc-sin-romper-scripts.md) | Un `.curlrc` en un `CURL_HOME` de pruebas, ver cómo rompe un script, `-q`, un `-K` por tarea y la credencial por stdin | 50 min |
| [04 — Métricas de un endpoint](2-practicas/04-metricas-de-un-endpoint.md) | Cien peticiones a JSON Lines, mediana, p95 y tasa de error con jq, y la fase culpable de una lentitud | 50 min |

### Proyecto

La **capa 6** de tu plataforma: `api-toolkit.sh` se vuelve observable. Todas las
llamadas a curl pasan por una sola función, `lanzar_curl`, que ignora el
`~/.curlrc` y tacha las credenciales de la traza. `--verbose` enseña la
conversación HTTP, `--timing` el tiempo de cada fase, y `METRICS_FILE` deja una
línea JSON por petición, también cuando falla. Detalles en
[3-proyecto](3-proyecto/README.md).

---

## ⏱️ Distribución del Tiempo (8 horas)

| Bloque | Tiempo |
|---|:--:|
| Teoría (8 archivos) | 2 h 00 |
| Prácticas (4 × 50 min) | 3 h 20 |
| Proyecto | 2 h 00 |
| Revisión y verificación | 40 min |
| **Total** | **8 h 00** |

> [!TIP]
> Haz la práctica 01 antes del TODO 6 del proyecto y la 02 antes de los TODOs
> 3 a 5. Tachar una traza es fácil cuando has visto en qué líneas exactas
> aparece la credencial; calcular fases es fácil cuando has visto un
> `time_appconnect` a cero.

---

## 🔭 Tres preguntas, tres herramientas

Casi toda la depuración HTTP es responder a una de estas tres preguntas, y cada
una tiene su herramienta. Usar la equivocada es la forma más común de perder la
tarde.

| Pregunta | Herramienta | Qué enseña | Qué no enseña |
|---|---|---|---|
| ¿Qué pasó? | `-w '%{http_code} %{exitcode} %{errormsg}'` | El resultado en una línea, apta para un log | Por qué |
| ¿Por qué pasó? | `-v` | La conversación: headers, TLS, redirects, reintentos | El cuerpo, los tiempos |
| ¿Qué bytes viajaron? | `--trace-ascii` | Todo, cuerpo incluido, con `--trace-time` si hace falta | Nada: por eso es peligroso |
| ¿Cuánto tardó cada parte? | `-w` con los `time_*` | DNS, TCP, TLS, servidor, transferencia | Qué se dijo |

Y una cuarta, la que nadie se hace hasta que le muerde: **¿qué configuración
estaba usando curl?** La respuesta está en el `~/.curlrc`, y en un script
la única respuesta aceptable es "ninguna": `curl -q`.

---

## 🎩 Trucos y atajos

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

---

## 📌 Entregables

1. `salida.md` con lo que va a stdout y a stderr en cada combinación de `-s`, `-S`, `-o` y `-v`, y los headers de una respuesta separados del cuerpo
2. `traza.md` con una traza `-v` sana anotada y cinco fallos (DNS, conexión, TLS, 401, bucle de redirects) localizados en su línea
3. Una traza con `AUTH_MODE=bearer` lista para compartir, sin el token y sin la cookie
4. `fases.md` con las fases medidas de HTTP y HTTPS, su suma y la explicación de por qué `time_appconnect` vale 0 en HTTP
5. `curlrc.md` con el `.curlrc` de pruebas, el script que rompe, cómo lo arregla `-q` y el orden de precedencia comprobado
6. `metricas.md` con mediana, p95, máximo y tasa de error de un endpoint, y la fase responsable de su lentitud
7. `api-toolkit.sh` con la capa 6 completa y ningún `TODO` pendiente
8. `--verbose` traza por stderr con las credenciales y las cookies tachadas, y stdout sigue siendo solo el cuerpo
9. `--timing` imprime las seis medidas, con `tls` a cero en HTTP y nunca un negativo
10. `METRICS_FILE` recibe una línea JSON por petición, sin la query string, también ante un 4xx o un fallo de red
11. El toolkit ignora el `~/.curlrc` y se presenta como `api-toolkit/VERSION`

---

## ✅ Verificación

```bash
./scripts/start.sh
./scripts/verificar-semana.sh 06
```

Las 18 comprobaciones tienen que pasar. Si alguna falla, la pista te dice en qué
TODO del proyecto se arregla.

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [Semana 05 — SSL/TLS, cookies y redirects](../week-05-ssl_tls_cookies_redirects/README.md) | **Semana 06 — Output, debug y configuración** | [Semana 07 — Scripting bash con curl](../week-07-scripting_bash_con_curl/README.md) |

[← Volver al inicio del bootcamp](../README.md)
