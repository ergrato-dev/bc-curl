# Ejercicio 1: Extraccion de metricas con --write-out

## Objetivo

Extraer metricas de rendimiento de multiples URLs y construir una tabla comparativa
para identificar los endpoints mas lentos y los mas rapidos.

## URLs a evaluar

```
https://jsonplaceholder.typicode.com/posts/1
https://jsonplaceholder.typicode.com/users
https://jsonplaceholder.typicode.com/comments?postId=1
https://httpbin.org/get
https://httpbin.org/delay/1
```

## Parte 1: extraccion basica (un URL a la vez)

Ejecuta el siguiente comando para cada URL de la lista:

```bash
curl -s -o /dev/null \
  -w "URL: %{url_effective}\nStatus: %{http_code}\nTiempo total: %{time_total}s\nTTFB: %{time_starttransfer}s\nTamano body: %{size_download} bytes\n---\n" \
  "https://jsonplaceholder.typicode.com/posts/1"
```

Anota los resultados.

## Parte 2: tabla automatizada

Crea un script `medir.sh` que itere sobre todas las URLs y produzca una tabla:

```bash
#!/bin/bash
set -euo pipefail

URLS=(
    "https://jsonplaceholder.typicode.com/posts/1"
    "https://jsonplaceholder.typicode.com/users"
    "https://jsonplaceholder.typicode.com/comments?postId=1"
    "https://httpbin.org/get"
    "https://httpbin.org/delay/1"
)

FORMAT="%{http_code} %{time_total} %{time_starttransfer} %{size_download}"

printf "%-45s  %s  %-10s  %-10s  %s\n" \
    "URL" "COD" "TOTAL(s)" "TTFB(s)" "SIZE(b)"
printf "%-45s  %s  %-10s  %-10s  %s\n" \
    "---" "---" "--------" "-------" "-------"

for url in "${URLS[@]}"; do
    RESULT=$(curl -sS -o /dev/null --max-time 15 -w "$FORMAT" "$url")
    CODE=$(echo "$RESULT" | awk '{print $1}')
    TOTAL=$(echo "$RESULT" | awk '{print $2}')
    TTFB=$(echo "$RESULT" | awk '{print $3}')
    SIZE=$(echo "$RESULT" | awk '{print $4}')

    # Mostrar solo los ultimos 44 chars de la URL si es muy larga
    SHORT_URL="${url: -44}"
    printf "%-45s  %s  %-10s  %-10s  %s\n" \
        "$SHORT_URL" "$CODE" "$TOTAL" "$TTFB" "$SIZE"
done
```

Guarda el output en `tabla.txt`:
```bash
chmod +x medir.sh
./medir.sh | tee tabla.txt
```

## Parte 3: preguntas de analisis

Responde en `respuestas.md`:

1. Cual fue la URL con mayor `time_total`? Que la hace diferente del resto?
2. Cual fue la diferencia entre `time_total` y `time_starttransfer` (TTFB) en
   `https://jsonplaceholder.typicode.com/users`? A que se debe esa diferencia?
3. El endpoint `/delay/1` tuvo un TTFB de aproximadamente 1 segundo. Por que?
   Como se diferencian `time_starttransfer` y `time_total` en ese endpoint?
4. `size_download` para `/users` es mucho mayor que para `/posts/1`. Cuanto
   mayor, en porcentaje?

## Desafio opcional

Modifica el script para hacer **3 requests a cada URL** y mostrar el **promedio**
del `time_total`. Pista: acumula los tiempos en una variable y divide con `awk`:

```bash
awk "BEGIN {printf \"%.6f\", ($T1 + $T2 + $T3) / 3}"
```

## Entregables

- `medir.sh`: el script
- `tabla.txt`: output capturado
- `respuestas.md`: respuestas a las preguntas
