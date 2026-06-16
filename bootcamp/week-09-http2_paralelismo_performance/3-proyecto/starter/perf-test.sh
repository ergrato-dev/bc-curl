#!/bin/bash
# perf-test.sh — Performance tester de endpoints HTTP
# Uso: bash perf-test.sh [--times N] [--max-parallel N] [--csv FILE] endpoints.txt

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
TIMES=5
MAX_PARALLEL=3
CSV_FILE=""
ENDPOINTS_FILE=""

# ---------------------------------------------------------------------------
# Parsear argumentos
# ---------------------------------------------------------------------------
usage() {
  echo "Uso: $0 [--times N] [--max-parallel N] [--csv FILE] endpoints.txt" >&2
  echo "" >&2
  echo "  --times N          Numero de requests por endpoint (default: 5)" >&2
  echo "  --max-parallel N   Maximo de requests simultaneos (default: 3)" >&2
  echo "  --csv FILE         Exportar resultados a FILE en formato CSV" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --times)        TIMES="$2"; shift 2 ;;
    --max-parallel) MAX_PARALLEL="$2"; shift 2 ;;
    --csv)          CSV_FILE="$2"; shift 2 ;;
    *.txt|*)
      if [[ -f "$1" ]]; then
        ENDPOINTS_FILE="$1"
        shift
      else
        echo "ERROR: Archivo no encontrado: $1" >&2
        usage
      fi
      ;;
  esac
done

[[ -z "$ENDPOINTS_FILE" ]] && usage

# ---------------------------------------------------------------------------
# Funciones de calculo
# ---------------------------------------------------------------------------

# Medir un endpoint N veces y retornar lineas "time_total http_code"
# Uso: measure_url URL N MAX_PARALLEL
measure_url() {
  local url="$1"
  local times="$2"
  local max_par="$3"

  # TODO: construir lista de argumentos para curl --parallel
  # Cada request debe capturar time_total y http_code con --write-out
  # Guardar resultados en archivos temporales para procesar despues

  local tmpdir
  tmpdir=$(mktemp -d)
  local args=()

  for i in $(seq 1 "$times"); do
    # TODO: agregar a args los flags para guardar en "${tmpdir}/${i}.out"
    # Hint: -o /dev/null -w "%{time_total} %{http_code}\n" -o "${tmpdir}/${i}.out" URL
    # Nota: -o /dev/null descarta el body; el write-out captura las metricas
    args+=()  # reemplazar esta linea con los args reales
  done

  # TODO: ejecutar curl con --parallel --parallel-max y "${args[@]}"
  # Manejar el caso de fallo de conexion (|| true para no abortar el script)
  # Ejemplo: curl --parallel --parallel-max "$max_par" -s "${args[@]}" || true

  # Leer resultados y emitir "time http_code" por linea
  for i in $(seq 1 "$times"); do
    local outfile="${tmpdir}/${i}.out"
    if [[ -f "$outfile" ]]; then
      cat "$outfile"
    else
      echo "0 000"  # request fallido o archivo no creado
    fi
  done

  rm -rf "$tmpdir"
}

# Calcular estadisticas de un endpoint dado sus mediciones
# Entrada: lineas "time_total http_code" en stdin
# Salida: "p50 p90 p99 errors/total"
calc_stats() {
  local total="$1"
  awk -v total="$total" '
    {
      time = $1
      code = $2
      times[NR] = time
      if (code >= 400 || code == "000") errors++
    }
    END {
      n = NR
      # Ordenar tiempos (insertion sort)
      for (i = 2; i <= n; i++) {
        key = times[i]
        j = i - 1
        while (j >= 1 && times[j] > key) {
          times[j+1] = times[j]
          j--
        }
        times[j+1] = key
      }

      # Calcular indices de percentiles
      p50_idx = int(n * 0.50); if (p50_idx < 1) p50_idx = 1
      p90_idx = int(n * 0.90); if (p90_idx < 1) p90_idx = 1
      p99_idx = int(n * 0.99 + 0.5); if (p99_idx > n) p99_idx = n

      printf "%.3f %.3f %.3f %d/%d\n",
        times[p50_idx], times[p90_idx], times[p99_idx],
        errors+0, total
    }
  '
}

# ---------------------------------------------------------------------------
# CSV helpers
# ---------------------------------------------------------------------------

init_csv() {
  [[ -z "$CSV_FILE" ]] && return
  echo "url,p50,p90,p99,errors,total" > "$CSV_FILE"
}

write_csv_row() {
  [[ -z "$CSV_FILE" ]] && return
  local url="$1" p50="$2" p90="$3" p99="$4" err_ratio="$5"
  echo "${url},${p50},${p90},${p99},${err_ratio}" >> "$CSV_FILE"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  echo "=== Performance Test: ${TIMES} requests por endpoint ==="
  echo ""
  printf "%-52s %8s %8s %8s %10s\n" "URL" "p50(s)" "p90(s)" "p99(s)" "errors"
  printf '%0.s-' {1..90}; echo ""

  init_csv

  # Guardar resultados para el ranking final
  local ranking_file
  ranking_file=$(mktemp)

  # Leer endpoints del archivo (ignorar comentarios y lineas vacias)
  while IFS= read -r url; do
    [[ -z "$url" || "$url" == \#* ]] && continue

    # TODO: llamar measure_url y calc_stats
    # Hint:
    #   measurements=$(measure_url "$url" "$TIMES" "$MAX_PARALLEL")
    #   stats=$(printf '%s\n' "$measurements" | calc_stats "$TIMES")
    #   p50=$(printf '%s\n' "$stats" | awk '{print $1}')
    #   p90=$(printf '%s\n' "$stats" | awk '{print $2}')
    #   p99=$(printf '%s\n' "$stats" | awk '{print $3}')
    #   err_ratio=$(printf '%s\n' "$stats" | awk '{print $4}')

    # Placeholder — reemplazar con implementacion real
    local p50="0.000" p90="0.000" p99="0.000" err_ratio="0/${TIMES}"

    printf "%-52s %8s %8s %8s %10s\n" "$url" "$p50" "$p90" "$p99" "$err_ratio"
    write_csv_row "$url" "$p50" "$p90" "$p99" "$err_ratio"
    echo "$p50 $url" >> "$ranking_file"

  done < "$ENDPOINTS_FILE"

  # Ranking final ordenado por p50
  echo ""
  echo "=== Ranking (mas rapido a mas lento por p50) ==="
  local rank=1
  while IFS=' ' read -r p50 url; do
    printf "%2d. %-50s %ss\n" "$rank" "$url" "$p50"
    (( rank++ ))
  done < <(sort -n "$ranking_file")

  rm -f "$ranking_file"

  if [[ -n "$CSV_FILE" ]]; then
    echo ""
    echo "Resultados exportados a: ${CSV_FILE}"
  fi
}

main
