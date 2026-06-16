# Arquitectura de herramientas CLI profesionales con bash

[← Semana 10](../README.md) | [→ 02: Configuración persistente](02-configuracion-persistente.md)

---

## Por qué importa el diseño de la CLI

Una CLI es una API. Sus usuarios son personas (y scripts) que la llaman desde la terminal, desde pipelines CI/CD, desde otros scripts. Un diseño descuidado produce herramientas que se usan una vez y se abandonan. Un diseño sólido produce herramientas que se adoptan, se comparten y se mantienen.

Esta semana construyes `api-toolkit`. Antes de escribir una sola línea de lógica, vale la pena entender qué hace a una CLI buena.

---

## Principios de una CLI bien diseñada

### 1. Un propósito claro

La herramienta hace una cosa, bien definida. `api-toolkit` hace requests a APIs REST. No parsea logs, no gestiona certificados, no envía emails. Si necesitas hacer algo relacionado, lo pipeas con otra herramienta.

### 2. Composable con pipes

El output a stdout debe ser utilizable por otras herramientas:

```bash
# Esto debe funcionar
api-toolkit get /users | jq '.[].name'
api-toolkit get /users | grep "Ana" | wc -l
api-toolkit get /products | jq '.[].price' | sort -n | tail -1
```

Para que la composición funcione: stdout lleva datos, stderr lleva mensajes de estado. Nunca mezcles los dos.

```bash
# Correcto
echo "$response" >&1          # datos al stdout
echo "Request completed" >&2  # mensajes al stderr

# Incorrecto: mezclar en stdout rompe los pipes
echo "Request completed"
echo "$response"
```

### 3. Predecible: exit codes

El shell usa exit codes para encadenar comandos. La convención es universal:

| Exit code | Significado |
|-----------|-------------|
| 0 | Exito |
| 1 | Error general |
| 2 | Uso incorrecto (argumento inválido) |
| 3-125 | Errores específicos de la aplicación |

```bash
# El operador && solo ejecuta si el primero exitó con 0
api-toolkit auth login && api-toolkit get /users

# El operador || ejecuta si el primero falló
api-toolkit get /health || notify "API caída"
```

Tu herramienta debe retornar exit code 0 solo cuando todo salió bien, y != 0 en cualquier error.

### 4. Configurable sin modificar código

Los valores que cambian entre entornos (URL base, credenciales, timeouts) deben vivir fuera del script:

```bash
# Mal: hardcoded en el script
BASE_URL="https://api.produccion.com"

# Bien: configurable desde afuera
BASE_URL="${BASE_URL:-https://api.ejemplo.com}"  # default, overrideable
```

Esto permite usar la misma herramienta en dev, staging y producción sin tocar el código.

### 5. Output a stdout, errores a stderr

```bash
log()   { echo "[$(date '+%H:%M:%S')] $*" >&2; }
error() { log "ERROR: $*"; exit 1; }
info()  { [[ "${VERBOSE:-0}" == "1" ]] && log "INFO: $*" || true; }
```

El `info` solo imprime si `--verbose` está activo. Esto es importante: en uso normal, la herramienta es silenciosa salvo que algo falle o el usuario pida verbosidad.

### 6. `--help` claro con ejemplos

El `--help` es la documentación principal. Muchas personas nunca leen el README: van directo al `--help`. Debe incluir:
- Qué hace la herramienta (una línea)
- Todos los subcomandos
- Todas las opciones con descripciones
- Ejemplos reales que el usuario puede copiar y pegar

---

## Estructura de una CLI bash grande

Cuando el script supera las 100 líneas, la estructura importa. Un patrón que escala:

```bash
#!/bin/bash
# api-toolkit — cliente REST configurable para cualquier API
# Version: 1.0.0

set -euo pipefail

readonly VERSION="1.0.0"
readonly CONFIG_DIR="${HOME}/.api-toolkit"

# ── Utilidades ──────────────────────────────────────────────────────────────

log()   { echo "[$(date '+%H:%M:%S')] $*" >&2; }
error() { log "ERROR: $*"; exit 1; }
info()  { [[ "${VERBOSE:-0}" == "1" ]] && log "INFO: $*" || true; }

# ── Configuracion ────────────────────────────────────────────────────────────

load_config() { ... }
init_config()  { ... }

# ── Autenticacion ────────────────────────────────────────────────────────────

get_auth_header() { ... }
ensure_auth()     { ... }
cmd_auth_login()  { ... }
cmd_auth_logout() { ... }
cmd_auth_status() { ... }

# ── Requests ─────────────────────────────────────────────────────────────────

do_request() { ... }
cmd_get()    { ... }
cmd_post()   { ... }
cmd_put()    { ... }
cmd_delete() { ... }

# ── Features avanzadas ───────────────────────────────────────────────────────

cmd_monitor() { ... }
cmd_bench()   { ... }

# ── Help ──────────────────────────────────────────────────────────────────────

show_help() { ... }

# ── Dispatcher ───────────────────────────────────────────────────────────────

main() {
  case "${1:-help}" in
    get)    shift; cmd_get "$@" ;;
    post)   shift; cmd_post "$@" ;;
    put)    shift; cmd_put "$@" ;;
    delete) shift; cmd_delete "$@" ;;
    auth)
      shift
      case "${1:-status}" in
        login)  shift; cmd_auth_login "$@" ;;
        logout) shift; cmd_auth_logout "$@" ;;
        status) shift; cmd_auth_status "$@" ;;
        *)      error "auth: subcomando desconocido: $1" ;;
      esac
      ;;
    monitor) shift; cmd_monitor "$@" ;;
    bench)   shift; cmd_bench "$@" ;;
    init)    shift; init_config "$@" ;;
    --help|-h)  show_help ;;
    --version)  echo "$VERSION" ;;
    *)      error "Comando desconocido: ${1:-}. Ver --help." ;;
  esac
}

main "$@"
```

### Por qué `main "$@"`

La función `main` recibe todos los argumentos del script. Al encapsular todo en `main`, evitas que las funciones auxiliares definidas más arriba ejecuten código accidentalmente. Ademas, facilita el testing con bats (puedes `source` el script sin ejecutar `main`).

### Por qué `shift` antes de pasar a las funciones

```bash
get)  shift; cmd_get "$@" ;;
```

`shift` descarta el primer argumento ("get"), para que `cmd_get` reciba solo los argumentos restantes. Si no haces esto, `cmd_get` recibiría `"get /users"` en lugar de `"/users"`.

---

## Documentation-driven development

Una técnica poderosa: escribir el `--help` antes de implementar cualquier función.

El `--help` define el contrato público de la herramienta:
- Qué subcomandos existen
- Qué argumentos acepta cada uno
- Qué opciones globales hay
- Cómo se comporta en los casos de uso principales

Si no puedes escribir el `--help` claramente, el diseño no está suficientemente pensado. El `--help` fuerza la claridad.

```bash
# Escribir esto primero...
show_help() {
  cat <<EOF
api-toolkit v${VERSION} — cliente REST configurable

Uso:
  api-toolkit [OPCIONES] COMANDO [ARGS]

Comandos:
  auth login              Obtener y guardar token de acceso
  auth logout             Borrar token guardado
  auth status             Mostrar estado del token actual
  get ENDPOINT            GET request al endpoint
  post ENDPOINT [--data JSON]  POST con body JSON
  put ENDPOINT --data JSON     PUT con body JSON
  delete ENDPOINT         DELETE request
  monitor FILE            Health check de lista de URLs
  bench ENDPOINT [--times N]  Benchmark de latencia
  init                    Inicializar configuracion interactivamente

Opciones globales:
  --dry-run               Mostrar comando sin ejecutar
  --verbose               Output detallado
  --base-url URL          Override de BASE_URL
  --output FORMAT         Formato de salida: json (default), table, csv
  --version               Mostrar version
  --help                  Esta ayuda

Ejemplos:
  api-toolkit auth login
  api-toolkit get /users
  api-toolkit post /users --data '{"name":"Ana"}'
  api-toolkit get /users | jq '.[].name'
  api-toolkit monitor urls.txt
  BASE_URL=https://api.ejemplo.com api-toolkit get /health

Configuracion:
  ${HOME}/.api-toolkit/config

EOF
}

# ...y despues implementar las funciones que soportan ese contrato.
```

---

## Separacion en modulos

Para scripts muy largos (mas de 300 lineas), bash permite separar el codigo en archivos y cargarlos con `source`:

```bash
# Estructura de archivos
api-toolkit.sh    # entry point y dispatcher
lib/
  config.sh       # load_config, init_config
  auth.sh         # get_auth_header, ensure_auth, cmd_auth_*
  requests.sh     # do_request, cmd_get, cmd_post, cmd_put, cmd_delete
  features.sh     # cmd_monitor, cmd_bench
  utils.sh        # log, error, info, helper functions
```

```bash
# En api-toolkit.sh, al inicio:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/auth.sh"
source "${SCRIPT_DIR}/lib/requests.sh"
source "${SCRIPT_DIR}/lib/features.sh"
```

Para `api-toolkit` en este bootcamp, un solo archivo es suficiente. La separacion en modulos es para cuando el proyecto crece.

---

## `set -euo pipefail`: por que es obligatorio

```bash
set -euo pipefail
```

- `-e`: el script termina si cualquier comando retorna exit code != 0. Sin esto, los errores pasan silenciosamente y el script continua en un estado inconsistente.
- `-u`: el script termina si se usa una variable no definida. Previene bugs de typos en nombres de variables.
- `-o pipefail`: en un pipe `cmd1 | cmd2`, si `cmd1` falla, el pipe completo falla. Sin esto, solo se comprueba el exit code del ultimo comando.

```bash
# Sin set -euo pipefail: silencioso y peligroso
rm -rf "${DIR}/"   # si DIR esta vacia, borra "/"
echo "Hecho"       # esto se ejecuta aunque rm haya fallado

# Con set -euo pipefail: el script para al primer error
set -euo pipefail
rm -rf "${DIR}/"   # si DIR esta vacia, el script termina aqui
echo "Hecho"       # nunca llega aqui si hubo error
```

---

## Siguiente

[→ 02: Configuracion persistente](02-configuracion-persistente.md) — como guardar y cargar configuracion entre sesiones.
