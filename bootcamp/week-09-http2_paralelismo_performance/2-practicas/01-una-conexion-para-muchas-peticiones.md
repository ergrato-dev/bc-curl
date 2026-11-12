# Práctica 01 — Una conexión para muchas peticiones

> **Duración**: 50 min · **Entregables**: `conexiones.md`

Vas a medir cuánto cuesta abrir una conexión y cuánto se ahorra al no
abrirla. Primero con curl a mano: las fases de una petición nueva, dos URLs en
un mismo curl, el bucle contra la lista, y las tres cosas que impiden
reutilizar. Después escribes la primera pieza de `bench` en el toolkit
(TODO 1): una lista de N peticiones en un `--config`, lanzada con un solo curl.

**Antes de empezar**, desde la raíz del repositorio, con la capa 8 terminada:

```bash
./scripts/start.sh
export TK="$PWD/bootcamp/week-09-http2_paralelismo_performance/3-proyecto/starter/api-toolkit.sh"
export CA="$PWD/docs/lab-ca.pem"
mkdir -p ~/bc-curl-trabajo/semana-09/p1 && cd ~/bc-curl-trabajo/semana-09/p1
bash    # los pasos estan escritos para bash; si tu terminal es zsh, abre un bash
```

El starter de esta semana es tu toolkit de la Semana 08 con los huecos de la
capa 9. Si tu capa 8 tiene arreglos propios, cópialos encima antes de seguir.

---

## Paso 1: Lo que cuesta una conexión nueva

**Por qué**: antes de ahorrar nada hay que ver dónde se va el tiempo. Las
variables `time_*` son instantes acumulados; cada fase es la resta de dos
(teoría 01, apartado 2.1).

**Comando**:

```bash
curl --cacert "$CA" -s -o /dev/null \
  -w 'tcp=%{time_connect} tls=%{time_appconnect} ttfb=%{time_starttransfer} total=%{time_total}\n' \
  https://localhost:8443/get
```

**Verifica**:

```bash
# tcp=0.000172 tls=0.003271 ttfb=0.004402 total=0.004556
```

Tus números serán otros. Calcula la duración del TLS (`tls - tcp`) y la del
servidor (`ttfb - tls`), y apúntalas en `conexiones.md`. En el laboratorio, el
handshake TLS suele durar más que el servidor en responder.

---

## Paso 2: Dos URLs, un curl

**Por qué**: dentro de un mismo proceso, curl guarda las conexiones abiertas y
reutiliza la que ya tiene al mismo host. `%{num_connects}`, que ya usaste en
la Semana 06, dice si una petición abrió conexión (1) o reutilizó (0) (teoría
02, apartado 2.2).

**Comando**:

```bash
curl --cacert "$CA" -s -o /dev/null -o /dev/null \
  -w '%{num_connects} tls=%{time_appconnect} total=%{time_total}\n' \
  https://localhost:8443/get https://localhost:8443/get
```

**Verifica**:

```bash
# 1 tls=0.003271 total=0.004556
# 0 tls=0.000016 total=0.000938
```

La segunda no abrió conexión y tardó varias veces menos. Cada `-o` se empareja
con su URL: prueba a quitar uno y verás la segunda respuesta en la pantalla.

---

## Paso 3: El bucle contra la lista

**Por qué**: un bucle de bash lanza un proceso curl por vuelta, y cada proceso
muere con su conexión. La misma lista en un solo curl abre una (teoría 02,
apartado 2.3).

**Comando**:

```bash
time (for i in $(seq 20); do
  curl --cacert "$CA" -s -o /dev/null https://localhost:8443/get
done)

for i in $(seq 20); do
  printf 'url = "https://localhost:8443/get"\noutput = "/dev/null"\n'
done > lista.txt
time curl --cacert "$CA" -s -K lista.txt
curl --cacert "$CA" -s -K lista.txt -w '%{num_connects}\n' | sort | uniq -c
```

**Verifica**:

```bash
# real    0m0,250s
# real    0m0,030s
#      19 0
#       1 1
```

Una conexión para veinte peticiones, y unas ocho veces menos de tiempo.
Apunta los dos `real` en `conexiones.md`, y calcula qué pasaría con una API a
90 ms de RTT: veinte handshakes de unos 270 ms (3 viajes) frente a uno.

---

## Paso 4: Lo que impide reutilizar

**Por qué**: hay causas que obligan a abrir conexión aunque el host sea el
mismo, y un flag que parece una de ellas y no lo es (teoría 02, apartados 2.4
y 2.5).

**Comando**:

```bash
u=http://localhost:8080/get
curl -s -o /dev/null -o /dev/null -w '%{num_connects} ' -H 'Connection: close' "$u" "$u"; echo "  Connection: close"
curl --cacert "$CA" -s -o /dev/null -o /dev/null -w '%{num_connects} ' "$u" https://localhost:8443/get; echo "  http y https"
curl -s -o /dev/null -o /dev/null -w '%{num_connects} ' --no-keepalive "$u" "$u"; echo "  --no-keepalive"
```

**Verifica**:

```bash
# 1 1   Connection: close
# 1 1   http y https
# 1 0   --no-keepalive
```

`--no-keepalive` reutiliza: apaga las sondas de TCP, no la conexión
persistente de HTTP. Apunta en `conexiones.md` cuál usarías para medir "el
peor caso" con el mismo comando.

---

## Paso 5: `--next`, cada petición con sus opciones

**Por qué**: un lote real mezcla métodos y cabeceras. `--next`, de la Semana
02, separa
operaciones con opciones distintas sin perder la conexión (teoría 02,
apartado 2.3).

**Comando**:

```bash
curl -s -o /dev/null -w '%{num_connects} GET\n' http://localhost:8080/get \
  --next -s -o /dev/null -w '%{num_connects} POST\n' \
  -X POST -H 'Content-Type: application/json' -d '{"a":1}' http://localhost:8080/post
```

**Verifica**:

```bash
# 1 GET
# 0 POST
```

El POST viajó por la conexión que abrió el GET. Fíjate en que `-s`, `-o` y
`-w` se repiten detrás de `--next`: no pasan de una operación a la siguiente.

---

## Paso 6: El hueco del TODO 1

**Por qué**: `bench` tiene que lanzar N peticiones. Un bucle de N curl mediría
N handshakes; un solo curl con un `--config` de N pares `url`/`output` mide la
API. Y en un `--config`, las URLs no aparecen en `ps`.

**Comando**:

```bash
grep -n 'TODO 1' -A 12 "$TK"
"$TK" bench /get 3; echo "exit $?"
```

**Verifica**:

```bash
# NNN:  # TODO 1: escribe en LISTA, con un bucle de n vueltas, dos lineas por
# ...
# error: construir_args_bench todavia no esta implementada: http://localhost:8080/get 3
# exit 1
```

La validación de N ya está hecha en `main`: prueba `"$TK" bench /get 0` y
`"$TK" bench /get 5000`, y lee el mensaje.

---

## Paso 7: El TODO 1, la lista

**Por qué**: es la misma lista del paso 3, escrita por el script. Cada URL
pasa por `escapar_config`, igual que la credencial en la Semana 03: una URL con
comillas rompería el `--config`.

**Comando**: resuelve el TODO 1. La lista va a `LISTA`, que ya es un
temporal con permisos 600:

```bash
for ((i = 0; i < n; i++)); do
  printf 'url = "%s"\noutput = "/dev/null"\n' "$(escapar_config "$url")"
done > "$LISTA"
```

Después rellena `ARGS_CURL` como dice el TODO. Y comprueba:

```bash
"$TK" --dry-run bench /get 3
bash -n "$TK" && shellcheck -S warning "$TK" && echo "sin avisos"
```

**Verifica**:

```bash
# curl --disable --max-time 10 --silent --show-error --write-out %\{http_code\}\ %\{time_total\}\ %\{num_connects\}\ %\{http_version\}\\n --connect-timeout 5 --user-agent api-toolkit/0.9.0 --config /tmp/api-toolkit.XXXXXX
# sin avisos
```

Una sola invocación de curl, con la lista en un `--config`. Sin `--retry` ni
`--location`: `main` construye la red con `construir_red BENCH` (teoría 05,
apartado 2.5).

---

## Paso 8: Las líneas en bruto

**Por qué**: `estadisticas` todavía es un `cat` (TODO 3, práctica 03). Antes de
resumir hay que ver qué datos llegan: una línea por petición, con el código,
el tiempo, si abrió conexión y la versión de HTTP.

**Comando**:

```bash
"$TK" bench /get 5
BASE_URL=https://localhost:8443 API_CACERT="$CA" "$TK" bench /get 5
```

**Verifica**:

```bash
# 200 0.000753 1 1.1
# 200 0.000307 0 1.1
# 200 0.000946 0 1.1
# 200 0.000311 0 1.1
# 200 0.000295 0 1.1
# 200 0.004912 1 2
# 200 0.000610 0 2
# ...
```

La primera abre, las demás reutilizan, y sobre HTTPS la versión es `2`. Pero
van **en serie**: prueba `"$TK" bench /delay/1 3` y cuenta tres segundos. Eso
lo arregla la práctica 02.

Copia las dos salidas en `conexiones.md`.

---

## ✅ Resultado

- [ ] Sé calcular la duración del TLS y la del servidor a partir del `-w`
- [ ] He medido el bucle de curl contra la lista en un solo curl
- [ ] Sé qué impide reutilizar, y que `--no-keepalive` no es una de ellas
- [ ] He mezclado un GET y un POST con `--next` sobre una conexión
- [ ] Mi `construir_args_bench` (TODO 1) lanza la lista con un solo curl

```bash
./scripts/verificar-semana.sh 09
```

Esta práctica cierra el TODO 1. El check `bench-un-solo-curl` aún falla: le
falta el `--parallel`, que llega en la práctica 02.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| `curl: (60) SSL certificate problem` | Falta `--cacert`, o `CA` no apunta al certificado del laboratorio | `echo "$CA"` y `ls -l "$CA"`; se exporta desde la raíz del repositorio |
| El paso 2 imprime la segunda respuesta en la pantalla | Un solo `-o` para dos URLs | Un `-o` por URL, en el mismo orden |
| El paso 3 da `1` en todas las líneas | El `printf` escribió `url=` sin espacios y con comillas mal | `cat lista.txt`: cada línea `url = "..."` y `output = "/dev/null"` |
| `bench` imprime el JSON de `/get` | Falta la línea `output` en la lista | Dos líneas por vuelta: `url` y `output` |
| `bench` no imprime ninguna línea y sale con 0 | `LISTA` quedó vacía: el bucle no dio vueltas o escribió en otra ruta. Con `-s`, curl no avisa de un `--config` ilegible | `> "$LISTA"` detrás del `done`, no dentro; y `n` es el segundo argumento, `"$2"` |
| `bench` reintenta un 503 | Has llamado a `construir_red` con GET dentro de tu TODO | Usa `"${RED_CURL[@]}"` tal cual: `main` ya la construyó con BENCH |

---

| Anterior | Siguiente |
|---|---|
| [Teoría 08 — Procesos que comparten estado](../1-teoria/08-procesos-que-comparten-estado.md) | [Práctica 02 — HTTP/2 y peticiones en paralelo](02-http2-y-peticiones-en-paralelo.md) |
