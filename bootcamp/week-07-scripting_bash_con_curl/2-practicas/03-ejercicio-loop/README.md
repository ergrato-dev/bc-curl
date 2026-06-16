# Ejercicio 3: Loop con curl y jq

## Objetivo

Crear un script que descargue los primeros 10 posts de jsonplaceholder, extraiga
el titulo de cada uno con jq, y los guarde en un archivo de texto. El script debe
ser robusto ante errores y respetar la API con un delay entre requests.

## El script a construir: descargar-titulos.sh

```bash
#!/bin/bash
set -uo pipefail

BASE_URL="https://jsonplaceholder.typicode.com"
OUTPUT_FILE="titulos.txt"
DELAY=0.5   # segundos entre requests
MAX_ID=10

log() {
    echo "[$(date '+%H:%M:%S')] $*" >&2
}

log "Descargando titulos de posts 1 a $MAX_ID..."
log "Output: $OUTPUT_FILE"
echo ""

# Limpiar archivo de output si existe
> "$OUTPUT_FILE"

EXITOSOS=0
FALLIDOS=0

for id in $(seq 1 "$MAX_ID"); do
    log "Descargando post $id..."

    RESPUESTA=$(curl -sS \
                     --max-time 10 \
                     --connect-timeout 5 \
                     "$BASE_URL/posts/$id" 2>/dev/null)
    CURL_EXIT=$?

    if [ "$CURL_EXIT" -ne 0 ]; then
        log "Error de curl (exit $CURL_EXIT) en post $id"
        FALLIDOS=$((FALLIDOS + 1))
        sleep "$DELAY"
        continue
    fi

    # Verificar que la respuesta tiene un campo 'title'
    TITULO=$(echo "$RESPUESTA" | jq -r '.title // empty')

    if [ -z "$TITULO" ]; then
        log "Post $id: respuesta sin titulo o invalida"
        FALLIDOS=$((FALLIDOS + 1))
        sleep "$DELAY"
        continue
    fi

    echo "$id. $TITULO" >> "$OUTPUT_FILE"
    EXITOSOS=$((EXITOSOS + 1))

    sleep "$DELAY"
done

echo ""
log "Completado: $EXITOSOS exitosos, $FALLIDOS fallidos"
log "Titulos guardados en: $OUTPUT_FILE"
```

## Ejecucion y verificacion

```bash
chmod +x descargar-titulos.sh
./descargar-titulos.sh
```

El script tarda aproximadamente 5 segundos (10 requests x 0.5s de delay).

Verifica el resultado:
```bash
cat titulos.txt
wc -l titulos.txt   # debe mostrar 10 lineas
```

## Variantes a implementar

### Variante A: descargar desde un archivo de IDs

Modifica el script para leer los IDs desde un archivo en lugar de un rango fijo:

Crea `ids.txt`:
```
1
5
10
42
99
100
```

Modifica el loop para leer desde el archivo:

```bash
while IFS= read -r id; do
    [ -z "$id" ] && continue
    [[ "$id" == \#* ]] && continue
    # ... mismo codigo de descarga ...
done < ids.txt
```

### Variante B: mostrar progreso en tiempo real

Muestra una barra de progreso simple:

```bash
TOTAL=$MAX_ID
ACTUAL=0

for id in $(seq 1 "$MAX_ID"); do
    ACTUAL=$((ACTUAL + 1))
    PORCENTAJE=$((ACTUAL * 100 / TOTAL))
    printf "\r  Progreso: [%d/%d] %d%%  " "$ACTUAL" "$TOTAL" "$PORCENTAJE" >&2

    # ... descarga ...
done

echo "" >&2  # nueva linea al terminar
```

### Variante C: guardar JSON completo de cada post

En lugar de solo el titulo, guarda el JSON completo de cada post en un archivo
separado:

```bash
mkdir -p posts/

for id in $(seq 1 "$MAX_ID"); do
    curl -sS "$BASE_URL/posts/$id" -o "posts/post-${id}.json"
    sleep "$DELAY"
done

# Contar cuantos se guardaron
ls posts/*.json | wc -l
```

## Preguntas de analisis (respuestas.md)

1. Que pasa si eliminas el `sleep "$DELAY"` y corres el script varias veces
   seguidas? Observas diferencia en los tiempos de respuesta?
2. En el script, `continue` salta al siguiente elemento del loop. Que pasaria
   si usaras `exit 1` en su lugar?
3. El filtro `jq -r '.title // empty'` usa `// empty`. Que diferencia hay con
   solo `'.title'`? Por que es mejor para verificar si el campo existe?
4. Como modificarias el script para hacer los 10 requests de forma paralela?
   (No necesitas implementarlo, solo describir el enfoque)

## Entregables

- `descargar-titulos.sh`: script base + al menos una variante
- `titulos.txt`: archivo generado por el script
- `output.txt`: output del script (incluido el log de stderr: `./script 2>&1 | tee output.txt`)
- `respuestas.md`: respuestas a las preguntas
