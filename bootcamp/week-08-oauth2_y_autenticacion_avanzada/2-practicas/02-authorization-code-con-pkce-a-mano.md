# Práctica 02 — Authorization code con PKCE, a mano

> **Duración**: 50 min · **Entregables**: `pkce.sh`

Vas a recorrer authorization code + PKCE haciendo tú de navegador con curl:
generar el verifier y el challenge, enviar el formulario de login, leer el
código de la redirección sin seguirla, comprobar el `state` y canjear el
código. Después provocarás los rechazos que hace el servidor, verás lo que el
simulador deja pasar y un servidor real no, y lo juntarás todo en `pkce.sh`,
que deja una sesión **de una persona**, con refresh token, para la práctica 04.

**Antes de empezar**, desde la raíz del repositorio:

```bash
./scripts/start.sh
export TK="$PWD/bootcamp/week-08-oauth2_y_autenticacion_avanzada/3-proyecto/starter/api-toolkit.sh"
export OAUTH=http://localhost:8081/default
mkdir -p ~/bc-curl-trabajo/semana-08/p2 && cd ~/bc-curl-trabajo/semana-08/p2
umask 077    # todo lo que crees en esta terminal nace con 600: aqui hay tokens
bash    # los pasos estan escritos para bash; si tu terminal es zsh, abre un bash
```

Necesitas `openssl` (cualquier versión de la 1.1 en adelante): `openssl
version`.

---

## Paso 1: El verifier y el challenge

**Por qué**: PKCE ata el código al cliente que lo pidió. El cliente guarda un
secreto de un solo uso (el *verifier*) y manda por el navegador solo su hash
(el *challenge*). Quien robe el código en la redirección no tiene el verifier
(teoría 04, apartado 2.3).

**Comando**:

```bash
verifier=$(openssl rand -base64 48 | tr '+/' '-_' | tr -d '=\n')
challenge=$(printf %s "$verifier" | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=')
echo "${#verifier} ${#challenge}"

# El error clasico: echo anade un salto de linea al verifier antes del hash.
malo=$(echo "$verifier" | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=')
[ "$malo" = "$challenge" ] && echo igual || echo distinto
```

**Verifica**:

```bash
# 64 43
# distinto
```

43 caracteres es lo que mide un SHA-256 (32 bytes) en base64url sin relleno.
Si tu challenge mide 44, te queda un `=`; si mide más de 80, te falta
`-binary`. Apunta en un comentario al principio de `pkce.sh` por qué `printf
%s` y no `echo`.

---

## Paso 2: El formulario de login

**Por qué**: en la vida real, el cliente abre esta URL en el navegador y la
persona ve una página de login. Aquí la pides con curl para ver qué hay: un
formulario HTML que el paso 3 rellenará.

**Comando**:

```bash
redirect=http://localhost:9999/cb
state=$(openssl rand -hex 16)
autorizar="$OAUTH/authorize?response_type=code&client_id=cli-publico&redirect_uri=${redirect}&scope=openid&state=${state}&code_challenge=${challenge}&code_challenge_method=S256"

curl -sS --fail-with-body --max-time 5 -o login.html -w '%{http_code} %{content_type}\n' "$autorizar"
grep -o '<form[^>]*>\|name="username"' login.html
```

**Verifica**:

```bash
# 200 text/html;charset=UTF-8
# <form method="post">
# name="username"
```

Un formulario con `method="post"` y sin `action` se envía a la misma URL: el
paso 3 hace un `POST` a `$autorizar` con `username`.

---

## Paso 3: El login y la redirección

**Por qué**: tras el login, el servidor responde con un 302 a la
`redirect_uri`, con el código y el `state` en la URL. En `localhost:9999` no
escucha nadie, así que no se sigue: se lee con `%{redirect_url}`.

**Comando**:

```bash
vuelta=$(curl -sS --max-time 10 -o /dev/null -w '%{redirect_url}' -d username=alumno "$autorizar")
echo "${vuelta%%\?*}"

recibido=$(sed -n 's/.*[?&]state=\([^&]*\).*/\1/p' <<<"$vuelta")
[ "$recibido" = "$state" ] && echo "state correcto" || echo "state distinto: aborta"
code=$(sed -n 's/.*[?&]code=\([^&]*\).*/\1/p' <<<"$vuelta")
echo "code de ${#code} caracteres"
```

**Verifica**:

```bash
# http://localhost:9999/cb
# state correcto
# code de 43 caracteres
```

Comprobar el `state` es trabajo **del cliente**: el servidor lo devuelve tal
cual, sea el que sea (teoría 04, apartado 2.2):

```bash
curl -sS --max-time 10 -o /dev/null -w '%{redirect_url}\n' -d username=alumno \
  "${autorizar/state=$state/state=abc}" | sed 's/code=[^&]*/code=.../'
# http://localhost:9999/cb?code=...&state=abc
```

---

## Paso 4: El canje, con un cliente público

**Por qué**: `cli-publico` es un CLI repartido que no puede guardar un
secreto. Lo único que demuestra que el código es suyo es el verifier.

**Comando**:

```bash
curl -sS --max-time 10 -o tokens.json -w '%{http_code}\n' "$OAUTH/token" \
  -d grant_type=authorization_code -d client_id=cli-publico \
  --data-urlencode "code=$code" --data-urlencode "redirect_uri=$redirect" \
  --data-urlencode "code_verifier=$verifier"
jq '{token_type, expires_in, refresh_token: (.refresh_token | type), id_token: (.id_token | type)}' tokens.json

# De quien es el token: el payload del JWT (teoria 07).
jq -r .access_token tokens.json | cut -d. -f2 | tr '_-' '/+' | base64 -d 2>/dev/null \
  | jq -c '{sub, azp}'
```

**Verifica**:

```bash
# 200
# {
#   "token_type": "Bearer",
#   "expires_in": 3599,
#   "refresh_token": "string",
#   "id_token": "string"
# }
# {"sub":"alumno","azp":"cli-publico"}
```

Compara con la práctica 01: allí `sub` era `api-toolkit`, el cliente; aquí es
`alumno`, la persona, y `azp` dice qué cliente actúa en su nombre. Y ahora sí
hay `refresh_token`.

`code` y `verifier` van aquí en la línea de comandos porque mueren en este
canje; en `pkce.sh` irán en el `--config`.

---

## Paso 5: Rechazo 1, el código reutilizado

**Por qué**: un código vale una vez. Si un atacante lo intercepta después de
que el cliente legítimo lo canjee, llega tarde (teoría 04, apartado 2.2).

Los pasos 5 a 7 canjean muchas veces: hazte dos funciones.

**Comando**:

```bash
nuevo_code() {
  curl -sS --max-time 10 -o /dev/null -w '%{redirect_url}' -d username=alumno "$autorizar" \
    | sed -n 's/.*[?&]code=\([^&]*\).*/\1/p'
}
canjear() {   # canjear CODE VERIFIER [REDIRECT]
  curl -sS --max-time 10 "$OAUTH/token" -d grant_type=authorization_code -d client_id=cli-publico \
    --data-urlencode "code=$1" --data-urlencode "redirect_uri=${3:-$redirect}" \
    ${2:+--data-urlencode "code_verifier=$2"}
}

# El code del paso 3, que ya se canjeo en el paso 4.
canjear "$code" "$verifier" | jq -c .
```

**Verifica**:

```bash
# {"error_description":"unknown or already-used authorization code","error":"invalid_grant"}
```

El código HTTP es 400. `${2:+...}` añade el verifier solo si no está vacío:
lo necesitas en el paso 7. `nuevo_code` repite el login con la misma URL de
autorización, y por tanto con el mismo challenge: cada código nuevo sigue
atado a tu verifier.

---

## Paso 6: Rechazo 2, el verifier incorrecto

**Por qué**: es el ataque que PKCE frena. El atacante tiene un código válido,
recién salido de la redirección, pero no el verifier.

**Comando**:

```bash
otro=$(openssl rand -base64 48 | tr '+/' '-_' | tr -d '=\n')
canjear "$(nuevo_code)" "$otro" | jq -c .
```

**Verifica**:

```bash
# {"error_description":"invalid_pkce: code_verifier does not compute to code_challenge from request","error":"invalid_grant"}
```

El servidor guardó el challenge del paso 2 junto al código, recalculó el hash
del verifier que le llega y no coinciden. Un `invalid_grant`: para el toolkit,
77.

---

## Paso 7: Lo que el simulador no comprueba

**Por qué**: un servidor de pruebas deja pasar cosas que uno real no. Verlo
evita aprender seguridad de lo que un servidor permite.

**Comando**:

```bash
# Sin verifier, con un codigo cuya autorizacion llevaba challenge.
canjear "$(nuevo_code)" "" | jq -c '{token_type, error}'
# Con una redirect_uri distinta de la de la autorizacion.
canjear "$(nuevo_code)" "$verifier" http://localhost:9999/otra | jq -c '{token_type, error}'
```

**Verifica**:

```bash
# {"token_type":"Bearer","error":null}
# {"token_type":"Bearer","error":null}
```

Los dos deberían fallar. El RFC 7636 (4.6) dice que un código emitido con
challenge **exige** el verifier en el canje; el RFC 6749 (4.1.3) exige la
misma `redirect_uri` que en la autorización. Un servidor real responde
`invalid_grant` a los dos.

Copia los dos a un comentario de `pkce.sh` con el error que daría un servidor
conforme. No hace falta un check que lo compruebe: el autograding no puede
cambiar el servidor.

---

## Paso 8: `pkce.sh`, y una sesión para el toolkit

**Por qué**: los pasos 1 a 4 son un script. Este, además, se autentica como
cliente confidencial (`api-toolkit`, con secreto en un `--config`) y guarda el
resultado con el formato de sesión del toolkit: así el toolkit puede renovarla
con el refresh token en la práctica 04.

**Comando**: crea `pkce.sh` con este contenido:

```bash
#!/usr/bin/env bash
# pkce.sh: authorization code + PKCE contra el laboratorio. Hace de navegador
# con curl y deja una sesion con refresh_token en OAUTH_SESSION_FILE.
set -euo pipefail

: "${OAUTH_CLIENT_ID:?falta OAUTH_CLIENT_ID}" "${OAUTH_CLIENT_SECRET:?falta OAUTH_CLIENT_SECRET}"
OAUTH="${OAUTH:-http://localhost:8081/default}"
SESION="${OAUTH_SESSION_FILE:-$HOME/.bc-curl-session}"
REDIRECT=http://localhost:9999/cb
USUARIO="${1:-alumno}"

config="$(umask 077 && mktemp)"
cuerpo="$(umask 077 && mktemp)"
trap 'rm -f "$config" "$cuerpo"' EXIT

# 1. verifier, challenge y state.
verifier="$(openssl rand -base64 48 | tr '+/' '-_' | tr -d '=\n')"
challenge="$(printf %s "$verifier" | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=')"
state="$(openssl rand -hex 16)"

# 2 y 3. La autorizacion y el login: lo que haria el navegador.
vuelta="$(curl -sS --fail --max-time 10 -o /dev/null -w '%{redirect_url}' -d "username=$USUARIO" \
  "$OAUTH/authorize?response_type=code&client_id=$OAUTH_CLIENT_ID&redirect_uri=$REDIRECT&scope=openid&state=$state&code_challenge=$challenge&code_challenge_method=S256")"

# 4. El state tiene que ser el nuestro, o el codigo es de otro.
[ "$(sed -n 's/.*[?&]state=\([^&]*\).*/\1/p' <<<"$vuelta")" = "$state" ] \
  || { echo "error: state distinto: no canjeo el codigo" >&2; exit 1; }
code="$(sed -n 's/.*[?&]code=\([^&]*\).*/\1/p' <<<"$vuelta")"
[ -n "$code" ] || { echo "error: la redireccion no trae code: $vuelta" >&2; exit 1; }

# 5. El canje, secreto y verifier en el --config (sin escapar: un " lo romperia).
{
  printf 'user = "%s:%s"\n' "$OAUTH_CLIENT_ID" "$OAUTH_CLIENT_SECRET"
  printf 'data-urlencode = "%s"\n' grant_type=authorization_code "code=$code" \
    "redirect_uri=$REDIRECT" "code_verifier=$verifier"
} > "$config"
codigo="$(curl -sS --max-time 10 --config "$config" -o "$cuerpo" -w '%{http_code}' "$OAUTH/token")"
if [ "$codigo" != 200 ]; then
  echo "error: el canje respondio $codigo: $(jq -r '.error // empty' "$cuerpo")" >&2
  exit 77
fi

# 6. La sesion, en el formato del toolkit: con expires_at, 600 y atomica.
nueva="$(mktemp "$SESION.XXXXXX")"
jq --argjson ahora "$(date +%s)" '.expires_at = $ahora + (.expires_in // 0)' "$cuerpo" > "$nueva"
mv -f "$nueva" "$SESION"
echo "sesion de $USUARIO guardada en $SESION" >&2
```

Y ejecútalo:

```bash
chmod +x pkce.sh
shellcheck -S warning pkce.sh && echo "shellcheck limpio"
export OAUTH_CLIENT_ID=api-toolkit OAUTH_CLIENT_SECRET=secreto-de-laboratorio
./pkce.sh
ls -l ~/.bc-curl-session | cut -c1-10
"$TK" auth status
```

**Verifica**:

```bash
# shellcheck limpio
# sesion de alumno guardada en /home/tu-usuario/.bc-curl-session
# -rw-------
# activa: expira en 3599 s, sub=alumno, refresh_token: si
```

`auth status` ya funciona con el starter: no depende de ningún TODO. Lee la
sesión que ha escrito otro programa, porque el formato es el mismo. `printf`
es una orden interna de bash: el secreto no pasa por ningún argumento de un
proceso aunque esté en su línea.

---

## ✅ Resultado

- [ ] Genero un verifier y su challenge S256, y sé por qué `echo` rompe el hash
- [ ] He leído el código de la redirección sin seguirla y he comprobado el `state`
- [ ] He canjeado un código como cliente público y he visto `sub=alumno`
- [ ] He provocado el código reutilizado y el verifier incorrecto
- [ ] `pkce.sh` apunta en comentarios los dos fallos que el simulador deja pasar
- [ ] `pkce.sh` pasa shellcheck y deja una sesión 600 que `auth status` reconoce

```bash
./scripts/verificar-semana.sh 08
```

Esta práctica no cierra ningún TODO: prepara la sesión con refresh token con
la que la práctica 04 prueba el TODO 4.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| `${#challenge}` da 44 | Te falta `tr -d '='` | El challenge de base64url no lleva relleno |
| `${#challenge}` pasa de 80 | Te falta `-binary` en `openssl dgst` | Sin él, `openssl` imprime el hash en hexadecimal y con texto delante |
| El paso 2 da 400 con un JSON | Falta un parámetro de la URL, normalmente `scope` | Copia `autorizar` tal cual |
| El paso 4 da `invalid_pkce` | El verifier de esta terminal no es el del challenge de `autorizar` | Si reabriste el terminal, repite desde el paso 1 |
| `auth status` dice `sub=?` | El token no es un JWT, o la sesión no tiene `access_token` | `jq 'keys' ~/.bc-curl-session` |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 01 — Pedir un token sin filtrar el secreto](01-pedir-un-token-sin-filtrar-el-secreto.md) | [Práctica 03 — Caducidad y el 401 inesperado](03-caducidad-y-el-401-inesperado.md) |
