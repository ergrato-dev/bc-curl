# Práctica 03 — Caducidad y el 401 inesperado

> **Duración**: 50 min · **Entregables**: `caducidad.md`

Vas a darle al toolkit un sentido del tiempo. Primero, guardar la sesión con
`expires_at` en un archivo 600 escrito de forma atómica (TODO 2). Después,
renovar antes de que caduque, con margen (TODO 3). Y por último, el caso que
el reloj no ve: un token que la API rechaza antes de su `exp`, que se arregla
renovando y repitiendo **una sola vez** (TODO 5).

**Antes de empezar**, desde la raíz del repositorio, con el TODO 1 resuelto
(práctica 01):

```bash
./scripts/start.sh
export TK="$PWD/bootcamp/week-08-oauth2_y_autenticacion_avanzada/3-proyecto/starter/api-toolkit.sh"
export OAUTH=http://localhost:8081/default
export OAUTH_CLIENT_ID=api-toolkit OAUTH_CLIENT_SECRET=secreto-de-laboratorio
mkdir -p ~/bc-curl-trabajo/semana-08/p3 && cd ~/bc-curl-trabajo/semana-08/p3
umask 077    # todo lo que crees en esta terminal nace con 600: aqui hay tokens
bash    # los pasos estan escritos para bash; si tu terminal es zsh, abre un bash
```

Varios pasos cambian un campo de la sesión para fingir que pasó el tiempo.
Esta función lo hace sin tocar los permisos del archivo:

```bash
# retocar FILTRO_JQ: aplica el filtro a la sesion. El temporal nace con 600
# (mktemp), y cat > conserva el 600 de la sesion; mv no.
retocar() {
  local t
  t=$(mktemp) && jq "$1" ~/.bc-curl-session > "$t" && cat "$t" > ~/.bc-curl-session
  rm -f "$t"
}
```

---

## Paso 1: `expires_in` no dice cuándo

**Por qué**: `expires_in: 3599` cuenta desde que el servidor respondió. Una
hora después, el número sigue diciendo 3599 y ya no significa nada. Hay que
convertirlo en un instante en el momento de recibirlo (teoría 06, apartado
2.1).

**Comando**:

```bash
cfg=$(umask 077 && mktemp)
printf '%s\n' "user = \"$OAUTH_CLIENT_ID:$OAUTH_CLIENT_SECRET\"" \
  'data-urlencode = "grant_type=client_credentials"' > "$cfg"
curl -sS --max-time 10 --config "$cfg" -o r.json "$OAUTH/token"

jq --argjson ahora "$(date +%s)" '{expires_in, expires_at: ($ahora + .expires_in)}' r.json
date -d "@$(jq --argjson ahora "$(date +%s)" '$ahora + .expires_in' r.json)" +%H:%M:%S
rm -f "$cfg" r.json
```

**Verifica**:

```bash
# {
#   "expires_in": 3599,
#   "expires_at": 1794450418
# }
# 15:46:58
```

Tus números serán otros: la hora es la de ahora más una hora. `date -d @` es
de GNU; en macOS, `date -r`. Apunta en `caducidad.md` por qué `expires_at`
se puede comparar con `date +%s` en cualquier proceso y en cualquier momento,
y `expires_in` no.

---

## Paso 2: El TODO 2, guardar la sesión

**Por qué**: `guardar_sesion` es lo que convierte una respuesta del servidor
en una sesión: `expires_at`, permisos 600, y escritura atómica (teoría 08,
apartados 2.2 a 2.4). Sin ella no hay `auth login`.

**Comando**: resuelve el TODO 2. Después:

```bash
"$TK" auth login
ls -l ~/.bc-curl-session | cut -c1-10
jq 'del(.access_token)' ~/.bc-curl-session
echo "quedan $(( $(jq .expires_at ~/.bc-curl-session) - $(date +%s) )) s"
ls ~/.bc-curl-session.* 2>/dev/null | wc -l
```

**Verifica**:

```bash
# sesion guardada en /home/tu-usuario/.bc-curl-session
# -rw-------
# {
#   "token_type": "Bearer",
#   "expires_in": 3599,
#   "expires_at": 1794450418
# }
# quedan 3599 s
# 0
```

El último 0 dice que no queda ningún temporal `~/.bc-curl-session.XXXXXX`:
`mv` lo convirtió en la sesión. Si queda alguno, tu TODO 2 no lo renombra o no
lo borra cuando `jq` falla.

Comprueba también que `auth login` no imprime el token por ningún lado. Es la
comprobación `toolkit-login-sin-token`:

```bash
"$TK" auth login 2>&1 | grep -c eyJ
# 0
```

---

## Paso 3: El TODO 3, renovar antes de caducar

**Por qué**: un token que caduca en diez segundos puede llegar muerto al
servidor. Con un margen de 30 segundos (`MARGEN_CADUCIDAD`), el toolkit lo
renueva antes de la petición (teoría 06, apartado 2.2). Es
`toolkit-renueva-caducado`.

**Comando**: resuelve el TODO 3. Después, finge que a la sesión le quedan 10
segundos, y luego 100:

```bash
retocar ".expires_at = $(( $(date +%s) + 10 ))"
AUTH_MODE=oauth BASE_URL="$OAUTH" "$TK" get /userinfo | jq -r .sub
"$TK" auth status

retocar ".expires_at = $(( $(date +%s) + 100 ))"
AUTH_MODE=oauth BASE_URL="$OAUTH" "$TK" get /userinfo | jq -r .sub
"$TK" auth status
```

**Verifica**:

```bash
# aviso: token OAuth2 renovado
# api-toolkit
# activa: expira en 3599 s, sub=api-toolkit, refresh_token: no
# api-toolkit
# activa: expira en 99 s, sub=api-toolkit, refresh_token: no
```

Con 10 segundos, dentro del margen: renueva, y la sesión vuelve a tener una
hora. Con 100, fuera: usa el token que hay. Prueba con 30 y con 31 y apunta en
`caducidad.md` cuál renueva y por qué.

Y una sesión sin `expires_at`:

```bash
retocar 'del(.expires_at)'
AUTH_MODE=oauth BASE_URL="$OAUTH" "$TK" get /userinfo >/dev/null
# aviso: token OAuth2 renovado
```

Sin dato, la sesión cuenta como caducada: mejor pedir de más que fallar a
ciegas.

---

## Paso 4: Sin renovar de más

**Por qué**: el antipatrón opuesto es renovar en cada petición "por si
acaso", que dobla el tráfico y castiga al servidor de tokens. Con una sesión
vigente, el toolkit no debe tocar `/token`.

**Comando**:

```bash
"$TK" auth login 2>/dev/null
for i in 1 2 3; do
  AUTH_MODE=oauth BASE_URL="$OAUTH" "$TK" --verbose get /userinfo 2>&1 \
    | grep -c 'POST /default/token'
done
```

**Verifica**:

```bash
# 0
# 0
# 0
```

Tres peticiones, ninguna al servidor de tokens. Si ves un 1, tu
`sesion_caducada` devuelve verdadero siempre: revisa la comparación.

---

## Paso 5: El 401 que el reloj no ve

**Por qué**: el `exp` es lo que el servidor prometió, no lo que va a cumplir.
Un token revocado, o firmado con una clave que el servidor ya rotó, vale para
el reloj y no para la API (teoría 06, apartado 2.5). El simulador no rota sus
claves, así que lo imitas estropeando la firma: el token sigue pareciendo
vigente, y la API lo rechaza.

**Comando**:

```bash
retocar '.access_token |= (.[:-4] + "AAAA")'
"$TK" auth status

cabecera=$(umask 077 && mktemp)
jq -j .access_token ~/.bc-curl-session | sed 's/^/header = "Authorization: Bearer /; s/$/"/' > "$cabecera"
curl -sS --max-time 5 --config "$cabecera" -o /dev/null -w '%{http_code}\n' "$OAUTH/userinfo"
rm -f "$cabecera"

AUTH_MODE=oauth BASE_URL="$OAUTH" "$TK" get /userinfo; echo "salida: $?"
```

**Verifica** (con el TODO 5 todavía sin resolver):

```bash
# activa: expira en 3580 s, sub=api-toolkit, refresh_token: no
# 401
# error: la API respondio 401
# salida: 77
```

`auth status` dice "activa": lee `expires_at` y el payload, y los dos están
intactos. Solo la API, que comprueba la firma, sabe que el token no vale.
Apunta en `caducidad.md` tres causas reales de un 401 antes del `exp`.

---

## Paso 6: El TODO 5, renovar y repetir

**Por qué**: ante un 401 con OAuth2, lo razonable es renovar una vez y
repetir la petición una vez. Un 401 significa que la API rechazó la petición
antes de procesarla: repetirla es seguro aunque sea un `POST`. Es
`toolkit-reintenta-401`.

**Comando**: resuelve el TODO 5 en `ejecutar`: si `CODIGO` es 401 y
`AUTH_MODE` es `oauth`, `renovar`, `construir_config` y `peticion` otra vez.
Después, el mismo token estropeado:

```bash
retocar '.access_token |= (.[:-4] + "AAAA")'
AUTH_MODE=oauth BASE_URL="$OAUTH" "$TK" get /userinfo | jq -r .sub; echo "salida: ${PIPESTATUS[0]}"
```

**Verifica**:

```bash
# aviso: token OAuth2 renovado
# api-toolkit
# salida: 0
```

`construir_config` hace falta porque el `--config` de la petición lleva el
header con el token **viejo**: renovar cambia la sesión, no el archivo que
curl va a leer.

---

## Paso 7: Una vez, y solo una

**Por qué**: si el 401 no es del token sino del cliente (sin permisos para
ese recurso), renovar no lo arregla. Un bucle "401, renovar, 401, renovar"
convierte un error de permisos en un ataque al servidor de tokens.

**Comando**: `/status/401` del laboratorio responde 401 a cualquier token:

```bash
AUTH_MODE=oauth BASE_URL=http://localhost:8080 "$TK" --verbose get /status/401 2>traza.txt
echo "salida: $?"
grep -c 'POST /default/token' traza.txt
grep -c 'GET /status/401' traza.txt
rm -f traza.txt
```

**Verifica**:

```bash
# salida: 77
# 1
# 2
```

Una renovación y dos peticiones: la original y la repetición. Después, 77,
como cualquier credencial rechazada. Apunta en `caducidad.md` qué pasaría con
un bucle sin límite si la API respondiera siempre 401.

El TODO 5 solo repite en `ejecutar`. `fetch-all` (Semana 07) no repite en un
401 a mitad del listado: el `ponytail:` de `ejecutar` lo explica. Para un
listado que tarda más de una hora, el margen del TODO 3 renueva antes de cada
página.

---

## ✅ Resultado

- [ ] `caducidad.md` explica por qué se guarda `expires_at` y no `expires_in`
- [ ] Mi `guardar_sesion` (TODO 2) escribe una sesión 600, sin dejar temporales ni imprimir el token
- [ ] Mi `sesion_caducada` (TODO 3) renueva dentro del margen y no fuera
- [ ] Con una sesión vigente, el toolkit no toca `/token`
- [ ] He visto un 401 con una sesión "activa", y sé por qué el reloj no lo ve
- [ ] Mi `ejecutar` (TODO 5) renueva y repite una vez, y sale con 77 si el 401 sigue

```bash
./scripts/verificar-semana.sh 08
```

Esta práctica cierra los TODOs 2, 3 y 5.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| `error: ... es legible por otros usuarios` | Reescribiste la sesión con `mv` o con `>` a un archivo nuevo | `chmod 600 ~/.bc-curl-session`, y usa `retocar` |
| `jq: error: Could not open file` en `retocar` | No hay sesión todavía | `"$TK" auth login` |
| El paso 2 deja un `~/.bc-curl-session.XXXXXX` | `mktemp` funcionó y el `mv` no llegó a ejecutarse | Mira el error de `jq` en tu TODO 2 y borra el temporal |
| El paso 3 no renueva con 10 segundos | El TODO 3 compara al revés, o sin el margen | `[ "$(date +%s)" -ge $(( expires_at - MARGEN_CADUCIDAD )) ]` |
| `date: invalid option -- 'd'` | Estás en macOS | `date -r 1794450418` |
| El paso 7 cuenta más de una renovación | Tu TODO 5 llama a `ejecutar` dentro de `ejecutar` | Repite con `peticion`, no con `ejecutar` |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 02 — Authorization code con PKCE, a mano](02-authorization-code-con-pkce-a-mano.md) | [Práctica 04 — Refrescar y revocar](04-refrescar-y-revocar.md) |
