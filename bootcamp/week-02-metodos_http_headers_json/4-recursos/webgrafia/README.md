# Webgrafía — Semana 02

_Comprobado en agosto de 2026._

## Referencia de curl

### [manpage de curl](https://curl.se/docs/manpage.html)

Las secciones de esta semana: [`-d`](https://curl.se/docs/manpage.html#-d),
[`--data-binary`](https://curl.se/docs/manpage.html#--data-binary),
[`-H`](https://curl.se/docs/manpage.html#-H),
[`-X`](https://curl.se/docs/manpage.html#-X) y
[`--json`](https://curl.se/docs/manpage.html#--json).

**Por qué vale la pena**: es la única fuente que no envejece. Y la entrada de
`-X` dice literalmente que no suele hacer falta, lo que ahorra discusiones.

### [Cuándo entró cada opción](https://github.com/curl/curl/blob/master/docs/options-in-versions)

Un archivo de texto plano del repositorio oficial: flag, versión.

**Por qué vale la pena**: es la respuesta a "¿puedo usar `--json`?" sin
adivinar. Antes de escribir un flag nuevo en un script que corre en máquinas de
otros, se mira aquí.

### [Variables de `--write-out`](https://curl.se/docs/manpage.html#-w)

La lista completa, con la versión mínima de cada una.

**Por qué vale la pena**: `%{method}` es de 7.72 y `%{header_json}` de 7.83.
Inventarse una variable que suena bien es el error más frecuente al escribir
material sobre curl.

## HTTP

### [MDN — Métodos HTTP](https://developer.mozilla.org/es/docs/Web/HTTP/Methods)

En español, con una tabla de si cada verbo es seguro, idempotente y cacheable.

**Por qué vale la pena**: esa tabla es la respuesta rápida a "¿puedo reintentar
esto?".

### [MDN — Códigos de estado](https://developer.mozilla.org/es/docs/Web/HTTP/Status)

También en español, con ejemplos de cuándo aparece cada uno.

**Por qué vale la pena**: la entrada del 422 explica la diferencia con el 400
mejor que el propio RFC.

### [httpwg.org — Las especificaciones HTTP en HTML navegable](https://httpwg.org/specs/)

Los RFC 9110-9114 con índice, enlaces cruzados y buscador.

**Por qué vale la pena**: leer un RFC en el texto plano de la IETF es incómodo;
aquí es casi agradable.

## Herramientas

### [Manual de jq](https://jqlang.github.io/jq/manual/)

Las secciones que se usan esta semana: `--arg`, `--argjson`, `-r`, `-n`, `empty`
y `@tsv`.

**Por qué vale la pena**: `jq -n --arg` es lo que evita todos los problemas de
comillas de esta semana, y está a dos párrafos del principio.

### [jqplay](https://jqplay.org/)

Prueba expresiones de `jq` en el navegador, con el JSON pegado a un lado.

**Por qué vale la pena**: iterar una expresión de `jq` en la terminal es lento;
aquí es instantáneo. Pega el JSON, no datos reales.

### [go-httpbin — el reflector del laboratorio](https://github.com/mccutchen/go-httpbin)

El README lista todos los endpoints, incluidos los que este bootcamp no usa.

**Por qué vale la pena**: cuando quieras provocar un caso concreto —un delay, un
gzip, un ETag— la lista está ahí y el laboratorio ya lo sirve.

### [ShellCheck online](https://www.shellcheck.net/)

Pega el script y te dice qué está mal.

**Por qué vale la pena**: `SC2086` (variables sin comillas) es el aviso que más
va a salirte en el proyecto, y la explicación de su wiki es la mejor que hay.

## Artículos

### [Why you should stop using `curl -X POST`](https://daniel.haxx.se/blog/2015/09/11/unnecessary-use-of-curl-x/) — Daniel Stenberg

El artículo original del autor de curl, de 2015. Sigue igual de vigente.

**Por qué vale la pena**: es la fuente de la teoría 04. Léelo después de haber
reproducido el caso del 303 en la práctica 02: se entiende el doble.

### [Idempotency keys — Stripe](https://docs.stripe.com/api/idempotent_requests)

Cómo una API de pagos resuelve el problema de reintentar un POST.

**Por qué vale la pena**: es la respuesta industrial a la pregunta 4 de la
rúbrica, en una API que se usa de verdad.

---

## 🔗 Navegación

[← Volver a Recursos](../README.md) · [← Volver a la Semana 02](../../README.md)
