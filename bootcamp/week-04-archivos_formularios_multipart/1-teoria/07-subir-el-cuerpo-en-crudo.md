# Subir el cuerpo en crudo

> No todas las subidas son formularios. Un bucket de S3, un registry de
> artefactos o una API de "reemplaza este archivo" esperan los bytes del
> archivo y nada más: ni boundary, ni nombre de campo, ni codificación.

![Diagrama de dos formas de subir un archivo en crudo: -T, que manda PUT, no pone Content-Type, añade el nombre del archivo si la URL acaba en barra y con -T - usa Transfer-Encoding chunked; y --data-binary @archivo, que manda POST con el Content-Type de formulario por defecto, que casi siempre hay que cambiar; en el centro, el cuerpo idéntico byte a byte al archivo](../0-assets/07-subir-el-cuerpo-en-crudo.svg)

## 🎯 Objetivos

- Subir un archivo como cuerpo de la petición, sin envoltorio, con `-T` y con `--data-binary @`
- Saber qué método, qué `Content-Type` y qué `Content-Length` pone cada uno
- Predecir la URL final de un `-T` cuando la URL acaba en `/`
- Subir desde un pipe con `-T -` y entender el `Transfer-Encoding: chunked`
- Reconocer el `Expect: 100-continue` y saber cuándo lo manda tu versión de curl
- Medir lo que se subió con `%{size_upload}` y `%{speed_upload}`

---

## 1. Qué problema resuelve

Multipart está pensado para formularios: varios campos, cada uno con su
nombre. Cuando la API solo quiere **un archivo**, el envoltorio sobra y a veces
estorba: una URL prefirmada de S3 calcula la firma sobre el cuerpo exacto, y un
boundary de más la invalida.

Para esos casos el cuerpo de la petición **es** el archivo. HTTP no necesita
nada más: el método dice qué hacer (`PUT` = "deja esto en esta URL"), el
`Content-Type` dice qué es, y el `Content-Length` cuánto mide.

---

## 2. Cómo funciona

### 2.1 Las dos herramientas

| | `-T archivo` (`--upload-file`) | `--data-binary @archivo` |
|---|---|---|
| Método por defecto | `PUT` | `POST` |
| `Content-Type` por defecto | **Ninguno** | `application/x-www-form-urlencoded` |
| Lectura | En streaming, a medida que envía | Entero en memoria antes de enviar |
| Desde stdin | `-T -` (chunked) | `--data-binary @-` |
| URL acabada en `/` | Le añade el nombre del archivo | La deja tal cual |
| Pensado para | Subir archivos | Mandar un cuerpo |

La fila de lectura importa con archivos grandes: `--data-binary @` carga el
archivo entero en la memoria de curl. Con 4 GB, son 4 GB de RAM. `-T` lo va
leyendo a trozos.

### 2.2 `-T`: PUT y sin Content-Type

```bash
printf 'hola\n' > nota.txt
curl -s -T nota.txt -v -o /dev/null http://localhost:8080/put 2>&1 \
  | grep -iE '^> (PUT|content-|expect)'
# > PUT /put HTTP/1.1
# > Content-Length: 5
# > Expect: 100-continue
```

No hay `Content-Type`. Muchos servidores asumen `application/octet-stream`;
otros lo exigen. Si lo exigen, `-H 'Content-Type: ...'`.

El `Expect: 100-continue` con solo 5 bytes es una particularidad de 7.81: con
`-T` lo manda siempre. curl 8.x (comprobado con 8.21) solo lo manda por encima
de 1 MB, igual que con `-F` y `--data-binary`. Si el servidor no responde el
`100`, curl espera un segundo antes de mandar el cuerpo igualmente; `-H 'Expect:'`
lo suprime.

### 2.3 `-T` con la URL acabada en barra

Si la URL acaba en `/`, curl entiende que es un directorio y le pega el nombre
del archivo:

```bash
curl -s -T nota.txt http://localhost:8080/anything/subidas/ | jq -r .url
# http://localhost:8080/anything/subidas/nota.txt
```

Es cómodo y peligroso a partes iguales: una barra de más en una variable
cambia el destino. Y admite globbing para subir varios a la vez:

```bash
curl -s -T "{nota.txt,meta.json}" http://localhost:8080/anything/subidas/ | jq -r .url
# http://localhost:8080/anything/subidas/nota.txt
# http://localhost:8080/anything/subidas/meta.json
```

### 2.4 `-T -`: desde un pipe, sin tamaño

```bash
printf 'abc' | curl -s -T - -v -o /dev/null http://localhost:8080/put 2>&1 \
  | grep -iE '^> (transfer-encoding|content-length)'
# > Transfer-Encoding: chunked
```

Leyendo de stdin, curl no sabe cuánto va a mandar, así que no puede poner
`Content-Length`. Usa `Transfer-Encoding: chunked`: el cuerpo va en trozos,
cada uno precedido de su tamaño, y un trozo de tamaño cero cierra.

Sirve para subir algo que se genera al vuelo sin pasar por el disco:

```bash
# pipefail: sin el, si tar falla a mitad se sube un .tar.gz truncado y el
# pipeline sale con 0, porque solo cuenta el codigo de curl.
set -o pipefail
tar czf - directorio/ | curl --fail-with-body --max-time 300 -sS -T - \
  https://artefactos.ejemplo.com/backups/hoy.tar.gz
```

Algunos servidores (y las URLs prefirmadas de S3) **no aceptan chunked**:
necesitan el `Content-Length` por adelantado. En ese caso, primero al disco.

### 2.5 `--data-binary @`: el cuerpo exacto, con el tipo que tú digas

```bash
# Sin -H, curl lo etiqueta como formulario y el servidor lo interpreta como
# tal: el contenido del archivo acaba convertido en un nombre de campo.
curl -s --data-binary @nota.txt http://localhost:8080/post \
  | jq -c '[.headers["Content-Type"][0], .form]'
# ["application/x-www-form-urlencoded",{"hola\n":[""]}]

# Con el tipo correcto, el servidor lo entiende.
printf '{"a":1}' > meta.json
curl -s --data-binary @meta.json -H 'Content-Type: application/json' \
  http://localhost:8080/post | jq -c .json
# {"a":1}
```

**Con `--data-binary`, el `-H 'Content-Type: ...'` no es opcional.**

---

## 3. Cómo se usa

### 3.1 Elegir el método

| Quieres | Comando |
|---|---|
| `PUT` del archivo | `curl -T archivo URL` |
| `POST` del archivo, en streaming | `curl -X POST -T archivo URL` |
| `POST` del archivo, tipo explícito | `curl --data-binary @archivo -H 'Content-Type: T' URL` |
| `PATCH` con el cuerpo de un archivo | `curl -X PATCH --data-binary @archivo -H 'Content-Type: T' URL` |

```bash
curl -s -X POST -T nota.txt http://localhost:8080/post | jq -c '[.method, .data]'
# ["POST","data:application/octet-stream;base64,aG9sYQo="]
```

El `data:` en base64 es cómo el laboratorio enseña un cuerpo que no es texto
declarado: lo que llegó es `hola\n` exacto.

### 3.2 Una subida de producción

```bash
# --fail-with-body: si el servidor rechaza la subida, su motivo esta en el
#   cuerpo de la respuesta.
# --max-time: generoso, la subida tarda lo que pese el archivo.
# --retry: un PUT es idempotente; repetirlo deja el mismo resultado.
curl --fail-with-body --max-time 300 --retry 3 -sS \
  -T informe.pdf -H 'Content-Type: application/pdf' \
  --config ~/.api-auth \
  https://api.ejemplo.com/v1/documentos/informe.pdf
```

El `--retry` es seguro aquí porque `PUT` es idempotente (Semana 02). Con un
`POST` que crea un recurso, reintentar puede crear dos.

### 3.3 Medir la subida

```bash
curl -s -T nota.txt -o /dev/null \
  -w 'subidos %{size_upload} bytes a %{speed_upload} B/s, codigo %{http_code}\n' \
  http://localhost:8080/put
# subidos 5 bytes a 3725 B/s, codigo 200
```

### 3.4 Un límite del laboratorio

El httpbin del laboratorio rechaza con un `400` los cuerpos de más de 1 MB.
Para las prácticas, archivos pequeños. Si ves un 400 subiendo algo grande, es
el laboratorio, no tu comando.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `--data-binary @f` sin `-H 'Content-Type'` | Sale etiquetado como formulario y el servidor lo malinterpreta | `-H 'Content-Type: ...'` siempre |
| `-d @archivo` para subir un archivo | Quita los saltos de línea: el archivo llega distinto | `--data-binary @archivo` o `-T` |
| `--data-binary @` con archivos de gigas | Se carga entero en memoria | `-T` |
| `-T -` contra un servidor que exige `Content-Length` | Rechaza el chunked con un 411 o un 400 | Escribir a disco y `-T archivo` |
| `"$BASE/$DIR/"` con `-T` y `$DIR` vacío | La URL queda `$BASE//` y curl le añade el nombre en un sitio inesperado | Construir la URL completa, con el nombre explícito |
| `--retry` en un `POST` que crea recursos | Un reintento tras un timeout puede crear dos | Reintentos solo con métodos idempotentes, o con clave de idempotencia (Semana 07) |

---

## 5. Trucos

```bash
# Ver el chunked por dentro: el tamano de cada trozo en hexadecimal antes de
# cada trozo, y el 0 final.
printf 'abc' | curl -s -T - --trace-ascii - -o /dev/null http://localhost:8080/put \
  | grep -A4 '=> Send data' | head -6
```

```bash
# Comprobar que lo que llego es exactamente lo que mandaste, comparando el
# base64 que devuelve /put. Es base64url: el tr lo pasa al alfabeto estandar.
curl -s -T nota.txt http://localhost:8080/put | jq -r .data | cut -d, -f2 \
  | tr '_-' '/+' | base64 -d | cmp - nota.txt && echo identico
# identico
```

```bash
# Subir con una velocidad maxima, para no saturar la subida de la oficina.
curl -s --limit-rate 100K -T nota.txt -o /dev/null http://localhost:8080/put
```

---

## 📚 Recursos Adicionales

- [manpage de curl — `-T`](https://curl.se/docs/manpage.html#-T) — la barra final, el globbing y el `-` de stdin
- [manpage de curl — `--data-binary`](https://curl.se/docs/manpage.html#--data-binary) — y su diferencia con `-d`
- [RFC 9112 §7.1 — Chunked Transfer Coding](https://datatracker.ietf.org/doc/html/rfc9112#section-7.1) — el formato de los trozos
- [RFC 9110 §10.1.1 — Expect](https://datatracker.ietf.org/doc/html/rfc9110#section-10.1.1) — `100-continue` y para qué sirve

---

## ✅ Checklist de Verificación

- [ ] He subido el mismo archivo con `-T` y con `--data-binary @` y sé qué método y qué `Content-Type` llevó cada uno
- [ ] He predicho la URL final de un `-T` contra una URL acabada en `/`
- [ ] He subido desde un pipe con `-T -` y he visto el `Transfer-Encoding: chunked`
- [ ] He visto el formulario fantasma de `--data-binary` sin `-H`, y lo he arreglado
- [ ] Sé cuándo manda `Expect: 100-continue` mi versión de curl
- [ ] Sé por qué `--retry` es seguro con `PUT` y no con un `POST` que crea

---

| Anterior | Siguiente |
|---|---|
| [06 — Multipart por dentro](06-multipart-por-dentro.md) | [08 — Elegir cómo subir](08-elegir-como-subir.md) |
