# Ejercicio 4: Script Completo con Subcomandos

**Tiempo estimado:** 75 minutos
**Competencia:** C4 - Script con estructura profesional

## Objetivo

Construir `user-manager.sh`, un script bash con subcomandos que gestiona
usuarios usando la API de jsonplaceholder. El objetivo no es solo que funcione,
sino que tenga estructura profesional: manejo de errores, logging, validacion
de argumentos y salidas correctas a stdout y stderr.

## Especificacion

El script debe aceptar los siguientes subcomandos:

```
./user-manager.sh list              Lista todos los usuarios
./user-manager.sh get <id>          Muestra la info de un usuario
./user-manager.sh search <termino>  Filtra usuarios por nombre
./user-manager.sh posts <id>        Muestra los titulos de posts de un usuario
./user-manager.sh help              Muestra la ayuda de uso
```

Sin argumentos, muestra la ayuda y sale con exit code 1.

## Implementacion paso a paso

### Paso 1: estructura base y configuracion

```bash
#!/bin/bash
set -uo pipefail

readonly BASE_URL="${BASE_URL:-https://jsonplaceholder.typicode.com}"
readonly TIMEOUT="${TIMEOUT:-15}"

log() {
    echo "[$(date '+%H:%M:%S')] $*" >&2
}

usage() {
    cat >&2 <<EOF
Uso: $0 <subcomando> [argumentos]

Subcomandos:
  list              Lista todos los usuarios (id y nombre)
  get <id>          Muestra la informacion de un usuario por ID
  search <termino>  Filtra usuarios cuyo nombre contiene el termino
  posts <id>        Muestra los titulos de posts del usuario
  help              Muestra esta ayuda

Variables de entorno:
  BASE_URL          URL base de la API (default: https://jsonplaceholder.typicode.com)
  TIMEOUT           Segundos de timeout por request (default: 15)

Ejemplos:
  $0 list
  $0 get 3
  $0 search "Leanne"
  $0 posts 1
EOF
    exit "${1:-0}"
}
```

### Paso 2: funcion de request base

```bash
api_get() {
    local endpoint="$1"
    local response http_code

    http_code=$(curl -sS \
                     --max-time "$TIMEOUT" \
                     --connect-timeout 5 \
                     -o /tmp/user_manager_response_$$.json \
                     -w "%{http_code}" \
                     "${BASE_URL}${endpoint}")
    local curl_exit=$?

    if [ "$curl_exit" -ne 0 ]; then
        log "Error de red (curl exit $curl_exit): ${BASE_URL}${endpoint}"
        return 1
    fi

    if [ "$http_code" -ge 400 ]; then
        log "Error HTTP $http_code: ${BASE_URL}${endpoint}"
        return 1
    fi

    cat /tmp/user_manager_response_$$.json
    rm -f /tmp/user_manager_response_$$.json
    return 0
}
```

### Paso 3: implementar cada subcomando

```bash
cmd_list() {
    log "Listando usuarios..."
    local users
    users=$(api_get "/users") || {
        echo "Error: no se pudieron obtener los usuarios" >&2
        return 1
    }
    echo "$users" | jq -r '.[] | "\(.id)\t\(.name)"'
}

cmd_get() {
    local id="${1:?Error: se requiere un ID. Uso: $0 get <id>}"
    log "Obteniendo usuario $id..."
    local user
    user=$(api_get "/users/$id") || {
        echo "Error: no se pudo obtener el usuario $id" >&2
        return 1
    }
    echo "$user" | jq '.'
}

cmd_search() {
    local term="${1:?Error: se requiere un termino. Uso: $0 search <termino>}"
    log "Buscando usuarios que contienen: $term"
    local users
    users=$(api_get "/users") || {
        echo "Error: no se pudieron obtener los usuarios" >&2
        return 1
    }
    local results
    results=$(echo "$users" | jq --arg t "$term" \
        '[.[] | select(.name | ascii_downcase | contains($t | ascii_downcase))]')
    local count
    count=$(echo "$results" | jq 'length')
    if [ "$count" -eq 0 ]; then
        echo "No se encontraron usuarios con '$term'" >&2
        return 1
    fi
    echo "Encontrados: $count" >&2
    echo "$results" | jq -r '.[] | "\(.id)\t\(.name)\t<\(.email)>"'
}

cmd_posts() {
    local id="${1:?Error: se requiere un ID. Uso: $0 posts <id>}"
    log "Posts del usuario $id..."
    local posts
    posts=$(api_get "/posts?userId=$id") || {
        echo "Error: no se pudieron obtener los posts del usuario $id" >&2
        return 1
    }
    local count
    count=$(echo "$posts" | jq 'length')
    echo "Usuario $id tiene $count posts:" >&2
    echo "$posts" | jq -r '.[].title'
}
```

### Paso 4: funcion main con case

```bash
main() {
    local cmd="${1:-}"
    shift 2>/dev/null || true

    case "$cmd" in
        list)    cmd_list ;;
        get)     cmd_get "$@" ;;
        search)  cmd_search "$@" ;;
        posts)   cmd_posts "$@" ;;
        help|-h|--help) usage 0 ;;
        "")      usage 1 ;;
        *)
            echo "Subcomando desconocido: $cmd" >&2
            usage 1
            ;;
    esac
}

main "$@"
```

## Pruebas que debe pasar el script

Una vez que el script este completo, ejecuta estas pruebas:

```bash
chmod +x user-manager.sh

# Prueba 1: sin argumentos muestra uso y sale con error
./user-manager.sh
echo "Exit: $?"    # debe ser 1

# Prueba 2: listar todos los usuarios
./user-manager.sh list

# Prueba 3: obtener usuario por ID
./user-manager.sh get 3

# Prueba 4: ID inexistente
./user-manager.sh get 9999
echo "Exit: $?"   # debe ser distinto de 0

# Prueba 5: buscar por nombre
./user-manager.sh search "Leanne"

# Prueba 6: busqueda sin resultados
./user-manager.sh search "zzzzzzz"
echo "Exit: $?"   # debe ser distinto de 0

# Prueba 7: posts de un usuario
./user-manager.sh posts 1

# Prueba 8: BASE_URL configurable
BASE_URL="https://jsonplaceholder.typicode.com" ./user-manager.sh list

# Prueba 9: subcomando invalido
./user-manager.sh eliminar 5
echo "Exit: $?"   # debe ser 1
```

## Mejoras opcionales (nivel avanzado)

Si terminas el script base y tienes tiempo:

**Opcion A: formato de salida configurable**

Agrega una opcion `--format json|table` (default: table) que cambie el formato
de la salida del subcomando `list`:

```bash
./user-manager.sh list --format json   # JSON array completo
./user-manager.sh list --format table  # tabla id/nombre (default)
```

**Opcion B: filtros adicionales en list**

```bash
./user-manager.sh list --sort-by name   # ordenar por nombre
./user-manager.sh list --limit 5        # solo los primeros 5
```

**Opcion C: subcomando stats**

```bash
./user-manager.sh stats   # muestra: total usuarios, total posts, promedio posts/usuario
```

## Preguntas de reflexion (respuestas.md)

1. El script usa `set -uo pipefail` pero NO `set -e`. Por que puede ser mejor
   omitir `set -e` en un script con manejo de errores granular?

2. Los mensajes de log van a stderr (`>&2`) y la data util va a stdout. Por que
   esta separacion es importante en el contexto de pipelines como:
   ```bash
   ./user-manager.sh list | grep "Leanne"
   ```

3. La funcion `api_get` crea un archivo temporal con `$$` (PID del proceso).
   Cual es la ventaja de esto frente a usar siempre el mismo archivo
   `/tmp/response.json`?

4. Como testear que el script maneja correctamente un timeout? (pista: usa
   una URL que tarde mucho en responder y ajusta `TIMEOUT=1`)

## Entregables

- `user-manager.sh`: script completo y funcional con todos los subcomandos
- `output.txt`: output de ejecutar las 9 pruebas listadas arriba
- `respuestas.md`: respuestas a las 4 preguntas de reflexion
