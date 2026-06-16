# Ejercicio 03: Benchmark de Endpoints con --write-out

## Objetivo

Construir un script de benchmark que mida el tiempo de respuesta de un endpoint HTTP en multiples dimensiones (DNS, TCP, TLS, TTFB, total) y calcule estadisticas sobre N ejecuciones.

**Duracion estimada:** 60 minutos

## Prerequisitos

- curl con soporte HTTP/2 (verificado en ejercicio 01)
- `jq` y `awk` instalados
- Completado el ejercicio 02

---

## Tarea 1: Template de timing completo

Ejecutar este comando contra tres URLs distintas y anotar los resultados en `respuestas.md`:

```bash
curl -s -o /dev/null -w "
     DNS: %{time_namelookup}s
     TCP: %{time_connect}s
     TLS: %{time_appconnect}s
    TTFB: %{time_starttransfer}s
   Total: %{time_total}s
  Status: %{http_code}
    Size: %{size_download} bytes
 Version: %{http_version}
" https://api.github.com/users/octocat
```

URLs a probar:
- `https://api.github.com/users/octocat`
- `https://jsonplaceholder.typicode.com/posts/1`
- `https://httpbin.org/get`

Observar: cual tiene el DNS mas alto? Cual tiene el TLS mas alto? Por que?

---

## Tarea 2: Script perf.sh

Crear el script `perf.sh` con la siguiente funcionalidad:

1. Acepta una URL como primer argumento
2. Hace 10 requests a esa URL
3. Captura `time_total` de cada uno
4. Calcula y muestra: minimo, maximo, promedio
5. Muestra el desglose DNS/TCP/TLS/TTFB del primer request

```bash
#!/bin/bash
# perf.sh — benchmark simple de un endpoint HTTP

set -euo pipefail

URL="${1:-}"
if [[ -z "$URL" ]]; then
  echo "Uso: $0 URL" >&2
  echo "Ejemplo: $0 https://api.github.com/users/octocat" >&2
  exit 1
fi

N="${2:-10}"  # numero de requests, default 10

echo "=== Benchmark: $URL ($N requests) ==="
echo ""

# Desglose del primer request
echo "--- Desglose primer request ---"
curl -s -o /dev/null -w "  DNS: %{time_namelookup}s\n  TCP: %{time_connect}s\n  TLS: %{time_appconnect}s\n TTFB: %{time_starttransfer}s\nTotal: %{time_total}s\n" "$URL"
echo ""

# N requests para estadisticas
echo "--- ${N} requests (time_total) ---"
times=()
for i in $(seq 1 "$N"); do
  t=$(curl -s -o /dev/null -w "%{time_total}" "$URL")
  printf "  request %2d: %ss\n" "$i" "$t"
  times+=("$t")
done

echo ""
echo "--- Estadisticas ---"
printf '%s\n' "${times[@]}" | awk '
{
  sum += $1
  if (NR == 1 || $1 < min) min = $1
  if ($1 > max) max = $1
}
END {
  printf "  min: %.3fs\n  max: %.3fs\n  avg: %.3fs\n", min, max, sum/NR
}'
```

Guardar como `perf.sh`, darle permisos de ejecucion con `chmod +x perf.sh` y probarlo.

---

## Tarea 3: Ejecutar contra 3 URLs

```bash
bash perf.sh https://api.github.com/users/octocat
bash perf.sh https://jsonplaceholder.typicode.com/posts/1
bash perf.sh https://httpbin.org/get
```

Registrar los resultados en `respuestas.md` con la siguiente tabla:

| URL | DNS (1er) | TLS (1er) | TTFB (1er) | avg total |
|-----|-----------|-----------|------------|-----------|
| api.github.com | ? | ? | ? | ? |
| jsonplaceholder | ? | ? | ? | ? |
| httpbin.org | ? | ? | ? | ? |

---

## Tarea 4: Comparar 1er request vs subsiguientes

Observar si el primer request es significativamente mas lento que los siguientes. Esto ocurre porque:
- El DNS no esta en cache la primera vez
- La sesion TLS se negocia desde cero
- El servidor puede estar "cold"

En `respuestas.md`, responder:
- Cual fue la diferencia entre el request 1 y el promedio de los requests 2-10?
- Tiene sentido excluir el primer request de los calculos de benchmark? Por que?

Bonus: modificar `perf.sh` para mostrar el promedio excluyendo el primer request ("warmup").

---

## Tarea 5: Diagnosticar un endpoint lento

Usar el endpoint de delay de httpbin para simular un servidor lento y analizar el desglose:

```bash
# Endpoint que tarda 2 segundos en responder
curl -s -o /dev/null -w "
  DNS: %{time_namelookup}s
  TCP: %{time_connect}s
  TLS: %{time_appconnect}s
 TTFB: %{time_starttransfer}s
Total: %{time_total}s
" https://httpbin.org/delay/2
```

En `respuestas.md`, identificar: en que variable se refleja el delay del servidor? DNS? TCP? TTFB? Total? Por que?

---

## Entrega

Archivos a crear en esta carpeta:

- `perf.sh` — script de la Tarea 2 (debe funcionar con `bash perf.sh URL`)
- `respuestas.md` — resultados de Tareas 1, 3, 4 y 5

## Referencia

```
-w "%{time_total}"      tiempo total en segundos
-w "%{time_namelookup}" DNS
-w "%{time_connect}"    TCP handshake
-w "%{time_appconnect}" TLS handshake
-w "%{time_starttransfer}" TTFB
-o /dev/null            descartar body de respuesta
```
