# Elegir cómo subir

> Crudo, multipart o JSON con base64: los tres llevan el mismo archivo al
> servidor. La elección no es tuya — la hace el servidor —, pero saber qué
> cuesta cada uno te dice qué preguntar cuando la documentación no lo aclara.

![Diagrama comparativo del mismo archivo de 30.000 bytes subido de tres formas: en crudo con -T, 30.000 bytes y sin metadatos; en multipart con -F, 30.200 bytes con nombre y tipo por parte; en JSON con el contenido en base64, 40.046 bytes, un tercio más, y el archivo entero en memoria en los dos extremos](../0-assets/08-elegir-como-subir.svg)

## 🎯 Objetivos

- Reconocer en la documentación de una API cuál de los tres formatos espera
- Medir lo que cuesta cada formato con `%{size_upload}` sobre el mismo archivo
- Explicar de dónde sale el 33 % de más del base64
- Construir una subida JSON con base64 sin meter el archivo en la línea de comandos
- Elegir el formato cuando el servidor acepta más de uno

---

## 1. Qué problema resuelve

Las APIs suben archivos de tres formas, y la documentación rara vez usa las
mismas palabras:

| La documentación dice | Quiere decir |
|---|---|
| "Send the file as the request body", "binary upload", `Content-Type: application/octet-stream` | **Crudo**: `-T` o `--data-binary @` |
| "multipart/form-data", "form field `file`", "as a form upload" | **Multipart**: `-F` |
| "base64-encoded content", un campo `content` o `data` dentro de un JSON | **JSON** con el archivo en base64 |

Mandar el formato equivocado da errores poco explicativos: un `400` genérico,
un `415 Unsupported Media Type`, o — el peor — un `200` con el archivo vacío o
convertido en texto.

---

## 2. Cómo funciona

### 2.1 El mismo archivo, tres veces

Un archivo binario de 30.000 bytes, subido de las tres formas:

```bash
curl -s -o foto.bin "http://localhost:8080/bytes/30000?seed=7"

curl -s -T foto.bin -o /dev/null -w 'crudo     %{size_upload}\n' \
  http://localhost:8080/put
curl -s -F 'foto=@foto.bin' -o /dev/null -w 'multipart %{size_upload}\n' \
  http://localhost:8080/post
base64 -w0 foto.bin > foto.b64
jq -n --rawfile c foto.b64 '{nombre: "foto.bin", contenido: $c}' \
  | curl -s --data-binary @- -H 'Content-Type: application/json' \
         -o /dev/null -w 'json      %{size_upload}\n' http://localhost:8080/post
# crudo     30000
# multipart 30200
# json      40046
```

`?seed=7` hace que `/bytes` devuelva siempre los mismos bytes: así tu número y
el de esta tabla coinciden.

### 2.2 Qué cuesta cada uno

| | Crudo | Multipart | JSON + base64 |
|---|---|---|---|
| Bytes sobre el archivo | +0 | +~200 (boundary y cabeceras de parte) | **+33 %** |
| Metadatos junto al archivo | En headers o en la URL | En otras partes del mismo cuerpo | En otros campos del JSON |
| Varios archivos por petición | No | Sí | Sí |
| Streaming (sin cargar en memoria) | Sí, con `-T` | Sí | **No**: hay que codificar entero |
| Content-Type del archivo | El de la petición | Uno por parte | Lo declara un campo, si existe |
| Típico de | S3 y almacenes de objetos, registries, WebDAV | Formularios web, "adjuntar archivo" | APIs que solo hablan JSON (GitHub contents, algunas de correo) |

### 2.3 De dónde sale el 33 %

base64 convierte cada 3 bytes en 4 caracteres: 4/3 = 1,33. Los 30.000 bytes se
convierten en 40.000 caracteres, y los 46 restantes son el `{"nombre":...}`.

Y eso es solo el tamaño. Los dos extremos tienen que tener el archivo **entero
en memoria** para codificarlo y decodificarlo: no hay streaming posible dentro
de un string JSON. Para un avatar de 50 KB da igual. Para un vídeo de 2 GB, el
JSON no es una opción.

### 2.4 Lo que no cambia: el contenido

Las tres formas entregan los mismos bytes. Con JSON, el servidor decodifica el
base64 y recupera el original:

```bash
jq -n --rawfile c foto.b64 '{nombre: "foto.bin", contenido: $c}' \
  | curl -s --data-binary @- -H 'Content-Type: application/json' \
         http://localhost:8080/post \
  | jq -r '.json.contenido' | base64 -d | cmp - foto.bin && echo identico
# identico
```

---

## 3. Cómo se usa

### 3.1 Construir el JSON sin el archivo en el argv

La tentación es esta:

```bash
# MAL: el archivo entero, codificado, como argumento de jq.
jq -n --arg c "$(base64 -w0 foto.bin)" '{contenido: $c}'
```

Funciona con archivos pequeños y revienta antes de lo que parece. En Linux un
**solo argumento** no puede pasar de 128 KiB (`MAX_ARG_STRLEN`), aunque el
total del argv (`getconf ARG_MAX`) sea de 2 MB. Con el 33 % del base64, un
archivo de unos 96 KB ya no cabe:

```bash
head -c 200000 /dev/urandom > med.bin
jq -n --arg c "$(base64 -w0 med.bin)" '{}'
# bash: /usr/bin/jq: Argument list too long
```

Además, si el archivo es sensible, queda en `ps`.

La forma correcta pasa por un archivo y por pipes:

```bash
base64 -w0 foto.bin > foto.b64            # en macOS: base64 -i foto.bin > foto.b64
jq -n --rawfile c foto.b64 '{nombre: "foto.bin", contenido: $c}' \
  | curl --fail-with-body --max-time 60 -sS \
         --data-binary @- -H 'Content-Type: application/json' \
         http://localhost:8080/post >/dev/null && echo subido
```

`--rawfile` (jq 1.6+) lee el archivo como string sin tocarlo, y
`--data-binary @-` lee el cuerpo de stdin. Nada pasa por el argv.

`-w0` quita los saltos de línea que GNU `base64` mete cada 76 caracteres: un
salto de línea dentro de un string JSON lo invalida.

### 3.2 Cuando el servidor acepta más de uno

| Si… | Elige |
|---|---|
| El archivo pesa más de unos pocos MB | Crudo con `-T`: streaming, sin sobrecoste |
| Tienes que mandar metadatos con el archivo en la misma petición | Multipart |
| Son varios archivos en una sola operación | Multipart |
| La URL es prefirmada (S3, GCS) | Crudo, sin `Content-Type` distinto del firmado |
| La API no acepta otra cosa | JSON, y asumes el 33 % |

### 3.3 Preguntar al servidor

Si la documentación no lo dice, el error lo suele decir. Manda lo más simple y
lee la respuesta:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -T foto.bin https://api.ejemplo.com/v1/upload
# 415   ← no quiere crudo: prueba multipart
```

Un `415 Unsupported Media Type` es el servidor diciéndote el formato
equivocado. Un `400` con el cuerpo de la respuesta (`--fail-with-body`) suele
decir qué campo esperaba.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `--arg c "$(base64 archivo)"` | Revienta con archivos de más de ~96 KB (128 KiB por argumento) y deja el contenido en `ps` | `--rawfile` y pipes |
| `base64` sin `-w0` dentro de un JSON | Los saltos de línea cada 76 caracteres invalidan el string | `base64 -w0` (o `-i` en macOS, que no parte líneas) |
| JSON con base64 para archivos grandes | +33 % de bytes y el archivo entero en memoria en los dos extremos | Crudo o multipart |
| Multipart para un único archivo sin metadatos contra una URL prefirmada | El cuerpo ya no es el archivo y la firma no cuadra | Crudo con `-T` |
| Elegir el formato por costumbre | El servidor decide; el formato equivocado da 400, 415 o, peor, un 200 con basura | Leer la documentación y, si duda, el error |
| Probar formatos contra una API de producción a ciegas | Cada intento puede crear un recurso a medias | Probar contra el laboratorio o un entorno de pruebas |

---

## 5. Trucos

```bash
# El factor exacto de base64 para cualquier archivo.
echo "scale=3; $(base64 -w0 foto.bin | wc -c) / $(wc -c < foto.bin)" | bc
# 1.333
```

```bash
# Tamano maximo del argv entero. El de UN argumento es fijo en Linux:
# 131072 bytes (128 KiB), y es el que revienta primero.
getconf ARG_MAX
# 2097152
```

```bash
# Las tres subidas de un vistazo, en una funcion.
medir() { curl -s -o /dev/null -w "%{size_upload}\n" "$@"; }
medir -T foto.bin http://localhost:8080/put
medir -F 'f=@foto.bin' http://localhost:8080/post
```

---

## 📚 Recursos Adicionales

- [RFC 4648 §4 — Base64](https://datatracker.ietf.org/doc/html/rfc4648#section-4) — por qué 3 bytes son 4 caracteres
- [GitHub REST API — Create or update file contents](https://docs.github.com/en/rest/repos/contents#create-or-update-file-contents) — un caso real de archivo en base64 dentro de JSON
- [AWS S3 — Uploading objects with presigned URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/PresignedUrlUploadObject.html) — un caso real de subida en crudo con `PUT`
- [Manual de jq — `--rawfile`](https://jqlang.github.io/jq/manual/#invoking-jq) — cómo meter un archivo en un string sin pasar por el argv

---

## ✅ Checklist de Verificación

- [ ] He subido `foto.bin` de las tres formas y he medido los bytes con `%{size_upload}`
- [ ] Sé explicar el 33 % del base64 con una división
- [ ] He construido el JSON con `--rawfile` y he comprobado con `cmp` que llega idéntico
- [ ] He visto el `Argument list too long` de `--arg` con un archivo de 200 KB, y sé qué límite lo provoca
- [ ] Sé qué formato pedir según lo que diga la documentación de la API
- [ ] Sé qué significa un `415` en una subida

---

| Anterior | Siguiente |
|---|---|
| [07 — Subir el cuerpo en crudo](07-subir-el-cuerpo-en-crudo.md) | [Prácticas](../2-practicas/01-descargar-y-reanudar.md) |
