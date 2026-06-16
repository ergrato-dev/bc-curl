# Glosario — Semana 9: HTTP/2, Paralelismo y Performance

## Terminos Principales

**HTTP/2**
Version 2 del protocolo HTTP (RFC 7540). Introduce multiplexing, compresion de headers HPACK y transmision binaria. Permite multiples requests simultaneos sobre una sola conexion TCP. Requiere soporte en el servidor y en el cliente (curl compilado con nghttp2).

**HTTP/3**
Version 3 del protocolo HTTP (RFC 9114). Usa QUIC (sobre UDP) en lugar de TCP, eliminando el head-of-line blocking a nivel de transporte. curl tiene soporte experimental con `--http3`.

**QUIC**
Protocolo de transporte desarrollado por Google, estandarizado en RFC 9000. Implementa control de congestión, corrección de errores y multiplexing sobre UDP. Base de HTTP/3.

**Multiplexing**
Capacidad de enviar multiples requests y recibir multiples respuestas de forma simultanea sobre una sola conexion TCP. Característica central de HTTP/2. Elimina la necesidad de abrir multiples conexiones paralelas.

**HPACK**
Algoritmo de compresion de headers HTTP definido en RFC 7541, usado en HTTP/2. Mantiene una tabla de headers previamente enviados y los referencia con indices compactos, reduciendo el tamaño de headers repetidos a uno o pocos bytes.

**nghttp2**
Libreria C que implementa el protocolo HTTP/2. curl usa nghttp2 cuando se compila con soporte HTTP/2. `curl --version | grep nghttp2` muestra si esta presente.

**Keepalive**
Mecanismo de HTTP/1.1 (header `Connection: keep-alive`) que mantiene la conexion TCP abierta para reutilizar en requests subsiguientes. Evita el overhead de TCP+TLS handshake por cada request. Activado por defecto en curl.

**TTFB**
Time To First Byte. El tiempo desde que el cliente envia el request hasta que recibe el primer byte de la respuesta (excluyendo la descarga del body). Indicador del tiempo de procesamiento del servidor. En curl: `time_starttransfer`.

**parallel**
Flag de curl (`--parallel` o `-Z`) que activa el modo de requests paralelos. Multiples URLs se descargan simultaneamente en el mismo proceso curl. Disponible desde curl 7.66.

**parallel-max**
Flag de curl (`--parallel-max N`) que limita el numero maximo de conexiones paralelas cuando se usa `--parallel`. Default: 50. Se recomienda reducirlo para no saturar servidores o violar rate limits.

**WebSocket**
Protocolo de comunicacion full-duplex sobre una conexion TCP persistente. Comienza con un upgrade desde HTTP. Permite que servidor y cliente envien mensajes en cualquier momento sin que haya un request previo.

**Upgrade**
Header HTTP que solicita cambiar el protocolo de la conexion actual. En WebSockets: `Upgrade: websocket`. El servidor responde con `101 Switching Protocols` si acepta.

**101 Switching Protocols**
Codigo de estado HTTP que indica que el servidor acepto cambiar el protocolo segun lo solicitado en el header `Upgrade`. Unico uso comun: handshake de WebSocket.

**ALPN**
Application-Layer Protocol Negotiation. Extension de TLS que permite al cliente y servidor negociar que protocolo de capa de aplicacion usar (HTTP/1.1, HTTP/2) durante el TLS handshake, sin necesidad de un round-trip adicional.

**h2**
Identificador del protocolo HTTP/2 en la negociacion ALPN. Se ve en logs de curl con `-v` como `ALPN: offering h2` o `ALPN: server accepted h2`.

**h2c**
HTTP/2 cleartext — HTTP/2 sin TLS. Poco comun en produccion (requiere "prior knowledge" o upgrade HTTP/1.1). Util para desarrollo local. En curl: `--http2-prior-knowledge`.

**time_namelookup**
Variable de `--write-out` en curl. Tiempo desde el inicio hasta que el DNS lookup completo. Valores altos indican DNS lento.

**time_connect**
Variable de `--write-out` en curl. Tiempo desde el inicio hasta que se completo el TCP handshake (3-way handshake).

**time_appconnect**
Variable de `--write-out` en curl. Tiempo desde el inicio hasta que se completo el TLS/SSL handshake. Para HTTP sin TLS, es 0.

**time_starttransfer**
Variable de `--write-out` en curl. Tiempo desde el inicio hasta que se recibio el primer byte del body de la respuesta. Equivale a TTFB.

**time_total**
Variable de `--write-out` en curl. Tiempo total desde el inicio hasta que se completo la transferencia (headers + body completo).

**p50 / p90 / p99**
Percentiles de una distribucion de tiempos. p50 (mediana): el 50% de los requests fue mas rapido que este valor. p90: el 90% fue mas rapido. p99: el 99% fue mas rapido. Los percentiles altos (p99) revelan los casos mas lentos ("tail latency") que el promedio oculta.

**Head-of-line blocking**
Fenomeno donde un elemento en una cola bloquea a todos los siguientes. En HTTP/1.1 pipelining: un request lento bloquea los que vienen despues. HTTP/2 lo resuelve a nivel HTTP pero TCP lo sigue teniendo. HTTP/3/QUIC lo resuelve completamente.

**websocat**
Herramienta de linea de comandos para interactuar con servidores WebSocket. Similar a curl pero especializada en WS. Permite enviar y recibir mensajes WebSocket de forma interactiva o en scripts.
