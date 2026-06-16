# Loops, Iteracion y Paginacion

## Iterar sobre una lista de IDs

El caso mas simple: tienes una lista de IDs y quieres hacer un request por cada uno.

```bash
#!/bin/bash
BASE_URL="https://jsonplaceholder.typicode.com"

for id in 1 2 3 4 5; do
    echo "--- Post $id ---"
    curl -s "$BASE_URL/posts/$id" | jq -r '.title'
done
```

Con un array bash:

```bash
IDS=(1 5 10 42 100)

for id in "${IDS[@]}"; do
    RESULTADO=$(curl -s "$BASE_URL/posts/$id")
    if echo "$RESULTADO" | jq -e '.id' > /dev/null 2>&1; then
        TITLE=$(echo "$RESULTADO" | jq -r '.title')
        echo "Post $id: $TITLE"
    else
        echo "Post $id: no encontrado"
    fi
done
```

## Iterar sobre un archivo de URLs o IDs

```bash
# ids.txt contiene un ID por linea
while IFS= read -r id; do
    [ -z "$id" ] && continue        # saltar lineas vacias
    [[ "$id" == \#* ]] && continue  # saltar comentarios

    RESULTADO=$(curl -s "$BASE_URL/users/$id")
    echo "$id: $(echo "$RESULTADO" | jq -r '.name // "no encontrado"')"
done < ids.txt
```

`jq -r '.name // "no encontrado"'` usa el operador `//` de jq (alternative
operator): si `.name` es null, retorna el string de la derecha.

## Paginacion: loop while hasta agotar paginas

Muchas APIs retornan datos paginados. El patron tipico es:
- La respuesta incluye un campo `next` con la URL de la siguiente pagina
- Cuando `next` es `null` o no existe, llegamos a la ultima pagina

```bash
#!/bin/bash
set -uo pipefail

# Ejemplo con una API paginada hipotetica
# (jsonplaceholder no pagina, pero la logica aplica)

PAGE=1
LIMIT=10
TODOS_LOS_POSTS=()

while true; do
    URL="https://jsonplaceholder.typicode.com/posts?_page=${PAGE}&_limit=${LIMIT}"

    RESPUESTA=$(curl -sS --max-time 15 "$URL")
    if [ $? -ne 0 ]; then
        echo "Error de red en pagina $PAGE" >&2
        break
    fi

    # Verificar si la pagina tiene datos
    COUNT=$(echo "$RESPUESTA" | jq 'length')
    if [ "$COUNT" -eq 0 ]; then
        echo "Pagina $PAGE vacia, terminando"
        break
    fi

    echo "Pagina $PAGE: $COUNT elementos"

    # Procesar cada elemento de la pagina
    while IFS= read -r titulo; do
        TODOS_LOS_POSTS+=("$titulo")
    done < <(echo "$RESPUESTA" | jq -r '.[].title')

    PAGE=$((PAGE + 1))

    # Seguro de fuga del loop
    if [ "$PAGE" -gt 50 ]; then
        echo "Limite de 50 paginas alcanzado" >&2
        break
    fi
done

echo ""
echo "Total posts recolectados: ${#TODOS_LOS_POSTS[@]}"
```

## Acumular resultados en un archivo JSON con jq

```bash
RESULTADOS_JSON="[]"

for id in $(seq 1 5); do
    ITEM=$(curl -s "$BASE_URL/users/$id")
    # Agregar al array JSON
    RESULTADOS_JSON=$(echo "$RESULTADOS_JSON" | \
        jq --argjson item "$ITEM" '. + [$item]')
done

echo "$RESULTADOS_JSON" | jq 'map({id: .id, nombre: .name})'
```

## Rate limiting: sleep entre requests

Cuando haces muchos requests a una API publica, es importante no sobrecargarla.
La mayoria de las APIs tienen rate limits (por ejemplo, 100 requests por minuto).

```bash
for id in $(seq 1 20); do
    curl -s "$BASE_URL/posts/$id" | jq -r '.title'
    sleep 0.5    # 0.5 segundos entre cada request
done
```

Para calcular el delay correcto: si el rate limit es 100 req/min, el minimo
seguro es 60/100 = 0.6 segundos entre requests. Con 0.5 podrias acercarte al
limite. Con 1 segundo tienes margen de seguridad.

Si la API retorna `429 Too Many Requests`, el header `Retry-After` indica cuantos
segundos esperar:

```bash
HTTP_CODE=$(curl -sS -o /tmp/resp.json -w "%{http_code}" "$URL")
if [ "$HTTP_CODE" -eq 429 ]; then
    RETRY_AFTER=$(curl -sS -I -o /dev/null \
                       -w "%header{retry-after}" "$URL" 2>/dev/null)
    WAIT="${RETRY_AFTER:-60}"
    echo "Rate limit. Esperando ${WAIT}s..."
    sleep "$WAIT"
fi
```

Nota: `%header{nombre}` en `--write-out` esta disponible desde curl 7.84.0.
En versiones anteriores, captura los headers con `-D /tmp/headers.txt` y usa
`grep`.

## Paralelo vs Secuencial

Hasta ahora todos los loops son secuenciales: esperamos que cada request complete
antes de iniciar el siguiente. Esto es lo mas simple y adecuado cuando:

- La API tiene rate limits estrictos
- Cada request depende del resultado del anterior
- No necesitamos velocidad extrema

La ejecucion paralela (usando `&` en bash, `xargs -P` o GNU `parallel`) se
cubre en la semana 9. Tiene complejidad adicional: manejo de concurrencia,
sincronizacion de resultados y riesgo de violar rate limits.

Para la mayoria de los scripts de automatizacion, la ejecucion secuencial con
un `sleep` adecuado es la eleccion correcta.
