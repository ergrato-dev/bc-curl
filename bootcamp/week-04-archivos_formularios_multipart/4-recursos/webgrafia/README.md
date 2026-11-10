# Webgrafía — Semana 04

_Comprobado el 10 de noviembre de 2026._

## Referencia de curl

| Recurso | Por qué vale la pena |
|---|---|
| [manpage de curl](https://curl.se/docs/manpage.html) | La fuente. Antes de escribir un flag que «suena bien», búscalo aquí |
| [`-O, --remote-name`](https://curl.se/docs/manpage.html#-O) y [`-J`](https://curl.se/docs/manpage.html#-J) | De dónde sale el nombre del archivo, y las reglas de seguridad del nombre que manda el servidor |
| [`-C, --continue-at`](https://curl.se/docs/manpage.html#-C) | El guion, el desplazamiento explícito y su relación con `-o` |
| [`-r, --range`](https://curl.se/docs/manpage.html#-r) | Las formas del rango, incluida la de los últimos N bytes |
| [`-F, --form`](https://curl.se/docs/manpage.html#-F) | Todas las directivas (`;type=`, `;filename=`, `;headers=`) y las comillas en el nombre |
| [`-T, --upload-file`](https://curl.se/docs/manpage.html#-T) | La barra final, el globbing y el `-` de stdin |
| [`--data-urlencode`](https://curl.se/docs/manpage.html#--data-urlencode) | Las cinco formas, con un ejemplo de cada una |
| [`--max-filesize`](https://curl.se/docs/manpage.html#--max-filesize) | La nota sobre transferencias de tamaño desconocido, que explica el punto ciego de 7.81 |
| [`--write-out`](https://curl.se/docs/manpage.html#-w) | `size_download`, `size_upload`, `speed_*`, `content_type`, `filename_effective` |
| [Códigos de salida](https://curl.se/libcurl/c/libcurl-errors.html) | El 18, 22, 23, 26, 28, 33 y 63 de esta semana, con su nombre oficial |
| [everything.curl.dev — Timeouts](https://everything.curl.dev/usingcurl/timeouts.html) | Los límites de tiempo y velocidad explicados por el autor de curl |

## HTTP y formatos

| Recurso | Por qué vale la pena |
|---|---|
| [MDN — HTTP range requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/Range_requests) | La conversación completa de un rango con ejemplos de cada respuesta, más legible que el RFC |
| [MDN — Content-Disposition](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Disposition) | El header en sus dos usos: en una respuesta (`-J`) y dentro de una parte multipart |
| [MDN — Sending form data](https://developer.mozilla.org/en-US/docs/Learn/Forms/Sending_and_retrieving_form_data) | Qué manda un navegador en cada caso: urlencoded por defecto, multipart cuando hay un archivo |
| [MDN — MIME types](https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types) | Los `Content-Type` habituales, para el `;type=` de `-F` y el `-H` de `--data-binary` |
| [WHATWG URL — urlencoded](https://url.spec.whatwg.org/#application/x-www-form-urlencoded) | La especificación vigente del formato de los formularios, con el algoritmo exacto de codificación |

## Verificación y casos reales

| Recurso | Por qué vale la pena |
|---|---|
| [GNU coreutils — sha2 utilities](https://www.gnu.org/software/coreutils/manual/html_node/sha2-utilities.html) | `sha256sum -c`, `--quiet`, `--ignore-missing`, y el formato exacto de la línea |
| [Ubuntu — How to verify your Ubuntu download](https://ubuntu.com/tutorials/how-to-verify-ubuntu) | Un `SHA256SUMS` firmado de verdad, verificado paso a paso. Es la tabla de fuentes de la teoría 03 en la práctica |
| [AWS S3 — Presigned URL uploads](https://docs.aws.amazon.com/AmazonS3/latest/userguide/PresignedUrlUploadObject.html) | El caso canónico de subida en crudo con `PUT`, y por qué el multipart no sirve ahí |
| [GitHub REST — Create or update file contents](https://docs.github.com/en/rest/repos/contents#create-or-update-file-contents) | El caso canónico de archivo en base64 dentro de JSON |
| [Manual de jq — invocación](https://jqlang.github.io/jq/manual/#invoking-jq) | `--rawfile`, la forma de meter un archivo en un JSON sin pasar por el argv |

---

| Anterior | Siguiente |
|---|---|
| [Videografía](../videografia/README.md) | [Recursos de la semana](../README.md) |
