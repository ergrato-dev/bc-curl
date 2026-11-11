# Proyecto — Capa 6: observable

> Hasta ahora, cuando `api-toolkit.sh` fallaba, te decía el código y una causa
> en una frase. Esta capa le enseña a contar más: la conversación HTTP entera,
> con las credenciales tachadas, el tiempo de cada fase, y una línea de
> métricas por llamada que otro programa puede leer.

---

## 🎯 Objetivo

Hacer que **todas** las llamadas a curl del toolkit pasen por una sola
función, `lanzar_curl`, que ignora el `~/.curlrc` de quien lo ejecuta y filtra
stderr para tachar credenciales y cookies. Sobre ella, tres formas de observar
una petición: `--verbose` (la traza), `--timing` (las fases) y `METRICS_FILE`
(una línea JSON por petición, también cuando falla). Y que el toolkit se
presente al servidor con su propio nombre.

---

## 📦 Qué añade esta capa

La Semana 05 dejó el toolkit preparado para la red hostil. Esta capa no cambia
qué peticiones hace ni cómo: añade **lo que cuenta de ellas**.

| Viene de la Semana 05 | Lo añade esta capa |
|---|---|
| curl se ejecuta en cuatro sitios distintos | Un solo punto, `lanzar_curl`, con `--disable` primero |
| El `~/.curlrc` del usuario se aplica sin que nadie lo sepa | Se ignora: el toolkit hace lo mismo en todas las máquinas |
| El servidor ve `User-Agent: curl/7.81.0` | Ve `api-toolkit/0.6.0` |
| `-w '\n%{http_code}'` | `FORMATO_W`: el código y seis medidas más en la última línea |
| Para depurar, copiar el comando de `--dry-run` y añadir `-v` | `--verbose`, con `Authorization`, la API key y las cookies tachadas |
| — | `--timing`: dns, tcp, tls, servidor, transferencia y total, por stderr |
| — | `METRICS_FILE`: una línea JSON por petición, sin la query string |

Dos decisiones que conviene entender antes de empezar:

- **stdout sigue siendo solo el cuerpo.** La traza y los tiempos van a stderr.
  `./api-toolkit.sh --verbose --timing get /get | jq .` tiene que funcionar
  igual que sin los flags.
- **Un fallo se mide antes de salir.** `fallo_de_red` termina el script; si la
  métrica se escribiera después, una caída no dejaría rastro. Por eso
  `ejecutar` llama a `medir` antes que a `fallo_de_red`.

`download` no se mide: su `-w` sigue siendo solo `%{http_code}` (está marcado
con un comentario `ponytail:` en el código). `--timing` con `download` es un
error de uso; `METRICS_FILE`, simplemente no recibe la línea.

Lo que desbloquea: la Semana 07 apoya en `lanzar_curl` y en la línea de
`FORMATO_W` sus reintentos y `fetch-all`, y la 09 medirá con `FORMATO_W` lo que
gana el paralelismo. Sin esta capa, la 09 no tiene con qué comparar.

---

## ✅ Requisitos verificables

`./scripts/verificar-semana.sh 06` comprueba estas dieciocho cosas. Las
descripciones son literales: si una falla, es la que tienes que buscar aquí.

1. El laboratorio responde en el puerto 8080
2. api-toolkit.sh existe, es ejecutable y arranca con set -euo pipefail
3. No queda ningun TODO por resolver
4. La capa 5 sigue funcionando: get valida con API_CACERT y sigue los redirects
5. Un ~/.curlrc con include no cambia la salida del toolkit
6. El toolkit se presenta al servidor como api-toolkit/VERSION
7. --timing imprime por stderr las seis medidas: dns, tcp, tls, servidor, transferencia y total
8. Sobre http, la fase tls dura cero y no sale negativa
9. Sobre https, la fase tls dura mas de cero
10. Con --verbose y --timing, stdout sigue siendo solo el cuerpo JSON
11. Con METRICS_FILE, cada peticion anade exactamente una linea JSON
12. La linea de metricas lleva el metodo, el endpoint y el codigo HTTP, tambien si es un 4xx
13. El endpoint de las metricas no incluye la query string
14. Un fallo de red tambien deja su linea de metricas, con codigo 0
15. --verbose muestra por stderr la peticion que se envia
16. Con --verbose y AUTH_MODE=bearer, el token sale tachado en la traza
17. Con --verbose y AUTH_MODE=apikey, la clave sale tachada en la traza
18. shellcheck -S warning no encuentra nada

---

## 🎨 Criterios de calidad

Lo que el autograding no ve y la rúbrica sí:

- **El código de salida de curl sobrevive al filtro.** `lanzar_curl` pasa
  stderr por `redactar_traza`; si devuelve el código del filtro en vez del de
  curl, todos los fallos de red parecen éxitos. Ningún check lo prueba
  directamente: lo notarás porque `fallo_de_red` deja de llamarse.
- **Las cookies también se tachan**, en las tres formas en que aparecen:
  `> Cookie:`, `< Set-Cookie:` y `* Added cookie`. Pruébalo con `COOKIE_JAR`
  y `--verbose` sobre `/cookies/set?sesion=...`.
- **La comparación de nombres de header no distingue mayúsculas.** Un servidor
  puede devolver `set-cookie` en minúsculas (HTTP/2 lo hace siempre).
- **El temporal de la traza se crea con 600 y se borra en `limpiar`.** Contiene
  la traza sin tachar.
- **`fases` acota todo a cero**, también la fase servidor de una petición que
  no llegó a conectar.
- **El JSON de métricas lo construye `jq`**, con `--arg` y `--argjson`, no un
  `printf` con comillas: un endpoint con comillas rompería la línea.
- **Comentarios que dicen por qué**: por qué `--disable` primero, por qué la
  query string fuera, por qué se mide antes de salir.

---

## 💡 Adaptación a tu dominio

Lleva la capa a la API que elegiste en la Semana 01:

| Dominio | Qué tachar además | Qué medir con interés | Ojo con |
|---|---|---|---|
| GitHub | Nada nuevo: `Authorization` ya está | La fase servidor de `/search`, que tiene su propio rate limit | El header `X-GitHub-Request-Id`: no es secreto y es lo que pide soporte |
| Open-Meteo | No tiene credencial | La transferencia: respuestas grandes con `hourly=` | La query string lleva las coordenadas; cortarla agrupa bien por endpoint |
| TfL | `app_key` va en la **query string** | La fase tls desde fuera de Europa | `redactar_traza` no toca la línea de petición: la clave sale en `> GET /...?app_key=` |
| TMDB | `Authorization` con v4; `api_key` en la query con v3 | La fase servidor de `/discover` | Lo mismo que TfL si usas v3: preferible la v4 con header |

```bash
# ¿Que User-Agent ve tu API? Algunas lo exigen (GitHub rechaza peticiones sin el)
./api-toolkit.sh --verbose get /<un-endpoint-de-tu-api> 2> traza.txt >/dev/null
grep -E '^> (User-Agent|Authorization|<tu-header>)' traza.txt

# ¿Donde se va el tiempo?
METRICS_FILE=mi-api.jsonl ./api-toolkit.sh --timing get /<un-endpoint-de-tu-api> >/dev/null
```

Si tu API lleva la clave en la query string, apúntalo en tu `metricas.md`: es
la limitación conocida de `redactar_traza` (comentario `ponytail:` en el
código), y la razón por la que la Semana 08 prefiere tokens en header.

---

## 🚦 Cómo entregarlo

**1.** El starter trae la capa 5 resuelta, así que puedes partir de él aunque
tu versión de la Semana 05 sea distinta. Edítalo en su sitio: el autograding
comprueba ese archivo.

```bash
cd bootcamp/week-06-output_debug_configuracion/3-proyecto/starter/
# Guarda antes tu version de la Semana 05: el cp de abajo la sobrescribe.
cp ~/api-toolkit.sh ~/api-toolkit.semana05.sh 2>/dev/null || true
```

**2.** Resuelve los seis TODOs. El orden recomendado no es el numérico:

| TODO | Qué | Dónde se practica |
|---|---|---|
| 1 | `lanzar_curl`: `--disable` primero, stderr al temporal, filtro, código de curl | Teoría 01 §3.3 y 07 §2.4; práctica 03, paso 4 |
| 6 | `redactar_traza`: tachar los headers de credencial y las cookies | Teoría 05 §2.4 y §3.1; práctica 01, paso 6 |
| 2 | El User-Agent `api-toolkit/VERSION` | Práctica 03, paso 2 |
| 3 | `FORMATO_W`: el código y seis medidas, en orden | Teoría 03 §3.1 y 04 §2.1 |
| 4 | `fases`: de instantes a duraciones, sin negativos | Teoría 04 §2.3; práctica 02, pasos 5 y 7 |
| 5 | `medir`: `--timing` por stderr y la línea de `METRICS_FILE` | Práctica 02, paso 9; práctica 04, pasos 1, 2 y 7 |

El 1 y el 6 van juntos: con el 1 hecho y el 6 sin hacer, `--verbose` enseña el
token en claro. No pruebes `--verbose` con una credencial real hasta tener los
dos.

**3.** Pruébalo a mano, desde la raíz del repositorio:

```bash
T=bootcamp/week-06-output_debug_configuracion/3-proyecto/starter/api-toolkit.sh
export CA="$PWD/docs/lab-ca.pem"

# La traza, con el token tachado. stdout sigue siendo JSON.
AUTH_MODE=bearer API_TOKEN=token-de-prueba "$T" --verbose get /bearer 2> traza.txt | jq -r .authenticated
# true
grep -E '^> (GET|Authorization|User-Agent)' traza.txt
# > GET /bearer HTTP/1.1
# > User-Agent: api-toolkit/0.6.0
# > Authorization: <REDACTADO>

# Las fases, por HTTP y por HTTPS.
"$T" --timing get /get >/dev/null
# tiempos: dns=0.000021s tcp=0.000127s tls=0.000000s servidor=0.000755s transferencia=0.000031s total=0.000934s
BASE_URL=https://localhost:8443 API_CACERT="$CA" "$T" --timing get /get >/dev/null
# tiempos: dns=0.000019s tcp=0.000131s tls=0.003271s servidor=0.002604s transferencia=0.000060s total=0.006085s

# Una linea por peticion, tambien la que falla.
METRICS_FILE=m.jsonl "$T" get '/get?api_key=x' >/dev/null
METRICS_FILE=m.jsonl BASE_URL=http://127.0.0.1:9 "$T" get /get 2>/dev/null; echo "salida: $?"
# salida: 69
jq -c '{metodo, endpoint, codigo, total}' m.jsonl
# {"metodo":"GET","endpoint":"/get","codigo":200,"total":0.000934}
# {"metodo":"GET","endpoint":"/get","codigo":0,"total":0.000155}
rm -f m.jsonl traza.txt
```

**4.** Pásale el autograding y shellcheck:

```bash
./scripts/verificar-semana.sh 06
shellcheck -S warning "$T"
```

Cuando pase, cópialo a tu sitio de trabajo: `cp "$T" ~/api-toolkit.sh`.

---

## 🧯 Errores comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `toolkit-ignora-curlrc` falla aunque pusiste `-q` | Va detrás de otro argumento, o solo en una de las llamadas | `curl --disable "$@"` dentro de `lanzar_curl`, y que nadie más llame a curl |
| Tras el TODO 1, los fallos de red salen con 0 | `lanzar_curl` devuelve el código de `redactar_traza` | Guarda `rc` de curl antes de filtrar y haz `return "$rc"` |
| `--verbose` no enseña nada | stderr va al temporal y nadie lo lee | `redactar_traza < "$TRAZA" >&2` después de curl |
| `toolkit-timing-sin-tls` da `tls=-0.000113s` | Restas `time_appconnect - time_connect` sin mirar el cero | `fin_tls = (tls > 0) ? tls : con` |
| `toolkit-metricas-fallo-de-red` falla con `jq: invalid JSON text` | `--argjson codigo 000`: no es un número JSON | `$((10#$codigo))` |
| `toolkit-metricas-una-por-peticion` da 20 | `jq` sin `-c`: diez líneas por objeto | `jq -cn` |
| `toolkit-metricas-campos` no encuentra la línea del 418 | `medir` se llama después de `salir_por_codigo`, que hace `exit` | `medir` primero |
| `toolkit-verbose-tacha-apikey` falla | Tachas `X-API-Key` a fuego en vez de `API_KEY_HEADER` | Compara con el valor de la variable, en minúsculas |
| `toolkit-stdout-limpio` falla | La línea de `-w` se imprime con el cuerpo, o `--timing` escribe en stdout | Separa la última línea en `ejecutar`; `printf ... >&2` en `medir` |
| shellcheck: `VERSION appears unused` | Borraste el `shellcheck disable` de `VERSION` antes de resolver el TODO 2 | Resuelve el TODO 2; después, el comentario `disable` sobra y puedes borrarlo |

---

## 🔗 Navegación

| Anterior | Siguiente |
|---|---|
| [Práctica 04 — Métricas de un endpoint](../2-practicas/04-metricas-de-un-endpoint.md) | [Rúbrica de evaluación](../rubrica-evaluacion.md) |

[← Volver a la Semana 06](../README.md)
