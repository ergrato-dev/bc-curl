# Ejercicio 04: Status codes en la práctica

## Objetivo

Provocar y leer los status codes más comunes. Aprender a capturarlos en una variable.

## Tareas

### 1. Status 200 — OK

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://httpbin.org/get
curl -s -o /dev/null -w "%{http_code}\n" https://jsonplaceholder.typicode.com/posts/1
```

### 2. Status 201 — Created

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"title": "test"}' \
  https://jsonplaceholder.typicode.com/posts
```

### 3. Status 301 / 302 — Redirect

```bash
# Ver el 301 sin seguirlo
curl -s -o /dev/null -w "%{http_code}\n" http://httpbin.org

# Ver la cadena completa
curl -s -o /dev/null -w "%{http_code} → %{redirect_url}\n" http://httpbin.org

# Con -L: el código final después de seguir
curl -s -L -o /dev/null -w "%{http_code}\n" http://httpbin.org
```

### 4. Status 404 — Not Found

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://httpbin.org/status/404
curl -s -o /dev/null -w "%{http_code}\n" https://jsonplaceholder.typicode.com/posts/9999
```

### 5. Status 401 — Unauthorized

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://httpbin.org/basic-auth/user/pass
```

¿Qué devuelve sin credenciales?

### 6. Status 429 — Too Many Requests

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://httpbin.org/status/429
```

### 7. Status 500 — Server Error

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://httpbin.org/status/500
```

### 8. Script: verificar múltiples endpoints

```bash
#!/bin/bash
URLS=(
  "https://httpbin.org/get"
  "https://httpbin.org/status/404"
  "https://httpbin.org/status/500"
  "https://jsonplaceholder.typicode.com/posts/1"
  "https://jsonplaceholder.typicode.com/posts/9999"
)

for url in "${URLS[@]}"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  echo "$code $url"
done
```

Guardar como `check-urls.sh`, ejecutar con `bash check-urls.sh`.

## Entrega

Archivo `respuestas.md` con:
1. Tabla: URL → status code obtenido para los 8 escenarios
2. Output del script del punto 8
3. Explicación: diferencia entre 401 y 403 en tus palabras
4. ¿Cuándo usarías `-w "%{http_code}"` en un script real?
