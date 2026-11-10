# Descargar un archivo

> Bajar un archivo es lo primero que todo el mundo hace con curl y lo que más
> scripts rompe en silencio. El problema nunca es la descarga: es lo que queda
> en el disco cuando la descarga sale mal.

![Diagrama de las tres formas de elegir el nombre del archivo: -o con el nombre que das tú, -O con el último segmento de la URL incluida la query string, y -OJ con el nombre que manda el servidor en Content-Disposition; abajo, el 404 sin --fail que acaba guardado como si fuera el archivo](../0-assets/01-descargar-un-archivo.svg)

## 🎯 Objetivos

- Elegir entre `-o`, `-O` y `-J` sabiendo de dónde sale el nombre en cada caso
- Predecir el nombre que va a usar `-O` antes de ejecutarlo, incluida la query string
- Evitar que una respuesta de error se guarde con el nombre del archivo bueno
- Saber por qué en una descarga se usa `--fail` y no `--fail-with-body`
- Dejar las descargas en un directorio concreto sin hacer `cd`

---

## 1. Qué problema resuelve

Por defecto curl escribe el cuerpo de la respuesta en la salida estándar. Para
un JSON es lo que quieres: lo encadenas con `jq`. Para un PDF de 40 MB es un
desastre: bytes binarios en la terminal, que se queda con caracteres raros o
con el cursor desaparecido.

curl lo detecta y se niega:

```bash
curl http://localhost:8080/image/png
# Warning: Binary output can mess up your terminal. Use "--output -" to tell
# Warning: curl to output it to your terminal anyway, or consider "--output
# Warning: <FILE>" to save to a file.
```

La solución obvia es `-o archivo`. La no obvia es todo lo que puede salir mal
entre que lanzas el comando y que el archivo queda en el disco: el servidor
responde 404, la URL no tiene un nombre de archivo, el servidor manda el nombre
en un header, el archivo ya existía. Este archivo de teoría trata de esas
cuatro.

---

## 2. Cómo funciona

### 2.1 Tres formas de decidir el nombre

| Flag | Quién decide el nombre | Ejemplo | Nombre resultante |
|---|---|---|---|
| `-o NOMBRE` | Tú | `-o datos.bin URL/range/10` | `datos.bin` |
| `-O` | El último segmento de la URL | `-O URL/range/10` | `10` |
| `-O -J` | El header `Content-Disposition` del servidor | `-OJ URL/descarga?id=7` | Lo que diga el header |

`-O` es la forma larga `--remote-name`, y `-J` es `--remote-header-name`. `-J`
**solo funciona junto con `-O`**: le dice a `-O` que, si el servidor manda un
nombre, use ese en vez del de la URL.

### 2.2 `-O` toma el último segmento, query string incluida

curl no interpreta la URL para sacar un nombre bonito: corta por la última
barra y se queda con todo lo que hay después.

```bash
curl -sS -O "http://localhost:8080/range/10?x=1"
ls
# 10?x=1
```

Un archivo llamado `10?x=1` es válido en Linux, pero rompe el `ls *.pdf` de
después, los scripts que no entrecomillan, y en Windows ni siquiera se puede
crear. Si la URL lleva query string, **`-o` con un nombre explícito**.

Y si la URL acaba en barra, no hay nombre que tomar:

```bash
curl -sS -O http://localhost:8080/
# curl: (23) Failed writing received data to disk/application
```

El 23 es "no he podido escribir". Ojo: esto es curl 7.81. Las versiones 8.x
recientes ya no fallan y guardan con un nombre por defecto, `curl_response`
(comprobado con 8.21). El mismo comando da un error o un archivo según la
máquina: otro motivo para no usar `-O` con URLs que no controlas.

### 2.3 `-J`: el nombre lo pone el servidor

Muchas descargas no tienen el nombre en la URL: `/export?id=7`,
`/download/a8f3c1`. El servidor lo manda en un header:

```
Content-Disposition: attachment; filename=informe.txt
```

```bash
curl -sS -OJ "http://localhost:8080/response-headers?Content-Disposition=attachment%3B%20filename%3Dinforme.txt"
ls
# informe.txt
```

Dos garantías de `-J` que conviene conocer:

- **Nunca sobrescribe.** Si `informe.txt` ya existe, curl falla con el 23
  (`Failed writing header`) y deja el viejo intacto.
- **Quita cualquier ruta del nombre.** Un servidor que mande
  `filename=../../.bashrc` acaba escribiendo `.bashrc` en el directorio actual,
  no dos niveles arriba. Aun así, no uses `-J` contra servidores en los que no
  confías: el nombre lo eligen ellos.

### 2.4 Elegir el directorio

```bash
# --output-dir (7.73+): el directorio donde caen los -O y los -o relativos.
# --create-dirs crea ese directorio, y cualquier ruta intermedia de -o.
curl -sS --output-dir descargas --create-dirs -O http://localhost:8080/range/10
ls descargas
# 10
```

En 7.72 o anterior no existe `--output-dir`. La alternativa es la misma de
siempre: `mkdir -p descargas && (cd descargas && curl -sS -O URL)`.

`--create-dirs` sirve también sin `--output-dir`:

```bash
curl -sS --create-dirs -o a/b/c.bin http://localhost:8080/range/10
ls a/b
# c.bin
```

---

## 3. Cómo se usa

### 3.1 El fallo: la página de error con el nombre del archivo

Este es el fallo que más scripts de descarga tiene en producción, y no da
ninguna señal:

```bash
curl -s -o informe.pdf http://localhost:8080/status/404
echo "codigo de salida: $?"
# codigo de salida: 0
ls -l informe.pdf
# -rw-r--r-- 1 tu tu 0 nov 10 10:00 informe.pdf
```

curl salió con 0 porque, para curl, **la transferencia fue un éxito**: pidió y
le contestaron. Que la respuesta fuera un 404 es asunto tuyo. Y en el disco hay
un `informe.pdf` que no es un PDF: vacío aquí, y con el HTML de "Not Found" en
un servidor real. El paso siguiente del script — subirlo, descomprimirlo,
enviarlo por correo — trabaja con basura.

### 3.2 La defensa: `--fail`

```bash
rm -f informe.pdf
curl -sS --fail -o informe.pdf http://localhost:8080/status/404
# curl: (22) The requested URL returned error: 404
echo $?
# 22
ls informe.pdf
# ls: cannot access 'informe.pdf': No such file or directory
```

Con `--fail` (`-f`) curl sale con 22 ante cualquier 4xx/5xx **y no escribe el
cuerpo**. Si el archivo no existía, sigue sin existir.

### 3.3 Por qué aquí `--fail` y no `--fail-with-body`

En todo el bootcamp la regla es `--fail-with-body` (7.76+): falla, pero
conserva el cuerpo, que es donde la API explica qué fue mal. En una descarga
**esa virtud es el defecto**: el cuerpo del error se escribiría en
`informe.pdf`. Justo lo que queremos evitar.

| Situación | Flag | Por qué |
|---|---|---|
| Llamada a una API que devuelve JSON | `--fail-with-body` | El cuerpo del 4xx explica el error y lo quieres ver |
| Descarga a un archivo con `-o` / `-O` | `--fail` | El cuerpo del 4xx no puede acabar con el nombre del archivo |

Si necesitas el motivo del error de una descarga, pídelo aparte o guarda el
código con `-w '%{http_code}'` y reintenta la petición sin `-o`.

### 3.4 El caso que `--fail` no cubre: el archivo viejo

`--fail` no escribe nada, pero **tampoco borra** lo que ya estaba. Si ayer
descargaste `informe.pdf` y hoy el servidor da 404, el de ayer sigue ahí y tu
script no se entera de que no hay versión nueva. Y con un archivo a medias es
peor: curl ya lo había creado cuando la conexión se cortó.

```bash
# --remove-on-error (7.83+): si la transferencia falla, borra el archivo.
curl -sS --fail --remove-on-error -o informe.pdf URL

# En 7.81 no existe. La alternativa hace lo mismo:
curl -sS --fail -o informe.pdf URL || rm -f informe.pdf
```

Ninguna de las dos resuelve el caso de fondo: mientras curl escribe, el
archivo tiene el nombre definitivo y quien lo lea ve una descarga a medias. La
solución completa — descargar a `informe.pdf.part` y renombrar al final — es
el tema del [archivo 02](02-rangos-y-descargas-reanudables.md).

### 3.5 Saber qué nombre se usó

```bash
# %{filename_effective} es el nombre con el que curl escribio de verdad.
# Con -J no lo sabes de antemano: esta es la forma de averiguarlo.
curl -sS -OJ -w '%{filename_effective}\n' \
  "http://localhost:8080/response-headers?Content-Disposition=attachment%3B%20filename%3Dotro.txt"
# otro.txt
```

### 3.6 Varias URLs, cada una a su archivo

```bash
# Un -O por URL, en el mismo orden.
curl -sS -O http://localhost:8080/range/10 -O http://localhost:8080/range/20

# O --remote-name-all, que aplica -O a todas.
curl -sS --remote-name-all http://localhost:8080/range/10 http://localhost:8080/range/20
ls
# 10  20
```

Un solo `-O` con dos URLs guarda la primera y vuelca la segunda a la terminal.
Es el error de quien da por hecho que `-O` es global.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `curl -s -o archivo URL` en un script | Un 404 sale con 0 y deja la página de error con el nombre del archivo | `curl -fsS -o archivo URL` |
| `--fail-with-body` en una descarga | El cuerpo del error acaba en el archivo, que es lo que `--fail` evita | `--fail` a secas |
| `-O` con una URL con query string | El archivo se llama `export?id=7&fmt=csv` | `-o` con un nombre explícito |
| `-OJ` contra un servidor que no controlas | El nombre lo elige el servidor | `-o` con un nombre tuyo |
| `curl URL > archivo` | Igual que `-o`, pero además el shell crea el archivo **antes** de que curl conecte: un fallo de DNS deja un archivo vacío | `-o archivo` con `--fail` |
| `-k` para que una descarga por HTTPS "funcione" | Descargas un binario que cualquiera en medio pudo cambiar, y luego lo ejecutas | `--cacert` con la CA correcta (Semana 05) |
| `curl URL \| bash` sin leer | Ejecutas lo que el servidor quiera, incluida una descarga cortada a mitad de una línea | Descarga, lee, verifica el hash, ejecuta |

---

## 5. Trucos

```bash
# Ver que es lo que te han dado, sin abrirlo: los primeros bytes son la firma
# del formato. %PDF, PK (zip), \x89PNG, <!DOCTYPE (HTML: mala senal).
curl -s -r 0-15 http://localhost:8080/image/png | xxd | head -1
# 00000000: 8950 4e47 0d0a 1a0a 0000 000d 4948 4452  .PNG........IHDR
```

```bash
# Forzar la salida binaria a la terminal cuando de verdad la quieres, por
# ejemplo para pasarla por un pipe que curl no detecta como pipe.
curl -s --output - http://localhost:8080/image/png | wc -c
```

```bash
# Nombre del archivo que propondria el servidor, sin descargarlo.
curl -sI "http://localhost:8080/response-headers?Content-Disposition=attachment%3B%20filename%3Dinforme.txt" \
  | grep -i '^content-disposition'
# Content-Disposition: attachment; filename=informe.txt
```

---

## 📚 Recursos Adicionales

- [manpage de curl — `-O`](https://curl.se/docs/manpage.html#-O) — incluida la advertencia sobre la query string
- [manpage de curl — `-J`](https://curl.se/docs/manpage.html#-J) — las reglas de seguridad del nombre que manda el servidor
- [RFC 6266 — Content-Disposition en HTTP](https://datatracker.ietf.org/doc/html/rfc6266) — `filename` y `filename*`
- [everything.curl.dev — Download](https://everything.curl.dev/usingcurl/downloads/) — el capítulo de descargas del libro oficial

---

## ✅ Checklist de Verificación

- [ ] Sé qué nombre va a usar `-O` con `http://localhost:8080/range/10?x=1` antes de ejecutarlo
- [ ] He descargado con `-OJ` y he leído el nombre con `%{filename_effective}`
- [ ] He visto un 404 guardado como archivo sin `--fail`, y el mismo 404 sin archivo con `--fail`
- [ ] Sé explicar por qué en una descarga uso `--fail` y no `--fail-with-body`
- [ ] Sé qué no resuelve `--fail`: el archivo viejo y el archivo a medias
- [ ] Conozco la alternativa a `--remove-on-error` en curl 7.81
- [ ] He usado `--output-dir` o, si mi curl es anterior a 7.73, su alternativa

---

| Anterior | Siguiente |
|---|---|
| [Semana 03 — Autenticación básica](../../week-03-autenticacion_basica/README.md) | [02 — Rangos y descargas reanudables](02-rangos-y-descargas-reanudables.md) |
