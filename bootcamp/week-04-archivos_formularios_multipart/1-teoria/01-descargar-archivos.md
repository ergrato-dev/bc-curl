# Descargar archivos con curl

## El flag -o: nombre que tú eliges

Por defecto curl imprime la respuesta en stdout. Para guardar el contenido en un archivo usás `-o` seguido del nombre que querés darle:

```bash
# Descargar imagen y guardarla como logo.png
curl -o logo.png https://httpbin.org/image/png

# Descargar JSON y guardarlo
curl -o respuesta.json https://httpbin.org/get

# Descargar archivo de texto
curl -o robots.txt https://www.google.com/robots.txt
```

Verificar el tamaño del archivo descargado:

```bash
wc -c logo.png
# 8090 logo.png  (muestra el tamaño en bytes)

ls -lh logo.png
# -rw-r--r-- 1 user user 7.9K Jun 15 10:00 logo.png
```

---

## El flag -O: nombre del servidor

`-O` (mayúscula) descarga el archivo usando el nombre que aparece en la URL. Útil cuando el nombre del archivo ya es correcto y no querés escribirlo a mano:

```bash
# Descarga como "robots.txt"
curl -O https://www.google.com/robots.txt

# Descarga como "image" (el último segmento de la URL)
curl -O https://httpbin.org/image/png
```

Importante: `-O` usa exactamente el último segmento de la URL como nombre. Si la URL termina en `/` o en un path sin extensión, el nombre puede quedar mal. En ese caso usá `-o` con nombre explícito.

---

## Mostrar progreso con --progress-bar

Por defecto curl muestra una tabla de progreso detallada. Para una barra más limpia:

```bash
# Barra de progreso estilo [ ====>     ]
curl --progress-bar -o archivo.bin https://httpbin.org/stream-bytes/1000000

# Forma corta
curl -# -o archivo.bin https://httpbin.org/stream-bytes/1000000
```

Para suprimir todo el progreso (modo silencioso):

```bash
curl -s -o archivo.json https://httpbin.org/get
```

---

## Continuar una descarga interrumpida con -C -

Si una descarga falló a la mitad, `-C -` le dice a curl que detecte el offset automáticamente y continúe desde donde quedó:

```bash
# Primera descarga (la interrumpís con Ctrl+C)
curl -o archivo-grande.bin https://httpbin.org/stream-bytes/5000000

# Continuar desde donde quedó
curl -C - -o archivo-grande.bin https://httpbin.org/stream-bytes/5000000
```

El guión `-` después de `-C` le indica a curl que detecte solo el tamaño actual del archivo. También podés especificar un offset manual: `-C 1024` para empezar desde el byte 1024.

Para que `-C -` funcione el servidor debe soportar el header `Range`. La mayoría de los servidores modernos lo hacen; curl envía automáticamente `Range: bytes=N-` donde N es el tamaño del archivo parcial.

---

## Descargar múltiples archivos en un comando

Podés pasar varias URLs en un mismo comando curl. Con `-O` para cada una:

```bash
curl -O https://httpbin.org/image/png \
     -O https://httpbin.org/image/jpeg \
     -O https://httpbin.org/image/svg
```

O con nombres distintos usando múltiples `-o` y URLs:

```bash
curl -o imagen1.png https://httpbin.org/image/png \
     -o datos.json  https://httpbin.org/get \
     -o texto.txt   https://httpbin.org/robots.txt
```

curl procesa las URLs en secuencia, no en paralelo. Para descargas paralelas se usa `--parallel` (curl 7.66+) o herramientas como `xargs`.

---

## Ejemplo completo

```bash
# Descargar PDF público, imagen y JSON; mostrar progreso en cada uno
curl --progress-bar -o manual.pdf \
     https://www.w3.org/WAI/WCAG21/Techniques/pdf/PDF1/table.pdf

curl --progress-bar -o logo.png \
     https://httpbin.org/image/png

curl -s -o info.json \
     https://httpbin.org/get

# Ver qué descargamos
ls -lh manual.pdf logo.png info.json
```

---

## Resumen de flags de descarga

| Flag | Qué hace |
|------|---------|
| `-o nombre` | Guarda en el archivo con el nombre que especificás |
| `-O` | Guarda usando el nombre de la URL |
| `--progress-bar` / `-#` | Barra de progreso compacta |
| `-s` | Sin progreso ni mensajes de error (silencioso) |
| `-C -` | Continúa una descarga interrumpida |
| `--limit-rate 100k` | Limita la velocidad a 100 KB/s |
