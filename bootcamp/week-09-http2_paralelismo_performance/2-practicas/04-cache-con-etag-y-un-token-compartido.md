# Práctica 04 — Caché con ETag y un token compartido

> **Duración**: 50 min · **Entregables**: `cache-y-cerrojo.md`

Dos formas de que el toolkit haga menos trabajo. La primera, no descargar lo
que ya tiene: `get` guarda cada respuesta con su ETag y la siguiente vez
pregunta con `If-None-Match` (TODOs 4 y 5). La segunda, no renovar ocho veces
el mismo token cuando ocho procesos lo encuentran caducado a la vez: un
cerrojo con `flock` y una segunda comprobación (TODO 6).

**Antes de empezar**, desde la raíz del repositorio, con los TODOs 1 a 3
resueltos:

```bash
./scripts/start.sh
export TK="$PWD/bootcamp/week-09-http2_paralelismo_performance/3-proyecto/starter/api-toolkit.sh"
mkdir -p ~/bc-curl-trabajo/semana-09/p4 && cd ~/bc-curl-trabajo/semana-09/p4
umask 077    # la cache y la sesion guardan respuestas y tokens: nacen con 600
bash    # los pasos estan escritos para bash; si tu terminal es zsh, abre un bash
```

---

## Paso 1: Un ETag a mano

**Por qué**: antes de automatizarlo, hay que ver la conversación: el servidor
etiqueta la versión, el cliente la devuelve, y un 304 sin cuerpo dice "sigue
valiendo" (teoría 06, apartados 2.1 y 2.2). `/etag/{etag}` del laboratorio
responde con el ETag que pongas en la ruta.

**Comando**:

```bash
curl -s -D- -o /dev/null http://localhost:8080/etag/v1 | grep -i '^etag'
curl -s -o /dev/null -w '%{http_code} %{size_download}\n' -H 'If-None-Match: "v1"' http://localhost:8080/etag/v1
curl -s -o /dev/null -w '%{http_code} %{size_download}\n' -H 'If-None-Match: "v0"' http://localhost:8080/etag/v1
```

**Verifica**:

```bash
# Etag: "v1"
# 304 0
# 200 292
```

Las comillas son parte del ETag: prueba `If-None-Match: v1` sin ellas y
apunta en `cache-y-cerrojo.md` qué responde.

---

## Paso 2: `--etag-save`, `--etag-compare` y su rareza

**Por qué**: curl guarda y manda el ETag por ti desde la 7.68.0. Pero el ETag
queda separado del cuerpo, y un archivo vacío se manda como `""` (teoría 06,
apartado 2.4).

**Comando**:

```bash
for i in 1 2; do
  curl -s -o datos.json --etag-compare e.txt --etag-save e.txt \
    -w '%{http_code} ' http://localhost:8080/etag/v1; wc -c < datos.json
done
cat e.txt

rm -f e.txt
curl -sv -o /dev/null --etag-compare e.txt --etag-save e.txt \
  http://localhost:8080/cache 2>&1 | grep -E '^> If-None|^< HTTP'
```

**Verifica**:

```bash
# 200 292
# 304 292
# "v1"
# > If-None-Match: ""
# < HTTP/1.1 304 Not Modified
```

El 304 no toca `datos.json`. Pero en la segunda parte, la primera petición
de todas ya recibe un 304: curl creó `e.txt` vacío, mandó `""`, y `/cache`
responde 304 a cualquier `If-None-Match`. No tienes nada guardado y el
servidor cree que sí. Apúntalo: es la razón de que el toolkit guarde el ETag
él mismo.

---

## Paso 3: Por fecha, con `-z`

**Por qué**: la alternativa al ETag es `Last-Modified` e `If-Modified-Since`,
con resolución de un segundo. curl la manda con `-z` (teoría 06, apartado
2.3).

**Comando**:

```bash
curl -s -D- -o /dev/null http://localhost:8080/cache | grep -iE '^(last-modified|etag)'
curl -s -o /dev/null -w '%{http_code}\n' -z 'Wed, 01 Jan 2020 00:00:00 GMT' http://localhost:8080/cache
curl -s -D- -o /dev/null http://localhost:8080/cache/60 | grep -i cache-control
```

**Verifica**:

```bash
# Etag: 5468752c...
# Last-Modified: Thu, 12 Nov 2026 01:56:04 UTC
# 304
# Cache-Control: public, max-age=60
```

`/cache` da las dos cosas. Y `/cache/60` dice "no preguntes en 60 segundos",
que el toolkit no aprovecha: solo revalida. Apunta en `cache-y-cerrojo.md`
qué ahorra cada una.

---

## Paso 4: El TODO 4, preparar la caché

**Por qué**: la caché guarda respuestas que pueden ser autenticadas: es tan
sensible como el token. Directorio 700, nombre de cada entrada el SHA-256 de
la URL, e `If-None-Match` solo si hay ETag **y** cuerpo (teoría 06, apartado
2.6).

**Comando**: resuelve el TODO 4. Después:

```bash
export API_CACHE_DIR="$PWD/cache"
"$TK" get /etag/v1 | jq -r .url
stat -c '%a' cache 2>/dev/null || stat -f '%Lp' cache
ls cache | wc -l
chmod 755 cache && "$TK" get /etag/v1; echo "exit $?"; chmod 700 cache
```

**Verifica**:

```bash
# http://localhost:8080/etag/v1
# 700
# 0
# error: /home/tu-usuario/bc-curl-trabajo/semana-09/p4/cache es accesible a otros usuarios. Arreglalo con: chmod 700 "..."
# exit 1
```

La caché está vacía: guardar es trabajo de `servir_respuesta` (TODO 5).

---

## Paso 5: El 304 que no se puede servir

**Por qué**: para ver el `If-None-Match` sin el TODO 5, escribe tú la entrada
a mano. Y mira lo que pasa cuando la API dice 304 y el script imprime el
cuerpo de la respuesta, que está vacío.

**Comando**:

```bash
k=$(printf '%s' http://localhost:8080/etag/v1 | sha256sum | cut -d' ' -f1)
printf '"v1"\n' > "cache/$k.etag"
echo '{"guardado": true}' > "cache/$k.cuerpo"
"$TK" --verbose get /etag/v1 2>traza.txt | wc -c
grep -E '^[<>] (HTTP|If-None)' traza.txt
```

**Verifica**:

```bash
# 0
# > If-None-Match: "v1"
# < HTTP/1.1 304 Not Modified
```

En macOS, `shasum -a 256` en vez de `sha256sum`. Cero bytes por stdout y
salida 0: un `get` que "funciona" y no devuelve nada. Eso arregla el TODO 5.

---

## Paso 6: El TODO 5, servir la respuesta

**Por qué**: con un 304, el cuerpo es el guardado. Con un 200 que trae ETag,
se guarda: primero el cuerpo, después el ETag, cada uno con `mv`, para que un
corte entre los dos deje un ETag viejo y nunca uno nuevo con el cuerpo viejo.

**Comando**: resuelve el TODO 5. Después:

```bash
rm -rf cache
"$TK" get /etag/v1 | jq -r .url
"$TK" get /etag/v1 | jq -r .url
ls cache | sed 's/^.\{56\}/.../'
"$TK" get /get > /dev/null; ls cache | wc -l
"$TK" --verbose get /etag/v2 2>&1 >/dev/null | grep -E '^[<>] (HTTP|If-None)'
"$TK" get '/response-headers?ETag=%22x1%22&Cache-Control=no-store' > /dev/null; ls cache | wc -l
unset API_CACHE_DIR; "$TK" get /get | jq -r .url
```

**Verifica**:

```bash
# http://localhost:8080/etag/v1
# http://localhost:8080/etag/v1
# ...4a830440.cuerpo
# ...4a830440.etag
# 2
# < HTTP/1.1 200 OK
# 4
# http://localhost:8080/get
```

La segunda salió del disco. `/get` no trae ETag y no se guarda. `/etag/v2`
es otra URL, otra entrada, y no manda `If-None-Match` (los archivos pasan a
4). La respuesta con `no-store` trae ETag y no se guarda: sigue habiendo 4.
Sin `API_CACHE_DIR`,
`get` sigue como siempre. Copia la salida en `cache-y-cerrojo.md`.

---

## Paso 7: Ocho procesos, un token caducado

**Por qué**: cuando varios procesos comparten la sesión OAuth2, todos ven el
token caducado a la vez y todos lo renuevan. Con un refresh token que rota,
siete de ocho fallarían (teoría 08, apartado 1).

**Comando**:

```bash
export OAUTH_CLIENT_ID=api-toolkit OAUTH_CLIENT_SECRET=secreto-de-laboratorio
export OAUTH_SESSION_FILE="$PWD/sesion.json"
caducar() { local t; t=$(mktemp) && jq '.expires_at = 0' sesion.json > "$t" && cat "$t" > sesion.json; rm -f "$t"; }
ocho() {
  : > errores.log
  for i in 1 2 3 4 5 6 7 8; do
    AUTH_MODE=oauth BASE_URL=http://localhost:8081/default "$TK" get /userinfo > /dev/null 2>> errores.log &
  done
  wait; grep -c renovado errores.log
}
"$TK" auth login; caducar; ocho
```

**Verifica**:

```bash
# sesion guardada en /home/tu-usuario/bc-curl-trabajo/semana-09/p4/sesion.json
# 8
```

Ocho renovaciones para un token. Apunta en `cache-y-cerrojo.md` por qué el
`mv` atómico de `guardar_sesion` no lo evita.

---

## Paso 8: El TODO 6, el cerrojo

**Por qué**: el cerrojo pone a los ocho en fila; la segunda comprobación, con
el cerrojo en la mano, hace que el segundo y siguientes vean el token nuevo y
no renueven (teoría 08, apartados 2.2 y 2.3).

**Comando**: resuelve el TODO 6. El esqueleto:

```bash
if command -v flock >/dev/null 2>&1; then
  exec 9>>"${OAUTH_SESSION_FILE}.lock"
  flock -w "$ESPERA_CERROJO" 9 || error "..."
  # si visto no esta vacio, el token de la sesion ya no es visto, y la
  # sesion no ha caducado: exec 9>&- y return 0
fi
```

Después:

```bash
caducar; ocho
caducar; ocho
```

**Verifica**:

```bash
# 1
# 1
```

Una renovación por caducidad, siempre. Si sale 8, falta la segunda
comprobación; si sale un número entre 1 y 8 que cambia, falta el cerrojo o no
se coge.

---

## Paso 9: El cerrojo, visto desde fuera

**Por qué**: un cerrojo que nadie suelta bloquearía el toolkit para siempre.
`-w` pone el límite, y el kernel lo suelta cuando el proceso muere (teoría 08,
apartado 2.2).

**Comando**:

```bash
caducar
flock sesion.json.lock sleep 3 &
sleep 0.2
time (AUTH_MODE=oauth BASE_URL=http://localhost:8081/default "$TK" get /userinfo | jq -r .sub)
wait
flock -n sesion.json.lock true && echo libre
ls -l sesion.json.lock | cut -c1-10
```

**Verifica**:

```bash
# aviso: token OAuth2 renovado
# api-toolkit
# real    0m2,9s
# libre
# -rw-------
```

El toolkit esperó a que el `sleep` soltara el cerrojo y después renovó: el
token seguía siendo el caducado. El `.lock` se queda, vacío y con 600. Apunta
en `cache-y-cerrojo.md` por qué no se borra.

---

## ✅ Resultado

- [ ] He hecho una petición condicional a mano y he visto el 304 sin cuerpo
- [ ] Sé por qué `--etag-save` no basta: el ETag va separado del cuerpo
- [ ] Mi `preparar_cache` (TODO 4) crea la caché con 700 y manda `If-None-Match` solo con ETag y cuerpo
- [ ] Mi `servir_respuesta` (TODO 5) sirve el 304 desde el disco y guarda el cuerpo antes que el ETag
- [ ] Mi `renovar` (TODO 6) renueva una sola vez con ocho procesos a la vez

```bash
./scripts/verificar-semana.sh 09
```

Esta práctica cierra los TODOs 4, 5 y 6. Las 18 comprobaciones deberían pasar.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| `sha256sum: command not found` | macOS | `shasum -a 256`; el toolkit ya prueba los dos en `sha256_de` |
| La caché nace con 755 | Falta el `umask 077` del subshell en `mkdir` | `(umask 077 && mkdir -p "$API_CACHE_DIR")` |
| El segundo `get` no manda `If-None-Match` | El ETag no se guardó: `cabecera etag` vacío, o guardas solo con 304 | Guarda con `CODIGO` 200 y ETag no vacío |
| `get` imprime vacío tras un 304 | `servir_respuesta` imprime `CUERPO` también con 304 | Con 304, `cat "${CACHE_BASE}.cuerpo"` y `return 0` |
| `ocho` imprime 0 | La sesión no tenía `expires_at = 0`, o falta `auth login` | `jq .expires_at sesion.json` |
| `flock: command not found` | macOS | `brew install flock`; sin él, el toolkit renueva sin cerrojo |
| `ocho` se queda colgado | `flock` sin `-w`, y un proceso no soltó el cerrojo | `flock -w "$ESPERA_CERROJO" 9` y `exec 9>&-` en los dos caminos de salida |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 03 — Medir sin engañarse](03-medir-sin-enganarse.md) | [Proyecto — Capa 9](../3-proyecto/README.md) |
