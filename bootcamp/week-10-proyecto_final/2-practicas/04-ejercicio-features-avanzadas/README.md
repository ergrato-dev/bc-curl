# Stage 4: Features Avanzadas

**Tiempo estimado:** 60 minutos
**Objetivo:** Implementar monitor, bench, y mejoras de UX

---

## Objetivo

Agregar los subcomandos avanzados `monitor` y `bench` a `api-toolkit.sh`. Implementar mejoras de experiencia de usuario: colores en output, spinner de progreso, y `init` interactivo.

---

## Tarea 1: `monitor`

Verifica una lista de endpoints desde un archivo:

```bash
cmd_monitor() {
  local urls_file="${1:?Error: especificá archivo de URLs}"
  [ -f "$urls_file" ] || { error "Archivo no encontrado: $urls_file"; return 1; }

  local ok=0 warn=0 err=0

  echo "API Monitor — $(date)"
  echo "=============================="
  echo ""

  while IFS= read -r url; do
    [ -z "$url" ] && continue
    [[ "$url" == \#* ]] && continue

    local http_code time_total
    read -r http_code time_total < <(
      curl -sS -o /dev/null -L \
        --max-time 10 --connect-timeout 5 \
        -w "%{http_code} %{time_total}" \
        "$url" 2>/dev/null || echo "000 0.000"
    )

    if [ "$http_code" -ge 500 ] || [ "$http_code" -ge 400 ] || [ "$http_code" = "000" ]; then
      printf "[ERROR] %s  %ss  %s\n" "$http_code" "$time_total" "$url"
      err=$((err + 1))
    elif [ "$http_code" -ge 300 ] || awk "BEGIN{exit !($time_total > 1.0)}"; then
      printf "[WARN ] %s  %ss  %s\n" "$http_code" "$time_total" "$url"
      warn=$((warn + 1))
    else
      printf "[OK   ] %s  %ss  %s\n" "$http_code" "$time_total" "$url"
      ok=$((ok + 1))
    fi
  done < "$urls_file"

  echo ""
  echo "Resumen: OK=$ok WARN=$warn ERROR=$err"
}
```

---

## Tarea 2: `bench`

Ejecuta N requests a un endpoint y calcula estadísticas:

```bash
cmd_bench() {
  local url="${1:?Error: especificá URL}"
  local n="${2:-10}"

  echo "Benchmark: $url ($n requests)"
  echo "=============================="

  local times=()
  local errors=0

  for i in $(seq 1 "$n"); do
    local http_code time_total
    read -r http_code time_total < <(
      curl -sS -o /dev/null \
        --max-time 30 --connect-timeout 5 \
        -w "%{http_code} %{time_total}" \
        "$url" 2>/dev/null || echo "000 0"
    )

    if [ "$http_code" -ge 400 ] || [ "$http_code" = "000" ]; then
      errors=$((errors + 1))
      printf "  [%2d] ERROR %s\n" "$i" "$http_code"
    else
      times+=("$time_total")
      printf "  [%2d] %s  %ss\n" "$i" "$http_code" "$time_total"
    fi
  done

  echo ""
  echo "Resultados:"
  echo "  Requests: $n | Errores: $errors"

  if [ ${#times[@]} -gt 0 ]; then
    printf '%s\n' "${times[@]}" | sort -n | awk '
    { vals[NR] = $1; sum += $1 }
    END {
      n = NR
      if (n == 0) exit
      p50 = vals[int(n * 0.50) + 1]
      p90 = vals[int(n * 0.90) + 1]
      p99 = vals[int(n * 0.99) + 1]
      printf "  Min:  %.4fs\n", vals[1]
      printf "  Avg:  %.4fs\n", sum / n
      printf "  Max:  %.4fs\n", vals[n]
      printf "  p50:  %.4fs\n", p50
      printf "  p90:  %.4fs\n", p90
      printf "  p99:  %.4fs\n", p99
    }'
  fi
}
```

---

## Tarea 3: Colores y spinner

Agrega helpers de UX:

```bash
# Colores
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*" >&2; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# Spinner simple para operaciones largas
spinner() {
  local pid=$1
  local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  while kill -0 "$pid" 2>/dev/null; do
    for ((i=0; i<${#chars}; i++)); do
      printf "\r  %s Cargando..." "${chars:$i:1}" >&2
      sleep 0.1
    done
  done
  printf "\r" >&2
}
```

---

## Tarea 4: `init` interactivo

```bash
cmd_init() {
  echo "=== Configuración inicial de api-toolkit ==="
  echo ""

  read -rp "URL base de la API [https://jsonplaceholder.typicode.com]: " BASE_URL
  BASE_URL="${BASE_URL:-https://jsonplaceholder.typicode.com}"

  read -rp "Token URL (OAuth2) [https://httpbin.org/post]: " TOKEN_URL
  TOKEN_URL="${TOKEN_URL:-https://httpbin.org/post}"

  read -rp "Client ID: " CLIENT_ID
  read -rsp "Client Secret: " CLIENT_SECRET
  echo ""

  read -rp "Timeout en segundos [30]: " TIMEOUT
  TIMEOUT="${TIMEOUT:-30}"

  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR"

  cat > "$CONFIG_DIR/config" <<EOF
BASE_URL=$BASE_URL
TOKEN_URL=$TOKEN_URL
CLIENT_ID=$CLIENT_ID
CLIENT_SECRET=$CLIENT_SECRET
TIMEOUT=$TIMEOUT
CONNECT_TIMEOUT=10
EOF

  chmod 600 "$CONFIG_DIR/config"
  info "Configuración guardada en $CONFIG_DIR/config"
}
```

---

## Tarea 5: Log rotation

```bash
rotate_log_if_needed() {
  local log_file="$CONFIG_DIR/requests.log"
  local max_size=$((1024 * 1024))  # 1MB

  if [ -f "$log_file" ] && [ "$(stat -c%s "$log_file" 2>/dev/null || stat -f%z "$log_file" 2>/dev/null)" -gt "$max_size" ]; then
    mv "$log_file" "${log_file}.1"
    info "Log rotado (superaba 1MB)"
  fi
}
```

---

## Verificación

```bash
# 1. Monitor
cat > /tmp/test-urls.txt <<EOF
https://jsonplaceholder.typicode.com/posts/1
https://httpbin.org/get
https://httpbin.org/status/404
EOF
./api-toolkit.sh monitor /tmp/test-urls.txt

# 2. Bench
./api-toolkit.sh bench https://jsonplaceholder.typicode.com/posts/1 5

# 3. Init
./api-toolkit.sh init

# 4. Probar colores (info vs error)
./api-toolkit.sh get /posts/99999   # debe mostrar ERROR en rojo

# 5. Verificar log rotation
ls -la ~/.api-toolkit/requests.log*
```

---

## Entregables

- Subcomandos `monitor` y `bench` funcionales en `api-toolkit.sh`
- `init` interactivo funcional
- Colores en output y/o spinner
- `respuestas.md` con:
  - Cómo calculás p50, p90, p99 en el benchmark
  - Qué criterios usás para clasificar OK/WARN/ERROR en monitor
  - Por qué `init` usa `read -rsp` para el secret
  - Cómo funciona la rotación de logs
