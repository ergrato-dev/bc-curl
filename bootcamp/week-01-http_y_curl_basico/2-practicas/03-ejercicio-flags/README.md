# Ejercicio 03: Dominar los flags esenciales

## Objetivo

Usar los 6 flags más importantes de curl con confianza, entendiendo qué hace cada uno.

## Flags a dominar

`-v`, `-i`, `-I`, `-o`, `-s`, `-L`

## Tareas

### 1. Flag -v (verbose)

```bash
curl -v https://httpbin.org/get 2>&1 | head -40
```

Identificar y anotar:
- La línea donde se establece la conexión TCP
- Los headers que curl envía (líneas con `>`)
- Los headers que el servidor devuelve (líneas con `<`)
- Dónde empieza el body

### 2. Flag -i (include response headers)

```bash
curl -i https://httpbin.org/get
```

Comparar con `-v`: ¿qué muestra -i que no muestra -v y viceversa?

### 3. Flag -I (HEAD request)

```bash
curl -I https://httpbin.org/get
curl -I https://httpbin.org/image/png
```

¿Por qué `-I` en la imagen es más útil que un GET?

### 4. Flag -o (output a archivo)

```bash
curl -o /tmp/respuesta.json https://httpbin.org/get
curl -o /tmp/imagen.png https://httpbin.org/image/png

# Verificar
ls -lh /tmp/respuesta.json /tmp/imagen.png
cat /tmp/respuesta.json
```

### 5. Flag -s (silent)

```bash
# Con barra de progreso (default en archivos grandes)
curl -o /tmp/grande.json https://httpbin.org/anything

# Sin barra de progreso
curl -s -o /tmp/grande.json https://httpbin.org/anything
echo "Exit code: $?"
```

¿Cuándo es útil -s?

### 6. Flag -L (follow redirects)

```bash
# Sin -L: se detiene en el 301
curl -v http://httpbin.org 2>&1 | grep -E "^[<>*]"

# Con -L: sigue hasta destino final
curl -v -L http://httpbin.org 2>&1 | grep -E "^[<>*]"
```

Contar cuántos redirects hay.

### 7. Combinar flags

```bash
# Silencioso, siguiendo redirects, guardando a archivo
curl -s -L -o /tmp/final.json https://httpbin.org/get

# Solo ver el status code
curl -s -o /dev/null -w "%{http_code}\n" https://httpbin.org/get

# Headers + body sin barra de progreso
curl -s -i https://httpbin.org/get
```

## Entrega

Archivo `respuestas.md` con:
1. Descripción de qué hace cada flag en tus propias palabras
2. Output del comando del punto 7 (status code)
3. Diferencia entre `-v` y `-i` según lo que observaste
4. Un caso de uso propio para cada flag
