# WebSockets con curl

## Que es WebSocket

WebSocket es un protocolo de comunicacion full-duplex sobre TCP. A diferencia de HTTP (request → response → cierra/reutiliza), WebSocket establece un canal persistente donde ambas partes pueden enviar mensajes en cualquier momento sin necesidad de un request previo.

Casos de uso tipicos: chat en tiempo real, actualizaciones en vivo (precio de acciones, estado de un job), juegos en linea, notificaciones push.

---

## El Handshake de Upgrade

WebSocket comienza con un request HTTP que solicita "upgrade" del protocolo:

```
Cliente                              Servidor
  |                                      |
  |--- GET /ws HTTP/1.1 ---------------->|
  |    Upgrade: websocket                |
  |    Connection: Upgrade               |
  |    Sec-WebSocket-Key: dGhlIHNhbXBsZ |
  |    Sec-WebSocket-Version: 13         |
  |                                      |
  |<-- HTTP/1.1 101 Switching Protocols -|
  |    Upgrade: websocket                |
  |    Connection: Upgrade               |
  |    Sec-WebSocket-Accept: s3pPLMBiTx  |
  |                                      |
  |======== Canal WebSocket =============|
  |<====== mensajes bidireccionales ====>|
```

El status 101 (Switching Protocols) confirma que el servidor acepto el upgrade. Despues de eso, la conexion TCP ya no habla HTTP sino el protocolo WebSocket.

---

## curl y WebSockets

### Versiones con soporte nativo

curl 7.86.0 (octubre 2022) agrego soporte experimental para WebSocket. En versiones 8.x esta mas maduro pero sigue siendo "experimental" oficialmente.

Verificar soporte:
```bash
curl --version | grep WebSockets
# Features: ... WebSockets ...
```

### Alternativa: Simular el Handshake Manualmente

Aunque curl no tenga soporte WS nativo, se puede hacer el handshake HTTP a mano y ver el 101:

```bash
# Generar una clave WS valida (16 bytes random en base64)
WS_KEY=$(openssl rand -base64 16)

# Hacer el request de upgrade
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: $WS_KEY" \
  "https://ws.postman-echo.com/raw"
```

Con `-N` (no-buffer) y `-i` (incluir headers), se puede ver el handshake. Sin embargo, despues del 101 el protocolo es binario y curl no lo maneja como WS — la conexion se ve "colgada" o cierra.

### Con Soporte Nativo (curl 7.86+)

```bash
# Verificar que tiene soporte
curl --version | grep -i websocket

# Conectar a un servidor WebSocket
# --no-buffer es importante para ver la comunicacion en tiempo real
curl -v --no-buffer \
  "wss://ws.postman-echo.com/raw"
```

Con soporte nativo, curl mantiene la conexion WS abierta. Sin embargo, la interfaz de linea de comandos de curl no esta bien diseñada para sesiones interactivas WS — es mejor para testing del handshake y mensajes simples.

---

## Herramientas Especializadas para WebSocket

Para uso real con WebSockets, existen herramientas dedicadas:

```bash
# websocat — mejor alternativa CLI para WebSocket
# Instalacion:
# Linux: cargo install websocat  o  apt-get install websocat
# macOS: brew install websocat

# Conectar y enviar/recibir mensajes interactivamente
websocat "wss://ws.postman-echo.com/raw"

# Enviar un mensaje y recibir respuesta (echo server)
echo "hola mundo" | websocat "wss://ws.postman-echo.com/raw"

# wscat (Node.js)
npm install -g wscat
wscat -c "wss://ws.postman-echo.com/raw"
```

---

## Testing de WebSocket Servers con curl

El caso de uso practico de curl con WebSockets en scripting es verificar que el endpoint existe y acepta el upgrade:

```bash
check_websocket() {
  local url="$1"
  local ws_key
  ws_key=$(openssl rand -base64 16)
  
  # Hacer el request de upgrade (HTTP a WS)
  response=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 5 \
    -H "Connection: Upgrade" \
    -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" \
    -H "Sec-WebSocket-Key: $ws_key" \
    "$url")
  
  if [ "$response" = "101" ]; then
    echo "OK: $url acepta WebSocket (101 Switching Protocols)"
    return 0
  else
    echo "FAIL: $url respondio $response (esperado 101)"
    return 1
  fi
}

check_websocket "https://ws.postman-echo.com/raw"
```

---

## Inspeccion del Handshake

Para debugging, ver el handshake completo con `-v`:

```bash
WS_KEY=$(openssl rand -base64 16)

curl -v \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: $WS_KEY" \
  "wss://ws.postman-echo.com/raw" 2>&1 | head -40
```

Buscar en la salida:
- `> Upgrade: websocket` — el cliente solicito el upgrade
- `< HTTP/1.1 101 Switching Protocols` — el servidor acepto
- `< Sec-WebSocket-Accept: ...` — la clave de confirmacion del servidor

La clave de confirmacion es `SHA1(WS_KEY + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")` en base64. Se puede verificar:

```bash
echo -n "${WS_KEY}258EAFA5-E914-47DA-95CA-C5AB0DC85B11" | \
  openssl dgst -sha1 -binary | base64
```

---

## Resumen

| Aspecto | curl | websocat / wscat |
|---------|------|-----------------|
| Handshake WS | Si | Si |
| Mensajes interactivos | Limitado (7.86+) | Si |
| Verificacion de endpoint | Excelente | Parcial |
| Uso en scripts | Si | Si |
| Facil de usar | Si | Si |

Para **verificar que un endpoint WS existe y responde**: curl es suficiente.
Para **enviar y recibir mensajes**: usar websocat o wscat.
