# Práctica 02 — Verificar y limitar

> **Duración**: 50 min · **Entregables**: `SHA256SUMS`, `limites.md`

Vas a comprobar lo descargado en sus tres capas — tamaño, tipo y hash —, montar
un `SHA256SUMS` y verlo fallar, y después provocar uno a uno los límites que
cortan una transferencia para saber reconocer cada uno por su código y su
mensaje.

**Antes de empezar**:

```bash
./scripts/start.sh
mkdir -p ~/bc-curl-trabajo/semana-04/p2 && cd ~/bc-curl-trabajo/semana-04/p2
command -v sha256sum || echo 'macOS: usa shasum -a 256 donde ponga sha256sum'
```

---

## Paso 1: El tamaño anunciado frente al recibido

**Por qué**: es la comprobación más barata. Si el servidor anuncia un tamaño y
no llega entero, algo se cortó. curl ya lo vigila cuando hay `Content-Length`,
pero conviene ver las tres cifras con tus ojos una vez.

**Comando**:

```bash
curl -s -D cabeceras.txt -o datos.bin -w 'size_download=%{size_download}\n' \
  http://localhost:8080/range/1000
grep -i '^content-length' cabeceras.txt
wc -c < datos.bin
```

**Verifica**:

```bash
# size_download=1000
# Content-Length: 1000
# 1000
```

Las tres coinciden. Ahora una que no lo anuncia:

```bash
curl -sI http://localhost:8080/stream-bytes/1000 | grep -ci '^content-length'
# 0
```

Sin `Content-Length` no hay con qué comparar: si la conexión se corta, curl no
tiene forma de saber que faltaba algo.

---

## Paso 2: La trampa de `--compressed`

**Por qué**: con compresión, lo que viaja y lo que se escribe tienen tamaños
distintos. Un script que compara `size_download` con `wc -c` da un falso error
en cada descarga comprimida.

**Comando**:

```bash
curl -s --compressed -D cab-gzip.txt -o g.json -w '%{size_download}\n' \
  http://localhost:8080/gzip
grep -iE '^content-(length|encoding)' cab-gzip.txt
wc -c < g.json
```

**Verifica**:

```bash
# 207
# Content-Encoding: gzip
# Content-Length: 207
# 303
```

`size_download` y `Content-Length` hablan de lo comprimido; `wc -c` de lo
descomprimido. Se compara cada uno con su pareja.

---

## Paso 3: El tipo como detector de páginas ajenas

**Por qué**: un proxy cautivo o un balanceador mal configurado te devuelven su
página HTML con un 200. `--fail` no lo atrapa porque no es un error HTTP.
El `Content-Type`, sí.

**Comando**:

```bash
# Una funcion que rechaza HTML cuando esperabas otra cosa.
bajar_no_html() {
  local tipo
  tipo=$(curl -fsS -o "$2" -w '%{content_type}' "$1") || return 1
  case "$tipo" in
    text/html*) echo "rechazado: me han dado HTML ($tipo)" >&2; rm -f "$2"; return 1 ;;
  esac
}

bajar_no_html http://localhost:8080/range/100 bueno.bin; echo "bueno: $?"
bajar_no_html http://localhost:8080/html malo.bin; echo "malo: $?"
```

**Verifica**:

```bash
# bueno: 0
# rechazado: me han dado HTML (text/html; charset=utf-8)
# malo: 1
ls bueno.bin malo.bin 2>&1
# ls: cannot access 'malo.bin': No such file or directory
# bueno.bin
```

---

## Paso 4: Contra un hash publicado

**Por qué**: el tamaño y el tipo no detectan un archivo distinto con la misma
forma. El hash sí: cualquier byte cambiado lo cambia entero.

**Comando**:

```bash
# Este hash esta "publicado": escrito aqui, no descargado del mismo sitio.
ESPERADO=2ac123dcd759eebabfa1b17c0332b88b3815ef3f95fbfcceb5fac07e233235bd
curl -fsS -o cien.bin http://localhost:8080/range/100
echo "$ESPERADO  cien.bin" | sha256sum -c -
```

**Verifica**:

```bash
# cien.bin: OK
echo "$ESPERADO  cien.bin" | sha256sum -c - >/dev/null; echo $?
# 0

# Un byte cambiado:
printf 'X' | dd of=cien.bin bs=1 seek=0 conv=notrunc 2>/dev/null
echo "$ESPERADO  cien.bin" | sha256sum -c -; echo $?
# cien.bin: FAILED
# sha256sum: WARNING: 1 computed checksum did NOT match
# 1
```

Fíjate en los **dos espacios** entre el hash y el nombre. Con uno, `sha256sum`
no reconoce la línea.

---

## Paso 5: Un `SHA256SUMS`

**Por qué**: con varios archivos se publica un solo listado. Es el formato que
vas a encontrar en cualquier página de descargas, y `sha256sum -c` lo lee
directamente.

**Comando**:

```bash
curl -fsS -o a.bin http://localhost:8080/range/100
curl -fsS -o b.bin http://localhost:8080/range/200
curl -fsS -o c.bin "http://localhost:8080/bytes/300?seed=3"
sha256sum a.bin b.bin c.bin > SHA256SUMS
cat SHA256SUMS
sha256sum -c SHA256SUMS
```

**Verifica**:

```bash
# a.bin: OK
# b.bin: OK
# c.bin: OK

echo x >> b.bin
sha256sum -c SHA256SUMS; echo "codigo: $?"
# a.bin: OK
# b.bin: FAILED
# c.bin: OK
# sha256sum: WARNING: 1 computed checksum did NOT match
# codigo: 1

rm c.bin
sha256sum -c --ignore-missing SHA256SUMS 2>&1 | grep -c OK
# 1                           ← solo a.bin; c.bin se ignora y b.bin falla
```

Guarda `SHA256SUMS` y las dos salidas, la verde y la roja.

---

## Paso 6: Verificar antes de renombrar

**Por qué**: si verificas después del `mv`, durante un instante el archivo malo
tiene el nombre bueno. Y si el script muere justo ahí, se queda así.

**Comando**:

```bash
bajar_verificado() {
  local url="$1" destino="$2" hash="$3"
  curl -fsS -C - -o "$destino.part" "$url" || return 1
  # --quiet calla los OK, pero el FAILED sigue saliendo por stdout.
  if ! echo "$hash  $destino.part" | sha256sum -c --quiet - >/dev/null 2>&1; then
    echo "hash incorrecto, borro $destino.part" >&2
    rm -f "$destino.part"
    return 1
  fi
  mv "$destino.part" "$destino"
}

bajar_verificado http://localhost:8080/range/100 ok.bin "$ESPERADO"; echo "ok: $?"
bajar_verificado http://localhost:8080/range/101 mal.bin "$ESPERADO"; echo "mal: $?"
```

**Verifica**:

```bash
# ok: 0
# hash incorrecto, borro mal.bin.part
# mal: 1
ls ok.bin mal.bin mal.bin.part 2>&1 | sort
# ls: cannot access 'mal.bin': No such file or directory
# ls: cannot access 'mal.bin.part': No such file or directory
# ok.bin
```

El `.part` se borra cuando el hash falla: reanudar sobre él solo añadiría bytes
a algo que ya está mal.

---

## Paso 7: Los dos límites de tiempo

**Por qué**: `--connect-timeout` y `--max-time` salen los dos con 28. En un log
solo los distingue el mensaje, y conviene haberlos visto antes de necesitarlo.

**Comando**:

```bash
# 10.255.255.1 no responde: la conexion no llega a establecerse.
curl -sS --connect-timeout 2 -o /dev/null http://10.255.255.1/; echo "codigo: $?"

# /delay/3 tarda 3 segundos en responder.
curl -sS --max-time 1 -o /dev/null http://localhost:8080/delay/3; echo "codigo: $?"
```

**Verifica**:

```bash
# curl: (28) Connection timeout after 2000 ms
# codigo: 28
# curl: (28) Operation timed out after 1001 milliseconds with 0 bytes received
# codigo: 28
```

Si tu red devuelve un error inmediato para `10.255.255.1` (algunas VPN lo
hacen), verás un 7 en vez de un 28: la conexión se rechazó en vez de quedarse
esperando.

---

## Paso 8: Lento pero vivo, frente a muerto

**Por qué**: es el límite que hace falta en las descargas grandes. No las mata
por durar, las mata por pararse.

**Comando**:

```bash
# /drip manda 5 bytes repartidos en 10 segundos: medio byte por segundo.
curl -sS --speed-limit 10 --speed-time 2 -o /dev/null \
  "http://localhost:8080/drip?numbytes=5&duration=10&delay=0"; echo "codigo: $?"

# El mismo goteo, con un minimo que si cumple: termina bien.
curl -sS --speed-limit 1 --speed-time 3 -o /dev/null \
  "http://localhost:8080/drip?numbytes=10&duration=2&delay=0"; echo "codigo: $?"
```

**Verifica**:

```bash
# curl: (28) Operation too slow. Less than 10 bytes/sec transferred the last 2 seconds
# codigo: 28
# codigo: 0
```

---

## Paso 9: Tamaño máximo, y su punto ciego

**Por qué**: `--max-filesize` protege el disco, pero solo cuando el servidor
anuncia el tamaño. En curl 7.81 una respuesta sin `Content-Length` lo esquiva.

**Comando**:

```bash
curl -sS --max-filesize 100 -o /dev/null http://localhost:8080/range/1000; echo "con tamano: $?"
curl -sS --max-filesize 100 -o grande.bin http://localhost:8080/stream-bytes/1000; echo "sin tamano: $?"
wc -c < grande.bin
```

**Verifica**:

```bash
# curl: (63) Maximum file size exceeded
# con tamano: 63
# sin tamano: 0               ← curl 7.81. En 8.x recientes: 63
# 1000
```

Completa `limites.md` con una fila por límite: flag, código, mensaje, y qué
caso no cubre.

---

## Paso 10: Frenar sin cortar

**Por qué**: `--limit-rate` es el único control que no aborta nada. Sirve para
no saturar una red compartida, y para fabricar descargas lentas cuando quieres
probar los demás límites.

**Comando**:

```bash
curl -s --limit-rate 50K -o /dev/null \
  -w 'bytes=%{size_download} velocidad=%{speed_download} tiempo=%{time_total}\n' \
  http://localhost:8080/range/200000
```

**Verifica**:

```bash
# bytes=200000 velocidad=54926 tiempo=3.641218
```

La velocidad ronda 51.200 B/s (50 × 1024) y el tiempo, los 4 segundos. Tus
cifras variarán un poco; si la velocidad es diez veces mayor, `--limit-rate`
no se aplicó.

---

## ✅ Resultado

- [ ] He visto coincidir `size_download`, `Content-Length` y `wc -c`, y he visto por qué no coinciden con `--compressed`
- [ ] Mi función del paso 3 rechaza HTML y borra el archivo
- [ ] `SHA256SUMS` verifica en verde, y en rojo tras estropear un archivo
- [ ] La función del paso 6 borra el `.part` cuando el hash falla
- [ ] `limites.md` tiene los cuatro límites con su código y su mensaje

```bash
./scripts/verificar-semana.sh 04
```

Esta práctica prepara las comprobaciones de `--sha256` del proyecto.

---

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `sha256sum: command not found` | Estás en macOS | `shasum -a 256` en su lugar; acepta `-c` igual |
| `sha256sum -c` dice `no properly formatted checksum lines found` | Un solo espacio entre hash y nombre | Dos espacios: `HASH  nombre` |
| El paso 7 tarda mucho más de 2 s | Tu red no descarta los paquetes a esa IP | Usa otra IP no enrutable, o salta al `--max-time` |
| El paso 8 sale con 0 en el primer comando | El `delay=0` no está en la URL y el goteo empieza tarde | Copia la URL completa, entre comillas |
| El paso 9 sale con 63 en los dos | Tu curl es 8.x | Correcto para tu versión; apunta la diferencia en `limites.md` |
| `dd` del paso 4 no cambia nada | Falta `conv=notrunc` y el archivo se truncó | Descarga de nuevo y repite con el comando exacto |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 01 — Descargar y reanudar](01-descargar-y-reanudar.md) | [Práctica 03 — Formularios y multipart](03-formularios-y-multipart.md) |
