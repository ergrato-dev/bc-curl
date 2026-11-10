# Verificar lo descargado

> curl sale con 0 cuando la transferencia termina, no cuando el archivo es el
> que pediste. Entre una cosa y otra hay tres comprobaciones baratas, y la
> última es la única que no se puede engañar.

![Diagrama de las tres capas de verificación de un archivo descargado: el tamaño, que compara Content-Length con size_download; el tipo, que compara content_type con lo esperado; y el hash, que compara el SHA-256 calculado con el publicado; cada capa atrapa un fallo distinto y solo el hash atrapa todos](../0-assets/03-verificar-lo-descargado.svg)

## 🎯 Objetivos

- Comprobar el tamaño, el tipo y el hash de lo descargado, y saber qué fallo atrapa cada uno
- Leer `%{size_download}` y `%{content_type}` con `--write-out`
- Entender por qué con `--compressed` el tamaño descargado no coincide con el del archivo
- Verificar un archivo contra un hash publicado y contra un `SHA256SUMS`
- Saber de dónde tiene que venir el hash para que la verificación valga algo

---

## 1. Qué problema resuelve

Un archivo puede llegar mal de muchas formas que curl no ve como error:

| Qué pasó | Código de salida de curl |
|---|:--:|
| Un proxy cautivo del hotel te sirvió su página de login con un 200 | 0 |
| El servidor tenía una versión vieja en una réplica de la CDN | 0 |
| Reanudaste y el archivo había cambiado en el servidor entretanto | 0 |
| Un atacante en medio cambió el binario (sin TLS, o con TLS sin verificar) | 0 |
| La conexión se cerró antes de tiempo **y** el servidor no mandó `Content-Length` | 0 |

En los cinco casos curl hizo bien su trabajo: pidió y le dieron. Si quieres
saber si lo que tienes es lo que querías, tienes que comprobarlo tú.

---

## 2. Cómo funciona

### 2.1 Tres capas, de más barata a más fiable

| Capa | Qué compara | Qué atrapa | Qué no atrapa |
|---|---|---|---|
| **Tamaño** | Bytes recibidos frente a los anunciados | Cortes de conexión | Contenido equivocado del tamaño correcto |
| **Tipo** | `Content-Type` frente al esperado | HTML de error o de un proxy en vez del binario | Un binario equivocado del tipo correcto |
| **Hash** | SHA-256 calculado frente al publicado | Todo lo anterior y cualquier byte cambiado | Nada, **si el hash viene de una fuente fiable** |

Las dos primeras son gratis y dan un diagnóstico rápido. La tercera es la que
cierra el caso.

### 2.2 Tamaño: lo que curl ya comprueba y lo que no

Si el servidor manda `Content-Length` y cierra antes de completarlo, curl lo
nota y sale con **18** (`Partial file`) o, según cómo se corte, con **56**
(`Failure when receiving data`). Ese caso está cubierto.

Lo que curl no puede comprobar es una respuesta sin `Content-Length` — las que
van con `Transfer-Encoding: chunked`, típicas de lo que se genera al vuelo —:
no hay cifra contra la que comparar.

```bash
# size_download: los bytes del cuerpo que curl recibio.
curl -s -o r.bin -w '%{size_download}\n' http://localhost:8080/range/1000
# 1000
wc -c < r.bin
# 1000
```

### 2.3 La trampa de `--compressed`

Con `--compressed`, curl pide el cuerpo comprimido y lo descomprime al
escribirlo. `size_download` cuenta lo que viajó, no lo que se escribió:

```bash
curl -s --compressed -o g.json -w '%{size_download}\n' http://localhost:8080/gzip
# 207
wc -c < g.json
# 303
```

`Content-Length: 207` habla de los bytes comprimidos. Compara `size_download`
con `Content-Length`, nunca con el tamaño del archivo en disco, cuando hay
`Content-Encoding` de por medio.

### 2.4 Tipo: el detector de páginas de error

```bash
curl -s -o r.bin -w '%{http_code} %{content_type}\n' http://localhost:8080/range/1000
# 200 text/plain; charset=utf-8
curl -s -o x.bin -w '%{http_code} %{content_type}\n' http://localhost:8080/html
# 200 text/html; charset=utf-8
```

Si esperabas un `.zip` y llega `text/html` con un 200, no es tu zip: es la
página de alguien. El `Content-Type` lo declara el servidor y puede mentir, pero
como alarma barata funciona muy bien.

### 2.5 Hash: la única comprobación que no se engaña

Una función hash como SHA-256 convierte cualquier archivo en 64 caracteres
hexadecimales. Cambia un solo bit y cambia el hash entero. No se puede
fabricar un archivo distinto con el mismo hash.

```bash
curl -s http://localhost:8080/range/100 | sha256sum
# 2ac123dcd759eebabfa1b17c0332b88b3815ef3f95fbfcceb5fac07e233235bd  -
```

En macOS no hay `sha256sum`: el equivalente es `shasum -a 256`, con la misma
salida.

---

## 3. Cómo se usa

### 3.1 Contra un hash publicado

El proyecto publica el hash en su web o en sus notas de versión. Lo comparas
con `sha256sum -c`, que lee líneas `HASH  NOMBRE` (**dos espacios**) y dice
`OK` o `FAILED`:

```bash
curl -fsS -o datos.bin http://localhost:8080/range/100
echo "2ac123dcd759eebabfa1b17c0332b88b3815ef3f95fbfcceb5fac07e233235bd  datos.bin" \
  | sha256sum -c -
# datos.bin: OK
echo $?
# 0
```

Si no coincide, `sha256sum -c` sale con 1. Es lo que permite encadenarlo con
`&&`.

### 3.2 Contra un `SHA256SUMS`

Los proyectos con muchos archivos publican uno solo con todos los hashes:

```bash
sha256sum a.bin b.bin > SHA256SUMS
cat SHA256SUMS
# 915e53a4...59d87  a.bin
# 2ac123dc...235bd  b.bin

echo x >> b.bin       # estropear uno
sha256sum -c SHA256SUMS
# a.bin: OK
# b.bin: FAILED
# sha256sum: WARNING: 1 computed checksum did NOT match
echo $?
# 1
```

Con `--ignore-missing` solo comprueba los archivos que tengas: útil cuando el
`SHA256SUMS` lista veinte y tú has bajado uno.

### 3.3 El orden correcto en un script

```bash
# Descargar a .part, verificar el .part, y solo entonces renombrar. Si el hash
# no coincide, el archivo malo nunca llega a tener el nombre bueno.
curl -fsS --max-time 600 --retry 3 -C - -o datos.bin.part http://localhost:8080/range/100 \
  && echo "2ac123dcd759eebabfa1b17c0332b88b3815ef3f95fbfcceb5fac07e233235bd  datos.bin.part" \
     | sha256sum -c --quiet - \
  && mv datos.bin.part datos.bin
```

Y si falla el hash, **borra el `.part`**: con un hash que no coincide, reanudar
solo añadiría bytes a algo que ya está mal.

### 3.4 De dónde sale el hash

La verificación vale lo que vale la fuente del hash:

| Fuente del hash | ¿Vale? | Por qué |
|---|:--:|---|
| Escrito en tu script o en tu repositorio, copiado una vez de la web oficial | ✅ | Un atacante tendría que cambiar tu repositorio, no solo el servidor |
| Un `SHA256SUMS` firmado con GPG, con la firma verificada | ✅ | La firma prueba quién lo publicó |
| Un `SHA256SUMS` descargado del mismo servidor, por HTTPS verificado | ⚠️ | Protege contra corrupción, no contra un servidor comprometido |
| Un `SHA256SUMS` descargado del mismo servidor sin TLS verificado | ❌ | Quien cambió el archivo cambió también el hash |

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Fiarse de que curl salió con 0 | 0 significa "transferencia terminada", no "archivo correcto" | Verificar al menos el tipo, y el hash cuando lo haya |
| Comparar `size_download` con `wc -c` usando `--compressed` | Uno cuenta comprimido y el otro descomprimido: nunca coinciden | Comparar `size_download` con `Content-Length` |
| Hash y archivo del mismo sitio, sin TLS verificado | Quien cambia uno cambia el otro | Hash fijado en tu código, o firmado |
| `md5sum` o `sha1sum` para seguridad | Ambos tienen colisiones fabricables | SHA-256 |
| Verificar **después** del `mv` | Durante un instante el archivo malo tiene el nombre bueno, y si el script muere ahí, se queda | Verificar el `.part`, luego `mv` |
| Un espacio entre hash y nombre en la línea de `sha256sum -c` | `sha256sum` no reconoce el formato y no verifica nada | Dos espacios: `HASH  NOMBRE` |

---

## 5. Trucos

```bash
# Las tres capas en una sola linea de --write-out.
curl -s -o r.bin -w 'codigo=%{http_code} tipo=%{content_type} bytes=%{size_download}\n' \
  http://localhost:8080/range/1000
# codigo=200 tipo=text/plain; charset=utf-8 bytes=1000
```

```bash
# Comparar el hash sin escribir el archivo en disco: util para comprobar si
# lo que hay en el servidor cambio respecto a lo que tienes.
[ "$(curl -s http://localhost:8080/range/100 | sha256sum | cut -d' ' -f1)" \
  = "$(sha256sum < datos.bin | cut -d' ' -f1)" ] && echo igual || echo distinto
```

```bash
# Hash portable entre Linux y macOS en un script.
sha256_de() { { sha256sum "$1" 2>/dev/null || shasum -a 256 "$1"; } | cut -d' ' -f1; }
```

---

## 📚 Recursos Adicionales

- [manpage de curl — `--write-out`](https://curl.se/docs/manpage.html#-w) — `size_download`, `content_type` y las demás variables
- [Códigos de salida de curl](https://curl.se/libcurl/c/libcurl-errors.html) — el 18 y el 56, y qué los distingue
- [GNU coreutils — sha2 utilities](https://www.gnu.org/software/coreutils/manual/html_node/sha2-utilities.html) — `sha256sum -c`, `--quiet`, `--ignore-missing`
- [Ubuntu — How to verify your Ubuntu download](https://ubuntu.com/tutorials/how-to-verify-ubuntu) — un caso real de `SHA256SUMS` firmado

---

## ✅ Checklist de Verificación

- [ ] Sé qué atrapa y qué no atrapa cada una de las tres capas
- [ ] He visto que con `--compressed` `size_download` y `wc -c` no coinciden, y sé por qué
- [ ] He detectado una respuesta HTML con `%{content_type}` cuando esperaba otra cosa
- [ ] He verificado un archivo con `sha256sum -c` en verde y en rojo
- [ ] Sé por qué se verifica el `.part` y no el archivo final
- [ ] Sé de qué fuentes vale la pena sacar el hash y de cuáles no

---

| Anterior | Siguiente |
|---|---|
| [02 — Rangos y descargas reanudables](02-rangos-y-descargas-reanudables.md) | [04 — Controlar la transferencia](04-controlar-la-transferencia.md) |
