#!/usr/bin/env bash
# auth-check.sh — Prueba los 3 mecanismos de autenticación y reporta resultados
# Uso: source .env && ./auth-check.sh [--verbose] [--wrong]
#
# Variables de entorno requeridas:
#   BASIC_USER, BASIC_PASS — credenciales para Basic Auth
#   API_KEY                — API Key para header
#   BEARER_TOKEN           — Bearer token

set -euo pipefail

VERBOSE=false
TEST_WRONG=false
PASSED=0
TOTAL=0
REPORT_FILE="auth-report.txt"

# ─── parse args ────────────────────────────────────────────

for arg in "$@"; do
  case "$arg" in
    --verbose) VERBOSE=true ;;
    --wrong)   TEST_WRONG=true ;;
  esac
done

# ─── helpers ───────────────────────────────────────────────

check_vars() {
  local missing=0
  for var in BASIC_USER BASIC_PASS API_KEY BEARER_TOKEN; do
    if [ -z "${!var:-}" ]; then
      echo "Error: variable de entorno $var no definida"
      missing=1
    fi
  done
  if [ "$missing" -eq 1 ]; then
    echo ""
    echo "Cargá las variables con: source .env"
    exit 1
  fi
}

print_result() {
  local test_name="$1"
  local status="$2"
  local expected="$3"
  TOTAL=$((TOTAL + 1))
  local result="OK"
  local color="\033[32m"
  if [ "$status" != "$expected" ]; then
    result="FALLO"
    color="\033[31m"
  else
    PASSED=$((PASSED + 1))
  fi
  printf "  ${color}%-50s Status: %-6s %s\033[0m\n" "$test_name" "$status" "$result"
}

hide_token() {
  local val="$1"
  if [ ${#val} -le 12 ]; then
    echo "${val:0:6}****"
  else
    echo "${val:0:6}...${val: -6}"
  fi
}

# ─── main ──────────────────────────────────────────────────

echo ""
echo "============================================"
echo "  AUTH EXPLORER — Semana 3"
echo "============================================"
echo ""
echo "Credenciales detectadas:"
echo "  BASIC_USER    = ${BASIC_USER}"
echo "  BASIC_PASS   = ****"
echo "  API_KEY       = $(hide_token "$API_KEY")"
echo "  BEARER_TOKEN  = $(hide_token "$BEARER_TOKEN")"
echo ""

check_vars

# ── Test 1: Basic Auth ─────────────────────────────────────
echo "── 1. HTTP Basic Auth ───────────────────────"
echo ""

BASIC_URL="https://httpbin.org/basic-auth/${BASIC_USER}/${BASIC_PASS}"
if $VERBOSE; then
  echo "  URL: $BASIC_URL"
fi

# Correct
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -u "${BASIC_USER}:${BASIC_PASS}" "$BASIC_URL")
print_result "Basic Auth correcto" "$STATUS" "200"

# No credentials
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASIC_URL")
print_result "Basic Auth sin credenciales (esperado 401)" "$STATUS" "401"

if $TEST_WRONG; then
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -u "wrong:wrong" "$BASIC_URL")
  print_result "Basic Auth credenciales incorrectas" "$STATUS" "401"
fi

echo ""

# ── Test 2: API Key ────────────────────────────────────────
echo "── 2. API Key ────────────────────────────────"
echo ""

API_URL="https://httpbin.org/get"

# In header (correct)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "X-API-Key: $API_KEY" "$API_URL")
print_result "API Key en header" "$STATUS" "200"

# In query string (discouraged)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${API_URL}?api_key=${API_KEY}")
print_result "API Key en query string (desaconsejado)" "$STATUS" "200"

# Verify httpbin reflects the key
if $VERBOSE; then
  echo ""
  echo "  httpbin refleja el header:"
  curl -s -H "X-API-Key: $API_KEY" "$API_URL" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'    X-Api-Key: {d[\"headers\"].get(\"X-Api-Key\",\"NO ENVIADO\")}')"
fi

echo ""

# ── Test 3: Bearer Token ───────────────────────────────────
echo "── 3. Bearer Token ───────────────────────────"
echo ""

BEARER_URL="https://httpbin.org/bearer"

# Correct token
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $BEARER_TOKEN" "$BEARER_URL")
print_result "Bearer Token correcto" "$STATUS" "200"

# No token
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BEARER_URL")
print_result "Bearer Token sin header (esperado 401)" "$STATUS" "401"

# Wrong token
if $TEST_WRONG; then
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer token_falso_12345" "$BEARER_URL")
  print_result "Bearer Token inválido" "$STATUS" "401"
fi

echo ""

# ── Summary ────────────────────────────────────────────────
echo "============================================"
printf "  RESULTADO: %d/%d pruebas exitosas\n" "$PASSED" "$TOTAL"
echo "============================================"
echo ""

# Generate report file
{
  echo "Auth Explorer Report — $(date)"
  echo "Resultado: ${PASSED}/${TOTAL} pruebas exitosas"
} > "$REPORT_FILE"
echo "Reporte guardado en $REPORT_FILE"

# Return exit code
[ "$PASSED" -eq "$TOTAL" ]
