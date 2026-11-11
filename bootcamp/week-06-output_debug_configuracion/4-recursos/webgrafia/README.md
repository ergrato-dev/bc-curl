# Webgrafía — Semana 06

_Comprobado el 10 de noviembre de 2026._

## Referencia de curl

| Recurso | Por qué vale la pena |
|---|---|
| [manpage de curl](https://curl.se/docs/manpage.html) | La fuente. Antes de escribir un flag que «suena bien», búscalo aquí |
| [`-w, --write-out`](https://curl.se/docs/manpage.html#-w) | La lista completa de variables, con la versión en que entró cada una. Imprescindible para no inventar un `%{total_time}` |
| [`-v, --verbose`](https://curl.se/docs/manpage.html#-v) | Qué enseña y qué no, y cómo se combina con `--trace` |
| [`--trace-ascii`](https://curl.se/docs/manpage.html#--trace-ascii) | El formato de la traza y por qué `-` es stdout |
| [`-K, --config`](https://curl.se/docs/manpage.html#-K) | La sintaxis del archivo y el orden exacto en que se busca el `.curlrc` |
| [`-q, --disable`](https://curl.se/docs/manpage.html#-q) | Una línea que dice "first parameter". Es la razón del TODO 1 |
| [`-D, --dump-header`](https://curl.se/docs/manpage.html#-D) | Headers a un archivo, también los de cada redirect |
| [`--libcurl`](https://curl.se/docs/manpage.html#--libcurl) | Del comando al programa en C equivalente |
| [libcurl — `curl_easy_getinfo`](https://curl.se/libcurl/c/curl_easy_getinfo.html) | El diagrama de los tiempos que hay debajo de cada `time_*` de `-w`, con qué marca exactamente cada instante |
| [Códigos de salida](https://curl.se/libcurl/c/libcurl-errors.html) | El 6, 7, 22, 28, 47 y 60 que esta semana aparecen en `%{exitcode}` |
| [Cuándo entró cada opción](https://github.com/curl/curl/blob/master/docs/options-in-versions) | Para saber si tu curl tiene `--trace-ids` o `--variable` sin probarlo |

## Artículos

| Recurso | Por qué vale la pena |
|---|---|
| [Daniel Stenberg — curl write-out JSON](https://daniel.haxx.se/blog/2020/03/17/curl-write-out-json/) | El anuncio de `%{json}` en 7.70, con el porqué: dejar de partir líneas por espacios |
| [Daniel Stenberg — Easier header picking with curl](https://daniel.haxx.se/blog/2022/03/24/easier-header-picking-with-curl/) | `%header{}` y `%{header_json}` contados por quien los añadió, con la sintaxis rara de las llaves explicada |
| [JSON Lines](https://jsonlines.org/) | El formato de `METRICS_FILE`: una línea, un objeto. Dos párrafos que bastan |
| [Brendan Gregg — The USE Method](https://www.brendangregg.com/usemethod.html) | Utilización, saturación, errores: un método para no mirar métricas al azar cuando algo va lento |

## Herramientas

| Recurso | Por qué vale la pena |
|---|---|
| [Manual de jq](https://jqlang.github.io/jq/manual/) | `-c`, `-s`, `--arg`, `--argjson`, `group_by` y `sort`: todo lo que usa la práctica 04 |
| [Bash Reference Manual — Redirections](https://www.gnu.org/software/bash/manual/html_node/Redirections.html) | Qué hacen exactamente `2>`, `2>&1` y su orden. Para entender por qué zsh se comporta distinto |

---

| Anterior | Siguiente |
|---|---|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
