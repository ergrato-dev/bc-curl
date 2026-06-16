#!/usr/bin/env bash
# session.sh — SSL & Session Checker
# Simula login con cookies, mantiene sesión, hace requests autenticados.
#
# Uso: ./session.sh <subcomando> [argumentos]
#
# Subcomandos:
#   login user pass          Inicia sesión, guarda cookies en ~/.session-checker/sesion.txt
#   status                   Muestra estado de la sesión
#   get URL                  GET autenticado usando la sesión guardada
#   logout                   Cierra sesión (borra archivo de cookies)

set -euo pipefail

SESSION_DIR="${HOME}/.session-checker"
SESSION_FILE="${SESSION_DIR}/sesion.txt"
API_BASE="https://httpbin.org"
CONNECT_TIMEOUT=10
MAX_TIME=30
RETRY=2

# ─── helpers ───────────────────────────────────────────────

ensure_session_dir() {
  mkdir -p "$SESSION_DIR"
}

has_session() {
  [ -f "$SESSION_FILE" ] && [ -s "$SESSION_FILE" ]
}

require_session() {
  if ! has_session; then
    echo "Error: no hay sesión activa. Ejecutá primero: ./session.sh login usuario contraseña"
    exit 1
  fi
}

curl_opts() {
  echo "--connect-timeout ${CONNECT_TIMEOUT} --max-time ${MAX_TIME} --retry ${RETRY}"
}

# ─── subcomandos ───────────────────────────────────────────

cmd_login() {
  local user="${1:-}"
  local pass="${2:-}"

  if [ -z "$user" ] || [ -z "$pass" ]; then
    echo "Error: usuario y contraseña requeridos"
    echo "Uso: ./session.sh login usuario contraseña"
    exit 1
  fi

  ensure_session_dir

  echo "=== Iniciando sesión ==="
  echo "Usuario: $user"

  # Simular login: setear cookies vía httpbin
  curl -s $(curl_opts) \
    -c "$SESSION_FILE" \
    "${API_BASE}/cookies/set?session=${user}_$(date +%s)&user=${user}" \
    > /dev/null

  if has_session; then
    echo "✓ Sesión guardada en ${SESSION_FILE}"
    echo ""
    echo "Cookies almacenadas:"
    grep -v '^#' "$SESSION_FILE" | grep -v '^$' | awk -F$'\t' '{printf "  %-20s = %s\n", $6, $7}'
  else
    echo "✗ Error al guardar la sesión"
    exit 1
  fi
}

cmd_status() {
  echo "=== Estado de sesión ==="

  if ! has_session; then
    echo "No hay sesión activa."
    echo "Iniciá sesión con: ./session.sh login usuario contraseña"
    exit 1
  fi

  echo "✓ Sesión activa: ${SESSION_FILE}"
  echo ""
  echo "Cookies en la sesión:"
  grep -v '^#' "$SESSION_FILE" | grep -v '^$' | awk -F$'\t' '{printf "  %-20s = %s\n", $6, $7}'

  # Verificar que el servidor las acepta
  echo ""
  echo "Verificando sesión con el servidor..."
  local result
  result=$(curl -s $(curl_opts) -b "$SESSION_FILE" "${API_BASE}/cookies")
  local cookies_count
  cookies_count=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('cookies',{})))" 2>/dev/null || echo "0")

  echo "El servidor reconoce $cookies_count cookie(s)"
}

cmd_get() {
  local url="${1:-}"

  if [ -z "$url" ]; then
    echo "Error: especificá una URL"
    echo "Uso: ./session.sh get URL"
    exit 1
  fi

  require_session

  echo "=== GET ${url} ==="
  echo ""

  local start_time
  start_time=$(date +%s%N)

  curl -s $(curl_opts) -b "$SESSION_FILE" \
    -w "\n---\nStatus: %{http_code}\nTime: %{time_total}s\n" \
    "$url"

  local end_time
  end_time=$(date +%s%N)
  local elapsed_ms=$(( (end_time - start_time) / 1000000 ))
  echo "Wall clock: ${elapsed_ms}ms"
}

cmd_logout() {
  echo "=== Cerrando sesión ==="

  if has_session; then
    rm -f "$SESSION_FILE"
    echo "✓ Sesión eliminada: ${SESSION_FILE}"
  else
    echo "No hay sesión activa para cerrar."
  fi
}

cmd_help() {
  cat <<'EOF'
session.sh — SSL & Session Checker

Uso: ./session.sh <subcomando> [argumentos]

Subcomandos:
  login user pass     Inicia sesión y guarda cookies
  status              Muestra estado de la sesión activa
  get URL             Hace GET autenticado con la sesión
  logout              Cierra sesión (borra archivo de cookies)

Configuración de timeout (aplicada a todos los requests):
  --connect-timeout 10    (establecer conexión)
  --max-time 30           (operación total)
  --retry 2               (reintentos en error de red)

Ejemplos:
  ./session.sh login ana password123
  ./session.sh status
  ./session.sh get https://httpbin.org/get
  ./session.sh logout
EOF
}

# ─── dispatch ──────────────────────────────────────────────

case "${1:-help}" in
  login)
    shift
    cmd_login "$@"
    ;;
  status)
    cmd_status
    ;;
  get)
    shift
    cmd_get "$@"
    ;;
  logout)
    cmd_logout
    ;;
  help|--help|-h)
    cmd_help
    ;;
  *)
    echo "Subcomando desconocido: ${1:-}"
    echo "Usá: ./session.sh help"
    exit 1
    ;;
esac
