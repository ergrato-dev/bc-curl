#!/bin/bash
# sync.sh — sincroniza usuarios desde un CSV hacia la API
#
# Uso: ./sync.sh [archivo.csv]
#      Por defecto lee users.csv en el directorio actual
#
# La API no persiste datos (jsonplaceholder es de solo lectura),
# pero la logica del script debe ser correcta como si lo hiciera.

set -uo pipefail

# ---------------------------------------------------------------------------
# Configuracion
# ---------------------------------------------------------------------------

readonly BASE_URL="${BASE_URL:-https://jsonplaceholder.typicode.com}"
readonly TIMEOUT="${TIMEOUT:-15}"
readonly CSV_FILE="${1:-users.csv}"
readonly DELAY="${DELAY:-0.3}"    # segundos entre requests
readonly MAX_RETRIES=3

# ---------------------------------------------------------------------------
# Contadores (modificar dentro del loop usando process substitution, no pipe)
# ---------------------------------------------------------------------------

created=0
existed=0
errors=0

# ---------------------------------------------------------------------------
# Funciones de utilidad
# ---------------------------------------------------------------------------

log() {
    echo "[$(date '+%H:%M:%S')] $*" >&2
}

# ---------------------------------------------------------------------------
# Funcion: user_exists <id>
#
# Retorna 0 (verdadero en bash) si el usuario existe en la API.
# Retorna 1 si no existe o si hay un error de red.
#
# Implementacion sugerida:
#   - GET ${BASE_URL}/users/${id}
#   - Captura el HTTP status code con -w "%{http_code}" -o /dev/null
#   - Retorna 0 si http_code == 200, 1 en cualquier otro caso
# ---------------------------------------------------------------------------

user_exists() {
    local id="$1"
    # TODO: implementar
    # Ejemplo de estructura:
    #   local http_code
    #   http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    #                    --max-time "$TIMEOUT" \
    #                    "${BASE_URL}/users/${id}")
    #   [ "$http_code" -eq 200 ]
    return 1  # placeholder: eliminar cuando implementes
}

# ---------------------------------------------------------------------------
# Funcion: create_user <name> <email>
#
# Crea un usuario via POST /users con Content-Type application/json.
# Si el request tiene exito (201), imprime el id del nuevo usuario en stdout.
# Si hay error, retorna 1.
#
# Implementacion sugerida:
#   - Construir el JSON con jq -n --arg name ... --arg email ...
#   - POST a ${BASE_URL}/users
#   - Capturar http_code y body
#   - Si http_code es 201 o 200, extraer .id con jq y hacer echo
#   - Si es 429, llamar a la logica de retry (o retornar 1 para que el
#     loop principal decida reintentar)
# ---------------------------------------------------------------------------

create_user() {
    local name="$1"
    local email="$2"
    # TODO: implementar
    # El id nuevo debe ir a stdout (no a stderr)
    # Los mensajes de log van a stderr con log()
    return 1  # placeholder: eliminar cuando implementes
}

# ---------------------------------------------------------------------------
# Funcion: curl_with_retry <curl args...>
#
# Wrapper sobre curl que reintenta hasta MAX_RETRIES veces si recibe 429.
# En otros errores, retorna inmediatamente.
#
# Uso: curl_with_retry -s -X POST ... -w "%{http_code}"
# Retorna: el http_code del request (o del ultimo reintento)
# ---------------------------------------------------------------------------

curl_with_retry() {
    local attempt=1
    local http_code

    while [ "$attempt" -le "$MAX_RETRIES" ]; do
        http_code=$(curl "$@")
        local curl_exit=$?

        if [ "$curl_exit" -ne 0 ]; then
            log "Error de red (curl exit $curl_exit), intento $attempt/$MAX_RETRIES"
            attempt=$((attempt + 1))
            sleep 2
            continue
        fi

        if [ "$http_code" -eq 429 ]; then
            log "Rate limit (429). Esperando 5s... (intento $attempt/$MAX_RETRIES)"
            sleep 5
            attempt=$((attempt + 1))
            continue
        fi

        echo "$http_code"
        return 0
    done

    log "Error: maximo de reintentos ($MAX_RETRIES) alcanzado"
    return 1
}

# ---------------------------------------------------------------------------
# Validaciones iniciales
# ---------------------------------------------------------------------------

if [ ! -f "$CSV_FILE" ]; then
    log "Error: archivo CSV no encontrado: $CSV_FILE"
    log "Uso: $0 [archivo.csv]"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    log "Error: jq no esta instalado. Instala con: sudo apt install jq"
    exit 1
fi

# ---------------------------------------------------------------------------
# Loop principal
#
# Lee el CSV saltando la primera linea (cabecera).
# Usa process substitution < <(...) para que los cambios a las variables
# created/existed/errors sean visibles fuera del loop.
# ---------------------------------------------------------------------------

log "Iniciando sincronizacion desde $CSV_FILE"
log "API: $BASE_URL"
echo "" >&2

while IFS=, read -r id name email; do
    # Saltar lineas vacias y comentarios
    [ -z "$id" ] && continue
    [[ "$id" == \#* ]] && continue

    log "Procesando: $name ($email)"

    # TODO: llamar a user_exists "$id"
    #   Si existe: log "Usuario $id ya existe", incrementar existed
    #   Si no existe:
    #     log "Usuario $id no existe, creando..."
    #     llamar a create_user "$name" "$email"
    #     Si exito: log "Creado con id: $new_id", incrementar created
    #     Si fallo: log "Error al crear $name", incrementar errors

    sleep "$DELAY"

done < <(tail -n +2 "$CSV_FILE")

# ---------------------------------------------------------------------------
# Resumen final
# ---------------------------------------------------------------------------

echo "" >&2
echo "=== Resumen ==="
echo "Creados   : $created"
echo "Existian  : $existed"
echo "Errores   : $errors"

# Salir con error si hubo errores
[ "$errors" -gt 0 ] && exit 1 || exit 0
