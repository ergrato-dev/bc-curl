#!/usr/bin/env bash
# api-toolkit.sh — REST API CLI toolkit
# Proyecto final — Bootcamp curl Zero to Hero
#
# Uso: ./api-toolkit.sh <subcomando> [argumentos]
#
# Subcomandos:
#   auth login|logout|status     Gestión de sesión OAuth2
#   get ENDPOINT [--output F]    GET request
#   post ENDPOINT DATA           POST request
#   put ENDPOINT DATA            PUT request
#   delete ENDPOINT              DELETE request
#   monitor URLS_FILE            Monitoreo de endpoints
#   bench URL [N]                Benchmark (N requests)
#   init                         Configuración interactiva
#
# Flags globales:
#   --dry-run                    Modo simulación
#   --help                       Esta ayuda

set -uo pipefail

# ─── Constants ────────────────────────────────────────────
readonly SCRIPT_NAME="api-toolkit"
readonly CONFIG_DIR="${HOME}/.${SCRIPT_NAME}"

# ─── Globals ──────────────────────────────────────────────
DRY_RUN=false
BASE_URL="https://jsonplaceholder.typicode.com"
TOKEN_URL=""
CLIENT_ID=""
CLIENT_SECRET=""
TIMEOUT=30
CONNECT_TIMEOUT=10
TOKEN_FILE="$CONFIG_DIR/token.json"

# ─── Colors ───────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# ─── Utils ────────────────────────────────────────────────
log()   { echo "[$(date '+%H:%M:%S')] $*" >&2; }
info()  { echo -e "${GREEN}[INFO]${NC}  $*" >&2; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

usage() {
  sed -n '2,21p' "$0"
  exit "${1:-0}"
}

# ─── Config ───────────────────────────────────────────────
load_config() {
  local config_file="$CONFIG_DIR/config"
  [ -f "$config_file" ] && source "$config_file"

  BASE_URL="${BASE_URL:-https://jsonplaceholder.typicode.com}"
  TIMEOUT="${TIMEOUT:-30}"
  CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-10}"
}

# ─── Auth ─────────────────────────────────────────────────
save_token() {
  local token="$1" expires_in="${2:-3600}"
  local now; now=$(date +%s)
  mkdir -p "$CONFIG_DIR"
  jq -n --arg token "$token" --argjson exp $((now + expires_in)) \
    '{access_token: $token, expires_at: $exp}' > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
}

load_token() {
  [ -f "$TOKEN_FILE" ] || return 1
  jq -r '.access_token' "$TOKEN_FILE"
}

is_token_valid() {
  [ -f "$TOKEN_FILE" ] || return 1
  local exp; exp=$(jq -r '.expires_at' "$TOKEN_FILE")
  [ "$exp" -gt $(( $(date +%s) + 60 )) ]
}

ensure_auth() {
  is_token_valid || { error "No hay sesión activa. Usá: $0 auth login"; return 1; }
}

cmd_auth_login() {
  load_config
  [ -z "$TOKEN_URL" ] && error "TOKEN_URL no configurada. Ejecutá: $0 init"

  local response; response=$(curl -sS --max-time "$TIMEOUT" \
    -d "grant_type=client_credentials" \
    -d "client_id=$CLIENT_ID" \
    -d "client_secret=$CLIENT_SECRET" \
    "$TOKEN_URL") || error "No se pudo conectar al Auth Server"

  local token; token=$(echo "$response" | jq -r '.access_token // empty')
  [ -z "$token" ] && error "No se recibió access_token"

  local expires_in; expires_in=$(echo "$response" | jq -r '.expires_in // 3600')
  save_token "$token" "$expires_in"
  info "Sesión iniciada — Token válido hasta $(date -d "@$(( $(date +%s) + expires_in ))" '+%H:%M:%S')"
}

cmd_auth_status() {
  if ! [ -f "$TOKEN_FILE" ]; then
    info "No hay sesión activa"; return 1
  fi
  local exp preview remaining
  exp=$(jq -r '.expires_at' "$TOKEN_FILE")
  preview=$(jq -r '.access_token[:20] + "..."' "$TOKEN_FILE")
  remaining=$((exp - $(date +%s)))
  echo "Token: $preview"
  echo "Expira: $(date -d "@$exp" '+%Y-%m-%d %H:%M:%S') (${remaining}s)"
  if [ "$remaining" -lt 60 ]; then echo "Estado: EXPIRADO"; return 1
  elif [ "$remaining" -lt 300 ]; then echo "Estado: POR EXPIRAR"
  else echo "Estado: VÁLIDO"; fi
}

cmd_auth_logout() {
  if [ -f "$TOKEN_FILE" ]; then rm -f "$TOKEN_FILE"; info "Sesión cerrada"
  else info "No hay sesión activa"; fi
}

# ─── Requests ─────────────────────────────────────────────
do_request() {
  local method="$1" endpoint="$2" data="${3:-}"
  local url="${BASE_URL}${endpoint}" retry_count=0
  local args=(-sS --max-time "$TIMEOUT" --connect-timeout "$CONNECT_TIMEOUT")

  if is_token_valid 2>/dev/null; then
    args+=(-H "Authorization: Bearer $(load_token)")
  fi
  [ "$method" != "GET" ] && [ "$method" != "DELETE" ] && args+=(-X "$method")
  [ -n "$data" ] && args+=(-H "Content-Type: application/json" -d "$data")

  if $DRY_RUN; then
    info "[DRY RUN] $method $url"
    [ -n "$data" ] && info "[DRY RUN] body: $data"
    echo "{}"; return 0
  fi

  while [ "$retry_count" -le 1 ]; do
    local http_code resp_file="/tmp/api_toolkit_resp_$$.json"
    http_code=$(curl "${args[@]}" -o "$resp_file" -w "%{http_code}" "$url")
    local ce=$?
    log_req "$method" "$endpoint" "$http_code"

    if [ "$http_code" = "401" ] && [ "$retry_count" -eq 0 ]; then
      info "Token expirado. Refrescando..."; retry_count=1; continue
    fi

    cat "$resp_file" 2>/dev/null; rm -f "$resp_file"
    return "$ce"
  done
}

log_req() {
  local log_file="$CONFIG_DIR/requests.log"
  mkdir -p "$CONFIG_DIR"
  echo "[$(date -Iseconds)] $1 $2 → $3" >> "$log_file"
}

cmd_get()    { local ep="${1:?Endpoint requerido}"; ensure_auth 2>/dev/null; do_request "GET" "$ep"; }
cmd_post()   { local ep="${1:?Endpoint}" d="${2:?Body JSON}"; ensure_auth 2>/dev/null; do_request "POST" "$ep" "$d"; }
cmd_put()    { local ep="${1:?Endpoint}" d="${2:?Body JSON}"; ensure_auth 2>/dev/null; do_request "PUT" "$ep" "$d"; }
cmd_delete() { local ep="${1:?Endpoint}"; ensure_auth 2>/dev/null; do_request "DELETE" "$ep"; }

# ─── Monitor ──────────────────────────────────────────────
cmd_monitor() {
  local f="${1:?Archivo de URLs requerido}"
  [ -f "$f" ] || error "No encontrado: $f"
  local ok=0 warn=0 err=0
  echo "Monitor — $(date '+%H:%M:%S')"; echo "=============================="
  while IFS= read -r url; do
    [ -z "$url" ] && continue; [[ "$url" == \#* ]] && continue
    local code time
    read -r code time < <(curl -sS -o /dev/null -L --max-time 10 --connect-timeout 5 -w "%{http_code} %{time_total}" "$url" 2>/dev/null || echo "000 0.000")
    if [ "$code" -ge 500 ] || [ "$code" -ge 400 ] || [ "$code" = "000" ]; then
      printf "[ERROR] %s  %ss  %s\n" "$code" "$time" "$url"; err=$((err+1))
    elif [ "$code" -ge 300 ] || awk "BEGIN{exit !($time > 1.0)}"; then
      printf "[WARN ] %s  %ss  %s\n" "$code" "$time" "$url"; warn=$((warn+1))
    else
      printf "[OK   ] %s  %ss  %s\n" "$code" "$time" "$url"; ok=$((ok+1))
    fi
  done < "$f"
  echo "=============================="
  echo "Resumen: OK=$ok WARN=$warn ERROR=$err"
}

# ─── Bench ────────────────────────────────────────────────
cmd_bench() {
  local url="${1:?URL requerida}" n="${2:-10}"
  echo "Benchmark: $url ($n requests)"; echo "=============================="
  local times=() errors=0
  for i in $(seq 1 "$n"); do
    local code time
    read -r code time < <(curl -sS -o /dev/null --max-time 30 --connect-timeout 5 -w "%{http_code} %{time_total}" "$url" 2>/dev/null || echo "000 0")
    if [ "$code" -ge 400 ] || [ "$code" = "000" ]; then
      errors=$((errors+1)); printf "  [%2d] ERROR %s\n" "$i" "$code"
    else
      times+=("$time"); printf "  [%2d] %s  %ss\n" "$i" "$code" "$time"
    fi
  done
  echo ""
  if [ ${#times[@]} -gt 0 ]; then
    printf '%s\n' "${times[@]}" | sort -n | awk '
    { vals[NR]=$1; sum+=$1 } END { n=NR
      printf "  Min: %.4fs  Avg: %.4fs  Max: %.4fs\n", vals[1], sum/n, vals[n]
      printf "  p50: %.4fs  p90: %.4fs  p99: %.4fs\n", vals[int(n*0.5)+1], vals[int(n*0.9)+1], vals[int(n*0.99)+1] }'
  fi
  echo "  Errores: $errors / $n"
}

# ─── Init ─────────────────────────────────────────────────
cmd_init() {
  echo "=== Configuración de $SCRIPT_NAME ==="; echo ""
  read -rp "Base URL [https://jsonplaceholder.typicode.com]: " BASE_URL
  BASE_URL="${BASE_URL:-https://jsonplaceholder.typicode.com}"
  read -rp "Token URL [https://httpbin.org/post]: " TOKEN_URL
  TOKEN_URL="${TOKEN_URL:-https://httpbin.org/post}"
  read -rp "Client ID: " CLIENT_ID
  read -rsp "Client Secret: " CLIENT_SECRET; echo ""
  read -rp "Timeout [30]: " TIMEOUT; TIMEOUT="${TIMEOUT:-30}"
  mkdir -p "$CONFIG_DIR"; chmod 700 "$CONFIG_DIR"
  cat > "$CONFIG_DIR/config" <<ENDCONF
BASE_URL=$BASE_URL
TOKEN_URL=$TOKEN_URL
CLIENT_ID=$CLIENT_ID
CLIENT_SECRET=$CLIENT_SECRET
TIMEOUT=$TIMEOUT
CONNECT_TIMEOUT=10
ENDCONF
  chmod 600 "$CONFIG_DIR/config"
  info "Configuración guardada en $CONFIG_DIR/config"
}

# ─── Dispatch ─────────────────────────────────────────────
main() {
  load_config 2>/dev/null || true

  # Parse global flags
  while [[ "${1:-}" == --* ]]; do
    case "$1" in
      --dry-run) DRY_RUN=true; shift ;;
      --help|-h) usage 0 ;;
      *) error "Flag desconocido: $1" ;;
    esac
  done

  local cmd="${1:-help}"; shift || true
  case "$cmd" in
    auth)
      case "${1:-}" in
        login)  cmd_auth_login ;;
        logout) cmd_auth_logout ;;
        status) cmd_auth_status ;;
        *)      error "Uso: $0 auth login|logout|status" ;;
      esac ;;
    get)    cmd_get "$@" ;;
    post)   cmd_post "$@" ;;
    put)    cmd_put "$@" ;;
    delete) cmd_delete "$@" ;;
    monitor) cmd_monitor "$@" ;;
    bench)  cmd_bench "$@" ;;
    init)   cmd_init ;;
    help|--help|-h) usage 0 ;;
    *)      error "Subcomando desconocido: $cmd. Usá: $0 help" ;;
  esac
}

main "$@"
