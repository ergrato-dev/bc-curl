# Proyecto Semana 6: API Monitor

## Descripcion

Construiras `monitor.sh`, un script de monitoreo de URLs que:

1. Lee una lista de URLs desde un archivo de texto
2. Hace GET a cada URL y mide el tiempo de respuesta
3. Clasifica cada resultado como OK, WARN o ERROR
4. Genera un resumen al final con conteo por categoria

El script no debe tener dependencias externas: solo `curl` y herramientas
estandar de bash (`awk`, `grep`, `date`, etc.).

## Criterios de clasificacion

- **OK**: HTTP 2xx y tiempo total <= 1.0 segundos
- **WARN**: HTTP 3xx, o HTTP 2xx con tiempo > 1.0 segundos
- **ERROR**: HTTP 4xx, HTTP 5xx, timeout (curl exit code 28), o error de red

## Archivo de URLs (urls.txt)

Crea este archivo en el mismo directorio que el script:

```
# API Monitor - lista de URLs
# Formato: una URL por linea, lineas con # son comentarios

https://jsonplaceholder.typicode.com/posts/1
https://jsonplaceholder.typicode.com/users
https://httpbin.org/get
https://httpbin.org/status/404
https://httpbin.org/status/500
https://httpbin.org/delay/2
https://httpbin.org/redirect/2
https://este-host-no-existe-12345.xyz/
```

## Interfaz del script

```bash
./monitor.sh urls.txt
```

Output esperado:

```
API Monitor - 2026-06-15 10:30:00
==================================

Chequeando 8 URLs...

[OK  ] 200  0.312s  https://jsonplaceholder.typicode.com/posts/1
[OK  ] 200  0.287s  https://jsonplaceholder.typicode.com/users
[OK  ] 200  0.401s  https://httpbin.org/get
[ERROR] 404  0.198s  https://httpbin.org/status/404
[ERROR] 500  0.201s  https://httpbin.org/status/500
[WARN] 200  2.103s  https://httpbin.org/delay/2
[WARN] 200  0.356s  https://httpbin.org/redirect/2
[ERROR] 000  0.000s  https://este-host-no-existe-12345.xyz/

==================================
Resumen:
  OK:    3
  WARN:  2
  ERROR: 3
  Total: 8

Estado general: DEGRADADO
```

El "Estado general" es:
- **OK**: todos los checks son OK
- **DEGRADADO**: hay WARNs pero no ERRORs
- **ERROR**: hay al menos un ERROR

## Estructura del script

```bash
#!/bin/bash
set -uo pipefail

URLS_FILE="${1:?Uso: $0 <archivo-de-urls>}"
WARN_TIME_THRESHOLD=1.0   # segundos

COUNT_OK=0
COUNT_WARN=0
COUNT_ERROR=0

# ... funciones y logica principal
```

## Funciones a implementar

### check_url()

```bash
check_url() {
    local url="$1"
    local code time_total curl_exit

    # Capturar code y tiempo; el exit code de curl en $?
    if ! RESULT=$(curl -sS \
                       -o /dev/null \
                       --max-time 10 \
                       --connect-timeout 5 \
                       -w "%{http_code} %{time_total}" \
                       -L \
                       "$url" 2>/dev/null); then
        curl_exit=$?
        # Error de red o timeout
        printf "[ERROR] %s  %s  %s\n" "000" "0.000s" "$url"
        COUNT_ERROR=$((COUNT_ERROR + 1))
        return
    fi

    code=$(echo "$RESULT" | awk '{print $1}')
    time_total=$(echo "$RESULT" | awk '{print $2}')

    # Clasificar
    local status
    if [[ "$code" -ge 500 ]] || [[ "$code" -ge 400 ]]; then
        status="ERROR"
        COUNT_ERROR=$((COUNT_ERROR + 1))
    elif [[ "$code" -ge 300 ]]; then
        status="WARN"
        COUNT_WARN=$((COUNT_WARN + 1))
    else
        # 2xx: verificar tiempo
        if awk "BEGIN { exit !($time_total > $WARN_TIME_THRESHOLD) }"; then
            status="WARN"
            COUNT_WARN=$((COUNT_WARN + 1))
        else
            status="OK"
            COUNT_OK=$((COUNT_OK + 1))
        fi
    fi

    printf "[%-5s] %s  %ss  %s\n" "$status" "$code" "$time_total" "$url"
}
```

Nota: las variables `COUNT_OK`, `COUNT_WARN`, `COUNT_ERROR` deben ser globales
(declaradas antes de la funcion) para que las modificaciones dentro de la funcion
sean visibles fuera de ella.

### read_urls() y main()

```bash
read_urls() {
    local file="$1"
    grep -v '^\s*#' "$file" | grep -v '^\s*$'
}

main() {
    local urls_file="$1"

    if [ ! -f "$urls_file" ]; then
        echo "Error: archivo '$urls_file' no encontrado" >&2
        exit 1
    fi

    local total
    total=$(read_urls "$urls_file" | wc -l)

    echo "API Monitor - $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=================================="
    echo ""
    echo "Chequeando $total URLs..."
    echo ""

    while IFS= read -r url; do
        check_url "$url"
    done < <(read_urls "$urls_file")

    echo ""
    echo "=================================="
    echo "Resumen:"
    echo "  OK:    $COUNT_OK"
    echo "  WARN:  $COUNT_WARN"
    echo "  ERROR: $COUNT_ERROR"
    echo "  Total: $total"
    echo ""

    if [ "$COUNT_ERROR" -gt 0 ]; then
        echo "Estado general: ERROR"
    elif [ "$COUNT_WARN" -gt 0 ]; then
        echo "Estado general: DEGRADADO"
    else
        echo "Estado general: OK"
    fi
}

main "$URLS_FILE"
```

## Requisitos de entrega

1. El script `monitor.sh` debe funcionar con el archivo `urls.txt` de ejemplo
2. Debe leer y omitir correctamente las lineas de comentario y las lineas vacias
3. Los contadores del resumen deben ser correctos
4. Debe ejecutarse sin errores con `bash -x monitor.sh urls.txt` (modo debug)
5. El exit code del script debe reflejar el estado general:
   - 0 si todo es OK
   - 1 si hay WARNs o ERRORs

## Entregables

- `monitor.sh`: script completo y funcional
- `urls.txt`: archivo de URLs usado
- `output.txt`: output de una ejecucion real (`./monitor.sh urls.txt | tee output.txt`)
