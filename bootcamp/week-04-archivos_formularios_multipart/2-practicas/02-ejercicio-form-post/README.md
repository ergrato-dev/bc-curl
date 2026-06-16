# Ejercicio 02: Formularios URL-encoded

## Objetivo

Enviar datos de formulario con `-d` y `--data-urlencode`, entender la diferencia entre ambos, y ver cómo se codifican los caracteres especiales.

---

## Tarea 1: Formulario básico con -d

Enviar un formulario simple a httpbin:

```bash
curl -s -d "nombre=Ana&apellido=Lopez&edad=30&ciudad=Buenos%20Aires" \
     https://httpbin.org/post | python3 -m json.tool
```

Inspeccionar la respuesta:
- ¿En qué campo del JSON aparecen los datos del formulario?
- ¿Qué Content-Type envió curl? Verificar con `-v`:

```bash
curl -v -d "nombre=Ana" https://httpbin.org/post 2>&1 | grep -E "Content-Type|> POST"
```

---

## Tarea 2: El problema de los caracteres especiales

Intentar enviar un valor con `&` sin encoding:

```bash
curl -s -d "mensaje=Hola & bienvenidos al curso" \
     https://httpbin.org/post | python3 -m json.tool
```

**Pregunta:** ¿Qué recibió el servidor en el campo `mensaje`? ¿Por qué es diferente a lo que enviaste?

Ahora encodear el `&` manualmente:

```bash
curl -s -d "mensaje=Hola %26 bienvenidos al curso" \
     https://httpbin.org/post | python3 -m json.tool
```

**Pregunta:** ¿Qué cambió en la respuesta?

---

## Tarea 3: --data-urlencode con valores complejos

Usar `--data-urlencode` para que curl codifique automáticamente:

```bash
# Valor con espacios
curl -s --data-urlencode "nombre=María José García" \
     https://httpbin.org/post | python3 -m json.tool

# Valor con & y =
curl -s --data-urlencode "formula=a & b = c" \
     https://httpbin.org/post | python3 -m json.tool

# Múltiples campos con caracteres especiales
curl -s \
     --data-urlencode "nombre=José María" \
     --data-urlencode "ciudad=São Paulo" \
     --data-urlencode "comentario=Muy buena clase & excelente contenido" \
     https://httpbin.org/post | python3 -m json.tool
```

**Preguntas:**
- ¿Cómo aparecen los valores en la respuesta de httpbin?
- ¿Qué diferencia hay entre el valor enviado y cómo se ve en la wire (con `-v`)?

---

## Tarea 4: Comparar -d vs --data-urlencode en el wire

Ver exactamente qué envía curl al servidor en ambos casos:

```bash
# Con -d (sin encoding automático)
curl -v -d "nombre=María José" https://httpbin.org/post 2>&1 | grep -A5 "< HTTP\|> Content"

# Con --data-urlencode (con encoding automático)
curl -v --data-urlencode "nombre=María José" https://httpbin.org/post 2>&1 | grep -A5 "< HTTP\|> Content"
```

También podés ver el body que curl envía usando `--trace-ascii -`:

```bash
curl --trace-ascii - -d "nombre=Ana&rol=admin" https://httpbin.org/post 2>&1 | grep -A3 "=> Send"
```

---

## Tarea 5: Leer datos desde un archivo

Crear un archivo con los datos del formulario:

```bash
cat > form-data.txt << 'EOF'
nombre=Carlos Ruiz
cargo=desarrollador backend
tecnologias=Python, Go & Rust
EOF
```

Usar `--data-urlencode` para leer desde archivo:

```bash
curl -s --data-urlencode "bio@form-data.txt" \
     https://httpbin.org/post | python3 -m json.tool
```

**Pregunta:** ¿Cómo aparece el contenido del archivo en la respuesta?

---

## Entrega

Archivo `respuestas.md` con:
1. Qué campo de la respuesta httpbin contiene los datos de formulario
2. Output de la Tarea 2 antes y después del encoding manual
3. Output de la Tarea 3 con los tres valores con caracteres especiales
4. Explicación de la diferencia entre `-d` y `--data-urlencode`
5. Output de la Tarea 5
