# Multipart por dentro

> `-F` parece magia: le das un archivo y el servidor lo recibe con nombre, tipo
> y contenido. Por dentro es texto con separadores, y saber leerlo es lo que te
> deja depurar una subida que el servidor rechaza sin explicar por qué.

![Diagrama de un cuerpo multipart/form-data: el header Content-Type con el boundary; debajo, el cuerpo dividido en partes por líneas que empiezan con dos guiones más el boundary; cada parte con su Content-Disposition, su Content-Type opcional, una línea en blanco y el contenido; al final el boundary con dos guiones de cierre](../0-assets/06-multipart-por-dentro.svg)

## 🎯 Objetivos

- Leer un cuerpo `multipart/form-data` real y señalar el boundary, cada parte y su cabecera
- Construir partes de texto y de archivo con `-F`, y saber qué hacen `@` y `<`
- Fijar el tipo y el nombre de un archivo con `;type=` y `;filename=`
- Mandar un valor que empieza por `@` o `<` sin que curl lea un archivo
- Subir un archivo cuyo nombre lleva `;` o `,`
- Saber por qué el `Content-Type` de un multipart no se escribe a mano, y cuándo eso rompe la subida

---

## 1. Qué problema resuelve

El formato urlencoded del [archivo 05](05-formularios-urlencoded.md) sirve para
pares de texto cortos. Para un archivo es pésimo: cada byte que no sea una
letra se convierte en tres (`%XX`), y no hay sitio para decir cómo se llamaba
el archivo ni de qué tipo es.

`multipart/form-data`
([RFC 7578](https://datatracker.ietf.org/doc/html/rfc7578)) resuelve las dos
cosas: el contenido va **tal cual**, sin codificar, y cada campo lleva sus
propias cabeceras. Es lo que manda un navegador cuando un formulario tiene un
`<input type="file">`, y lo que esperan casi todos los endpoints de "subir
adjunto".

---

## 2. Cómo funciona

### 2.1 Un cuerpo multipart, byte a byte

El `/post` del laboratorio devuelve en `data` el cuerpo crudo que recibió. Con
`cat -A`, los `\r\n` se ven como `^M$`:

```bash
printf 'hola\n' > nota.txt
curl -s -F 'autor=ana' -F 'doc=@nota.txt' http://localhost:8080/post \
  | jq -r .data | cat -A
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
```

Y el header de la petición:

```
Content-Type: multipart/form-data; boundary=------------------------13bf6e6cc679fb9c
```

### 2.2 Las piezas

| Pieza | Qué es |
|---|---|
| **Boundary** | Una cadena aleatoria que curl elige para cada petición y declara en el `Content-Type`. Separa las partes |
| **Delimitador** | `--` + boundary, en su propia línea, antes de cada parte. Por eso en el cuerpo hay dos guiones más que en el header |
| **Cierre** | `--` + boundary + `--`. Marca el final del cuerpo |
| **`Content-Disposition`** | Obligatorio en cada parte. `name` es el nombre del campo; `filename`, solo en partes de archivo |
| **`Content-Type` de la parte** | Opcional. curl lo pone en las partes de archivo, deducido de la extensión |
| **Línea en blanco** | Separa las cabeceras de la parte de su contenido |
| **Contenido** | Los bytes del valor o del archivo, **sin codificar**. Fíjate en el `hola$`: el `\n` del archivo va tal cual |

El boundary es aleatorio para que no aparezca dentro de ningún archivo. Si
apareciera, el servidor cortaría la parte por ahí.

Por eso el header no se escribe a mano. Si copias uno con su boundary, curl
añade el suyo detrás y el servidor se queda con el primero, que no está en el
cuerpo:

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'Content-Type: multipart/form-data; boundary=xyz' -F 'f=@nota.txt' \
  http://localhost:8080/post
# 400
```

### 2.3 Las formas de `-F`

| Forma | Qué crea | Parte resultante |
|---|---|---|
| `-F 'nombre=valor'` | Campo de texto | `name="nombre"`, contenido `valor` |
| `-F 'nombre=@archivo'` | Campo de **archivo** | `name="nombre"; filename="archivo"`, con `Content-Type` |
| `-F 'nombre=<archivo'` | Campo de **texto** con el contenido del archivo | `name="nombre"`, sin `filename` |
| `-F 'nombre=@archivo;type=TIPO'` | Archivo con el tipo que tú digas | `Content-Type: TIPO` |
| `-F 'nombre=@archivo;filename=OTRO'` | Archivo con otro nombre | `filename="OTRO"` |
| `--form-string 'nombre=@valor'` | Texto literal, sin interpretar `@`, `<` ni `;` | `name="nombre"`, contenido `@valor` |

La diferencia entre `@` y `<` es la que más confunde. Las dos leen el archivo;
solo `@` lo manda **como archivo**. El servidor lo nota: lo de `@` le llega en
`files`, lo de `<` en `form`.

```bash
curl -s -F 'nota=<nota.txt' http://localhost:8080/post | jq -c '.form, .files'
# {"nota":["hola\n"]}
# {}
curl -s -F 'nota=@nota.txt' http://localhost:8080/post | jq -c '.form, .files'
# {}
# {"nota":["hola\n"]}
```

### 2.4 El tipo deducido, y cuándo no basta

curl deduce el `Content-Type` de la parte por la extensión, pero su tabla es
corta: `.txt`, `.html`, `.xml`, `.pdf`, `.png`, `.jpg`, `.gif`, `.svg` y poco
más. Todo lo demás sale como `application/octet-stream`:

```bash
printf '{"a":1}' > meta.json
curl -s -F 'f=@meta.json' http://localhost:8080/post | jq -r .data | grep -i content-type
# Content-Type: application/octet-stream
```

Si el servidor valida el tipo — "solo acepto `application/json`" — lo fijas tú:

```bash
curl -s -F 'doc=@nota.txt;type=text/markdown;filename=leeme.md' \
        -F 'meta=<meta.json;type=application/json' \
  http://localhost:8080/post | jq -r .data | grep -iE 'disposition|content-type'
# Content-Disposition: form-data; name="doc"; filename="leeme.md"
# Content-Type: text/markdown
# Content-Disposition: form-data; name="meta"
# Content-Type: application/json
```

### 2.5 Método y `Expect`

`-F` implica `POST`. Si la API pide `PUT` con multipart, `-X PUT -F ...`.

Con cuerpos de **más de 1 MB**, curl 7.81 añade `Expect: 100-continue`: manda
las cabeceras, espera hasta un segundo a que el servidor diga `100 Continue`, y
solo entonces manda el cuerpo. Así un servidor que va a rechazar la subida (por
tamaño, por credencial) lo dice antes de que viajen los megas. Si el servidor
no contesta el `100`, pierdes ese segundo en cada subida; `-H 'Expect:'` lo
suprime. Con `-T` el umbral es otro: lo verás en el
[archivo 07](07-subir-el-cuerpo-en-crudo.md).

---

## 3. Cómo se usa

### 3.1 Archivo más metadatos, el caso típico

```bash
# El archivo como parte de archivo, y los metadatos como partes de texto.
curl --fail-with-body --max-time 60 -sS \
  -F 'documento=@nota.txt' \
  -F 'carpeta=informes' \
  -F 'metadatos=<meta.json;type=application/json' \
  http://localhost:8080/post | jq -c '.form, .files'
# {"carpeta":["informes"],"metadatos":["{\"a\":1}"]}
# {"documento":["hola\n"]}
```

### 3.2 Un valor del usuario que empieza por `@`

```bash
# Con -F, curl intentaria abrir el archivo "ana_dev" y fallaria con el 26.
curl -s --form-string 'usuario=@ana_dev' http://localhost:8080/post | jq -c .form
# {"usuario":["@ana_dev"]}
```

En un script, **cualquier valor que no controles va por `--form-string`**.

### 3.3 Un nombre de archivo con `;`

curl lee `;` dentro de `-F` como el comienzo de una directiva (`;type=`,
`;filename=`). Un archivo llamado `informe;v2.txt` lo confunde:

```bash
cp nota.txt 'informe;v2.txt'
curl -sS -F 'doc=@informe;v2.txt' http://localhost:8080/post
# curl: (26) Failed to open/read local data from file/application
```

curl cortó el nombre en el `;`, trató `v2.txt` como una directiva que no
conoce, e intentó abrir un archivo llamado `informe`. Si ese archivo existiera,
lo habría subido en silencio en lugar del bueno.

La solución es entrecomillar el nombre **dentro** del valor:

```bash
curl -s -F 'doc=@"informe;v2.txt"' http://localhost:8080/post \
  | jq -r .data | grep -i disposition
# Content-Disposition: form-data; name="doc"; filename="informe;v2.txt"
```

En un script, con una variable: `-F "doc=@\"${archivo}\""`. Es lo que hace el
`upload` del proyecto.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `-H 'Content-Type: multipart/form-data; boundary=...'` copiado de otra petición, junto a `-F` | curl añade **su** boundary detrás del tuyo; el servidor lee el primero, que no aparece en el cuerpo, y responde 400 | No poner el header: `-F` lo genera completo |
| `-H 'Content-Type: multipart/form-data'` sin boundary | En curl no rompe (le añade el boundary), pero es un hábito que en `fetch`, `requests` o `axios` sí deja la subida sin boundary | No poner el header, en ninguna herramienta |
| `-F "campo=$VALOR"` con un valor externo | Si empieza por `@` o `<`, curl lee un archivo del disco y lo manda | `--form-string "campo=$VALOR"` |
| `-F "doc=@$ARCHIVO"` sin comillas internas | Un nombre con `;` o `,` rompe el comando | `-F "doc=@\"$ARCHIVO\""` |
| `<` cuando el servidor espera un archivo | Llega como campo de texto: el servidor no lo encuentra en `files` | `@` |
| Dar por bueno el tipo deducido | Un `.json` sale como `application/octet-stream` y un servidor estricto lo rechaza | `;type=` explícito |
| Multipart para mandar solo pares de texto cortos | Más bytes y más complejidad que urlencoded, sin ganar nada | `-d` / `--data-urlencode` |

---

## 5. Trucos

```bash
# Ver el multipart exacto sin servidor de por medio: --trace-ascii vuelca lo
# que sale por el cable.
curl -s -F 'a=1' -F 'f=@nota.txt' --trace-ascii - -o /dev/null \
  http://localhost:8080/post | sed -n '/=> Send data/,/== Info/p' | head -20
```

```bash
# Cuanto pesa el envoltorio multipart: bytes enviados menos bytes de archivo.
curl -s -F 'f=@nota.txt' -o /dev/null -w '%{size_upload}\n' http://localhost:8080/post
wc -c < nota.txt
```

```bash
# Subir varios archivos en el mismo campo, como un <input multiple>.
curl -s -F 'docs=@nota.txt' -F 'docs=@meta.json' http://localhost:8080/post \
  | jq -c '.files | map_values(length)'
# {"docs":2}
```

---

## 📚 Recursos Adicionales

- [RFC 7578 — multipart/form-data](https://datatracker.ietf.org/doc/html/rfc7578) — corto, y la sección 4 es exactamente lo que hay en el cuerpo
- [manpage de curl — `-F`](https://curl.se/docs/manpage.html#-F) — todas las directivas, incluidas las comillas en el nombre
- [everything.curl.dev — Multipart formposts](https://everything.curl.dev/http/post/multipart.html) — con el cuerpo explicado
- [MDN — Content-Disposition](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Disposition) — el header en su uso dentro de multipart

---

## ✅ Checklist de Verificación

- [ ] He leído un cuerpo multipart con `cat -A` y sé señalar boundary, delimitadores, cierre y partes
- [ ] Sé por qué el delimitador tiene dos guiones más que el boundary del header
- [ ] He mandado el mismo archivo con `@` y con `<` y he visto dónde llega cada uno
- [ ] He fijado `;type=` y `;filename=` y los he visto en el cuerpo
- [ ] He mandado un valor que empieza por `@` con `--form-string`
- [ ] He subido un archivo con `;` en el nombre
- [ ] He visto el 400 de un `Content-Type` con boundary copiado a mano, y sé por qué curl no lo arregla

---

| Anterior | Siguiente |
|---|---|
| [05 — Formularios urlencoded](05-formularios-urlencoded.md) | [07 — Subir el cuerpo en crudo](07-subir-el-cuerpo-en-crudo.md) |
