# Ejercicio 04: WebSockets con curl

## Objetivo

Entender el handshake de WebSocket a nivel HTTP, verificarlo con curl, e identificar los limites de curl como cliente WebSocket.

**Duracion estimada:** 30 minutos

## Prerequisitos

- curl instalado (se comprobara la version)
- `openssl` instalado (para generar el key del handshake)
- Completados los ejercicios anteriores

---

## Tarea 1: Verificar soporte WebSocket en curl

```bash
curl --version | grep -i websocket
curl --version | grep -i features
```

Si aparece `WebSockets` en Features, el build actual soporta WS nativo (curl >= 7.86). Si no aparece, se usara el metodo manual de handshake HTTP.

Anotar en `respuestas.md`:
- Version de curl instalada
- Aparece WebSockets en las features? Si/No

---

## Tarea 2: Handshake WebSocket manual

El handshake de WebSocket es un request HTTP con headers especiales. curl puede enviarlo aunque no soporte WS nativo:

```bash
curl -v \
  -H "Upgrade: websocket" \
  -H "Connection: Upgrade" \
  -H "Sec-WebSocket-Key: $(openssl rand -base64 16)" \
  -H "Sec-WebSocket-Version: 13" \
  https://ws.postman-echo.com/raw 2>&1 | head -40
```

Anotar el output en `respuestas.md`. Buscar en el output:
- El codigo de respuesta del servidor (deberia ser `101 Switching Protocols`)
- El header `Upgrade: websocket` en la respuesta
- El header `Sec-WebSocket-Accept` en la respuesta

Si el servidor retorna 200 o 400 en lugar de 101, el endpoint no soporta WS o hubo un error en los headers.

---

## Tarea 3: Identificar los headers del handshake

En el output verbose de la Tarea 2, identificar y anotar cada header:

**Request (enviado por curl):**
- `Upgrade: websocket` — indica que se quiere cambiar de protocolo
- `Connection: Upgrade` — indica que la conexion debe procesarse como Upgrade
- `Sec-WebSocket-Key: [base64 random]` — nonce aleatorio para verificar el handshake
- `Sec-WebSocket-Version: 13` — version del protocolo WebSocket

**Response (enviado por el servidor):**
- `101 Switching Protocols` — el servidor acepta el upgrade
- `Upgrade: websocket` — confirma el protocolo
- `Sec-WebSocket-Accept: [hash]` — derivado del Key enviado (SHA1 + base64)

En `respuestas.md`, copiar el valor de `Sec-WebSocket-Key` y `Sec-WebSocket-Accept` del output. El servidor calcula el Accept a partir del Key — esa es la verificacion de que el servidor entiende WebSocket.

---

## Tarea 4: Soporte nativo (curl >= 7.86)

Si la Tarea 1 confirmo soporte nativo, probar:

```bash
# Enviar un mensaje y recibir el echo
curl --websocket wss://ws.postman-echo.com/raw \
  --data "hola desde curl"
```

Si curl < 7.86, saltear esta tarea y documentar el motivo.

---

## Tarea 5: Limitaciones de curl para WebSocket

Responder en `respuestas.md`:

1. curl esta disenado para request/response. Una vez que el servidor acepta el handshake WS (101), que le pasa a curl si intenta leer frames WS que llegan en streaming?

2. Para una aplicacion que necesita mantener una conexion WS abierta e intercambiar mensajes en tiempo real, que herramienta alternativa es mas adecuada que curl?

3. Mencionar al menos dos casos de uso donde curl SI es util para testing de WebSocket (aunque no soporte sesiones persistentes).

---

## Tarea Bonus: websocat

Si se puede instalar `websocat` (cliente WS nativo):

```bash
# Instalar (Linux)
cargo install websocat
# o descargar binario desde https://github.com/vi/websocat/releases

# Conectar y enviar mensaje
echo "hola" | websocat wss://ws.postman-echo.com/raw
```

Comparar la experiencia con el metodo manual de curl.

---

## Entrega

- `respuestas.md` con:
  - Version de curl y soporte WebSocket (Tarea 1)
  - Output del handshake manual con los headers identificados (Tareas 2 y 3)
  - Resultado de soporte nativo si aplica (Tarea 4)
  - Respuestas de analisis (Tarea 5)
