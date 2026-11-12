# El problema que resuelve OAuth2

> En la Semana 03 la credencial era tuya y la pegabas en una variable. OAuth2
> existe para el caso en que no lo es: un programa necesita actuar en una API,
> a veces en nombre de una persona, y nadie quiere darle la password de esa
> persona ni una clave que valga para siempre.

![Los cuatro roles de OAuth2: el propietario del recurso (una persona) autoriza; el cliente (tu script) pide un token al servidor de autorización, que se lo entrega; el cliente presenta el token al servidor de recursos (la API), que lo valida sin ver nunca la password de la persona. Debajo, la tabla de qué flujo usar según quién actúa](../0-assets/01-el-problema-que-resuelve-oauth2.svg)

## 🎯 Objetivos

- Explicar qué problema tenía la password compartida y qué resuelve un token delegado
- Identificar los cuatro roles de OAuth2 en una integración concreta
- Distinguir access token, refresh token, scope y grant
- Elegir el flujo según quién está detrás de la petición

---

## 1. Qué problema resuelve

Una herramienta de informes quiere leer tus repositorios privados de una forja
de código. La solución ingenua es la de 2005: le das tu usuario y tu password.

| Lo que pasa | Por qué duele |
|---|---|
| La herramienta guarda tu password | Si la filtran, tienen tu cuenta entera, no solo los repositorios |
| La password vale para todo | La herramienta podría borrar repositorios, cambiar tu email, crear tokens |
| No caduca | Sigue valiendo hasta que cambies la password, y entonces se rompen todas las integraciones a la vez |
| No se puede retirar a una sola herramienta | Revocar el acceso de una es cambiar la password de todas |
| El 2FA lo hace imposible | La herramienta no tiene tu móvil |

Las claves de API de la Semana 03 arreglan parte: no son tu password y se
pueden borrar una a una. Pero siguen valiendo para siempre, casi nunca se
pueden limitar a "solo leer", y alguien tiene que copiarlas a mano de una web
a un archivo.

OAuth2 (RFC 6749) cambia el modelo: **el programa no recibe una credencial
tuya, recibe un permiso**. Ese permiso es un *access token* que:

- Caduca solo, normalmente en minutos u horas
- Vale para lo que se pidió (el *scope*), no para todo
- Lo emite un servidor que sabe a quién, para qué y hasta cuándo
- Se puede revocar sin tocar la password de nadie

---

## 2. Cómo funciona

### 2.1 Los cuatro roles

| Rol | Quién es | En el laboratorio |
|---|---|---|
| Propietario del recurso (*resource owner*) | La persona dueña de los datos | `alumno`, el usuario que escribes en el login de la práctica 02 |
| Cliente (*client*) | El programa que quiere acceder | Tu script, `api-toolkit` |
| Servidor de autorización (*authorization server*) | Quien autentica y emite tokens | `http://localhost:8081/default`, con `/token`, `/authorize` y `/revoke` |
| Servidor de recursos (*resource server*) | La API que valida el token y sirve los datos | `/userinfo` del mismo servidor, que solo responde con un token válido |

En una API real, los dos servidores suelen ser máquinas distintas: el de
autorización es de un proveedor de identidad y el de recursos es la API. Lo
que importa es que **el servidor de recursos nunca ve la password**: solo ve
tokens.

### 2.2 El vocabulario

| Término | Qué es | Dónde lo ves |
|---|---|---|
| *Access token* | El permiso. Viaja en `Authorization: Bearer ...` en cada petición a la API | `.access_token` de la respuesta de `/token` |
| *Refresh token* | Una credencial para pedir otro access token sin volver a preguntar a la persona. Nunca va a la API, solo al servidor de autorización | `.refresh_token`, en los flujos con persona |
| *Scope* | Para qué vale el token, como texto separado por espacios | `scope=leer escribir` en la petición; `.scope` en la respuesta |
| *Grant* | La forma de conseguir el token: el flujo | `grant_type=client_credentials`, `authorization_code`, `refresh_token` |
| *Client ID* y *client secret* | El usuario y la password **del programa**, no de la persona | Los registra quien opera la API |
| *Bearer* | "Al portador": quien tenga el token, lo usa. No hay nada más que lo ate a ti | El header `Authorization` |

> [!WARNING]
> *Bearer* significa exactamente eso. Un access token copiado de un log
> funciona igual de bien en la máquina del atacante que en la tuya, hasta que
> caduque. Por eso caduca pronto, y por eso esta semana se insiste tanto en no
> imprimirlo.

### 2.3 Los flujos

Todos terminan igual: un `POST` al endpoint de token que devuelve un JSON con
`access_token`. Cambia **qué prueba presenta el cliente** para conseguirlo.

| Flujo | Qué presenta el cliente | Para quién |
|---|---|---|
| Client credentials | Su propio ID y secreto | Una máquina que actúa en nombre propio |
| Authorization code + PKCE | Un código de un solo uso que la persona consiguió al hacer login en el navegador | Una persona con navegador |
| Device code | Un código de dispositivo que la persona aprobó desde otro aparato | Una persona sin navegador en esa máquina |
| Refresh token | El refresh token de una sesión anterior | Renovar cualquiera de los dos anteriores |
| ~~Password~~ | El usuario y la password de la persona | Nadie: el RFC 9700 lo prohíbe |
| ~~Implicit~~ | Nada: el token llegaba en la URL del navegador | Nadie: retirado por lo mismo |

### 2.4 OAuth2 y OpenID Connect

El servidor del laboratorio habla también OpenID Connect (OIDC), una capa
sobre OAuth2 que añade **quién es la persona**: un `id_token` y el endpoint
`/userinfo`. OAuth2 responde "¿qué puede hacer este programa?"; OIDC añade
"¿quién ha hecho login?". Esta semana se usa poco OIDC, pero de él viene el
documento de *discovery* que lista todos los endpoints.

---

## 3. Cómo se usa

El servidor del laboratorio publica su configuración en una ruta estándar.
Es lo primero que se mira ante un servidor OAuth2 desconocido:

```bash
# /.well-known/openid-configuration es la ruta de discovery de OIDC (RFC 8414
# define la equivalente para OAuth2 puro). Lista los endpoints y lo que soporta.
curl -sS --max-time 5 http://localhost:8081/default/.well-known/openid-configuration \
  | jq '{token_endpoint, authorization_endpoint, revocation_endpoint, jwks_uri}'
# {
#   "token_endpoint": "http://localhost:8081/default/token",
#   "authorization_endpoint": "http://localhost:8081/default/authorize",
#   "revocation_endpoint": "http://localhost:8081/default/revoke",
#   "jwks_uri": "http://localhost:8081/default/jwks"
# }
```

El servidor de recursos rechaza a quien no trae token:

```bash
curl -sS --max-time 5 -o /dev/null -w '%{http_code}\n' \
  http://localhost:8081/default/userinfo
# 401
```

Y la primera petición OAuth2 de la semana, la más corta posible. La práctica
01 la rehace bien; esta solo enseña la forma:

```bash
# CONTRASTE: el secreto va en la linea de comandos y lo ve cualquiera con ps.
# La teoria 02 explica como sacarlo de ahi.
curl -sS --max-time 5 -u api-toolkit:secreto-de-laboratorio \
  -d grant_type=client_credentials \
  http://localhost:8081/default/token | jq 'del(.access_token)'
# {
#   "token_type": "Bearer",
#   "expires_in": 3599
# }
```

`del(.access_token)` no es decoración: el token es una credencial y esta
semana no se imprime nunca entero, ni siquiera en un ejemplo.

> [!NOTE]
> El servidor del laboratorio acepta **cualquier** `client_id` y cualquier
> secreto: es un simulador. Un servidor real solo acepta los clientes que
> alguien registró, y un secreto incorrecto da `invalid_client`. La práctica
> 01 provoca ese error quitando el secreto.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Pedir la password de la persona para conseguir un token (*password grant*) | El cliente ve la password, no hay 2FA posible y la persona no sabe a qué ha dado acceso | Authorization code + PKCE, o device code si no hay navegador |
| Usar client credentials para actuar "en nombre de" una persona | El token es del programa: la API no sabe qué persona hay detrás y los permisos son los del programa, que suelen ser más | El flujo con persona que toque |
| Pedir todos los scopes "por si acaso" | Un token filtrado vale para todo lo que pediste | El scope mínimo que necesita la operación |
| Tratar el access token como una clave de API: copiarlo a un archivo y olvidarse | Caduca en una hora y el script falla a las tres de la mañana | Guardar la sesión y renovarla (teoría 06) |
| Mandar el refresh token a la API | La API no lo necesita, y ahora lo tiene alguien más | El refresh token solo va al endpoint de token |

---

## 5. Trucos

- **El discovery dice qué soporta el servidor**, no solo dónde está. Mira
  `grant_types_supported` y `code_challenge_methods_supported` antes de
  elegir flujo. El del laboratorio no publica la primera: no soporta device
  code, y la teoría 05 lo explica con un servidor real.
- **`/userinfo` es un servidor de recursos de bolsillo.** Valida la firma del
  token y responde quién es: perfecto para comprobar que un token funciona
  sin montar una API.
- **El `client_id` no es secreto.** Va en URLs, en logs y en el navegador. El
  secreto sí.
- **Un simulador no es la especificación.** El del laboratorio acepta
  cualquier secreto, no exige la misma `redirect_uri` en el canje y responde
  `invalid_grant` a un grant desconocido. Las prácticas señalan cada
  diferencia: apréndelas del RFC, no de lo que el servidor deja pasar.

---

## 📚 Recursos Adicionales

- [RFC 6749 — The OAuth 2.0 Authorization Framework](https://datatracker.ietf.org/doc/html/rfc6749), secciones 1.1 (roles) y 1.3 (grants)
- [RFC 9700 — Best Current Practice for OAuth 2.0 Security](https://datatracker.ietf.org/doc/html/rfc9700)
- [oauth.net — OAuth 2.1](https://oauth.net/2.1/)

---

## ✅ Checklist de Verificación

- [ ] Explicas por qué un token delegado es mejor que una password compartida, con tres razones
- [ ] Nombras los cuatro roles en la integración del laboratorio
- [ ] Sabes qué va a la API (access token) y qué nunca va (refresh token, client secret)
- [ ] Eliges flujo para un cron, para una persona con navegador y para una sesión SSH
- [ ] Sacas los endpoints del laboratorio del documento de discovery
