# Documentar una herramienta CLI profesionalmente

![Documentación CLI](../0-assets/04-documentacion-cli.svg)

[← 03: Testing](03-testing-scripts-bash.md) | [→ 05: CI/CD con curl](05-ci-cd-curl.md)

---

## La documentacion es parte del producto

Una herramienta sin documentacion no existe para los demas. Incluso para ti mismo: dentro de 6 meses no recordaras como funciona. La documentacion de una CLI tiene tres piezas:

1. El `--help`: documentacion en tiempo de ejecucion
2. El `README.md`: documentacion para empezar a usar la herramienta
3. El `CHANGELOG.md`: registro de cambios entre versiones

---

## `--help` bien estructurado

El `--help` es lo primero que ve un nuevo usuario. Debe contener todo lo necesario para empezar sin abrir ningun otro documento.

```bash
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
  --verbose               Output detallado (logs a stderr)
  --base-url URL          Override de BASE_URL para esta ejecucion
  --output FORMAT         Formato: json (default), table, csv
  --version               Mostrar version (${VERSION})
  --help                  Esta ayuda

Ejemplos:
  api-toolkit init
  api-toolkit auth login
  api-toolkit get /users
  api-toolkit get /users | jq '.[].name'
  api-toolkit post /users --data '{"name":"Ana","email":"ana@ejemplo.com"}'
  api-toolkit put /users/42 --data '{"name":"Ana Lopez"}'
  api-toolkit delete /users/42
  api-toolkit monitor urls.txt
  api-toolkit bench /users --times 20
  BASE_URL=https://api.staging.com api-toolkit get /health

Variables de entorno:
  BASE_URL        URL base de la API (override de config file)
  AUTH_TYPE       Tipo de auth: none, api_key, bearer, basic
  VERBOSE         1 para output detallado

Configuracion:
  ${HOME}/.api-toolkit/config

EOF
}
```

### Convenciones de formato en `--help`

- Comandos en minusculas, argumentos en MAYUSCULAS
- Argumentos opcionales entre `[corchetes]`
- Argumentos requeridos sin corchetes
- Una descripcion por linea, alineadas
- Los ejemplos son reales, ejecutables, no placeholders abstractos

### Ayuda por subcomando

Para herramientas grandes, es util tener `--help` por subcomando:

```bash
cmd_get() {
  local endpoint=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        cat <<EOF
Uso: api-toolkit get ENDPOINT [--output FORMAT]

Hace un GET request al ENDPOINT relativo a BASE_URL.

Argumentos:
  ENDPOINT      Path relativo, ej: /users o /users/42

Opciones:
  --output json    Output JSON crudo (default)
  --output table   Formatear como tabla (requiere jq)
  --output csv     Formatear como CSV (requiere jq)

Ejemplos:
  api-toolkit get /users
  api-toolkit get /users/42
  api-toolkit get /users | jq '.[].name'
  api-toolkit get /users --output table
EOF
        return 0
        ;;
      *) endpoint="$1" ;;
    esac
    shift
  done

  [[ -z "$endpoint" ]] && error "get: falta ENDPOINT. Ver --help."
  do_request "GET" "$endpoint"
}
```

---

## README del proyecto

El README es para quienes ven el proyecto por primera vez. Secciones minimas:

### 1. Titulo y descripcion (1-2 lineas)

```markdown
# api-toolkit

Cliente REST configurable para la terminal. Soporta autenticacion Bearer, API Key y Basic.
```

### 2. Instalacion

```markdown
## Instalacion

### Requisitos

- bash 4.0+
- curl
- jq

### Instalar

```bash
curl -o ~/bin/api-toolkit https://raw.githubusercontent.com/usuario/api-toolkit/main/api-toolkit.sh
chmod +x ~/bin/api-toolkit
api-toolkit --version
```

O clonar el repositorio:

```bash
git clone https://github.com/usuario/api-toolkit.git
cd api-toolkit
chmod +x api-toolkit.sh
./api-toolkit.sh --version
```
```

### 3. Inicio rapido

```markdown
## Inicio rapido

```bash
# 1. Inicializar configuracion
api-toolkit init

# 2. (Opcional) Autenticarse si la API requiere Bearer token
api-toolkit auth login

# 3. Hacer requests
api-toolkit get /users
api-toolkit post /users --data '{"name": "Ana"}'
```
```

### 4. Configuracion detallada

```markdown
## Configuracion

El archivo de configuracion vive en `~/.api-toolkit/config`:

```bash
BASE_URL=https://api.ejemplo.com
AUTH_TYPE=bearer       # none | api_key | bearer | basic
TOKEN_URL=https://auth.ejemplo.com/oauth/token
CLIENT_ID=tu-client-id
# CLIENT_SECRET en variable de entorno: export CLIENT_SECRET=...
TIMEOUT=30
```

Las variables de entorno tienen prioridad sobre el archivo de config:

```bash
BASE_URL=https://api.staging.com api-toolkit get /health
```
```

### 5. Referencia de comandos

```markdown
## Comandos

### auth

```bash
api-toolkit auth login      # obtener token y guardarlo
api-toolkit auth status     # ver token actual y expiracion
api-toolkit auth logout     # borrar token guardado
```

### get / post / put / delete

```bash
api-toolkit get /users
api-toolkit get /users/42
api-toolkit post /users --data '{"name": "Ana"}'
api-toolkit put /users/42 --data '{"name": "Ana Lopez"}'
api-toolkit delete /users/42
```
...
```

### 6. Troubleshooting

```markdown
## Troubleshooting

### "ERROR: BASE_URL no configurada"

Ejecuta `api-toolkit init` o define la variable:

```bash
export BASE_URL=https://api.ejemplo.com
```

### "curl: (6) Could not resolve host"

Verifica que `BASE_URL` sea correcto y que tengas conexion a internet.

### "ERROR: token expirado y no se pudo renovar"

El CLIENT_SECRET puede haber cambiado. Ejecuta `api-toolkit auth logout` y luego `api-toolkit auth login`.

### Request falla con 401 aunque tengo token

Verifica con `api-toolkit auth status` que el token no este expirado. Si AUTH_TYPE no es `bearer`, verifica que `API_KEY` o `BASIC_USER`/`BASIC_PASS` esten configurados.
```

### 7. Contribuir (opcional en un proyecto de bootcamp)

```markdown
## Contribuir

1. Fork del repositorio
2. Crear rama: `git checkout -b feature/nuevo-comando`
3. Implementar cambios y tests: `bats test/`
4. Pull request con descripcion de los cambios
```

---

## CHANGELOG.md

El CHANGELOG documenta que cambio entre versiones. El formato recomendado es [Keep a Changelog](https://keepachangelog.com/):

```markdown
# Changelog

Todos los cambios notables de este proyecto se documentan aqui.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es/1.0.0/).
El versionado sigue [Semantic Versioning](https://semver.org/).

## [Sin publicar]

### Pendiente
- Soporte para multipart/form-data en POST

## [1.0.0] - 2026-06-15

### Agregado
- Subcomandos: auth login/logout/status, get, post, put, delete, monitor, bench, init
- Soporte de autenticacion: none, api_key, bearer (OAuth2 client_credentials), basic
- Opcion --dry-run para inspeccionar el comando curl sin ejecutarlo
- Opcion --verbose para logs detallados
- Opcion --output con formatos: json, table, csv
- Retry automatico en 429 (respeta Retry-After) y renovacion de token en 401
- Log de requests en ~/.api-toolkit/requests.log
- Benchmarking con percentiles p50, p90, p99
- Monitor de URLs con --parallel y reporte de estado

## [0.1.0] - 2026-05-01

### Agregado
- Estructura base del proyecto
- cmd_get y cmd_post funcionales
- Configuracion basica en ~/.api-toolkit/config
```

### Versionado semantico (semver)

`MAYOR.MENOR.PARCHE`

- `MAYOR`: cambios incompatibles con versiones anteriores (quiebra la API existente)
- `MENOR`: nueva funcionalidad compatible hacia atras
- `PARCHE`: bug fixes compatibles hacia atras

Para `api-toolkit` en el bootcamp, `1.0.0` es la primera version completa.

---

## Documentar en el codigo

El codigo tambien necesita documentacion minima:

```bash
# Obtener el header de autenticacion segun AUTH_TYPE.
# Salida: string con el header, p.e. "Authorization: Bearer TOKEN"
# o string vacio si AUTH_TYPE=none.
# Exit code: 0 siempre (incluso si no hay header).
get_auth_header() {
  case "${AUTH_TYPE:-none}" in
    bearer)
      local token
      token=$(load_token) || { error "No hay token. Ejecuta: api-toolkit auth login"; }
      echo "Authorization: Bearer ${token}"
      ;;
    api_key)
      [[ -z "${API_KEY:-}" ]] && error "AUTH_TYPE=api_key pero API_KEY no esta configurada"
      echo "X-API-Key: ${API_KEY}"
      ;;
    basic)
      [[ -z "${BASIC_USER:-}" ]] && error "AUTH_TYPE=basic pero BASIC_USER no esta configurado"
      # curl maneja basic auth con -u user:pass, no con header
      # esta funcion retorna string vacio; do_request usa -u cuando AUTH_TYPE=basic
      echo ""
      ;;
    none)
      echo ""
      ;;
    *)
      error "AUTH_TYPE desconocido: ${AUTH_TYPE}. Opciones: none, api_key, bearer, basic"
      ;;
  esac
}
```

Nivel adecuado de comentarios para bash:
- Documentar el contrato de cada funcion: que recibe, que retorna, que side effects tiene
- Comentar el "por que", no el "que": el codigo dice "que", el comentario explica "por que"
- Comentar casos no obvios: manejo de plataformas, workarounds, edge cases

---

## Siguiente

[→ 05: curl en CI/CD](05-ci-cd-curl.md) — como usar curl en pipelines de automatizacion.
