# Ejercicio 1: Exit Codes de curl

## Objetivo

Experimentar con los exit codes de curl en diferentes escenarios para entender
la diferencia entre errores de red y errores HTTP, y el efecto del flag `-f`.

## Parte 1: sin -f, errores HTTP retornan 0

Ejecuta cada comando y anota el exit code:

```bash
# Respuesta exitosa
curl -s -o /dev/null https://jsonplaceholder.typicode.com/posts/1
echo "Exit code: $?"

# Respuesta 404 - SIN -f
curl -s -o /dev/null https://httpbin.org/status/404
echo "Exit code: $?"

# Respuesta 500 - SIN -f
curl -s -o /dev/null https://httpbin.org/status/500
echo "Exit code: $?"

# Respuesta 200
curl -s -o /dev/null https://httpbin.org/status/200
echo "Exit code: $?"
```

Documenta los 4 exit codes en `respuestas.md`. Todos son 0? Que significa esto
para un script que no usa `-f`?

## Parte 2: con -f, errores HTTP retornan 22

Repite los mismos requests con `-f`:

```bash
# Respuesta 200 con -f
curl -sf -o /dev/null https://httpbin.org/status/200
echo "Exit code: $?"

# Respuesta 404 con -f
curl -sf -o /dev/null https://httpbin.org/status/404
echo "Exit code: $?"

# Respuesta 500 con -f
curl -sf -o /dev/null https://httpbin.org/status/500
echo "Exit code: $?"

# Respuesta 201 con -f
curl -sf -o /dev/null https://httpbin.org/status/201
echo "Exit code: $?"
```

Nota: `-sf` es la forma compacta de `-s -f`.

## Parte 3: --fail-with-body

Compara el output con `-f` vs `--fail-with-body`:

```bash
echo "=== Con -f ==="
curl -sf https://httpbin.org/status/422
echo ""
echo "Exit code: $?"

echo ""
echo "=== Con --fail-with-body ==="
curl -s --fail-with-body https://httpbin.org/status/422
echo ""
echo "Exit code: $?"
```

Cual muestra el body del error? Cual no?

## Parte 4: errores de red

Estos comandos tienen exit codes distintos de 22:

```bash
# Host que no existe (exit 6)
curl -s https://host-que-no-existe-12345.xyz/ 2>&1
echo "Exit code: $?"

# Conexion rechazada (exit 7) - intenta conectar a un puerto no abierto
curl -s --connect-timeout 3 http://localhost:19999/ 2>&1
echo "Exit code: $?"

# Timeout (exit 28)
curl -s --connect-timeout 1 https://10.255.255.1/ 2>&1
echo "Exit code: $?"
```

Nota: el ultimo puede tardar hasta `connect-timeout` segundos (1 segundo en el
ejemplo). Los primeros dos son casi instantaneos.

## Parte 5: tabla de resultados

Completa esta tabla en `respuestas.md` con tus resultados:

| Escenario | Flag -f | HTTP Code | Exit Code |
|-----------|---------|-----------|-----------|
| Respuesta 200 | No | 200 | ??? |
| Respuesta 200 | Si | 200 | ??? |
| Respuesta 404 | No | 404 | ??? |
| Respuesta 404 | Si | 404 | ??? |
| Respuesta 500 | No | 500 | ??? |
| Respuesta 500 | Si | 500 | ??? |
| Host no existe | No | N/A | ??? |
| Timeout | No | N/A | ??? |

## Parte 6: uso correcto en un if

Escribe un script `check.sh` que demuestre el uso correcto:

```bash
#!/bin/bash
set -uo pipefail

check_endpoint() {
    local url="$1"
    local http_code curl_exit

    http_code=$(curl -sS -o /dev/null -w "%{http_code}" \
                     --max-time 10 --connect-timeout 5 "$url")
    curl_exit=$?

    echo -n "URL: $url -> "

    if [ "$curl_exit" -ne 0 ]; then
        echo "ERROR DE RED (curl exit $curl_exit)"
        return 1
    fi

    if [ "$http_code" -ge 400 ]; then
        echo "ERROR HTTP $http_code"
        return 1
    fi

    echo "OK ($http_code)"
    return 0
}

check_endpoint "https://jsonplaceholder.typicode.com/posts/1"
check_endpoint "https://httpbin.org/status/404"
check_endpoint "https://httpbin.org/status/500"
check_endpoint "https://host-invalido-12345.xyz/"
```

## Preguntas de reflexion (respuestas.md)

1. Por que curl retorna 0 en errores HTTP 4xx/5xx por defecto?
2. En un script de CI/CD que verifica que un endpoint retorna 200, que pasa
   si no usas `-f` y el servidor retorna 503?
3. Cual es la diferencia entre exit code 6 y exit code 7?
4. Cuando usarias `--fail-with-body` en lugar de `-f`?

## Entregables

- `check.sh`: script de la parte 6
- `output.txt`: output de cada parte
- `respuestas.md`: tabla completada y respuestas a las preguntas
