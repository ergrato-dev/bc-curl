#!/usr/bin/env bash
# monitor.sh — API Monitor
# Lee URLs de un archivo, mide tiempo de respuesta, clasifica OK/WARN/ERROR
# Uso: ./monitor.sh urls.txt

set -uo pipefail

URLS_FILE="${1:?Uso: $0 <archivo-de-urls>}"
WARN_TIME_THRESHOLD=1.0

COUNT_OK=0
COUNT_WARN=0
COUNT_ERROR=0
TOTAL=0

# ─── helpers ───────────────────────────────────────────────

read_urls() {
  local file="$1"
  grep -v '^\s*#' "$file" | grep -v '^\s*$'
}

check_url() {
  local url="$1"
  local code time_total

  if ! RESULT=$(curl -sS \
                     -o /dev/null \
                     --max-time 10 \
                     --connect-timeout 5 \
                     -w "%{http_code} %{time_total}" \
                     -L \
                     "$url" 2>/dev/null); then
    printf "[%-5s] %s  %s  %s\n" "ERROR" "000" "0.000s" "$url"
    COUNT_ERROR=$((COUNT_ERROR + 1))
    return
  fi

  code=$(echo "$RESULT" | awk '{print $1}')
  time_total=$(echo "$RESULT" | awk '{print $2}')

  if [[ "$code" -ge 500 ]] || [[ "$code" -ge 400 && "$code" -lt 500 ]]; then
    printf "[%-5s] %s  %ss  %s\n" "ERROR" "$code" "$time_total" "$url"
    COUNT_ERROR=$((COUNT_ERROR + 1))
  elif [[ "$code" -ge 300 ]]; then
    printf "[%-5s] %s  %ss  %s\n" "WARN" "$code" "$time_total" "$url"
    COUNT_WARN=$((COUNT_WARN + 1))
  else
    if awk "BEGIN { exit !($time_total > $WARN_TIME_THRESHOLD) }"; then
      printf "[%-5s] %s  %ss  %s\n" "WARN" "$code" "$time_total" "$url"
      COUNT_WARN=$((COUNT_WARN + 1))
    else
      printf "[%-5s] %s  %ss  %s\n" "OK" "$code" "$time_total" "$url"
      COUNT_OK=$((COUNT_OK + 1))
    fi
  fi
}

# ─── main ──────────────────────────────────────────────────

if [ ! -f "$URLS_FILE" ]; then
  echo "Error: archivo '$URLS_FILE' no encontrado"
  exit 1
fi

TOTAL=$(read_urls "$URLS_FILE" | wc -l)

echo "API Monitor — $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
echo ""
echo "Chequeando $TOTAL URLs..."
echo ""

while IFS= read -r url; do
  check_url "$url"
done < <(read_urls "$URLS_FILE")

echo ""
echo "============================================"
echo "Resumen:"
echo "  OK:    $COUNT_OK"
echo "  WARN:  $COUNT_WARN"
echo "  ERROR: $COUNT_ERROR"
echo "  Total: $TOTAL"
echo ""

if [ "$COUNT_ERROR" -gt 0 ]; then
  echo "Estado general: ERROR"
  exit 1
elif [ "$COUNT_WARN" -gt 0 ]; then
  echo "Estado general: DEGRADADO"
else
  echo "Estado general: OK"
fi
