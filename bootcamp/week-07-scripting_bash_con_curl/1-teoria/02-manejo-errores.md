# Manejo de Errores en Scripts con curl

## El patron basico

La forma mas simple de manejar errores de curl en un script es con `if`:

```bash
if ! curl -sS -f https://httpbin.org/status/404; then
    echo "El request fallo" >&2
    exit 1
fi
```

`if !` ejecuta el comando y entra al bloque si el exit code es distinto de cero.
Con `-f`, esto captura tanto errores de red como errores HTTP 4xx/5xx.

## Capturar HTTP status y curl exit code por separado

Para poder diferenciar el tipo de error, captura ambos valores:

```bash
HTTP_CODE=$(curl -sS \
                 --max-time 10 \
                 -o /tmp/response_body.json \
                 -w "%{http_code}" \
                 https://httpbin.org/get)
CURL_EXIT=$?

if [ "$CURL_EXIT" -ne 0 ]; then
    case $CURL_EXIT in
        6)  echo "Error: no se pudo resolver el host" >&2 ;;
        7)  echo "Error: no se pudo conectar al servidor" >&2 ;;
        28) echo "Error: timeout en la operacion" >&2 ;;
        35) echo "Error: fallo TLS/SSL" >&2 ;;
        *)  echo "Error de curl: exit code $CURL_EXIT" >&2 ;;
    esac
    exit 1
fi

if [ "$HTTP_CODE" -ge 500 ]; then
    echo "Error del servidor: HTTP $HTTP_CODE" >&2
    exit 1
elif [ "$HTTP_CODE" -ge 400 ]; then
    echo "Error del cliente: HTTP $HTTP_CODE" >&2
    exit 1
fi

echo "Exito: HTTP $HTTP_CODE"
cat /tmp/response_body.json
```

## Funcion curl_check() reutilizable

En lugar de repetir esta logica, encapsulala en una funcion:

```bash
#!/bin/bash

RESPONSE_FILE="/tmp/curl_response_$$"

curl_check() {
    local url="$1"
    local method="${2:-GET}"
    local body="${3:-}"

    local http_code curl_exit args=()

    args+=(-sS --max-time 15 --connect-timeout 5)
    args+=(-X "$method")
    args+=(-o "$RESPONSE_FILE")
    args+=(-w "%{http_code}")

    if [ -n "$body" ]; then
        args+=(-H "Content-Type: application/json")
        args+=(-d "$body")
    fi

    http_code=$(curl "${args[@]}" "$url")
    curl_exit=$?

    if [ "$curl_exit" -ne 0 ]; then
        echo "CURL_ERROR:$curl_exit"
        return 1
    fi

    if [ "$http_code" -ge 400 ]; then
        echo "HTTP_ERROR:$http_code"
        return 1
    fi

    echo "OK:$http_code"
    return 0
}

# Uso:
RESULT=$(curl_check "https://jsonplaceholder.typicode.com/posts/1")
if [[ "$RESULT" == OK:* ]]; then
    echo "Exito: $RESULT"
    cat "$RESPONSE_FILE"
else
    echo "Fallo: $RESULT" >&2
fi

rm -f "$RESPONSE_FILE"
```

## Manejo de errores en pipelines con set -o pipefail

Por defecto en bash, el exit code de un pipeline (`cmd1 | cmd2 | cmd3`) es el
exit code del ultimo comando, aunque los anteriores hayan fallado:

```bash
# Sin pipefail: si curl falla, jq procesa string vacio y bash reporta exito
curl -s https://host-invalido.xyz/ | jq '.campo'
echo $?   # 0 (el exit code de jq, no de curl)
```

`set -o pipefail` hace que el pipeline falle si cualquier comando falla:

```bash
set -o pipefail

# Ahora esto falla correctamente si curl falla
curl -sS https://host-invalido.xyz/ | jq '.campo'
echo $?   # 6 (el exit code de curl)
```

## Logging de errores a archivo

```bash
LOG_FILE="/var/log/mi-script.log"

log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE" >&2
}

log INFO "Iniciando proceso"

if ! curl -sS -f -o /tmp/data.json "https://api.ejemplo.com/datos"; then
    log ERROR "No se pudo obtener datos de la API"
    exit 1
fi

log INFO "Datos obtenidos exitosamente"
```

## Diferenciar tipos de error

```bash
make_request() {
    local url="$1"
    local out_file="$2"

    local http_code curl_exit
    http_code=$(curl -sS \
                     --connect-timeout 5 \
                     --max-time 30 \
                     -o "$out_file" \
                     -w "%{http_code}" \
                     "$url")
    curl_exit=$?

    if [ "$curl_exit" -eq 6 ] || [ "$curl_exit" -eq 7 ]; then
        echo "ERROR_RED"
    elif [ "$curl_exit" -eq 28 ]; then
        echo "ERROR_TIMEOUT"
    elif [ "$curl_exit" -ne 0 ]; then
        echo "ERROR_CURL:$curl_exit"
    elif [ "$http_code" -eq 429 ]; then
        echo "ERROR_RATE_LIMIT"
    elif [ "$http_code" -ge 500 ]; then
        echo "ERROR_SERVIDOR:$http_code"
    elif [ "$http_code" -ge 400 ]; then
        echo "ERROR_CLIENTE:$http_code"
    else
        echo "OK:$http_code"
    fi
}
```

## set -e y sus limitaciones

`set -e` hace que el script se detenga ante cualquier comando que falle (exit code
distinto de cero). Pero tiene comportamientos sorprendentes:

```bash
set -e

# Este comando falla (grep no encuentra nada) y detiene el script
echo "hello" | grep "world"

# Para evitar que set -e se active en este caso:
echo "hello" | grep "world" || true
```

En scripts con curl, `set -e` puede causar que el script se detenga cuando curl
retorna exit code 6 (host no resuelve) incluso si quieres manejar ese error tu
mismo. La forma correcta es usar `|| true` o estructuras `if` cuando quieres que
un fallo sea manejado, no propagado.

Combinacion recomendada para scripts robustos:

```bash
set -u          # error si usas variable no definida
set -o pipefail # error si falla cualquier parte de un pipeline
# NO usar set -e en scripts con manejo de errores granular;
# usa if/|| explicitos en su lugar
```
