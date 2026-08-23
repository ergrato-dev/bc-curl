# Libros y RFC gratuitos — Semana 03

_Comprobado el 23 de agosto de 2026._

## Libros

| Recurso | Por qué vale la pena |
|---|---|
| [everything.curl.dev — HTTP authentication](https://everything.curl.dev/http/auth.html) | El capítulo de autenticación del libro oficial de curl, escrito por su autor. Cubre los esquemas y, sobre todo, cuándo curl manda la credencial de entrada y cuándo espera al reto |
| [everything.curl.dev — Config file](https://everything.curl.dev/cmdline/configfile.html) | El formato de `--config` con sus reglas de comillas, que es lo que el manpage explica peor. Incluye `--config -` para leer de stdin |
| [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html) | Corto y práctico. Explica por qué la variable de entorno tampoco es el destino final de un secreto, y qué viene después |
| [OWASP API Security Top 10 (2023)](https://owasp.org/API-Security/editions/2023/en/0x00-header/) | Los fallos reales de autenticación en APIs, con casos. `API2:2023` es el de esta semana |

## RFC

Se leen enteros en una tarde y son la fuente de verdad cuando la documentación
de una API se contradice consigo misma.

| RFC | Por qué vale la pena |
|---|---|
| [RFC 9110 §11](https://datatracker.ietf.org/doc/html/rfc9110#section-11) | El marco: el reto `WWW-Authenticate`, la respuesta `Authorization` y el `realm`. Todo lo demás son esquemas concretos dentro de este marco |
| [RFC 7617](https://datatracker.ietf.org/doc/html/rfc7617) | Basic Auth completo en ocho páginas. Incluye la parte del juego de caracteres, que es la causa de los `401` con tildes |
| [RFC 6750](https://datatracker.ietf.org/doc/html/rfc6750) | Bearer. La sección de consideraciones de seguridad explica exactamente qué puede hacer quien robe un token |
| [RFC 7519](https://datatracker.ietf.org/doc/html/rfc7519) | JWT: el formato y los claims registrados. La tabla de `exp`, `iat` y `nbf` es la que consultarás |
| [RFC 8725](https://datatracker.ietf.org/doc/html/rfc8725) | Las malas prácticas de JWT recogidas por quienes las han visto fallar, incluido el ataque de `alg: none` |
| [RFC 7616](https://datatracker.ietf.org/doc/html/rfc7616) | Digest. Útil para entender por qué necesita el `nonce` y por qué eso obliga a la petición extra |
| [RFC 4648](https://datatracker.ietf.org/doc/html/rfc4648) | Base64 y base64url en el mismo documento. La §5 es la que explica el `-`, el `_` y la ausencia de relleno |

---

| Anterior | Siguiente |
|---|---|
| [Recursos de la semana](../README.md) | [Videografía](../videografia/README.md) |
