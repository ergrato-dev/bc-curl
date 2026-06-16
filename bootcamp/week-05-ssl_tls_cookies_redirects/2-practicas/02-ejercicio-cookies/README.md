# Ejercicio 02: Cookies y sesiones

## Objetivo

Practicar el flujo completo de cookies: que el servidor las setee, guardarlas en archivo, reenviarlas en requests posteriores, e inspeccionar el archivo cookie jar.

---

## Tarea 1: Ver cómo el servidor setea cookies

```bash
# httpbin /cookies/set setea las cookies que le pasás en la query string
# -v para ver el header Set-Cookie en la respuesta
curl -v "https://httpbin.org/cookies/set?usuario=ana&rol=admin" 2>&1 | grep -i "set-cookie\|location\|HTTP/"
```

**Preguntas:**
- ¿Cuál es el status code de la respuesta?
- ¿Qué header usa el servidor para setear las cookies?
- ¿A qué URL redirige la respuesta?

---

## Tarea 2: Guardar cookies en archivo con -c

```bash
# -c guarda las cookies, -L sigue el redirect
curl -c mi-sesion.txt -L \
     "https://httpbin.org/cookies/set?session_id=abc123&usuario=ana"

# Inspeccionar el archivo generado
cat mi-sesion.txt
```

**Preguntas:**
- ¿Cuántas líneas no comentadas tiene el archivo?
- ¿Cuántos campos tiene cada línea? ¿Qué representa cada campo?
- ¿Hay fecha de expiración? ¿Qué significa si es `0`?

---

## Tarea 3: Reenviar cookies con -b

```bash
# Enviar las cookies guardadas a un endpoint que las refleja
curl -b mi-sesion.txt https://httpbin.org/cookies
```

La respuesta debe mostrar las cookies que curl envió:

```json
{
  "cookies": {
    "session_id": "abc123",
    "usuario": "ana"
  }
}
```

Verificar que curl envía el header `Cookie` correcto:

```bash
curl -v -b mi-sesion.txt https://httpbin.org/cookies 2>&1 | grep -i "^> cookie"
```

**Pregunta:** ¿Cuál es el formato del header `Cookie` que curl envía?

---

## Tarea 4: Flujo de sesión completo

Simular un flujo realista: login (setea cookie) → verificar sesión → hacer request autenticado → obtener datos.

```bash
# Paso 1: Login (httpbin simula el Set-Cookie)
echo "=== Paso 1: Login ==="
curl -s -c sesion.txt -L \
     "https://httpbin.org/cookies/set?token=secreto-xyz&user_id=42" | \
     python3 -m json.tool

# Paso 2: Verificar que la sesión está activa
echo "=== Paso 2: Verificar sesión ==="
curl -s -b sesion.txt https://httpbin.org/cookies | python3 -m json.tool

# Paso 3: Request autenticado (GET con cookie de sesión)
echo "=== Paso 3: Request autenticado ==="
curl -s -b sesion.txt https://httpbin.org/get | \
     python3 -m json.tool | grep -A5 '"headers"'

# Paso 4: Verificar el archivo de cookies
echo "=== Paso 4: Archivo de sesión ==="
cat sesion.txt
```

**Preguntas:**
- ¿Cuántos pasos tiene un flujo típico de autenticación con cookies?
- ¿Qué pasaría si no guardaras la cookie entre el Paso 1 y el Paso 2?

---

## Tarea 5: Enviar cookie manual sin archivo

```bash
# Enviar un valor de cookie directamente en el comando
curl -b "token=test123" https://httpbin.org/cookies

# Múltiples cookies en una sola cadena
curl -b "token=test123; user_id=42; rol=admin" https://httpbin.org/cookies | \
     python3 -m json.tool
```

**Pregunta:** ¿Cuándo usarías `-b "clave=valor"` en lugar de `-b archivo.txt`?

---

## Tarea 6: Actualizar cookies durante la sesión

Usar `-b` y `-c` al mismo tiempo para leer Y escribir cookies:

```bash
# Limpiar sesión anterior
rm -f sesion-actualizable.txt

# Primera request: login, guarda cookies
curl -s -c sesion-actualizable.txt -L \
     "https://httpbin.org/cookies/set?token=v1" | python3 -m json.tool

echo "Cookies iniciales:"
cat sesion-actualizable.txt

# Segunda request: el servidor podría actualizar cookies; -b y -c al mismo tiempo
curl -s -b sesion-actualizable.txt -c sesion-actualizable.txt \
     -L "https://httpbin.org/cookies/set?token=v2&extra=nuevo" | python3 -m json.tool

echo "Cookies actualizadas:"
cat sesion-actualizable.txt
```

**Pregunta:** ¿Qué cambió en el archivo de cookies después de la segunda request?

---

## Entrega

Archivo `respuestas.md` con:
1. Status code y header Set-Cookie de la Tarea 1
2. Contenido del archivo cookie jar y explicación de cada campo (Tarea 2)
3. Header Cookie que curl envía (Tarea 3)
4. Output completo del flujo de la Tarea 4
5. Cuándo usar `-b "valor"` vs `-b archivo` (Tarea 5)
6. Diferencia en el archivo de cookies antes y después de la Tarea 6
