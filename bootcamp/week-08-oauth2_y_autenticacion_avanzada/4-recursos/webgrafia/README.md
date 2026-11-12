# Webgrafía — Semana 08

_Comprobado el 11 de noviembre de 2026._

## Las especificaciones

| Recurso | Por qué vale la pena |
|---|---|
| [RFC 6749 — The OAuth 2.0 Authorization Framework](https://datatracker.ietf.org/doc/html/rfc6749) | La base. Los apartados 4.1 (authorization code), 4.4 (client credentials), 5.2 (errores) y 6 (refresh) son los que usa el toolkit |
| [RFC 6750 — Bearer Token Usage](https://datatracker.ietf.org/doc/html/rfc6750) | Cómo viaja el access token a la API, y qué significa el `WWW-Authenticate` de un 401 |
| [RFC 7636 — PKCE](https://datatracker.ietf.org/doc/html/rfc7636) | El verifier, el challenge S256 y lo que el servidor comprueba. Corto y directo |
| [RFC 7009 — Token Revocation](https://www.rfc-editor.org/rfc/rfc7009) | Por qué `/revoke` responde 200 a un token que no existe, y qué es `unsupported_token_type` |
| [RFC 8252 — OAuth 2.0 for Native Apps](https://datatracker.ietf.org/doc/html/rfc8252) | La redirección a loopback en un CLI, y por qué un cliente nativo es público |
| [RFC 8414 — Authorization Server Metadata](https://datatracker.ietf.org/doc/html/rfc8414) | El documento de discovery: qué campos publica un servidor y cuáles son opcionales |
| [RFC 9700 — OAuth 2.0 Security Best Current Practice](https://datatracker.ietf.org/doc/html/rfc9700) | Lo que hoy está prohibido o es obligatorio: sin *password grant*, PKCE siempre, rotación de refresh tokens en clientes públicos |
| [OAuth 2.1 (borrador)](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1) | RFC 6749 con diez años de lecciones aplicadas. Hacia donde va todo |

## Guías y referencias

| Recurso | Por qué vale la pena |
|---|---|
| [oauth.net — OAuth 2.0](https://oauth.net/2/) | El índice de todo: cada flujo, cada extensión y su RFC, en una página |
| [oauth.net — OAuth 2.1](https://oauth.net/2.1/) | Resumen de lo que cambia frente a 2.0, en una lista |
| [OWASP — OAuth2 Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/OAuth2_Cheat_Sheet.html) | Las comprobaciones de seguridad de un cliente y un servidor OAuth2, en formato lista |
| [PortSwigger — OAuth 2.0 authentication vulnerabilities](https://portswigger.net/web-security/oauth) | Los ataques reales contra el `state`, la `redirect_uri` y el código, con laboratorios. Lo que pasa cuando falta alguna pieza de la teoría 04 |
| [PortSwigger — JWT attacks](https://portswigger.net/web-security/jwt) | `alg: none`, claves débiles y confusión de algoritmos: por qué la API, y no el cliente, valida el JWT |
| [jwt.io — Introduction to JSON Web Tokens](https://jwt.io/introduction) | Las tres partes y los claims, con diagramas. No pegues ahí un token de verdad: decodifícalo con `claims_jwt` |
| [GitHub — Authorizing OAuth apps](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps) | Authorization code y device code en un proveedor real, con sus errores propios. El ejemplo opcional de la teoría 05 |

## curl y el laboratorio

| Recurso | Por qué vale la pena |
|---|---|
| [`--oauth2-bearer`](https://curl.se/docs/manpage.html#--oauth2-bearer) | 7.61+ para HTTP (la opción es de la 7.33, solo para correo). Manda el `Authorization: Bearer`; el toolkit usa un `header` en el `--config` para que el token no vaya en la línea |
| [mock-oauth2-server](https://github.com/navikt/mock-oauth2-server) | El simulador del laboratorio. Su README dice qué implementa y qué no: útil cuando algo del laboratorio no coincide con el RFC |

---

| Anterior | Siguiente |
|---|---|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
