# Ejercicio 03: Subir archivos con multipart

## Objetivo

Practicar el upload de archivos usando `-F`, especificar tipos MIME explícitos, y verificar en la respuesta de httpbin que el servidor recibió el archivo correctamente.

---

## Preparación: Crear archivos de prueba

```bash
mkdir ~/upload-practica
cd ~/upload-practica

# Archivo de texto
echo "Este es el contenido de mi archivo de prueba." > documento.txt

# Archivo JSON simulado
cat > datos.json << 'EOF'
{
  "usuario": "ana",
  "rol": "admin",
  "activo": true
}
EOF

# Archivo CSV simulado
cat > reporte.csv << 'EOF'
nombre,apellido,edad,ciudad
Ana,Lopez,30,Buenos Aires
Carlos,Garcia,25,Mendoza
Maria,Rodriguez,35,Rosario
EOF

# Crear una imagen PNG mínima (1x1 pixel, PNG válido)
# Si no tenés una imagen real, descargá una de httpbin
curl -s -o imagen.png https://httpbin.org/image/png
```

---

## Tarea 1: Upload básico de un archivo de texto

```bash
curl -s -F "archivo=@documento.txt" \
     https://httpbin.org/post | python3 -m json.tool
```

Inspeccionar la respuesta:
- ¿En qué campo aparece el archivo enviado?
- ¿Qué MIME type detectó curl para el archivo `.txt`?

```bash
# Ver el Content-Type que curl asignó automáticamente
curl -v -F "archivo=@documento.txt" https://httpbin.org/post 2>&1 | grep -i "content-type"
```

---

## Tarea 2: Upload con MIME type explícito

```bash
# Forzar application/pdf aunque el archivo es texto
curl -s -F "doc=@documento.txt;type=application/pdf" \
     https://httpbin.org/post | python3 -m json.tool

# JSON con tipo explícito
curl -s -F "datos=@datos.json;type=application/json" \
     https://httpbin.org/post | python3 -m json.tool

# CSV con tipo explícito
curl -s -F "reporte=@reporte.csv;type=text/csv" \
     https://httpbin.org/post | python3 -m json.tool
```

**Pregunta:** ¿Aparece el tipo MIME en la respuesta de httpbin? ¿Dónde?

---

## Tarea 3: Múltiples archivos en un request

```bash
curl -s \
     -F "documento=@documento.txt" \
     -F "datos=@datos.json;type=application/json" \
     -F "reporte=@reporte.csv;type=text/csv" \
     https://httpbin.org/post | python3 -m json.tool
```

**Pregunta:** ¿Cuántos archivos aparecen en el campo `files` de la respuesta?

---

## Tarea 4: Upload con filename alternativo

```bash
# El servidor verá "informe-final.txt" aunque el archivo local se llama "documento.txt"
curl -s -F "archivo=@documento.txt;filename=informe-final.txt" \
     https://httpbin.org/post | python3 -m json.tool
```

**Pregunta:** ¿Qué nombre aparece en la respuesta?

---

## Tarea 5: Inspeccionar el body completo con -v

Usar `-v` para ver el body multipart que curl construye y envía:

```bash
curl -v -F "campo=valor" -F "archivo=@documento.txt" \
     https://httpbin.org/post 2>&1 | head -60
```

Identificar en el output:
- El valor del header `Content-Type` (debe incluir `boundary=`)
- Las partes del body separadas por el boundary
- El `Content-Disposition` de cada parte

---

## Tarea 6: Upload de imagen

```bash
curl -s -F "foto=@imagen.png;type=image/png" \
     https://httpbin.org/post | python3 -m json.tool
```

**Pregunta:** ¿Cómo aparece el contenido de la imagen en la respuesta? ¿Por qué es diferente al texto?

---

## Entrega

Archivo `respuestas.md` con:
1. Campo donde aparece el archivo en la respuesta de httpbin (Tarea 1)
2. MIME type que curl asignó automáticamente a `.txt`
3. Output de la Tarea 3 (múltiples archivos)
4. Filename que aparece en la Tarea 4
5. Identificación del boundary y las partes en la Tarea 5
6. Explicación de cómo aparece la imagen en la respuesta (Tarea 6)
