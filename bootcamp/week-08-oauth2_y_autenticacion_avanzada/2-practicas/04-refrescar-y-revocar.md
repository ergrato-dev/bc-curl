# Práctica 04 — Refrescar y revocar

> **Duración**: 50 min · **Entregables**: `refresco.md`

Vas a usar el refresh token de la sesión que dejó `pkce.sh` en la práctica 02,
con los TODOs 1, 2, 3 y 5 ya resueltos (prácticas 01 y 03):
refrescarlo a mano, comprobar que el token nuevo sigue siendo de la misma
persona y ver si el servidor rota. Después lo revocarás y provocarás el
`invalid_grant` que no tiene arreglo automático. Con eso resuelves los TODOs 4
(`renovar`) y 6 (`cerrar_sesion`), y compruebas que el toolkit nunca cambia de
identidad en silencio.

**Antes de empezar**, desde la raíz del repositorio:

```bash
./scripts/start.sh
export TK="$PWD/bootcamp/week-08-oauth2_y_autenticacion_avanzada/3-proyecto/starter/api-toolkit.sh"
export OAUTH=http://localhost:8081/default
export OAUTH_CLIENT_ID=api-toolkit OAUTH_CLIENT_SECRET=secreto-de-laboratorio
mkdir -p ~/bc-curl-trabajo/semana-08/p4 && cd ~/bc-curl-trabajo/semana-08/p4
umask 077    # todo lo que crees en esta terminal nace con 600: aqui hay tokens
cp ../p2/pkce.sh .
bash    # los pasos estan escritos para bash; si tu terminal es zsh, abre un bash
```

Las peticiones a mano usan un `--config` por petición, como en la práctica
01: el secreto del cliente y el refresh token no pasan por la línea de
comandos. Esta función los escribe:

```bash
# formulario CAMPO=VALOR...: un --config con la autenticacion del cliente.
formulario() {
  local archivo
  archivo=$(umask 077 && mktemp)
  printf 'user = "%s:%s"\n' "$OAUTH_CLIENT_ID" "$OAUTH_CLIENT_SECRET" > "$archivo"
  printf 'data-urlencode = "%s"\n' "$@" >> "$archivo"
  echo "$archivo"
}
```

`printf` es una orden interna de bash: sus argumentos no aparecen en `ps`.
Define también `retocar`, la de la práctica 03: los pasos 4, 5 y 7 la usan.

---

## Paso 1: Una sesión con refresh token

**Por qué**: client credentials no da refresh token (práctica 01). Para
practicar con uno hace falta una sesión de una persona: la de `pkce.sh`.

**Comando**:

```bash
./pkce.sh
"$TK" auth status
jq 'del(.access_token, .refresh_token, .id_token)' ~/.bc-curl-session
```

**Verifica**:

```bash
# sesion de alumno guardada en /home/tu-usuario/.bc-curl-session
# activa: expira en 3599 s, sub=alumno, refresh_token: si
# {
#   "token_type": "Bearer",
#   "expires_in": 3599,
#   "expires_at": 1794450120
# }
```

Cuando miras una sesión, miras todo **menos** los tokens: `del(...)`.

---

## Paso 2: Refrescar a mano

**Por qué**: es la petición que hará `renovar` (TODO 4). Otro `POST` a
`/token`, con `grant_type=refresh_token` y la autenticación del cliente
(teoría 06, apartado 2.3).

**Comando**:

```bash
refresh=$(jq -r .refresh_token ~/.bc-curl-session)
cfg=$(formulario grant_type=refresh_token "refresh_token=$refresh")
curl -sS --max-time 10 --config "$cfg" -o nuevo.json -w '%{http_code}\n' "$OAUTH/token"
jq --slurpfile antes ~/.bc-curl-session '{
  mismo_refresh: (.refresh_token == $antes[0].refresh_token),
  mismo_access:  (.access_token  == $antes[0].access_token),
  expires_in
}' nuevo.json
```

**Verifica**:

```bash
# 200
# {
#   "mismo_refresh": true,
#   "mismo_access": false,
#   "expires_in": 3599
# }
```

Access token nuevo, con su hora de vida entera. Refresh token **el mismo**:
el laboratorio no rota. Apunta en `refresco.md` qué cambiaría si rotara: el
nuevo hay que guardarlo antes de nada, y el viejo deja de valer (teoría 06,
apartado 2.4). `guardar_sesion 1` cubre los dos casos: conserva el anterior
solo si la respuesta no trae uno.

---

## Paso 3: De quién es el token renovado

**Por qué**: renovar con refresh token conserva la identidad. Es lo que lo
distingue de pedir otro token con client credentials, y lo que el TODO 4 no
puede romper.

**Comando**:

```bash
sub_de() { jq -r .access_token "$1" | cut -d. -f2 | tr '_-' '/+' | base64 -d 2>/dev/null | jq -r .sub; }
echo "sesion: $(sub_de ~/.bc-curl-session)"
echo "renovado: $(sub_de nuevo.json)"

cc=$(formulario grant_type=client_credentials)
curl -sS --max-time 10 --config "$cc" -o cc.json "$OAUTH/token"
echo "client credentials: $(sub_de cc.json)"
```

**Verifica**:

```bash
# sesion: alumno
# renovado: alumno
# client credentials: api-toolkit
```

Apunta en `refresco.md` la consecuencia: si `renovar` pidiera client
credentials con una sesión de `alumno`, el script seguiría funcionando con
**otra identidad y otros permisos**, sin un solo error.

---

## Paso 4: El bug del starter

**Por qué**: el `renovar` del starter siempre pide client credentials. Con una
sesión de client credentials da igual; con una de `alumno`, es el fallo del
paso 3. Hay que verlo antes de arreglarlo.

**Comando**: con el TODO 4 **sin** resolver (y el 3 resuelto en la práctica
03), fuerza la caducidad de la sesión y haz una petición:

```bash
./pkce.sh 2>/dev/null
retocar '.expires_at = 0'
AUTH_MODE=oauth BASE_URL="$OAUTH" "$TK" get /userinfo | jq -r .sub
```

**Verifica**:

```bash
# aviso: token OAuth2 renovado
# api-toolkit
```

Una
petición que empezó como `alumno` ha terminado como `api-toolkit`. Ningún
error, ningún código de salida distinto de 0.

---

## Paso 5: El TODO 4, la renovación que conserva la identidad

**Por qué**: con refresh token, `renovar` tiene que usarlo. Es la comprobación
`toolkit-refresh-token`.

**Comando**: resuelve el TODO 4. Si la sesión trae `refresh_token`,
`peticion_oauth "$OAUTH_TOKEN_URL" grant_type=refresh_token
"refresh_token=..."`; si no, `pedir_client_credentials`. Después:

```bash
./pkce.sh 2>/dev/null
retocar '.expires_at = 0'
AUTH_MODE=oauth BASE_URL="$OAUTH" "$TK" get /userinfo | jq -r .sub
"$TK" auth status
```

**Verifica**:

```bash
# aviso: token OAuth2 renovado
# alumno
# activa: expira en 3599 s, sub=alumno, refresh_token: si
```

---

## Paso 6: Revocar a mano

**Por qué**: el endpoint de revocación (RFC 7009) tiene sus reglas, y el
simulador una propia: exige `token_type_hint` (teoría 06, apartado 2.7).

**Comando**:

```bash
revocar() {   # revocar TOKEN [HINT]
  local cfg
  cfg=$(formulario "token=$1" ${2:+"token_type_hint=$2"})
  curl -sS --max-time 10 --config "$cfg" -o "$cfg.r" -w '%{http_code} ' "$OAUTH/revoke"
  jq -r '.error // empty' "$cfg.r"
  rm -f "$cfg" "$cfg.r"
}
revocar "$(jq -r .access_token ~/.bc-curl-session)"
revocar "$(jq -r .access_token ~/.bc-curl-session)" access_token
revocar inventado refresh_token
```

**Verifica**:

```bash
# 400 unsupported_token_type
# 400 unsupported_token_type
# 200
```

Tres cosas para `refresco.md`:

| Petición | Respuesta | Qué enseña |
|---|---|---|
| Sin hint | 400 `unsupported_token_type` | El simulador no adivina el tipo; el RFC dice que debería |
| Access token | 400 `unsupported_token_type` | No revoca access tokens: un JWT vale hasta su `exp` |
| Token inventado | 200 | El RFC responde 200 a lo que no existe, para no revelar qué tokens existen |

El tercero significa que un 200 de `/revoke` **no** prueba que el token
existiera. Lo que lo prueba es el paso siguiente.

---

## Paso 7: El refresh token revocado

**Por qué**: un refresh token revocado no tiene arreglo automático. El
toolkit tiene que salir con 77 y pedir `auth login`, nunca caer a client
credentials. Es la comprobación `toolkit-refresh-revocado-77`.

**Comando**:

```bash
revocar "$(jq -r .refresh_token ~/.bc-curl-session)" refresh_token
"$TK" auth status

retocar '.expires_at = 0'
AUTH_MODE=oauth BASE_URL="$OAUTH" "$TK" get /userinfo; echo "salida: $?"
```

**Verifica**:

```bash
# 200
# activa: expira en 3540 s, sub=alumno, refresh_token: si
# error: el servidor OAuth2 respondio 400: invalid_grant (unknown refresh_token)
# error: la sesion ya no se puede renovar: ejecuta auth login
# salida: 77
```

`auth status` dice "activa" con el refresh token ya revocado: la sesión local
no sabe lo que pasó en el servidor. Solo el siguiente uso lo descubre.

Si ves `api-toolkit` en vez del 77, tu TODO 4 cae a client credentials cuando
el refresh falla. `exigir_token_ok` ya sale con 77: no hace falta nada más que
**no** probar otra cosa después.

---

## Paso 8: El TODO 6, un logout que revoca

**Por qué**: `auth logout` como `rm` deja el refresh token vivo en el
servidor (teoría 08, apartado 2.6). Es la comprobación
`toolkit-logout-revoca`.

**Comando**: resuelve el TODO 6. Después:

```bash
./pkce.sh 2>/dev/null
cp ~/.bc-curl-session copia.json      # lo que se llevaria quien copio la sesion
"$TK" auth logout
ls ~/.bc-curl-session

cfg=$(formulario grant_type=refresh_token "refresh_token=$(jq -r .refresh_token copia.json)")
curl -sS --max-time 10 --config "$cfg" "$OAUTH/token" | jq -r .error
rm -f copia.json
```

**Verifica**:

```bash
# sesion cerrada: refresh_token revocado
# ls: cannot access '/home/tu-usuario/.bc-curl-session': No such file or directory
# invalid_grant
```

La copia no sirve: el logout la ha matado en el servidor. Con un `logout` que
solo hiciera `rm`, el último comando daría un token nuevo.

---

## Paso 9: El logout de una sesión sin refresh token, y el que falla

**Por qué**: una sesión de client credentials solo tiene access token, que el
simulador no revoca. El TODO 6 tiene que avisar y borrar. Y si la revocación
falla por otra causa, **no** borrar. Es `toolkit-logout-borra`.

**Comando**:

```bash
"$TK" auth login
"$TK" auth logout; echo "salida: $?"

"$TK" auth login 2>/dev/null
OAUTH_REVOKE_URL=http://localhost:9/revoke "$TK" auth logout; echo "salida: $?"
ls ~/.bc-curl-session
"$TK" auth logout 2>/dev/null
```

**Verifica**:

```bash
# sesion guardada en /home/tu-usuario/.bc-curl-session
# aviso: el servidor no revoca el access_token: sigue valido hasta que caduque
# sesion cerrada
# salida: 0
# curl: (7) Failed to connect to localhost port 9 after 0 ms: Connection refused
# error: el servidor rechaza la conexion (curl: 7)
# salida: 69
# /home/tu-usuario/.bc-curl-session
```

Con el servidor de revocación caído, la sesión sigue ahí: el logout se puede
repetir. El último comando la cierra de verdad. Apunta en `refresco.md` por
qué borrar igualmente habría sido peor.

Limpia:

```bash
rm -f "$cfg" "$cc" nuevo.json cc.json
```

---

## ✅ Resultado

- [ ] He refrescado un token a mano y sé si el servidor rota
- [ ] `refresco.md` explica por qué renovar con client credentials cambia la identidad
- [ ] Mi `renovar` (TODO 4) usa el refresh token y conserva `sub=alumno`
- [ ] He revocado un refresh token y he visto el 77 del toolkit, sin caer a client credentials
- [ ] `refresco.md` tiene la tabla de las tres revocaciones
- [ ] Mi `cerrar_sesion` (TODO 6) revoca, avisa con `unsupported_token_type` y no borra si la revocación falla

```bash
./scripts/verificar-semana.sh 08
```

Esta práctica cierra los TODOs 4 y 6.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| El paso 2 da `invalid_grant` | La sesión es de client credentials (`auth login`), sin refresh token | `./pkce.sh` |
| `error: ... es legible por otros usuarios` | Reescribiste la sesión con `mv` en vez de con `retocar` | `chmod 600 ~/.bc-curl-session` |
| El paso 7 sale con 0 y `api-toolkit` | Tu TODO 4 prueba client credentials tras el fallo | Quita esa rama: con refresh token, o funciona o sale |
| El paso 9 borra la sesión con el servidor caído | Tu TODO 6 hace el `rm` antes de mirar el resultado | Revoca, comprueba, y solo entonces `rm` |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 03 — Caducidad y el 401 inesperado](03-caducidad-y-el-401-inesperado.md) | [Proyecto — Capa 8](../3-proyecto/README.md) |
