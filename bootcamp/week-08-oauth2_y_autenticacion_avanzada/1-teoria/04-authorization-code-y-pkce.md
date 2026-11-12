# Authorization code y PKCE

> El flujo con el que una persona le da permiso a un programa sin darle su
> password. La persona hace login en el navegador, el servidor devuelve un
> código de un solo uso, y el programa lo cambia por un token. PKCE añade la
> pieza que impide que quien robe ese código pueda usarlo.

![Secuencia de authorization code con PKCE en cinco pasos: el cliente genera un code_verifier aleatorio y calcula su code_challenge con SHA-256; abre en el navegador /authorize con el challenge y un state; la persona hace login y el servidor redirige a la redirect_uri con code y state; el cliente comprueba el state y envía a /token el code junto al code_verifier original; el servidor recalcula el hash, lo compara con el challenge guardado y entrega access_token y refresh_token. Debajo, el atacante que intercepta el code y no puede canjearlo porque no tiene el verifier](../0-assets/04-authorization-code-y-pkce.svg)

## 🎯 Objetivos

- Recorrer el flujo de authorization code de la redirección al token
- Generar un `code_verifier` y calcular su `code_challenge` S256 con `openssl`
- Explicar qué ataque frena el `state`, cuál PKCE y cuál el código de un solo uso
- Saber qué cambia entre un cliente con secreto y uno público

---

## 1. Qué problema resuelve

Un CLI quiere leer los repositorios de quien lo usa. No puede pedir la
password (teoría 01) y no puede usar client credentials, porque el token
tiene que ser **de la persona**. Necesita que la persona:

1. Se autentique ante el servidor de autorización, no ante el CLI
2. Vea qué permisos pide el CLI y los acepte
3. Le haga llegar al CLI algo que el CLI pueda cambiar por un token

El navegador hace los dos primeros: es donde la persona ya tiene sesión, su
gestor de contraseñas y su 2FA. El tercero es el problema: lo que vuelve del
navegador viaja en una URL, y las URLs se filtran (historial, logs, otras
apps del móvil que registran el mismo esquema de URL). Si lo que viaja fuera
el token, cualquiera que viera la URL lo tendría. Por eso viaja un **código**
que no sirve de nada sin una prueba más.

---

## 2. Cómo funciona

### 2.1 Los pasos

| # | Quién | Qué |
|:--:|---|---|
| 1 | Cliente | Genera un `code_verifier` aleatorio y un `state` aleatorio. Calcula `code_challenge = BASE64URL(SHA256(code_verifier))` |
| 2 | Cliente | Abre en el navegador `/authorize?response_type=code&client_id=...&redirect_uri=...&scope=...&state=...&code_challenge=...&code_challenge_method=S256` |
| 3 | Persona | Hace login y acepta los permisos |
| 4 | Servidor | Guarda el `code_challenge` junto a un código nuevo y redirige a `redirect_uri?code=...&state=...` |
| 5 | Cliente | Comprueba que el `state` es el suyo. Manda a `/token`: `grant_type=authorization_code`, el `code`, la misma `redirect_uri` y el `code_verifier` |
| 6 | Servidor | Recalcula `SHA256(code_verifier)`, lo compara con el challenge del paso 4, marca el código como usado y entrega `access_token` y `refresh_token` |

### 2.2 Qué frena cada pieza

| Pieza | Ataque que frena | Cómo |
|---|---|---|
| `code_verifier` / `code_challenge` (PKCE, RFC 7636) | Robo del código en la redirección | El challenge viajó por el navegador; el verifier nunca. Sin el verifier, el código no se canjea |
| `state` | CSRF: un atacante hace que tu cliente reciba **su** código, y acabas trabajando con su cuenta | El cliente solo acepta una respuesta con el `state` que él mismo generó |
| Código de un solo uso | Reutilizar un código interceptado después del dueño legítimo | El segundo canje falla con `invalid_grant`. Un servidor estricto revoca además los tokens del primero |
| `redirect_uri` exacta | Que el código se mande a una URL del atacante | El servidor solo redirige a URLs registradas, y el canje exige la misma |
| Vida corta del código | Uso tardío de un código filtrado | Caduca en segundos o pocos minutos |

### 2.3 El verifier y el challenge

El `code_verifier` es una cadena aleatoria de **43 a 128 caracteres** del
alfabeto `A-Z a-z 0-9 - . _ ~` (RFC 7636, 4.1). El challenge S256 es su
SHA-256 en base64url, sin relleno:

```bash
# 48 bytes aleatorios en base64url: 64 caracteres, dentro del rango.
verifier=$(openssl rand -base64 48 | tr '+/' '-_' | tr -d '=\n')
challenge=$(printf %s "$verifier" | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=')
echo "${#verifier} ${#challenge}"
# 64 43
```

Tres detalles que rompen el cálculo:

| Error | Qué pasa |
|---|---|
| `echo "$verifier" \| openssl ...` | Se hashea el verifier **con un salto de línea**. El servidor responde `invalid_grant` |
| Olvidar `-binary` | Se codifica en base64 el texto que imprime `openssl`, con el hash en hexadecimal: un challenge de más de 80 caracteres que no coincide |
| Dejar el `=` o el `+/` | Eso es base64, no base64url. El servidor compara cadenas exactas |

Existe también `code_challenge_method=plain`, donde challenge y verifier son
iguales. No protege contra quien ve la URL de autorización y solo está para
clientes que no pueden calcular SHA-256. Con `openssl` a mano, siempre S256.

### 2.4 Con secreto o sin él

| | Cliente confidencial (servidor web, tu cron) | Cliente público (CLI repartido, app móvil, SPA) |
|---|---|---|
| Tiene secreto | Sí | No: no puede guardarlo |
| Se autentica en el canje | `Authorization: Basic` o `client_secret_post` | Solo manda `client_id` en el cuerpo |
| PKCE | Recomendado (RFC 9700) | **Obligatorio**: es lo único que ata el código al cliente |

### 2.5 La redirección en un CLI

Un programa de terminal tiene que recibir la redirección de alguna forma:

| Estrategia | Cómo | Quién la usa |
|---|---|---|
| Servidor local en loopback | `redirect_uri=http://127.0.0.1:PUERTO/cb`; el CLI escucha en ese puerto | `gh auth login --web`, `gcloud auth login` |
| Pegar la URL | El navegador acaba en una página de error con el código en la URL; la persona la copia al terminal | Modos `--no-browser` de varios CLIs |
| Device code | Sin redirección | Teoría 05 |

En la práctica 02 harás de navegador tú mismo con curl: el formulario de
login del laboratorio se envía con `-d username=alumno`, y la redirección se
lee con `%{redirect_url}` sin seguirla.

---

## 3. Cómo se usa

Con el `verifier` y el `challenge` del apartado 2.3, el paso 2 y el login. En
la vida real lo hace el navegador; aquí, curl:

```bash
redirect=http://localhost:9999/cb
state=$(openssl rand -hex 16)
autorizar="http://localhost:8081/default/authorize?response_type=code&client_id=cli-publico&redirect_uri=${redirect}&scope=openid&state=${state}&code_challenge=${challenge}&code_challenge_method=S256"

# El login del laboratorio es un formulario que solo pide un nombre. La
# respuesta es un 302 a la redirect_uri; -w '%{redirect_url}' la lee sin
# seguirla (en localhost:9999 no escucha nadie).
vuelta=$(curl -sS --max-time 10 -o /dev/null -w '%{redirect_url}' "$autorizar" -d username=alumno)
echo "${vuelta%%\?*}"
# http://localhost:9999/cb
```

El paso 5: comprobar el `state` y canjear el código. `cli-publico` es un
cliente público: no manda secreto, solo su `client_id` y el verifier.

```bash
[ "$(sed -n 's/.*[?&]state=\([^&]*\).*/\1/p' <<<"$vuelta")" = "$state" ] || echo "state distinto: aborta"
code=$(sed -n 's/.*[?&]code=\([^&]*\).*/\1/p' <<<"$vuelta")

curl -sS --max-time 10 -o tokens.json http://localhost:8081/default/token \
  -d grant_type=authorization_code -d client_id=cli-publico \
  --data-urlencode "code=$code" --data-urlencode "redirect_uri=$redirect" \
  --data-urlencode "code_verifier=$verifier"
jq '{token_type, expires_in, refresh_token: (.refresh_token | type)}' tokens.json
# {
#   "token_type": "Bearer",
#   "expires_in": 3599,
#   "refresh_token": "string"
# }
```

Aquí `code` y `code_verifier` van en la línea de comandos. Es aceptable en
este ejemplo porque los dos dejan de valer en cuanto se canjean, pero el
patrón del toolkit sigue siendo el `--config`.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Authorization code sin PKCE en un cliente público | Un código interceptado se canjea sin más | PKCE con S256, siempre |
| No comprobar el `state` | Tu cliente acepta el código del atacante | Generarlo aleatorio, guardarlo y comparar antes de canjear |
| Un `state` fijo (`state=xyz`) | Es como no tenerlo | `openssl rand -hex 16` por cada login |
| `code_challenge_method=plain` | El verifier viaja en la URL: PKCE deja de proteger | S256 |
| Un `code_verifier` corto o predecible | Se adivina | 43-128 caracteres de `openssl rand` |
| Abrir la URL de autorización con `-k` en un servidor de pruebas | El código viaja por una conexión que no verificas | `--cacert` con la CA del servidor |

---

## 5. Trucos

- **La redirección se puede leer sin seguirla**: `-w '%{redirect_url}'`
  devuelve el `Location` resuelto sin `-L`. Es la forma de ver el código que
  el navegador habría entregado.
- **Algunos servidores no devuelven el error en `/token` sino en la
  redirección**: `redirect_uri?error=access_denied&state=...`. Mira siempre
  si la vuelta trae `error` antes de buscar `code`.
- **El simulador del laboratorio no exige el verifier** si el canje no lo
  manda, aunque la autorización llevara challenge. Un servidor real lo exige.
  Pruébalo en la práctica 02: es un buen ejemplo de por qué no se aprende
  seguridad de lo que un servidor permite.
- **Tampoco compara la `redirect_uri` del canje** con la de la autorización.
  El RFC 6749 (4.1.3) lo exige: es lo que impide que un código emitido para
  una URL se canjee anunciando otra.

---

## 📚 Recursos Adicionales

- [RFC 6749, apartado 4.1 — Authorization Code Grant](https://datatracker.ietf.org/doc/html/rfc6749#section-4.1)
- [RFC 7636 — Proof Key for Code Exchange (PKCE)](https://datatracker.ietf.org/doc/html/rfc7636)
- [RFC 8252 — OAuth 2.0 for Native Apps](https://datatracker.ietf.org/doc/html/rfc8252), sobre loopback y CLIs

---

## ✅ Checklist de Verificación

- [ ] Recorres los seis pasos sin mirar la tabla
- [ ] Calculas un `code_challenge` S256 y sabes por qué `echo` lo rompe
- [ ] Explicas qué frena el `state` y qué frena PKCE, y por qué no son lo mismo
- [ ] Canjeas un código con un cliente público, sin secreto
- [ ] Sabes por qué un código no se puede canjear dos veces
- [ ] Sabes qué dos comprobaciones del canje se salta el simulador
