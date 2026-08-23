# Libros y especificaciones gratuitas — Semana 02

_Comprobado en agosto de 2026._

## Libros

### [everything.curl.dev](https://everything.curl.dev/) — Daniel Stenberg

El libro oficial de curl, escrito por su autor, gratis y en HTML. Para esta
semana, tres capítulos concretos:

- [HTTP POST](https://everything.curl.dev/http/post) — por qué `-d` hace las tres cosas que hace
- [POST binary](https://everything.curl.dev/http/post/binary) — la diferencia entre `-d` y `--data-binary`, explicada por quien la implementó
- [Request method](https://everything.curl.dev/http/requests/method) — incluye la advertencia sobre `-X` y las redirecciones, que casi ningún tutorial menciona

**Por qué vale la pena**: es la única fuente que explica el *porqué* de las
decisiones de diseño de curl, no solo qué hace cada flag.

### [HTTP/2 in Action (capítulos de muestra)](https://www.manning.com/books/http-2-in-action) — Barry Pollard

Los capítulos 1 y 2, gratuitos, cubren HTTP/1.1 con más profundidad que casi
cualquier tutorial: métodos, headers y el ciclo completo.

**Por qué vale la pena**: entiendes qué hay debajo de los verbos antes de que la
Semana 09 empiece a hablar de multiplexación.

## Especificaciones

### [RFC 9110 — HTTP Semantics](https://datatracker.ietf.org/doc/html/rfc9110)

La norma. Es legible, más de lo que su fama sugiere. Las secciones de esta
semana:

- [§9.3 — Method Definitions](https://datatracker.ietf.org/doc/html/rfc9110#name-method-definitions) — POST, PUT, DELETE, HEAD, OPTIONS
- [§9.2.2 — Idempotent Methods](https://datatracker.ietf.org/doc/html/rfc9110#name-idempotent-methods) — la definición exacta, y por qué PATCH queda fuera
- [§15 — Status Codes](https://datatracker.ietf.org/doc/html/rfc9110#name-status-codes) — 201, 204, 405, 409, 415 y 422

**Por qué vale la pena**: cuando una API y tú discrepáis sobre qué debería hacer
un PUT, esto es lo que zanja la discusión.

### [RFC 5789 — PATCH](https://datatracker.ietf.org/doc/html/rfc5789)

Cinco páginas. PATCH llegó cinco años después que el resto de verbos y por eso
tiene su propio RFC.

**Por qué vale la pena**: explica en dos párrafos por qué PATCH no garantiza
idempotencia, que es la pregunta 4 de la rúbrica.

### [RFC 8259 — JSON](https://datatracker.ietf.org/doc/html/rfc8259)

Dieciséis páginas y la especificación entera del formato.

**Por qué vale la pena**: para las discusiones sobre si un `NaN` o un comentario
son JSON válido. No lo son, y aquí está escrito.

---

## 🔗 Navegación

[← Volver a Recursos](../README.md) · [← Volver a la Semana 02](../../README.md)
