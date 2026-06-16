# Ejercicio 03: Headers custom

## Objetivo

Experimentar con headers HTTP. Observar qué headers envía curl por defecto, cómo cambiarlos, y cómo httpbin los refleja para confirmar que llegaron correctamente.

## API de práctica

`https://httpbin.org/headers` — refleja exactamente todos los headers que recibió.
`https://httpbin.org/get` — refleja headers y datos del GET.

---

## Tareas

### 1. Ver los headers por defecto de curl

```bash
curl -s https://httpbin.org/headers | python3 -m json.tool
```

Observar qué headers envía curl automáticamente:
- `User-Agent`: identifica la versión de curl
- `Accept`: `*/*` (acepta cualquier formato)
- `Host`: el dominio de la URL

### 2. Agregar un header custom X-*

```bash
curl -s \
     -H "X-Request-ID: ejercicio-03-test" \
     -H "X-Bootcamp: bc-curl" \
     https://httpbin.org/headers | python3 -m json.tool
```

Verificar que ambos headers aparecen en la respuesta.

### 3. Cambiar el User-Agent

El User-Agent identifica tu cliente. Muchas APIs lo registran en sus logs.

```bash
# User-Agent de Chrome (simulación)
curl -s \
     -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
     https://httpbin.org/headers | python3 -m json.tool

# User-Agent custom de tu app
curl -s \
     -H "User-Agent: mi-cliente-rest/1.0 (bootcamp-curl)" \
     https://httpbin.org/headers | python3 -m json.tool

# Usando el flag dedicado -A
curl -s -A "mi-cliente/1.0" https://httpbin.org/headers | python3 -m json.tool
```

### 4. Experimentar con Accept

Accept le dice al servidor qué formatos aceptás en la respuesta:

```bash
# Pedir JSON explícitamente
curl -s -H "Accept: application/json" https://httpbin.org/get | python3 -m json.tool

# Pedir XML (httpbin tiene un endpoint de XML)
curl -s -H "Accept: application/xml" https://httpbin.org/xml

# Múltiples formatos con preferencia (q=quality factor)
curl -s -H "Accept: application/json;q=0.9,text/html;q=0.5" https://httpbin.org/get
```

Observar si la respuesta cambia según el Accept.

### 5. Enviar Accept: application/xml vs application/json

```bash
# Endpoint que devuelve JSON por defecto
curl -s -H "Accept: application/json" https://httpbin.org/get | head -5

# Mismo endpoint, pidiendo XML
curl -s -H "Accept: application/xml" https://httpbin.org/get | head -5
```

httpbin devuelve JSON independientemente del Accept en este endpoint, pero en APIs reales la diferencia es importante.

### 6. Eliminar un header que curl agrega por defecto

```bash
# curl agrega Accept: */* por defecto
# Para eliminarlo, poner el header con valor vacío
curl -s -H "Accept:" https://httpbin.org/headers | python3 -m json.tool
```

Verificar que `Accept` ya no aparece en la respuesta de httpbin.

### 7. Combinación completa de headers

```bash
curl -s \
     -X POST \
     -H "Content-Type: application/json" \
     -H "Accept: application/json" \
     -H "X-Request-ID: $(date +%s)" \
     -H "User-Agent: bootcamp-curl/2.0" \
     -d '{"test": "headers completos"}' \
     https://httpbin.org/post | python3 -m json.tool
```

`$(date +%s)` genera un timestamp Unix como valor del request ID — útil para hacer cada request único.

---

## Preguntas para responder

1. ¿Cuáles son los headers que curl envía en todo request sin que hagas nada?
2. ¿Qué diferencia hay entre `-H "User-Agent: mi-app"` y `-A "mi-app"`?
3. ¿Para qué sirve el header `Accept` en la práctica?
4. ¿Por qué los headers custom suelen empezar con `X-`?

---

## Entrega

Archivo `respuestas.md` con:
1. Output del paso 1 (headers por defecto de curl)
2. Output del paso 7 (combinación completa)
3. Respuestas a las 4 preguntas
