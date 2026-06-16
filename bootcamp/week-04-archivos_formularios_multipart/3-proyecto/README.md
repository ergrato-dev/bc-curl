# Proyecto Semana 4: File Manager CLI

## Descripcion

Crear un script `file-ops.sh` que funciona como un gestor de archivos de línea de comandos. El script acepta subcomandos para descargar archivos, subir archivos y enviar formularios. Usa `https://httpbin.org` como backend de prueba.

---

## Subcomandos requeridos

### download URL [output]

Descarga un archivo de la URL dada. Si se especifica `output`, guarda con ese nombre. Si no, usa el nombre del servidor con `-O`.

```bash
./file-ops.sh download https://httpbin.org/image/png
./file-ops.sh download https://httpbin.org/get datos.json
```

Comportamiento:
- Muestra barra de progreso durante la descarga
- Imprime el tamaño del archivo descargado al terminar
- Si la descarga falla, imprime el código de error de curl

### upload FILE

Sube un archivo al endpoint `https://httpbin.org/post` usando multipart. Imprime la confirmación de que el servidor recibió el archivo.

```bash
./file-ops.sh upload documento.txt
./file-ops.sh upload imagen.png
```

Comportamiento:
- Detecta automáticamente si el archivo existe; si no, imprime error y sale con código 1
- Imprime el nombre del archivo y su tamaño antes de subir
- Muestra del JSON de respuesta solo el campo `files` (lo que recibió el servidor)

### form-post key=value ...

Envía uno o más campos como form data URL-encoded a `https://httpbin.org/post`. Acepta cualquier número de pares `clave=valor`.

```bash
./file-ops.sh form-post nombre=Ana email=ana@test.com rol=admin
./file-ops.sh form-post "nombre=María García" ciudad=Rosario
```

Comportamiento:
- Cada par `clave=valor` se envía con `--data-urlencode` para manejar caracteres especiales
- Imprime del JSON de respuesta solo el campo `form`

---

## Estructura del script

```bash
#!/bin/bash
# file-ops.sh - Gestor de archivos CLI con curl

set -e

BASE_URL="https://httpbin.org"
SUBCOMANDO="$1"

usage() {
    echo "Uso: $0 SUBCOMANDO [ARGUMENTOS]"
    echo ""
    echo "Subcomandos:"
    echo "  download URL [output]     Descargar archivo de URL"
    echo "  upload FILE               Subir archivo con multipart"
    echo "  form-post key=val ...     Enviar formulario URL-encoded"
    exit 1
}

cmd_download() { ... }
cmd_upload()   { ... }
cmd_form_post() { ... }

case "$SUBCOMANDO" in
    download)   cmd_download "$@" ;;
    upload)     cmd_upload "$@" ;;
    form-post)  cmd_form_post "$@" ;;
    *)          usage ;;
esac
```

---

## Criterios de evaluacion

| Criterio | Puntos |
|----------|--------|
| `download` funciona con y sin nombre de salida | 20 |
| `download` muestra tamaño del archivo al terminar | 10 |
| `upload` valida que el archivo existe antes de subir | 15 |
| `upload` muestra el campo `files` de la respuesta | 15 |
| `form-post` usa `--data-urlencode` para cada campo | 20 |
| `form-post` muestra el campo `form` de la respuesta | 10 |
| Manejo de errores y mensaje de `usage` | 10 |

**Total: 100 puntos**

---

## Entrega

Archivo `file-ops.sh` en esta carpeta con permisos de ejecución (`chmod +x file-ops.sh`).

Archivo `demo.md` con el output de ejecutar los tres subcomandos con al menos un ejemplo cada uno.

---

## Pistas

Para extraer un campo del JSON de respuesta:

```bash
# Extraer el campo "files" de la respuesta
RESPUESTA=$(curl -s -F "archivo=@test.txt" https://httpbin.org/post)
echo "$RESPUESTA" | python3 -c "import sys, json; d=json.load(sys.stdin); print(json.dumps(d.get('files', {}), indent=2))"
```

Para calcular el tamaño de un archivo descargado:

```bash
BYTES=$(wc -c < archivo.bin)
echo "Descargado: ${BYTES} bytes"
```

Para usar `--data-urlencode` con argumentos variables:

```bash
ARGS=()
for par in "$@"; do
    ARGS+=(--data-urlencode "$par")
done
curl -s "${ARGS[@]}" https://httpbin.org/post
```
