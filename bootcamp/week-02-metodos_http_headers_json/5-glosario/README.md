# Glosario — Semana 02

Términos de esta semana, de la A a la Z. El término real en inglés va entre
paréntesis cuando lo hay, y la versión mínima de curl cuando el flag no es
universal.

Para lo anterior, el [glosario de la Semana 01](../../week-01-http_y_curl_basico/5-glosario/README.md).
Para todo el bootcamp, el [glosario global](../../../docs/glosario-global.md).

---

### `--argjson` (jq)

Igual que `--arg`, pero interpreta el valor como JSON en vez de como cadena. Es
la diferencia entre que la API reciba `36` y que reciba `"36"`, y por tanto entre
un 201 y un 422. Para números, booleanos, `null`, objetos y arrays.

### `Accept`

Header de **petición** que dice en qué formato quieres la respuesta. Es una
preferencia, no una orden: el servidor puede ignorarla, o contestar **406 Not
Acceptable** si es estricto y no sabe generar lo que pides. No confundir con
`Content-Type`, que describe lo que **envías**.

### `Allow`

Header de **respuesta** con la lista de métodos que ese recurso admite. Es
obligatorio en una respuesta **405**, y por eso provocar un 405 a propósito es la
forma más fiable de averiguar qué acepta un endpoint.

### `--arg` (jq)

Mete una variable del shell dentro de un JSON construido con `jq -n`,
escapándola correctamente: comillas, saltos de línea y acentos incluidos. Es la
alternativa a interpolar a mano, que se rompe con el primer valor raro. Mete
**siempre** una cadena; para otros tipos, `--argjson`.

### Cuerpo (*body*, *payload*)

La cuarta parte de un mensaje HTTP, después de la línea en blanco que cierra los
headers. Lleva los datos. Un GET normal lo tiene vacío; POST, PUT y PATCH lo
llevan lleno. El servidor sabe cuántos bytes leer por el `Content-Length`.

### `Content-Length`

Header que dice cuántos bytes tiene el cuerpo. Lo calcula curl solo, y hacerlo a
mano es una mala idea: si te equivocas por un byte, el servidor corta el cuerpo o
se queda esperando. Su ausencia en un HEAD **no** significa que el recurso esté
vacío.

### `Content-Type`

Header que declara el formato de lo que **envías**. `-d` pone
`application/x-www-form-urlencoded` por defecto, que no es JSON: de ahí sale la
mayoría de los 415 de esta semana.

### `--data` / `-d`

Pone contenido en el cuerpo, cambia el método a POST y añade el `Content-Type`
de formulario. Con `@archivo` lee el archivo **y le quita los saltos de línea**.
Universal (curl 4.0).

### `--data-binary`

Como `-d`, pero manda el contenido byte a byte, sin tocarlo. Es el correcto para
cualquier cuerpo que salga de un archivo: JSON, PEM, CSV, binarios. Desde curl
7.2.

### `--data-raw`

Como `-d`, pero **no interpreta la `@` inicial** como una ruta de archivo. Es la
opción por defecto correcta cuando el contenido viene de fuera —una variable, un
argumento— porque `-d` con un `@` y un archivo inexistente manda un cuerpo vacío
sin fallar. Desde curl 7.43.

### `--data-urlencode`

Codifica el valor en `x-www-form-urlencoded` antes de mandarlo: los espacios
pasan a `+` y `&`, `=` y los acentos a `%XX`. Con `-G` va a la query string en
vez de al cuerpo. Desde curl 7.18.

### DELETE

Verbo HTTP que elimina un recurso. **Idempotente**: borrarlo dos veces deja el
mismo estado (aunque la segunda respuesta suela ser 404). Puede llevar cuerpo,
pero no tiene semántica definida y proxies y servidores lo descartan sin avisar.

### `--dry-run`

No es un flag de curl: es una convención de los CLI, y en este bootcamp una
regla del proyecto desde la Semana 02. Imprime el comando que se habría
ejecutado y termina. Es lo que permite probar un `delete` sin borrar nada.

### `--fail` / `-f`

Hace que curl salga con **22** ante un 4xx o un 5xx, en vez de con 0. Descarta el
cuerpo de la respuesta —ni siquiera crea el archivo de `-o`—, que es justo donde
la API explica el motivo del rechazo. Universal (curl 4.0).

### `--fail-with-body`

Como `--fail`, pero **conserva el cuerpo**. Es el que se usa en todo este
bootcamp: ante un 422, esos bytes son el diagnóstico. Desde curl **7.76**.

### `--form` / `-F`

Envía un formulario `multipart/form-data`, que es lo que usan las subidas de
archivo. Implica POST. Se ve en profundidad en la Semana 04. Universal (curl 5.0).

### `-G` / `--get`

Mueve a la query string lo que los flags `--data*` habrían puesto en el cuerpo, y
deja el método en GET. Es la mitad correcta de `-G --data-urlencode`.

### `--header` / `-H`

Añade un header a la petición. Cuatro comportamientos según la puntuación:
`'X: v'` añade, `'User-Agent: v'` sustituye uno de los que pone curl, `'X;'` lo
manda vacío y `'X:'` lo suprime. Con `@archivo` lee un header por línea, y ahí es
donde se saca un token de `ps`. La forma `@archivo` es de curl **7.55**.

### HEAD

Verbo HTTP que devuelve los headers de la respuesta que habría dado un GET, sin
el cuerpo. curl lo manda con `-I`. Ojo: es **otro método**, así que un endpoint
que solo acepta POST contesta 405 a un HEAD.

### Idempotencia

Propiedad de un método por la que ejecutarlo N veces deja el servidor en el mismo
estado que ejecutarlo una vez. **No** significa "no cambia nada". GET, HEAD, PUT
y DELETE la tienen; POST no; PATCH depende del parche. De ella depende si
`--retry` es seguro.

### `--json`

Atajo equivalente a `-d` más `-H 'Content-Type: application/json'` más
`-H 'Accept: application/json'`. No valida el JSON. Desde curl **7.82**, y
**Ubuntu 22.04 trae 7.81**: en material y scripts portables se escribe el
equivalente largo.

### `Location`

Header de **respuesta** con la URL de un recurso. En un **201** es dónde ha
quedado lo que acabas de crear; en un 3xx es a dónde te redirigen. Es el sitio
normativo para saber la URL del recurso nuevo: buscarla en el cuerpo es un error,
porque puede no estar.

### `%{method}`

Variable de `--write-out` con el método que salió de verdad. Es la comprobación
de dos segundos antes de dar por bueno un comando de escritura. Desde curl
**7.72**.

### `--next` / `-:`

Separa varias peticiones en una sola invocación de curl, reutilizando la
conexión. Los flags se reinician en cada `--next`. Desde curl 7.36.

### OPTIONS

Verbo HTTP que pregunta qué métodos admite un recurso. La respuesta canónica es
`Allow`, pero la mayoría de los servidores solo implementan OPTIONS para el
*preflight* de CORS y contestan `Access-Control-Allow-Methods`. Cuando no
convence, el `Allow` de un 405 es más fiable.

### PATCH

Verbo HTTP que aplica un cambio **parcial**: los campos que no mandas se quedan
como estaban. No garantiza idempotencia, porque depende de lo que haga el parche.
Llegó cinco años después que el resto, en el RFC 5789.

### PUT

Verbo HTTP que **reemplaza** el recurso entero: pasa a ser exactamente lo que
mandas, y los campos ausentes desaparecen. Idempotente. `-T` lo implica sin
necesidad de `--request`.

### `--request` / `-X`

Sobrescribe el método de la petición. **No envía nada**: solo cambia la etiqueta.
Sobra siempre que otro flag ya elija el método, y con `-L` fuerza el método en
todos los saltos, lo que convierte un 303 en un segundo POST no previsto. Es
necesario para PATCH, DELETE, OPTIONS y los verbos que ningún flag implica.

### `--upload-file` / `-T`

Sube un archivo **implicando PUT**, sin tocar el contenido. Es el atajo de PUT
que evita un `--request`. Aquí se usa solo por eso; las transferencias de
archivo en serio son la Semana 04. Universal (curl 4.0).

### 201 Created

El recurso existe ahora y no existía antes. Trae `Location` con su URL.

### 204 No Content

Salió bien y no hay nada que devolver. El cuerpo está vacío **a propósito**:
`jq` sobre él no da error, simplemente no imprime nada, y ahí es donde se
esconden los fallos.

### 405 Method Not Allowed

El recurso existe pero no admite ese método. Obligado a traer `Allow`.

### 409 Conflict

La petición es válida; el estado del servidor no la admite (ese email ya está
registrado). **No se reintenta**: fallará igual.

### 415 Unsupported Media Type

El `Content-Type` que declaraste no le sirve al servidor. En la práctica, el
error de `-d` con JSON y sin header. Se arregla cambiando un header, no los
datos.

### 422 Unprocessable Content

El formato es correcto y los datos no pasan la validación de negocio. La
diferencia con el 400: el 400 es "no te entiendo", el 422 es "te entiendo y no me
vale". El motivo viene en el cuerpo.

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [Glosario Semana 01](../../week-01-http_y_curl_basico/5-glosario/README.md) | **Glosario Semana 02** | [Glosario global](../../../docs/glosario-global.md) |

[← Volver a la Semana 02](../README.md)
