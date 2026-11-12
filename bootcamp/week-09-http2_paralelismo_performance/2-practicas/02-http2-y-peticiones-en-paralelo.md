# Práctica 02 — HTTP/2 y peticiones en paralelo

> **Duración**: 50 min · **Entregables**: `paralelo.md`

Vas a ver cómo negocia curl HTTP/2, por qué en claro casi nunca lo consigue, y
qué pasa cuando lanzas varias peticiones a la vez: cuántas conexiones abre en
HTTP/1.1, cuántas en HTTP/2, y la espera de curl 7.x que convierte un segundo
en dos. Con eso resuelves el TODO 2: que `bench` mande sus N peticiones en
paralelo, y con la estrategia de conexiones correcta para cada esquema.

**Antes de empezar**, desde la raíz del repositorio, con el TODO 1 resuelto
(práctica 01):

```bash
./scripts/start.sh
export TK="$PWD/bootcamp/week-09-http2_paralelismo_performance/3-proyecto/starter/api-toolkit.sh"
export CA="$PWD/docs/lab-ca.pem"
mkdir -p ~/bc-curl-trabajo/semana-09/p2 && cd ~/bc-curl-trabajo/semana-09/p2
bash    # los pasos estan escritos para bash; si tu terminal es zsh, abre un bash
```

Varios pasos lanzan la misma URL N veces. Esta función escribe el `--config`:

```bash
# lista URL N: imprime N pares url/output para curl -K
lista() { for ((i = 0; i < $2; i++)); do printf 'url = "%s"\noutput = "/dev/null"\n' "$1"; done; }
```

---

## Paso 1: ALPN, la negociación que no cuesta nada

**Por qué**: sobre HTTPS, la versión de HTTP se elige dentro del handshake
TLS. curl ofrece `h2` por defecto desde la 7.62.0, y el servidor elige
(teoría 03, apartado 2.3).

**Comando**:

```bash
curl --cacert "$CA" -sv -o /dev/null https://localhost:8443/get 2>&1 \
  | grep -E 'ALPN|HTTP2|MAX_CONCURRENT|^> GET'
curl --cacert "$CA" -sI https://localhost:8443/get | head -3
```

**Verifica**:

```bash
# * ALPN, offering h2
# * ALPN, offering http/1.1
# * ALPN, server accepted to use h2
# * Using HTTP2, server supports multiplexing
# > GET /get HTTP/2
# * Connection state changed (MAX_CONCURRENT_STREAMS == 250)!
# HTTP/2 200
# access-control-allow-credentials: true
# access-control-allow-origin: *
```

Cabeceras en minúscula y sin `OK` en la línea de estado. Apunta en
`paralelo.md` cuántos streams a la vez acepta el servidor.

---

## Paso 2: HTTP/2 en claro

**Por qué**: sin TLS no hay ALPN. `--http2` pide el cambio con `Upgrade: h2c`
y `--http2-prior-knowledge` habla HTTP/2 sin preguntar. El go-httpbin del
laboratorio no habla h2c (teoría 03, apartado 2.4).

**Comando**:

```bash
curl -s -o /dev/null --http2 -w '%{http_version}\n' http://localhost:8080/get
curl -sv -o /dev/null --http2 http://localhost:8080/get 2>&1 | grep -E '^> (Connection|Upgrade)'
curl -s -o /dev/null --http2-prior-knowledge http://localhost:8080/get; echo "exit $?"
```

**Verifica**:

```bash
# 1.1
# > Connection: Upgrade, HTTP2-Settings
# > Upgrade: h2c
# exit 52
```

El `Upgrade` se ignora sin error; el *prior knowledge* rompe la conexión.
Apunta en `paralelo.md` qué conclusión sacas para `bench` sobre `http://`.

---

## Paso 3: `-Z` sobre HTTP/1.1, y la espera

**Por qué**: con `-Z`, curl lanza las transferencias a la vez. Pero antes de
abrir más conexiones, curl 7.x espera a ver si la primera podrá multiplexar,
y sobre `http://` esa espera retrasa todo (teoría 04, apartado 2.4).

**Comando**:

```bash
lista http://localhost:8080/delay/1 3 > tres.txt
time curl -s -Z -K tres.txt -w '%{num_connects} %{time_total}\n'
time curl -s -Z --parallel-immediate -K tres.txt -w '%{num_connects} %{time_total}\n'
```

**Verifica**:

```bash
# 1 1.004270
# 0 2.007285
# 1 2.007410
# real    0m2,01s
# 1 1.003144
# 1 1.003002
# 1 1.003710
# real    0m1,01s
```

Sin el flag, la primera va sola y las otras dos salen cuando termina: una
reutiliza su conexión y otra abre. Con `--parallel-immediate`, tres
conexiones y un segundo. Copia los dos `real` en `paralelo.md`.

---

## Paso 4: `-Z` sobre HTTP/2

**Por qué**: en HTTPS, la espera tiene sentido: si el servidor acepta h2,
todas las peticiones caben en una conexión como streams (teoría 03, apartado
2.1).

**Comando**:

```bash
lista https://localhost:8443/delay/1 3 > tres-tls.txt
time curl --cacert "$CA" -s -Z -K tres-tls.txt -w '%{num_connects} %{http_version}\n'
curl --cacert "$CA" -sv -Z -K tres-tls.txt 2>&1 | grep -o 'Stream ID: [0-9]*'
```

**Verifica**:

```bash
# 1 2
# 0 2
# 0 2
# real    0m1,06s
# Stream ID: 1
# Stream ID: 3
# Stream ID: 5
```

Una conexión, tres streams, un segundo. Ahora repite el primer comando con
`--parallel-immediate` y apunta cuántas conexiones abre: el flag que en
`http://` ayuda, en `https://` estropea la multiplexación.

---

## Paso 5: `--parallel-max`, el freno

**Por qué**: por defecto `-Z` lanza hasta 50 a la vez. Contra una API ajena
eso es una ráfaga que dispara el rate limit. `--parallel-max` pone el techo
(teoría 04, apartado 2.2).

**Comando**:

```bash
lista http://localhost:8080/delay/1 8 > ocho.txt
time curl -s -Z --parallel-max 4 --parallel-immediate -K ocho.txt -w '%{num_connects}\n' | sort | uniq -c
```

**Verifica**:

```bash
#       4 0
#       4 1
# real    0m2,01s
```

Dos tandas de cuatro: las cuatro primeras abren conexión y las cuatro
siguientes las reutilizan. Prueba con `--parallel-max 8` y con `2`, y apunta
los tiempos en `paralelo.md`.

---

## Paso 6: El TODO 2, `bench` en paralelo

**Por qué**: es lo que acabas de hacer a mano. `BENCH_PARALELO` es el techo, y
`--parallel-immediate` va solo en `http://`, por lo que viste en los pasos 3 y
4.

**Comando**: resuelve el TODO 2. `--parallel` y `--parallel-max` van en
`ARGS_CURL`; el `--parallel-immediate`, en `RED_CURL` y solo si la URL empieza
por `http://`:

```bash
case "$url" in
  http://*) RED_CURL+=(--parallel-immediate) ;;
  *) ;;
esac
```

El `case` va **antes** de rellenar `ARGS_CURL`, que copia `RED_CURL`. Después:

```bash
"$TK" --dry-run bench /get 3 | grep -o -- '--parallel[a-z-]*' | sort -u
time "$TK" bench /delay/1 8
```

**Verifica**:

```bash
# --parallel
# --parallel-immediate
# --parallel-max
# 200 1.002272 1 1.1
# 200 1.001941 1 1.1
# 200 1.001841 1 1.1
# 200 1.004796 1 1.1
# 200 1.001180 0 1.1
# 200 1.001131 0 1.1
# 200 1.001124 0 1.1
# 200 1.000605 0 1.1
# real    0m2,04s
```

Dos segundos, no ocho. Prueba con `BENCH_PARALELO=8` y con `BENCH_PARALELO=1`.

---

## Paso 7: `bench` sobre HTTPS

**Por qué**: la misma orden contra el endpoint TLS tiene que multiplexar: una
conexión para todo. Si ves más de un `1`, el `--parallel-immediate` se está
colando en `https://`.

**Comando**:

```bash
BASE_URL=https://localhost:8443 API_CACERT="$CA" "$TK" bench /get 8
BASE_URL=https://localhost:8443 API_CACERT="$CA" "$TK" --dry-run bench /get 8 | grep -c immediate
```

**Verifica**:

```bash
# 200 0.004188 0 2
# 200 0.004180 0 2
# 200 0.004179 0 2
# 200 0.006515 1 2
# 200 0.000765 0 2
# 200 0.000942 0 2
# 200 0.000894 0 2
# 200 0.000881 0 2
# 0
```

Un solo `1`, y no tiene por qué ser la primera línea: con `-Z`, cada una sale
cuando termina. Copia la salida en `paralelo.md`.

---

## Paso 8: El código de salida de un lote

**Por qué**: un lote con `-Z` sale con 0 si todas las transferencias fueron
bien **para curl**, y un 500 no es un fallo para curl sin `--fail`. El
resultado de verdad está en las líneas del `-w` (teoría 04, apartado 2.6).

**Comando**:

```bash
curl -s -Z -f -o /dev/null -o /dev/null -w '%{http_code}\n' \
  http://localhost:8080/status/404 http://localhost:8080/get; echo "exit $?"
curl -s -Z -o /dev/null -o /dev/null -w '%{http_code}\n' \
  http://localhost:8080/status/500 http://localhost:8080/get; echo "exit $?"
"$TK" bench /status/503 3; echo "exit $?"
```

**Verifica**:

```bash
# 404
# 200
# exit 22
# 500
# 200
# exit 0
# 503 0.001149 1 1.1
# 503 0.000945 1 1.1
# 503 0.001233 1 1.1
# exit 0
```

Tres 503 y `bench` sale con 0. Contar los errores por las líneas es trabajo
del TODO 3, en la práctica 03. Apunta en `paralelo.md` por qué `bench` no usa
`--fail`.

---

## ✅ Resultado

- [ ] He visto ALPN elegir h2, y sé por qué en `http://` no hay HTTP/2
- [ ] He medido la espera de curl 7.x y cómo la quita `--parallel-immediate`
- [ ] Sé cuántas conexiones abre `-Z` en HTTP/1.1 y en HTTP/2
- [ ] Mi `construir_args_bench` (TODO 2) lanza en paralelo con el techo de `BENCH_PARALELO`
- [ ] `bench` sobre HTTPS abre una sola conexión

```bash
./scripts/verificar-semana.sh 09
```

Esta práctica cierra el TODO 2. Ya pasan `bench-un-solo-curl` y
`bench-en-paralelo`; los que leen el resumen esperan al TODO 3.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| El paso 1 dice `ALPN, server accepted to use http/1.1` | Tu curl no tiene HTTP/2 compilado | `curl --version \| grep -o HTTP2`; en Ubuntu 22.04 viene, en imágenes mínimas puede faltar |
| El paso 3 tarda 1 s también sin el flag | Tu curl no es la 7.81: otras versiones reparten las conexiones de otra forma | Apunta tu versión (`curl --version \| head -1`) junto a la medida; el `bench` del toolkit funciona igual |
| `curl: option --parallel-immediate: is unknown` | curl anterior a 7.68.0 | Actualiza; el suelo del bootcamp es 7.81 |
| `bench /delay/1 8` tarda 8 s | `--parallel` no está en `ARGS_CURL`, o está detrás del `--config` de la lista | `"$TK" --dry-run bench /get 3` y busca `--parallel` |
| `bench /delay/1 8` tarda 3 s | Falta `--parallel-immediate` con `http://`, o el `case` va después de copiar `RED_CURL` | Mueve el `case` arriba |
| El paso 7 muestra cuatro `1` | `--parallel-immediate` también en `https://` | El `case` solo con el patrón `http://*` |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 01 — Una conexión para muchas peticiones](01-una-conexion-para-muchas-peticiones.md) | [Práctica 03 — Medir sin engañarse](03-medir-sin-enganarse.md) |
