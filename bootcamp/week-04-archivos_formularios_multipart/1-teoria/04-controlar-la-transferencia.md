# Controlar la transferencia

> Una petición de API dura milisegundos y un `--max-time 10` la cubre. Una
> descarga de 2 GB dura lo que dure, y ese mismo límite la mata a los diez
> segundos. Las descargas necesitan otro tipo de límites.

![Diagrama de los cuatro límites de una transferencia sobre una línea de tiempo: --connect-timeout acota el establecimiento de la conexión, --speed-limit con --speed-time corta si la velocidad cae por debajo de un mínimo durante un periodo, --max-time es el techo absoluto, y --max-filesize rechaza por tamaño; aparte, --limit-rate frena a curl sin cortar nada](../0-assets/04-controlar-la-transferencia.svg)

## 🎯 Objetivos

- Distinguir los cuatro límites que cortan una transferencia y el que solo la frena
- Explicar por qué `--max-time` solo no sirve para una descarga grande
- Detectar una conexión muerta que no se ha cerrado con `--speed-limit` y `--speed-time`
- Usar `--max-filesize` sabiendo cuándo puede cortar y cuándo no en curl 7.81
- Frenar una descarga con `--limit-rate` para no saturar una red compartida
- Elegir entre la barra de progreso, el medidor completo y el silencio

---

## 1. Qué problema resuelve

En la Semana 01 la regla fue "toda petición lleva `--max-time`". Con llamadas
a una API funciona: si en diez segundos no hay respuesta, algo va mal.

Una descarga rompe esa regla por los dos lados:

- **Por arriba**: un archivo de 2 GB a 10 MB/s tarda 200 segundos. Un
  `--max-time 10` lo corta siempre, aunque todo vaya bien.
- **Por abajo**: quitar el límite tampoco vale. Una conexión que se queda
  colgada — el otro extremo desapareció, pero nadie cerró el socket — no da
  error nunca. Tu cron se queda esperando para siempre.

Lo que se necesita es distinguir **lento pero vivo** de **muerto**, y eso no
lo hace un techo de tiempo.

---

## 2. Cómo funciona

### 2.1 Los cinco controles

| Flag | Qué controla | Si se supera | Código |
|---|---|---|:--:|
| `--connect-timeout S` | Tiempo para establecer la conexión (TCP + TLS) | Aborta | 28 |
| `--max-time S` (`-m`) | Tiempo total de la operación, de principio a fin | Aborta | 28 |
| `--speed-limit B` + `--speed-time S` | Velocidad mínima: si baja de `B` bytes/s durante `S` segundos seguidos | Aborta | 28 |
| `--max-filesize B` | Tamaño máximo del cuerpo | Aborta | 63 |
| `--limit-rate B` | Velocidad máxima | **No aborta**: frena a curl | — |

Los tres que salen con 28 se distinguen por el mensaje, no por el código:

```bash
curl -sS --max-time 1 -o /dev/null http://localhost:8080/delay/3
# curl: (28) Operation timed out after 1001 milliseconds with 0 bytes received
curl -sS --speed-limit 100000 --speed-time 2 -o /dev/null \
  "http://localhost:8080/drip?numbytes=10&duration=5&delay=0"
# curl: (28) Operation too slow. Less than 100000 bytes/sec transferred the last 2 seconds
```

### 2.2 Las unidades

Los tiempos son segundos y aceptan decimales: `--max-time 2.5`. Los tamaños son
bytes y aceptan sufijos: `--limit-rate 500K`, `--max-filesize 2G`. **`K` es
1024**, no 1000.

### 2.3 El detector de conexiones muertas

`--speed-limit` y `--speed-time` se usan juntos. La frase que leen es: "si
durante `speed-time` segundos seguidos la velocidad media no llega a
`speed-limit` bytes por segundo, aborta".

```bash
# Menos de 1 KB/s durante 30 segundos = la conexion esta muerta.
curl -fsS --speed-limit 1024 --speed-time 30 -o grande.bin.part URL
```

Con `--speed-time` solo, el límite por defecto es 1 byte/s: atrapa una
conexión totalmente parada, pero no una que gotea un byte cada segundo.

### 2.4 `--max-filesize` y su punto ciego

curl puede rechazar un archivo demasiado grande **antes** de descargarlo, si el
servidor anuncia el tamaño con `Content-Length`:

```bash
curl -sS --max-filesize 100 -o /dev/null http://localhost:8080/range/1000
# curl: (63) Maximum file size exceeded
```

Sin `Content-Length` — respuestas `chunked`, generadas al vuelo — el
comportamiento depende de la versión:

```bash
curl -s --max-filesize 100 -o /dev/null http://localhost:8080/stream-bytes/1000
echo $?
# 0     ← curl 7.81: no sabe el tamano de antemano, y descarga los 1000 bytes
# 63    ← curl 8.x recientes (comprobado con 8.21): corta en cuanto lo supera
```

En 7.81, `--max-filesize` **no te protege** de un servidor que manda un cuerpo
infinito sin `Content-Length`. Para eso queda `--max-time`.

---

## 3. Cómo se usa

### 3.1 La combinación para una descarga

```bash
# --connect-timeout 10: si en 10 s no conecta, no va a conectar.
# --speed-limit/--speed-time: lento se tolera, parado no.
# --max-time 3600: techo absoluto. Generoso, pero existe: el cron no se
#   queda colgado nunca.
# --max-filesize 2G: si alguien cambia el archivo por uno de 50 GB, no llena
#   el disco (cuando el servidor anuncia el tamano).
curl -fsS --connect-timeout 10 \
     --speed-limit 1024 --speed-time 30 \
     --max-time 3600 --max-filesize 2G --retry 3 \
     -C - -o imagen.iso.part https://descargas.ejemplo.com/imagen.iso \
  && mv imagen.iso.part imagen.iso
```

Para una llamada de API, en cambio, sigue valiendo lo de siempre: un
`--max-time` corto y nada más.

| Tipo de petición | Límites |
|---|---|
| Llamada a una API (JSON, pocos KB) | `--max-time 10` a `30` |
| Descarga de tamaño conocido | `--connect-timeout` + `--speed-limit`/`--speed-time` + `--max-time` holgado |
| Descarga de origen no fiable | Lo anterior + `--max-filesize` |

### 3.2 Frenar sin cortar: `--limit-rate`

Bajar 4 GB en la red de la oficina a toda velocidad deja sin ancho de banda a
todos los demás. `--limit-rate` pone un techo de velocidad:

```bash
curl -s --limit-rate 50K -o /dev/null \
  -w '%{size_download} bytes a %{speed_download} B/s en %{time_total} s\n' \
  http://localhost:8080/range/200000
# 200000 bytes a 54926 B/s en 3.641218 s
```

La media sale algo por encima de 51.200 B/s (50 × 1024): curl regula por
ventanas de tiempo y al principio se adelanta. Sobre una descarga larga la
media converge al límite.

`--limit-rate` vale para subidas igual que para descargas.

### 3.3 Lo que se ve en la terminal

| Forma | Qué enseña | Cuándo |
|---|---|---|
| Sin flags, con `-o` | El medidor completo: porcentaje, velocidad, tiempo restante | Descargas a mano |
| `-#` (`--progress-bar`) | Una barra de `#` y el porcentaje | Descargas a mano, salida limpia |
| `--no-progress-meter` (7.67+) | Nada de progreso, pero **sí** los mensajes de error | Scripts |
| `-s` (`--silent`) | Nada, ni progreso ni errores | Casi nunca solo |
| `-sS` | Nada salvo los errores | Scripts, la forma clásica |

```bash
curl -# -o /dev/null http://localhost:8080/range/200000 --limit-rate 50K
# ######################################################################## 100.0%
```

El medidor sale por stderr. Si en un script quieres los errores pero no el
progreso, `-sS` o `--no-progress-meter`; las dos sirven en 7.81.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `--max-time 10` en una descarga grande | Corta todas las descargas que tarden más de diez segundos, aunque vayan bien | `--speed-limit`/`--speed-time` y un `--max-time` holgado |
| Ningún límite en una descarga de un cron | Una conexión colgada deja el cron esperando para siempre, y el siguiente se solapa | Siempre un `--max-time`, aunque sea de una hora |
| Confiar en `--max-filesize` en 7.81 | No corta una respuesta sin `Content-Length` | `--max-time` como red de seguridad |
| `--speed-time` sin `--speed-limit` | Solo atrapa la conexión parada del todo | Los dos juntos, con un mínimo razonable |
| `-s` solo en un script | Cuando falla, no hay ni un mensaje en el log | `-sS` |
| `-k` para que una descarga lenta por TLS "vaya" | No tiene nada que ver con la velocidad y abre la puerta a un binario cambiado | Diagnosticar con `-v` y `--write-out` (Semana 06) |

---

## 5. Trucos

```bash
# Ver la velocidad media real de una descarga, sin el medidor.
curl -s -o /dev/null -w '%{speed_download}\n' http://localhost:8080/range/200000
```

```bash
# Simular una red lenta para probar tus limites. /drip manda numbytes bytes
# repartidos en duration segundos.
curl -sS --speed-limit 10 --speed-time 2 -o /dev/null \
  "http://localhost:8080/drip?numbytes=5&duration=10&delay=0"; echo $?
# curl: (28) Operation too slow. Less than 10 bytes/sec transferred the last 2 seconds
# 28
```

```bash
# Saber si --max-filesize va a poder actuar: busca Content-Length.
curl -sI http://localhost:8080/stream-bytes/1000 | grep -ci '^content-length'
# 0   ← sin Content-Length: en 7.81 no puede cortar
```

---

## 📚 Recursos Adicionales

- [manpage de curl — `--speed-limit`](https://curl.se/docs/manpage.html#-Y) — y su pareja `--speed-time`
- [manpage de curl — `--max-filesize`](https://curl.se/docs/manpage.html#--max-filesize) — la nota sobre transferencias sin tamaño conocido
- [manpage de curl — `--limit-rate`](https://curl.se/docs/manpage.html#--limit-rate) — unidades y sufijos
- [everything.curl.dev — Timeouts](https://everything.curl.dev/usingcurl/timeouts.html) — los límites explicados por el autor de curl

---

## ✅ Checklist de Verificación

- [ ] Sé qué límite usar para una llamada de API y cuáles para una descarga de 2 GB
- [ ] He provocado un 28 por `--max-time` y otro por `--speed-limit`, y los distingo por el mensaje
- [ ] He visto un 63 de `--max-filesize` contra `/range/1000`
- [ ] Sé por qué `--max-filesize` no cortó `/stream-bytes/1000` en curl 7.81
- [ ] He frenado una descarga con `--limit-rate` y he medido la velocidad con `speed_download`
- [ ] Sé la diferencia entre `-s`, `-sS` y `--no-progress-meter`

---

| Anterior | Siguiente |
|---|---|
| [03 — Verificar lo descargado](03-verificar-lo-descargado.md) | [05 — Formularios urlencoded](05-formularios-urlencoded.md) |
