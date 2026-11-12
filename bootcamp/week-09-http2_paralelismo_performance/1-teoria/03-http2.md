# HTTP/2

> HTTP/1.1 manda una petición por conexión y espera la respuesta antes de
> mandar la siguiente. Para pedir diez cosas a la vez, abre diez conexiones.
> HTTP/2 mete las diez en una sola, intercaladas. curl lo habla desde hace
> años y casi siempre lo elige solo: lo que hay que saber es cuándo no puede,
> y cómo comprobar cuál se usó.

![HTTP/1.1 frente a HTTP/2: a la izquierda, tres peticiones en HTTP/1.1 necesitan tres conexiones, o esperar en fila en una sola; a la derecha, las tres viajan como streams 1, 3 y 5 intercalados en una única conexión HTTP/2. Debajo, la negociación: ALPN dentro del handshake TLS ofrece h2 y http/1.1, el servidor elige h2; sin TLS, h2c necesita Upgrade o prior knowledge](../0-assets/03-http2.svg)

## 🎯 Objetivos

- Explicar qué cambia HTTP/2 respecto a 1.1: binario, streams, multiplexación
  y compresión de cabeceras
- Saber cómo se negocia (ALPN) y por qué sin TLS casi nunca se usa
- Comprobar con `%{http_version}` y con `-v` qué versión se usó de verdad
- Usar `--http2`, `--http1.1` y `--http2-prior-knowledge` sabiendo qué hace cada
  uno
- Reconocer lo que HTTP/2 no arregla

---

## 1. Qué problema resuelve

En HTTP/1.1 una conexión lleva **una petición a la vez**. El cliente manda la
petición, espera la respuesta entera, y solo entonces manda la siguiente. Si
la primera es lenta, las demás esperan detrás: es el *head-of-line blocking*
de HTTP.

La solución de los navegadores fue abrir seis conexiones por host. Funciona,
pero cada una paga su handshake, y el servidor sostiene seis veces más
conexiones.

HTTP/2 (RFC 9113) resuelve lo mismo con **una sola conexión** por host.

---

## 2. Cómo funciona

### 2.1 Frames y streams

HTTP/2 no es texto. Cada mensaje se parte en **frames** binarios: un frame
`HEADERS` con las cabeceras, frames `DATA` con el cuerpo. Cada petición y su
respuesta forman un **stream**, con un número (impar si lo abre el cliente:
1, 3, 5…).

Los frames de distintos streams se **intercalan** en la conexión. La petición
3 no espera a que termine la 1: sus frames viajan entre los de la otra. Eso es
la **multiplexación**.

El servidor anuncia cuántos streams acepta a la vez, y curl lo enseña con
`-v`:

```
* Connection state changed (MAX_CONCURRENT_STREAMS == 250)!
```

### 2.2 Cabeceras comprimidas y en minúsculas

HTTP/2 comprime las cabeceras con **HPACK**: una cabecera que se repite en
cada petición (el `User-Agent`, el `Authorization`) viaja entera una vez y
después como un índice. En una API con un token de 1 KB, eso son KB
ahorrados por petición.

Y los nombres van **siempre en minúsculas**. curl te enseña la respuesta tal
cual llega:

```bash
curl --cacert docs/lab-ca.pem -sI https://localhost:8443/get | head -3
# HTTP/2 200
# access-control-allow-credentials: true
# access-control-allow-origin: *
```

Un script que hace `grep '^Content-Type:'` deja de funcionar al pasar a
HTTP/2. Busca sin distinguir mayúsculas (`grep -i`), como hace `cabecera` en
el toolkit desde la Semana 07.

### 2.3 Cómo se negocia: ALPN

Sobre HTTPS, la versión se decide **dentro del handshake TLS**, con la
extensión ALPN: el cliente ofrece una lista (`h2`, `http/1.1`) y el servidor
elige. No cuesta ningún viaje extra.

```bash
curl --cacert docs/lab-ca.pem -sv -o /dev/null https://localhost:8443/get 2>&1 \
  | grep -E 'ALPN|HTTP2|^> GET'
# * ALPN, offering h2
# * ALPN, offering http/1.1
# * ALPN, server accepted to use h2
# * Using HTTP2, server supports multiplexing
# > GET /get HTTP/2
```

**Desde la 7.62.0, curl ofrece `h2` por defecto en toda URL `https://`.** No
hace falta `--http2`: si el servidor lo acepta, se usa.

### 2.4 Sin TLS: h2c

HTTP/2 en claro se llama **h2c**, y casi nadie lo sirve. Hay dos formas de
pedirlo:

- **`--http2` sobre `http://`** manda la petición en HTTP/1.1 con
  `Upgrade: h2c`. Si el servidor no sabe, responde en 1.1 y no pasa nada.
- **`--http2-prior-knowledge`** (7.49.0+) habla HTTP/2 desde el primer byte,
  sin preguntar. Si el servidor no sabe, la conexión falla.

El go-httpbin del laboratorio no habla h2c:

```bash
curl -s -o /dev/null --http2 -w '%{http_version}\n' http://localhost:8080/get
# 1.1

curl -s -o /dev/null --http2-prior-knowledge http://localhost:8080/get; echo "exit $?"
# exit 52
```

El 52 es *empty reply*: el servidor no entendió el saludo binario y cerró.

### 2.5 Los flags de versión

| Flag | Desde | Qué hace |
|---|:--:|---|
| (nada) | 7.62.0 | HTTPS: ofrece h2 y http/1.1 por ALPN. HTTP: 1.1 |
| `--http1.1` | 7.33.0 | Solo 1.1. Para comparar, o contra un servidor con un h2 roto |
| `--http2` | 7.33.0 | HTTPS: como sin nada. HTTP: 1.1 con `Upgrade: h2c` |
| `--http2-prior-knowledge` | 7.49.0 | HTTP/2 directo, sin negociar |
| `--http3` | 7.66.0 | Ver teoría 07; casi nunca está compilado |

Y para saber cuál se usó, `%{http_version}` (7.50.0+): `1.1`, `2` o `3`.

### 2.6 Lo que HTTP/2 no arregla

- **El head-of-line blocking de TCP.** Si se pierde un paquete, TCP retiene
  todos los que vienen detrás hasta recuperarlo, sean del stream que sean.
  Con pérdidas, una conexión HTTP/2 puede ir peor que seis HTTP/1.1. HTTP/3
  nace para eso (teoría 07).
- **Un servidor lento.** Si cada respuesta tarda 1 s, diez multiplexadas
  tardan 1 s… pero solo si las pides a la vez. Un curl con diez URLs y sin
  `-Z` las pide **una detrás de otra**, aunque sea por HTTP/2.
- **El orden.** Las respuestas llegan cuando están listas, no en el orden en
  que se pidieron.

---

## 3. Cómo se usa

Comparar la misma petición en 1.1 y en 2:

```bash
for v in --http1.1 --http2; do
  curl --cacert docs/lab-ca.pem -s -o /dev/null "$v" \
    -w "$v %{http_version} %{time_total}\n" https://localhost:8443/get
done
# --http1.1 1.1 0.004811
# --http2 2 0.004532
```

Una petición sola tarda lo mismo: HTTP/2 no acelera **una** petición. Gana
cuando hay muchas a la vez sobre la misma conexión, y eso es la teoría 04.

---

## 4. Antipatrones

- **Poner `--http2` "para que vaya más rápido"** en URLs `https://`. Desde la
  7.62.0 ya es el comportamiento por defecto.
- **`--http2-prior-knowledge` contra un servidor que no lo anuncia.** Falla con
  52 o con un error de protocolo. Úsalo solo si sabes que el servidor habla
  h2c (un servicio gRPC interno, por ejemplo).
- **Parsear cabeceras distinguiendo mayúsculas.** En HTTP/2 vienen en
  minúsculas siempre.
- **Dar por hecho que hubo HTTP/2.** Un proxy corporativo, un balanceador o un
  curl compilado sin nghttp2 lo bajan a 1.1 sin avisar. Mira
  `%{http_version}`.
- **Esperar que un `Connection: close` funcione en HTTP/2.** Esa cabecera está
  prohibida en HTTP/2: la conexión se cierra con un frame `GOAWAY`.

---

## 5. Trucos

- **¿Tu curl sabe HTTP/2?** `curl --version | grep -o HTTP2`. Si no imprime
  nada, no hay nghttp2, y `--http2` no hará nada.
- **La versión de cada petición en un lote**: `-w '%{http_version}\n'` con
  varias URLs imprime una línea por cada una.
- **`curl -sI` enseña la línea de estado de HTTP/2** como `HTTP/2 200`, sin
  texto de razón: en HTTP/2 el `OK` no existe.
- **Para ver los streams**, `-v` dice qué número le toca a cada petición:
  `* Using Stream ID: 1`. Con varias URLs multiplexadas verás el 1, el 3, el 5…
- **El `alt-svc` de la respuesta** dice si el servidor ofrece HTTP/3. El
  laboratorio lo anuncia: `alt-svc: h3=":8443"`.

---

## 📚 Recursos Adicionales

- [RFC 9113 — HTTP/2](https://datatracker.ietf.org/doc/html/rfc9113)
- [Everything curl — HTTP/2](https://everything.curl.dev/http/versions/http2.html)
- [High Performance Browser Networking, capítulo 12 — HTTP/2](https://hpbn.co/http2/)

---

## ✅ Checklist de Verificación

- [ ] Explicas qué son un frame y un stream, y qué es multiplexar
- [ ] Explicas cómo ALPN negocia la versión sin coste extra
- [ ] Sabes por qué `--http2` sobre `http://` acaba casi siempre en 1.1
- [ ] Compruebas la versión usada con `%{http_version}`
- [ ] Nombras tres cosas que HTTP/2 no arregla
