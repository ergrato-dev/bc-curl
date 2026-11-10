# Webgrafía — Semana 05

_Comprobado el 10 de noviembre de 2026._

## Referencia de curl

| Recurso | Por qué vale la pena |
|---|---|
| [manpage de curl](https://curl.se/docs/manpage.html) | La fuente. Antes de escribir un flag que «suena bien», búscalo aquí |
| [curl — SSL certificate verification](https://curl.se/docs/sslcerts.html) | La página a la que enlaza el propio error 60. Explica dónde busca curl las CAs y cómo cambiarlo |
| [`--cacert`](https://curl.se/docs/manpage.html#--cacert) y [`--capath`](https://curl.se/docs/manpage.html#--capath) | El archivo, el directorio indexado por hash y `CURL_CA_BUNDLE` |
| [`-E, --cert`](https://curl.se/docs/manpage.html#-E) y [`--key`](https://curl.se/docs/manpage.html#--key) | El certificado de cliente, sus formatos y por qué la frase no va en el comando |
| [`--pinnedpubkey`](https://curl.se/docs/manpage.html#--pinnedpubkey) | Los formatos del pin y la versión desde la que cada backend lo soporta |
| [`-b, --cookie`](https://curl.se/docs/manpage.html#-b) y [`-c, --cookie-jar`](https://curl.se/docs/manpage.html#-c) | Cuándo `-b` es texto y cuándo archivo, y cuándo escribe `-c` |
| [curl — HTTP cookies](https://curl.se/docs/http-cookies.html) | El formato del tarro, columna a columna, incluido el prefijo `#HttpOnly_` |
| [`-L, --location`](https://curl.se/docs/manpage.html#-L) | El cambio de método, las credenciales y la nota sobre `-X` |
| [`--proto-redir`](https://curl.se/docs/manpage.html#--proto-redir) | La sintaxis `=`, `+` y `-` para limitar los protocolos de un salto |
| [`--retry`](https://curl.se/docs/manpage.html#--retry) | La lista exacta de errores transitorios y la espera por defecto |
| [Códigos de salida](https://curl.se/libcurl/c/libcurl-errors.html) | El 1, 28, 35, 47, 56, 58, 60, 77 y 90 de esta semana, con su nombre oficial |
| [everything.curl.dev — Timeouts](https://everything.curl.dev/usingcurl/timeouts.html) | Los límites de tiempo explicados por el autor de curl |

## OpenSSL

| Recurso | Por qué vale la pena |
|---|---|
| [`openssl s_client`](https://docs.openssl.org/3.0/man1/openssl-s_client/) | `-connect`, `-servername`, `-showcerts`, `-CAfile`: todo lo que usas para mirar un servidor |
| [`openssl x509`](https://docs.openssl.org/3.0/man1/openssl-x509/) | `-noout`, `-ext`, `-checkend`, `-fingerprint`, `-pubkey` |
| [`openssl rehash`](https://docs.openssl.org/3.0/man1/openssl-rehash/) | Cómo se construye un directorio de CAs para `--capath` |
| [`openssl req`](https://docs.openssl.org/3.0/man1/openssl-req/) | Generar el par de la práctica 02, y la CSR que pedirías en producción |

## Artículos y guías

| Recurso | Por qué vale la pena |
|---|---|
| [Mozilla — Server Side TLS](https://wiki.mozilla.org/Security/Server_Side_TLS) | Qué versiones y cifrados se consideran seguros hoy. Útil para saber si un `--tlsv1.2` es un mínimo razonable |
| [MDN — Set-Cookie](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie) | Todos los atributos con ejemplos, incluidos los que solo afectan al navegador |
| [MDN — Redirections in HTTP](https://developer.mozilla.org/en-US/docs/Web/HTTP/Redirections) | La tabla de códigos 3xx y cuándo usar cada uno, desde el lado del servidor |
| [Cloudflare — What is mutual TLS?](https://www.cloudflare.com/learning/access-management/what-is-mutual-tls/) | El concepto de mTLS con diagramas, y dónde se usa |
| [Stripe — Idempotent requests](https://docs.stripe.com/api/idempotent_requests) | Un ejemplo real de `Idempotency-Key`: cómo una API hace seguro reintentar un POST |
| [Caddy — `tls` directive](https://caddyserver.com/docs/caddyfile/directives/tls) | La CA interna y el `client_auth` que usa el laboratorio, para entender qué valida y qué no |

---

| Anterior | Siguiente |
|---|---|
| [Videografía](../videografia/README.md) | [Recursos](../README.md) |
