# Semana 07 — Scripting bash con curl

> Un comando curl en la terminal falla delante de ti. Uno dentro de un script
> falla a las tres de la mañana, dentro de un cron, y lo único que queda es un
> código de salida y lo que escribió en stdout. Esta semana aprendes a que
> esas dos cosas digan la verdad: que el script falle cuando debe, que
> distinga "repite más tarde" de "algo está mal", que recorra un listado
> entero y que no machaque a una API que le pide calma.

---

## 🎯 Objetivos de la Semana

Al terminar serás capaz de:

- Leer el código de salida de curl y saber en qué fase falló la petición, también dentro de una tubería
- Elegir entre `--fail`, `--fail-with-body` y leer `%{http_code}`, sin que el cuerpo de un error acabe tratado como datos
- Escribir scripts con `set -euo pipefail` sabiendo dónde no protege: `if`, `||`, `local x=$(...)` y `curl | head`
- Validar una respuesta con `jq -e` antes de usarla, pasar valores con `--arg` y juntar varias respuestas con `-s`
- Recorrer un listado paginado siguiendo el header `Link`, con un máximo de páginas y sin salir nunca del host de la API
- Saber qué reintenta `--retry`, cuánto espera y qué deja en stdout, en `-o` y en `-D` después de varios intentos
- Responder a un 429 con `Retry-After` o con backoff exponencial con azar, y rendirse con un código que diga "más tarde"
- Diseñar el contrato de un script: datos por stdout, todo lo demás por stderr, y un código de salida para cada tipo de fallo

---

## 📋 Prerrequisitos

- **Semana 06 completada**: `api-toolkit.sh` con `lanzar_curl` y `medir`, y `./scripts/verificar-semana.sh 06` en verde
- **El laboratorio actualizado**: esta semana añade a `https://localhost:8443` las rutas `/paginas` (paginación con `Link`) y `/limitado` (429 con `Retry-After`). Si clonaste el repositorio antes, actualízalo y ejecuta `docker compose restart tls`
- **`docs/lab-ca.pem` exportada**: `./scripts/start.sh` lo hace. Casi todo esta semana va por HTTPS
- **`jq` y `shellcheck` instalados**: `jq --version` (Ubuntu 22.04 trae 1.6; la teoría 04 explica en qué se nota)
- **Tu versión de curl a mano**: `curl --version | head -1`. Esta semana aparecen `--fail-with-body` (7.76+), `--retry-all-errors` (7.71+) y `%{num_retries}` (8.9+); 7.81 tiene las dos primeras

---

## 🗂️ Estructura de la Semana

```
week-07-scripting_bash_con_curl/
├── README.md                  # Este archivo
├── rubrica-evaluacion.md      # Cómo se evalúa
├── checks.json                # Las 18 comprobaciones automáticas
├── 0-assets/                  # Diagramas
├── 1-teoria/                  # 8 archivos, un concepto cada uno
├── 2-practicas/               # 4 prácticas sobre el laboratorio
├── 3-proyecto/                # La capa 7 de api-toolkit: robusto
├── 4-recursos/                # Libros, vídeos y enlaces
└── 5-glosario/                # Términos de esta semana
```

---

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01 — Códigos de salida de curl](1-teoria/01-codigos-de-salida-de-curl.md) | Un código por fase, por qué un 500 sale con 0, `PIPESTATUS`, `pipefail` y el `case` por familias | 15 min |
| [02 — `--fail` y `--fail-with-body`](1-teoria/02-fail-y-fail-with-body.md) | Qué hace cada uno con el cuerpo del error, por qué no se combinan, el límite del 401 y la tercera vía con `%{http_code}` | 15 min |
| [03 — `set -euo pipefail` y sus trampas](1-teoria/03-errexit-y-sus-trampas.md) | Dónde no mira `-e`, `local x=$(...)`, `\|\| rc=$?`, `-u` con valores por defecto, `trap` y el 23 de `curl \| head` | 15 min |
| [04 — jq en scripts](1-teoria/04-jq-en-scripts.md) | `-e` y los códigos de jq, la entrada vacía de jq 1.6, `--arg`, `-s` para juntar y `@tsv` para volver a bash | 15 min |
| [05 — Paginación](1-teoria/05-paginacion.md) | Cuatro estilos, el header `Link`, cuándo parar y los dos frenos: máximo de páginas y no salir de la API | 15 min |
| [06 — Los reintentos de curl, por dentro](1-teoria/06-reintentos-de-curl.md) | Qué es transitorio, el backoff de curl, `--retry-max-time`, qué queda en stdout, `-o` y `-D`, y qué métodos reintentar | 15 min |
| [07 — Rate limit y backoff](1-teoria/07-rate-limit-y-backoff.md) | 429 y `Retry-After`, los headers del cupo, backoff exponencial con tope y azar, y cuándo rendirse | 15 min |
| [08 — El contrato de un script](1-teoria/08-el-contrato-de-un-script.md) | stdout para datos, `sysexits.h`, temporal o definitivo, completo o nada, y quien llama al otro lado | 15 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01 — Cada fallo, su código](2-practicas/01-cada-fallo-su-codigo.md) | Un fallo por fase, `--fail` frente a `--fail-with-body`, `\|\| rc=$?`, las trampas de `-e` y una función que traduce el código HTTP | 50 min |
| [02 — Reintentos sin sorpresas](2-practicas/02-reintentos-sin-sorpresas.md) | Cronometrar `--retry`, ver los cuerpos concatenados, el cuerpo único con `-o`, los bloques de `-D` y leer un header del último | 50 min |
| [03 — Recorrer un listado paginado](2-practicas/03-recorrer-un-listado-paginado.md) | Leer el `Link`, sacar el `rel="next"`, el bucle, juntar con `jq -s` y los dos frenos contra `?page=fuera` y `?page=bucle` | 50 min |
| [04 — Backoff a mano](2-practicas/04-backoff-a-mano.md) | Un bucle de backoff con tope y azar, respetar `Retry-After`, rendirse con 75 y leer el cupo de GitHub | 50 min |

### Proyecto

La **capa 7** de tu plataforma: `api-toolkit.sh` se vuelve robusto. El cuerpo
y los headers van a archivos, así que un reintento ya no mezcla respuestas.
Un error nunca sale por stdout, y un 429 o un 503 salen con 75, con el
`Retry-After` en el mensaje. Además, un subcomando nuevo, `fetch-all`, recorre
un listado paginado entero siguiendo el `Link`, sin salir de la API y sin
imprimir nada hasta tener la última página. Detalles en
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
> Haz la práctica 02 antes de los TODOs 1 y 2 del proyecto, y la 03 antes de
> los TODOs 4 a 6. Ver con tus ojos tres cuerpos pegados en stdout es lo que
> hace obvio por qué `peticion` escribe en un archivo; ver un `Link` con el
> `next` en tercer lugar es lo que hace obvio por qué no vale la primera URL.

---

## 🧭 Cuatro preguntas antes de repetir

Un script robusto no reintenta todo ni se rinde ante todo. Ante cada fallo
se hace cuatro preguntas, en este orden:

| Pregunta | Si la respuesta es sí | Dónde se ve |
|---|---|---|
| ¿Hubo respuesta HTTP? | Mira el código HTTP. Si no la hubo, mira el código de curl: un 6 no se arregla solo, un 7 o un 28 quizá | Teoría 01 |
| ¿El código dice "más tarde"? | 429, 502, 503 y 504 merecen otro intento. El resto de 4xx, no | Teoría 08 |
| ¿Es seguro repetir? | `GET`, `PUT` y `DELETE`, sí. Un `POST`, solo si la API acepta una clave de idempotencia | Teoría 06 |
| ¿Cuánto esperar? | Lo que diga `Retry-After`. Si no dice nada, backoff con tope y azar. Si es demasiado, rendirse con 75 | Teoría 07 |

---

## 🎩 Trucos y atajos

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

---

## 📌 Entregables

1. `codigos.md` con un fallo provocado por cada fase y su código, la diferencia entre `--fail` y `--fail-with-body` y las dos trampas de `-e` reproducidas
2. `reintentos.md` con el tiempo de un `--retry 3` contra un 503, los cuerpos concatenados en stdout, el cuerpo único con `-o` y los bloques de `-D`
3. `paginar.sh`, que junta las siete entradas de `/paginas` en una sola lista y se niega a seguir `?page=fuera` y `?page=bucle`
4. `backoff.sh`, con un bucle que respeta `Retry-After`, dobla la espera con tope y azar y sale con 75 al rendirse
5. `api-toolkit.sh` con la capa 7 completa y ningún `TODO` pendiente
6. El cuerpo de una respuesta de error sale por stderr, y stdout queda vacío
7. Un 429, un 502, un 503 y un 504 salen con 75, y el mensaje incluye el `Retry-After` si la respuesta lo trae
8. Un `GET` reintentado deja un solo cuerpo, el del último intento
9. `fetch-all` imprime todas las páginas como una sola lista, o nada si alguna falla
10. `fetch-all` no sigue un `Link` fuera de `BASE_URL` y para en `MAX_PAGINAS`

---

## ✅ Verificación

```bash
./scripts/start.sh
./scripts/verificar-semana.sh 07
```

Las 18 comprobaciones tienen que pasar. Si alguna falla, la pista te dice en qué
TODO del proyecto se arregla.

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [Semana 06 — Output, debug y configuración](../week-06-output_debug_configuracion/README.md) | **Semana 07 — Scripting bash con curl** | [Semana 08 — OAuth2 y autenticación avanzada](../week-08-oauth2_y_autenticacion_avanzada/README.md) |

[← Volver al inicio del bootcamp](../README.md)
