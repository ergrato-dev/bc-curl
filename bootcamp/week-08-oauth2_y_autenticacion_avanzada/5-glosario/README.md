# Glosario — Semana 8: OAuth2 y Autenticacion Avanzada

## Terminos Principales

**OAuth2**
Protocolo de autorizacion (RFC 6749) que permite que aplicaciones accedan a recursos en nombre de un usuario o con identidad propia, sin compartir contraseñas. Define flujos estandarizados para distintos escenarios.

**Access Token**
Credencial de corta duracion que se presenta al Resource Server para acceder a recursos protegidos. Se envia en el header `Authorization: Bearer TOKEN`. Puede ser opaco (string random) o estructurado (JWT).

**Refresh Token**
Credencial de larga duracion que se usa exclusivamente con el Authorization Server para obtener nuevos access tokens sin intervencion del usuario. Debe guardarse con maxima seguridad.

**Client Credentials**
Flujo OAuth2 para autenticacion maquina-a-maquina. El cliente se autentica con su propio `client_id` y `client_secret` para obtener un token, sin usuario involucrado.

**Authorization Code**
Flujo OAuth2 para actuar en nombre de un usuario. El usuario autoriza en el browser, el servidor devuelve un `code` de un solo uso, que el cliente intercambia por tokens. Es el flujo mas seguro para aplicaciones que representan usuarios.

**PKCE**
Proof Key for Code Exchange (RFC 7636). Extension del flujo Authorization Code para apps publicas que no pueden guardar un `client_secret` de forma segura. Usa un par `code_verifier`/`code_challenge` generado en el cliente.

**JWT**
JSON Web Token (RFC 7519). Formato de token compacto con tres partes en base64url: `header.payload.signature`. El payload contiene claims (afirmaciones) verificables. La firma garantiza integridad.

**Bearer**
Esquema de autenticacion HTTP para tokens. `Authorization: Bearer TOKEN`. Cualquier portador del token tiene acceso — por eso es importante protegerlos.

**grant_type**
Parametro en el request al token endpoint que indica que flujo OAuth2 se esta usando. Valores comunes: `client_credentials`, `authorization_code`, `refresh_token`.

**scope**
Cadena que define el nivel de acceso que solicita el cliente. Ejemplo: `read:user write:repos`. El servidor puede otorgar menos scopes que los solicitados. Principio de minimo privilegio: pedir solo lo necesario.

**expires_in**
Campo en la respuesta del token endpoint que indica cuantos segundos durara el access token. Tipicamente 3600 (1 hora). Permite calcular el timestamp de expiracion: `expiry = now + expires_in`.

**iss (issuer)**
Claim estandar de JWT. Identifica quien emitio el token. El Resource Server debe verificar que el `iss` coincide con el Authorization Server esperado.

**sub (subject)**
Claim estandar de JWT. Identifica el "sujeto" del token — quien es el usuario o aplicacion representada. Puede ser un ID de usuario, un ID de cliente, etc.

**exp (expiration time)**
Claim estandar de JWT. Unix timestamp en que el token deja de ser valido. El Resource Server rechaza tokens con `exp` en el pasado.

**aud (audience)**
Claim estandar de JWT. Identifica los destinatarios del token. El Resource Server debe verificar que esta en el `aud`. Previene que un token de un servicio sea usado en otro.

**iat (issued at)**
Claim estandar de JWT. Unix timestamp de cuando fue creado el token. Util para auditoría y para detectar tokens demasiado viejos aunque no hayan expirado.

**Authorization Server**
El servidor que autentica al usuario/cliente y emite tokens. Ejemplos: Keycloak, Auth0, GitHub OAuth, Google Identity Platform.

**Resource Server**
El servidor que tiene los datos protegidos y acepta tokens como credencial de acceso. Ejemplos: GitHub API, Google Calendar API, tu propia API.

**Resource Owner**
El usuario que posee los datos a los que se quiere acceder. En Client Credentials no hay Resource Owner — el cliente accede con su propia identidad.

**OIDC (OpenID Connect)**
Capa de identidad construida sobre OAuth2. Agrega el ID Token (JWT que contiene informacion del usuario) y el endpoint `/userinfo`. Convierte OAuth2 (autorizacion) en un sistema de autenticacion.

**Token Introspection**
Endpoint del Authorization Server (RFC 7662) donde el Resource Server puede verificar si un token opaco es valido y obtener sus claims. Para JWT se puede verificar localmente con la clave publica del servidor.

**JWKS**
JSON Web Key Set. Endpoint (tipicamente `/.well-known/jwks.json`) donde el Authorization Server publica sus claves publicas. Usado por Resource Servers para verificar firmas de JWT sin contactar al Authorization Server en cada request.
