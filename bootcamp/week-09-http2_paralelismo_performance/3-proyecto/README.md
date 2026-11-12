# Proyecto — Capa 9: rápido

> Hasta ahora, `api-toolkit.sh` hacía una petición por llamada y no sabía
> decir cuánto tardaba una API de verdad, solo cuánto había tardado una vez.
> Esta capa le enseña a medir con un solo curl que lanza N peticiones en
> paralelo y reutiliza la conexión, a no descargar lo que ya tiene, y a que
> ocho copias suyas compartan una sesión OAuth2 sin renovarla ocho veces.

---

## 🎯 Objetivo

Que el toolkit **sea rápido sin volverse frágil**. Un subcomando nuevo,
`bench ENDPOINT [N]`, que lanza N GET (10 por defecto) con **un solo curl**,
en paralelo con `-Z` y un techo de `BENCH_PARALELO` (4), sin reintentos ni
redirects que falseen la medida, y resume min, media, p95, max, cuántas
peticiones reutilizaron la conexión y cuántas fallaron. Una caché opcional,
`API_CACHE_DIR`, con la que `get` revalida por ETag y sirve el 304 desde el
disco. Y un cerrojo en `renovar` para que varios procesos con el mismo token
caducado lo renueven una sola vez.

---

## 📦 Qué añade esta capa

La Semana 08 hizo al toolkit responsable de su credencial. Esta capa lo hace
consciente de lo que cuesta cada petición.

| Viene de la Semana 08 | Lo añade esta capa |
|---|---|
| Un curl por llamada, una petición por curl | `bench`: N peticiones en un `--config`, un solo curl, `--parallel` |
| `--timing` mide una petición | `estadisticas`: min, media, p95 por rango, max, reutilización y errores |
| Toda petición GET reintenta y sigue redirects | `construir_red BENCH`: sin `--retry` ni `--location`, para medir |
| `get` descarga siempre el cuerpo entero | Con `API_CACHE_DIR`, `If-None-Match` y el 304 servido desde el disco |
| Dos procesos que renuevan a la vez se pisan (`ponytail:` en `renovar`) | `flock` sobre `SESION.lock` y una segunda comprobación con el cerrojo |
| — | Variables nuevas: `BENCH_PARALELO`, `API_CACHE_DIR` |
| — | Constantes nuevas: `MAX_BENCH=1000`, `MAX_PARALELO=8`, `ESPERA_CERROJO=30` |

Tres decisiones que conviene entender antes de empezar:

- **`bench` mide latencia, no carga.** El techo de 1000 peticiones y el
  paralelo de 4 por defecto (8 como máximo) son deliberados: lo que se pase de ahí es una
  prueba de carga, y eso se hace con otras herramientas y con permiso del
  dueño de la API (teoría 05, apartado 2.6).
- **`--parallel-immediate` solo en `http://`.** Sobre `https://`, la espera de
  curl 7.x es lo que mete todas las peticiones en una conexión HTTP/2. El
  toolkit no elige la versión: deja que ALPN la negocie y lo cuenta.
- **La caché solo revalida.** No interpreta `Cache-Control: max-age`: siempre
  pregunta, y un 304 ahorra el cuerpo, no el viaje. El `ponytail:` de
  `preparar_cache` lo apunta.

Lo que desbloquea: la Semana 10 empaqueta el toolkit y lo prueba en CI; con
`bench` puedes comparar dos versiones contra el laboratorio con los mismos
números.

---

## ✅ Requisitos verificables

`./scripts/verificar-semana.sh 09` comprueba estas dieciocho cosas. Las
descripciones son literales: si una falla, es la que tienes que buscar aquí.

1. El laboratorio TLS responde por HTTP/2
2. api-toolkit.sh existe, es ejecutable y arranca con set -euo pipefail
3. No queda ningun TODO por resolver
4. El User-Agent anuncia la version 0.9.0
5. get sigue imprimiendo el cuerpo JSON por stdout
6. bench lanza todas las peticiones con un solo curl en paralelo
7. bench imprime cuantas peticiones, cuantas en paralelo y la version de HTTP
8. bench imprime min, media, p95 y max en segundos con tres decimales
9. 8 peticiones a /delay/1 con BENCH_PARALELO=4 tardan 2 o 3 segundos, no 8
10. Sobre HTTPS, bench multiplexa por HTTP/2: 7 de 8 peticiones reutilizan la conexion
11. bench cuenta las peticiones fallidas y sale con 1
12. bench no reintenta: 3 peticiones a /status/503 terminan en menos de 2 segundos
13. Con API_CACHE_DIR, el segundo get pregunta con If-None-Match y la API responde 304
14. El get que recibe un 304 imprime el cuerpo guardado
15. El directorio de la cache se crea con permisos 700
16. Una respuesta sin ETag no se guarda en la cache
17. Ocho procesos con el token caducado lo renuevan una sola vez
18. shellcheck -S warning no encuentra nada

---

## 🎨 Criterios de calidad

Lo que el autograding no ve y la rúbrica sí:

- **Un solo curl en `bench`**, nunca un bucle de N curl: el bucle mide N
  handshakes, no la API.
- **La lista va en un `--config`** escrito en `LISTA` (temporal 600), con cada
  URL pasada por `escapar_config`. Ninguna URL en la línea del proceso.
- **`--parallel-immediate` depende del esquema**, y un comentario dice por qué.
- **`estadisticas` no divide entre cero** si no llega ninguna línea, y cuenta
  como error el `000` de una petición sin respuesta.
- **La caché nunca sirve un cuerpo que no corresponde a su ETag.** Se guarda
  el cuerpo antes que el ETag, cada uno con `mktemp` en el mismo directorio y
  `mv`; un corte entre los dos deja un ETag viejo, no uno nuevo.
- **La caché se comprueba como el resto de secretos**: 700 o error, igual que
  el 600 de la sesión y del tarro de cookies.
- **Una respuesta con `Cache-Control: no-store` no se guarda**, aunque traiga
  ETag: la API pide que no quede en disco.
- **El `.lock` nace con 600** aunque la umask de quien ejecuta sea 022.
- **El cerrojo se suelta en todos los caminos**: el que renueva y el que ve
  que otro ya renovó. `flock` lleva `-w`; sin él, un proceso colgado bloquea a
  todos.
- **Sin `flock`, el toolkit sigue funcionando** (macOS): renueva sin cerrojo,
  y el comentario `ponytail:` lo dice.
- **El `--help` sigue siendo verdad**: `bench`, `BENCH_PARALELO` y
  `API_CACHE_DIR` ya están documentados en el starter; si cambias algo,
  cámbialo también ahí.

---

## 💡 Adaptación a tu dominio

Lleva la capa a la API que elegiste en la Semana 01:

| Dominio | HTTP/2 | ETag | Ojo con |
|---|:--:|:--:|---|
| GitHub | Sí | Sí, y un 304 no gasta rate limit | `bench /rate_limit 20` gasta 20 de tus 5000 por hora. `/rate_limit` no los descuenta, el resto sí |
| Open-Meteo | Sí | Depende del endpoint | Es gratuita y sin clave: con más razón, `BENCH_PARALELO` bajo y N pequeño |
| TfL | Sí | No siempre | La `app_key` va en la query: la caché la usa como parte de la clave, y el SHA-256 evita que aparezca en el nombre del archivo |
| TMDB | Sí | Sí, en los recursos de detalle | Su rate limit es por segundo: con paralelo 4 te puedes acercar |

```bash
# ¿Tu API habla HTTP/2 y da ETag?
curl -sS -I --max-time 5 https://<tu-api>/<un-endpoint> \
  -w 'http/%{http_version}\n' | grep -iE '^(etag|cache-control|alt-svc):|^http/'
```

Mide tu API con `bench` **una vez**, con N=20 y el paralelo por defecto, y
apunta el resumen en el `README` de tu dominio. Veinte peticiones a 4 en
paralelo miden latencia, no carga; aun así, lee antes sus condiciones de uso y
su rate limit (la tabla de arriba apunta los más estrictos). No lo repitas en
bucle: para eso está el laboratorio.

---

## 🚦 Cómo entregarlo

**1.** El starter trae la capa 8 resuelta y el esqueleto de la 9, así que
puedes partir de él aunque tu versión de la Semana 08 sea distinta. Edítalo en
su sitio: el autograding comprueba ese archivo.

```bash
cd bootcamp/week-09-http2_paralelismo_performance/3-proyecto/starter/
# Guarda antes tu version de la Semana 08: el cp del paso 4 la sobrescribe.
cp ~/api-toolkit.sh ~/api-toolkit.semana08.sh 2>/dev/null || true
```

**2.** Resuelve los seis TODOs, en orden:

| TODO | Qué | Dónde se practica |
|---|---|---|
| 1 | `construir_args_bench`: la lista en `LISTA` y `ARGS_CURL` | Teoría 02 §2.3; práctica 01, pasos 6 a 8 |
| 2 | `construir_args_bench`: `--parallel`, `--parallel-max` y `--parallel-immediate` solo en `http://` | Teoría 04 §2.2 a §2.4; práctica 02, pasos 3 a 7 |
| 3 | `estadisticas`: el resumen, la reutilización, los errores y el código de salida | Teoría 05 §2.3; práctica 03, pasos 4 a 6 |
| 4 | `preparar_cache`: el directorio 700, la clave y el `If-None-Match` | Teoría 06 §2.6; práctica 04, pasos 4 y 5 |
| 5 | `servir_respuesta`: el 304 desde el disco y guardar cuerpo y ETag | Teoría 06 §2.2 y §2.6; práctica 04, paso 6 |
| 6 | `renovar`: `flock` y la segunda comprobación | Teoría 08 §2.2 y §2.3; práctica 04, pasos 7 a 9 |

El 2 necesita el 1, y el 3 necesita datos que resumir. El 5 sin el 4 no tiene
dónde guardar; el 4 sin el 5 manda `If-None-Match` y no sabe servir el 304.

**3.** Pruébalo a mano, desde la raíz del repositorio:

```bash
T=bootcamp/week-09-http2_paralelismo_performance/3-proyecto/starter/api-toolkit.sh

# En paralelo, sobre HTTP/1.1 y sobre HTTP/2.
time "$T" bench /delay/1 8 | head -1
# 8 peticiones, 4 en paralelo, HTTP/1.1
# real    0m2,04s
BASE_URL=https://localhost:8443 API_CACERT=docs/lab-ca.pem "$T" bench /get 20
# 20 peticiones, 4 en paralelo, HTTP/2
#   min    0.001s
#   media  0.003s
#   p95    0.006s
#   max    0.009s
#   reutilizacion de conexion: 19/20
#   errores: 0

# Los errores cuentan.
"$T" bench /status/503 3 | tail -1; echo "salida: ${PIPESTATUS[0]}"
#   errores: 3
# error: alguna peticion de bench fallo
# salida: 1

# La cache.
export API_CACHE_DIR="$(mktemp -u)"
"$T" get /etag/v1 | jq -r .url
# http://localhost:8080/etag/v1
"$T" --verbose get /etag/v1 2>&1 >/dev/null | grep -E '^< HTTP'
# < HTTP/1.1 304 Not Modified
rm -rf "$API_CACHE_DIR"; unset API_CACHE_DIR
```

La parte del cerrojo se prueba con la función `ocho` de la práctica 04, paso
7: con la capa 9, imprime `1`.

**4.** Pásale el autograding y shellcheck:

```bash
./scripts/verificar-semana.sh 09
shellcheck -S warning "$T"
```

Cuando pase, cópialo a tu sitio de trabajo: `cp "$T" ~/api-toolkit.sh`.

---

## 🧯 Errores comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `laboratorio-http2` falla con `1.1` | Tu curl no tiene HTTP/2 compilado | `curl --version \| grep -o HTTP2`; en Ubuntu 22.04 viene |
| `bench-un-solo-curl` falla | Falta `--parallel` en `ARGS_CURL`, o el TODO 1 lanza un curl por vuelta | TODO 2; un solo `lanzar_curl` en `bench` |
| `bench-en-paralelo` da 8 | No hay `--parallel` | TODO 2 |
| `bench-en-paralelo` da 3 o más con margen justo | Falta `--parallel-immediate` en `http://` | El `case` del TODO 2, antes de copiar `RED_CURL` a `ARGS_CURL` |
| `bench-reutiliza-http2` cuenta 4/8 | `--parallel-immediate` también en `https://` | El `case` solo con `http://*` |
| `bench-estadisticas` cuenta menos de 4 | Formato distinto: un espacio, otra anchura o otros decimales | `printf "  min    %.3fs\n"`: dos espacios, etiqueta y relleno hasta la columna 9 |
| `bench-errores` sale con `0 errores: 3` | Falta `exit (errores > 0)` en el `END` del `awk` | TODO 3 |
| `cache-304` cuenta 0 | No se guarda el ETag, o `preparar_cache` no añade la cabecera | TODO 5 guarda; TODO 4 manda |
| `cache-mismo-cuerpo` falla | Con 304 se imprime `CUERPO`, que está vacío | TODO 5: con 304, el `.cuerpo` guardado |
| `renovar-una-vez` cuenta 8 | Falta la segunda comprobación con el cerrojo | TODO 6: si el token ya no es `VISTO` y no ha caducado, `return 0` |

---

## 🔗 Navegación

| Anterior | Siguiente |
|---|---|
| [Práctica 04 — Caché con ETag y un token compartido](../2-practicas/04-cache-con-etag-y-un-token-compartido.md) | [Rúbrica de evaluación](../rubrica-evaluacion.md) |

[← Volver a la Semana 09](../README.md)
