# Client credentials

> El flujo más corto de OAuth2 y el que más usa un script: no hay persona, no
> hay navegador, no hay redirección. Un programa se presenta con su ID y su
> secreto y recibe un token a su nombre. Lo difícil no es pedirlo: es saber
> cuándo **no** es este el flujo.

![Secuencia de client credentials: el script envía al servidor de autorización un POST a /token con grant_type=client_credentials, el scope y su autenticación Basic; recibe access_token y expires_in sin refresh_token; lo guarda junto a su instante de caducidad y lo presenta como Bearer a la API en cada petición; cuando caduca, vuelve a pedir otro con las mismas credenciales](../0-assets/03-client-credentials.svg)

## 🎯 Objetivos

- Describir el flujo de client credentials paso a paso
- Explicar por qué no devuelve refresh token y qué se hace cuando el token caduca
- Pedir el scope mínimo y comprobar el que concede el servidor
- Reconocer los casos en que client credentials es el flujo equivocado

---

## 1. Qué problema resuelve

Un cron consulta cada noche una API de facturación. Nadie está delante. Las
opciones de la Semana 03 eran una clave de API eterna o el usuario y la
password de una persona. Las dos son malas:

- La clave eterna vale hasta que alguien se acuerde de borrarla.
- La password de una persona ata el cron a esa persona: si se va de la
  empresa o activa 2FA, el cron se rompe, y mientras tanto el cron puede
  hacer todo lo que puede ella.

Client credentials (RFC 6749, 4.4) le da al cron **identidad propia**: un
cliente registrado con su ID y su secreto, que pide tokens de vida corta con
el scope que necesita. Si el secreto se filtra, se rota ese cliente y nadie
más se entera.

---

## 2. Cómo funciona

### 2.1 El flujo

Un único intercambio:

```text
POST /token
Authorization: Basic base64(client_id:client_secret)
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials&scope=leer
```

```json
{"access_token": "eyJ...", "token_type": "Bearer", "expires_in": 3599, "scope": "leer"}
```

Y desde ahí, `Authorization: Bearer eyJ...` en cada petición a la API hasta
que caduque.

### 2.2 Sin refresh token

El RFC lo dice expresamente (4.4.3): en client credentials **no se debería
emitir refresh token**. No hace falta: el cliente tiene a mano la credencial
que le dio el primer token, y pedir otro cuesta lo mismo que refrescar.

Consecuencia práctica: renovar es repetir el login. Es lo que hace `renovar`
en el toolkit cuando la sesión no trae `refresh_token`.

### 2.3 Pedir uno y reutilizarlo

Pedir un token nuevo para cada petición funciona en el laboratorio y es un
error en producción:

| Token por petición | Token reutilizado hasta que caduca |
|---|---|
| Dos peticiones HTTP por cada llamada a la API | Una petición al servidor de tokens por hora |
| El servidor de tokens suele tener su propio rate limit, más bajo | Fuera del rate limit |
| Si el servidor de tokens cae, cae todo | Si cae, sigues trabajando hasta que caduque el token que tienes |
| Cada token nuevo es una firma criptográfica en el servidor | — |

Por eso el toolkit guarda la sesión en disco (teoría 08) y solo pide otro
token cuando el que tiene está a punto de caducar (teoría 06).

### 2.4 El scope

El scope es una lista de palabras separadas por espacios. Qué palabras
existen lo decide cada API (`repo`, `read:org`, `invoices.read`...).

- **Pide el mínimo.** Un token con `leer` filtrado hace menos daño que uno
  con `leer escribir borrar`.
- **Mira el `scope` de la respuesta.** El servidor puede concederte menos de
  lo que pediste y, si no lo comprueba nadie, el error llega después como un
  403 de la API.
- **Sin `scope`**, el servidor aplica el que tenga configurado por defecto
  para ese cliente. El del laboratorio no pone ninguno.

### 2.5 Quién es el token

En client credentials, el sujeto del token (`sub`) es **el propio cliente**:

```bash
# Con el respuesta.json del apartado 3. claims_jwt es la funcion del toolkit;
# aqui, la misma idea en una linea. La teoria 07 la explica.
jq -r .access_token respuesta.json | cut -d. -f2 | tr '_-' '/+' | base64 -d 2>/dev/null | jq '{sub, iss}'
# {
#   "sub": "api-toolkit",
#   "iss": "http://localhost:8081/default"
# }
```

Para la API, quien hace las peticiones es `api-toolkit`, no una persona. Los
permisos y la auditoría son los del cliente.

### 2.6 Cuándo no es este el flujo

| Situación | Por qué client credentials no sirve | Flujo correcto |
|---|---|---|
| El script actúa sobre los datos de una persona concreta | El token no lleva a la persona; la API no puede aplicar sus permisos | Authorization code + PKCE o device code |
| Un CLI que distribuyes a cien usuarios | El secreto viaja dentro del CLI y deja de ser secreto: es un *public client* | Authorization code + PKCE o device code, sin secreto |
| Una app de navegador o de móvil | Igual: cualquiera puede extraer el secreto | Authorization code + PKCE |
| Tu propio cron, en tu servidor, con su secreto en `~/.bc-curl` | — | **Este**. Es el caso del toolkit |

> [!IMPORTANT]
> Un secreto solo es secreto si vive en una máquina que controlas. En cuanto
> el programa se reparte, el cliente es público y el flujo tiene que funcionar
> sin secreto. Por eso PKCE existe.

### 2.7 Más allá del secreto compartido

Un secreto compartido se puede filtrar. Hay dos formas de autenticar al
cliente sin él, que verás en proveedores grandes:

| Método | Cómo | Relación con el bootcamp |
|---|---|---|
| `tls_client_auth` (RFC 8705) | El cliente se autentica con un certificado en el handshake TLS | El mTLS de la Semana 05, con `--cert` y `--key` |
| `private_key_jwt` (RFC 7523) | El cliente firma un JWT corto con su clave privada y lo manda como `client_assertion` | Necesita firmar con `openssl`; fuera del alcance de esta semana |

---

## 3. Cómo se usa

El flujo completo, con el secreto fuera de la línea de comandos:

```bash
config=$(umask 077 && mktemp)
printf '%s\n' 'user = "api-toolkit:secreto-de-laboratorio"' \
  'data-urlencode = "grant_type=client_credentials"' \
  'data-urlencode = "scope=leer"' > "$config"

curl -sS --max-time 10 --config "$config" -o respuesta.json \
  http://localhost:8081/default/token
jq '{token_type, expires_in, scope}' respuesta.json
# {
#   "token_type": "Bearer",
#   "expires_in": 3599,
#   "scope": "leer"
# }
```

Y el token contra el servidor de recursos. El header también va en un
archivo, para que el token no pase por la línea de comandos:

```bash
# printf es un builtin de bash: el token no aparece en ningun argv.
printf 'header = "Authorization: Bearer %s"\n' "$(jq -r .access_token respuesta.json)" > "$config"
curl -sS --max-time 10 --config "$config" http://localhost:8081/default/userinfo | jq -r .sub
# api-toolkit
rm -f "$config" respuesta.json
```

Con el toolkit, todo eso es una línea (la práctica 01 lo monta paso a paso):

```bash
./api-toolkit.sh auth login
# sesion guardada en /home/tu-usuario/.bc-curl-session
```

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Un token nuevo por cada petición | Duplica las peticiones, choca con el rate limit del servidor de tokens y hace de él un punto único de fallo | Guardar el token y reutilizarlo hasta que caduque |
| El secreto del cliente dentro de un CLI que se reparte | Cualquiera lo extrae con `strings` | Un flujo sin secreto: PKCE o device code |
| Usar el cliente de producción en el portátil para probar | Un secreto con permisos de producción en una máquina que viaja | Un cliente por entorno, con su scope |
| Ignorar el `scope` de la respuesta | El 403 llega más tarde y nadie sabe por qué | Comparar el concedido con el pedido |
| Guardar `expires_in` tal cual | Dentro de una hora nadie sabe desde cuándo contaba | Guardar `expires_at` (teoría 06) |

---

## 5. Trucos

- **El servidor del laboratorio pone el scope en `aud`.** Si pides
  `scope=leer`, el token sale con `"aud": "leer"`. Es una rareza del
  simulador, útil para ver en el JWT qué pediste; un servidor real pone en
  `aud` la API a la que va destinado el token.
- **Algunos proveedores llaman `audience` o `resource` a un campo extra** del
  formulario para elegir la API destino. El `resource` es estándar (RFC
  8707); `audience` no.
- **Rotar el secreto sin cortar el servicio**: la mayoría de proveedores
  admiten dos secretos activos a la vez. Se crea el nuevo, se despliega, y se
  borra el viejo.

---

## 📚 Recursos Adicionales

- [RFC 6749, apartado 4.4 — Client Credentials Grant](https://datatracker.ietf.org/doc/html/rfc6749#section-4.4)
- [RFC 8705 — OAuth 2.0 Mutual-TLS Client Authentication](https://datatracker.ietf.org/doc/html/rfc8705)
- [oauth.net — Client Credentials](https://oauth.net/2/grant-types/client-credentials/)

---

## ✅ Checklist de Verificación

- [ ] Pides un token de client credentials con el secreto en un `--config`
- [ ] Explicas por qué no hay refresh token y qué hace el toolkit en su lugar
- [ ] Compruebas el `scope` concedido en la respuesta
- [ ] Sabes por qué un CLI repartido no puede usar client credentials
- [ ] Ves en el `sub` del token que el sujeto es el cliente, no una persona
