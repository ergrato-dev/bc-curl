# Práctica 04 — Subir en crudo y elegir

> **Duración**: 50 min · **Entregables**: `tres-formatos.md`

Vas a subir archivos sin envoltorio con `-T` y con `--data-binary @`, ver qué
método y qué cabeceras pone cada uno, subir desde un pipe sin pasar por el
disco, y terminar subiendo el mismo archivo en los tres formatos para medir lo
que cuesta cada uno.

**Antes de empezar**:

```bash
./scripts/start.sh
mkdir -p ~/bc-curl-trabajo/semana-04/p4 && cd ~/bc-curl-trabajo/semana-04/p4
printf 'hola\n' > nota.txt
printf '{"a":1}' > meta.json
# 30.000 bytes binarios, siempre los mismos gracias a seed.
curl -fsS -o foto.bin "http://localhost:8080/bytes/30000?seed=7"
wc -c < foto.bin
# 30000
```

El httpbin del laboratorio rechaza cuerpos de más de 1 MB con un `400`. En esta
práctica todos los archivos son pequeños a propósito.

---

## Paso 1: `-T` y lo que manda

**Por qué**: `-T` es la subida más simple que existe: el cuerpo es el archivo.
Pero elige el método y las cabeceras por ti, y hay que saber cuáles.

**Comando**:

```bash
curl -s -T nota.txt -v -o /dev/null http://localhost:8080/put 2>&1 \
  | grep -iE '^> (PUT|POST|content-|expect|transfer)'
```

**Verifica**:

```bash
# > PUT /put HTTP/1.1
# > Content-Length: 5
# > Expect: 100-continue       ← curl 7.81 lo manda siempre con -T; 8.x solo > 1 MB
```

`PUT`, el tamaño exacto, y **ningún `Content-Type`**.

---

## Paso 2: Comprobar que llegó idéntico

**Por qué**: una subida que "funciona" con un 200 no garantiza que el servidor
recibiera los mismos bytes. El laboratorio devuelve lo que recibió en base64;
decodificarlo y compararlo es la prueba.

**Comando**:

```bash
# El laboratorio usa base64url, el alfabeto del JWT de la Semana 03: - y _
# en lugar de + y /. El tr lo devuelve al alfabeto que entiende base64 -d.
curl -s -T foto.bin http://localhost:8080/put \
  | jq -r .data | cut -d, -f2 | tr '_-' '/+' | base64 -d > recibido.bin
cmp foto.bin recibido.bin && echo identico
```

**Verifica**:

```bash
# identico
sha256sum foto.bin recibido.bin | awk '{print $1}' | uniq | wc -l
# 1
```

---

## Paso 3: La URL que acaba en barra

**Por qué**: con `-T`, una URL acabada en `/` recibe el nombre del archivo
pegado al final. Es cómodo para subir varios, y peligroso cuando la barra
viene de una variable vacía.

**Comando**:

```bash
curl -s -T nota.txt http://localhost:8080/anything/subidas/ | jq -r .url
curl -s -T "{nota.txt,meta.json}" http://localhost:8080/anything/subidas/ | jq -r .url

# Una variable vacia cambia el destino sin dar error de curl.
DIR=""
curl -s -T nota.txt -o /dev/null -w '%{http_code} %{redirect_url}\n' \
  "http://localhost:8080/anything/${DIR}/"
```

**Verifica**:

```bash
# http://localhost:8080/anything/subidas/nota.txt
# http://localhost:8080/anything/subidas/nota.txt
# http://localhost:8080/anything/subidas/meta.json
# 307 http://localhost:8080/anything/nota.txt   ← la URL era /anything//nota.txt;
#                                                 el servidor la limpia y redirige
```

---

## Paso 4: Subir desde un pipe

**Por qué**: un backup, un informe generado, un `tar` de un directorio: no
hace falta escribirlos en el disco para subirlos. Pero sin archivo, curl no
sabe el tamaño, y eso cambia cómo viaja el cuerpo.

**Comando**:

```bash
printf 'generado al vuelo\n' | curl -s -T - -v -o /dev/null \
  http://localhost:8080/put 2>&1 | grep -iE '^> (content-length|transfer-encoding)'

# Un directorio entero, comprimido, sin archivo intermedio.
mkdir -p datos && cp nota.txt meta.json datos/
tar czf - datos | curl -s -T - -o /dev/null -w '%{http_code} %{size_upload}\n' \
  http://localhost:8080/put
```

**Verifica**:

```bash
# > Transfer-Encoding: chunked
# 200 221                     ← el tamano exacto variara con tu tar
```

No hay `Content-Length`: el cuerpo va en trozos con `Transfer-Encoding:
chunked`. Hay servidores que no lo aceptan; para ellos, primero a disco.

---

## Paso 5: `--data-binary` y el formulario fantasma

**Por qué**: `--data-binary @archivo` manda el archivo exacto, pero lo etiqueta
como formulario si no le dices otra cosa. El servidor se lo cree, y el
contenido acaba convertido en un nombre de campo.

**Comando**:

```bash
curl -s --data-binary @meta.json http://localhost:8080/post \
  | jq -c '{tipo: .headers["Content-Type"][0], form, json}'
curl -s --data-binary @meta.json -H 'Content-Type: application/json' \
  http://localhost:8080/post | jq -c '{tipo: .headers["Content-Type"][0], form, json}'
```

**Verifica**:

```bash
# {"tipo":"application/x-www-form-urlencoded","form":{"{\"a\":1}":[""]},"json":null}
# {"tipo":"application/json","form":{},"json":{"a":1}}
```

El primero llegó con un campo de formulario llamado `{"a":1}` y valor vacío.
El segundo, como un JSON.

---

## Paso 6: Otros métodos con el archivo como cuerpo

**Por qué**: la API decide el método. `-T` asume `PUT`, `--data-binary` asume
`POST`; con `-X` se cambia cualquiera de los dos.

**Comando**:

```bash
curl -s -X POST -T nota.txt http://localhost:8080/post | jq -c '[.method, .data]'
curl -s -X PATCH --data-binary @meta.json -H 'Content-Type: application/json' \
  http://localhost:8080/patch | jq -c '[.method, .json]'
```

**Verifica**:

```bash
# ["POST","data:application/octet-stream;base64,aG9sYQo="]
# ["PATCH",{"a":1}]
```

---

## Paso 7: Medir la subida y quitar el `Expect`

**Por qué**: `%{size_upload}` dice cuántos bytes salieron de verdad, cabeceras
de parte incluidas. Y el `Expect: 100-continue` cuesta un segundo de espera
contra un servidor que no lo contesta; saber quitarlo ahorra ese segundo.

**Comando**:

```bash
curl -s -T foto.bin -o /dev/null \
  -w 'subidos %{size_upload} bytes, codigo %{http_code}\n' http://localhost:8080/put

curl -s -T nota.txt -H 'Expect:' -v -o /dev/null http://localhost:8080/put 2>&1 \
  | grep -ci '^> expect'
```

**Verifica**:

```bash
# subidos 30000 bytes, codigo 200
# 0                           ← el header vacio lo suprime
```

---

## Paso 8: El mismo archivo, tres formatos

**Por qué**: el formato lo elige el servidor, pero el coste lo pagas tú. Medir
los tres sobre el mismo archivo convierte "el base64 ocupa más" en una cifra.

**Comando**:

```bash
medir() { curl -s -o /dev/null -w '%{size_upload}\n' "$@"; }

printf 'crudo:     '; medir -T foto.bin http://localhost:8080/put
printf 'multipart: '; medir -F 'foto=@foto.bin' http://localhost:8080/post

base64 -w0 foto.bin > foto.b64          # macOS: base64 -i foto.bin > foto.b64
printf 'json:      '
jq -n --rawfile c foto.b64 '{nombre: "foto.bin", contenido: $c}' \
  | medir --data-binary @- -H 'Content-Type: application/json' http://localhost:8080/post
```

**Verifica**:

```bash
# crudo:     30000
# multipart: 30200
# json:      40046
echo "scale=3; 40046 / 30000" | bc
# 1.334
```

Copia las tres cifras en `tres-formatos.md` y explica de dónde salen los 200
bytes del multipart y los 10.046 del JSON.

---

## Paso 9: El JSON llega entero, y por qué no por el argv

**Por qué**: el JSON con base64 entrega los mismos bytes; hay que comprobarlo.
Y la forma "obvia" de construirlo, metiendo el base64 en un argumento, revienta
en cuanto el archivo pasa de unos 96 KB.

**Comando**:

```bash
jq -n --rawfile c foto.b64 '{nombre: "foto.bin", contenido: $c}' \
  | curl -s --data-binary @- -H 'Content-Type: application/json' \
         http://localhost:8080/post \
  | jq -r '.json.contenido' | base64 -d | cmp - foto.bin && echo identico

# La forma "obvia", con un archivo de 200 KB:
head -c 200000 /dev/urandom > med.bin
jq -n --arg c "$(base64 -w0 med.bin)" '{c: $c}' >/dev/null; echo "codigo: $?"
```

**Verifica**:

```bash
# identico
# bash: /usr/bin/jq: Argument list too long
# codigo: 126
```

Un solo argumento no puede pasar de 128 KiB en Linux. `--rawfile` y el pipe no
tienen ese límite. Añade a `tres-formatos.md` cuál elegirías para un archivo
de 50 KB, uno de 500 MB y cinco archivos con metadatos, y por qué.

---

## ✅ Resultado

- [ ] He visto el método y las cabeceras de `-T`, incluido el `Expect` de mi versión
- [ ] He comprobado con `cmp` que una subida con `-T` llega idéntica
- [ ] He subido desde un pipe y he visto el `Transfer-Encoding: chunked`
- [ ] He visto el formulario fantasma de `--data-binary` sin `-H`
- [ ] `tres-formatos.md` tiene las tres cifras, su explicación y la elección para tres casos

```bash
./scripts/verificar-semana.sh 04
```

Con esta práctica terminada, las prácticas de la semana están completas. Lo
que queda en rojo se arregla en el proyecto.

---

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `400` al subir | El archivo pasa de 1 MB, el límite del laboratorio | Usa archivos más pequeños |
| `base64: invalid input` en el paso 2 | Falta el `tr '_-' '/+'`, o el `cut` no quitó el prefijo `data:...;base64,` | Copia el pipe completo del paso 2 |
| `base64: invalid option -- 'w'` (macOS) | El `base64` de macOS no tiene `-w` | `base64 -i foto.bin > foto.b64`: no parte líneas |
| `jq: error: --rawfile takes two parameters` | jq anterior a 1.6 | Actualiza jq: `jq --version` tiene que ser 1.6 o más |
| Las cifras del paso 8 no coinciden con las de la tabla | No usaste `?seed=7` y el multipart lleva otro nombre de campo | Repite la descarga del principio y usa `foto=@foto.bin` |
| El paso 9 da `codigo: 127` en vez de 126 | Tu shell es zsh, que reporta el error de otra forma | Es el mismo fallo: el argumento no cabe |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 03 — Formularios y multipart](03-formularios-y-multipart.md) | [Proyecto — Capa 4](../3-proyecto/README.md) |
