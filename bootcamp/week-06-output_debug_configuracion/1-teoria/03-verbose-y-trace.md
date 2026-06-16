# Depuracion: -v, --trace y --trace-ascii

## Niveles de verbosidad

curl ofrece tres niveles de informacion de depuracion, cada uno mas detallado
que el anterior:

1. `-v` (verbose): muestra el proceso general en texto legible
2. `--trace archivo`: captura dump binario completo de todos los bytes
3. `--trace-ascii archivo`: dump legible combinando hex y ASCII imprimible

## El flag -v (--verbose)

`-v` es la herramienta de depuracion mas usada. Muestra en stderr:

- La resolucion DNS
- La conexion TCP (IP y puerto)
- El handshake TLS (version, cipher elegido, certificado)
- Los headers HTTP enviados (prefijados con `>`)
- Los headers HTTP recibidos (prefijados con `<`)
- Informacion adicional de curl (prefijada con `*`)

```bash
curl -v https://httpbin.org/get 2>&1 | head -40
```

Ejemplo de output parcial:
```
*   Trying 54.208.105.16:443...
* Connected to httpbin.org (54.208.105.16) port 443 (#0)
* ALPN: offers h2,http/1.1
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.3 (IN), TLS handshake, Server hello (1):
* SSL connection using TLSv1.3 / TLS_AES_128_GCM_SHA256
* Server certificate:
*  subject: CN=httpbin.org
*  expire date: Sep 15 2026 23:59:59 GMT
*  issuer: C=US; O=Let's Encrypt; CN=R3
* SSL certificate verify ok.
> GET /get HTTP/2
> Host: httpbin.org
> user-agent: curl/7.88.1
> accept: */*
>
< HTTP/2 200
< date: Mon, 15 Jun 2026 10:00:00 GMT
< content-type: application/json
< content-length: 305
<
```

Los prefijos tienen significado:
- `*` = informacion interna de curl (DNS, TCP, TLS, reintentos)
- `>` = datos que curl envio al servidor (request)
- `<` = datos que curl recibio del servidor (response)

## --trace archivo

Captura absolutamente todos los bytes que pasan por la conexion en un formato
binario que incluye timestamps y direccion (enviado/recibido). El archivo puede
crecer rapidamente en transferencias grandes.

```bash
curl --trace dump.bin https://httpbin.org/get -o /dev/null
```

Para leer el archivo (no es texto plano):
```bash
# Mostrar como hexadecimal
xxd dump.bin | head -50
```

## --trace-ascii archivo

Igual que `--trace` pero en un formato legible: cada bloque muestra los bytes en
hex y al lado los caracteres ASCII imprimibles. Es el nivel de depuracion mas
profundo que necesitaras en la mayoria de los casos.

```bash
curl --trace-ascii trace.txt https://httpbin.org/get -o /dev/null
cat trace.txt
```

Ejemplo de output:
```
== Info: Trying 54.208.105.16:443...
== Info: Connected to httpbin.org port 443
=> Send SSL data, 517 bytes (0x205)
0000: 16 03 01 02 00 01 00 01 fc 03 03 ab cd ...
== Info: TLSv1.3 (IN), TLS handshake
<= Recv SSL data, 5 bytes (0x5)
0000: 16 03 03 00 5a                              ....Z
=> Send header, 74 bytes (0x4a)
0000: 47 45 54 20 2f 67 65 74 20 48 54 54 50 2f 32 0d GET /get HTTP/2.
0010: 0a 48 6f 73 74 3a 20 68 74 74 70 62 69 6e 2e 6f .Host: httpbin.o
```

## --trace-time

Agrega timestamps a cada linea del trace. Util para medir cuanto tarda cada fase:

```bash
curl --trace-ascii trace.txt --trace-time https://httpbin.org/get -o /dev/null
```

El output incluira timestamps en formato `HH:MM:SS.microsegundos` al inicio de
cada linea.

## Cuando usar cada nivel

| Situacion | Herramienta |
|-----------|-------------|
| Ver que headers se envian/reciben | `-v` |
| Depurar un error de TLS | `-v` (muestra cipher y certificado) |
| Verificar que el request sea correcto | `-v` |
| Problema de protocolo dificil de reproducir | `--trace-ascii` |
| Analizar timing de cada fase | `--trace-ascii --trace-time` |
| Capturar para analisis offline con otra herramienta | `--trace` |

## Leer un trace file e identificar fases

Un trace completo tiene estas secciones en orden:

1. **Resolucion DNS**: `Trying X.X.X.X...` y `Connected to hostname`
2. **TCP handshake**: implicito en el `Connected`
3. **TLS handshake**: bloques `Send SSL data` y `Recv SSL data` alternados
4. **Request HTTP**: `Send header` con los headers y `Send data` con el body (en POST)
5. **Response**: `Recv header` con los headers de respuesta
6. **Body**: `Recv data` con el contenido del body

Si el trace se corta en el paso 3 (SSL), el problema es TLS: certificado invalido,
version incompatible o cipher no soportado.

Si llega hasta el paso 4 pero no hay paso 5, el servidor recibio el request pero
no respondio: timeout del servidor o problema de red unidireccional.

## Comparar HTTP/1.1 vs HTTP/2

```bash
# Forzar HTTP/1.1
curl --trace-ascii trace-http1.txt --http1.1 https://httpbin.org/get -o /dev/null

# Usar HTTP/2 (default si disponible)
curl --trace-ascii trace-http2.txt https://httpbin.org/get -o /dev/null

# Comparar
wc -l trace-http1.txt trace-http2.txt
```

En el trace de HTTP/2 veras bloques de datos binarios del framing de HTTP/2 antes
de los headers legibles. En HTTP/1.1 los headers son texto plano directamente.
