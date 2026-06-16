# Etapa 1: Estructura base de api-toolkit

[← Practicas](../README.md) | [→ Etapa 2: Modulo auth](../02-ejercicio-auth-module/README.md)

**Tiempo estimado:** 45 minutos

---

## Objetivo

Construir el esqueleto completo de `api-toolkit.sh`: la estructura que soporte todo lo demas. Al final de esta etapa, el script funciona (carga sin errores, muestra ayuda, responde a subcomandos), aunque los subcomandos no hagan nada real todavia.

Un buen esqueleto es la base de una herramienta mantenible. Una vez que esta estructura existe, agregar funcionalidad es cuestion de rellenar funciones, no de reorganizar codigo.

---

## Tareas

### Tarea 1: Configuracion inicial del script

El script empieza con tres elementos fundamentales:

```bash
#!/bin/bash
# api-toolkit — cliente REST configurable para cualquier API REST
# Version: 1.0.0

set -euo pipefail
```

- El shebang `#!/bin/bash` especifica que interpreter usar
- `set -euo pipefail` activa el modo seguro (ver teoria 01)
- El comentario de version es opcional pero profesional

Tambien define las constantes globales:

```bash
readonly VERSION="1.0.0"
readonly CONFIG_DIR="${HOME}/.api-toolkit"
readonly LOG_FILE="${CONFIG_DIR}/requests.log"
```

`readonly` previene que estas variables se sobreescriban accidentalmente.

### Tarea 2: Funciones de utilidad

Estas tres funciones son la base del sistema de logging. Deben existir antes que cualquier otra funcion:

```bash
log()   { echo "[$(date '+%H:%M:%S')] $*" >&2; }
error() { log "ERROR: $*"; exit 1; }
info()  { [[ "${VERBOSE:-0}" == "1" ]] && log "INFO: $*" || true; }
```

El `>&2` envia el output a stderr. Esto es critico: los mensajes de estado no deben mezclarse con los datos de respuesta en stdout.

### Tarea 3: `show_help()` completa

Escribe el `--help` completo antes de implementar nada mas. Debe incluir:
- Nombre y version de la herramienta (una linea)
- Seccion "Uso:" con la sintaxis general
- Seccion "Comandos:" con todos los subcomandos y su descripcion
- Seccion "Opciones globales:" con `--dry-run`, `--verbose`, `--base-url`, `--output`, `--version`, `--help`
- Seccion "Ejemplos:" con al menos 5 comandos reales ejecutables
- Seccion "Configuracion:" con la ruta al config file

Usa `cat <<EOF ... EOF` para el heredoc.

### Tarea 4: `load_config()`

Lee la configuracion de archivo y establece defaults:

```bash
load_config() {
  # Defaults (menor prioridad)
  BASE_URL="${BASE_URL:-https://jsonplaceholder.typicode.com}"
  AUTH_TYPE="${AUTH_TYPE:-none}"
  TIMEOUT="${TIMEOUT:-30}"
  VERBOSE="${VERBOSE:-0}"
  DRY_RUN="${DRY_RUN:-0}"
  OUTPUT_FORMAT="${OUTPUT_FORMAT:-json}"

  # Config file (sobreescribe defaults si existe)
  if [[ -f "${CONFIG_DIR}/config" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_DIR}/config"
  fi
}
```

El comentario `# shellcheck source=/dev/null` le dice a shellcheck (linter de bash) que ignore el source dinamico.

### Tarea 5: `init_config()`

Crea el directorio y archivo de configuracion por defecto:

```bash
init_config() {
  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR"

  # ... leer BASE_URL interactivamente ...
  # ... escribir archivo de config ...

  echo "Config creada en ${CONFIG_DIR}/config"
  echo "Edita el archivo para ajustar las opciones."
}
```

El directorio debe tener permisos `700` (solo el usuario puede acceder).

### Tarea 6: Stubs de todos los comandos

Cada subcomando tiene una funcion. Por ahora, las funciones muestran un mensaje descriptivo en lugar de hacer trabajo real:

```bash
cmd_get() {
  echo "TODO: implementar GET request a: ${1:-ENDPOINT}" >&2
  echo "Consulta la Etapa 3 para implementar esta funcion."
}

cmd_post()   { echo "TODO: implementar cmd_post" >&2; }
cmd_put()    { echo "TODO: implementar cmd_put" >&2; }
cmd_delete() { echo "TODO: implementar cmd_delete" >&2; }

cmd_auth_login()  { echo "TODO: implementar cmd_auth_login" >&2; }
cmd_auth_logout() { echo "TODO: implementar cmd_auth_logout" >&2; }
cmd_auth_status() { echo "TODO: implementar cmd_auth_status" >&2; }

cmd_monitor() { echo "TODO: implementar cmd_monitor" >&2; }
cmd_bench()   { echo "TODO: implementar cmd_bench" >&2; }
```

### Tarea 7: Manejo de flags globales en `main()`

Antes de despachar al subcomando, `main()` debe procesar los flags globales:

```bash
main() {
  # Cargar config primero
  load_config

  # Procesar flags globales
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --verbose|-v)   VERBOSE=1; shift ;;
      --dry-run)      DRY_RUN=1; shift ;;
      --base-url)     BASE_URL="${2:?--base-url requiere un argumento}"; shift 2 ;;
      --output)       OUTPUT_FORMAT="${2:?--output requiere un argumento}"; shift 2 ;;
      --version)      echo "$VERSION"; exit 0 ;;
      --help|-h)      show_help; exit 0 ;;
      --)             shift; break ;;
      -*)             error "Opcion desconocida: $1. Ver --help." ;;
      *)              break ;;  # primer argumento no-flag: es el subcomando
    esac
  done

  # Dispatcher
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
        *)      error "auth: subcomando desconocido: ${1:-}. Opciones: login, logout, status" ;;
      esac
      ;;
    monitor) shift; cmd_monitor "$@" ;;
    bench)   shift; cmd_bench "$@" ;;
    init)    shift; init_config "$@" ;;
    help)    show_help ;;
    *)       error "Comando desconocido: ${1}. Ver --help." ;;
  esac
}

main "$@"
```

---

## Verificacion

Al terminar esta etapa, los siguientes comandos deben funcionar:

```bash
# Sintaxis sin errores
bash -n api-toolkit.sh

# Version
bash api-toolkit.sh --version
# Output esperado: 1.0.0

# Ayuda
bash api-toolkit.sh --help
# Output: descripcion completa con todos los comandos y opciones

# Ayuda con flag corta
bash api-toolkit.sh -h
# Output: idem

# Comando desconocido
bash api-toolkit.sh no-existe
# Exit code != 0, mensaje de error en stderr

# Stub de subcomando
bash api-toolkit.sh get /users
# Mensaje de TODO (exit code puede ser != 0 esta bien)

# Flag global antes del subcomando
bash api-toolkit.sh --verbose get /users
# Mismo mensaje de TODO, la flag debe ser procesada sin error

# Inicializar config
bash api-toolkit.sh init
# Crea ~/.api-toolkit/config interactivamente
# Verificar: cat ~/.api-toolkit/config

# Sin argumentos muestra ayuda
bash api-toolkit.sh
# Output: ayuda (igual que --help)
```

---

## Checklist de entrega

- [ ] El script carga sin errores de sintaxis (`bash -n` exitoso)
- [ ] `--version` muestra la version y retorna exit 0
- [ ] `--help` muestra ayuda completa con todos los subcomandos documentados
- [ ] Un comando desconocido retorna exit code != 0
- [ ] `load_config()` carga el archivo de config si existe
- [ ] `init_config()` crea el directorio y archivo con permisos correctos
- [ ] Todos los subcomandos tienen stubs que no crashean el script
- [ ] Los flags `--verbose`, `--dry-run`, `--base-url`, `--output` son aceptados antes del subcomando

---

## Siguiente etapa

[→ Etapa 2: Modulo de autenticacion](../02-ejercicio-auth-module/README.md)
