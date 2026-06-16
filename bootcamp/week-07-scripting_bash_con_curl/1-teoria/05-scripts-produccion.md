# Estructura de Scripts Bash para Produccion

## El shebang y opciones de seguridad

Todo script de produccion empieza con:

```bash
#!/bin/bash
set -euo pipefail
```

- `#!/bin/bash`: ejecutar con bash, no con sh (tienen diferencias importantes)
- `set -e`: salir si cualquier comando falla (con cautela, ver nota abajo)
- `set -u`: error si se usa una variable no definida
- `set -o pipefail`: el pipeline falla si cualquier parte falla

Nota: `set -e` en combinacion con `set -u` y `pipefail` es lo mas seguro, pero
para scripts con manejo de errores granular (como los que hemos visto) puede
interferir. En ese caso, omite `set -e` y maneja los errores explicitamente con
`if` y `||`.

## Variables globales y constantes

Las variables de configuracion van al inicio, en MAYUSCULAS:

```bash
#!/bin/bash
set -uo pipefail

readonly BASE_URL="${BASE_URL:-https://api.ejemplo.com}"
readonly API_KEY="${API_KEY:?La variable API_KEY es requerida}"
readonly TIMEOUT=30
readonly LOG_FILE="/tmp/script-$(date +%Y%m%d).log"
readonly TEMP_DIR=$(mktemp -d)

# Limpiar el directorio temporal al salir
trap 'rm -rf "$TEMP_DIR"' EXIT
```

`readonly` evita sobreescritura accidental. `trap ... EXIT` garantiza limpieza
aunque el script falle.

## Estructura con funciones

```bash
#!/bin/bash
set -uo pipefail

# --- Configuracion ---
readonly BASE_URL="${BASE_URL:-https://jsonplaceholder.typicode.com}"
readonly TIMEOUT=15

# --- Funciones de utilidad ---

log() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] $*" >&2
}

die() {
    log "ERROR: $*"
    exit 1
}

api_get() {
    local endpoint="$1"
    curl -sS --max-time "$TIMEOUT" "${BASE_URL}${endpoint}"
}

api_post() {
    local endpoint="$1"
    local body="$2"
    curl -sS --max-time "$TIMEOUT" \
         -X POST \
         -H "Content-Type: application/json" \
         -d "$body" \
         "${BASE_URL}${endpoint}"
}

# --- Logica del negocio ---

get_user() {
    local user_id="$1"
    local response
    response=$(api_get "/users/$user_id") || die "No se pudo obtener usuario $user_id"
    echo "$response"
}

list_posts_by_user() {
    local user_id="$1"
    api_get "/posts?userId=$user_id" | jq -r '.[].title'
}

# --- Funcion principal ---

main() {
    local user_id="${1:-1}"

    log "Obteniendo usuario $user_id..."
    local user
    user=$(get_user "$user_id")
    local name
    name=$(echo "$user" | jq -r '.name')

    log "Usuario: $name"
    log "Posts:"
    list_posts_by_user "$user_id" | while read -r title; do
        echo "  - $title"
    done
}

main "$@"
```

## Argparse basico con case

```bash
usage() {
    cat <<EOF
Uso: $0 <comando> [argumentos]

Comandos:
  list              Lista todos los usuarios
  get <id>          Muestra un usuario por ID
  search <termino>  Busca usuarios por nombre

Opciones:
  -h, --help        Muestra esta ayuda
EOF
    exit "${1:-0}"
}

main() {
    local cmd="${1:-}"
    shift || true

    case "$cmd" in
        list)
            do_list
            ;;
        get)
            local id="${1:?Uso: $0 get <id>}"
            do_get "$id"
            ;;
        search)
            local term="${1:?Uso: $0 search <termino>}"
            do_search "$term"
            ;;
        -h|--help|help)
            usage 0
            ;;
        "")
            usage 1
            ;;
        *)
            echo "Comando desconocido: $cmd" >&2
            usage 1
            ;;
    esac
}

main "$@"
```

## Secrets desde variables de entorno

Nunca hardcodees credenciales en el script:

```bash
# MAL
TOKEN="sk-hardcodeado-12345"

# BIEN: leer de variable de entorno
TOKEN="${API_TOKEN:?La variable API_TOKEN es requerida}"

# BIEN: leer de archivo con permisos restringidos
if [ -f ~/.config/miapp/token ]; then
    TOKEN=$(cat ~/.config/miapp/token)
fi
```

## Idempotencia: verificar antes de crear

Un script idempotente puede ejecutarse multiples veces con el mismo resultado.
En el contexto de APIs, significa verificar si el recurso ya existe antes de crearlo:

```bash
create_user_if_not_exists() {
    local email="$1"
    local name="$2"

    # Verificar si existe
    local existing
    existing=$(curl -s "$BASE_URL/users?email=$email" | jq 'length')

    if [ "$existing" -gt 0 ]; then
        log "Usuario $email ya existe, saltando"
        return 0
    fi

    # Crear si no existe
    local body
    body=$(jq -n --arg email "$email" --arg name "$name" \
               '{name: $name, email: $email}')

    curl -sS -X POST \
         -H "Content-Type: application/json" \
         -d "$body" \
         "$BASE_URL/users"

    log "Usuario $email creado"
}
```

## Dry run mode

Agrega una opcion `--dry-run` que muestra lo que haria el script sin ejecutarlo:

```bash
DRY_RUN=false

if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
    log "MODO DRY RUN: no se realizaran cambios"
    shift
fi

api_post_or_dry() {
    local endpoint="$1"
    local body="$2"

    if $DRY_RUN; then
        log "DRY RUN: POST $endpoint"
        log "DRY RUN: body = $body"
        return 0
    fi

    curl -sS -X POST \
         -H "Content-Type: application/json" \
         -d "$body" \
         "${BASE_URL}${endpoint}"
}
```

## Ejemplo completo: script de migracion

```bash
#!/bin/bash
set -uo pipefail

readonly BASE_URL="${API_BASE:-https://jsonplaceholder.typicode.com}"
readonly INPUT_FILE="${1:?Uso: $0 <archivo-usuarios.csv> [--dry-run]}"
readonly DRY_RUN="${2:-}"

log() { echo "[$(date '+%H:%M:%S')] $*" >&2; }

COUNT_CREATED=0
COUNT_SKIPPED=0
COUNT_ERRORS=0

process_user() {
    local name="$1" email="$2"

    local body
    body=$(jq -n --arg name "$name" --arg email "$email" \
               '{name: $name, email: $email}')

    if [ "$DRY_RUN" = "--dry-run" ]; then
        log "DRY RUN: crearia usuario $name <$email>"
        COUNT_CREATED=$((COUNT_CREATED + 1))
        return 0
    fi

    local http_code
    http_code=$(curl -sS -X POST \
                     -H "Content-Type: application/json" \
                     -d "$body" \
                     -o /dev/null \
                     -w "%{http_code}" \
                     "$BASE_URL/users")

    if [ "$http_code" -eq 201 ] || [ "$http_code" -eq 200 ]; then
        log "Creado: $name"
        COUNT_CREATED=$((COUNT_CREATED + 1))
    else
        log "Error HTTP $http_code para $name"
        COUNT_ERRORS=$((COUNT_ERRORS + 1))
    fi
}

# Leer CSV (asume: nombre,email)
while IFS=, read -r name email; do
    [ -z "$name" ] && continue
    [[ "$name" == \#* ]] && continue
    process_user "$name" "$email"
    sleep 0.2
done < "$INPUT_FILE"

log "--- Resumen ---"
log "Creados:  $COUNT_CREATED"
log "Saltados: $COUNT_SKIPPED"
log "Errores:  $COUNT_ERRORS"

[ "$COUNT_ERRORS" -gt 0 ] && exit 1 || exit 0
```
