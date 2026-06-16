# Ejercicio 04: Request combinado - texto y archivo

## Objetivo

Simular un flujo realista de upload de perfil de usuario: campos de texto (nombre, email, rol) más un archivo de foto, todo en un mismo request multipart. Verificar que el servidor recibió todos los campos correctamente.

---

## Contexto

En muchas APIs, cuando un usuario actualiza su perfil, el frontend envía en un solo request:
- Campos de texto: nombre, email, bio
- Un archivo: foto de perfil

Este ejercicio replica ese flujo usando httpbin como backend.

---

## Preparación

```bash
mkdir ~/perfil-practica
cd ~/perfil-practica

# Foto de perfil simulada (imagen real de httpbin)
curl -s -o foto-perfil.jpg https://httpbin.org/image/jpeg

# Archivo de bio en texto
cat > bio.txt << 'EOF'
Desarrolladora backend con 5 años de experiencia en Python y Go.
Apasionada por las APIs bien documentadas y el testing automatizado.
EOF

echo "Archivos preparados:"
ls -lh
```

---

## Tarea 1: Simular actualización de perfil básico

```bash
curl -s \
     -F "nombre=Ana Lopez" \
     -F "email=ana@ejemplo.com" \
     -F "rol=desarrolladora" \
     -F "foto=@foto-perfil.jpg;type=image/jpeg" \
     https://httpbin.org/post | python3 -m json.tool
```

En la respuesta verificar:
- Los campos de texto aparecen en `.form`
- El archivo aparece en `.files`

**Pregunta:** ¿Llegaron todos los campos? Lista los que aparecen en `.form` y los que aparecen en `.files`.

---

## Tarea 2: Perfil completo con múltiples campos y archivo de bio

```bash
curl -s \
     -F "nombre=Carlos Ruiz" \
     -F "email=carlos@ejemplo.com" \
     -F "usuario=carlos_r" \
     -F "pais=Argentina" \
     -F "activo=true" \
     -F "foto=@foto-perfil.jpg;type=image/jpeg" \
     -F "bio=@bio.txt;type=text/plain" \
     https://httpbin.org/post | python3 -m json.tool
```

**Preguntas:**
- ¿Cuántos campos aparecen en `.form`?
- ¿Cuántos archivos aparecen en `.files`?
- ¿Cómo aparece el contenido de `bio.txt` en la respuesta?

---

## Tarea 3: Verificar el Content-Type del request

```bash
curl -v \
     -F "nombre=Test" \
     -F "foto=@foto-perfil.jpg" \
     https://httpbin.org/post 2>&1 | grep -E "^> |Content-Type"
```

**Pregunta:** ¿Cuál es el Content-Type exacto que curl setea para este request? ¿Qué es el `boundary`?

---

## Tarea 4: Comparar con URL-encoded

Enviar los mismos datos de texto (sin foto) en URL-encoded:

```bash
curl -s \
     -d "nombre=Ana Lopez&email=ana@ejemplo.com&rol=desarrolladora" \
     https://httpbin.org/post | python3 -m json.tool
```

Y en multipart sin archivo:

```bash
curl -s \
     -F "nombre=Ana Lopez" \
     -F "email=ana@ejemplo.com" \
     -F "rol=desarrolladora" \
     https://httpbin.org/post | python3 -m json.tool
```

**Pregunta:** ¿En qué campo del JSON de httpbin aparecen los datos en cada caso? ¿Qué diferencia notás en el Content-Type?

---

## Tarea 5: Script de actualización de perfil

Crear un script que encapsula la actualización de perfil:

```bash
cat > actualizar-perfil.sh << 'SCRIPT'
#!/bin/bash

# Uso: ./actualizar-perfil.sh NOMBRE EMAIL FOTO_PATH
NOMBRE="$1"
EMAIL="$2"
FOTO="$3"

if [ -z "$NOMBRE" ] || [ -z "$EMAIL" ] || [ -z "$FOTO" ]; then
    echo "Uso: $0 NOMBRE EMAIL FOTO_PATH"
    exit 1
fi

if [ ! -f "$FOTO" ]; then
    echo "Error: no se encontró el archivo $FOTO"
    exit 1
fi

echo "Actualizando perfil de $NOMBRE ($EMAIL)..."

RESPUESTA=$(curl -s \
     -F "nombre=${NOMBRE}" \
     -F "email=${EMAIL}" \
     -F "foto=@${FOTO};type=image/jpeg" \
     https://httpbin.org/post)

HTTP_STATUS=$(echo "$RESPUESTA" | python3 -c "import sys, json; d=json.load(sys.stdin); print('OK' if 'form' in d else 'ERROR')")
echo "Estado: $HTTP_STATUS"
echo "$RESPUESTA" | python3 -m json.tool | grep -A5 '"form"'
SCRIPT

chmod +x actualizar-perfil.sh

# Probar el script
./actualizar-perfil.sh "María García" "maria@ejemplo.com" foto-perfil.jpg
```

---

## Entrega

Archivo `respuestas.md` con:
1. Campos en `.form` y `.files` de la Tarea 1
2. Conteo de campos y archivos de la Tarea 2
3. Content-Type exacto de la Tarea 3 y explicación del boundary
4. Comparación URL-encoded vs multipart de la Tarea 4
5. Output del script de la Tarea 5
6. Reflexión: ¿en qué casos usarías multipart en una API real?
