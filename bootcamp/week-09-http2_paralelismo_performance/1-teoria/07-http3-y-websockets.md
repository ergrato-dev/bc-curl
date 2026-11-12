# HTTP/3 y WebSockets

> Dos cosas que vas a encontrar en APIs reales y que tu curl 7.81 no sabe
> hablar. HTTP/3 cambia TCP por QUIC para que un paquete perdido no frene a
> todos los demás. WebSocket convierte una petición HTTP en un canal abierto
> en las dos direcciones. Esta teoría explica qué son, cómo reconocerlos con
> la versión que tienes y desde qué versión curl los habla.

![A la izquierda, la pila de HTTP/2 (TLS sobre TCP) frente a la de HTTP/3 (QUIC sobre UDP, con TLS 1.3 dentro), y el descubrimiento por la cabecera alt-svc. A la derecha, el handshake de WebSocket: una petición GET con Upgrade: websocket y Sec-WebSocket-Key, la respuesta 101 Switching Protocols con Sec-WebSocket-Accept, y a partir de ahí mensajes en las dos direcciones sobre la misma conexión](../0-assets/07-http3-y-websockets.svg)

## 🎯 Objetivos

- Explicar qué problema de HTTP/2 resuelve HTTP/3 y por qué va sobre UDP
- Saber cómo descubre un cliente que el servidor habla HTTP/3 (`alt-svc`)
- Comprobar si tu curl tiene HTTP/3 antes de usar `--http3`
- Explicar el handshake de WebSocket y verlo con curl 7.81
- Saber desde qué versión curl habla `ws://` y qué alternativa usar antes

---

## 1. Qué problema resuelve

**HTTP/3.** HTTP/2 mete muchos streams en una conexión TCP. Pero TCP entrega
los bytes **en orden**: si se pierde un paquete del stream 1, los del stream
3 y 5 que ya llegaron esperan en el buffer hasta que se recupere. Con una red
con pérdidas (móvil, Wi-Fi saturada), la multiplexación se vuelve en contra.

**WebSocket.** HTTP es pregunta-respuesta: el servidor no puede hablar si el
cliente no pregunta. Para notificaciones, chats o precios en tiempo real, el
cliente tendría que preguntar cada segundo (*polling*). WebSocket abre un
canal donde **los dos** mandan mensajes cuando quieren.

---

## 2. Cómo funciona

### 2.1 HTTP/3 y QUIC

HTTP/3 (RFC 9114) va sobre **QUIC** (RFC 9000), un transporte sobre **UDP**:

- QUIC gestiona él mismo la entrega, **por stream**. Un paquete perdido solo
  frena a su stream.
- **TLS 1.3 va dentro de QUIC**: transporte y cifrado se negocian en el mismo
  viaje. Una conexión nueva cuesta 1 RTT, y una reanudada puede costar 0.
- Una conexión QUIC sobrevive a un **cambio de IP** (de Wi-Fi a datos móviles)
  porque se identifica por un ID, no por la IP y el puerto.

Al ser UDP, muchas redes corporativas lo bloquean. Por eso un cliente **nunca
empieza** por HTTP/3: empieza por HTTP/2 o 1.1 sobre TCP, y el servidor le
avisa de que existe la otra vía.

### 2.2 El aviso: `alt-svc`

La cabecera `alt-svc` (RFC 7838) dice "también estoy en este otro protocolo y
puerto". El laboratorio la manda:

```bash
curl --cacert docs/lab-ca.pem -sI https://localhost:8443/get | grep -i alt-svc
# alt-svc: h3=":8443"; ma=2592000
```

`h3` en el puerto 8443 (UDP), válido 30 días (`ma` en segundos). Un navegador
lo apunta y la siguiente vez prueba HTTP/3. curl puede hacer lo mismo con
`--alt-svc ARCHIVO` (7.64.1+), que guarda y lee esos avisos… siempre que esté
compilado con HTTP/3.

### 2.3 `--http3` en tu curl

`--http3` existe desde la 7.66.0, pero **casi ninguna distribución compila
curl con HTTP/3**. Ubuntu 22.04 no:

```bash
curl --version | grep -o HTTP3
#                  ← nada: tu curl no lo trae

curl --http3 https://localhost:8443/get
# curl: option --http3: the installed libcurl version doesn't support this
echo $?
# 2
```

| Flag | Desde | Qué hace |
|---|:--:|---|
| `--http3` | 7.66.0 | Desde la 7.88.0, prueba HTTP/3 y cae a 2 o 1.1 si no conecta; antes, solo HTTP/3 |
| `--http3-only` | 7.88.0 | Solo HTTP/3: si no conecta, falla |

Para probarlo contra el laboratorio con un curl que sí lo trae, hay un
contenedor documentado en
[`docs/versiones-de-curl.md`](../../../docs/versiones-de-curl.md). Es
opcional: nada de esta semana lo necesita.

### 2.4 WebSocket: el handshake es HTTP

Un WebSocket (RFC 6455) empieza como una petición HTTP/1.1 normal que pide
cambiar de protocolo:

```
GET /websocket/echo HTTP/1.1
Connection: Upgrade
Upgrade: websocket
Sec-WebSocket-Version: 13
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
```

Si el servidor acepta, responde **101 Switching Protocols**, y a partir de ese
momento la conexión ya no habla HTTP: habla *frames* de WebSocket, en las dos
direcciones.

`Sec-WebSocket-Accept` es el SHA-1 de la clave más una constante fija del RFC,
en base64. No es seguridad: solo demuestra que el servidor entiende WebSocket
y no es un proxy que devuelve cualquier cosa.

### 2.5 Lo que curl 7.81 puede hacer

El handshake, sí. Es HTTP con cuatro cabeceras:

```bash
curl -s -i --max-time 2 \
  -H 'Connection: Upgrade' -H 'Upgrade: websocket' \
  -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  http://localhost:8080/websocket/echo | tr -d '\r' | head -4
# HTTP/1.1 101 Switching Protocols
# Connection: upgrade
# Sec-Websocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
# Upgrade: websocket
```

Después, curl 7.81 no sabe leer ni escribir frames: se queda esperando hasta
el `--max-time`. Sirve para **diagnosticar**: si el endpoint responde 101, el
servidor y los proxies intermedios dejan pasar el WebSocket. Si responde 400,
200 o 426, algo en el camino no lo acepta.

Sin las cabeceras, el endpoint del laboratorio lo dice claro:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/websocket/echo
# 400
```

### 2.6 `ws://` y `wss://` en curl

curl habla WebSocket con URLs `ws://` y `wss://`:

- **7.86.0**: soporte **experimental**, que hay que activar al compilar.
- **8.11.0**: deja de ser experimental y viene activado por defecto.

Con un curl 8.11 o posterior, `curl ws://servidor/ruta` hace el handshake y
vuelca los mensajes recibidos por stdout. Con 7.81 no existe: para hablar
WebSocket desde el terminal hace falta otra herramienta (`websocat` es la más
usada).

---

## 3. Cómo se usa

Tres comprobaciones que sí puedes hacer con 7.81 contra cualquier API:

```bash
# ¿Ofrece HTTP/3?
curl -sI https://api.ejemplo.com/ | grep -i '^alt-svc'

# ¿Mi curl podría usarlo?
curl --version | grep -o HTTP3 || echo "sin HTTP/3"

# ¿El endpoint WebSocket llega vivo a través de los proxies?
curl -s -o /dev/null -w '%{http_code}\n' --max-time 3 \
  -H 'Connection: Upgrade' -H 'Upgrade: websocket' \
  -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  https://api.ejemplo.com/ws
# 101
```

`%{http_code}` sale aunque curl acabe por timeout: el 101 ya llegó.

---

## 4. Antipatrones

- **`--http3` en un script sin comprobar `Features:`.** En la mayoría de
  máquinas sale con 2 antes de hacer nada.
- **Esperar que HTTP/3 vaya siempre más rápido.** En una red sin pérdidas y
  con poca latencia, la diferencia con HTTP/2 es pequeña; y si UDP está
  bloqueado, el intento fallido cuesta tiempo.
- **Polling cada segundo** cuando la API ofrece WebSocket o eventos
  (*server-sent events*). Gasta rate limit y llega tarde.
- **Usar curl 7.81 como cliente WebSocket.** Diagnostica el handshake; para
  conversar hace falta otra herramienta.
- **Copiar la `Sec-WebSocket-Key` del RFC en un cliente real.** Debe ser
  aleatoria por conexión; la del ejemplo vale solo para diagnosticar.

---

## 5. Trucos

- **`curl --version`, línea `Features:`**: `HTTP2`, `HTTP3` y `alt-svc`
  dicen qué sabe tu binario. `Protocols:` dice si trae `ws` y `wss`.
- **El 101 en un lote**: `-w '%{http_code}'` con `--max-time 2` comprueba
  varios endpoints WebSocket sin quedarse colgado.
- **`ma` en `alt-svc`** son segundos: 2592000 son 30 días.
- **`-sI` y `alt-svc`** te dicen en un comando si un CDN ya sirve HTTP/3.
- **Para ver HTTP/3 en el laboratorio sin instalar nada**, el contenedor de
  `docs/versiones-de-curl.md` imprime `3` en `%{http_version}`.

---

## 📚 Recursos Adicionales

- [RFC 9114 — HTTP/3](https://datatracker.ietf.org/doc/html/rfc9114)
- [RFC 6455 — The WebSocket Protocol](https://datatracker.ietf.org/doc/html/rfc6455)
- [curl — WebSocket](https://curl.se/docs/websocket.html)

---

## ✅ Checklist de Verificación

- [ ] Explicas qué head-of-line blocking resuelve HTTP/3 y por qué va sobre UDP
- [ ] Encuentras el `alt-svc` de una respuesta y lo interpretas
- [ ] Compruebas si tu curl soporta HTTP/3 antes de usar `--http3`
- [ ] Haces el handshake de WebSocket con curl 7.81 y lees el 101
- [ ] Sabes desde qué versión curl habla `ws://` y qué usar antes
