# 🔗 Webgrafía — Semana 01

Comprobados el **23 de agosto de 2026**.

## Referencia de curl

| Recurso | Por qué vale la pena |
|---|---|
| [curl — manpage](https://curl.se/docs/manpage.html) | La referencia completa, con buscador. Es el mismo texto que `curl --manual`, pero enlazado. Consúltalo cuando dudes de si una opción existe |
| [Variables de `--write-out`](https://curl.se/docs/manpage.html#-w) | La lista entera de variables de `-w`, con lo que devuelve cada una. La usarás en el proyecto y en la Semana 06 |
| [Códigos de salida de libcurl](https://curl.se/libcurl/c/libcurl-errors.html) | Los ~100 códigos de salida con su nombre interno. El sitio donde mirar cuando te salga uno que no reconoces |
| [Changelog de curl](https://curl.se/changes.html) | Qué versión trajo qué. Es la forma de confirmar desde cuándo existe una opción antes de usarla en un ejemplo |
| [Vulnerabilidades de curl](https://curl.se/docs/vulnerabilities.html) | Lista completa por versión. Sirve para argumentar por qué hay que actualizar |

## HTTP

| Recurso | Por qué vale la pena |
|---|---|
| [MDN — HTTP](https://developer.mozilla.org/es/docs/Web/HTTP) | En español y mantenido. Una página por header y por código de estado; el mejor sitio para consultas puntuales |
| [RFC 9110 — HTTP Semantics](https://datatracker.ietf.org/doc/html/rfc9110) | La norma vigente, de 2022. Sustituye a los RFC 7230-7235 que aún citan muchos tutoriales. La sección 15 define cada código de estado |
| [RFC 9112 — HTTP/1.1](https://datatracker.ietf.org/doc/html/rfc9112) | El formato de los mensajes: la línea de petición, los headers, el CRLF. Lo que ves en una traza `-v` está definido aquí |

## Para practicar

| Recurso | Por qué vale la pena |
|---|---|
| [go-httpbin](https://github.com/mccutchen/go-httpbin) | El servicio que corre en tu `localhost:8080`. Su README lista **todos** los endpoints disponibles: los vas a necesitar las diez semanas |
| [GitHub REST API](https://docs.github.com/es/rest) | API real, documentada en español, con rate limit visible en los headers. Es el dominio recomendado para `api-toolkit` |
| [JSONPlaceholder](https://jsonplaceholder.typicode.com/) | API de prueba que acepta escrituras falsas. Útil en la Semana 02, cuando toque POST y PUT |

> [!WARNING]
> `httpbin.org` aparece en casi todos los tutoriales de curl. Este bootcamp **no**
> lo usa: se cae, limita por IP y cambia sin avisar. El laboratorio local hace lo
> mismo y es tuyo. Si un tutorial externo lo usa, sustituye el host por
> `http://localhost:8080` y el ejemplo funciona igual.

## Herramientas que acompañan

| Recurso | Por qué vale la pena |
|---|---|
| [jq](https://jqlang.github.io/jq/manual/) | Filtra JSON en la terminal. A partir de la Semana 02 es tan habitual como curl |
| [ShellCheck](https://www.shellcheck.net/) | Analiza scripts bash y encuentra los fallos de comillas antes que tú. El autograding lo exige limpio |
| [explainshell](https://explainshell.com/) | Pega un comando largo de curl y te desglosa qué hace cada flag. Muy útil al copiar un comando de un blog |

---

[← Volver a Recursos](../README.md)
