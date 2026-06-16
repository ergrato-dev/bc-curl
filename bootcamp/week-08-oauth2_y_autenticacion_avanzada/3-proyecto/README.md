# Proyecto Semana 8: oauth-client.sh

## Descripcion

Construir `oauth-client.sh`, un cliente OAuth2 reutilizable que gestiona el token lifecycle de forma transparente y expone una interfaz simple para interactuar con cualquier API protegida.

## Interfaz del Script

```bash
# Autenticarse (obtener y guardar token)
./oauth-client.sh login

# Llamar a un endpoint
./oauth-client.sh call GET /api/users
./oauth-client.sh call POST /api/users '{"name":"Ana","email":"ana@x.com"}'
./oauth-client.sh call DELETE /api/users/123

# Ver estado del token actual
./oauth-client.sh status

# Eliminar token (desautenticarse)
./oauth-client.sh logout

# Ayuda
./oauth-client.sh --help
```

## Subcomandos

### login

Obtiene un access token usando Client Credentials y lo guarda en `~/.oauth-client/token.json`.
Si ya hay un token valido, no hace nada (imprime mensaje).

```
$ ./oauth-client.sh login
Obteniendo token de https://demo.duendesoftware.com/connect/token...
Token obtenido. Expira: Mon 14 Oct 2024 16:00:00 UTC
```

### logout

Elimina el archivo de token guardado.

```
$ ./oauth-client.sh logout
Token eliminado.
```

### status

Muestra informacion del token actual sin hacer requests al servidor.

```
$ ./oauth-client.sh status
Token: eyJhbGci... (valido)
Expira: Mon 14 Oct 2024 16:00:00 UTC (en 3421 segundos)
Subject: m2m.client
Issuer: https://demo.duendesoftware.com
```

### call METHOD ENDPOINT [data]

Hace un request autenticado. Gestiona el token automaticamente (renueva si expiro).

```
$ ./oauth-client.sh call GET /api/test
{"message": "OK", "user": "m2m.client"}

$ ./oauth-client.sh call POST /api/items '{"name":"test"}'
{"id": 42, "name": "test"}
```

## Requisitos

### Configuracion

El script lee su configuracion de `~/.oauth-client/config` o de variables de entorno:

```bash
# ~/.oauth-client/config
OAUTH_TOKEN_ENDPOINT="https://demo.duendesoftware.com/connect/token"
OAUTH_CLIENT_ID="m2m"
OAUTH_CLIENT_SECRET="secret"
OAUTH_SCOPE="api"
OAUTH_BASE_URL="https://demo.duendesoftware.com"
```

Variables de entorno tienen prioridad sobre el archivo de config.

### Token Persistence

- Token guardado en `~/.oauth-client/token.json`
- Permisos del archivo: 600
- Formato: JSON con `access_token`, `expires_at`, `token_type`
- Verificar validez antes de cada uso (con margen de 60 segundos)

### Manejo de Errores

- Si no hay config, imprimir mensaje claro con instrucciones
- Si el login falla, imprimir el error del servidor y salir con codigo 1
- Si `call` recibe 401 despues de renovar, imprimir error y salir con codigo 2
- Si el endpoint no existe (404), mostrar el body de error del servidor

### Exit Codes

| Codigo | Significado |
|--------|-------------|
| 0 | Exito |
| 1 | Error de autenticacion / configuracion |
| 2 | Error en el request (4xx, 5xx) |
| 3 | Error de uso (argumentos incorrectos) |

## Estructura del Script

```bash
#!/bin/bash
# oauth-client.sh

# Variables de configuracion (con defaults)
CONFIG_DIR="$HOME/.oauth-client"
TOKEN_FILE="$CONFIG_DIR/token.json"
CONFIG_FILE="$CONFIG_DIR/config"

# Funciones internas
load_config() { ... }
save_token() { ... }
is_token_valid() { ... }
get_valid_token() { ... }

# Subcomandos
cmd_login() { ... }
cmd_logout() { ... }
cmd_status() { ... }
cmd_call() { ... }
cmd_help() { ... }

# Main
main() {
  load_config
  case "$1" in
    login)   cmd_login ;;
    logout)  cmd_logout ;;
    status)  cmd_status ;;
    call)    shift; cmd_call "$@" ;;
    --help|-h) cmd_help ;;
    *) echo "Subcomando desconocido: $1" >&2; cmd_help; exit 3 ;;
  esac
}

main "$@"
```

## Criterios de Evaluacion

- **Funcionalidad** (40%): los 4 subcomandos funcionan correctamente
- **Token lifecycle** (25%): el token se persiste, verifica y renueva correctamente
- **Manejo de errores** (20%): mensajes claros, exit codes correctos
- **Codigo** (15%): legible, funciones bien nombradas, sin repeticion

## Entrega

Archivo `oauth-client.sh` en esta carpeta (`3-proyecto/`).
El script debe ser ejecutable (`chmod +x oauth-client.sh`) y funcionar correctamente contra el servidor de demo sin modificaciones.

Incluir tambien una breve demostracion en `demo.md`: captura de pantalla o texto copiado de una sesion completa (login -> call -> status -> logout).
