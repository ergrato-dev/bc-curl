# Glosario — Semana 08

Términos de OAuth2, PKCE, JWT y sesiones que aparecen esta semana. El término
real en inglés va entre paréntesis, y los flags que no son universales llevan
**su versión mínima**. Los términos de todo el bootcamp están en
[`docs/glosario-global.md`](../../../docs/glosario-global.md).

---

## A

**Access token** · La credencial que el cliente manda a la API, normalmente
como `Authorization: Bearer`. Vive poco (una hora en el laboratorio). Para el
cliente es opaco, aunque sea un JWT.

**`aud`** (*audience*) · Claim de un JWT: para qué API es el token. Una API
debe rechazar un token con otro `aud`.

**Authorization code** · Flujo en el que una persona hace login en el
navegador y el servidor devuelve un código de un solo uso que el cliente
cambia por un token. Con PKCE, siempre.

**`authorization_pending`** · Error del sondeo de device code que no es un
fallo: la persona todavía no ha aprobado. Se espera `interval` y se repite.

## B

**base64url** · Variante de base64 que se puede poner en una URL: `-` y `_` en
vez de `+` y `/`, y sin relleno `=`. La usan los JWT y el challenge de PKCE.

**Bearer** · Tipo de token que vale para quien lo tenga, sin más prueba
(RFC 6750). Por eso no se imprime nunca.

## C

**Claim** · Cada campo del payload de un JWT: `iss`, `sub`, `aud`, `exp`...
Es lo que el token afirma, no lo que está comprobado.

**Client credentials** · Flujo en el que una máquina pide un token en nombre
propio, con su `client_id` y su `client_secret`. No da refresh token.

**Cliente confidencial / público** (*confidential / public client*) · El
confidencial puede guardar un secreto (un servidor, un cron); el público no
(un CLI repartido, una app móvil). El público se apoya solo en PKCE.

**`code_challenge`** · El SHA-256 del verifier en base64url (método S256). Va
en la URL de autorización.

**`code_verifier`** · Cadena aleatoria de 43 a 128 caracteres que el cliente
guarda y manda solo en el canje. Demuestra que quien canjea es quien pidió.

**`--config`, `-K`** · Lee opciones de curl desde un archivo. Con permisos 600,
es donde el toolkit pone el secreto del cliente y los tokens: no aparecen en
`ps`.

## D

**`--data-urlencode`** (7.18.0+) · Codifica el valor para un formulario. Una
línea `data-urlencode = "campo=valor"` por campo en el `--config` del
endpoint de token.

**Device code** · Flujo para una persona en una máquina sin navegador: el
programa enseña un código corto, la persona lo aprueba en otro aparato, y el
programa sondea `/token` (RFC 8628). El laboratorio no lo implementa.

**Discovery** · El documento `/.well-known/openid-configuration` (o
`oauth-authorization-server`) donde el servidor publica sus endpoints
(RFC 8414).

## E

**`exp`** (*expiration*) · Claim de un JWT: instante de caducidad, en segundos
desde 1970. Lo que el servidor prometió, no lo que va a cumplir.

**`expires_at`** · Campo que añade el toolkit a la sesión: `date +%s` +
`expires_in` en el momento de recibir el token. Se compara con el reloj en
cualquier momento.

**`expires_in`** · Segundos de vida del token **desde la respuesta**. Guardado
tal cual, no dice nada una hora después.

## I

**`id_token`** · Token de OpenID Connect que dice quién hizo login. Es para el
cliente, que sí debe validarlo si lo usa. Esta semana no se usa.

**Introspección** (*token introspection*) · Preguntarle al servidor si un token
está activo (RFC 7662). Responde `{"active": false}` sin decir por qué.

**`invalid_client`** · Error del endpoint de token: la autenticación del
cliente falló o falta. El toolkit sale con 77.

**`invalid_grant`** · Error del endpoint de token: el código, el verifier o el
refresh token no valen. Sin arreglo automático: 77 y `auth login`.

**`iss`** (*issuer*) · Claim de un JWT: quién lo emitió.

## J

**`jti`** (*JWT ID*) · Identificador único del token. Lo que se apunta en un
log para saber qué token se usó, sin enseñarlo.

**JWKS** (*JSON Web Key Set*) · El conjunto de claves públicas del servidor,
publicado en `jwks_uri`. La API valida la firma con la que indica el `kid`.

**JWT** (*JSON Web Token*) · Tres trozos en base64url separados por puntos:
cabecera, payload y firma (RFC 7519). Se lee con `base64`; se valida con la
clave pública.

## K

**`kid`** (*key ID*) · Campo de la cabecera del JWT: qué clave del JWKS lo
firmó.

## M

**Margen de caducidad** · Segundos antes de `expires_at` en los que el toolkit
ya renueva: `MARGEN_CADUCIDAD=30`. Cubre la red y un reloj desajustado.

## O

**OAuth 2.0** · Marco para que un programa obtenga acceso limitado a una API
sin la contraseña del usuario (RFC 6749). Varios flujos, según quién actúa.

**OAuth 2.1** · Revisión en borrador que recoge las buenas prácticas: PKCE
siempre, sin flujo implícito ni *password grant*.

**`--oauth2-bearer`** (7.61.0+ para HTTP) · Manda `Authorization: Bearer
TOKEN`. Pone el token en los argumentos del proceso: en un script, mejor un
`header` en el `--config`.

**OpenID Connect** · Capa de identidad sobre OAuth2: añade el `id_token` y
`/userinfo`. El discovery del laboratorio es el suyo.

## P

**Password grant** (*resource owner password credentials*) · Flujo en el que
el cliente recibe la contraseña del usuario. Prohibido por el RFC 9700.

**PKCE** (*Proof Key for Code Exchange*, se pronuncia "pixie") · El verifier y
el challenge que atan el código de autorización al cliente que lo pidió
(RFC 7636).

## R

**`redirect_uri`** · La URL a la que el servidor devuelve el código. Tiene que
estar registrada, y el canje debe repetir la misma.

**`%{redirect_url}`** (7.18.2+) · Variable de `--write-out`: la URL a la que lleva un
redirect, sin seguirlo. Lee el código de la redirección en la práctica 02.

**Refresh token** · Credencial de larga vida que sirve para pedir access
tokens nuevos sin que la persona vuelva a hacer login. Conserva la identidad.

**Revocación** (*token revocation*) · Pedirle al servidor que invalide un
token (RFC 7009). Responde 200 también a tokens que no existen.

**RFC 9700** · *OAuth 2.0 Security Best Current Practice*: lo que hoy es
obligatorio o está prohibido en OAuth2.

**Rotación** (*refresh token rotation*) · El servidor devuelve un refresh
token nuevo en cada renovación e invalida el anterior. El laboratorio no rota.

## S

**Scope** · Los permisos que se piden, separados por espacios. El servidor
devuelve los concedidos, que pueden ser menos.

**Servidor de autorización** (*authorization server*) · El que emite los
tokens: `/authorize`, `/token`, `/revoke`. En el laboratorio, el puerto 8081.

**Servidor de recursos** (*resource server*) · La API que acepta el token y lo
valida en cada petición.

**Sesión** · El archivo `OAUTH_SESSION_FILE` (`~/.bc-curl-session`): la
respuesta del endpoint de token más `expires_at`, con permisos 600.

**`slow_down`** · Error del sondeo de device code: sondeas demasiado deprisa.
Se suman 5 segundos a `interval`.

**`state`** · Valor aleatorio que el cliente manda en la autorización y
comprueba en la vuelta. Frena el CSRF.

**`sub`** (*subject*) · Claim de un JWT: de quién es el token. `api-toolkit`
con client credentials, `alumno` con authorization code.

## T

**Token endpoint** · `/token`: recibe un formulario (nunca JSON) con el
`grant_type` y la autenticación del cliente, y devuelve el token.

**`token_type_hint`** · Pista de qué tipo de token se revoca:
`refresh_token` o `access_token`. El simulador la exige.

## U

**`unsupported_token_type`** · Error de `/revoke`: el servidor no revoca ese
tipo de token. El toolkit avisa y borra la sesión.

**`user_code`** · El código corto de device code que la persona escribe en
otro aparato. Es lo único de ese flujo que se enseña en pantalla.

---

| Anterior | Siguiente |
|---|---|
| [Recursos](../4-recursos/README.md) | [README de la Semana 08](../README.md) |

[← Glosario global del bootcamp](../../../docs/glosario-global.md)
