# Semana 04 — Archivos, formularios y multipart

> Hasta ahora el cuerpo era un JSON que cabía en una línea. Esta semana el cuerpo
> es un archivo: de megas, binario, que llega a medias o no llega, y que hay que subir en el formato que el servidor espera.

---

## 🎯 Objetivos de la Semana

Al terminar serás capaz de:

- Descargar con `-o`, `-O` y `-J`, y saber de dónde sale el nombre del archivo en cada caso
- Evitar el fallo más común de una descarga en un script: **guardar la página de error del 404 con el nombre del archivo**
- Pedir un trozo de un recurso con `Range`, leer un `206` y su `Content-Range`, y saber qué significa un `416`
- Reanudar una descarga cortada con `-C -`, y explicar por qué un servidor que ignora `Range` puede corromperte el archivo
- Comprobar que lo descargado es lo que pediste: tamaño, tipo y **SHA-256**
- Poner límites a una transferencia: techo de tiempo, velocidad mínima, tamaño máximo y ancho de banda
- Enviar un formulario `application/x-www-form-urlencoded` con `-d` y `--data-urlencode`, y saber qué hace cada uno con el `&`, el espacio y el salto de línea
- Leer un cuerpo `multipart/form-data` por dentro — boundary, partes, `Content-Disposition` — y construirlo con `-F`
- Subir un archivo tal cual con `-T` o `--data-binary @`, y elegir entre crudo, multipart y JSON según lo que espera el servidor

---

## 📋 Prerrequisitos

- **Semana 03 completada**: `api-toolkit.sh` con los cuatro modos de autenticación y `./scripts/verificar-semana.sh 03` en verde
- **El laboratorio levantado**: `./scripts/start.sh` — ver [setup-entorno](../../docs/setup-entorno.md)
- **`jq` instalado**: `jq --version`
- **`sha256sum` disponible** (coreutils en Linux; en macOS es `shasum -a 256`): `echo hola | sha256sum`
- **Saber leer la salida de `-v`**: líneas `>` son lo que envías, `<` lo que recibes. Lo viste en la Semana 01
- **Tu versión de curl a mano**: `curl --version | head -1`. Esta semana aparecen `--output-dir` (7.73+) y `--remove-on-error` (7.83+); en 7.81 el segundo no existe y se da la alternativa

---

## 🗂️ Estructura de la Semana

```
week-04-archivos_formularios_multipart/
├── README.md                  # Este archivo
├── rubrica-evaluacion.md      # Cómo se evalúa
├── checks.json                # Las 18 comprobaciones automáticas
├── 0-assets/                  # Diagramas
├── 1-teoria/                  # 8 archivos, un concepto cada uno
├── 2-practicas/               # 4 prácticas sobre el laboratorio
├── 3-proyecto/                # La capa 4 de api-toolkit: las transferencias
├── 4-recursos/                # Libros, vídeos y enlaces
└── 5-glosario/                # Términos de esta semana
```

---

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01 — Descargar un archivo](1-teoria/01-descargar-un-archivo.md) | `-o`, `-O`, `-J`, `--output-dir` (7.73+), y la página de error guardada como archivo | 15 min |
| [02 — Rangos y descargas reanudables](1-teoria/02-rangos-y-descargas-reanudables.md) | `Range`, `206`, `Content-Range`, `-r`, `-C -`, el `416` y el patrón `.part` | 15 min |
| [03 — Verificar lo descargado](1-teoria/03-verificar-lo-descargado.md) | `Content-Length` frente a `size_download`, `content_type`, SHA-256 y `SHA256SUMS` | 15 min |
| [04 — Controlar la transferencia](1-teoria/04-controlar-la-transferencia.md) | `--max-time`, `--speed-limit`, `--max-filesize`, `--limit-rate` y la barra de progreso | 15 min |
| [05 — Formularios urlencoded](1-teoria/05-formularios-urlencoded.md) | `-d`, `--data-urlencode` y sus cinco formas, `-d @` frente a `--data-binary @`, `-G` | 15 min |
| [06 — Multipart por dentro](1-teoria/06-multipart-por-dentro.md) | Boundary y partes, `-F` con `@`, `<`, `;type=`, `;filename=`, `--form-string`, `Expect` | 15 min |
| [07 — Subir el cuerpo en crudo](1-teoria/07-subir-el-cuerpo-en-crudo.md) | `-T` y su `PUT`, la URL que acaba en `/`, `-T -` y el chunked, `--data-binary @` | 15 min |
| [08 — Elegir cómo subir](1-teoria/08-elegir-como-subir.md) | Crudo, multipart o JSON con base64: qué espera cada servidor y cuánto cuesta cada uno | 15 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01 — Descargar y reanudar](2-practicas/01-descargar-y-reanudar.md) | `-O` y `-J`, cazar la página de error, pedir rangos, cortar una descarga y reanudarla | 50 min |
| [02 — Verificar y limitar](2-practicas/02-verificar-y-limitar.md) | Tamaño, tipo y SHA-256 de lo descargado; un `SHA256SUMS`; los cuatro límites de una transferencia | 50 min |
| [03 — Formularios y multipart](2-practicas/03-formularios-y-multipart.md) | Codificar un formulario a mano y con curl, leer un multipart byte a byte, subir con `-F` | 50 min |
| [04 — Subir en crudo y elegir](2-practicas/04-subir-en-crudo-y-elegir.md) | `-T`, `--data-binary @`, stdin chunked, y la misma subida en los tres formatos midiendo bytes | 50 min |

### Proyecto

La **capa 4** de tu plataforma: `api-toolkit.sh` aprende a mover archivos. Un
subcomando `download` que escribe en `DESTINO.part` y solo renombra cuando el
archivo está completo y verificado, `--resume` para continuar donde se cortó,
`--sha256` para rechazar lo que no es lo pedido, y un `upload` que sube como
multipart sin escribir a mano el `Content-Type`. Detalles en
[3-proyecto](3-proyecto/README.md).

---

## ⏱️ Distribución del Tiempo (8 horas)

| Bloque | Tiempo |
|---|:--:|
| Teoría (8 archivos) | 2 h 00 |
| Prácticas (4 × 50 min) | 3 h 20 |
| Proyecto | 2 h 00 |
| Revisión y verificación | 40 min |
| **Total** | **8 h 00** |

> [!TIP]
> Haz la práctica 01 **entera** antes de tocar el `download` del proyecto. La
> mitad de los TODOs se entienden en el momento en que ves un 404 guardado como
> `informe.pdf`, y la otra mitad cuando cortas una descarga con `Ctrl+C` y la
> reanudas.

---

## 📦 Un archivo descargado no es un archivo correcto

curl sale con `0` cuando la transferencia termina. No cuando el archivo es el
que querías. Entre una cosa y otra caben cuatro fallos distintos, y los cuatro
pasan en producción:

| Lo que pasó | Qué ves en el disco | Lo que lo detecta |
|---|---|---|
| El servidor respondió 404 | `informe.pdf` de 9 bytes que contiene `Not Found` | `--fail` |
| La conexión se cortó al 60 % | `informe.pdf` de la mitad de su tamaño | El código de salida (18, 28, 56) y el `.part` |
| Un proxy cautivo te sirvió su login | `informe.pdf` que es HTML | `%{content_type}` |
| El archivo cambió en el servidor entre dos intentos | `informe.pdf` con el tamaño correcto y bytes de dos versiones | El SHA-256 |

```bash
# Las cuatro defensas juntas. Este es el comando que se va a construir a lo
# largo de la semana, y el que acaba dentro de api-toolkit download.
curl --fail --max-time 600 --speed-limit 1024 --speed-time 30 \
     --retry 3 --continue-at - -sS \
     -o informe.pdf.part http://localhost:8080/range/1000 \
  && echo "<hash-esperado>  informe.pdf.part" | sha256sum -c - \
  && mv informe.pdf.part informe.pdf
```

Ninguna de las cuatro sobra. Quitar una es dejar pasar uno de los cuatro fallos
de la tabla con el nombre del archivo bueno.

---

## 🎩 Trucos y atajos

| Truco | Cómo |
|---|---|
| Saber con qué nombre guardó curl el archivo | `curl -sOJ -w '%{filename_effective}\n' URL`. Con `-J` el nombre lo decide el servidor, no la URL |
| Ver el tamaño de un recurso sin descargarlo | `curl -sI URL \| grep -i '^content-length'`. Si no aparece, el servidor no lo sabe de antemano y `--max-filesize` no podrá cortar a priori |
| Saber si un servidor acepta rangos antes de reanudar | `curl -sI URL \| grep -i '^accept-ranges'`. `bytes` = sí; ausente o `none` = `-C -` fallará con el 33 |
| Descargar solo el principio de un archivo para mirar qué es | `curl -s -r 0-15 URL \| xxd`. Los primeros bytes son la firma: `%PDF`, `PK` (zip), `\x89PNG` |
| Que el 404 no deje un archivo vacío en 7.81, sin `--remove-on-error` | `curl -fsS -o f URL \|\| rm -f f`. `--remove-on-error` es 7.83+ y hace exactamente eso |
| Bajar varias URLs guardando cada una con su nombre | `curl --remote-name-all URL1 URL2 URL3`. Equivale a poner un `-O` delante de cada una |
| Mandar un campo de formulario que empieza por `@` sin que curl lea un archivo | `curl --form-string 'twitter=@usuario' URL`. Con `-F` curl intentaría abrir el archivo `usuario` |
| Subir un archivo cuyo nombre lleva `;` o `,` | `curl -F 'doc=@"informe;v2.pdf"' URL`. Sin comillas, curl corta en el `;` e intenta abrir `informe`: el 26 en el mejor caso, el archivo equivocado en el peor |
| Ver el multipart exacto que curl va a enviar | `curl -s -F 'a=1' -F 'f=@archivo' http://localhost:8080/post \| jq -r .data`. El `data` de `/post` es el cuerpo crudo |
| Subir desde un pipe sin archivo intermedio | `set -o pipefail; tar cz dir \| curl -fsS -T - URL`. Sin tamaño conocido, curl usa `Transfer-Encoding: chunked`. Sin `pipefail`, un `tar` que falla sube un archivo truncado con código 0 |
| Quitar la espera del `Expect: 100-continue` en subidas grandes | `curl -H 'Expect:' -T grande.bin URL`. El header vacío lo suprime; útil cuando el servidor no contesta el `100` y curl espera 1 s |
| Medir a qué velocidad subiste | `curl -s -T f -o /dev/null -w '%{size_upload} B a %{speed_upload} B/s\n' URL` |

---

## 📌 Entregables

1. `descargas.md` con los nombres que dieron `-O`, `-O` con query string y `-OJ` en la práctica 01, y por qué difieren
2. `pagina-de-error.md` con el `xxd` del archivo que dejó un 404 sin `--fail`, y el comando que lo evita
3. `reanudar.md` con las cabeceras `Range` y `Content-Range` de la reanudación, y el `cmp` final contra la descarga completa
4. `SHA256SUMS` generado en la práctica 02 y la salida de `sha256sum -c` en verde y en rojo
5. `limites.md` con el código de salida de cada uno de los cuatro límites de la práctica 02
6. `multipart.txt` con un cuerpo multipart real anotado: dónde está el boundary, cada parte y su `Content-Disposition`
7. `tres-formatos.md` con la misma subida en crudo, multipart y JSON, y los bytes enviados en cada caso
8. `api-toolkit.sh` con `download` y `upload`, y ningún `TODO` pendiente
9. `download` no deja ningún archivo en el destino cuando la API responde un error
10. `--resume` continúa el `.part` existente, y no falla cuando ya estaba completo
11. `--sha256` rechaza y borra un archivo que no coincide
12. `upload` no escribe a mano el `Content-Type` multipart, ni hay ningún `-k`

---

## ✅ Verificación

```bash
./scripts/start.sh
./scripts/verificar-semana.sh 04
```

Las 18 comprobaciones tienen que pasar. Si alguna falla, la pista te dice en qué
práctica y en qué paso se arregla.

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [Semana 03 — Autenticación básica](../week-03-autenticacion_basica/README.md) | **Semana 04 — Archivos, formularios y multipart** | [Semana 05 — SSL/TLS, cookies y redirects](../week-05-ssl_tls_cookies_redirects/README.md) |

[← Volver al inicio del bootcamp](../README.md)
