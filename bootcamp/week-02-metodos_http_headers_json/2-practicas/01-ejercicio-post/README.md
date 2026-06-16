# Ejercicio 01: POST con JSON

## Objetivo

Crear recursos usando el método POST. Verificar el status code de respuesta, leer el body, y aprender a enviar el body desde un archivo externo.

## API de práctica

`https://jsonplaceholder.typicode.com/posts` — API de prueba que acepta POST y responde con el recurso creado (id 101 siempre, pero la estructura es real).

---

## Tareas

### 1. POST básico con JSON en línea

```bash
curl -X POST \
     -H "Content-Type: application/json" \
     -d '{"title": "mi primer post", "body": "contenido del post", "userId": 1}' \
     https://jsonplaceholder.typicode.com/posts
```

Observar:
- ¿Qué id devuelve el servidor?
- ¿Qué campos tiene la respuesta?

### 2. Verificar el status code

```bash
curl -s -o /dev/null -w "Status: %{http_code}\n" \
     -X POST \
     -H "Content-Type: application/json" \
     -d '{"title": "test", "body": "body", "userId": 1}' \
     https://jsonplaceholder.typicode.com/posts
```

Debe devolver `Status: 201`. POST exitoso que crea un recurso devuelve 201 Created.

### 3. Ver headers de respuesta también

```bash
curl -i \
     -X POST \
     -H "Content-Type: application/json" \
     -d '{"title": "con headers", "body": "body", "userId": 2}' \
     https://jsonplaceholder.typicode.com/posts
```

Identificar en los headers de respuesta: `Content-Type`, `Location` (si aparece), fecha.

### 4. Verificar con httpbin qué envía curl

```bash
curl -s \
     -H "Content-Type: application/json" \
     -d '{"title": "test", "body": "cuerpo", "userId": 1}' \
     https://httpbin.org/post | python3 -m json.tool
```

Identificar en la respuesta de httpbin:
- El campo `json`: ¿tiene el objeto que enviaste?
- El campo `headers`: ¿aparece `Content-Type: application/json`?
- El campo `data`: el body como string crudo

### 5. Enviar body desde un archivo

Crear el archivo:
```bash
cat > mi-post.json <<'EOF'
{
  "title": "Post desde archivo",
  "body": "Este contenido viene de un archivo .json externo",
  "userId": 3
}
EOF
```

Enviarlo:
```bash
curl -X POST \
     -H "Content-Type: application/json" \
     -d @mi-post.json \
     https://jsonplaceholder.typicode.com/posts
```

Verificar que el id de respuesta es el mismo que en los ejercicios anteriores (101 — jsonplaceholder es una API de prueba, no persiste datos).

---

## Preguntas para responder

1. ¿Qué diferencia hay entre la respuesta de httpbin y la de jsonplaceholder?
2. ¿Por qué el id siempre es 101 en jsonplaceholder?
3. ¿Qué pasaría si olvidás el header `Content-Type: application/json`?

Para la pregunta 3, probalo:
```bash
# Sin Content-Type
curl -s -X POST \
     -d '{"title": "test"}' \
     https://httpbin.org/post | python3 -m json.tool
```

Observá el campo `json` en la respuesta de httpbin. ¿Está `null` o tiene el objeto?

## Entrega

Archivo `respuestas.md` con:
1. Output completo de cada tarea
2. Respuestas a las tres preguntas
3. Explicación de qué significa el status 201
