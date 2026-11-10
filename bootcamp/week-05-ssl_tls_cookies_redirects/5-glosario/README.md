# Glosario — Semana 05

Términos de TLS, certificados, cookies, redirects, timeouts y reintentos que
aparecen esta semana. El término real en inglés va entre paréntesis, y los
flags que no son universales llevan **su versión mínima**. Los términos de
todo el bootcamp están en
[`docs/glosario-global.md`](../../../docs/glosario-global.md).

---

## A

**ALPN** (*Application-Layer Protocol Negotiation*) · Extensión de TLS con la
que cliente y servidor acuerdan, dentro del handshake, si hablarán HTTP/2 o
HTTP/1.1. En `-v`: `ALPN, offering h2` y `ALPN, server accepted to use h2`.

## C

**CA** (*Certificate Authority*) · Entidad que firma certificados. Un
certificado vale si la cadena de firmas llega a una CA en la que tu curl
confía. Las públicas vienen con el sistema; las internas hay que dárselas.

**CAfile / CApath** · Los dos sitios donde curl busca CAs de confianza: un
archivo PEM con varias (`--cacert`, `CURL_CA_BUNDLE`) y un directorio con una
por archivo indexado por hash (`--capath`). En el curl de Ubuntu, `--cacert`
cambia el CAfile pero no el CApath.

**Cadena de confianza** (*chain of trust*) · Certificado del servidor →
intermedia → raíz. El servidor manda las dos primeras; la raíz la tiene que
tener ya el cliente.

**`--cacert`** · Archivo PEM con las CAs con las que validar al servidor.
Sustituye el CAfile por defecto.

**`--cert` / `-E`** · Certificado de cliente para mTLS. Si el PEM incluye la
clave, basta con él; si no, hace falta `--key`.

**`--connect-timeout`** · Límite para la fase de conexión: DNS, TCP y, en
HTTPS, el handshake TLS. Por defecto, 300 s. Al vencer: código 28 con
`Connection timeout after N ms`.

**`--connect-to`** · Conectar a otro host o puerto sin cambiar la URL, así que
el SNI, el `Host` y la verificación del nombre siguen siendo los de la URL.

**Cookie de sesión** (*session cookie*) · La que llega sin `Expires` ni
`Max-Age`. En el tarro, columna 5 a `0`. curl la conserva hasta que `-j` la
descarta al leer.

**`--cookie` / `-b`** · Manda cookies: texto si lleva `=`, archivo si no. Usarlo
(aunque sea `-b ''`) enciende el motor de cookies.

**`--cookie-jar` / `-c`** · Escribe, al terminar el comando, todas las cookies
que curl conoce. Crea el archivo con la `umask` del proceso (normalmente 644).

**`CURL_CA_BUNDLE`** · Variable de entorno que hace de `--cacert` para todos los
comandos que la hereden.

## H

**Handshake** · La negociación con la que empieza una conexión TLS: versiones,
cifrado, certificado del servidor y, en mTLS, el del cliente. En `-v`, las
líneas `TLS handshake`.

**`#HttpOnly_`** · Prefijo que curl pone al dominio de una cookie `HttpOnly` en
el tarro. No es un comentario: un `grep -v '^#'` se lleva esas cookies.

## I

**Idempotente** (*idempotent*) · Que repetirlo deja el mismo resultado que
hacerlo una vez: `GET`, `PUT`, `DELETE`. `POST` no lo es. Decide qué se puede
reintentar sin riesgo.

**`Idempotency-Key`** · Header que algunas APIs aceptan para que un `POST`
repetido con la misma clave se ejecute una sola vez. No es estándar.

## J

**`--junk-session-cookies` / `-j`** · Descarta las cookies de sesión al leer el
tarro, como si empezara una sesión nueva.

## K

**`--key`** · Clave privada del certificado de cliente. Nunca sale del equipo;
permisos 600. Si está cifrada, la frase va en un `--config` (`pass = "..."`),
no en el comando.

## L

**`--location` / `-L`** · Sigue redirects. Con 301, 302 y 303 convierte un
POST en GET; con 307 y 308 lo mantiene. Quita el `Authorization` al cambiar de
host, pero no los headers propios.

**`--location-trusted`** · Como `-L`, pero manda las credenciales a cualquier
host de la cadena. Antipatrón casi siempre.

## M

**`--max-redirs`** · Máximo de redirects que sigue `-L`. Por defecto, 50. Al
superarlo: código 47.

**`--max-time` / `-m`** · Límite para la petición entera, conexión incluida.
Con `--retry`, cada intento tiene el suyo. Al vencer: código 28 con
`Operation timed out after N milliseconds`.

**Motor de cookies** (*cookie engine*) · La parte de curl que guarda los
`Set-Cookie` y los devuelve dentro del mismo comando. Apagado hasta que se usa
`-b` o `-c`.

**mTLS** (*mutual TLS*) · TLS en el que también el cliente presenta un
certificado. El servidor lo pide con un `Certificate Request`; sin él, corta
con `alert certificate required` (código 56 en curl).

## P

**PEM** · Formato de texto de certificados y claves, entre líneas
`-----BEGIN ...-----`. El que curl con OpenSSL espera por defecto.

**`--pinnedpubkey`** · Exige que la clave pública del servidor sea una concreta
(7.39+; `sha256//` desde 7.44 con OpenSSL). Al fallar: código 90. Rompe cuando
el servidor rota la clave.

**`--post301` / `--post302` / `--post303`** · Mantienen el POST tras esos
redirects, en vez de cambiar a GET.

**`--proto-redir`** · Protocolos a los que se permite saltar en un redirect.
`'=https'` impide bajar a HTTP; entre comillas en zsh.

## R

**`--resolve`** · `HOST:PUERTO:IP`: usa esa IP para ese nombre sin cambiar la
URL. Para probar un nodo concreto.

**`--retry`** · Reintenta los errores transitorios: timeout, 408, 429, 500,
502, 503, 504. Espera 1 s y dobla en cada intento.

**`--retry-all-errors`** (7.71+) · Reintenta cualquier error, también 4xx.
Con cuidado.

**`--retry-connrefused`** (7.52+) · Cuenta la conexión rechazada como
transitoria.

**`--retry-delay`** · Espera fija entre intentos, en vez de la creciente.

**`--retry-max-time`** · No empieza un reintento si han pasado más de N
segundos desde el principio. El techo del conjunto.

## S

**`Set-Cookie`** · Header con el que el servidor fija una cookie, con sus
atributos: `Max-Age`/`Expires`, `Path`, `Domain`, `Secure`, `HttpOnly`,
`SameSite`.

**SNI** (*Server Name Indication*) · El nombre que el cliente manda en el
handshake para que el servidor elija certificado. Con una IP en la URL no hay
SNI: de ahí el 35 contra el laboratorio.

**`subjectAltName`** (SAN) · Campo del certificado con los nombres para los que
vale. Es el único que miran los clientes actuales; el `CN` del subject ya no
cuenta.

## T

**Tarro de cookies** (*cookie jar*) · Archivo en formato Netscape, siete
columnas por cookie, que escribe `-c` y lee `-b`. Vale lo que una sesión:
permisos 600.

**`--tlsv1.2`** · Versión **mínima** de TLS (1.2 o superior). Para un techo,
`--tls-max`.

**Transitorio** (*transient error*) · Error que puede no repetirse en el
siguiente intento. Lo que `--retry` considera como tal está en su entrada.

## V

**Variables `time_*`** · `%{time_namelookup}`, `%{time_connect}`,
`%{time_appconnect}`, `%{time_starttransfer}`, `%{time_total}`: tiempos
acumulados de cada fase. Más en la Semana 06.

**`%{certs}` / `%{num_certs}`** (7.88+) · La cadena de certificados en texto, y
cuántos son. En 7.81 no existen.

**`%{num_retries}`** (8.9+) · Cuántos reintentos hizo curl. En 7.81 sale
`unknown --write-out variable`.

---

| Anterior | Siguiente |
|---|---|
| [Recursos](../4-recursos/README.md) | [README de la Semana 05](../README.md) |

[← Glosario global del bootcamp](../../../docs/glosario-global.md)
