# Exit Codes de curl

![Exit Codes de curl](../0-assets/01-exit-codes-curl.svg)

## El malentendido mas comun

curl retorna exit code 0 (exito) si pudo completar la transferencia, independientemente
del codigo HTTP de la respuesta. Esto significa que un `404 Not Found` o un
`500 Internal Server Error` resultan en exit code 0 por defecto.

```bash
curl https://httpbin.org/status/404
echo "Exit code: $?"   # Imprime: 0
```

Esto sorprende a quienes vienen de otros lenguajes. La logica de curl es: "yo hice
mi trabajo (la transferencia), lo que el servidor responda es cosa del servidor".

## Exit codes de curl

Los exit codes de curl indican problemas de curl mismo (red, TLS, configuracion),
no problemas HTTP:

| Exit code | Significado |
|-----------|-------------|
| 0 | Exito — la transferencia completo sin errores de curl |
| 3 | URL malformada |
| 5 | No se pudo resolver el proxy |
| 6 | No se pudo resolver el host (DNS fallo) |
| 7 | No se pudo conectar al servidor |
| 22 | HTTP error (solo con `-f` / `--fail`) |
| 23 | Error al escribir datos (disco lleno, etc.) |
| 26 | Error al leer el archivo de datos de upload |
| 28 | Timeout (la operacion excedio el tiempo maximo) |
| 35 | Error de SSL/TLS (handshake fallo) |
| 47 | Demasiadas redirecciones |
| 52 | No se recibio nada del servidor |
| 56 | Error al recibir datos de la red |

```bash
# Ejemplos de cada exit code

# Exit 6: host no resuelve
curl https://host-que-no-existe.xyz/
echo $?   # 6

# Exit 7: host resuelve pero no hay conexion (puerto cerrado o firewall)
curl https://localhost:19999/
echo $?   # 7

# Exit 28: timeout
curl --connect-timeout 1 https://10.255.255.1/
echo $?   # 28

# Exit 35: SSL error (certificado invalido sin -k)
curl https://expired.badssl.com/
echo $?   # 35
```

## El flag -f / --fail

Para hacer que curl retorne exit code distinto de cero en respuestas HTTP 4xx y 5xx,
usa `-f` o `--fail`:

```bash
curl -f https://httpbin.org/status/404
echo $?   # 22

curl -f https://httpbin.org/status/500
echo $?   # 22

curl -f https://httpbin.org/status/200
echo $?   # 0
```

Con `-f`, curl suprime ademas el body de error (no lo muestra en stdout). Esto
es util en scripts donde un body de error inesperado podria romper el procesamiento.

## El flag --fail-with-body

Disponible desde curl 7.76.0. Es como `-f` (exit code 22 en 4xx/5xx) pero mantiene
el body en stdout. Util para depuracion: sabes que hubo un error Y puedes leer
el mensaje de error del servidor.

```bash
curl --fail-with-body https://httpbin.org/status/422
# Imprime el body del 422 y retorna exit code 22

echo $?   # 22
```

Para verificar la version de curl y si soporta `--fail-with-body`:

```bash
curl --version | head -1
# curl 7.88.1 ...
```

## Capturar exit code en scripts

En bash, `$?` contiene el exit code del ultimo comando ejecutado:

```bash
curl -f https://httpbin.org/status/404
CURL_EXIT=$?

if [ $CURL_EXIT -ne 0 ]; then
    echo "Fallo con exit code: $CURL_EXIT"
fi
```

Para capturar el exit code de curl Y el body/metricas en una sola llamada:

```bash
HTTP_CODE=$(curl -s -o /tmp/body.json -w "%{http_code}" https://httpbin.org/get)
CURL_EXIT=$?

echo "Curl exit: $CURL_EXIT"
echo "HTTP code: $HTTP_CODE"

# Verificar manualmente el codigo HTTP
if [ "$CURL_EXIT" -ne 0 ]; then
    echo "Error de red o curl: $CURL_EXIT"
elif [ "$HTTP_CODE" -ge 400 ]; then
    echo "Error HTTP: $HTTP_CODE"
    cat /tmp/body.json
else
    echo "Exito: $HTTP_CODE"
    cat /tmp/body.json
fi
```

## Diferencia entre exit code y HTTP status code

| Situacion | Exit code curl | HTTP status |
|-----------|----------------|-------------|
| Request exitoso, respuesta 200 | 0 | 200 |
| Request exitoso, respuesta 404 | 0 (sin -f) / 22 (con -f) | 404 |
| Request exitoso, respuesta 500 | 0 (sin -f) / 22 (con -f) | 500 |
| Timeout de conexion | 28 | (ninguno) |
| Host no resuelve | 6 | (ninguno) |
| Error TLS | 35 | (ninguno) |

La distincion es importante: cuando el exit code de curl es 0, sabes que hubo
comunicacion exitosa con el servidor. Cuando es distinto de 0, ni siquiera hubo
respuesta HTTP (o hubo error con -f). Son dos capas de error diferentes.
