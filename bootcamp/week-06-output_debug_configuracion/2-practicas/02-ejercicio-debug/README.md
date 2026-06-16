# Ejercicio 2: Depuracion con -v y --trace-ascii

## Objetivo

Aprender a leer el output de depuracion de curl para entender exactamente que
sucede durante una transferencia HTTP: desde la conexion TCP hasta la recepcion
del body.

## Parte 1: depuracion basica con -v

Ejecuta este comando y guarda el output completo (stdout y stderr juntos):

```bash
curl -v https://httpbin.org/get 2>&1 | tee verbose-output.txt
```

Abre `verbose-output.txt` e identifica las siguientes secciones. Marca en el
archivo (con un comentario o anotacion) donde comienza y termina cada una:

- [ ] Resolucion DNS y conexion TCP (lineas con `Trying` y `Connected`)
- [ ] Inicio del TLS handshake (`TLS handshake` o `SSL connection`)
- [ ] Version TLS negociada y cipher suite elegido
- [ ] Nombre del servidor en el certificado (CN=)
- [ ] Headers enviados por curl (lineas con `>`)
- [ ] Primera linea de respuesta del servidor (linea con `< HTTP/`)
- [ ] Headers de respuesta (lineas con `<`)
- [ ] Inicio del body (linea en blanco despues de los headers)

Responde en `respuestas.md`:
- Que version de TLS se nego?
- Que cipher suite se uso?
- Cuantos headers envio curl en el request?
- Cuantos headers devolvio el servidor en la respuesta?

## Parte 2: trace completo con --trace-ascii

```bash
curl --trace-ascii trace-https.txt \
     --trace-time \
     -o body.json \
     https://httpbin.org/get
```

Abre `trace-https.txt`. Busca y anota los timestamps (columna izquierda) de:

1. El primer bloque `Send SSL data` (inicio del TLS handshake)
2. El primer bloque `Recv SSL data` (primera respuesta TLS del servidor)
3. El bloque `Send header` (envio del request HTTP)
4. El primer bloque `Recv header` (recepcion de la respuesta HTTP)
5. El primer bloque `Recv data` (inicio del body)

Con esos timestamps, calcula:
- Duracion del TLS handshake (punto 1 a punto 3)
- Tiempo del servidor para responder despues de recibir el request (punto 3 a punto 4)
- Tiempo para recibir el body completo (punto 4 a ultimo `Recv data`)

## Parte 3: comparar HTTP/1.1 vs HTTP/2

```bash
# HTTP/1.1 explicitamente
curl --trace-ascii trace-http1.txt --trace-time \
     --http1.1 -o /dev/null \
     https://httpbin.org/get

# HTTP/2 (default)
curl --trace-ascii trace-http2.txt --trace-time \
     -o /dev/null \
     https://httpbin.org/get
```

Compara los dos archivos:

```bash
wc -l trace-http1.txt trace-http2.txt
```

Diferencias a buscar en los traces:
- En HTTP/1.1 los headers son texto ASCII plano en `Send header`
- En HTTP/2 hay bloques de datos binarios adicionales (framing HEADERS frame)
- Busca en el trace HTTP/2 si ves `SETTINGS` o `WINDOW_UPDATE` — son frames
  de control del protocolo HTTP/2

Responde: el trace de HTTP/2 tiene mas o menos lineas que HTTP/1.1? Por que?

## Parte 4: depurar un request POST

```bash
curl -v -X POST \
     -H "Content-Type: application/json" \
     -d '{"titulo": "prueba", "contenido": "texto de prueba"}' \
     https://httpbin.org/post 2>&1 | tee verbose-post.txt
```

En el output de -v, busca las lineas con `>` que correspondan al body enviado.
Nota: en verbose, el body no siempre se muestra completo (depende de la version
de curl). Si no lo ves, usa `--trace-ascii trace-post.txt` y busca el bloque
`Send data`.

## Entregables

- `verbose-output.txt`: output de la parte 1
- `trace-https.txt`: trace de la parte 2
- `trace-http1.txt` y `trace-http2.txt`: traces de la parte 3
- `verbose-post.txt`: output de la parte 4
- `respuestas.md`: respuestas a todas las preguntas
