# Webgrafía — Semana 09

_Comprobado el 11 de noviembre de 2026._

## Las especificaciones

| Recurso | Por qué vale la pena |
|---|---|
| [RFC 9112 — HTTP/1.1](https://datatracker.ietf.org/doc/html/rfc9112) | El apartado 9, *Connection Management*: cuándo una conexión persiste y quién la cierra |
| [RFC 9113 — HTTP/2](https://datatracker.ietf.org/doc/html/rfc9113) | Frames, streams y `SETTINGS_MAX_CONCURRENT_STREAMS`. El apartado 3 explica la negociación con ALPN |
| [RFC 9000 — QUIC](https://datatracker.ietf.org/doc/html/rfc9000) | El transporte sobre UDP de HTTP/3. Para entender por qué un paquete perdido solo frena a su stream |
| [RFC 9114 — HTTP/3](https://datatracker.ietf.org/doc/html/rfc9114) | HTTP sobre QUIC, y cómo se descubre con `alt-svc` |
| [RFC 7838 — HTTP Alternative Services](https://datatracker.ietf.org/doc/html/rfc7838) | La cabecera `alt-svc` que manda el laboratorio: `h3=":8443"; ma=2592000` |
| [RFC 9110 — HTTP Semantics](https://datatracker.ietf.org/doc/html/rfc9110) | El apartado 13, *Conditional Requests*: `If-None-Match`, `If-Modified-Since` y el 304. El 8.8.3 define el ETag débil |
| [RFC 9111 — HTTP Caching](https://datatracker.ietf.org/doc/html/rfc9111) | `Cache-Control`, `max-age`, `no-store`: todo lo que el toolkit decide no implementar, y por qué es mucho |
| [RFC 6455 — The WebSocket Protocol](https://datatracker.ietf.org/doc/html/rfc6455) | El handshake del 101 y cómo se calcula `Sec-WebSocket-Accept` |

## curl

| Recurso | Por qué vale la pena |
|---|---|
| [curl manpage](https://curl.se/docs/manpage.html) | `-Z`, `--parallel-max` (7.66.0), `--parallel-immediate` (7.68.0), `--etag-save` y `--etag-compare` (7.68.0), `--http2-prior-knowledge` (7.49.0). La fuente de verdad, pero describe la última versión: contrasta con `curl --manual` |
| [curl — HTTP/3](https://curl.se/docs/http3.html) | Con qué bibliotecas se compila curl con HTTP/3, y por qué casi ninguna distribución lo hace |
| [curl — WebSocket](https://curl.se/docs/websocket.html) | El soporte de `ws://` y `wss://` en curl: qué hace el CLI y qué deja para libcurl |
| [everything.curl.dev — HTTP/2](https://everything.curl.dev/http/versions/http2.html) | Cuándo negocia curl HTTP/2 y qué hace con `--http2` sobre `http://` |
| [everything.curl.dev — HTTP/3](https://everything.curl.dev/http/versions/http3.html) | `--http3` frente a `--http3-only`, y el *happy eyeballs* entre QUIC y TCP |
| [everything.curl.dev — Keep alive](https://everything.curl.dev/usingcurl/connections/keepalive.html) | El keepalive de TCP, que es lo que apaga `--no-keepalive`. Deshace la confusión con la conexión persistente de HTTP |
| [everything.curl.dev — Write out](https://everything.curl.dev/usingcurl/verbose/writeout.html) | Todas las variables de `-w`, incluidas `%{num_connects}`, `%{http_version}` y `%{urlnum}` |

## Medir, cachear y compartir estado

| Recurso | Por qué vale la pena |
|---|---|
| [Gil Tene — How NOT to Measure Latency (InfoQ)](https://www.infoq.com/presentations/latency-response-time/) | La misma charla de la videografía, con la transcripción y las diapositivas |
| [Wikipedia — Percentile](https://en.wikipedia.org/wiki/Percentile) | El método *nearest-rank* que usa `estadisticas`, junto a los que interpolan. Para saber por qué dos herramientas dan p95 distintos con los mismos datos |
| [Google SRE Book — Service Level Objectives](https://sre.google/sre-book/service-level-objectives/) | Por qué los objetivos de una API se escriben en percentiles y no en medias |
| [MDN — ETag](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag) | El ETag fuerte y el débil, con ejemplos de petición y respuesta |
| [MDN — HTTP caching](https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching) | Revalidar frente a cachear con `max-age`, explicado sin RFC |
| [GitHub — Best practices for using the REST API](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api) | Peticiones condicionales en una API real, y que un 304 no gasta rate limit |
| [Manual de flock(1)](https://man7.org/linux/man-pages/man1/flock.1.html) | `-w`, `-n` y la forma con descriptor que usa `renovar` |
| [Bash Reference Manual — Redirections](https://www.gnu.org/software/bash/manual/html_node/Redirections.html) | `exec 9>>archivo` y `exec 9>&-`: abrir y cerrar un descriptor sin lanzar nada |

## El laboratorio

| Recurso | Por qué vale la pena |
|---|---|
| [go-httpbin](https://github.com/mccutchen/go-httpbin) | Los endpoints de esta semana: `/delay/N`, `/etag/{etag}`, `/cache`, `/cache/N` y `/websocket/echo` |
| [Caddy — opciones globales](https://caddyserver.com/docs/caddyfile/options) | `servers { protocols h1 h2 h3 }`: la línea del `Caddyfile` que hace que el laboratorio hable las tres versiones |

---

| Anterior | Siguiente |
|---|---|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
