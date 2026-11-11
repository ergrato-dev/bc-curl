# Paginación

> Ninguna API seria devuelve diez mil elementos de una vez: devuelve treinta y
> te dice dónde están los siguientes. Un script que no lo sabe procesa la
> primera página, termina con 0, y da por completo un listado al que le falta
> el 99 %.

![Diagrama de las cuatro formas de paginar: número de página (page y per_page), desplazamiento (offset y limit), cursor opaco en el cuerpo (next_cursor) y header Link de RFC 8288 (rel next, prev, first, last); debajo, el bucle común a todas: pedir, guardar, buscar la siguiente, parar cuando no hay, con dos frenos marcados en rojo: un máximo de páginas y no salir nunca del host de la API](../0-assets/05-paginacion.svg)

## 🎯 Objetivos

- Reconocer los cuatro estilos de paginación y cómo se para cada uno
- Leer un header `Link` y sacar la URL `rel="next"`
- Escribir el bucle que recorre todas las páginas y junta el resultado
- Poner los dos frenos que impiden que el bucle se convierta en un problema

---

## 1. Qué problema resuelve

```bash
export CA="$PWD/docs/lab-ca.pem"
curl -sS --cacert "$CA" https://localhost:8443/paginas | jq length
# 3
```

Tres elementos. Parece el listado entero, y no hay nada en el cuerpo que diga
lo contrario. La pista está en los headers:

```bash
curl -sS --cacert "$CA" -D - -o /dev/null https://localhost:8443/paginas | grep -i '^link'
# link: <https://localhost:8443/paginas?page=2>; rel="next", <https://localhost:8443/paginas?page=3>; rel="last"
```

Hay una página 2, y la última es la 3. Una API que pagina con `Link`, como la
de GitHub, **no avisa en el cuerpo**: si no lees los headers, no sabes que
falta algo.

---

## 2. Cómo funciona

### 2.1 Cuatro estilos

| Estilo | La petición | Cómo sabes que hay más | Cuándo paras | Ejemplo |
|---|---|---|---|---|
| Número de página | `?page=3&per_page=50` | Llega una página llena | Llega una página vacía o incompleta | Muchas APIs internas |
| Desplazamiento | `?offset=100&limit=50` | Igual | Igual | APIs sobre SQL |
| Cursor | `?cursor=eyJpZCI6...` | El cuerpo trae `next_cursor` | `next_cursor` es `null` o falta | Slack, Stripe |
| Header `Link` | La URL que te dan | El header trae `rel="next"` | No hay `rel="next"` | GitHub, GitLab |

Los dos primeros te dejan construir la URL. Los dos últimos te la dan hecha, y
**hay que usar la que te dan**: el cursor es opaco (no se decodifica ni se
fabrica), y la URL del `Link` puede llevar parámetros que no conoces.

### 2.2 El header `Link`

Lo define RFC 8288. Una lista de enlaces separados por comas, cada uno con su
URL entre `< >` y su relación en `rel`:

```
link: <https://localhost:8443/paginas?page=1>; rel="prev",
      <https://localhost:8443/paginas?page=3>; rel="next",
      <https://localhost:8443/paginas?page=1>; rel="first",
      <https://localhost:8443/paginas?page=3>; rel="last"
```

(Va en una sola línea; aquí está partido para leerlo.)

Tres detalles que rompen un parser ingenuo:

- **El orden no está garantizado.** `next` puede ir primero, o tercero detrás
  de `prev` y `first`. Quedarse con la primera URL del header es un error que
  funciona en la página 1 y falla en la 2.
- **No siempre están todos.** La primera página no lleva `prev`; la última no
  lleva `next`. La ausencia de `next` es justo la condición de parada.
- **El nombre del header llega en minúsculas sobre HTTP/2.** `link:`, no
  `Link:`. Compara sin mayúsculas.

### 2.3 Cuándo parar

Cada estilo tiene **su** condición, y ninguna es "hasta que falle":

| Estilo | Para cuando |
|---|---|
| Página u offset | La página llega vacía, o con menos elementos que `per_page` |
| Cursor | `next_cursor` es `null`, vacío o no está |
| `Link` | El header no trae `rel="next"`, o no hay header |

"Hasta que falle" significa interpretar un 500 a mitad del listado como el
final, y dar por bueno un listado cortado.

### 2.4 Los dos frenos

El bucle hace peticiones mientras la API diga que hay más. Eso es confiar en
la API dos veces:

**Que termine.** Un `rel="next"` que apunta a la página actual (un bug del
servidor, un proxy que reescribe mal) convierte el script en un bucle
infinito contra la API. El freno es un máximo de páginas: si se supera, el
script falla en vez de seguir.

**Que no salga de la API.** Cada petición del bucle lleva tu credencial. Si
un `rel="next"` apunta a otro host, seguirlo es mandarle el token a ese host.
curl quita el `Authorization` al seguir un redirect a otro host (Semana 05),
pero aquí no hay redirect: **eres tú** quien pide la URL nueva, con todas las
opciones. El freno es comprobar que la URL empieza por la base de la API,
**con la `/` final**: sin ella, `https://api.ejemplo.com.otro.net/` pasaría por
`https://api.ejemplo.com`.

---

## 3. Cómo se usa

### 3.1 Sacar el `rel="next"` de un `Link`

```bash
siguiente() {
  tr ',' '\n' | awk '/rel="next"/ {
    if (match($0, /<[^>]*>/)) print substr($0, RSTART + 1, RLENGTH - 2)
  }'
}

curl -sS --cacert "$CA" -D cab.txt -o pagina.json 'https://localhost:8443/paginas?page=2'
tr -d '\r' < cab.txt | grep -i '^link:' | cut -d' ' -f2- | siguiente
# https://localhost:8443/paginas?page=3
```

`tr ',' '\n'` pone cada enlace en su línea; `awk` elige la del `rel="next"` y
saca lo que hay entre `< >`. Partir por comas falla si una URL lleva una coma
dentro; para las APIs habituales basta, y el toolkit lo deja anotado.

`%header{link}` en el `-w` lo haría sin `-D`, pero es 7.84+: en 7.81 imprime el
texto literal `%header{link}` (Semana 06).

### 3.2 El bucle completo

```bash
base=https://localhost:8443
url="$base/paginas"
n=0
: > todas.jsonl

while [ -n "$url" ]; do
  n=$((n + 1))
  [ "$n" -le 100 ] || { echo "mas de 100 paginas" >&2; exit 1; }
  case "$url" in
    "$base"/*) ;;
    *) echo "el Link sale de la API: $url" >&2; exit 1 ;;
  esac

  curl -sS --fail-with-body --max-time 10 --retry 3 --cacert "$CA" \
    -D cab.txt -o pagina.json "$url"
  jq -c . pagina.json >> todas.jsonl

  url=$(tr -d '\r' < cab.txt | grep -i '^link:' | cut -d' ' -f2- | siguiente || true)
  echo "pagina $n -> ${url:-fin}" >&2
done

jq -c -s 'add // []' todas.jsonl
# pagina 1 -> https://localhost:8443/paginas?page=2
# pagina 2 -> https://localhost:8443/paginas?page=3
# pagina 3 -> fin
# [{"id":1},{"id":2},{"id":3},{"id":4},{"id":5},{"id":6},{"id":7}]
```

Lo que hace cada pieza:

- **Una página por línea** en `todas.jsonl`, y un `jq -s` al final (teoría
  04). Nada sale por stdout hasta tener todas: si la página 2 falla, quien
  lea la salida no recibe un listado a medias.
- **`|| true`** en la búsqueda del siguiente: en la última página el `grep` o
  el `awk` no encuentran nada, y con `pipefail` eso abortaría.
- **El progreso va a stderr.** stdout es solo el resultado.
- **`--retry 3`**: una página que da 503 se reintenta, en vez de tirar las
  anteriores (teoría 06).

### 3.3 Con cursor

Sin laboratorio para este estilo, el patrón es el mismo con otra forma de
encontrar la siguiente:

```bash
cursor=""
n=0
while :; do
  n=$((n + 1))
  [ "$n" -le 100 ] || { echo "mas de 100 paginas" >&2; exit 1; }
  curl -sS --fail-with-body --max-time 10 --retry 3 -o pagina.json \
    "$BASE_URL/items?limit=100${cursor:+&cursor=$cursor}"
  jq -c '.items' pagina.json >> todas.jsonl
  cursor=$(jq -r '.next_cursor // empty' pagina.json)
  [ -n "$cursor" ] || break
done
```

`// empty` convierte el `null` del final en nada, y nada en una cadena vacía
que cierra el bucle. Si el cursor puede llevar caracteres especiales, pásalo
con `--data-urlencode` y `-G` en vez de pegarlo en la URL (Semana 02).

### 3.4 Contra una API real

GitHub pagina con `Link` y acepta `per_page` hasta 100:

```bash
curl -sS --fail-with-body --max-time 10 -D - -o /dev/null \
  'https://api.github.com/orgs/curl/repos?per_page=5' | grep -i '^link'
# link: <https://api.github.com/organizations/16928085/repos?per_page=5&page=2>; rel="next",
#       <https://api.github.com/organizations/16928085/repos?per_page=5&page=5>; rel="last"
```

Fíjate en la ruta: pediste `/orgs/curl/repos` y el `next` apunta a
`/organizations/16928085/repos`. Un script que fabricara la siguiente URL
sumando `&page=2` a la suya funcionaría hoy por casualidad; el que usa la que
le dan funciona siempre. Y con `per_page=100`, las mismas peticiones se
dividen entre veinte: con un rate limit de por medio (teoría 07), eso importa.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Procesar solo la primera página | El listado parece completo y no lo es | Leer el `Link`, o el cursor |
| Tomar la primera URL del `Link` | El orden de los `rel` no está garantizado | Buscar `rel="next"` |
| Fabricar la URL de la página siguiente con un cursor o un `Link` | Pierdes parámetros que no conoces | Usar la URL que da la API |
| `while true` sin máximo de páginas | Un `next` que apunta a sí mismo no termina nunca | Contador y límite |
| Seguir un `next` a cualquier host | Le mandas la credencial | `case "$url" in "$BASE"/*)` |
| Imprimir cada página según llega | Un fallo a mitad deja una salida a medias que parece buena | Acumular y escribir al final |
| Offset sobre datos que cambian | Un elemento nuevo desplaza todo: duplicados o huecos | Cursor, si la API lo ofrece |

---

## 5. Trucos

- **`-D - -o /dev/null`** enseña solo los headers de la respuesta a un GET,
  sin pedir un `HEAD` que la API quizá no acepte.
- **`rel="last"`** dice cuántas páginas hay sin recorrerlas: útil para una
  barra de progreso, o para comprobar antes de empezar que no son diez mil.
- **`per_page` al máximo** que acepte la API: menos peticiones, menos rate
  limit, menos páginas que pueden fallar.

---

## 📚 Recursos Adicionales

- [RFC 8288 — Web Linking](https://www.rfc-editor.org/rfc/rfc8288)
- [GitHub — Using pagination in the REST API](https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api)
- [Slack — Pagination](https://api.slack.com/apis/pagination), el estilo
  cursor contado por quien lo usa

---

## ✅ Checklist de Verificación

- [ ] Distingues los cuatro estilos y la condición de parada de cada uno
- [ ] Sacas el `rel="next"` de `/paginas?page=2`, donde no va el primero
- [ ] Tu bucle junta las siete entradas de `/paginas` en una sola lista
- [ ] Tu bucle para ante `/paginas?page=fuera` y ante `/paginas?page=bucle`
