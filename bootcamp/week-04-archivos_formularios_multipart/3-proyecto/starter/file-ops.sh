#!/usr/bin/env bash
# file-ops.sh — File Manager CLI para operaciones con httpbin
# Uso: ./file-ops.sh <subcomando> [argumentos]
#
# Subcomandos:
#   download URL [output]    — descarga un archivo con barra de progreso
#   upload FILE               — sube un archivo vía multipart
#   form-post key=value ...   — envía campos URL-encoded

set -euo pipefail

# ─── helpers ───────────────────────────────────────────────

usage() {
  cat <<'EOF'
file-ops.sh — File Manager CLI

Uso: ./file-ops.sh <subcomando> [argumentos]

Subcomandos:
  download URL [output]    Descarga un archivo. Usa -o si se da nombre, sino -O
  upload FILE              Sube un archivo vía multipart/form-data
  form-post key=value ...  Envía campos como form URL-encoded

Ejemplos:
  ./file-ops.sh download https://httpbin.org/image/png mi-imagen.png
  ./file-ops.sh download https://httpbin.org/json
  ./file-ops.sh upload documento.pdf
  ./file-ops.sh form-post nombre=Ana email=ana@mail.com
EOF
}

# ─── subcomandos ───────────────────────────────────────────

cmd_download() {
  local url="${1:-}"
  local output="${2:-}"

  if [ -z "$url" ]; then
    echo "Error: especificá una URL"
    echo "Uso: ./file-ops.sh download URL [output]"
    exit 1
  fi

  echo "=== Descargando ==="
  echo "URL: $url"

  if [ -n "$output" ]; then
    echo "Archivo: $output"
    curl --progress-bar -o "$output" "$url"
    if [ -f "$output" ]; then
      echo "Descarga completa: $(wc -c < "$output") bytes"
    fi
  else
    echo "Usando nombre remoto (-O)..."
    curl --progress-bar -O "$url"
    local filename
    filename=$(basename "$url")
    if [ -f "$filename" ]; then
      echo "Descarga completa: $(wc -c < "$filename") bytes → $filename"
    fi
  fi
}

cmd_upload() {
  local file="${1:-}"

  if [ -z "$file" ]; then
    echo "Error: especificá un archivo"
    echo "Uso: ./file-ops.sh upload ARCHIVO"
    exit 1
  fi

  if [ ! -f "$file" ]; then
    echo "Error: el archivo '$file' no existe"
    exit 1
  fi

  local size
  size=$(wc -c < "$file")
  echo "=== Subiendo ==="
  echo "Archivo: $file ($size bytes)"
  echo ""

  curl -s -F "archivo=@${file}" https://httpbin.org/post | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
files = data.get('files', {})
if files:
    print('Archivo recibido por el servidor:')
    for name, content in files.items():
        print(f'  Campo: {name}')
        if isinstance(content, str):
            print(f'  Contenido (primeros 200 chars): {content[:200]}')
else:
    print('(sin archivos en la respuesta)')
"
}

cmd_form_post() {
  if [ $# -eq 0 ]; then
    echo "Error: especificá al menos un campo key=value"
    echo "Uso: ./file-ops.sh form-post key=value ..."
    exit 1
  fi

  echo "=== Enviando formulario ==="

  # Build curl args dynamically
  local curl_args=()
  for pair in "$@"; do
    if [[ "$pair" != *=* ]]; then
      echo "Error: formato inválido '$pair'. Usá key=value"
      exit 1
    fi
    curl_args+=(--data-urlencode "$pair")
    echo "  $pair"
  done

  echo ""
  echo "Respuesta (campo 'form'):"
  curl -s "${curl_args[@]}" https://httpbin.org/post | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
form = data.get('form', {})
for k, v in form.items():
    print(f'  {k} = {v}')
"
}

# ─── dispatch ──────────────────────────────────────────────

case "${1:-help}" in
  download)
    shift
    cmd_download "$@"
    ;;
  upload)
    shift
    cmd_upload "$@"
    ;;
  form-post)
    shift
    cmd_form_post "$@"
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    echo "Subcomando desconocido: ${1:-}"
    usage
    exit 1
    ;;
esac
