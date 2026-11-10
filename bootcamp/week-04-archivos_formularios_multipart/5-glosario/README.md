# Glosario — Semana 04

Términos de transferencias, formularios y multipart que aparecen esta semana. El
término real en inglés va entre paréntesis, y los flags que no son universales
llevan **su versión mínima**. Los términos de todo el bootcamp están en
[`docs/glosario-global.md`](../../../docs/glosario-global.md).

---

## A

**`Accept-Ranges`** · Header de respuesta con el que el servidor anuncia que
acepta peticiones de rango. `bytes` = sí; ausente o `none` = no cuentes con
reanudar. Es un anuncio, no una garantía: manda el código de la respuesta.

**Atómico** (*atomic*) · Una operación que ocurre entera o no ocurre. `mv`
dentro del mismo sistema de archivos lo es; entre sistemas de archivos, no.

## B

**base64url** · Variante de base64 que usa `-` y `_` en lugar de `+` y `/`, y
suele ir sin relleno. La usan los JWT y el `data:` del laboratorio. `base64 -d`
no la entiende sin un `tr '_-' '/+'`.

**Boundary** · Cadena aleatoria que separa las partes de un cuerpo multipart.
curl la elige en cada petición y la declara en el `Content-Type`. No se escribe
a mano.

## C

**Chunked** (*Transfer-Encoding: chunked*) · Forma de enviar un cuerpo sin
conocer su tamaño: en trozos, cada uno precedido de su longitud en
hexadecimal, y un trozo de tamaño cero al final. curl la usa con `-T -`.

**`-C -`** (`--continue-at`) · Reanuda una descarga: curl mide el archivo de
salida y pide desde ese byte con `Range`. Siempre con `-o`.

**`Content-Disposition`** · Header con dos usos. En una respuesta, propone un
nombre de archivo (`attachment; filename=...`), que `-J` usa. Dentro de una
parte multipart, da el `name` del campo y, si es archivo, su `filename`.

**`Content-Range`** · Header de una respuesta `206` que dice qué bytes lleva y
de qué total: `bytes 500-999/1000`.

## D

**`--data-binary`** · Manda el cuerpo exacto, sin quitar saltos de línea. Con
`@archivo`, el archivo byte a byte. Pone por defecto el `Content-Type` de
formulario: hay que cambiarlo con `-H`.

**`--data-raw`** (**7.43+**) · Como `-d`, pero sin interpretar una `@` inicial
como archivo.

**`--data-urlencode`** · Codifica el valor según las reglas de urlencoded antes
de enviarlo. Cinco formas: `nombre=valor`, `=valor`, `valor`, `nombre@archivo`
y `@archivo`. El nombre nunca se codifica.

## E

**`EX_TEMPFAIL`** (75) · Código de `sysexits.h` para "fallo temporal, vuelve a
intentarlo". El `download` del proyecto lo usa para una descarga cortada.

**`Expect: 100-continue`** · Header con el que curl pide permiso antes de
mandar un cuerpo grande. El servidor responde `100 Continue` o rechaza sin que
viajen los datos. curl 7.81 lo manda siempre con `-T` y por encima de 1 MB con
`-F` y `-d`; 8.x solo por encima de 1 MB. Se suprime con `-H 'Expect:'`.

## F

**`--fail`** (`-f`) · Sale con 22 ante un 4xx/5xx **y no escribe el cuerpo**.
En descargas es la opción correcta, frente a `--fail-with-body` (**7.76+**),
que escribiría el error en el archivo.

**`%{filename_effective}`** · Variable de `--write-out` con el nombre con el
que curl escribió de verdad. La forma de saber qué decidió `-J`.

**`--form-string`** · Como `-F`, pero el valor es literal: una `@` o una `<`
iniciales no leen ningún archivo.

## J

**`-J`** (`--remote-header-name`) · Junto a `-O`, usa el nombre del
`Content-Disposition` del servidor. Nunca sobrescribe y quita cualquier ruta
del nombre.

## L

**`--limit-rate`** · Velocidad máxima de la transferencia. No aborta nada:
frena. `K` es 1024.

## M

**`--max-filesize`** · Rechaza un cuerpo mayor que el límite, con el código
63. En 7.81 solo actúa si el servidor manda `Content-Length`; las versiones
8.x recientes también cortan a mitad de transferencia.

**Multipart** (`multipart/form-data`) · Formato de cuerpo dividido en partes,
cada una con sus cabeceras y su contenido sin codificar. Lo que manda `-F` y
un navegador con un `<input type="file">`.

## N

**`--no-progress-meter`** (**7.67+**) · Quita el medidor de progreso pero
conserva los mensajes de error. Equivale al `-sS` clásico.

## O

**`-O`** (`--remote-name`) · Guarda con el último segmento de la URL como
nombre, **query string incluida**.

**`--output-dir`** (**7.73+**) · Directorio donde caen los `-O` y los `-o`
relativos. En 7.72 o anterior: `mkdir -p dir && cd dir`.

## P

**`.part`** · Convención para el archivo de una descarga en curso. Se renombra
al destino solo cuando está completo y verificado. Es también el estado de la
reanudación.

**Petición de rango** (*range request*) · Petición que pide solo una parte de
un recurso con el header `Range`. El servidor responde `206` si la sirve.

## R

**`-r`** (`--range`) · Escribe el header `Range`: `0-9`, `20-`, `-5`, o varios
trozos separados por comas.

**`--remove-on-error`** (**7.83+**) · Borra el archivo de salida si la
transferencia falla. En 7.81: `curl ... -o f || rm -f f`.

## S

**SHA-256** · Función hash que convierte cualquier archivo en 64 caracteres
hexadecimales. Un bit distinto cambia el hash entero. `sha256sum` en Linux,
`shasum -a 256` en macOS.

**`SHA256SUMS`** · Archivo con una línea `HASH  NOMBRE` (dos espacios) por
archivo publicado. Se verifica con `sha256sum -c`.

**`%{size_download}` / `%{size_upload}`** · Bytes de cuerpo recibidos o
enviados. Con `--compressed`, `size_download` cuenta los comprimidos.

**`--speed-limit` / `--speed-time`** (`-Y` / `-y`) · Abortan con 28 si la
velocidad no llega a un mínimo durante un periodo. El detector de conexiones
muertas.

## T

**`-T`** (`--upload-file`) · Sube un archivo como cuerpo, con `PUT` y sin
`Content-Type`. Si la URL acaba en `/`, le añade el nombre del archivo. `-T -`
lee de stdin, en chunked.

## U

**Urlencoded** (`application/x-www-form-urlencoded`) · Formato de formulario:
pares `nombre=valor` unidos por `&`, con el espacio como `+` y los caracteres
reservados como `%XX`. El que manda `-d`.

**`--url-query`** (**7.87+**) · Añade parámetros codificados a la query string
sin cambiar el método. En 7.81: `-G --data-urlencode`.

## 4

**416** (*Range Not Satisfiable*) · El rango pedido no existe. Al reanudar,
significa que el archivo ya estaba completo. Con `--fail`, curl sale con 22.

---

| Anterior | Siguiente |
|---|---|
| [Recursos](../4-recursos/README.md) | [README de la Semana 04](../README.md) |

[← Glosario global del bootcamp](../../../docs/glosario-global.md)
