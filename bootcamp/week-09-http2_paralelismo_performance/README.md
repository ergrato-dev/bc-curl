# Semana 09 — HTTP/2, paralelismo y rendimiento

> Tu script hace 200 peticiones y tarda un minuto. El servidor responde en
> 20 ms: el resto se va en abrir 200 conexiones, en esperar una respuesta
> antes de pedir la siguiente, y en descargar otra vez lo que ya tenías. Esta
> semana aprendes a ver dónde se va el tiempo, a reutilizar la conexión, a
> pedir en paralelo con un solo curl, a medir sin que la media te mienta, y a
> que varias copias de tu script no se pisen.

---

## 🎯 Objetivos de la Semana

Al terminar serás capaz de:

- Partir el tiempo de una petición en sus fases y decidir cuál se puede ahorrar
- Reutilizar la conexión dando varias URLs a un mismo curl, en la línea, con `--next` o en un `--config`, y comprobarlo con `%{num_connects}`
- Explicar qué cambia HTTP/2, cómo se negocia con ALPN y por qué sin TLS casi nunca se usa
- Lanzar peticiones en paralelo con `-Z`, limitarlas con `--parallel-max` y saber cuándo poner `--parallel-immediate`
- Resumir una medida con min, media, p95 y max, y evitar lo que la contamina: el handshake, los reintentos y los redirects
- Revalidar con ETag e `If-None-Match`, y guardar una caché en disco sin abrir un agujero
- Reconocer HTTP/3 y WebSocket con curl 7.81, y saber desde qué versión curl los habla
- Proteger con `flock` el estado que comparten varios procesos

---

## 📋 Prerrequisitos

- **Semana 08 completada**: `api-toolkit.sh` con la capa 8 y `./scripts/verificar-semana.sh 08` en verde. Esta semana renueva la sesión OAuth2 desde varios procesos a la vez
- **Semana 06 repasada**: las variables `time_*` y `%{num_connects}` de `--write-out`, `--timing`, y `-K` con una lista de URLs. Esta semana se mide con ellas
- **Semana 02 repasada**: `--next` para mezclar operaciones en un mismo curl
- **El laboratorio arriba**: `./scripts/start.sh`. El endpoint TLS habla HTTP/2: compruébalo con `curl --cacert docs/lab-ca.pem -s -o /dev/null -w '%{http_version}\n' https://localhost:8443/get`, que debe imprimir `2`
- **`flock`**: viene con util-linux en cualquier Linux. En macOS, `brew install flock`; sin él, el toolkit funciona igual, pero sin cerrojo
- **Tu versión de curl**: `curl --version | head -1`. Todo lo de esta semana funciona en 7.81; `--rate` (7.84), `--http3-only` (7.88) y `ws://` (8.11 por defecto) solo aparecen como referencia

---

## 🗂️ Estructura de la Semana

```
week-09-http2_paralelismo_performance/
├── README.md                  # Este archivo
├── rubrica-evaluacion.md      # Cómo se evalúa
├── checks.json                # Las 18 comprobaciones automáticas
├── 0-assets/                  # Diagramas
├── 1-teoria/                  # 8 archivos, un concepto cada uno
├── 2-practicas/               # 4 prácticas sobre el laboratorio
├── 3-proyecto/                # La capa 9 de api-toolkit: rápido
├── 4-recursos/                # Libros, vídeos y enlaces
└── 5-glosario/                # Términos de esta semana
```

---

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01 — Dónde se va el tiempo](1-teoria/01-donde-se-va-el-tiempo.md) | Las cinco fases de una petición, latencia frente a ancho de banda, cuántos viajes cuesta una conexión nueva y qué se puede ahorrar | 15 min |
| [02 — Reutilizar la conexión](1-teoria/02-reutilizar-la-conexion.md) | La conexión persistente, varias URLs en un curl, `--next`, el `--config` como lista, `%{num_connects}` y la trampa de `--no-keepalive` | 15 min |
| [03 — HTTP/2](1-teoria/03-http2.md) | Frames, streams y multiplexación, HPACK, ALPN, h2c, los flags de versión y lo que HTTP/2 no arregla | 15 min |
| [04 — Peticiones en paralelo](1-teoria/04-peticiones-en-paralelo.md) | `-Z`, `--parallel-max`, la espera de curl 7.x y `--parallel-immediate`, el `-w` por transferencia y el código de salida de un lote | 15 min |
| [05 — Medir sin engañarse](1-teoria/05-medir-sin-enganarse.md) | Min, media, mediana, p95 y max, el percentil por rango, cuántas muestras, lo que contamina una medida y latencia frente a carga | 15 min |
| [06 — Caché y peticiones condicionales](1-teoria/06-cache-y-peticiones-condicionales.md) | ETag, `If-None-Match`, el 304, `-z`, las rarezas de `--etag-save` en 7.81, `max-age` y una caché en disco segura | 15 min |
| [07 — HTTP/3 y WebSockets](1-teoria/07-http3-y-websockets.md) | QUIC y `alt-svc`, `--http3` en tu curl, el handshake de WebSocket con 7.81 y desde qué versión curl habla `ws://` | 15 min |
| [08 — Procesos que comparten estado](1-teoria/08-procesos-que-comparten-estado.md) | La carrera de ocho renovaciones, `flock`, comprobar-cerrar-volver a comprobar, y `&` con `wait` | 15 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01 — Una conexión para muchas peticiones](2-practicas/01-una-conexion-para-muchas-peticiones.md) | Las fases de una conexión nueva, el bucle contra la lista, lo que impide reutilizar, `--next`, y la lista de `bench` en un `--config` | 50 min |
| [02 — HTTP/2 y peticiones en paralelo](2-practicas/02-http2-y-peticiones-en-paralelo.md) | ALPN, el h2c que falla, `-Z` en HTTP/1.1 y en HTTP/2, la espera de curl 7.x, `--parallel-max` y `bench` en paralelo | 50 min |
| [03 — Medir sin engañarse](2-practicas/03-medir-sin-enganarse.md) | Veinte muestras, la media que se traga la cola, el p95 de diez, el resumen de `bench`, calentar y el rate limit | 50 min |
| [04 — Caché con ETag y un token compartido](2-practicas/04-cache-con-etag-y-un-token-compartido.md) | Peticiones condicionales a mano, la rareza de `--etag-save`, la caché del toolkit, ocho renovaciones y el cerrojo que las deja en una | 50 min |

### Proyecto

La **capa 9** de tu plataforma: `api-toolkit.sh` se vuelve rápido sin
volverse frágil. `bench ENDPOINT [N]` lanza N peticiones con un solo curl en
paralelo, sin reintentos ni redirects que falseen la medida, y resume min,
media, p95, max, reutilización de conexión y errores. Con `API_CACHE_DIR`,
`get` revalida por ETag y sirve el 304 desde el disco. Y `renovar` coge un
cerrojo para que varios procesos con el mismo token caducado lo renueven una
sola vez. Detalles en [3-proyecto](3-proyecto/README.md).

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
> Haz la práctica 01 antes del TODO 1 del proyecto, la 02 antes del TODO 2,
> la 03 antes del TODO 3, y la 04 antes de los TODOs 4, 5 y 6. Medir a mano
> cómo un segundo se convierte en dos sin `--parallel-immediate` es lo que
> hace obvio por qué `bench` lo pone solo en `http://`; ver ocho renovaciones
> en un log es lo que hace obvio para qué sirve el cerrojo.

---

## 🚦 Qué técnica, según dónde se va el tiempo

Optimizar sin medir es adivinar. Primero `-w` (o `--timing`), después la
técnica que ataca la fase que domina:

| Si domina… | Técnica | Qué ahorra | Dónde se ve |
|---|---|---|---|
| DNS, TCP y TLS en cada petición | Reutilizar la conexión: un curl, muchas URLs | Los handshakes de todas menos la primera | Teoría 02 · Práctica 01 |
| Esperar una respuesta antes de pedir la siguiente | `-Z` con `--parallel-max` | La espera en serie | Teoría 04 · Práctica 02 |
| Muchas conexiones al mismo host | HTTP/2: lo negocia curl solo en `https://` | Conexiones; varias peticiones en una | Teoría 03 · Práctica 02 |
| La transferencia de algo que no ha cambiado | ETag e `If-None-Match` | El cuerpo (no el viaje) | Teoría 06 · Práctica 04 |
| El servidor, en cada petición | Nada de curl: pídele menos (caché) o no lo esperes en serie (paralelo) | — | Teoría 01 |
| Un paquete perdido que frena todo, en redes malas | HTTP/3, si tu curl y el servidor lo tienen | El head-of-line blocking de TCP | Teoría 07 |

---

## 🎩 Trucos y atajos

| Truco | Cómo |
|---|---|
| Saber si una petición abrió conexión o reutilizó | `-w '%{num_connects}\n'`: 1 si abrió, 0 si reutilizó. Con varias URLs, una línea por cada una |
| Muchas peticiones con un solo curl y sin una línea gigante | Un `--config` con pares `url = "..."` y `output = "/dev/null"`, y `curl -K lista.txt`. Con `-K -`, la lista llega por stdin |
| Forzar una conexión nueva para medir el peor caso | `-H 'Connection: close'`. `--no-keepalive` no sirve: apaga las sondas de TCP, no la conexión de HTTP |
| Un GET y un POST sobre la misma conexión | `curl URL1 --next -X POST -d '...' URL2` (7.36.0+). Lo que va antes de `--next` no pasa a la siguiente operación |
| Saber qué versión de HTTP se usó de verdad | `-w '%{http_version}\n'` (7.50.0+): `1.1`, `2` o `3`. En `https://`, curl ofrece h2 por defecto desde la 7.62.0 |
| Paralelo sin perder un segundo en `http://` | `curl -Z --parallel-max 4 --parallel-immediate -K lista.txt` (7.68.0+). En `https://` sin el `immediate`: la espera es lo que multiplexa por HTTP/2 |
| Saber cuál es cada línea de un lote con `-Z` | `-w '%{urlnum} %{http_code}\n'` (7.75.0+): llegan en orden de terminación, no de la línea |
| Contar los errores de un lote | `... -w '%{http_code}\n' \| grep -vc '^[23]'`. El código de salida no lo dice: sin `-f`, un 500 sale con 0 |
| El p95 de una columna de tiempos | `sort -n t.txt \| awk '{t[NR]=$1} END {i=int(NR*0.95); if (i<NR*0.95) i++; print t[i]}'`. Con 10 muestras es el max |
| Revalidar un recurso por ETag | `curl -H 'If-None-Match: "v1"' -w '%{http_code} %{size_download}\n' URL` responde `304 0` si no cambió |
| Ver si una API ofrece HTTP/3 | `curl -sI URL \| grep -i '^alt-svc'`. Para usarlo, tu curl necesita `HTTP3` en `curl --version` |
| Que un cron no arranque dos veces a la vez | `flock -n /ruta/job.lock ./job.sh`: si ya hay uno corriendo, el segundo sale sin hacer nada |

---

## 📌 Entregables

1. `conexiones.md` con las fases de una conexión nueva, el bucle contra la lista con sus tiempos, lo que impide reutilizar y las líneas en bruto de `bench`
2. `paralelo.md` con la negociación ALPN, el h2c fallido, la espera de curl 7.x con y sin `--parallel-immediate`, y las conexiones de `-Z` en HTTP/1.1 y HTTP/2
3. `medidas.md` con la media frente a mediana, p95 y max, la posición del p95 según N, los resúmenes de `bench` y el efecto de calentar
4. `cache-y-cerrojo.md` con la petición condicional a mano, la rareza de `--etag-save`, la caché funcionando y las ocho renovaciones antes y después del cerrojo
5. `api-toolkit.sh` con la capa 9 completa y ningún `TODO` pendiente
6. `bench` lanza las N peticiones con un solo curl en paralelo, sin reintentos, y resume min, media, p95, max, reutilización y errores
7. Con `API_CACHE_DIR`, `get` revalida con `If-None-Match` y sirve el 304 desde una caché con permisos 700
8. Ocho procesos con la sesión caducada la renuevan una sola vez

---

## ✅ Verificación

```bash
./scripts/start.sh
./scripts/verificar-semana.sh 09
```

Las 18 comprobaciones tienen que pasar. Si alguna falla, la pista te dice en qué
TODO del proyecto se arregla.

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [Semana 08 — OAuth2 y autenticación avanzada](../week-08-oauth2_y_autenticacion_avanzada/README.md) | **Semana 09 — HTTP/2, paralelismo y rendimiento** | [Semana 10 — Proyecto final](../week-10-proyecto_final/README.md) |

[← Volver al inicio del bootcamp](../README.md)
