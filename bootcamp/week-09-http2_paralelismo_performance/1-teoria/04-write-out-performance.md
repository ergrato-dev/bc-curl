# Write-Out: Profiling de Performance

## Variables de Tiempo en --write-out

La opcion `--write-out` (o `-w`) permite imprimir variables internas de curl al finalizar un request. Las variables de tiempo miden cada fase del ciclo de vida del request.

### Las Fases y Sus Variables

```
Inicio de request
     |
     v
[DNS lookup]           → time_namelookup
     |
     v
[TCP connect]          → time_connect
     |
     v
[TLS handshake]        → time_appconnect
     |
     v
[Preparacion]          → time_pretransfer
     |
     v
[Espera respuesta]     |
     |                 |
     v                 |
[Primer byte]          → time_starttransfer  (TTFB)
     |
     v
[Descarga body]
     |
     v
[Request completo]     → time_total
```

Todas las variables miden tiempo en **segundos desde el inicio del request**.

---

## Uso Basico

```bash
curl -s -w "\nTiempo total: %{time_total}s\n" -o /dev/null https://httpbin.org/get
```

### Template de Profiling Completo

```bash
TIME_FORMAT='\n
DNS lookup:    %{time_namelookup}s
TCP connect:   %{time_connect}s
TLS handshake: %{time_appconnect}s
Pre-transfer:  %{time_pretransfer}s
TTFB:          %{time_starttransfer}s
Total:         %{time_total}s
-
HTTP status:   %{http_code}
IP:            %{remote_ip}:%{remote_port}
Size:          %{size_download} bytes
Speed:         %{speed_download} bytes/s
'

curl -s -w "$TIME_FORMAT" -o /dev/null https://httpbin.org/get
```

---

## Calcular Tiempos Incrementales

Las variables miden tiempo acumulado desde el inicio, no duracion de cada fase. Para saber cuanto duro cada fase se restan:

```bash
curl -s -o /dev/null -w '%{time_namelookup} %{time_connect} %{time_appconnect} %{time_pretransfer} %{time_starttransfer} %{time_total}' \
  https://httpbin.org/get | \
  awk '{
    dns=$1
    tcp=$2-$1
    tls=$3-$2
    pre=$4-$3
    wait=$5-$4
    dl=$6-$5
    printf "DNS:      %.3fs\nTCP:      %.3fs\nTLS:      %.3fs\nPre:      %.3fs\nWait:     %.3fs\nDownload: %.3fs\nTotal:    %.3fs\n", dns, tcp, tls, pre, wait, dl, $6
  }'
```

---

## Otras Variables Utiles

| Variable | Descripcion |
|----------|-------------|
| `%{http_code}` | Codigo de estado HTTP (200, 404, etc.) |
| `%{remote_ip}` | IP del servidor al que se conecto |
| `%{remote_port}` | Puerto del servidor |
| `%{num_connects}` | Numero de conexiones TCP nuevas abiertas |
| `%{num_redirects}` | Numero de redirects seguidos |
| `%{size_download}` | Bytes descargados en el body |
| `%{size_header}` | Bytes de headers recibidos |
| `%{speed_download}` | Velocidad de descarga en bytes/segundo |
| `%{ssl_verify_result}` | Resultado de la verificacion SSL (0 = ok) |
| `%{url_effective}` | URL final (despues de redirects) |
| `%{content_type}` | Content-Type de la respuesta |

Ver la lista completa: `man curl` buscar "VARIABLES".

---

## Script de Benchmark Simple

```bash
#!/bin/bash
# bench.sh <URL> [repeticiones]

URL="${1:-https://httpbin.org/get}"
N="${2:-10}"

echo "Benchmarking: $URL ($N requests)"
echo "---"

TIMES=()
ERRORS=0

for i in $(seq 1 "$N"); do
  result=$(curl -s -o /dev/null \
    -w '%{http_code} %{time_total} %{time_starttransfer}' \
    --connect-timeout 10 \
    --max-time 30 \
    "$URL")
  
  http_code=$(echo "$result" | awk '{print $1}')
  total=$(echo "$result" | awk '{print $2}')
  ttfb=$(echo "$result" | awk '{print $3}')
  
  if [[ "$http_code" != 2* ]]; then
    ERRORS=$(( ERRORS + 1 ))
  fi
  
  TIMES+=("$total")
  printf "Request %2d: %s  total=%.3fs  ttfb=%.3fs\n" "$i" "$http_code" "$total" "$ttfb"
done

echo "---"
echo "Total requests: $N"
echo "Errores (non-2xx): $ERRORS"
echo ""

# Calcular estadísticas con awk
printf '%s\n' "${TIMES[@]}" | awk '
{
  times[NR] = $1
  sum += $1
  if (NR == 1 || $1 < min) min = $1
  if ($1 > max) max = $1
}
END {
  avg = sum / NR
  # Ordenar para percentiles (bubble sort simple)
  n = asort(times)
  p50 = times[int(n * 0.50)]
  p90 = times[int(n * 0.90)]
  p99 = times[int(n * 0.99 + 0.5)]
  printf "Min:  %.3fs\n", min
  printf "Max:  %.3fs\n", max
  printf "Avg:  %.3fs\n", avg
  printf "p50:  %.3fs\n", p50
  printf "p90:  %.3fs\n", p90
  printf "p99:  %.3fs\n", p99
}'
```

---

## Que Buscar en los Resultados

### DNS lento (`time_namelookup` alto)

Causa: resolver DNS tarda. Soluciones: usar `--resolve` para saltear DNS, cambiar el servidor DNS, o usar `--dns-servers` en sistemas compatibles.

```bash
# Forzar IP directamente (evitar DNS lookup)
curl -s --resolve httpbin.org:443:34.237.56.30 https://httpbin.org/get
```

### TLS lento (`time_appconnect - time_connect` alto)

Causa: negociacion TLS cara. Puede mejorar con session resumption (automatico en curl para requests subsiguientes al mismo servidor).

### TTFB alto (`time_starttransfer - time_pretransfer` alto)

Causa: el servidor tarda en procesar la request y enviar el primer byte. Esto es tiempo de procesamiento del servidor — no hay mucho que hacer desde el cliente salvo cambiar el servidor.

### Download lento (`time_total - time_starttransfer` alto)

Causa: body grande o ancho de banda limitado. Verificar el tamaño de la respuesta con `%{size_download}`.
