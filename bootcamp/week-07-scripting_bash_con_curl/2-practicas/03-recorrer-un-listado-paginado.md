# Práctica 03 — Recorrer un listado paginado

> **Duración**: 50 min · **Entregables**: `paginar.sh`

Vas a recorrer `/paginas`, el listado paginado del laboratorio, como recorrerías
el de GitHub: leyendo el header `Link`, eligiendo el `rel="next"` aunque no
vaya primero y juntando todas las páginas en una sola lista. Después le
pondrás los dos frenos: no salir de la API y no pasar de un máximo de páginas.
El resultado es `paginar.sh`, el `fetch-all` del proyecto en pequeño.

**Antes de empezar**, desde la raíz del repositorio:

```bash
./scripts/start.sh
export CA="$PWD/docs/lab-ca.pem"
mkdir -p ~/bc-curl-trabajo/semana-07/p3 && cd ~/bc-curl-trabajo/semana-07/p3
bash    # los pasos estan escritos para bash
```

`/paginas` vive en `https://localhost:8443`. Tiene tres páginas (`?page=1` a
`?page=3`) y dos trampas: `?page=fuera` y `?page=bucle`.

---

## Paso 1: Ver el `Link`

**Por qué**: el cuerpo no dice que haya más páginas. Lo dice un header.

**Comando**:

```bash
curl -sS --cacert "$CA" https://localhost:8443/paginas; echo
curl -sS --cacert "$CA" -D - -o /dev/null https://localhost:8443/paginas | grep -i '^link'
```

**Verifica**:

```bash
# [{"id":1},{"id":2},{"id":3}]
# link: <https://localhost:8443/paginas?page=2>; rel="next", <https://localhost:8443/paginas?page=3>; rel="last"
```

`-D - -o /dev/null` enseña solo los headers. El nombre llega en minúsculas
porque `:8443` habla HTTP/2. Apunta en un comentario de `paginar.sh` cuántas
páginas dice `rel="last"` que hay.

---

## Paso 2: Página a página, a mano

**Por qué**: antes de automatizar, mira qué cambia de una página a otra.

**Comando**:

```bash
for p in 1 2 3 9; do
  ids=$(curl -sS --cacert "$CA" "https://localhost:8443/paginas?page=$p" | jq -c '[.[].id]')
  link=$(curl -sS --cacert "$CA" -D - -o /dev/null "https://localhost:8443/paginas?page=$p" \
    | tr -d '\r' | grep -i '^link:' || true)
  echo "page=$p ids=$ids"
  echo "  ${link:-(sin Link)}"
done
```

**Verifica**:

```bash
# page=1 ids=[1,2,3]
#   link: <https://localhost:8443/paginas?page=2>; rel="next", <https://localhost:8443/paginas?page=3>; rel="last"
# page=2 ids=[4,5,6]
#   link: <https://localhost:8443/paginas?page=1>; rel="prev", <https://localhost:8443/paginas?page=3>; rel="next", ...
# page=3 ids=[7]
#   link: <https://localhost:8443/paginas?page=2>; rel="prev", <https://localhost:8443/paginas?page=1>; rel="first"
# page=9 ids=[]
#   (sin Link)
```

Tres cosas que el bucle tiene que respetar: en la página 2 el `next` va
**segundo**; en la 3 hay `Link` pero **sin** `next`, y es el final; y una página
que no existe da 200 con una lista vacía, no un 404.

---

## Paso 3: Sacar el `rel="next"`

**Por qué**: es el TODO 4. Y el error típico, quedarse con la primera URL,
funciona en la página 1 y falla en la 2.

**Comando**:

```bash
link_de() {
  curl -sS --cacert "$CA" -D - -o /dev/null "https://localhost:8443/paginas?page=$1" \
    | tr -d '\r' | grep -i '^link:' | cut -d' ' -f2- || true
}

siguiente() {
  tr ',' '\n' | awk '/rel="next"/ {
    if (match($0, /<[^>]*>/)) print substr($0, RSTART + 1, RLENGTH - 2)
  }'
}

echo "ingenuo, page=2: $(link_de 2 | grep -o '<[^>]*>' | head -1)"
echo "next, page=1:    $(link_de 1 | siguiente)"
echo "next, page=2:    $(link_de 2 | siguiente)"
echo "next, page=3:    [$(link_de 3 | siguiente)]"
```

**Verifica**:

```bash
# ingenuo, page=2: <https://localhost:8443/paginas?page=1>
# next, page=1:    https://localhost:8443/paginas?page=2
# next, page=2:    https://localhost:8443/paginas?page=3
# next, page=3:    []
```

El ingenuo vuelve a la página 1 desde la 2: un bucle infinito en dos pasos.
`siguiente` parte el header por comas, se queda con el trozo del
`rel="next"` y saca lo que hay entre `< >`. En la página 3 no imprime nada, y
esa cadena vacía es la que cerrará el bucle.

---

## Paso 4: El bucle, sin frenos

**Por qué**: primero que funcione el camino normal.

**Comando**:

```bash
url=https://localhost:8443/paginas
while [ -n "$url" ]; do
  curl -sS --fail-with-body --max-time 10 --cacert "$CA" -D cab.txt -o pagina.json "$url"
  echo "$(jq -c '[.[].id]' pagina.json) <- $url"
  url=$(tr -d '\r' < cab.txt | grep -i '^link:' | cut -d' ' -f2- | siguiente || true)
done
```

**Verifica**:

```bash
# [1,2,3] <- https://localhost:8443/paginas
# [4,5,6] <- https://localhost:8443/paginas?page=2
# [7] <- https://localhost:8443/paginas?page=3
```

El `|| true` importa: en un script con `pipefail`, el `grep` de una página sin
`Link` haría abortar el bucle en vez de terminarlo. Ahora cambia la primera
línea por `url='https://localhost:8443/paginas?page=fuera'` y ejecútalo otra
vez:

```bash
# [1] <- https://localhost:8443/paginas?page=fuera
# curl: (6) Could not resolve host: otra-api.invalid
# [1] <- https://otra-api.invalid/paginas?page=2
```

Dos problemas en tres líneas. El bucle ha **intentado** pedir una URL de otro
host. Y como curl falló, `pagina.json` sigue teniendo la página anterior, y el
`echo` la presenta como si viniera de `otra-api.invalid`. Sin `set -e` ni
comprobar el código de curl, un dato viejo pasa por nuevo.

---

## Paso 5: Primer freno, no salir de la API

**Por qué**: es el TODO 5. Con `?page=fuera`, el bucle del paso 4 ha intentado
pedir `https://otra-api.invalid/...`. Si llevara un `Authorization`, se lo
habría mandado a ese host.

**Comando**:

```bash
BASE=https://localhost:8443

misma_api() {
  case "$1" in
    "$BASE"/*) echo "ok:    $1" ;;
    *)         echo "fuera: $1" ;;
  esac
}

misma_api https://localhost:8443/paginas?page=2
misma_api https://otra-api.invalid/paginas?page=2
misma_api https://localhost:8443.otra-api.invalid/paginas
misma_api http://localhost:8443/paginas
```

**Verifica**:

```bash
# ok:    https://localhost:8443/paginas?page=2
# fuera: https://otra-api.invalid/paginas?page=2
# fuera: https://localhost:8443.otra-api.invalid/paginas
# fuera: http://localhost:8443/paginas
```

Quita la `/` del patrón (`"$BASE"*`) y repite: la tercera pasa por buena. Esa
`/` es la diferencia entre "dentro de la API" y "empieza por las mismas
letras". La cuarta queda fuera por el esquema: un `next` que baja a `http`
mandaría la credencial en claro.

---

## Paso 6: Juntar las páginas en `paginar.sh`

**Por qué**: es el TODO 6. Nada sale por stdout hasta tener la última página.

**Comando**: crea `paginar.sh`:

```bash
#!/usr/bin/env bash
# paginar.sh RUTA — recorre un listado paginado con Link y lo imprime entero
set -euo pipefail

BASE="${BASE:-https://localhost:8443}"
MAX_PAGINAS="${MAX_PAGINAS:-100}"

cab=$(mktemp); pagina=$(mktemp); todas=$(mktemp)
trap 'rm -f "$cab" "$pagina" "$todas"' EXIT

siguiente() {
  tr ',' '\n' | awk '/rel="next"/ {
    if (match($0, /<[^>]*>/)) print substr($0, RSTART + 1, RLENGTH - 2)
  }'
}

url="${BASE}$1"
n=0
while [ -n "$url" ]; do
  n=$((n + 1))
  [ "$n" -le "$MAX_PAGINAS" ] || { echo "mas de $MAX_PAGINAS paginas" >&2; exit 1; }
  case "$url" in
    "$BASE"/*) ;;
    *) echo "el Link sale de la API: $url" >&2; exit 1 ;;
  esac

  curl -sS --fail-with-body --max-time 10 --retry 3 --cacert "$CA" \
    -D "$cab" -o "$pagina" "$url"
  if [ ! -s "$pagina" ] || ! jq -e 'type == "array"' "$pagina" > /dev/null; then
    echo "la pagina $n no es una lista" >&2; exit 1
  fi
  jq -c . "$pagina" >> "$todas"

  url=$(tr -d '\r' < "$cab" | grep -i '^link:' | cut -d' ' -f2- | siguiente || true)
  echo "pagina $n -> ${url:-fin}" >&2
done

jq -s 'add // []' "$todas"
```

```bash
chmod +x paginar.sh
shellcheck paginar.sh
./paginar.sh /paginas | jq -c '[.[].id]'
./paginar.sh '/paginas?page=fuera'; echo "salida: $?"
```

**Verifica**:

```bash
# pagina 1 -> https://localhost:8443/paginas?page=2
# pagina 2 -> https://localhost:8443/paginas?page=3
# pagina 3 -> fin
# [1,2,3,4,5,6,7]
# pagina 1 -> https://otra-api.invalid/paginas?page=2
# el Link sale de la API: https://otra-api.invalid/paginas?page=2
# salida: 1
```

En el segundo caso, stdout está **vacío**: la página 1 se descargó bien, pero
el listado no se completó y no se imprime nada. Compruébalo con
`./paginar.sh '/paginas?page=fuera' 2>/dev/null | wc -c`. Y `./paginar.sh /get`
falla con "la pagina 1 no es una lista": `/get` devuelve un objeto.

---

## Paso 7: Segundo freno, el máximo de páginas

**Por qué**: `?page=bucle` devuelve un `next` que apunta a sí mismo. Sin
contador, el script no termina nunca.

**Comando**:

```bash
MAX_PAGINAS=5 ./paginar.sh '/paginas?page=bucle'; echo "salida: $?"
time ./paginar.sh '/paginas?page=bucle' 2>/dev/null; echo "salida: $?"
```

**Verifica**:

```bash
# pagina 1 -> https://localhost:8443/paginas?page=bucle
# ...
# pagina 5 -> https://localhost:8443/paginas?page=bucle
# mas de 5 paginas
# salida: 1
# real  0m4,0s
# salida: 1
```

Con el máximo por defecto, cien peticiones en unos segundos contra el
laboratorio. Contra una API real con rate limit, son cien peticiones de tu
cupo tiradas: elige el máximo con eso en mente. El toolkit usa
`MAX_PAGINAS=100`.

---

## Paso 8 (opcional): Contra GitHub

**Por qué**: comprobar que tu parser aguanta un `Link` real, con rutas que no
son las que pediste.

**Comando**:

```bash
curl -sS --fail-with-body --max-time 10 -D - -o /dev/null \
  'https://api.github.com/orgs/curl/repos?per_page=5' \
  | tr -d '\r' | grep -i '^link:' | cut -d' ' -f2- | siguiente
```

**Verifica**:

```bash
# https://api.github.com/organizations/16928085/repos?per_page=5&page=2
```

Pediste `/orgs/curl/repos` y la siguiente es `/organizations/16928085/repos`.
Por eso se usa la URL que da la API, nunca una fabricada. Sin token tienes 60
peticiones por hora: no lances aquí `paginar.sh` con `per_page=1`.

---

## ✅ Resultado

- [ ] He visto el `Link` de cada página y dónde va el `rel="next"`
- [ ] Mi `siguiente` elige el `next` en la página 2 y no imprime nada en la 3
- [ ] `paginar.sh /paginas` imprime las siete entradas en una sola lista
- [ ] `paginar.sh` se niega a seguir `?page=fuera` y deja stdout vacío
- [ ] `paginar.sh` para en `MAX_PAGINAS` con `?page=bucle`
- [ ] `shellcheck paginar.sh` no dice nada

```bash
./scripts/verificar-semana.sh 07
```

Esta práctica prepara los TODOs 4, 5 y 6: `siguiente_pagina`, `misma_api` y el
bucle de `fetch_all`.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| `/paginas` responde 404 | El Caddyfile del laboratorio es anterior a la Semana 07 | Actualiza el repositorio y `docker compose restart tls` |
| El bucle no termina en la página 3 | `siguiente` imprime algo en la página 3: quizá busca `next` sin el `rel=` | El patrón es `/rel="next"/` |
| El bucle salta de la 2 a la 1 | Te quedas con la primera URL del `Link` | Paso 3 |
| `grep: ... Link` no encuentra nada | Buscas `Link:` con mayúscula y HTTP/2 lo manda en minúsculas | `grep -i` |
| El script aborta en la última página sin mensaje | Falta el `\|\| true` y `pipefail` aborta por el `grep` | Paso 4 |
| `paginar.sh` imprime `null` con una ruta vacía | `jq -s 'add'` sin el `// []` | `jq -s 'add // []'` |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 02 — Reintentos sin sorpresas](02-reintentos-sin-sorpresas.md) | [Práctica 04 — Backoff a mano](04-backoff-a-mano.md) |
