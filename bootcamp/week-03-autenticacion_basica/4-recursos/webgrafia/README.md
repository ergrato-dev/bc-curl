# Webgrafía — Semana 03

_Comprobado el 23 de agosto de 2026._

## Referencia de curl

| Recurso | Por qué vale la pena |
|---|---|
| [manpage de curl](https://curl.se/docs/manpage.html) | La fuente. Antes de escribir un flag que «suena bien», búscalo aquí: es el fallo más común de esta semana |
| [`-u, --user`](https://curl.se/docs/manpage.html#-u) | Incluye la regla del primer dos puntos y el comportamiento cuando omites la password |
| [`-K, --config`](https://curl.se/docs/manpage.html#-K) | El formato del archivo de opciones. Lo que usa el proyecto de esta semana |
| [`--netrc-file`](https://curl.se/docs/manpage.html#--netrc-file) | Y sus parientes `--netrc` y `--netrc-optional`, con las diferencias |
| [`--oauth2-bearer`](https://curl.se/docs/manpage.html#--oauth2-bearer) | Disponible desde 7.61. Cómodo, pero deja el token en el `argv` |
| [`--fail-with-body`](https://curl.se/docs/manpage.html#--fail-with-body) | Desde 7.76. La diferencia con `--fail` a secas es el cuerpo del error |
| [`--retry`](https://curl.se/docs/manpage.html#--retry) | La lista exacta de errores transitorios, y la nota de que respeta `Retry-After` desde 7.66 |
| [Códigos de salida de curl](https://everything.curl.dev/cmdline/exitcode.html) | Los 99, con su significado. Útil para elegir uno propio que no colisione |
| [Changelog de curl](https://curl.se/changes.html) | Para comprobar en qué versión apareció un flag antes de usarlo en el material |

## Autenticación y secretos

| Recurso | Por qué vale la pena |
|---|---|
| [IANA — HTTP Authentication Schemes](https://www.iana.org/assignments/http-authschemes/http-authschemes.xhtml) | El registro oficial de esquemas. Si te encuentras uno raro en un `WWW-Authenticate`, está aquí |
| [MDN — HTTP authentication](https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication) | La explicación con ejemplos del ciclo reto-respuesta. Más digerible que el RFC para una primera lectura |
| [MDN — WWW-Authenticate](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/WWW-Authenticate) | Los parámetros de cada esquema, incluido el `realm` |
| [GitHub — Secret scanning patterns](https://docs.github.com/en/code-security/secret-scanning/introduction/supported-secret-scanning-patterns) | Qué prefijos detectan los escáneres. Explica por qué en este material nunca escribimos un token con formato válido |
| [jwt.io — Introduction to JSON Web Tokens](https://jwt.io/introduction) | Buena introducción. **No pegues ahí un token vivo**: se lo estarías mandando a un tercero |
| [`sysexits.h`](https://man.freebsd.org/cgi/man.cgi?query=sysexits) | De dónde sale el `77` que usa el proyecto, y qué otros códigos hay reservados |

## Del propio bootcamp

| Recurso | Por qué vale la pena |
|---|---|
| [`docs/versiones-de-curl.md`](../../../../docs/versiones-de-curl.md) | Qué flag tienes según tu versión. Ubuntu 22.04 trae 7.81 |
| [`docs/trucos-curl.md`](../../../../docs/trucos-curl.md) | Los trucos de las diez semanas en un sitio |
| [`docs/glosario-global.md`](../../../../docs/glosario-global.md) | Los términos de todo el bootcamp |
| [`docs/setup-entorno.md`](../../../../docs/setup-entorno.md) | Levantar el laboratorio y exportar la CA |

---

| Anterior | Siguiente |
|---|---|
| [Videografía](../videografia/README.md) | [Recursos de la semana](../README.md) |
