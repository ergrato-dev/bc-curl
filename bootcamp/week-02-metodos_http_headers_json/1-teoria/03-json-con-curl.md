# JSON con curl

## Por qué JSON es el formato estándar

La mayoría de las APIs REST modernas hablan JSON. Es texto legible, tiene estructura jerárquica, y prácticamente todos los lenguajes lo soportan de forma nativa. Cuando trabajás con curl y APIs, el 90% de los bodies que vas a enviar y recibir son JSON.

---

## Enviar JSON: lo mínimo necesario

Dos cosas obligatorias al enviar JSON:

1. El header `Content-Type: application/json` — le dice al servidor qué formato viene
2. El body en formato JSON válido — entre comillas, claves entre comillas dobles

```bash
curl -X POST \
     -H "Content-Type: application/json" \
     -d '{"name": "Ana", "email": "ana@example.com"}' \
     https://httpbin.org/post
```

---

## El problema de las comillas en bash

JSON usa comillas dobles obligatoriamente. Bash interpreta las comillas dobles. Esto genera conflictos.

**Problema: comillas dobles dentro de string con comillas dobles**

```bash
# MAL: el shell interpreta las comillas internas y rompe el JSON
curl -d "{"name": "Ana"}" https://httpbin.org/post

# BIEN: comillas simples afuera, dobles adentro
curl -d '{"name": "Ana"}' https://httpbin.org/post
```

**Problema: el JSON es largo y difícil de escribir en una línea**

Usar heredoc:

```bash
curl -X POST \
     -H "Content-Type: application/json" \
     -d @- https://httpbin.org/post <<'EOF'
{
  "title": "Mi primer post",
  "body": "Contenido con 'comillas simples' y \"dobles\" sin problema",
  "userId": 1,
  "tags": ["curl", "http", "json"]
}
EOF
```

El `@-` le dice a curl que lea el body desde stdin, y el heredoc `<<'EOF'` alimenta ese stdin.

---

## Enviar desde archivo externo

La solución más limpia para bodies complejos o reutilizables:

```bash
# Crear el archivo JSON
cat > datos.json <<'EOF'
{
  "title": "Post desde archivo",
  "body": "Este body viene de un archivo externo",
  "userId": 1
}
EOF

# Enviarlo
curl -X POST \
     -H "Content-Type: application/json" \
     -d @datos.json \
     https://jsonplaceholder.typicode.com/posts
```

El `@` le indica a curl que el argumento de `-d` es un path de archivo, no un string.

---

## Recibir JSON y formatearlo

Las APIs devuelven JSON comprimido (sin espacios ni saltos de línea). Para leerlo:

**Con python3 (disponible en casi todos los sistemas):**

```bash
curl -s https://jsonplaceholder.typicode.com/posts/1 | python3 -m json.tool
```

**Con jq (si está instalado):**

```bash
curl -s https://jsonplaceholder.typicode.com/posts/1 | jq .

# Extraer un campo específico
curl -s https://jsonplaceholder.typicode.com/posts/1 | jq '.title'

# Extraer campo de array
curl -s https://jsonplaceholder.typicode.com/users | jq '.[0].email'
```

**Instalar jq:**

```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq
```

---

## Guardar la respuesta JSON en un archivo

```bash
# Guardar y mostrar al mismo tiempo con tee
curl -s https://jsonplaceholder.typicode.com/posts/1 | tee respuesta.json | python3 -m json.tool

# Solo guardar
curl -s -o respuesta.json https://jsonplaceholder.typicode.com/posts/1

# Guardar formateado
curl -s https://jsonplaceholder.typicode.com/posts/1 | python3 -m json.tool > respuesta_formateada.json
```

---

## Verificar que el JSON enviado llegó bien

httpbin.org/post muestra exactamente lo que recibió. El campo `json` del response confirma que el servidor parseó correctamente el body:

```bash
curl -s \
     -H "Content-Type: application/json" \
     -d '{"user": "Ana", "active": true, "score": 42}' \
     https://httpbin.org/post | python3 -m json.tool
```

Si el campo `json` tiene el objeto que enviaste, todo llegó bien. Si está `null`, el servidor no pudo parsear el body (probablemente un error de Content-Type o JSON malformado).

---

## JSON inválido: errores comunes

```bash
# MAL: trailing comma
-d '{"name": "Ana",}'

# MAL: comillas simples en las claves (JSON requiere dobles)
-d "{'name': 'Ana'}"

# MAL: sin comillas en strings
-d '{"name": Ana}'

# BIEN
-d '{"name": "Ana"}'
```

Para validar JSON antes de enviarlo:

```bash
echo '{"name": "Ana"}' | python3 -m json.tool
# Si es válido, lo imprime formateado
# Si no es válido, muestra el error
```
