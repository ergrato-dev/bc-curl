# Proyecto — Capa 7: robusto

> Hasta ahora, `api-toolkit.sh` hacía bien una petición. Esta capa lo prepara
> para vivir dentro de otro script: que lo que salga por stdout sea siempre
> un dato bueno, que el código de salida diga si merece la pena repetir, que
> un reintento no mezcle respuestas, y que pueda recorrer un listado entero
> sin salirse de la API.

---

## 🎯 Objetivo

Que el toolkit **falle cuando debe fallar, y diga cómo**. El cuerpo y los
headers de cada respuesta van a archivos, y un reintento ya no pega cuerpos
en stdout. Un error nunca sale por stdout. Un 429, un 502, un 503 o un 504
salen con 75 y el `Retry-After` en el mensaje. Y un subcomando nuevo,
`fetch-all`, sigue el header `Link` página a página, con dos frenos, e imprime
el listado completo o nada.

---

## 📦 Qué añade esta capa

La Semana 06 hizo el toolkit observable. Esta capa cambia **qué pasa cuando
algo va mal**.

| Viene de la Semana 06 | Lo añade esta capa |
|---|---|
| El cuerpo se captura de stdout junto al `-w` | `peticion`: el cuerpo, a `--output "$CUERPO"`; los headers, a `--dump-header "$CABECERAS"`; stdout solo lleva el `-w` |
| Con `--retry`, los cuerpos de cada intento se concatenan | Un solo cuerpo, el del último intento |
| Los headers de la respuesta no se leen | `cabecera NOMBRE`, del último bloque de `CABECERAS` |
| El cuerpo de un 4xx/5xx sale por stdout | `exigir_exito`: el cuerpo de un error va a stderr |
| Un 429 o un 503 salen con 1, como un 404 | Salen con 75 (EX_TEMPFAIL), con el `Retry-After` en el mensaje |
| `construir_args` recibe el endpoint | Recibe la URL entera: `fetch-all` pide la que trae el `Link` |
| — | `fetch-all ENDPOINT`: `siguiente_pagina`, `misma_api`, `MAX_PAGINAS` y `fetch_all` |

Tres decisiones que conviene entender antes de empezar:

- **El toolkit no lleva un bucle de backoff propio.** `GET`, `PUT` y `DELETE`
  ya llevan `--retry` desde la Semana 05, y curl hace backoff y respeta
  `Retry-After`. Lo que añade esta capa es qué pasa **después** de los
  reintentos: salir con 75 para que quien llama decida.
- **`fetch-all` no imprime nada hasta el final.** Cada página va, en una línea,
  al temporal `PAGINAS`; al terminar, `jq -s 'add // []'` las junta. Si la
  página 3 falla, stdout queda vacío, nunca con las dos primeras.
- **El 500 sigue saliendo con 1.** Si fuera pasajero, el `--retry` del `GET`
  ya lo habría superado.

`download` no cambia: tiene su propio `--output` y su `--fail` desde la Semana
04. Lo único que hereda es el 75 de `salir_por_codigo` ante un 503.

Lo que desbloquea: la Semana 08 necesita distinguir un 401 (77) de un fallo
temporal (75) para saber cuándo renovar el token OAuth2, y la 09 mide y
paraleliza peticiones que ya no mezclan respuestas al reintentar.

---

## ✅ Requisitos verificables

`./scripts/verificar-semana.sh 07` comprueba estas dieciocho cosas. Las
descripciones son literales: si una falla, es la que tienes que buscar aquí.

1. El laboratorio responde en el puerto 8080
2. El laboratorio TLS sirve /paginas con un header Link
3. api-toolkit.sh existe, es ejecutable y arranca con set -euo pipefail
4. No queda ningun TODO por resolver
5. get sigue imprimiendo el cuerpo JSON por stdout
6. La capa 6 sigue funcionando: --timing imprime las fases por stderr
7. Un 404 sale con 1
8. El cuerpo de una respuesta de error no sale por stdout
9. Un 429 sale con 75 (EX_TEMPFAIL)
10. Un 503 sale con 75
11. El mensaje de un 429 incluye el Retry-After de la respuesta
12. Tras los reintentos de un GET, solo queda el cuerpo del ultimo intento
13. fetch-all /paginas imprime los siete elementos de las tres paginas en una sola lista
14. fetch-all sigue el rel="next" aunque el Link traiga antes prev y first
15. fetch-all no sigue un Link a otro host: sale con 1, sin nada en stdout, y nombra el host
16. Un Link que apunta a si mismo no cuelga fetch-all: sale con 1, stdout vacio, y el mensaje nombra el limite de 100 paginas
17. fetch-all de algo que no es una lista JSON sale con 1, stdout vacio, y el mensaje dice que no es una lista
18. shellcheck -S warning no encuentra nada

---

## 🎨 Criterios de calidad

Lo que el autograding no ve y la rúbrica sí:

- **`cabecera` no distingue mayúsculas en el nombre que recibe.** `cabecera
  Retry-After` y `cabecera retry-after` dan lo mismo, sobre HTTP/1.1 y HTTP/2.
- **El valor de un header se corta en el primer `:`**, no en todos: una fecha
  o una URL llevan `:` dentro.
- **`misma_api` compara con la `/` final.** `https://localhost:8443.otra/`
  no pasa por `https://localhost:8443`. Pruébalo a mano: ningún check lo hace.
- **Los temporales nuevos (`CUERPO`, `CABECERAS`, `PAGINAS`) se crean con 600
  y se borran en `limpiar`.** `CUERPO` puede llevar datos personales;
  `CABECERAS`, un `Set-Cookie`.
- **`fetch-all` mide cada página** si hay `METRICS_FILE`: una línea por página,
  con el endpoint sin la query string.
- **El `--help` documenta `fetch-all` y el 75.** El contrato vive ahí (teoría
  08, apartado 3.3).
- **Comentarios que dicen por qué**: por qué el cuerpo a un archivo, por qué el
  último bloque, por qué la `/`, por qué no imprimir hasta el final.

---

## 💡 Adaptación a tu dominio

Lleva la capa a la API que elegiste en la Semana 01:

| Dominio | Cómo pagina | Rate limit | Ojo con |
|---|---|---|---|
| GitHub | `Link` con `rel="next"`; `per_page` hasta 100 | 60/h sin token, 5000/h con token; `x-ratelimit-*` | El `next` cambia de ruta: `/orgs/x/repos` pasa a `/organizations/N/repos`, dentro de la misma `BASE_URL` |
| Open-Meteo | No pagina | Generoso, sin headers de cupo | `fetch-all` no aplica: la respuesta es un objeto, y fallará con "no es una lista" |
| TfL | Casi ninguna ruta pagina | Por `app_key`; 429 si te pasas | Sin `rel="next"`, `fetch-all` hace una sola página |
| TMDB | `page` y `total_pages` en el cuerpo, sin `Link` | 429 si te pasas | El listado va en `.results`, no en la raíz: `fetch-all` lo rechaza como "no es una lista" |

```bash
# ¿Pagina tu API con Link?
./api-toolkit.sh --verbose get /<un-listado-de-tu-api> 2>&1 >/dev/null | grep -i '^< link'

# ¿Cuanto cupo te queda?
./api-toolkit.sh --verbose get /<un-endpoint> 2>&1 >/dev/null | grep -i '^< x-ratelimit'
```

Si tu API pagina por el cuerpo (TMDB) o con cursor, `fetch-all` no te sirve tal
cual. Apúntalo en tu `paginar.sh` de la práctica 03: adaptarlo es un buen
ejercicio, y la Semana 10 te deja hacerlo dentro del toolkit.

---

## 🚦 Cómo entregarlo

**1.** El starter trae la capa 6 resuelta, así que puedes partir de él aunque
tu versión de la Semana 06 sea distinta. Edítalo en su sitio: el autograding
comprueba ese archivo.

```bash
cd bootcamp/week-07-scripting_bash_con_curl/3-proyecto/starter/
# Guarda antes tu version de la Semana 06: el cp del paso 4 la sobrescribe.
cp ~/api-toolkit.sh ~/api-toolkit.semana06.sh 2>/dev/null || true
```

**2.** Resuelve los seis TODOs. El orden recomendado no es el numérico:

| TODO | Qué | Dónde se practica |
|---|---|---|
| 3 | `exigir_exito`: el cuerpo de un error a stderr; y el 75 en `salir_por_codigo` | Teoría 08 §2.2 y §2.3; práctica 01, pasos 3 y 8 |
| 1 | `peticion`: `--output "$CUERPO"` y `--dump-header "$CABECERAS"` | Teoría 06 §2.4; práctica 02, pasos 3 y 4 |
| 2 | `cabecera`: el valor de un header en el último bloque | Práctica 02, pasos 5 y 6 |
| 4 | `siguiente_pagina`: la URL del `rel="next"` | Teoría 05 §2.2 y §3.1; práctica 03, paso 3 |
| 5 | `misma_api`: la URL tiene que empezar por `"$BASE_URL/"` | Teoría 05 §2.4; práctica 03, paso 5 |
| 6 | `fetch_all`: el bucle, los dos frenos, la lista y el `jq -s` | Teoría 04 §2.3 y §3.3; práctica 03, pasos 6 y 7 |

El 2 necesita el 1: sin `--dump-header`, `CABECERAS` está vacío y `cabecera`
no tiene qué leer. El mensaje del 429 no lleva `Retry-After` hasta que estén
los dos.

**3.** Pruébalo a mano, desde la raíz del repositorio:

```bash
T=bootcamp/week-07-scripting_bash_con_curl/3-proyecto/starter/api-toolkit.sh
export BASE_URL=https://localhost:8443 API_CACERT="$PWD/docs/lab-ca.pem"

# Un listado entero, y un Link que sale de la API.
"$T" fetch-all /paginas | jq -c '[.[].id]'
# [1,2,3,4,5,6,7]
"$T" fetch-all '/paginas?page=fuera'; echo "salida: $?"
# error: el Link rel="next" sale de la API: https://otra-api.invalid/paginas?page=2
# salida: 1

# Un 429: tres intentos, un solo cuerpo, por stderr, y 75.
"$T" get /limitado > datos.json; echo "salida: $?"
# {"error":"demasiadas peticiones"}
# error: la API respondio 429; Retry-After: 1
# salida: 75
wc -c < datos.json
# 0

# Una linea de metricas por pagina.
METRICS_FILE=m.jsonl "$T" fetch-all /paginas > /dev/null
jq -c '{endpoint, codigo}' m.jsonl
# {"endpoint":"/paginas","codigo":200}
# {"endpoint":"/paginas","codigo":200}
# {"endpoint":"/paginas","codigo":200}
rm -f datos.json m.jsonl
unset BASE_URL API_CACERT
```

**4.** Pásale el autograding y shellcheck:

```bash
./scripts/verificar-semana.sh 07
shellcheck -S warning "$T"
```

Cuando pase, cópialo a tu sitio de trabajo: `cp "$T" ~/api-toolkit.sh`.

---

## 🧯 Errores comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `laboratorio-paginas` falla | Tu Caddyfile es anterior a la Semana 07 | Actualiza el repositorio y `docker compose restart tls` |
| Tras el TODO 1, `get /get` no imprime nada | Pusiste `--output` pero `ejecutar` sigue imprimiendo lo que capturó de stdout | `ejecutar` hace `cat "$CUERPO"`; borra la línea del `printf` que copiaba el cuerpo |
| `toolkit-reintentos-un-cuerpo` da 3 | El cuerpo sigue saliendo por stdout | `--output "$CUERPO"` en la llamada a `lanzar_curl` (TODO 1) |
| `toolkit-429-retry-after` falla con el TODO 2 hecho | Falta `--dump-header`, o `cabecera` compara con mayúsculas | TODO 1; y `tolower` en los dos lados |
| `Retry-After:  1`, con dos espacios | El valor conserva el espacio tras los `:` | `sub(/^[ \t]+/, "", valor)` |
| `toolkit-fetch-all-rel-next` da `[4,5,6,1,2,3,...]` | `siguiente_pagina` se queda con la primera URL del `Link` | Busca el trozo con `rel="next"` |
| `toolkit-fetch-all-junta` da `null` | `jq -s 'add'` sin el `// []`, o `PAGINAS` vacío | `jq -c . "$CUERPO" >> "$PAGINAS"` en cada vuelta |
| `toolkit-fetch-all-bucle` tarda y falla | No hay contador, o se comprueba después de pedir | Cuenta y compara con `MAX_PAGINAS` antes de cada petición |
| `toolkit-503-sale-75` falla y el 429 pasa | Solo pusiste el 429 en `salir_por_codigo` | `429\|502\|503\|504) exit 75 ;;` |
| shellcheck: `MAX_PAGINAS appears unused` | Borraste el `shellcheck disable` antes de resolver el TODO 6 | Resuelve el TODO 6; después, el comentario sobra |

---

## 🔗 Navegación

| Anterior | Siguiente |
|---|---|
| [Práctica 04 — Backoff a mano](../2-practicas/04-backoff-a-mano.md) | [Rúbrica de evaluación](../rubrica-evaluacion.md) |

[← Volver a la Semana 07](../README.md)
