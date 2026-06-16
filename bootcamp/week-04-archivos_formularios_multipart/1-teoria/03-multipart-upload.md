# Multipart upload: subir archivos con curl

## Qué es multipart/form-data

`multipart/form-data` es un formato de encoding diseñado para transmitir archivos binarios junto con datos de texto en un mismo request HTTP. A diferencia de URL-encoded, puede manejar datos arbitrarios (imágenes, PDFs, video) sin corromperlos.

El nombre "multipart" viene de que el body se divide en partes separadas por un delimitador llamado "boundary":

```
--boundary-abc123
Content-Disposition: form-data; name="nombre"

Ana
--boundary-abc123
Content-Disposition: form-data; name="foto"; filename="perfil.jpg"
Content-Type: image/jpeg

<bytes binarios del archivo>
--boundary-abc123--
```

curl construye este formato automáticamente cuando usás `-F`.

---

## El flag -F: enviar campos multipart

`-F` agrega un campo al request multipart. Cada `-F` es un campo separado:

```bash
# Campo de texto simple
curl -F "nombre=Ana" https://httpbin.org/post

# Subir un archivo: usá @ seguido de la ruta
curl -F "archivo=@/ruta/al/archivo.txt" https://httpbin.org/post

# Subir archivo con campo de texto en el mismo request
curl -F "nombre=Ana" -F "archivo=@./datos.txt" https://httpbin.org/post
```

Cuando usás `-F`, curl automáticamente setea el Content-Type a `multipart/form-data; boundary=...`. No necesitás especificarlo con `-H`.

---

## Crear un archivo de prueba y subirlo

```bash
# Crear archivo de prueba
echo "Contenido de prueba para upload" > test.txt

# Subir a httpbin
curl -F "documento=@test.txt" https://httpbin.org/post
```

La respuesta de httpbin mostrará el archivo en el campo `files`:

```json
{
  "files": {
    "documento": "Contenido de prueba para upload\n"
  },
  "form": {}
}
```

---

## Especificar el tipo MIME explícito

Por defecto curl detecta el MIME type según la extensión del archivo. Para forzar un tipo específico usá `;type=`:

```bash
# Forzar application/pdf aunque el archivo no tenga extensión .pdf
curl -F "doc=@informe;type=application/pdf" https://httpbin.org/post

# Forzar image/jpeg
curl -F "foto=@imagen.jpg;type=image/jpeg" https://httpbin.org/post

# Subir JSON como archivo
curl -F "datos=@payload.json;type=application/json" https://httpbin.org/post
```

---

## Especificar un filename diferente

Podés cambiar el nombre que el servidor ve para el archivo sin renombrar el archivo local:

```bash
# El servidor verá "reporte-final.pdf" aunque el archivo local se llame "borrador.pdf"
curl -F "doc=@borrador.pdf;filename=reporte-final.pdf" https://httpbin.org/post
```

---

## Ver lo que curl envía con -v

Para entender qué está pasando bajo el capó:

```bash
curl -v -F "campo=valor" -F "archivo=@test.txt" https://httpbin.org/post 2>&1 | head -40
```

Verás algo así en los headers de salida:

```
> POST /post HTTP/2
> Host: httpbin.org
> Content-Length: 312
> Content-Type: multipart/form-data; boundary=------------------------abc123def456
```

Y el body con las partes separadas por el boundary.

---

## Combinar múltiples archivos y campos

```bash
# Simular upload de perfil de usuario
curl -F "nombre=Ana Lopez" \
     -F "email=ana@ejemplo.com" \
     -F "rol=admin" \
     -F "foto=@perfil.jpg;type=image/jpeg" \
     -F "cv=@curriculum.pdf;type=application/pdf" \
     https://httpbin.org/post
```

---

## Resumen de sintaxis -F

| Sintaxis | Qué hace |
|----------|---------|
| `-F "campo=valor"` | Campo de texto |
| `-F "campo=@archivo"` | Sube el archivo, MIME detectado automáticamente |
| `-F "campo=@archivo;type=image/png"` | Sube con MIME explícito |
| `-F "campo=@archivo;filename=nuevo-nombre.ext"` | Sube con nombre diferente |
| `-F "campo=<archivo"` | Lee el contenido del archivo como texto (sin filename) |
