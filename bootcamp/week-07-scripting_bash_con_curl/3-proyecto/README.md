# Proyecto: API Sync

## Descripcion

`sync.sh` es un script de sincronizacion que lee un archivo CSV con registros
de usuarios, verifica cuales ya existen en la API y crea los que no existen.
Al finalizar genera un reporte con el resultado de cada operacion.

Este proyecto integra todo lo aprendido en la semana: exit codes, jq, loops
con manejo de errores, funciones reutilizables y estructura profesional.

## La API usada

`https://jsonplaceholder.typicode.com` — API REST publica para pruebas.
No persiste datos realmente, pero retorna respuestas validas (200 en GET,
201 en POST), lo que es suficiente para demostrar la logica del script.

## Archivo de entrada: users.csv

El script lee un CSV con las columnas `id,name,email`. El campo `id` se usa
para verificar si el usuario ya existe en la API (GET /users/id).

Ejemplo (`users.csv`):

```
id,name,email
1,John Doe,john@example.com
2,Jane Doe,jane@example.com
200,Nueva Persona,nueva@example.com
201,Otra Persona,otra@example.com
```

Los IDs 1 y 2 existen en jsonplaceholder. Los IDs 200 y 201 no existen,
por lo que el script deberia intentar crearlos (POST /users).

## Comportamiento esperado

```
[10:30:01] Iniciando sincronizacion desde users.csv
[10:30:01] Procesando: John Doe (john@example.com)
[10:30:01] Usuario 1 ya existe (John Doe)
[10:30:02] Procesando: Jane Doe (jane@example.com)
[10:30:02] Usuario 2 ya existe (Leanne Graham)
[10:30:02] Procesando: Nueva Persona (nueva@example.com)
[10:30:02] Usuario 200 no existe, creando...
[10:30:03] Creado con id: 11
[10:30:03] Procesando: Otra Persona (otra@example.com)
[10:30:03] Usuario 201 no existe, creando...
[10:30:04] Creado con id: 11

=== Resumen ===
Creados   : 2
Existian  : 2
Errores   : 0
```

Nota: jsonplaceholder siempre retorna id=11 en los POST, lo cual es correcto
para una API de pruebas.

## Features requeridas

### Estructura base

- `set -euo pipefail` en el encabezado
- Variables de configuracion con `readonly` y valores por defecto
- Contadores `created`, `existed`, `errors` inicializados en 0
- Funcion `log()` que escribe a stderr con timestamp

### Funcion `user_exists()`

```bash
user_exists() {
    local id="$1"
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
                     --max-time 10 \
                     "${BASE_URL}/users/${id}")
    [ "$http_code" -eq 200 ]
}
```

Retorna 0 (verdadero en bash) si el usuario existe, 1 si no existe.

### Funcion `create_user()`

```bash
create_user() {
    local name="$1"
    local email="$2"
    local body

    body=$(jq -n --arg name "$name" --arg email "$email" \
               '{name: $name, email: $email}')

    local response http_code
    http_code=$(curl -s \
                     --max-time 15 \
                     -X POST \
                     -H "Content-Type: application/json" \
                     -d "$body" \
                     -o /tmp/create_response_$$.json \
                     -w "%{http_code}" \
                     "${BASE_URL}/users")

    if [ "$http_code" -eq 201 ] || [ "$http_code" -eq 200 ]; then
        local new_id
        new_id=$(jq -r '.id' /tmp/create_response_$$.json)
        rm -f /tmp/create_response_$$.json
        echo "$new_id"
        return 0
    fi

    rm -f /tmp/create_response_$$.json
    return 1
}
```

### Loop sobre el CSV

```bash
tail -n +2 "$CSV_FILE" | while IFS=, read -r id name email; do
    [ -z "$id" ] && continue
    log "Procesando: $name ($email)"

    if user_exists "$id"; then
        log "Usuario $id ya existe"
        # incrementar existed
    else
        log "Usuario $id no existe, creando..."
        if new_id=$(create_user "$name" "$email"); then
            log "Creado con id: $new_id"
            # incrementar created
        else
            log "Error al crear usuario $name"
            # incrementar errors
        fi
    fi

    sleep 0.3
done
```

### Retry en 429

Si la API retorna 429 (rate limit), el script debe esperar 5 segundos y
reintentar. Implementa esta logica en una funcion `curl_with_retry()`:

```bash
curl_with_retry() {
    local max_retries=3
    local attempt=1

    while [ "$attempt" -le "$max_retries" ]; do
        local http_code
        # ... hacer el request ...

        if [ "$http_code" -eq 429 ]; then
            log "Rate limit (429). Esperando 5s... (intento $attempt/$max_retries)"
            sleep 5
            attempt=$((attempt + 1))
            continue
        fi

        echo "$http_code"
        return 0
    done

    log "Error: max reintentos alcanzados"
    return 1
}
```

## Estructura del archivo a entregar

```
3-proyecto/
├── README.md           <- este archivo
├── starter/
│   └── sync.sh         <- estructura base para completar
├── sync.sh             <- tu implementacion completa
├── users.csv           <- archivo CSV de entrada
└── respuestas.md       <- descripcion de tu solucion y decisiones tomadas
```

## Criterios de evaluacion

| Criterio | Puntos |
|----------|--------|
| Lee CSV y parsea campos correctamente (IFS=, skip header) | 15 |
| Verifica existencia via GET antes de crear | 20 |
| Crea registros nuevos via POST con JSON correcto | 20 |
| Implementa retry con espera en 429 | 20 |
| Reporte final: creados / existentes / errores | 15 |
| Estructura profesional (set -euo, funciones, logging) | 10 |

**Total: 100 puntos. Aprobacion: 60 puntos.**

## Como empezar

El directorio `starter/` contiene `sync.sh` con la estructura base: variables,
funciones vacias y el loop sobre el CSV. Completa las funciones `user_exists()`
y `create_user()`, e implementa la logica de contadores y retry.

```bash
cp starter/sync.sh sync.sh
chmod +x sync.sh
# edita sync.sh y completa los TODO
```

Crea el archivo `users.csv` con el ejemplo de arriba y prueba:

```bash
./sync.sh users.csv
```

## Preguntas de reflexion (respuestas.md)

1. El script usa `tail -n +2` para saltar la cabecera del CSV. Que pasaria
   si el CSV no tuviera cabecera y usaras `tail -n +2` igual?

2. Los contadores `created`, `existed`, `errors` se modifican dentro de un
   `while ... | while IFS=, read` que es un subshell. Esto puede causar que
   el reporte final muestre siempre 0. Como solucionarias este problema?
   (pista: busca "bash subshell variable scope" y la sintaxis `while ... done < <(...)`)

3. jsonplaceholder siempre retorna id=11 en los POST aunque envies datos
   distintos. En una API real, que deberia hacer tu script con el id nuevo
   que retorna la API?

4. El script verifica si un usuario existe con GET /users/ID. Esta tecnica
   tiene un problema de concurrencia: otro proceso podria crear el usuario
   entre el GET y el POST. Esto se llama "race condition". En que tipos de
   entorno importaria esto y como mitigarlo?
