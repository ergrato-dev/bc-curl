# HTTP/2: Conceptos y Diferencias con HTTP/1.1

## El Problema de HTTP/1.1

HTTP/1.1, publicado en 1999, funciona con un modelo simple: un request por conexion TCP a la vez. Para cargar una pagina web con 30 recursos (HTML, CSS, JS, imagenes), el browser necesita:

- Abrir multiples conexiones TCP (browsers tipicamente abren 6 por dominio)
- Esperar que cada request complete antes de hacer el siguiente en la misma conexion
- Pagar el overhead de TCP handshake + TLS handshake por cada conexion nueva

El resultado: mucha latencia, especialmente en redes con alta latencia (mobile, WAN).

HTTP pipelining intento resolver esto enviando multiples requests sin esperar respuestas, pero tenia problemas de "head-of-line blocking" (si un request falla o es lento, bloquea todos los siguientes) y nunca fue ampliamente adoptado.

---

## HTTP/2: Las Mejoras Clave

### 1. Multiplexing

Multiples requests y respuestas viajan **simultaneamente** en la misma conexion TCP. Cada request/response es un "stream" identificado con un numero. El servidor puede responder en cualquier orden.

```
HTTP/1.1 — 3 conexiones para 3 recursos:
Conn1: [==REQ1==][===RESP1===]
Conn2: [==REQ2==][=RESP2=]
Conn3: [==REQ3==][====RESP3====]

HTTP/2 — 1 conexion, 3 streams paralelos:
        [REQ1][REQ2][REQ3]
        [====RESP1====][=RESP2=][===RESP3===]
```

El beneficio es mayor cuando hay muchos recursos pequenos en el mismo servidor.

### 2. Header Compression (HPACK)

En HTTP/1.1, cada request repite todos los headers (Host, Accept, Authorization, Cookie...) en texto plano. En una sesion con 50 requests, eso son los mismos 500 bytes de headers repetidos 50 veces.

HTTP/2 usa HPACK: compresor de headers que mantiene una tabla de headers previamente enviados. Los headers repetidos se referencian con un solo byte en lugar de enviarse completos.

### 3. Server Push (teorico, raro en practica)

El servidor puede enviar recursos que el cliente no pidio pero que sabe que va a necesitar (por ejemplo, enviar el CSS junto con el HTML). En la practica, Server Push fue mal implementado y fue desactivado en Chrome y otros browsers. Mencionarlo como concepto pero no usarlo.

### 4. Binario, no texto

HTTP/1.1 es texto plano (legible para humanos). HTTP/2 es binario (mas eficiente para parsear, menos errores de implementacion). Esto significa que ya no se puede usar `telnet` para hablar HTTP/2 directamente.

---

## HTTP/3 sobre QUIC

HTTP/3 reemplaza TCP por QUIC (UDP con control de congestión incorporado). Resuelve el "head-of-line blocking" que persiste en HTTP/2 (porque aunque los requests son paralelos, viajan por el mismo TCP y un paquete perdido bloquea todo el stream).

curl soporta HTTP/3 si fue compilado con `--with-quiche` o `--with-ngtcp2`. Verificar:

```bash
curl --version | grep "quiche\|ngtcp2\|HTTP3"
```

HTTP/3 es relevante para casos con alta perdida de paquetes (mobile en movimiento, satélite). Para redes estables, la diferencia es menor.

---

## curl y HTTP/2

### Verificar soporte

```bash
curl --version | grep -E "Features:|HTTP2"
```

Buscar `HTTP2` en la linea de Features. Si no aparece, curl fue compilado sin soporte HTTP/2.

Para instalar curl con HTTP/2:
- Ubuntu/Debian: `sudo apt-get install curl` (normalmente ya incluye HTTP2 en versiones recientes)
- macOS con Homebrew: `brew install curl` (usar el path de brew, no el del sistema)
- Fedora/RHEL: `sudo dnf install curl`

### Forzar version HTTP

```bash
# Forzar HTTP/1.1
curl --http1.1 https://www.example.com

# Forzar HTTP/2 (falla si el servidor no lo soporta o curl no tiene soporte)
curl --http2 https://www.example.com

# HTTP/2 prior knowledge (sin TLS, para servidores h2c)
curl --http2-prior-knowledge http://servidor-local:8080

# HTTP/3 (requiere soporte compilado)
curl --http3 https://cloudflare.com
```

### Verificar que realmente usa HTTP/2

```bash
# Ver en los headers de respuesta
curl -sI --http2 https://www.google.com | head -2
# HTTP/2 200  <-- confirma que uso HTTP/2

# Ver la negociacion en el TLS handshake con -v
curl -sv --http2 https://www.google.com 2>&1 | grep -E "ALPN|HTTP/"
# ALPN: h2  <-- negocio HTTP/2 via ALPN
# < HTTP/2 200
```

---

## Cuándo Importa HTTP/2

HTTP/2 da mayor beneficio cuando:
- Hay muchos recursos en el mismo servidor (muchos requests al mismo host)
- Los requests son pequenos (headers comprimidos ayudan mas)
- La latencia de red es alta (el multiplexing elimina round-trips)

HTTP/2 da poco o ningun beneficio cuando:
- Solo haces un request ocasional (el beneficio del multiplexing no aplica)
- El cuerpo de las respuestas es muy grande (el bandwidth es el cuello de botella, no el protocolo)
- El servidor no tiene soporte HTTP/2

Para scripting con curl, HTTP/2 es especialmente util cuando se combinan con `--parallel` — curl puede usar una sola conexion HTTP/2 para multiples requests paralelos al mismo servidor.

---

## Comparacion Rapida

| Caracteristica | HTTP/1.1 | HTTP/2 | HTTP/3 |
|----------------|----------|--------|--------|
| Protocolo base | TCP | TCP | QUIC (UDP) |
| Formato | Texto | Binario | Binario |
| Multiplexing | No | Si | Si |
| Compresion headers | No | HPACK | QPACK |
| Head-of-line blocking | Si | Si (a nivel TCP) | No |
| Soporte curl | Siempre | Si (con nghttp2) | Experimental |
