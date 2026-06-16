# Ejercicio 4: Script de Benchmark

## Objetivo

Crear un script `benchmark.sh` que haga multiples requests al mismo endpoint y
calcule estadisticas de tiempo de respuesta: promedio, minimo y maximo.

## El script a construir

El script debe:
1. Aceptar la URL como argumento
2. Hacer N requests (10 por defecto)
3. Extraer el tiempo total de cada request con `--write-out`
4. Calcular minimo, maximo y promedio
5. Mostrar el resultado de forma legible

## Version 1: esqueleto basico

Crea `benchmark.sh`:

```bash
#!/bin/bash
set -euo pipefail

URL="${1:?Uso: $0 <URL> [N_REQUESTS]}"
N="${2:-10}"

echo "Benchmarking: $URL"
echo "Requests: $N"
echo ""

TIEMPOS=()

for i in $(seq 1 "$N"); do
    TIEMPO=$(curl -sS -o /dev/null \
                  --max-time 30 \
                  -w "%{time_total}" \
                  "$URL")
    TIEMPOS+=("$TIEMPO")
    echo "  Request $i: ${TIEMPO}s"
done

echo ""
echo "--- Resultados ---"

# Calcular estadisticas con awk
printf '%s\n' "${TIEMPOS[@]}" | awk '
BEGIN {
    min = 999999
    max = 0
    suma = 0
    n = 0
}
{
    val = $1 + 0
    suma += val
    n++
    if (val < min) min = val
    if (val > max) max = val
}
END {
    printf "Min:      %.4fs\n", min
    printf "Max:      %.4fs\n", max
    printf "Promedio: %.4fs\n", suma / n
    printf "Total:    %.4fs (%d requests)\n", suma, n
}
'
```

Hazlo ejecutable y pruebalo:

```bash
chmod +x benchmark.sh
./benchmark.sh https://jsonplaceholder.typicode.com/posts/1
```

## Version 2: agregar codigo HTTP y manejo de errores

Modifica el script para que tambien capture el codigo HTTP y marque los requests
fallidos sin detener el benchmark:

```bash
#!/bin/bash
set -uo pipefail

URL="${1:?Uso: $0 <URL> [N_REQUESTS]}"
N="${2:-10}"

echo "Benchmarking: $URL"
echo "Requests: $N"
echo ""

TIEMPOS=()
ERRORES=0

printf "  %-10s %-8s %s\n" "Request" "Status" "Tiempo"
printf "  %-10s %-8s %s\n" "-------" "------" "------"

for i in $(seq 1 "$N"); do
    RESULT=$(curl -sS -o /dev/null \
                  --max-time 30 \
                  -w "%{http_code} %{time_total}" \
                  "$URL" 2>/dev/null) || {
        printf "  %-10s %-8s %s\n" "$i" "ERR" "timeout/red"
        ERRORES=$((ERRORES + 1))
        continue
    }

    CODE=$(echo "$RESULT" | awk '{print $1}')
    TIEMPO=$(echo "$RESULT" | awk '{print $2}')

    TIEMPOS+=("$TIEMPO")
    printf "  %-10s %-8s %s\n" "$i" "$CODE" "${TIEMPO}s"
done

echo ""
echo "--- Resultados ---"
echo "Errores: $ERRORES de $N requests"
echo ""

if [ ${#TIEMPOS[@]} -gt 0 ]; then
    printf '%s\n' "${TIEMPOS[@]}" | awk '
    BEGIN { min = 999999; max = 0; suma = 0; n = 0 }
    { val = $1 + 0; suma += val; n++
      if (val < min) min = val
      if (val > max) max = val }
    END {
        printf "Requests exitosos: %d\n", n
        printf "Min:      %.4fs\n", min
        printf "Max:      %.4fs\n", max
        printf "Promedio: %.4fs\n", suma / n
    }
    '
else
    echo "No hubo requests exitosos."
fi
```

## Pruebas a ejecutar

```bash
# Endpoint rapido
./benchmark.sh https://jsonplaceholder.typicode.com/posts/1 10

# Endpoint que tarda 1 segundo siempre
./benchmark.sh https://httpbin.org/delay/1 5

# Endpoint que falla a veces (genera 500 aleatorio)
./benchmark.sh https://httpbin.org/status/200,500 10
```

Nota: `https://httpbin.org/status/200,500` retorna 200 o 500 de forma aleatoria
(no todos los servidores httpbin lo soportan; si no funciona usa `status/200`).

## Preguntas de analisis

Responde en `respuestas.md`:

1. En el benchmark de `/delay/1`, cual es el minimo esperado y por que?
2. Por que el promedio puede variar entre dos ejecuciones del mismo endpoint?
3. Que informacion adicional incluirias en el reporte para hacerlo mas util?
4. Si quisieras comparar dos URLs distintas, como modificarias el script?

## Desafio: agregar percentil 95

El percentil 95 es una metrica mas robusta que el promedio porque ignora los
outliers. Para calcularlo con awk necesitas ordenar los tiempos:

```bash
printf '%s\n' "${TIEMPOS[@]}" | sort -n | awk '
{
    vals[NR] = $1
}
END {
    n = NR
    idx = int(n * 0.95)
    if (idx < 1) idx = 1
    printf "P95: %.4fs\n", vals[idx]
}
'
```

Integra esto al script final.

## Entregables

- `benchmark.sh`: version final del script
- `output-posts.txt`: resultado del benchmark a `/posts/1`
- `output-delay.txt`: resultado del benchmark a `/delay/1`
- `respuestas.md`: respuestas a las preguntas
