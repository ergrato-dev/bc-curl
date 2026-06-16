# Ejercicio 02: GET básico a APIs reales

## Objetivo

Hacer peticiones GET a 3 APIs públicas diferentes e interpretar las respuestas.

## APIs a usar

- `https://httpbin.org` — refleja tus requests
- `https://api.github.com` — API REST real de GitHub
- `https://jsonplaceholder.typicode.com` — datos de prueba

## Tareas

### 1. httpbin - reflector de requests

```bash
# GET básico
curl https://httpbin.org/get

# GET con query string
curl "https://httpbin.org/get?nombre=estudiante&semana=1"
```

Observar: ¿dónde aparecen los query params en la respuesta?

### 2. GitHub API - datos reales

```bash
# Info de usuario público
curl https://api.github.com/users/octocat

# Repositorios públicos
curl https://api.github.com/users/octocat/repos

# Info del rate limit (cuántos requests quedan)
curl https://api.github.com/rate_limit
```

### 3. JSONPlaceholder - CRUD de prueba

```bash
# Lista de posts
curl https://jsonplaceholder.typicode.com/posts

# Un post específico
curl https://jsonplaceholder.typicode.com/posts/1

# Comentarios de un post
curl https://jsonplaceholder.typicode.com/posts/1/comments
```

### 4. Comparar las respuestas

Para cada API:
- ¿El Content-Type es `application/json`?
- ¿Qué otros headers de respuesta tiene?
- ¿El JSON está formateado (pretty) o en una línea?

```bash
# Ver headers de respuesta
curl -I https://jsonplaceholder.typicode.com/posts/1
```

## Entrega

Archivo `respuestas.md` con:
1. Output de 3 comandos a tu elección
2. Comparación de headers entre las 3 APIs
3. Una observación propia sobre diferencias entre las APIs
