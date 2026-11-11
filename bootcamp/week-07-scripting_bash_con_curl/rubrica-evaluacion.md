# Rúbrica de evaluación — Semana 07

> Scripting bash con curl. Se evalúa que tus scripts digan la verdad: que
> fallen cuando deben, que distingan "repite más tarde" de "algo está mal",
> que no mezclen un error con los datos y que recorran un listado entero sin
> salirse de la API ni machacarla.

---

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales |
| 💪 Desempeño | 40% | Las 4 prácticas, con sus entregables y salida real de tu máquina |
| 📦 Producto | 30% | `api-toolkit.sh`: 60 pts de autograding + 40 pts de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio. Un `fetch-all` que pasa los
checks no compensa no saber por qué un `local x=$(curl ...)` se traga el fallo.

---

## 🧠 Conocimiento (30%)

| # | Pregunta |
|:--:|---|
| 1 | Un cron ejecuta `curl -sS "$URL" > datos.json && publicar datos.json`. Un día la API responde 500 y `publicar` sube el error a producción. ¿Por qué el `&&` no lo paró? Da dos formas de arreglarlo y di qué pierde cada una. |
| 2 | Un script falla con 6 en CI y con 7 en tu máquina, contra la misma URL. ¿Qué te dice cada código, sin leer el mensaje? ¿Cuál de los dos tiene sentido reintentar? |
| 3 | `curl -sS "$URL" \| jq -r .id` sale con 0 cuando el servidor está caído. ¿Por qué? ¿Qué cambia `set -o pipefail`, y qué problema nuevo trae con `curl "$URL" \| head -1`? |
| 4 | En un script con `set -euo pipefail`, `f() { local cuerpo=$(curl -sS --fail-with-body "$URL"); procesar "$cuerpo"; }` procesa un cuerpo vacío cuando la API falla. ¿Por qué no abortó? ¿Y si `f` se llama desde `if f; then ...`, aunque arregles lo primero? |
| 5 | `jq -e '.items \| length > 0' respuesta.json` sale con 0 en tu portátil con un archivo vacío y con 4 en el servidor de CI. ¿Qué diferencia hay entre las dos máquinas? ¿Cómo escribes la comprobación para que se comporte igual en las dos? |
| 6 | Un script captura `cuerpo=$(curl -sS --retry 3 "$URL")` y a veces `jq -r .id <<<"$cuerpo"` imprime dos líneas, y la primera es `null`. ¿Qué ha pasado? ¿Por qué `-o archivo` lo arregla y `-D archivo` no tiene el mismo comportamiento? |
| 7 | La página 2 de un listado trae `Link: <...page=1>; rel="prev", <...page=3>; rel="next"`. Un script toma la primera URL entre `< >`. ¿Qué hace a partir de ahí? ¿Qué freno lo habría detenido aunque el parser estuviera mal? |
| 8 | ¿Por qué un script que sigue el `rel="next"` necesita comprobar el host, si curl ya quita el `Authorization` al seguir un redirect a otro host? ¿Por qué la comprobación tiene que incluir la `/` final? |
| 9 | Una API responde 429 con `Retry-After: Wed, 21 Oct 2026 07:28:00 GMT`. Tu bucle de backoff espera 1 s y repite. ¿Qué ha fallado en el parser? ¿Por qué un cliente que corre en doscientas máquinas necesita además azar en la espera? |
| 10 | El toolkit sale con 75 ante un 503 y con 1 ante un 404. ¿Qué haría un cron bien escrito con cada uno? ¿Por qué el 500 sale con 1 y no con 75? |

<details>
<summary><strong>Respuestas</strong></summary>

**1.** Sin `--fail`, un 500 es una transferencia correcta: curl sale con 0, el
`&&` sigue y `datos.json` contiene el cuerpo del error. Arreglos:
`--fail-with-body` hace que curl salga con 22 ante un 4xx/5xx; pierde la
distinción entre códigos (todo es 22), y el cuerpo del error queda en
`datos.json` si no se descarga a un temporal. Leer `-w '%{http_code}'` y
decidir en un `case` conserva el código exacto, a cambio de que el script
cubra todos los casos, también el `*`.

**2.** El 6 es DNS: el nombre no resuelve, casi siempre por configuración (un
host mal escrito, un DNS interno que CI no ve). Reintentar no lo arregla. El 7
es conexión rechazada: el host existe pero nadie escucha en ese puerto, quizá
porque el servicio se está reiniciando. Ese sí puede tener sentido
reintentarlo, y con curl hace falta `--retry-connrefused`.

**3.** Sin `pipefail`, el código de una tubería es el del último comando, `jq`,
que con una entrada vacía no se queja. `pipefail` hace que la tubería salga con
el último código distinto de 0, el 7 de curl. El problema nuevo: `head -1` lee
una línea y cierra; curl, que aún tiene datos por escribir, falla con 23, y
`pipefail` lo convierte en un fallo de toda la línea aunque no haya pasado
nada. Se evita guardando la respuesta en un archivo y aplicando `head` al
archivo.

**4.** `-e` mira el código de `local`, que es siempre 0; el de la sustitución
se pierde. Se arregla separando: `local cuerpo` y `cuerpo=$(curl ...)`. Pero
si `f` se evalúa en un `if`, `-e` se desactiva **dentro** de `f` entero: el
`cuerpo=$(curl ...)` que falla ya no aborta. La solución es comprobar
explícitamente: `cuerpo=$(curl ...) || return 1`.

**5.** El portátil tiene jq 1.6 (Ubuntu 22.04), que ante una entrada vacía no
evalúa nada y sale con 0 aunque lleve `-e`. jq 1.7 lo corrigió y sale con 4.
La comprobación portable mira antes que el archivo no esté vacío:
`[ -s respuesta.json ] && jq -e '.items | length > 0' respuesta.json`.

**6.** Con `--retry`, curl escribe en stdout el cuerpo de **cada** intento, y no
puede borrar lo ya escrito en una tubería. Si el primer intento dio 503 con un
cuerpo JSON de error y el segundo 200, `cuerpo` tiene los dos pegados: dos
valores JSON seguidos, y jq procesa los dos. Con `-o archivo`, curl trunca el archivo antes de cada reintento y
queda solo el último. `-D` no se trunca: acumula un bloque de headers por
intento, y hay que leer el último.

**7.** Vuelve a la página 1, cuyo `next` es la 2, cuyo primer enlace es la 1:
un bucle infinito de dos páginas, con cada vuelta gastando peticiones de tu
cupo y acumulando duplicados. El máximo de páginas lo habría parado con un
error en vez de dejarlo correr.

**8.** Porque aquí no hay redirect: es el script quien pide la URL nueva, con
todas sus opciones, incluido el `--config` con la credencial. curl no tiene
por qué sospechar de una URL que le pasas tú. La `/` final impide que
`https://api.ejemplo.com.atacante.net/` pase la comparación con
`https://api.ejemplo.com`, con la que comparte el principio.

**9.** El parser solo entiende `Retry-After` en segundos. RFC 9110 permite
también una fecha HTTP; el parser no la reconoce como número y cae al backoff
propio, ignorando lo que pidió la API. Hay que convertir la fecha a segundos
(`date -d`) y restar la hora actual. El azar: doscientos clientes que reciben
el 429 a la vez y esperan exactamente lo mismo vuelven a la vez y vuelven a
saturar; con azar, sus reintentos se reparten en el tiempo.

**10.** Ante un 75 (temporal), no avisar a nadie y dejar que el siguiente
ciclo lo intente: el servidor ha dicho "ahora no". Ante un 1 (definitivo),
avisar: el 404 no va a desaparecer solo, alguien tiene que mirar la URL o los
datos. El 500 sale con 1 porque, si fuera pasajero, el `--retry` de un `GET`
ya lo habría superado; y un 500 persistente suele ser un bug del servidor que
fallará siempre con la misma petición.

</details>

---

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Cada fallo, su código | `codigos.md` con un fallo provocado por fase y su código, `--fail` frente a `--fail-with-body` contra `/limitado`, `\|\| rc=$?` con `set -e`, `PIPESTATUS`, las dos trampas de `-e`, el 23 de `curl \| head` y `salida_para` | 10 |
| 02 — Reintentos sin sorpresas | `reintentos.md` con los tiempos de `--retry 1`, `2` y `3`, qué reintenta y qué no, los cuerpos concatenados frente a `-o`, los bloques de `-D` con un redirect y una función `cabecera` que lee el último bloque | 10 |
| 03 — Recorrer un listado paginado | `paginar.sh`, `shellcheck` limpio, que junta las siete entradas de `/paginas`, elige el `next` en la página 2, se niega a seguir `?page=fuera` con stdout vacío y para en `MAX_PAGINAS` con `?page=bucle` | 10 |
| 04 — Backoff a mano | `backoff.sh`, `shellcheck` limpio, que respeta `Retry-After` en segundos y en fecha, dobla la espera con tope, suma azar en milisegundos, se rinde con 75 y no reintenta un 404 | 10 |

---

## 📦 Producto (30%)

### Verificable por el autograding — 60 puntos

| Comprobación | Puntos |
|---|:--:|
| `toolkit-ejecutable` | 2 |
| `toolkit-sin-todos` | 2 |
| `toolkit-get-sigue` | 2 |
| `toolkit-observable-sigue` | 2 |
| `toolkit-404-sale-1` | 2 |
| `toolkit-error-fuera-de-stdout` | 5 |
| `toolkit-429-sale-75` | 4 |
| `toolkit-503-sale-75` | 3 |
| `toolkit-429-retry-after` | 4 |
| `toolkit-reintentos-un-cuerpo` | 5 |
| `toolkit-fetch-all-junta` | 5 |
| `toolkit-fetch-all-rel-next` | 5 |
| `toolkit-fetch-all-otro-host` | 6 |
| `toolkit-fetch-all-bucle` | 4 |
| `toolkit-fetch-all-no-lista` | 4 |
| `toolkit-shellcheck` | 5 |
| **Total** | **60** |

### Calidad — 40 puntos

| Criterio | Qué se mira | Puntos |
|---|---|:--:|
| Un cuerpo, un archivo | `peticion` manda el cuerpo a `--output` y los headers a `--dump-header`; stdout de curl solo lleva el `-w`; nada se captura de stdout | 7 |
| Headers bien leídos | `cabecera` lee el último bloque, quita el `\r`, no distingue mayúsculas en ningún lado y corta solo en el primer `:` | 6 |
| Contrato de salida | stdout solo con datos de un 2xx/3xx; el cuerpo de un error y todos los mensajes por stderr; 75 para 429, 502, 503 y 504; 77 para 401 y 403 | 7 |
| Frenos de `fetch-all` | `misma_api` con la `/` final; `MAX_PAGINAS` comprobado antes de cada petición; un `Link` relativo se rechaza en vez de resolverse mal | 6 |
| Completo o nada | `fetch-all` acumula en `PAGINAS` y solo imprime al final; una página vacía o que no es lista corta con error, también con jq 1.6 | 5 |
| Temporales protegidos | `CUERPO`, `CABECERAS` y `PAGINAS` con 600, creados con `temporal_privado` y borrados en `limpiar` | 4 |
| Documentación | El `--help` explica `fetch-all`, el 75 y que stdout solo lleva datos; los comentarios dicen por qué | 5 |
| **Total** | | **40** |

### Penalizaciones

| Situación | Deducción |
|---|---|
| Una credencial real comiteada, en el código, en un temporal o en una traza | **−30** y hay que rotarla ya |
| `fetch-all` sigue un `Link` a otro host | **−20** |
| Un `-k` o `--insecure` en la entrega | **−20** |
| `--retry` añadido a un `POST` | −10 |
| `--retry-all-errors` en el toolkit | −8 |
| `fetch-all` imprime páginas según llegan | −8 |
| El cuerpo de un error sale por stdout | −6 |
| Un bucle de backoff propio sin tope o sin respetar `Retry-After` | −6 |
| Un temporal creado con la umask por defecto (644) | −5 |
| `shellcheck -S warning` con avisos | −5 |

Las dos primeras no son puntos: son la diferencia entre un script que se
puede dejar en un cron y uno que, el día que la API cambie, le manda tu
credencial a otro sitio. Esta semana enseña a desconfiar de lo que dice la
respuesta; seguir un `next` a cualquier host es lo contrario.

---

[← README de la Semana 07](README.md)
