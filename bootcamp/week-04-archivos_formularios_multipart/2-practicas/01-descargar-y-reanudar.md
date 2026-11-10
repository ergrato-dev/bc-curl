# Práctica 01 — Descargar y reanudar

> **Duración**: 50 min · **Entregables**: `descargas.md`, `pagina-de-error.md`, `reanudar.md`

Vas a descargar con los tres mecanismos de nombre, provocar el fallo más común
de un script de descarga — la página de error guardada como si fuera el
archivo —, pedir trozos de un recurso, cortar una descarga a propósito y
reanudarla. Al final montas el patrón `.part` que usa el `download` del
proyecto.

**Antes de empezar**:

```bash
./scripts/start.sh
curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 http://localhost:8080/range/10
# 200
```

Crea una carpeta de trabajo **fuera** del repositorio:

```bash
mkdir -p ~/bc-curl-trabajo/semana-04/p1 && cd ~/bc-curl-trabajo/semana-04/p1
```

---

## Paso 1: Tres formas de poner nombre

**Por qué**: con `-O` el nombre lo decide la URL, y la URL lleva cosas que no
quieres en un nombre de archivo. Predecirlo antes de ejecutar es lo que evita
un `ls` lleno de `export?id=7&fmt=csv`.

**Comando**:

```bash
# Antes de ejecutar cada linea, apunta en descargas.md que nombre esperas.
curl -sS -o elegido.txt "http://localhost:8080/range/10"
curl -sS -O "http://localhost:8080/range/20"
curl -sS -O "http://localhost:8080/range/30?formato=txt"
ls -1
```

**Verifica**:

```bash
ls -1
# 20
# 30?formato=txt
# elegido.txt
wc -c < '30?formato=txt'
# 30
```

Apunta en `descargas.md` los tres nombres y por qué el tercero lleva la query
string.

---

## Paso 2: El nombre que manda el servidor

**Por qué**: muchas descargas no tienen el nombre en la URL. El servidor lo
manda en `Content-Disposition`, y `-J` lo usa. Como no lo eliges tú, tienes que
saber leer qué nombre acabó usando.

**Comando**:

```bash
# /response-headers devuelve como header lo que le pidas en la query string.
URL='http://localhost:8080/response-headers?Content-Disposition=attachment%3B%20filename%3Dinforme.txt'
curl -sS -OJ -w 'guardado como: %{filename_effective}\n' "$URL"
```

**Verifica**:

```bash
ls informe.txt
# informe.txt

# -J nunca sobrescribe: una segunda vez falla y deja el primero intacto.
curl -sS -OJ "$URL"; echo "codigo: $?"
# curl: (23) Failed writing header
# codigo: 23
```

Añade a `descargas.md` el nombre que dio `-OJ` y por qué la segunda ejecución
salió con 23.

---

## Paso 3: La página de error con el nombre bueno

**Por qué**: es el fallo de descarga más frecuente en producción, y no deja
ninguna señal. curl sale con 0 y el archivo existe. Solo que no es el archivo.

**Comando**:

```bash
# Una ruta que no existe en el laboratorio: 404 con un cuerpo de texto.
curl -s -o informe.pdf http://localhost:8080/descargas/informe.pdf
echo "codigo de salida: $?"
ls -l informe.pdf
xxd informe.pdf | head -2
```

**Verifica**:

```bash
echo $?        # justo despues del curl
# 0
xxd informe.pdf | head -1
# 00000000: 3430 3420 7061 6765 206e 6f74 2066 6f75  404 page not fou
```

Un PDF empieza por `%PDF` (`2550 4446`). Este empieza por `404 page not found`.
Copia el `xxd` en `pagina-de-error.md`.

---

## Paso 4: La defensa, y lo que no defiende

**Por qué**: `--fail` hace que curl no escriba el cuerpo del error. Pero no
borra lo que ya estaba: si hay un archivo de una descarga anterior, sigue ahí,
y tu script cree que tiene la versión nueva.

**Comando**:

```bash
rm -f informe.pdf
curl -fsS -o informe.pdf http://localhost:8080/descargas/informe.pdf
echo "codigo: $?"
ls informe.pdf

# Ahora con un archivo previo.
echo 'version de ayer' > informe.pdf
curl -fsS -o informe.pdf http://localhost:8080/descargas/informe.pdf
cat informe.pdf
```

**Verifica**:

```bash
# Primera parte:
# curl: (22) The requested URL returned error: 404
# codigo: 22
# ls: cannot access 'informe.pdf': No such file or directory

# Segunda parte: el archivo viejo sobrevive
cat informe.pdf
# version de ayer
```

La alternativa de 7.81 a `--remove-on-error` (7.83+):

```bash
curl -fsS -o informe.pdf http://localhost:8080/descargas/informe.pdf || rm -f informe.pdf
ls informe.pdf 2>&1
# ls: cannot access 'informe.pdf': No such file or directory
```

Añade a `pagina-de-error.md` el comando que evita el paso 3, y una frase sobre
por qué aquí se usa `--fail` y no `--fail-with-body`.

---

## Paso 5: Preguntar si acepta rangos, y pedir uno

**Por qué**: reanudar depende de que el servidor sepa servir un trozo. Hay que
preguntarlo antes, y saber leer qué contesta.

**Comando**:

```bash
curl -sI http://localhost:8080/range/26 | grep -i '^accept-ranges'
curl -sI http://localhost:8080/bytes/26 | grep -ci '^accept-ranges'

# Tres rangos sobre el abecedario de /range/26.
curl -s -r 0-4 http://localhost:8080/range/26; echo
curl -s -r 20- http://localhost:8080/range/26; echo
curl -s -r -3 http://localhost:8080/range/26; echo
```

**Verifica**:

```bash
# Accept-Ranges: bytes
# 0
# abcde
# uvwxyz
# xyz

curl -s -D - -o /dev/null -r 0-4 http://localhost:8080/range/26 \
  | grep -iE '^(HTTP|content-range|content-length)'
# HTTP/1.1 206 Partial Content
# Content-Length: 5
# Content-Range: bytes 0-4/26
```

---

## Paso 6: Cortar una descarga y reanudarla

**Por qué**: es el caso real. La conexión se corta a mitad, el archivo queda a
medias, y la siguiente ejecución tiene que continuar sin volver a bajar lo que
ya tiene.

**Comando**:

```bash
# --limit-rate la hace lenta y timeout la mata a los 2 segundos: una descarga
# cortada reproducible. El 124 es el codigo de timeout, no de curl.
timeout 2 curl -s --limit-rate 20K -o grande.bin.part http://localhost:8080/range/200000
echo "codigo: $?"
wc -c < grande.bin.part

# Reanudar, mirando lo que se pide y lo que se recibe.
curl -s -C - -o grande.bin.part -v http://localhost:8080/range/200000 2>&1 \
  | grep -iE '^> range|^< (HTTP|content-range)'
```

**Verifica**:

```bash
# codigo: 124
# 57344                       (el tuyo variara: depende de cuando corto)
# > Range: bytes=57344-
# < HTTP/1.1 206 Partial Content
# < Content-Range: bytes 57344-199999/200000

curl -s http://localhost:8080/range/200000 | cmp - grande.bin.part && echo identico
# identico
```

El número del `Range` es exactamente el tamaño del `.part`: eso es lo que hace
el guion de `-C -`. Copia las tres líneas y el `identico` en `reanudar.md`.

---

## Paso 7: Reanudar lo que ya estaba completo

**Por qué**: un script que se reanuda tras haber terminado no puede fallar.
Pero con `--fail`, el `416` que devuelve el servidor parece un error.

**Comando**:

```bash
curl -s -C - -o grande.bin.part -w '%{http_code}\n' http://localhost:8080/range/200000
echo "sin --fail: $?"
curl -sS --fail -C - -o grande.bin.part http://localhost:8080/range/200000
echo "con --fail: $?"
wc -c < grande.bin.part
```

**Verifica**:

```bash
# 416
# sin --fail: 0
# curl: (22) The requested URL returned error: 416
# con --fail: 22
# 200000                      ← el archivo no se ha tocado
```

Apunta en `reanudar.md`: ¿cómo distinguiría un script este 22 del 22 de un
404? (Pista: `-w '%{http_code}'`.)

---

## Paso 8: Un servidor que ignora el rango

**Por qué**: `/bytes` no acepta rangos. Si curl añadiera la respuesta completa
detrás de lo que ya tienes, el archivo saldría duplicado. curl 7.81 lo detecta.

**Comando**:

```bash
curl -s "http://localhost:8080/bytes/100?seed=1" | head -c 50 > aleatorio.bin
curl -sS -C - -o aleatorio.bin -w '%{http_code}\n' "http://localhost:8080/bytes/100?seed=1"
echo "codigo: $?"
wc -c < aleatorio.bin
```

**Verifica**:

```bash
# curl: (33) HTTP server doesn't seem to support byte ranges. Cannot resume.
# 200
# codigo: 33
# 50                          ← intacto, ni duplicado ni truncado
```

---

## Paso 9: El patrón completo

**Por qué**: todo lo anterior junto. Descargar a `.part`, reanudar si existe, y
solo renombrar si curl terminó bien. Es exactamente el `download` que vas a
programar en el proyecto.

**Comando**:

```bash
descargar() {
  curl -fsS --max-time 600 --speed-limit 1024 --speed-time 30 \
       -C - -o "$2.part" "$1" \
    && mv "$2.part" "$2"
}

descargar http://localhost:8080/range/1000 datos.bin; echo "bien: $?"
descargar http://localhost:8080/descargas/no-existe datos2.bin; echo "404: $?"
```

**Verifica**:

```bash
ls datos*
# datos.bin                   ← solo el bueno; ni datos2.bin ni datos2.bin.part
wc -c < datos.bin
# 1000
```

Esta función tiene un hueco: el 416 del paso 7. Si `datos.bin.part` ya estaba
completo, falla en vez de renombrar. El proyecto lo resuelve.

---

## ✅ Resultado

- [ ] `descargas.md` explica los nombres de `-o`, `-O`, `-O` con query string y `-OJ`
- [ ] `pagina-de-error.md` tiene el `xxd` del 404 guardado y el comando que lo evita
- [ ] `reanudar.md` tiene el `Range`, el `Content-Range` y el `identico` del `cmp`
- [ ] He visto el 416 con y sin `--fail`, y el 33 de un servidor sin rangos
- [ ] La función del paso 9 no deja archivos tras un 404

```bash
./scripts/verificar-semana.sh 04
```

Esta práctica prepara las comprobaciones de `download` del proyecto: guardar,
no dejar página de error, usar `.part` y reanudar.

---

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `Connection refused` en todo | El laboratorio no está levantado | `./scripts/start.sh` |
| El paso 6 descarga entero antes de los 2 s | Falta `--limit-rate` o tu red local es más rápida de lo esperado | Baja a `--limit-rate 10K` |
| `timeout: command not found` (macOS) | `timeout` es de GNU coreutils | `brew install coreutils` y usa `gtimeout`, o corta con `Ctrl+C` |
| El `cmp` del paso 6 dice `differ` | Reanudaste sobre un `.part` de otra URL | Borra el `.part` y repite el paso 6 entero |
| `-C -` empieza de cero | Usaste `-O` y el nombre no coincide con el `.part` | Usa siempre `-o` con el mismo nombre |
| El paso 2 no crea `informe.txt` | La URL no está entre comillas y el shell se comió el `;` o el `&` | Pon la URL entre comillas simples |
| `xxd: command not found` | No viene en todas las distribuciones | `od -c informe.pdf \| head -2` |

---

| Anterior | Siguiente |
|---|---|
| [Teoría 08 — Elegir cómo subir](../1-teoria/08-elegir-como-subir.md) | [Práctica 02 — Verificar y limitar](02-verificar-y-limitar.md) |
