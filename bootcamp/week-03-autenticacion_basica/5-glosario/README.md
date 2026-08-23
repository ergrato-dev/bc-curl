# Glosario — Semana 03

Términos de autenticación que aparecen esta semana. El término real en inglés va
entre paréntesis, y los flags que no son universales llevan **su versión mínima**.
Los términos de todo el bootcamp están en
[`docs/glosario-global.md`](../../../docs/glosario-global.md).

---

## A

**`--anyauth`** · Flag de curl que le deja elegir el esquema «más seguro» que
ofrezca el servidor. Cuesta **una petición extra siempre**: la primera va sin
credencial solo para leer el reto. No usarlo en bucles.

**API key** (*clave de API*) · Cadena fija que identifica a una **aplicación**,
no a una persona. No tiene RFC: cada servicio elige su header y su formato. Se
revoca sin tocar ninguna password, que es su mejor propiedad.

**`argv`** · La lista de argumentos con la que se lanzó un proceso. La lee
cualquier usuario de la máquina con `ps` o en `/proc/<pid>/cmdline`. Un secreto
en el `argv` es un secreto publicado.

**Autenticación** (*authentication*) · Responder «¿quién eres?». Es lo que falla
en un `401`.

**Autorización** (*authorization*) · Responder «¿puedes hacer esto?». Es lo que
falla en un `403`. El nombre del `401 Unauthorized` es un error histórico del
estándar.

**`Authorization`** · El header donde viaja la credencial. Su valor empieza por
el nombre del esquema: `Basic`, `Bearer`, `Digest`.

## B

**base64** · Codificación que convierte bytes cualesquiera en ASCII imprimible.
**Reversible sin ninguna clave**: no es cifrado. Ver [RFC 4648
§4](https://datatracker.ietf.org/doc/html/rfc4648#section-4).

**base64url** · Variante para URLs y headers: `+` pasa a `-`, `/` pasa a `_`, y
**no lleva relleno**. Es lo que usan los JWT, y la falta de relleno es la causa
del `base64: invalid input` más frecuente.

**`--basic`** · Fuerza el esquema Basic. Es el defecto de curl con `-u`, así que
solo hace falta para deshacer un `--digest` heredado de un `.curlrc`.

**Basic Auth** · Esquema del [RFC
7617](https://datatracker.ietf.org/doc/html/rfc7617): `base64(usuario:password)`
en el header `Authorization`. Manda la password en **cada** petición.

**Bearer** (*portador*) · Esquema del [RFC
6750](https://datatracker.ietf.org/doc/html/rfc6750). Vale por el hecho de
tenerlo, como un billete: no hay usuario ni reto que resolver.

## C

**Claim** (*afirmación*) · Cada campo del payload de un JWT. Los estándar son
`exp`, `iat`, `nbf`, `sub`, `iss`, `aud` y `jti`.

**Clock skew** (*desfase de reloj*) · La diferencia entre tu reloj y el del
servidor. Por eso se renueva un token con 60 segundos de margen sobre su `exp`.

**`--config ARCHIVO`** (`-K`) · Lee opciones de curl de un archivo, una por línea
y **sin los dos guiones**. Es la forma general de que un secreto no entre en el
`argv`. Acepta `-` para leer de stdin.

## D

**`--digest`** · Activa el esquema Digest. Gasta **dos peticiones**: la primera
sin credencial, para obtener el `nonce`.

**Digest** · Esquema del [RFC
7616](https://datatracker.ietf.org/doc/html/rfc7616). La password **no viaja**:
viaja un hash de la password, el `nonce`, el método y la URI.

## E

**`EX_NOPERM`** · El valor `77` de `sysexits.h`, reservado para «permiso
denegado». El proyecto de esta semana lo usa para `401` y `403`, y no colisiona
con ningún código de curl.

**`exp`** · El claim de caducidad de un JWT, en **segundos** desde epoch. Trece
dígitos significan milisegundos y son un error del emisor.

**`expires_in`** · Campo de la respuesta de un endpoint de token: segundos de
vida **desde ahora**. Es relativo, así que lo que se guarda es `ahora +
expires_in`.

## F

**`--fail`** · Hace que curl salga con **22** ante un `4xx` o `5xx`. Descarta el
cuerpo, que es donde la API explica el motivo.

**`--fail-with-body`** · Igual que `--fail`, pero **conserva el cuerpo**.
Disponible desde **curl 7.76**. Es el que se usa en producción.

## H

**`-H @ARCHIVO`** · Lee headers de un archivo, uno por línea. Disponible desde
**curl 7.55**. El shell **no** expande la `~` detrás de la `@`: usa `"@$HOME/…"`.

## J

**JWT** (*JSON Web Token*) · Token del [RFC
7519](https://datatracker.ietf.org/doc/html/rfc7519) con tres partes separadas
por puntos: header, payload y firma. Las dos primeras se leen con `base64 -d`.

**`jti`** · Identificador único de un JWT. Es lo que se puede loguear sin
filtrar nada, a diferencia del token entero.

## N

**`.netrc`** · Formato clásico de credenciales: `machine HOST login USUARIO
password SECRETO`, una línea por máquina. Su ventaja es que ata la credencial a
un host concreto.

**`--netrc-file ARCHIVO`** · Usa el archivo que le digas. Sus parientes son
`--netrc` (usa `~/.netrc` y falla si no hay entrada) y `--netrc-optional` (sigue
sin credencial si no lo encuentra).

**`nonce`** (*número de un solo uso*) · Valor que el servidor manda en el reto de
Digest y que el cliente incluye en su hash. Cambia en cada petición: por eso
Digest no puede mandar la credencial de entrada.

## O

**`--oauth2-bearer TOKEN`** · Construye el header `Authorization: Bearer` por ti.
Disponible desde **curl 7.61**. El token sigue estando en el `argv`: en un
script, `--config`.

**Opaco** (*opaque token*) · Token sin nada legible dentro: el servidor lo busca
en su almacén. Se distingue de un JWT contando los puntos: si no son dos, es
opaco.

## Q

**`-q`** · Hace que curl ignore el `~/.curlrc`. Es lo primero que se prueba ante
un comportamiento que no te explicas.

**Query string** · La parte de la URL tras el `?`. **Nunca** para una credencial:
acaba en el log del servidor, en el del proxy, en el `Referer` y en el historial,
también con HTTPS.

## R

**`realm`** (*espacio protegido*) · Etiqueta que el servidor manda en su reto. No
es un secreto. curl lo usa para no reenviar la credencial a un realm distinto.

**`Retry-After`** · Header que acompaña a un `429` y dice cuánto esperar, en
segundos o como fecha HTTP. curl lo respeta desde **7.66**.

**Reto** (*challenge*) · El header `WWW-Authenticate` de una respuesta `401`.
Dice qué esquema acepta el servidor, y en Digest trae además el material para
calcular la respuesta.

## S

**`sysexits.h`** · Cabecera de los BSD que reserva códigos de salida con
significado. De ahí sale el `77` que usa el proyecto.

## T

**`trap ... EXIT`** · Instrucción de bash que ejecuta algo al terminar el script,
**incluso si muere a mitad**. Es lo que garantiza que el archivo temporal de
credenciales se borra siempre.

## U

**`-u USUARIO:PASSWORD`** (`--user`) · La credencial de Basic Auth. curl parte
por el **primer** dos puntos, así que el usuario no puede llevarlos y la password
sí. Sin `:password`, curl la **pregunta** por terminal.

**`umask 077`** · Hace que los archivos nuevos nazcan con permisos `600`. Se pone
entre paréntesis —`(umask 077; ...)`— para que el cambio no afecte al resto del
script. Un `chmod` después deja una ventana en la que el archivo es legible.

## W

**`WWW-Authenticate`** · El header del reto. Obligatorio en un `401` según el
RFC, y ausente en un `403`: esa ausencia es en sí misma información.

## 4

**`401 Unauthorized`** · No sé quién eres. Trae `WWW-Authenticate`. **Puede**
arreglarse con otra credencial.

**`403 Forbidden`** · Sé quién eres y no puedes. No trae reto. No se arregla con
otra credencial del mismo tipo.

## 0

**`000`** · Lo que curl escribe en `%{http_code}` cuando **no hubo respuesta**:
DNS que no resuelve, puerto cerrado, timeout. No es un código HTTP y no se
compara como número: se trata con `case` y patrones.

---

| Anterior | Siguiente |
|---|---|
| [Recursos](../4-recursos/README.md) | [README de la Semana 03](../README.md) |

[← Glosario global del bootcamp](../../../docs/glosario-global.md)
