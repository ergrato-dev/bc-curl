# Glosario - Semana 4

## Terminos

**Multipart**
Formato de encoding HTTP que divide el body de un request en varias partes separadas por un delimitador (boundary). Diseñado para transmitir archivos binarios y datos de texto en un mismo request.

**form-data**
El valor del atributo `enctype` en formularios HTML que activa el encoding multipart. También el sufijo del Content-Type: `multipart/form-data`.

**URL-encoded** (application/x-www-form-urlencoded)
Formato de encoding donde los datos de formulario se representan como pares `clave=valor` separados por `&`, con caracteres especiales representados en percent-encoding. Ejemplo: `nombre=Ana&ciudad=S%C3%A3o+Paulo`.

**MIME type** (Multipurpose Internet Mail Extensions)
Identificador estándar para el formato de un archivo o contenido. Compuesto por tipo y subtipo separados por `/`. Ejemplos: `image/jpeg`, `application/json`, `text/plain`, `application/pdf`.

**Content-Disposition**
Header HTTP que indica cómo debe tratarse el contenido adjunto. En multipart, cada parte lleva `Content-Disposition: form-data; name="campo"; filename="archivo.ext"` para identificar a qué campo pertenece.

**Binary** (archivo binario)
Archivo cuyo contenido no es texto plano sino bytes arbitrarios que representan datos codificados (imágenes, audio, video, ejecutables). No puede incluirse directamente en JSON sin codificación previa (como Base64).

**Boundary**
Delimitador único generado por curl para separar las partes de un body multipart. Aparece en el Content-Type: `multipart/form-data; boundary=abc123`. Cada parte del body empieza con `--boundary` y el body termina con `--boundary--`.

**Progress bar**
Representación visual del progreso de una descarga o subida. En curl, `--progress-bar` (o `-#`) muestra una barra compacta tipo `[ ====>     ]`. El modo por defecto muestra una tabla con velocidad, tiempo estimado y bytes transferidos.

**--limit-rate**
Flag de curl para limitar la velocidad de transferencia (upload y download). Acepta valores en bytes (`500`), kilobytes (`100k`), megabytes (`2m`) o gigabytes (`1g`). Útil para simular conexiones lentas o no saturar la red.

**--retry**
Flag de curl que indica cuántas veces reintentar un request si falla por error de red o timeout. Por defecto no reintenta. Se complementa con `--retry-delay` (pausa entre intentos) y `--retry-max-time` (tiempo total máximo para todos los intentos).
