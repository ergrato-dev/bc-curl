#!/usr/bin/env bash
# crud.sh — Mini cliente REST para JSONPlaceholder /todos
# Uso: ./crud.sh <subcomando> [argumentos]
#
# Subcomandos:
#   list [limite]    — lista los primeros N todos (default 10)
#   get <id>         — obtiene un todo por ID
#   create           — crea un nuevo todo (datos hardcodeados)
#   update <id>      — reemplaza un todo completo (PUT)
#   patch <id>       — cambia el campo "completed" (PATCH)
#   delete <id>      — elimina un todo
#   help             — muestra esta ayuda

set -euo pipefail

API="https://jsonplaceholder.typicode.com/todos"

# ─── helpers ───────────────────────────────────────────────

show_status() {
  local url="$1"
  local method="$2"
  shift 2
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$@" "$url")
  echo "Status: $status"
  return "$status"
}

format_json() {
  python3 -m json.tool 2>/dev/null || cat
}

# ─── subcomandos ───────────────────────────────────────────

cmd_list() {
  local limit="${1:-10}"
  local url="${API}?_limit=${limit}"
  echo "=== GET ${url} ==="
  show_status "$url" "GET"
  echo
  curl -s "$url" | format_json
}

cmd_get() {
  local id="${1:-}"
  if [ -z "$id" ]; then
    echo "Error: especificá un ID. Ejemplo: ./crud.sh get 1"
    exit 1
  fi
  local url="${API}/${id}"
  echo "=== GET ${url} ==="
  show_status "$url" "GET"
  echo
  curl -s "$url" | format_json
}

cmd_create() {
  local url="$API"
  echo "=== POST ${url} ==="
  show_status "$url" "POST" \
    -H "Content-Type: application/json" \
    -d '{"userId":1,"title":"Aprender curl","completed":false}'
  echo
  curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"userId":1,"title":"Aprender curl","completed":false}' \
    "$url" | format_json
}

cmd_update() {
  local id="${1:-}"
  if [ -z "$id" ]; then
    echo "Error: especificá un ID. Ejemplo: ./crud.sh update 1"
    exit 1
  fi
  local url="${API}/${id}"
  echo "=== PUT ${url} ==="
  show_status "$url" "PUT" \
    -H "Content-Type: application/json" \
    -d "{\"userId\":1,\"title\":\"Actualizado con PUT\",\"completed\":true}"
  echo
  curl -s -X PUT \
    -H "Content-Type: application/json" \
    -d "{\"userId\":1,\"title\":\"Actualizado con PUT\",\"completed\":true}" \
    "$url" | format_json
}

cmd_patch() {
  local id="${1:-}"
  if [ -z "$id" ]; then
    echo "Error: especificá un ID. Ejemplo: ./crud.sh patch 1"
    exit 1
  fi
  local url="${API}/${id}"
  echo "=== PATCH ${url} (toggle completed) ==="
  show_status "$url" "PATCH" \
    -H "Content-Type: application/json" \
    -d '{"completed":true}'
  echo
  curl -s -X PATCH \
    -H "Content-Type: application/json" \
    -d '{"completed":true}' \
    "$url" | format_json
}

cmd_delete() {
  local id="${1:-}"
  if [ -z "$id" ]; then
    echo "Error: especificá un ID. Ejemplo: ./crud.sh delete 1"
    exit 1
  fi
  local url="${API}/${id}"
  echo "=== DELETE ${url} ==="
  show_status "$url" "DELETE"
  echo
  curl -s -X DELETE "$url" | format_json
}

cmd_help() {
  cat <<'EOF'
crud.sh — Mini cliente REST para JSONPlaceholder /todos

Uso: ./crud.sh <subcomando> [argumentos]

Subcomandos:
  list [limite]    Lista los primeros N todos (default: 10)
  get <id>         Obtiene un todo por ID
  create           Crea un nuevo todo
  update <id>      Reemplaza un todo completo (PUT)
  patch <id>       Cambia el campo "completed" a true (PATCH)
  delete <id>      Elimina un todo
  help             Muestra esta ayuda

Ejemplos:
  ./crud.sh list
  ./crud.sh list 5
  ./crud.sh get 1
  ./crud.sh create
  ./crud.sh update 1
  ./crud.sh patch 1
  ./crud.sh delete 1
EOF
}

# ─── dispatch ──────────────────────────────────────────────

case "${1:-help}" in
  list)   cmd_list "${2:-}" ;;
  get)    cmd_get "${2:-}" ;;
  create) cmd_create ;;
  update) cmd_update "${2:-}" ;;
  patch)  cmd_patch "${2:-}" ;;
  delete) cmd_delete "${2:-}" ;;
  help)   cmd_help ;;
  *)
    echo "Subcomando desconocido: ${1:-}"
    echo "Usá: ./crud.sh help"
    exit 1
    ;;
esac
