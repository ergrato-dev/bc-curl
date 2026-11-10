# Rangos y descargas reanudables

> Una descarga de 2 GB que se corta al 90 % no debería costar otros 2 GB. HTTP
> permite pedir solo los bytes que faltan; curl lo hace con un guion.

![Diagrama de una reanudación: el archivo local de 500 bytes, curl mide su tamaño y envía Range: bytes=500-, el servidor responde 206 con Content-Range: bytes 500-999/1000 y curl añade el resto; abajo, las tres respuestas posibles: 206 continúa, 200 significa que el servidor ignoró el rango, 416 que ya no falta nada](../0-assets/02-rangos-y-descargas-reanudables.svg)

## 🎯 Objetivos

- Pedir un trozo de un recurso con `-r` y leer el `206` y su `Content-Range`
- Saber, antes de intentarlo, si un servidor acepta rangos
- Reanudar con `-C -` y explicar qué hace curl por debajo
- Interpretar las tres respuestas a una reanudación: `206`, `200` y `416`
- Montar el patrón `.part` + `mv` que hace que nadie vea nunca un archivo a medias
- Saber qué riesgo queda cuando el archivo cambia en el servidor entre dos intentos

---

## 1. Qué problema resuelve

Las conexiones se cortan. Una VPN que se reconecta, un portátil que se duerme,
un proxy que mata las conexiones de más de cinco minutos, un `Ctrl+C`. Sin
rangos, cada corte obliga a empezar de cero: con un archivo grande y una red
mala, la descarga puede no terminar nunca.

HTTP lo resolvió en 1999 con las **peticiones de rango**: el cliente dice qué
bytes quiere, el servidor manda solo esos. Hoy están en el
[RFC 9110 §14](https://datatracker.ietf.org/doc/html/rfc9110#section-14).

---

## 2. Cómo funciona

### 2.1 La conversación

| Quién | Header | Significado |
|---|---|---|
| Servidor | `Accept-Ranges: bytes` | "Acepto rangos en bytes" — lo anuncia en cualquier respuesta |
| Cliente | `Range: bytes=500-` | "Dame desde el byte 500 hasta el final" |
| Servidor | `206 Partial Content` | "Te mando solo un trozo" |
| Servidor | `Content-Range: bytes 500-999/1000` | "Son los bytes 500 a 999 de un total de 1000" |

Los bytes se cuentan desde cero y los dos extremos son inclusivos: `0-9` son
diez bytes.

### 2.2 Las formas de `-r`

`-r` (`--range`) escribe el header `Range` por ti:

| `-r` | Header enviado | Qué pides |
|---|---|---|
| `-r 0-9` | `Range: bytes=0-9` | Los diez primeros bytes |
| `-r 20-` | `Range: bytes=20-` | Desde el byte 20 hasta el final |
| `-r -5` | `Range: bytes=-5` | Los **cinco últimos** bytes |
| `-r 0-4,10-14` | `Range: bytes=0-4,10-14` | Dos trozos a la vez |

```bash
# /range/26 del laboratorio devuelve el abecedario: un byte por letra.
curl -s -r 0-9 http://localhost:8080/range/26; echo
# abcdefghij
curl -s -r -5 http://localhost:8080/range/26; echo
# vwxyz
```

Con varios trozos la respuesta ya no es un bloque: es un
`multipart/byteranges`, con un boundary entre trozo y trozo — la misma idea que
el multipart de los formularios del [archivo 06](06-multipart-por-dentro.md).

```bash
curl -s -D - -o /dev/null -r 0-4,10-14 http://localhost:8080/range/26 \
  | grep -i '^content-type'
# Content-Type: multipart/byteranges; boundary=445448a0...
```

### 2.3 Saber si el servidor acepta rangos

```bash
curl -sI http://localhost:8080/range/1000 | grep -i '^accept-ranges'
# Accept-Ranges: bytes
curl -sI http://localhost:8080/bytes/1000 | grep -i '^accept-ranges'
# (nada)
```

Sin `Accept-Ranges: bytes`, o con `Accept-Ranges: none`, no cuentes con poder
reanudar. Y que lo anuncie tampoco es garantía: hay CDNs que lo anuncian y
luego responden 200. Lo que manda es el código de la respuesta, no el anuncio.

---

## 3. Cómo se usa

### 3.1 `-C -`: reanudar donde se quedó

`-C` (`--continue-at`) recibe un desplazamiento. Con un número, empieza ahí. Con
un guion, **curl mira el tamaño del archivo de salida y empieza en ese byte**:

```bash
# Simular una descarga cortada: solo los 10 primeros bytes.
curl -s -r 0-9 -o abc.txt http://localhost:8080/range/26

# Reanudar. curl ve que abc.txt mide 10 bytes y pide desde el 10.
curl -s -C - -o abc.txt -v http://localhost:8080/range/26 2>&1 \
  | grep -iE '^> range|^< (HTTP|content-range)'
# > Range: bytes=10-
# < HTTP/1.1 206 Partial Content
# < Content-Range: bytes 10-25/26
cat abc.txt; echo
# abcdefghijklmnopqrstuvwxyz
```

`-C -` **solo tiene sentido con `-o`** (o `-O`): es el archivo de salida lo que
curl mide. Sin archivo, no hay nada que medir.

### 3.2 Las tres respuestas a una reanudación

| Respuesta | Qué significa | Qué hace curl 7.81 |
|---|---|---|
| `206` | El servidor manda lo que falta | Lo añade al final del archivo. Sale con 0 |
| `200` | El servidor **ignoró** el `Range` y manda el archivo entero | Se niega: `(33) HTTP server doesn't seem to support byte ranges. Cannot resume.` El archivo queda intacto |
| `416` | El rango no existe: ya tienes el archivo entero (o más) | Sin `--fail`, sale con 0. **Con `--fail`, sale con 22** |

La fila del `200` es la que más importa conocer. Si curl añadiera el archivo
entero detrás de los bytes que ya tenías, el resultado tendría el tamaño
equivocado y contenido duplicado. curl 7.81 lo detecta y para con el 33.

La fila del `416` es la que muerde a los scripts. Una reanudación sobre una
descarga ya completa no es un error, pero con `--fail` lo parece:

```bash
curl -s -o completo.bin http://localhost:8080/range/1000
curl -sS --fail -C - -o completo.bin http://localhost:8080/range/1000
# curl: (22) The requested URL returned error: 416
```

Un script que reanuda tiene que tratar el `416` como "ya estaba", no como "ha
fallado"... **después de comprobarlo**. El `416` también sale si el archivo
local es más grande que el remoto, porque el remoto cambió y encogió. La forma
de distinguirlo es comparar tamaños: si `wc -c` del local coincide con el
`Content-Length` de un `curl -sI`, estaba completo; si no, se borra y se
empieza de cero. Lo verás en el `download --resume` del proyecto.

### 3.3 El patrón `.part`

`-C -` resuelve cómo continuar. No resuelve qué ve quien mira el archivo
mientras tanto: un `informe.pdf` a medias con el nombre bueno. La solución es
la misma que usan los navegadores y los gestores de paquetes:

```bash
# 1. Descargar SIEMPRE a un nombre temporal.
curl -fsS -C - -o informe.pdf.part http://localhost:8080/range/1000

# 2. Renombrar SOLO si curl salio con 0.
mv informe.pdf.part informe.pdf
```

En un script, encadenados con `&&`:

```bash
curl -fsS -C - -o informe.pdf.part http://localhost:8080/range/1000 \
  && mv informe.pdf.part informe.pdf
```

Tres propiedades salen gratis:

- **Quien busca `informe.pdf` nunca ve una descarga a medias.** O existe entero,
  o no existe.
- **El `.part` es el estado de la reanudación.** Si existe, hay algo que
  continuar; el siguiente `-C -` lo encuentra.
- **`mv` dentro del mismo sistema de archivos es atómico.** No hay un instante
  en el que `informe.pdf` exista a medio escribir. Por eso el `.part` va en el
  mismo directorio que el destino, y no en `/tmp`, que suele ser otro sistema
  de archivos y convierte el `mv` en una copia.

### 3.4 Con reintentos

`-C -` y `--retry` se combinan: si la conexión se corta, curl espera y vuelve a
intentar.

```bash
curl -fsS --retry 3 --retry-delay 2 --max-time 600 -C - \
  -o informe.pdf.part http://localhost:8080/range/1000 \
  && mv informe.pdf.part informe.pdf
```

`--retry` solo reintenta los errores que curl considera transitorios (timeout,
conexión rechazada, 5xx concretos). Los detalles y sus trampas son de la
Semana 05; el backoff ante un 429, de la Semana 07.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `-o informe.pdf` directo al destino | Durante la descarga, y tras un corte, `informe.pdf` existe a medias | `-o informe.pdf.part` y `mv` al terminar |
| Tratar el `416` de una reanudación como fallo, o darlo por bueno sin mirar | Lo primero: un script que se reanuda tras terminar falla para siempre. Lo segundo: un `.part` más grande que el remoto se queda con el nombre bueno | `416` con `-C -`: comparar el tamaño local con el `Content-Length` remoto |
| Reanudar días después sin comprobar nada | Si el archivo cambió en el servidor, el resultado mezcla dos versiones con el tamaño correcto | Comparar el `ETag` antes, o verificar el hash al final ([archivo 03](03-verificar-lo-descargado.md)) |
| `.part` en `/tmp` y `mv` al destino | Entre sistemas de archivos, `mv` es copiar y borrar: deja de ser atómico | El `.part` junto al destino |
| `-C -` sin `-o` | No hay archivo que medir | `-C -` siempre con `-o` |
| `-C -` para "actualizar" un archivo que cambia | Si el remoto creció, añades; si cambió, corrompes | Descarga completa y comparación, o `--etag-compare` (Semana 09) |

---

## 5. Trucos

```bash
# El tamaño total de un recurso, preguntando por un solo byte. Util cuando
# HEAD no esta permitido: el total va despues de la barra.
curl -s -D - -o /dev/null -r 0-0 http://localhost:8080/range/1000 \
  | grep -i '^content-range'
# Content-Range: bytes 0-0/1000
```

```bash
# El ETag de un recurso: si cambia entre dos intentos, el archivo cambio y
# reanudar mezclaria versiones.
curl -sI http://localhost:8080/range/1000 | grep -i '^etag'
# Etag: range1000
```

```bash
# Cuanto queda por bajar de un .part, antes de reanudar.
total=1000
tengo=$(wc -c < informe.pdf.part)
echo "faltan $(( total - tengo )) bytes"
```

---

## 📚 Recursos Adicionales

- [RFC 9110 §14 — Range Requests](https://datatracker.ietf.org/doc/html/rfc9110#section-14) — `Range`, `Content-Range`, `206`, `416` y `If-Range`
- [manpage de curl — `-C`](https://curl.se/docs/manpage.html#-C) — el guion y el desplazamiento explícito
- [manpage de curl — `-r`](https://curl.se/docs/manpage.html#-r) — las formas del rango y la advertencia sobre servidores que lo ignoran
- [MDN — HTTP range requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/Range_requests) — la conversación completa con ejemplos

---

## ✅ Checklist de Verificación

- [ ] He pedido `-r 0-9` y `-r -5` a `/range/26` y he predicho la salida antes de verla
- [ ] Sé saber si un servidor acepta rangos sin descargar nada
- [ ] He cortado una descarga y la he reanudado con `-C -`, viendo el `Range` en `-v`
- [ ] Sé qué hace curl 7.81 cuando el servidor contesta 200 a una reanudación
- [ ] Sé por qué una reanudación con `--fail` sobre un archivo completo sale con 22
- [ ] Sé explicar por qué el `.part` va en el mismo directorio que el destino
- [ ] Sé qué riesgo deja el patrón `.part` sin resolver, y qué lo cierra

---

| Anterior | Siguiente |
|---|---|
| [01 — Descargar un archivo](01-descargar-un-archivo.md) | [03 — Verificar lo descargado](03-verificar-lo-descargado.md) |
