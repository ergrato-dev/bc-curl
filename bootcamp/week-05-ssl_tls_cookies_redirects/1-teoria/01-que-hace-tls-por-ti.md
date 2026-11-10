# Qué hace TLS por ti

> `https://` no es un adorno de la URL. Son tres garantías que curl comprueba
> antes de mandar un solo byte de tu petición, y cada una falla con su propio
> código de salida.

![Diagrama del handshake TLS visto desde curl: el cliente ofrece versiones y protocolos, el servidor responde con su certificado, curl comprueba la cadena hasta una CA de confianza, el nombre del host y las fechas, y solo entonces viaja la petición HTTP cifrada; a la derecha, los códigos de salida 35 y 60 en el punto donde fallaría cada comprobación](../0-assets/01-que-hace-tls-por-ti.svg)

## 🎯 Objetivos

- Explicar las tres garantías de TLS: confidencialidad, integridad y autenticidad
- Leer el handshake en la salida de `-v` y localizar cada fase
- Saber qué comprueba curl del certificado del servidor, y en qué orden
- Reconocer los códigos de salida de un fallo TLS: `35` y `60`
- Fijar la versión mínima de TLS con `--tlsv1.2` y saber cuándo hace falta

---

## 1. Qué problema resuelve

Una petición HTTP viaja en claro. Cualquiera en el camino (la wifi del hotel,
un proxy, un router comprometido) puede leerla, y lo que es peor, cambiarla:
la respuesta que recibes no tiene por qué ser la que mandó el servidor.

TLS cierra los tres huecos:

| Garantía | Qué evita | Cómo |
|---|---|---|
| **Confidencialidad** | Que alguien lea el token o el cuerpo | Cifrado con claves que solo conocen los dos extremos |
| **Integridad** | Que alguien cambie la respuesta por el camino | Cada registro lleva un código de autenticación |
| **Autenticidad** | Hablar con un impostor que cifra perfectamente | El certificado del servidor, firmado por una CA de confianza |

La tercera es la que depende de ti. Las dos primeras las da el cifrado, y el
cifrado funciona igual con el servidor bueno que con el impostor. Lo único que
los distingue es la verificación del certificado.

---

## 2. Cómo funciona

### 2.1 El handshake en `-v`

El laboratorio tiene un frontal HTTPS en `https://localhost:8443` con una CA
propia, que `./scripts/start.sh` exporta a `docs/lab-ca.pem`. Desde la raíz del
repositorio:

```bash
curl -sv --cacert docs/lab-ca.pem https://localhost:8443/get -o /dev/null 2>&1 \
  | grep -E '^\* (ALPN|SSL connection|Server cert|  (subject|start|expire|issuer|SSL cert))'
```

En curl 7.81 sale esto (las fechas cambian: Caddy renueva el certificado cada
pocas horas):

```
* ALPN, offering h2
* ALPN, offering http/1.1
* SSL connection using TLSv1.3 / TLS_AES_128_GCM_SHA256
* ALPN, server accepted to use h2
* Server certificate:
*  subject: [NONE]
*  start date: Nov 10 21:29:21 2026 GMT
*  expire date: Nov 11 09:29:21 2026 GMT
*  subjectAltName: host "localhost" matched cert's "localhost"
*  issuer: CN=Caddy Local Authority - ECC Intermediate
*  SSL certificate verify ok.
```

Cada línea es una fase:

| Línea | Qué pasó |
|---|---|
| `ALPN, offering h2` | curl ofrece HTTP/2 y HTTP/1.1 dentro del handshake |
| `SSL connection using TLSv1.3 / ...` | Versión y cifrado acordados |
| `ALPN, server accepted to use h2` | El servidor eligió HTTP/2 |
| `subjectAltName: host ... matched` | El nombre de la URL está en el certificado |
| `start date` / `expire date` | La ventana de validez, que curl compara con el reloj |
| `issuer` | Quién firmó el certificado |
| `SSL certificate verify ok.` | La cadena llega hasta una CA en la que confías |

Sin `grep`, `-v` enseña además cada mensaje del handshake (`Client hello`,
`Server hello`, `Certificate`, `Finished`). Útil para ver **dónde** se corta
una conexión que falla; para el día a día, las líneas de arriba bastan.

En curl 8.x el formato cambia un poco (`ALPN: curl offers h2,http/1.1`,
`SSL Trust Anchors:`), pero las mismas piezas están ahí.

### 2.2 Las tres comprobaciones del certificado

Antes de mandar la petición, curl comprueba:

1. **La cadena.** El certificado del servidor está firmado por una
   intermedia, y la intermedia por una raíz. La raíz tiene que estar en el
   almacén de CAs de confianza. Si no está: código **60**.
2. **El nombre.** El host de la URL tiene que aparecer en el `subjectAltName`
   del certificado. Un certificado de `api.ejemplo.com` no vale para
   `www.ejemplo.com`. Si no aparece: código **60** en curl 7.81
   (`SSL: no alternative certificate subject name matches target host name`).
3. **Las fechas.** El reloj tiene que estar entre `start date` y `expire
   date`. Un certificado caducado: código **60**
   (`certificate has expired`).

El mismo 60 para las tres: lo que distingue la causa es el mensaje.

```bash
curl -sS https://localhost:8443/get -o /dev/null; echo "codigo: $?"
# curl: (60) SSL certificate problem: unable to get local issuer certificate
# codigo: 60
```

Sin `--cacert`, curl no conoce la CA del laboratorio, y la cadena no llega a
ninguna raíz de confianza. Es exactamente lo que verías ante un impostor.

### 2.3 Cuando ni siquiera hay certificado que comprobar

Hay fallos anteriores a la verificación: el handshake no llega a terminar.

| Código | Nombre | Cuándo |
|---|---|---|
| `35` | `CURLE_SSL_CONNECT_ERROR` | El handshake falla: versiones incompatibles, el servidor corta, no tiene certificado para ese nombre |
| `60` | `CURLE_PEER_FAILED_VERIFICATION` | La verificación del certificado falla: cadena, nombre o fechas |
| `51` | — | El valor antiguo del mismo error. Desde 7.62 se unificó en el 60; lo verás en scripts y foros viejos |

```bash
# Caddy solo tiene certificado para "localhost": por IP no hay nada que
# presentar, y el handshake se corta antes de llegar a verificar.
curl -sS --cacert docs/lab-ca.pem https://127.0.0.1:8443/get -o /dev/null; echo "codigo: $?"
# codigo: 35
```

La lección: `35` y `60` no se arreglan igual. El 60 casi siempre es "falta la
CA" o "nombre equivocado". El 35 es "no hemos llegado ni a hablar": versión,
nombre que el servidor no sirve, o un proxy en medio.

---

## 3. Cómo se usa

### 3.1 Ver solo la versión y el protocolo

```bash
curl -s --cacert docs/lab-ca.pem -o /dev/null \
  -w '%{http_version} %{ssl_verify_result}\n' https://localhost:8443/get
# 2 0
```

`%{http_version}` es el protocolo acordado por ALPN. `%{ssl_verify_result}` es
el resultado de la verificación según OpenSSL: `0` es que todo cuadró. La
Semana 06 entra a fondo en `--write-out`.

### 3.2 Exigir una versión mínima

curl 7.81 ya negocia TLS 1.2 como mínimo con la configuración de OpenSSL de
Ubuntu 22.04. Fijarlo explícito protege de entornos con una configuración más
permisiva:

```bash
curl --fail-with-body --max-time 10 --retry 3 --tlsv1.2 -sS \
  --cacert docs/lab-ca.pem https://localhost:8443/get
```

`--tlsv1.2` es "1.2 **o superior**", no "exactamente 1.2". Para un techo está
`--tls-max`; para probar si un servidor acepta 1.3, `--tlsv1.3`:

```bash
curl -s --cacert docs/lab-ca.pem --tlsv1.3 -o /dev/null -w '%{http_code}\n' \
  https://localhost:8443/get
# 200
```

### 3.3 Una petición de producción contra HTTPS

```bash
curl --fail-with-body --max-time 10 --retry 3 -sS \
  --cacert docs/lab-ca.pem \
  https://localhost:8443/get
```

Nada específico de TLS más allá del `--cacert`: la verificación está activa
por defecto, y así se queda.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `-k` / `--insecure` "para que funcione" | Apaga la autenticidad: el cifrado sigue, pero con quien sea que esté al otro lado | `--cacert` con la CA correcta ([archivo 02](02-confiar-en-una-ca-propia.md)) |
| Tratar el 35 y el 60 igual | Uno es "no hay handshake", el otro "el certificado no cuadra": causas y arreglos distintos | Leer el mensaje y el código |
| `http://` "porque es la red interna" | La red interna también tiene wifi, VPNs y equipos comprometidos | `https://` con la CA interna |
| Ignorar la hora del sistema | Un reloj desfasado hace que certificados válidos parezcan caducados o futuros | `timedatectl` / NTP en el equipo |
| `--tlsv1.0` para hablar con un servidor viejo | Rebaja la seguridad de todo lo que haga ese comando | Actualizar el servidor; si no se puede, aislarlo |

---

## 5. Trucos

```bash
# Que protocolo eligio el servidor, sin descargar nada util.
curl -sI --cacert docs/lab-ca.pem https://localhost:8443/get | head -1
# HTTP/2 200
```

```bash
# Todo el handshake, mensaje a mensaje: donde se corta una conexion que falla.
curl -sv --cacert docs/lab-ca.pem https://localhost:8443/get -o /dev/null 2>&1 \
  | grep -E 'TLS handshake'
```

```bash
# Que backend TLS usa tu curl: cambia mensajes y comportamientos.
curl --version | head -1 | grep -oE 'OpenSSL/[0-9.]+|GnuTLS/[0-9.]+|Schannel|SecureTransport'
# OpenSSL/3.0.2
```

---

## 📚 Recursos Adicionales

- [curl — SSL certificate verification](https://curl.se/docs/sslcerts.html) — la página a la que enlaza el propio error 60
- [everything.curl.dev — TLS](https://everything.curl.dev/usingcurl/tls.html) — versiones, verificación y backends
- [RFC 8446 — TLS 1.3](https://datatracker.ietf.org/doc/html/rfc8446) — la especificación, sección 2 para el handshake
- [libcurl — códigos de error](https://curl.se/libcurl/c/libcurl-errors.html) — el significado exacto de 35 y 60, y la nota del antiguo 51

---

## ✅ Checklist de Verificación

- [ ] Sé qué garantía de TLS depende de la verificación del certificado
- [ ] He localizado en `-v` la versión TLS, el ALPN, el `subjectAltName` y el `issuer`
- [ ] Sé las tres comprobaciones que hace curl del certificado
- [ ] He provocado un 60 (sin `--cacert`) y un 35 (por IP) y sé qué significa cada uno
- [ ] Sé qué hace `--tlsv1.2` y por qué no es "exactamente 1.2"

---

| Anterior | Siguiente |
|---|---|
| [Semana 05](../README.md) | [02 — Confiar en una CA propia](02-confiar-en-una-ca-propia.md) |
