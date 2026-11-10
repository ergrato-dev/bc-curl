# Práctica 03 — Formularios y multipart

> **Duración**: 50 min · **Entregables**: `multipart.txt`

Vas a codificar un formulario a mano y comprobar que coincide con el de curl,
romper un formulario con los tres caracteres que lo rompen, y después abrir un
cuerpo multipart byte a byte hasta poder señalar cada pieza. Terminas subiendo
archivos con `-F` en todas sus variantes.

**Antes de empezar**:

```bash
./scripts/start.sh
mkdir -p ~/bc-curl-trabajo/semana-04/p3 && cd ~/bc-curl-trabajo/semana-04/p3
printf 'hola\n' > nota.txt
printf '{"a":1}' > meta.json
```

El `/post` del laboratorio devuelve en `data` el cuerpo crudo que recibió
cuando no sabe interpretarlo. Forzando `Content-Type: text/plain` lo verás
siempre: es la ventana de esta práctica.

---

## Paso 1: Codificar a mano y comparar

**Por qué**: si sabes escribir el cuerpo a mano, sabes leerlo cuando falla.
Las reglas son cuatro: `&` → `%26`, `%` → `%25`, espacio → `+`, y los
caracteres no ASCII en sus bytes UTF-8.

**Comando**:

```bash
# Tu version: nota=50% & más, codificado a mano. La á son dos bytes, C3 A1.
# (En printf, %% escribe un % literal.)
printf 'nota=50%%25+%%26+m%%C3%%A1s\n'

# La de curl, en crudo.
curl -s --data-urlencode 'nota=50% & más' -H 'Content-Type: text/plain' \
  http://localhost:8080/post | jq -r .data
```

**Verifica**:

```bash
# nota=50%25+%26+m%C3%A1s
# nota=50%25+%26+m%C3%A1s
```

Idénticas. Si la tuya difiere, el fallo casi siempre es el espacio: `+`, no
`%20` (los dos son válidos, pero curl usa `+`).

---

## Paso 2: Los tres caracteres que rompen `-d`

**Por qué**: `-d` no codifica nada. Con datos que vienen de fuera — un nombre,
un comentario, una password — esos tres caracteres aparecen tarde o temprano.

**Comando**:

```bash
curl -s -d 'c=a+b' http://localhost:8080/post | jq -c .form
curl -s -d 'e=x&y=z' http://localhost:8080/post | jq -c .form
curl -s -o /dev/null -w '%{http_code}\n' -d 'ok=1' -d 'p=50%' http://localhost:8080/post
```

**Verifica**:

```bash
# {"c":["a b"]}               ← el + se convirtio en espacio
# {"e":["x"],"y":["z"]}       ← el & invento un campo
# 400                         ← un % suelto tira el formulario entero, ok=1 incluido
```

Ahora los tres con `--data-urlencode`:

```bash
curl -s --data-urlencode 'c=a+b' --data-urlencode 'e=x&y=z' \
     --data-urlencode 'p=50%' http://localhost:8080/post | jq -c .form
# {"c":["a+b"],"e":["x&y=z"],"p":["50%"]}
```

---

## Paso 3: Un valor desde un archivo

**Por qué**: los valores largos o con saltos de línea no caben cómodos en la
línea de comandos, y los secretos no deben estar en ella. `nombre@archivo` lee
el valor de un archivo y lo codifica.

**Comando**:

```bash
printf 'Despliegue OK\nVersion: 1.4.2\n' > mensaje.txt
curl -s --data-urlencode 'text@mensaje.txt' -H 'Content-Type: text/plain' \
  http://localhost:8080/post | jq -r .data
curl -s --data-urlencode 'text@mensaje.txt' http://localhost:8080/post \
  | jq -r '.form.text[0]'
```

**Verifica**:

```bash
# text=Despliegue+OK%0AVersion%3A+1.4.2%0A
# Despliegue OK
# Version: 1.4.2
```

Los saltos de línea viajan como `%0A` y el servidor los reconstruye.

---

## Paso 4: `-d @`, `--data-binary @` y `--data-raw`

**Por qué**: tres flags que parecen iguales y hacen tres cosas distintas con
el mismo archivo. Confundirlos es mandar un archivo estropeado sin enterarte.

**Comando**:

```bash
# Un archivo con fin de linea de Windows: \r\n.
printf 'uno\r\ndos\r\n' > win.txt
for flag in -d --data-binary --data-raw; do
  printf '%-14s ' "$flag"
  curl -s "$flag" @win.txt -H 'Content-Type: text/plain' \
    http://localhost:8080/post | jq -j .data | od -An -c
done
```

**Verifica**:

```bash
# -d                u   n   o   d   o   s
# --data-binary     u   n   o  \r  \n   d   o   s  \r  \n
# --data-raw        @   w   i   n   .   t   x   t
```

`-d @` se comió los cuatro caracteres de fin de línea. `--data-binary` mandó
el archivo exacto. `--data-raw` ni lo abrió: la `@` era un carácter más.

---

## Paso 5: Subir un archivo con `-F`

**Por qué**: es la subida que espera cualquier endpoint de "adjuntar archivo".
Lo primero es ver el `Content-Type` que genera curl, con su boundary: es lo
que el `upload` del proyecto tiene que producir sin escribirlo a mano.

**Comando**:

```bash
curl -s -F 'doc=@nota.txt' http://localhost:8080/post \
  | jq -c '{tipo: .headers["Content-Type"][0], files, form}'
```

**Verifica**:

```bash
# {"tipo":"multipart/form-data; boundary=------------------------5f7b1dfa4b89a151",
#  "files":{"doc":["hola\n"]},"form":{}}
```

El boundary cambia en cada ejecución. El archivo llega en `files`, bajo el
nombre del campo (`doc`), no bajo el nombre del archivo.

---

## Paso 6: El cuerpo multipart byte a byte

**Por qué**: cuando una subida falla con un 400 sin explicación, la única forma
de saber qué llegó es leer el cuerpo. Hacerlo una vez con calma es lo que te
deja hacerlo rápido cuando hace falta.

**Comando**:

```bash
# Aqui no hace falta forzar text/plain: /post guarda el crudo en .data
# tambien con multipart.
curl -s -F 'autor=ana' -F 'doc=@nota.txt' http://localhost:8080/post \
  | jq -r .data | cat -A | tee multipart.txt
```

**Verifica**:

```bash
# --------------------------13bf6e6cc679fb9c^M$
# Content-Disposition: form-data; name="autor"^M$
# ^M$
# ana^M$
# --------------------------13bf6e6cc679fb9c^M$
# Content-Disposition: form-data; name="doc"; filename="nota.txt"^M$
# Content-Type: text/plain^M$
# ^M$
# hola$
# ^M$
# --------------------------13bf6e6cc679fb9c--^M$
grep -c 'Content-Disposition' multipart.txt
# 2
```

Edita `multipart.txt` y anota, junto a cada línea: delimitador, cabecera de
parte, línea en blanco, contenido o cierre. Señala por qué `hola$` no lleva
`^M` y la línea siguiente sí: el `\n` es del archivo, el `\r\n` es del formato.

---

## Paso 7: `@` frente a `<`, `;type=` y `;filename=`

**Por qué**: la API decide si quiere el valor como archivo o como texto, y a
veces valida el tipo. Las tres directivas son lo que te deja darle exactamente
lo que pide.

**Comando**:

```bash
curl -s -F 'nota=<nota.txt' http://localhost:8080/post | jq -c '{form, files}'
curl -s -F 'nota=@nota.txt' http://localhost:8080/post | jq -c '{form, files}'

curl -s -F 'f=@meta.json' http://localhost:8080/post \
  | jq -r .data | grep -i '^content-type'
curl -s -F 'f=@meta.json;type=application/json;filename=datos.json' \
  http://localhost:8080/post | jq -r .data | grep -iE '^content-(type|disposition)'
```

**Verifica**:

```bash
# {"form":{"nota":["hola\n"]},"files":{}}
# {"form":{},"files":{"nota":["hola\n"]}}
# Content-Type: application/octet-stream     ← curl no conoce .json
# Content-Disposition: form-data; name="f"; filename="datos.json"
# Content-Type: application/json
```

---

## Paso 8: Los dos valores que engañan a `-F`

**Por qué**: en un script, el valor y el nombre del archivo vienen de fuera. Uno
que empiece por `@` hace que curl lea un archivo del disco; uno con `;` en el
nombre rompe el comando.

**Comando**:

```bash
# Un usuario que se llama @ana_dev:
curl -s -F 'usuario=@ana_dev' http://localhost:8080/post; echo "con -F: $?"
curl -s --form-string 'usuario=@ana_dev' http://localhost:8080/post | jq -c .form

# Un archivo con ; en el nombre:
cp nota.txt 'informe;v2.txt'
curl -sS -F 'doc=@informe;v2.txt' http://localhost:8080/post; echo "sin comillas: $?"
archivo='informe;v2.txt'
curl -s -F "doc=@\"${archivo}\"" http://localhost:8080/post \
  | jq -r .data | grep -i disposition
```

**Verifica**:

```bash
# con -F: 26                  ← curl intento abrir el archivo "ana_dev"
# {"usuario":["@ana_dev"]}
# curl: (26) Failed to open/read local data from file/application
# sin comillas: 26          ← curl corto en el ; e intento abrir "informe"
# Content-Disposition: form-data; name="doc"; filename="informe;v2.txt"
```

La forma `"doc=@\"${archivo}\""` es la que usa el `upload` del proyecto.

---

## Paso 9: El boundary escrito a mano

**Por qué**: copiar el `Content-Type` de una petición que viste en las
herramientas del navegador parece inofensivo. No lo es: ese header lleva un
boundary que no es el del cuerpo que va a generar curl.

**Comando**:

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'Content-Type: multipart/form-data; boundary=xyz' -F 'f=@nota.txt' \
  http://localhost:8080/post

curl -s -o /dev/null -v \
  -H 'Content-Type: multipart/form-data; boundary=xyz' -F 'f=@nota.txt' \
  http://localhost:8080/post 2>&1 | grep -i '^> content-type'
```

**Verifica**:

```bash
# 400
# > Content-Type: multipart/form-data; boundary=xyz; boundary=------------------------12a2...
```

curl añadió su boundary detrás del tuyo. El servidor lee el primero, `xyz`, no
lo encuentra en el cuerpo, y responde 400. Sin el `-H`, funciona.

---

## ✅ Resultado

- [ ] Mi codificación a mano del paso 1 coincide byte a byte con la de curl
- [ ] He visto los tres fallos de `-d` y los he arreglado con `--data-urlencode`
- [ ] Sé qué hace cada uno de `-d @`, `--data-binary @` y `--data-raw` con un archivo
- [ ] `multipart.txt` tiene el cuerpo anotado pieza a pieza
- [ ] He mandado un valor que empieza por `@` y un nombre con `;` sin romper nada
- [ ] He visto el 400 del boundary copiado a mano

```bash
./scripts/verificar-semana.sh 04
```

Esta práctica prepara las comprobaciones de `upload` del proyecto.

---

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `jq: error ... null` al leer `.data` | La respuesta no fue un 200 | Quita el `\| jq` y mira qué devolvió el laboratorio |
| El paso 1 sale con `%20` en vez de `+` | Usaste otra herramienta para codificar | En formularios ambos valen; curl usa `+` |
| `curl: (26) Failed to open/read local data` | La ruta tras `@` no existe desde el directorio actual | `ls` el archivo; `-F` resuelve rutas relativas al directorio actual |
| `cat -A` no existe (macOS) | Es de GNU coreutils | `cat -vet` hace lo mismo |
| El paso 6 sale vacío | Añadiste `-H 'Content-Type: text/plain'` por costumbre del paso 1 | Con multipart no se toca el `Content-Type`: quítalo |
| `files` sale vacío en el paso 5 | Usaste `<` en vez de `@` | `@` manda el archivo como archivo |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 02 — Verificar y limitar](02-verificar-y-limitar.md) | [Práctica 04 — Subir en crudo y elegir](04-subir-en-crudo-y-elegir.md) |
