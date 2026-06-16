# Ejercicio 01: Descargas de archivos

## Objetivo

Practicar la descarga de diferentes tipos de archivo, comparar los flags `-o` y `-O`, usar barra de progreso y simular la reanudación de una descarga interrumpida.

## Preparación

Crear un directorio de trabajo limpio:

```bash
mkdir ~/descargas-practica
cd ~/descargas-practica
```

---

## Tarea 1: Descargar tres tipos de archivo

Descargar cada uno con un nombre explícito usando `-o`:

```bash
# Imagen PNG
curl -o imagen.png https://httpbin.org/image/png

# Respuesta JSON
curl -o datos.json https://httpbin.org/get

# Texto plano
curl -o uuid.txt https://httpbin.org/uuid
```

Verificar los archivos descargados:

```bash
ls -lh imagen.png datos.json uuid.txt
wc -c imagen.png datos.json uuid.txt
```

**Preguntas:**
- ¿Cuál es el tamaño en bytes de cada archivo?
- ¿Qué content-type envió el servidor para cada uno? (pista: usá `-v` y buscá `Content-Type` en la respuesta)

---

## Tarea 2: Comparar -o vs -O

```bash
# Con -o: vos elegís el nombre
curl -o mi-imagen.png https://httpbin.org/image/jpeg

# Con -O: curl usa el nombre de la URL
curl -O https://httpbin.org/image/jpeg
```

**Preguntas:**
- ¿Con qué nombre quedó guardado el archivo descargado con `-O`?
- ¿Por qué ese nombre? ¿Cuál es el último segmento de la URL?
- ¿En qué situaciones preferirías `-o` sobre `-O`?

---

## Tarea 3: Barra de progreso

Descargar un archivo más grande con barra de progreso visible:

```bash
# stream-bytes/500000 genera 500 KB de datos
curl --progress-bar -o datos-grandes.bin https://httpbin.org/stream-bytes/500000

# Forma corta con -#
curl -# -o datos-grandes2.bin https://httpbin.org/stream-bytes/500000
```

Comparar con el progreso detallado por defecto (sin el flag):

```bash
curl -o datos-grandes3.bin https://httpbin.org/stream-bytes/500000
```

**Preguntas:**
- ¿Qué información muestra el progreso detallado que no muestra `--progress-bar`?
- ¿En qué situación preferirías cada uno?

---

## Tarea 4: Simular reanudación de descarga

Descargar parcialmente y reanudar:

```bash
# Paso 1: Iniciar descarga y cancelar a mano con Ctrl+C después de 1-2 segundos
curl --limit-rate 50k -o archivo-parcial.bin https://httpbin.org/stream-bytes/1000000

# Paso 2: Verificar tamaño parcial
wc -c archivo-parcial.bin

# Paso 3: Reanudar la descarga
curl -C - --limit-rate 50k -o archivo-parcial.bin https://httpbin.org/stream-bytes/1000000

# Paso 4: Verificar que el tamaño creció
wc -c archivo-parcial.bin
```

Nota: httpbin genera los bytes en el momento, así que el "archivo completo" será 1000000 bytes.

**Preguntas:**
- ¿Qué header envió curl al reanudar? (usá `-v` para verlo)
- ¿Qué respondió el servidor ante ese header?

---

## Entrega

Archivo `respuestas.md` con:
1. Output de `ls -lh` y `wc -c` de la Tarea 1
2. Nombre del archivo descargado con `-O` y explicación
3. Comparación del output de `--progress-bar` vs progreso detallado
4. Output de `wc -c` antes y después de reanudar (Tarea 4)
5. Respuestas a todas las preguntas
