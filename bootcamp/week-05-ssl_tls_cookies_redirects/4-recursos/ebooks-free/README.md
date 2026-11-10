# Libros y RFC gratuitos — Semana 05

_Comprobado el 10 de noviembre de 2026._

## Libros

| Recurso | Por qué vale la pena |
|---|---|
| [everything.curl.dev — TLS](https://everything.curl.dev/usingcurl/tls.html) | El capítulo de TLS del libro oficial: versiones, verificación, CAs y certificados de cliente, con los flags de curl y no los de una librería |
| [everything.curl.dev — Cookies](https://everything.curl.dev/http/cookies/) | El motor de cookies explicado por quien lo escribió. La parte de "cookie engine" es la teoría 05 §2.4 contada desde dentro |
| [everything.curl.dev — Redirects](https://everything.curl.dev/http/redirects.html) | Por qué curl no sigue redirects por defecto, qué hace con el método y con las credenciales |
| [The Illustrated TLS 1.3 Connection](https://tls13.xargs.org/) | Un handshake real, byte a byte, con cada campo explicado. Después de leerlo, las líneas `TLS handshake` de `-v` dejan de ser ruido |
| [High Performance Browser Networking — TLS](https://hpbn.co/transport-layer-security-tls/) | Gratis online. El capítulo de TLS explica el coste del handshake y la cadena de confianza desde el lado del rendimiento |
| [Smallstep — Everything you should know about certificates and PKI](https://smallstep.com/blog/everything-pki/) | La explicación más clara que existe de qué es una CA, una cadena y un certificado de cliente, escrita por gente que hace CAs internas |

## RFC

| Recurso | Por qué vale la pena |
|---|---|
| [RFC 8446 — TLS 1.3](https://datatracker.ietf.org/doc/html/rfc8446) | La sección 2 es un resumen legible del handshake; la 4.3.2 es el `Certificate Request` del mTLS |
| [RFC 6265 — HTTP State Management Mechanism](https://datatracker.ietf.org/doc/html/rfc6265) | `Set-Cookie`, sus atributos y cómo decide el cliente a qué peticiones mandar cada cookie |
| [RFC 9110 §15.4 — Redirection 3xx](https://datatracker.ietf.org/doc/html/rfc9110#section-15.4) | Qué significa cada 3xx y por qué 301 y 302 pueden cambiar el método y 307 y 308 no |
| [RFC 9110 §9.2.2 — Idempotent Methods](https://datatracker.ietf.org/doc/html/rfc9110#section-9.2.2) | La definición de idempotencia que decide qué se puede reintentar |

---

| Anterior | Siguiente |
|---|---|
| [Recursos](../README.md) | [Videografía](../videografia/README.md) |
