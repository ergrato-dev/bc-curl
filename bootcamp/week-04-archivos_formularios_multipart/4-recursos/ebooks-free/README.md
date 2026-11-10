# Libros y RFC gratuitos — Semana 04

_Comprobado el 10 de noviembre de 2026._

## Libros

| Recurso | Por qué vale la pena |
|---|---|
| [everything.curl.dev — Downloads](https://everything.curl.dev/usingcurl/downloads/) | El capítulo de descargas del libro oficial, escrito por el autor de curl. Cubre `-o`, `-O`, `-J` y lo que pasa con la query string mejor que el manpage |
| [everything.curl.dev — Resuming](https://everything.curl.dev/usingcurl/downloads/resume.html) | Corto y exacto sobre `-C -`. Lo que dice de los servidores que ignoran el rango es la teoría 02 en dos párrafos |
| [everything.curl.dev — Uploads](https://everything.curl.dev/usingcurl/uploads.html) | Las tres formas de subir — `-d`, `-F`, `-T` — en la misma página, que es exactamente la comparación de la teoría 08 |
| [everything.curl.dev — Multipart formposts](https://everything.curl.dev/http/post/multipart.html) | Enseña el cuerpo multipart tal como sale por el cable. Léelo después de la práctica 03 y lo reconocerás línea a línea |
| [High Performance Browser Networking](https://hpbn.co/) | Gratis online. Los capítulos de HTTP/1.1 explican por qué existen `Range`, chunked y `Expect: 100-continue` desde el lado del rendimiento |

## RFC

Se leen por secciones. Cuando la documentación de una API y el comportamiento
del servidor no coinciden, estos documentos deciden quién tiene razón.

| RFC | Por qué vale la pena |
|---|---|
| [RFC 9110 §14](https://datatracker.ietf.org/doc/html/rfc9110#section-14) | Range requests completo: `Range`, `Content-Range`, `206`, `416` y el `If-Range` que curl no envía por su cuenta |
| [RFC 7578](https://datatracker.ietf.org/doc/html/rfc7578) | `multipart/form-data` en diez páginas. La sección 4 es literalmente lo que ves con `cat -A` en la práctica 03 |
| [RFC 6266](https://datatracker.ietf.org/doc/html/rfc6266) | `Content-Disposition` en respuestas HTTP: `filename` y `filename*`, y por qué el cliente tiene que limpiar el nombre que le mandan |
| [RFC 9112 §7.1](https://datatracker.ietf.org/doc/html/rfc9112#section-7.1) | El formato de `Transfer-Encoding: chunked`, que viste con `-T -` |
| [RFC 4648](https://datatracker.ietf.org/doc/html/rfc4648) | Base64 y base64url. Explica el 33 % de la teoría 08 y el `tr '_-' '/+'` de la práctica 04 |

---

| Anterior | Siguiente |
|---|---|
| [Recursos de la semana](../README.md) | [Videografía](../videografia/README.md) |
