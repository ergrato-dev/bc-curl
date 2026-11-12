# Práctica 01 — Pedir un token sin filtrar el secreto

> **Duración**: 50 min · **Entregables**: `token.md`

Vas a pedir tu primer access token al servidor OAuth2 del laboratorio con
client credentials. Antes verás dónde se escapa el secreto del cliente cuando
va en la línea de comandos y en una traza; después lo moverás a un `--config`
con permisos 600, que es exactamente lo que hace el TODO 1 del proyecto.
Terminas usando el token contra `/userinfo`, a mano y con el toolkit.

**Antes de empezar**, desde la raíz del repositorio:

```bash
./scripts/start.sh
export TK="$PWD/bootcamp/week-08-oauth2_y_autenticacion_avanzada/3-proyecto/starter/api-toolkit.sh"
export OAUTH=http://localhost:8081/default
mkdir -p ~/bc-curl-trabajo/semana-08/p1 && cd ~/bc-curl-trabajo/semana-08/p1
umask 077    # todo lo que crees en esta terminal nace con 600: aqui hay tokens
bash    # los pasos estan escritos para bash; si tu terminal es zsh, abre un bash
```

El laboratorio acepta cualquier `client_id` con cualquier secreto: es un
simulador. En esta práctica el cliente es `api-toolkit` y el secreto,
`secreto-de-laboratorio`. Trátalo como si fuera de verdad: no aparece en
ninguna línea de comandos salvo en el contraste del paso 2.

---

## Paso 1: Preguntarle al servidor dónde está todo

**Por qué**: un servidor OAuth2 publica sus endpoints en el documento de
*discovery* (teoría 02). Copiar URLs de un tutorial funciona hasta que el
proveedor las cambia; leerlas del discovery, no.

**Comando**:

```bash
curl -sS --fail-with-body --max-time 5 "$OAUTH/.well-known/openid-configuration" \
  | jq '{issuer, token_endpoint, revocation_endpoint, introspection_endpoint, jwks_uri}'
```

**Verifica**:

```bash
# {
#   "issuer": "http://localhost:8081/default",
#   "token_endpoint": "http://localhost:8081/default/token",
#   "revocation_endpoint": "http://localhost:8081/default/revoke",
#   "introspection_endpoint": "http://localhost:8081/default/introspect",
#   "jwks_uri": "http://localhost:8081/default/jwks"
# }
```

Apunta en `token.md` los cinco valores. Son los que el toolkit tiene como
`OAUTH_TOKEN_URL` y `OAUTH_REVOKE_URL` por defecto.

---

## Paso 2: El secreto a la vista

**Por qué**: el antipatrón más habitual con OAuth2 en un script es `curl -u
id:secreto` o `-d client_secret=...`. Funciona, y deja el secreto en el
listado de procesos, donde cualquier usuario de la máquina lo lee.

**Comando** (contraste: así **no**):

```bash
# /delay/2 tarda dos segundos: tiempo para mirar el proceso mientras vive.
curl -sS --max-time 5 -o /dev/null -u api-toolkit:secreto-de-laboratorio \
  http://localhost:8080/delay/2 &
sleep 0.5
ps -o args= -p $!
wait
```

**Verifica**:

```bash
# curl -sS --max-time 5 -o /dev/null -u api-toolkit:secreto-de-laboratorio http://localhost:8080/delay/2
```

Algunas versiones de curl intentan tapar el argumento de `-u` después de
leerlo, pero no en todos los sistemas, y nunca antes de que el proceso
arranque: hay una ventana en la que se ve siempre. Con `-d
client_secret=...` no lo intenta ni siquiera. Y además está el historial del
terminal: `history | tail -5`. Apunta en `token.md` tres sitios donde ha
quedado el secreto.

---

## Paso 3: El secreto en un `--config`

**Por qué**: un archivo que solo lee su dueño y que curl lee por dentro no
aparece en `ps` ni en el historial. Es la técnica de la Semana 03 aplicada al
cliente OAuth2, y es la primera mitad del TODO 1.

**Comando**:

```bash
config=$(umask 077 && mktemp)
cat > "$config" <<'EOF'
user = "api-toolkit:secreto-de-laboratorio"
data-urlencode = "grant_type=client_credentials"
EOF
ls -l "$config" | cut -c1-10

curl -sS --max-time 10 --config "$config" -o token.json -w '%{http_code}\n' "$OAUTH/token"
jq 'del(.access_token)' token.json
```

**Verifica**:

```bash
# -rw-------
# 200
# {
#   "token_type": "Bearer",
#   "expires_in": 3599
# }
```

Tres decisiones que el TODO 1 copia:

| Pieza | Por qué |
|---|---|
| `umask 077` + `mktemp` | El archivo nace con 600, antes de escribir nada en él |
| `cat <<'EOF'` | Un *heredoc* es parte del shell: no lanza un proceso con el secreto como argumento |
| `-o token.json` | La respuesta con el token va a un archivo, no a la terminal |

`del(.access_token)` es la costumbre de esta semana: miras todo lo que trae
la respuesta **menos** el token. Fíjate en lo que falta: no hay
`refresh_token`. Client credentials no lo da (teoría 03): apúntalo.

---

## Paso 4: Lo que enseña la traza

**Por qué**: el `--config` saca el secreto de `ps`, pero curl lo convierte en
un header `Authorization: Basic`, y `-v` imprime los headers. Base64 no es
cifrado: es un disfraz.

**Comando**:

```bash
curl -v -sS --max-time 10 --config "$config" -o /dev/null "$OAUTH/token" 2>&1 \
  | grep -i '^> authorization' | cut -c1-30

curl -v -sS --max-time 10 --config "$config" -o /dev/null "$OAUTH/token" 2>&1 \
  | sed -n 's/^> Authorization: Basic //p' | tr -d '\r' | base64 -d; echo
```

**Verifica**:

```bash
# > Authorization: Basic YXBpLXRv
# api-toolkit:secreto-de-laboratorio
```

Cualquier traza que pegues en un issue o en un chat lleva el secreto. Por eso
`lanzar_curl` pasa la traza de `--verbose` por `redactar_traza` (Semana 06):

```bash
# Lo que veras en el paso 7, con el toolkit:
# > Authorization: <REDACTADO>
```

Apunta en `token.md` por qué base64 no protege nada. Es lo que comprueba
`toolkit-login-traza-sin-secreto`.

---

## Paso 5: Más campos, y el scope

**Por qué**: el TODO 1 recibe los campos del formulario como argumentos
(`grant_type=...`, `scope=...`) y escribe una línea `data-urlencode` por cada
uno. `data-urlencode` codifica el espacio de un scope con varios permisos, y
cualquier `&` o `=` que lleve un valor; un `data` sin codificar lo mandaría
roto.

**Comando**:

```bash
echo 'data-urlencode = "scope=leer escribir"' >> "$config"
curl -sS --max-time 10 --config "$config" "$OAUTH/token" | jq '{scope, expires_in}'

# Lo que curl manda, sin el header:
curl -sS --max-time 10 --config "$config" -o /dev/null "$OAUTH/token" \
  --trace-ascii - | grep -A1 '^=> Send data' | tail -1
```

**Verifica**:

```bash
# {
#   "scope": "leer escribir",
#   "expires_in": 3599
# }
# 0000: grant_type=client_credentials&scope=leer+escribir
```

Varios `data-urlencode` se unen con `&`, en el orden del archivo. El espacio
sale como `+`, como en un formulario HTML; según la versión de curl puede
salir `%20`, y el servidor entiende los dos. El servidor
devuelve el scope **concedido**, que puede ser menor que el pedido: un
cliente que necesita `escribir` comprueba que lo tiene antes de usarlo.

Para el TODO 1, el formato de cada línea es el mismo que escribirás con
`escapar_config`:

```text
user = "ID:SECRETO"
data-urlencode = "grant_type=client_credentials"
data-urlencode = "scope=leer escribir"
```

---

## Paso 6: Los errores del endpoint de token

**Por qué**: el endpoint de token no responde como una API cualquiera. Los
errores llegan con un campo `error` estándar (RFC 6749, 5.2), y ese campo es
lo que decide si el toolkit sale con 77 o con otro código.

**Comando**:

```bash
# Sin autenticar al cliente.
curl -sS --max-time 5 -w ' %{http_code}\n' "$OAUTH/token" -d grant_type=client_credentials
# Un grant que no existe. Con el grant_type repetido, el servidor usa el ultimo.
curl -sS --max-time 5 --config "$config" -d grant_type=inventado "$OAUTH/token" | jq -c .
# El cuerpo en JSON en vez de formulario.
curl -sS --max-time 5 --config "$config" -w ' %{http_code}\n' "$OAUTH/token" \
  -H 'Content-Type: application/json' --data-raw '{"grant_type":"client_credentials"}'
```

**Verifica**:

```bash
# {
#   "error_description" : "client authentication failed: missing client authentication",
#   "error" : "invalid_client"
# } 401
# {"error_description":"grant_type inventado not supported.","error":"invalid_grant"}
# {
#   "error_description" : "missing required parameter grant_type",
#   "error" : "invalid_request"
# } 400
```

Copia a `token.md` una tabla con los tres: petición, código HTTP, `error`, y
qué haría el toolkit (`rechazo_oauth`).

El segundo merece una nota: el RFC pide `unsupported_grant_type` para un grant
desconocido, y el simulador responde `invalid_grant`. El toolkit lo tratará
como una credencial que no vale (77): con un servidor real daría 1. Ningún
simulador es la especificación.

El tercero es el error de principiante con OAuth2: el endpoint de token
**solo** acepta `application/x-www-form-urlencoded`. No hay `--json` aquí.

---

## Paso 7: El TODO 1 en el toolkit

**Por qué**: con los pasos 3 a 5 tienes todas las piezas de `peticion_oauth`.
Escribirla y ver la traza tachada cierra el círculo.

**Comando**: resuelve el TODO 1 en `$TK`. Después:

```bash
export OAUTH_CLIENT_ID=api-toolkit
export OAUTH_CLIENT_SECRET=secreto-de-laboratorio    # en tu sistema real, en ~/.bc-curl
"$TK" --verbose auth login 2>&1 | grep -E '^> (POST|Authorization|Content-Type)|^(error|sesion)'
```

**Verifica**:

```bash
# > POST /default/token HTTP/1.1
# > Authorization: <REDACTADO>
# > Content-Type: application/x-www-form-urlencoded
# error: guardar_sesion todavia no esta implementada
```

El error del final es correcto: la petición ya funciona, y lo que falta es
guardarla (TODO 2, práctica 03). Si en vez de eso ves `peticion_oauth todavia
no esta implementada`, el TODO 1 no está resuelto. Comprueba también que el
secreto no aparece en ningún sitio:

```bash
"$TK" --verbose auth login 2>&1 | grep -c secreto-de-laboratorio
# 0
```

Con el TODO 2 resuelto, la última línea será `sesion guardada en
/home/tu-usuario/.bc-curl-session`.

---

## Paso 8: El token contra `/userinfo`

**Por qué**: un token sirve para algo cuando una API lo acepta. `/userinfo`
del laboratorio valida el token (firma, `exp`) y dice de quién es: es la API
de prueba de esta semana.

**Comando**: el token también es un secreto, así que tampoco va en la línea
de comandos. Va en un `--config` como header:

```bash
cabecera=$(umask 077 && mktemp)
jq -j .access_token token.json | sed 's/^/header = "Authorization: Bearer /; s/$/"/' > "$cabecera"
curl -sS --fail-with-body --max-time 5 --config "$cabecera" "$OAUTH/userinfo" | jq '{sub, aud, iss}'
curl -sS --max-time 5 -o /dev/null -w '%{http_code}\n' "$OAUTH/userinfo"
```

**Verifica**:

```bash
# {
#   "sub": "api-toolkit",
#   "aud": "default",
#   "iss": "http://localhost:8081/default"
# }
# 401
```

`sub=api-toolkit`: con client credentials, el token es **del cliente**, no de
una persona. Sin token, 401.

Con el TODO 2 resuelto, el toolkit hace lo mismo con la sesión. Es la
comprobación `toolkit-oauth-userinfo`:

```bash
"$TK" auth login
AUTH_MODE=oauth BASE_URL="$OAUTH" "$TK" get /userinfo | jq -r .sub
# api-toolkit
```

Limpia lo que no debe quedar:

```bash
rm -f "$config" "$cabecera" token.json
```

---

## ✅ Resultado

- [ ] `token.md` tiene los endpoints del discovery y los tres sitios donde quedó el secreto del paso 2
- [ ] He pedido un token con el secreto en un `--config` de permisos 600
- [ ] He decodificado el `Authorization: Basic` de una traza y sé por qué el toolkit lo tacha
- [ ] `token.md` tiene la tabla de errores del endpoint de token
- [ ] Mi `peticion_oauth` (TODO 1) llega al servidor y su traza no enseña el secreto
- [ ] He usado el token contra `/userinfo` sin ponerlo en la línea de comandos

```bash
./scripts/verificar-semana.sh 08
```

Esta práctica prepara el TODO 1: el `--config` con `user` y los
`data-urlencode`, y `lanzar_curl` con `--output` y `--write-out`.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| `curl: (7) Failed to connect to localhost port 8081` | El contenedor `oauth` no está arrancado | `./scripts/start.sh`; si sigue, `docker compose logs oauth` |
| `ps` no enseña nada en el paso 2 | La petición terminó antes del `ps` | Sube el delay: `/delay/4` |
| El paso 3 da 401 `invalid_client` | El `--config` no tiene la línea `user`, o le falta una comilla | `cat "$config"` y compara con el paso 3 |
| El paso 5 enseña `scope=leer%20escribir` | Tu curl codifica el espacio de otra forma | Para el servidor es lo mismo; apúntalo |
| `/userinfo` da 401 con un token recién pedido | Pasó más de una hora desde el paso 3 y el token caducó | Repite el paso 3 |

---

| Anterior | Siguiente |
|---|---|
| [Teoría 08 — Guardar la sesión](../1-teoria/08-guardar-la-sesion.md) | [Práctica 02 — Authorization code con PKCE, a mano](02-authorization-code-con-pkce-a-mano.md) |
