# Ejercicio 04: JSON desde archivos

## Objetivo

Trabajar con JSON usando archivos externos: crear un archivo JSON, enviarlo con curl, recibir la respuesta, guardarla, y formatearla. Este flujo es el que se usa en scripts reales.

---

## Tareas

### 1. Crear un archivo JSON válido

```bash
cat > nuevo-post.json <<'EOF'
{
  "title": "Aprendiendo curl en el bootcamp",
  "body": "Este post fue creado enviando un archivo JSON con el flag -d @archivo",
  "userId": 42
}
EOF
```

Verificar que el JSON es válido:
```bash
python3 -m json.tool nuevo-post.json
```

Si hay errores de sintaxis, los muestra con la línea exacta. Si es válido, lo imprime formateado.

### 2. Enviar el archivo con -d @

```bash
curl -s \
     -X POST \
     -H "Content-Type: application/json" \
     -d @nuevo-post.json \
     https://jsonplaceholder.typicode.com/posts
```

Observar que el `@` le dice a curl "leé el contenido de este archivo como body".

### 3. Verificar que llegó bien con httpbin

```bash
curl -s \
     -H "Content-Type: application/json" \
     -d @nuevo-post.json \
     https://httpbin.org/post | python3 -m json.tool
```

Verificar en la respuesta de httpbin:
- El campo `json` debe contener el objeto del archivo
- El campo `data` debe contener el JSON como string
- El campo `headers` debe mostrar `Content-Type: application/json`

### 4. Guardar la respuesta en un archivo

```bash
curl -s \
     -X POST \
     -H "Content-Type: application/json" \
     -d @nuevo-post.json \
     -o respuesta-post.json \
     https://jsonplaceholder.typicode.com/posts
```

Ver el archivo guardado:
```bash
python3 -m json.tool respuesta-post.json
```

### 5. Guardar y mostrar al mismo tiempo con tee

```bash
curl -s \
     -X POST \
     -H "Content-Type: application/json" \
     -d @nuevo-post.json \
     https://jsonplaceholder.typicode.com/posts | tee respuesta-tee.json | python3 -m json.tool
```

`tee` escribe en el archivo Y pasa el contenido a stdout al mismo tiempo.

### 6. Crear un JSON con múltiples campos y tipos

Probar con diferentes tipos de datos JSON:

```bash
cat > datos-completos.json <<'EOF'
{
  "titulo": "Post complejo",
  "publicado": true,
  "vistas": 0,
  "tags": ["curl", "http", "bash"],
  "autor": {
    "nombre": "Ana",
    "id": 7
  }
}
EOF

# Verificar
python3 -m json.tool datos-completos.json

# Enviar a httpbin para ver cómo lo parsea
curl -s \
     -H "Content-Type: application/json" \
     -d @datos-completos.json \
     https://httpbin.org/post | python3 -m json.tool
```

### 7. Guardar la respuesta y extraer un campo con python3

```bash
# Guardar respuesta
curl -s https://jsonplaceholder.typicode.com/posts/1 -o post1.json

# Extraer solo el título
python3 -c "import json; d=json.load(open('post1.json')); print(d['title'])"

# Extraer múltiples campos
python3 -c "
import json
with open('post1.json') as f:
    d = json.load(f)
print(f'ID: {d[\"id\"]}')
print(f'Titulo: {d[\"title\"]}')
print(f'Usuario: {d[\"userId\"]}')
"
```

---

## Errores comunes

**JSON malformado:**
```bash
cat > roto.json <<'EOF'
{
  "title": "sin cerrar
}
EOF
python3 -m json.tool roto.json
# Muestra: JSONDecodeError: Expecting ',' delimiter
```

**Olvidar el @ antes del nombre de archivo:**
```bash
# MAL: curl envía el string literal "datos.json" como body
curl -d "datos.json" https://httpbin.org/post

# BIEN: curl lee el contenido del archivo
curl -d @datos.json https://httpbin.org/post
```

---

## Entrega

Archivo `respuestas.md` con:
1. El contenido de `nuevo-post.json` que creaste
2. Output del paso 3 (verificación con httpbin)
3. Output del paso 6 (datos complejos)
4. El título extraído en el paso 7
5. Respuesta: ¿cuándo conviene enviar JSON desde archivo vs inline con `-d`?
