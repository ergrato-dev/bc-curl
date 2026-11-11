# `--trace` y `--trace-ascii`

> `-v` cuenta la conversación; `--trace` la graba. Cada byte que sale y cada
> byte que entra, cuerpo incluido, tal como viajó. Es la herramienta para
> cuando ya no te fías de lo que crees que estás enviando.

![Diagrama comparando las tres trazas de curl: -v muestra headers y decisiones de curl pero resume los datos en una línea de tamaño; --trace-ascii muestra además cada bloque de datos en texto con su desplazamiento; --trace añade el volcado hexadecimal; las tres pueden llevar --trace-time, y las dos últimas escriben a un archivo o a stdout con -](../0-assets/06-trace-y-trace-ascii.svg)

## 🎯 Objetivos

- Saber qué enseña `--trace-ascii` que `-v` no enseña
- Elegir entre `--trace-ascii` y `--trace` según si necesitas los bytes exactos
- Encontrar la fase lenta con `--trace-time`
- Ver el cuerpo que enviaste y el que llegó antes de descomprimir
- Saber por qué una traza completa es más peligrosa que una `-v`

---

## 1. Qué problema resuelve

Una API rechaza tu POST con un `400 Bad Request` y el mensaje "JSON inválido".
El JSON de tu script parece perfecto. `-v` te enseña los headers, pero el
cuerpo lo resume en una línea: `} [7 bytes data]`. No ves qué siete bytes
eran.

Quizás el shell se comió unas comillas, quizás hay un `\r` de un archivo
editado en Windows, quizás un BOM al principio. Ninguno se ve en `-v`. Todos se
ven en `--trace-ascii`.

---

## 2. Cómo funciona

### 2.1 Las tres trazas

| Opción | Headers | Datos del cuerpo | Formato | Destino |
|---|:--:|:--:|---|---|
| `-v` | ✅ | Solo el tamaño | Texto, con marcas `*` `>` `<` | stderr |
| `--trace-ascii ARCHIVO` | ✅ | ✅ | Texto con desplazamiento; los no imprimibles como `.` | El archivo |
| `--trace ARCHIVO` | ✅ | ✅ | Hexadecimal más texto | El archivo |

`-` como archivo significa **stdout**, no stderr. Con `--trace-ascii -` hay que
mandar el cuerpo a otro sitio (`-o /dev/null` o `-o archivo`) o se mezclarán.

Si se ponen varias, gana la última: `--trace-ascii` sustituye a `-v`, no se
suma.

### 2.2 Qué se ve con `--trace-ascii`

```bash
curl -s --trace-ascii - -o /dev/null -d '{"a":1}' http://localhost:8080/post
# == Info:   Trying 127.0.0.1:8080...
# == Info: Connected to localhost (127.0.0.1) port 8080 (#0)
# => Send header, 151 bytes (0x97)
# 0000: POST /post HTTP/1.1
# 0015: Host: localhost:8080
# 002b: User-Agent: curl/7.81.0
# 0044: Accept: */*
# 0051: Content-Length: 7
# 0064: Content-Type: application/x-www-form-urlencoded
# 0095:
# => Send data, 7 bytes (0x7)
# 0000: {"a":1}
# == Info: Mark bundle as not supporting multiuse
# <= Recv header, 17 bytes (0x11)
# 0000: HTTP/1.1 200 OK
# ...
```

Las marcas cambian respecto a `-v`:

| `--trace-ascii` | `-v` equivalente |
|---|---|
| `== Info:` | `*` |
| `=> Send header` | `>` |
| `<= Recv header` | `<` |
| `=> Send data` | `} [N bytes data]`, pero ahora con los bytes |
| `<= Recv data` | `{ [N bytes data]`, pero ahora con los bytes |

El número de la izquierda es el desplazamiento en hexadecimal dentro del
bloque. Y fíjate en el `Content-Type`: `-d` manda
`application/x-www-form-urlencoded` aunque el cuerpo sea JSON. Es el error que
la Semana 02 enseñó a evitar con `-H 'Content-Type: application/json'`, y aquí
se ve sin interpretar nada.

### 2.3 `--trace`: los bytes exactos

```bash
curl -s --trace - -o /dev/null -d 'hola' http://localhost:8080/post | sed -n 4,5p
# 0000: 50 4f 53 54 20 2f 70 6f 73 74 20 48 54 54 50 2f POST /post HTTP/
# 0010: 31 2e 31 0d 0a 48 6f 73 74 3a 20 6c 6f 63 61 6c 1.1..Host: local
```

`0d 0a` es el CR LF que termina cada línea. Un `\r` de más en tu cuerpo, un BOM
(`ef bb bf`) al principio de un archivo o un carácter no ASCII mal codificado
solo se distinguen aquí. `--trace-ascii` los convierte en `.` y se confunden
con cualquier otro byte no imprimible.

### 2.4 Lo que llegó por el cable, no lo que te enseña curl

La traza graba los bytes **antes** de que curl los procese. Dos casos donde eso
importa:

```bash
# Con --compressed, el cuerpo viaja comprimido. La traza ve 207 bytes de gzip;
# lo que curl escribe en stdout es el JSON descomprimido.
curl -s --trace-ascii - -o /dev/null --compressed http://localhost:8080/gzip \
  | grep -E 'Content-Encoding|Recv data'
# 0000: Content-Encoding: gzip
# <= Recv data, 207 bytes (0xcf)

# Con Transfer-Encoding: chunked, la traza ve los trozos, con sus marcas de
# tamano. stdout recibe el cuerpo ya reensamblado.
curl -s --trace-ascii - -o /dev/null http://localhost:8080/stream/2 \
  | grep -E 'Transfer-Encoding|Recv data'
# 0000: Transfer-Encoding: chunked
# <= Recv data, 340 bytes (0x154)
# <= Recv data, 5 bytes (0x5)
```

Si el cuerpo que te llega está mal, la traza te dice si llegó así del servidor
o si lo estropeó algo de tu lado.

### 2.5 `--trace-time`: ¿cuál fue el paso lento?

```bash
curl -s --trace-ascii - --trace-time -o /dev/null http://localhost:8080/delay/1 \
  | grep -E '(Send|Recv) header' | head -2
# 19:43:10.710833 => Send header, 85 bytes (0x55)
# 19:43:11.713769 <= Recv header, 17 bytes (0x11)
```

Un segundo entre enviar y recibir: la fase servidor. `--trace-time` también
funciona con `-v`. Es la versión de la teoría 04 para cuando no sabes qué
medir: la traza entera con su reloj.

---

## 3. Cómo se usa

### 3.1 Comprobar el cuerpo que envías

```bash
# El archivo que el script cree que manda, tal como viaja
printf '{"nombre":"prueba"}\r\n' > datos.json     # un \r\n de un editor de Windows
curl -s --trace - -o /dev/null -H 'Content-Type: application/json' \
  --data-binary @datos.json http://localhost:8080/post | grep -A1 'Send data'
# => Send data, 21 bytes (0x15)
# 0000: 7b 22 6e 6f 6d 62 72 65 22 3a 22 70 72 75 65 62 {"nombre":"prueb
```

21 bytes para un JSON de 19 caracteres: los dos que sobran son el `\r\n` final.
Con `-d @datos.json` en vez de `--data-binary`, curl habría quitado los saltos
de línea; la traza es la forma de saberlo sin leer el manual.

### 3.2 Opciones de la versión 8

Dos opciones añaden detalle a cualquier traza. Ninguna está en 7.81:

```bash
# --trace-ids (8.2+) antepone el numero de transferencia y de conexion a cada
# linea. Imprescindible con --parallel (Semana 09), donde las trazas se mezclan.
curl -s -v --trace-ids -o /dev/null http://localhost:8080/get
# [0-0] * Host localhost:8080 was resolved.

# --trace-config (8.3+) enciende la traza de componentes internos: tls, http/2,
# dns... Con 'all', todos.
curl -s -v --trace-config tls -o /dev/null --cacert docs/lab-ca.pem https://localhost:8443/get
```

Sin ellas, en 7.81: lanza las transferencias por separado, cada una con su
`--trace-ascii`, y nada se mezcla.

### 3.3 `--libcurl`: del comando al código

```bash
curl -s --libcurl programa.c -o /dev/null http://localhost:8080/get
grep -c curl_easy_setopt programa.c
# 10
```

Escribe un programa en C que hace lo mismo que tu comando, con una línea
`curl_easy_setopt` por opción. No es depuración en sentido estricto, pero es la
forma más honesta de ver **todas** las opciones que curl aplicó, incluidas las
que venían de un `.curlrc` (teoría 07).

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Compartir una traza completa "tachada" con el mismo `sed` que la `-v` | El cuerpo también viaja, y una API que hace eco devuelve tu `Authorization` dentro del JSON de respuesta | Una traza completa no se comparte: se lee tú y se cita el fragmento |
| `--trace-ascii -` sin `-o` | Traza y cuerpo se mezclan en stdout | `-o /dev/null` o `-o archivo` |
| `--trace-ascii` para buscar un `\r` o un BOM | Los dos salen como `.` | `--trace`, y buscar `0d` o `ef bb bf` |
| Una traza completa de una descarga grande | Cada byte, en hexadecimal: archivos de gigas | `-v`, o `--trace` contra un rango pequeño |
| Dejar `--trace` en un script de producción | Escribe en disco el cuerpo de cada petición, credenciales incluidas | Solo a mano, y borrar el archivo después |

---

## 5. Trucos

- **`--trace-ascii traza.txt` sin `-v`**: es su superconjunto, no hace falta
  sumarlas.
- **`grep -A3 'Send data'`** sobre una traza encuentra el cuerpo enviado al
  instante.
- **`--trace-time` con `-v`** es lo más barato para encontrar una pausa: no
  graba datos, solo pone hora a las líneas.
- **`--libcurl -`** escribe el programa en stdout. Combínalo con `-q` y sin
  `-q` para ver qué añade tu `.curlrc`.

---

## 📚 Recursos Adicionales

- [everything.curl.dev — Trace options](https://everything.curl.dev/usingcurl/verbose/trace.html)
- [Manpage: `--trace-ascii`](https://curl.se/docs/manpage.html#--trace-ascii)
- [Manpage: `--libcurl`](https://curl.se/docs/manpage.html#--libcurl)
- [RFC 9112 §7.1 — Chunked transfer coding](https://datatracker.ietf.org/doc/html/rfc9112#section-7.1)

---

## ✅ Checklist de Verificación

- [ ] Con `--trace-ascii -` ves el cuerpo de un POST, y con `-v` no
- [ ] Encuentras el `0d 0a` de un archivo con final de línea de Windows usando `--trace`
- [ ] Explicas por qué la traza de `/gzip` dice 207 bytes y stdout recibe más
- [ ] `--trace-time` te enseña el segundo de `/delay/1`
- [ ] Sabes si tu curl tiene `--trace-ids` y qué hacer si no
