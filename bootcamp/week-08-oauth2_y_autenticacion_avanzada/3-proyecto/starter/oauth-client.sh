#!/bin/bash
# oauth-client.sh — OAuth2 client generico con gestion automatica de token lifecycle

set -euo pipefail

CONFIG_DIR="${HOME}/.oauth-client"
CONFIG_FILE="${CONFIG_DIR}/config"
TOKEN_FILE="${CONFIG_DIR}/token.json"
LOG_FILE="${CONFIG_DIR}/requests.log"

DRY_RUN=0

# ---------------------------------------------------------------------------
# Configuracion
# ---------------------------------------------------------------------------

load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuracion no encontrada en ${CONFIG_FILE}" >&2
    echo "" >&2
    echo "Crear el archivo con el siguiente contenido:" >&2
    echo "" >&2
    echo "  TOKEN_URL=https://demo.duendesoftware.com/connect/token" >&2
    echo "  CLIENT_ID=m2m" >&2
    echo "  CLIENT_SECRET=secret" >&2
    echo "  BASE_URL=https://demo.duendesoftware.com" >&2
    echo "  SCOPE=api" >&2
    echo "" >&2
    echo "Luego ejecutar: $0 login" >&2
    exit 1
  fi
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"

  # Verificar variables obligatorias
  local missing=()
  [[ -z "${TOKEN_URL:-}" ]]    && missing+=("TOKEN_URL")
  [[ -z "${CLIENT_ID:-}" ]]    && missing+=("CLIENT_ID")
  [[ -z "${CLIENT_SECRET:-}" ]] && missing+=("CLIENT_SECRET")
  [[ -z "${BASE_URL:-}" ]]     && missing+=("BASE_URL")

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Faltan variables en ${CONFIG_FILE}: ${missing[*]}" >&2
    exit 1
  fi

  SCOPE="${SCOPE:-}"
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

log_request() {
  local method="$1" endpoint="$2" status="$3"
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  printf '[%s] %s %s -> %s\n' "$ts" "$method" "$endpoint" "$status" >> "$LOG_FILE"
}

# ---------------------------------------------------------------------------
# Gestion de tokens
# ---------------------------------------------------------------------------

get_token() {
  local scope_param=""
  [[ -n "${SCOPE:-}" ]] && scope_param="&scope=${SCOPE}"

  echo "Obteniendo token de ${TOKEN_URL}..." >&2

  local response
  response=$(curl -s -w '\n%{http_code}' -X POST "$TOKEN_URL" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}${scope_param}")

  local body http_code
  http_code=$(printf '%s' "$response" | tail -1)
  body=$(printf '%s' "$response" | head -n -1)

  if [[ "$http_code" != "200" ]]; then
    echo "ERROR: Token endpoint retorno HTTP ${http_code}" >&2
    echo "$body" | jq '.' 2>/dev/null || echo "$body" >&2
    exit 1
  fi

  # Calcular expires_at: epoch actual + expires_in
  local expires_in expires_at
  expires_in=$(printf '%s' "$body" | jq -r '.expires_in // 3600')
  expires_at=$(( $(date +%s) + expires_in ))

  # Guardar token con expires_at calculado
  mkdir -p "$CONFIG_DIR"
  printf '%s' "$body" | jq --argjson exp "$expires_at" '. + {expires_at: $exp}' > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"

  local expiry_human
  expiry_human=$(date -d "@${expires_at}" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null \
    || date -r "$expires_at" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null \
    || echo "epoch ${expires_at}")

  echo "Token obtenido. Expira: ${expiry_human}" >&2
}

load_token() {
  [[ -f "$TOKEN_FILE" ]] || return 1
  ACCESS_TOKEN=$(jq -r '.access_token // empty' "$TOKEN_FILE")
  EXPIRES_AT=$(jq -r '.expires_at // 0' "$TOKEN_FILE")
  [[ -n "$ACCESS_TOKEN" ]] || return 1
  return 0
}

is_token_valid() {
  # Retorna 0 si el token es valido con margen de 60 segundos, 1 si no
  load_token || return 1
  local now margin=60
  now=$(date +%s)
  [[ $(( EXPIRES_AT - now )) -gt $margin ]]
}

ensure_token() {
  if ! is_token_valid; then
    get_token
  fi
  load_token
}

# ---------------------------------------------------------------------------
# Requests
# ---------------------------------------------------------------------------

do_request() {
  local method="$1" endpoint="$2" data="${3:-}" retry="${4:-0}"

  ensure_token

  local url="${BASE_URL}${endpoint}"

  local curl_args=(
    -s -w '\n%{http_code}'
    -X "$method"
    -H "Authorization: Bearer ${ACCESS_TOKEN}"
    -H "Accept: application/json"
  )

  if [[ -n "$data" ]]; then
    curl_args+=(-H "Content-Type: application/json" -d "$data")
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] curl ${curl_args[*]} \"${url}\""
    return 0
  fi

  local response
  response=$(curl "${curl_args[@]}" "$url")

  local http_code body
  http_code=$(printf '%s' "$response" | tail -1)
  body=$(printf '%s' "$response" | head -n -1)

  log_request "$method" "$endpoint" "$http_code"

  if [[ "$http_code" == "401" && "$retry" -eq 0 ]]; then
    echo "Token rechazado (401). Renovando..." >&2
    get_token
    do_request "$method" "$endpoint" "$data" 1
    return $?
  fi

  if [[ "$http_code" -ge 400 ]]; then
    echo "ERROR HTTP ${http_code}:" >&2
    echo "$body" | jq '.' 2>/dev/null || echo "$body" >&2
    exit 2
  fi

  echo "$body" | jq '.' 2>/dev/null || echo "$body"
}

# ---------------------------------------------------------------------------
# Subcomandos
# ---------------------------------------------------------------------------

cmd_login() {
  if is_token_valid 2>/dev/null; then
    load_token
    local now remaining expiry_human
    now=$(date +%s)
    remaining=$(( EXPIRES_AT - now ))
    expiry_human=$(date -d "@${EXPIRES_AT}" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null \
      || date -r "$EXPIRES_AT" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null \
      || echo "epoch ${EXPIRES_AT}")
    echo "Ya hay un token valido. Expira: ${expiry_human} (en ${remaining}s)"
    return 0
  fi
  get_token
  echo "Login OK"
}

cmd_logout() {
  rm -f "$TOKEN_FILE"
  echo "Logout OK. Token eliminado."
}

cmd_status() {
  if ! load_token 2>/dev/null; then
    echo "Sin token. Ejecutar: $0 login"
    return 0
  fi

  local now remaining
  now=$(date +%s)
  remaining=$(( EXPIRES_AT - now ))

  local expiry_human
  expiry_human=$(date -d "@${EXPIRES_AT}" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null \
    || date -r "$EXPIRES_AT" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null \
    || echo "epoch ${EXPIRES_AT}")

  if [[ $remaining -le 0 ]]; then
    echo "Token: EXPIRADO"
  elif [[ $remaining -lt 60 ]]; then
    echo "Token: activo (expira en ${remaining} segundos — renovar pronto)"
  else
    local mins=$(( remaining / 60 ))
    echo "Token: activo (expira en ${mins} minutos — ${expiry_human})"
  fi

  # Decodificar payload del JWT sin validar firma
  local payload
  payload=$(printf '%s' "$ACCESS_TOKEN" | cut -d. -f2 | tr '_-' '/+')
  # Agregar padding si es necesario
  local pad=$(( ${#payload} % 4 ))
  [[ $pad -eq 2 ]] && payload="${payload}=="
  [[ $pad -eq 3 ]] && payload="${payload}="

  local decoded
  decoded=$(printf '%s' "$payload" | base64 -d 2>/dev/null | jq -r '
    "  sub: " + (.sub // "N/A") + "\n" +
    "  iss: " + (.iss // "N/A") + "\n" +
    "  scope: " + ((.scope // .scp // []) | if type=="array" then join(" ") else . end)
  ' 2>/dev/null) && echo "$decoded" || true
}

cmd_call() {
  local method="" endpoint="" data=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN=1; shift ;;
      --data|-d) data="$2"; shift 2 ;;
      GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)
        method="$1"; shift ;;
      *)
        if [[ -z "$endpoint" ]]; then
          endpoint="$1"
        fi
        shift ;;
    esac
  done

  if [[ -z "$method" || -z "$endpoint" ]]; then
    echo "ERROR: Uso: $0 call METHOD ENDPOINT [--data JSON]" >&2
    echo "  Ejemplo: $0 call GET /api/users" >&2
    echo "  Ejemplo: $0 call POST /api/users --data '{\"name\":\"Ana\"}'" >&2
    exit 3
  fi

  do_request "$method" "$endpoint" "$data"
}

cmd_help() {
  cat <<EOF
Uso: $0 SUBCOMANDO [opciones]

Subcomandos:
  login                           Obtener y guardar token OAuth2
  logout                          Eliminar token guardado
  status                          Mostrar estado del token actual
  call METHOD ENDPOINT [opciones] Hacer request autenticado

Opciones para 'call':
  --data JSON        Body JSON del request
  --dry-run          Mostrar el comando curl sin ejecutarlo

Configuracion en ${CONFIG_FILE}:
  TOKEN_URL=https://...
  CLIENT_ID=...
  CLIENT_SECRET=...
  BASE_URL=https://...
  SCOPE=...         (opcional)

Logs en: ${LOG_FILE}
Token en: ${TOKEN_FILE}
EOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  mkdir -p "$CONFIG_DIR"

  local cmd="${1:-help}"
  shift || true

  # --dry-run puede pasarse como primer argumento global
  if [[ "$cmd" == "--dry-run" ]]; then
    DRY_RUN=1
    cmd="${1:-help}"
    shift || true
  fi

  case "$cmd" in
    login)       load_config; cmd_login ;;
    logout)      load_config; cmd_logout ;;
    status)      load_config; cmd_status ;;
    call)        load_config; cmd_call "$@" ;;
    --help|-h|help) cmd_help ;;
    *)
      echo "ERROR: Subcomando desconocido: ${cmd}" >&2
      cmd_help
      exit 3
      ;;
  esac
}

main "$@"
