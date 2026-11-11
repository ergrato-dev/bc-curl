# Práctica 04 — Métricas de un endpoint

> **Duración**: 50 min · **Entregables**: `metricas.md`

Vas a convertir cada petición en una línea JSON, lanzar cien contra un
endpoint que falla una de cada diez veces, y sacar de esas cien líneas lo que
un panel de monitorización te enseñaría: tasa de error, mediana, p95 y
máximo. Después buscarás la fase culpable de una lentitud, y registrarás
también las peticiones que ni siquiera llegaron al servidor. Es el
`METRICS_FILE` del proyecto, construido a mano.

**Antes de empezar**, desde la raíz del repositorio:

```bash
./scripts/start.sh
export CA="$PWD/docs/lab-ca.pem"
mkdir -p ~/bc-curl-trabajo/semana-06/p4 && cd ~/bc-curl-trabajo/semana-06/p4
```

---

## Paso 1: Una petición, una línea JSON

**Por qué**: un log que un programa va a leer no se escribe en prosa. Una línea
JSON por evento (JSON Lines) se añade con `>>`, se lee con `jq` y no necesita
parser propio.

**Comando**:

```bash
medir() {
  curl -q -s -o /dev/null --max-time 5 -w '%{json}' "$1" \
    | jq -c '{url: .url_effective, codigo: .http_code, salida: .exitcode,
              dns: .time_namelookup, conexion: .time_connect,
              tls: .time_appconnect, ttfb: .time_starttransfer,
              total: .time_total}' >> metricas.jsonl
}

: > metricas.jsonl
medir http://localhost:8080/get
cat metricas.jsonl
```

**Verifica**:

```bash
cat metricas.jsonl
# {"url":"http://localhost:8080/get","codigo":200,"salida":0,"dns":1.5e-05,"conexion":0.000112,"tls":0,"ttfb":0.000656,"total":0.00071}
jq -e '.codigo == 200' metricas.jsonl
# true
```

`1.5e-05` es `0.000015` en notación científica: `jq` lo escribe así y lo lee
igual. `-c` (compacto) es imprescindible: sin él, cada objeto ocupa diez
líneas y deja de ser una por evento.

---

## Paso 2: La query string fuera

**Por qué**: agregar por endpoint exige la ruta sola. Y la query string es
donde acaba lo que no debería: un `?token=`, un `?api_key=`, un email.

**Comando**:

```bash
: > metricas.jsonl
medir 'http://localhost:8080/get?token=no-deberia-estar-aqui'
jq -r .url metricas.jsonl
```

**Verifica**:

```bash
jq -r .url metricas.jsonl
# http://localhost:8080/get?token=no-deberia-estar-aqui
```

Ahí está, en un archivo que acabará en un panel o en un ticket. Corrige
`medir` para que corte en el primer `?`:

```bash
medir() {
  curl -q -s -o /dev/null --max-time 5 -w '%{json}' "$1" \
    | jq -c '{url: (.url_effective | sub("[?].*$"; "")), codigo: .http_code,
              salida: .exitcode, dns: .time_namelookup,
              conexion: .time_connect, tls: .time_appconnect,
              ttfb: .time_starttransfer, total: .time_total}' >> metricas.jsonl
}
: > metricas.jsonl
medir 'http://localhost:8080/get?token=no-deberia-estar-aqui'
jq -r .url metricas.jsonl
# http://localhost:8080/get
```

`[?]` en vez de `\?` evita discutir cuántas barras hacen falta entre el shell y
`jq`. El proyecto hace lo mismo en bash con `${endpoint%%\?*}`.

---

## Paso 3: Cien peticiones

**Por qué**: con una medida no se concluye nada (teoría 04). Con cien ya hay
una distribución.

**Comando**:

```bash
# /status/200:0.9,500:0.1 responde 200 nueve de cada diez veces y 500 una
: > metricas.jsonl
for i in $(seq 100); do
  medir 'http://localhost:8080/status/200:0.9,500:0.1'
done
```

**Verifica**:

```bash
wc -l < metricas.jsonl
# 100
jq -r .codigo metricas.jsonl | sort | uniq -c
#      87 200
#      13 500       ← alrededor de 10; es aleatorio
```

Si una ejecución del bucle se cortó a medias, el archivo tiene menos de 100
líneas pero todas válidas: es la ventaja de añadir de una en una con `>>`.

---

## Paso 4: Tasa de error

**Por qué**: "falla a veces" no es un dato. "El 13 % de las peticiones dio 5xx
en la última hora" sí.

**Comando**:

```bash
jq -s -c '{
  peticiones: length,
  errores: map(select(.codigo >= 500 or .salida != 0)) | length
} | . + {tasa: (.errores / .peticiones * 100)}' metricas.jsonl
```

**Verifica**:

```bash
# {"peticiones":100,"errores":13,"tasa":13}
```

`-s` (slurp) lee todas las líneas en un solo array. Fíjate en la condición:
un error es un 5xx **o** una salida distinta de 0. Sin la segunda parte, una
petición que no llegó al servidor (paso 7) no contaría como error.

Apunta en `metricas.md` la tasa que te salió y por qué un 4xx no está en la
condición. Pista: ¿de quién es la culpa de un 404?

---

## Paso 5: Mediana, p95 y máximo

**Por qué**: la media miente cuando hay valores extremos: una petición de 5
segundos y 99 de 1 ms dan una media de 51 ms que no describe ninguna. La
mediana dice cómo es la petición típica; el p95, cómo es la mala.

**Comando**:

```bash
jq -s -c 'map(.total) | sort | {
  p50: .[length * 0.50 | floor],
  p95: .[length * 0.95 | floor],
  max: .[-1],
  media: (add / length)
}' metricas.jsonl
```

**Verifica**:

```bash
# {"p50":0.000809,"p95":0.001316,"max":0.001642,"media":0.000862}
```

Los números son tuyos; lo que se cumple siempre es `p50 <= p95 <= max`. El p95
es el valor por debajo del cual está el 95 % de las peticiones: lo que sufre
uno de cada veinte usuarios. Copia los cuatro en `metricas.md`.

---

## Paso 6: La fase culpable

**Por qué**: el p95 dice que algo va lento. Las fases dicen qué.

**Comando**:

```bash
: > lento.jsonl
for i in $(seq 20); do
  curl -q -s -o /dev/null --max-time 5 -w '%{json}' http://localhost:8080/delay/0.3 \
    | jq -c '{dns: .time_namelookup, conexion: .time_connect, tls: .time_appconnect,
              ttfb: .time_starttransfer, total: .time_total}' >> lento.jsonl
done

jq -s -c 'map({
  tcp: (.conexion - .dns),
  servidor: (.ttfb - (if .tls > 0 then .tls else .conexion end)),
  transferencia: (.total - .ttfb)
}) | {
  tcp: (map(.tcp) | add / length),
  servidor: (map(.servidor) | add / length),
  transferencia: (map(.transferencia) | add / length)
}' lento.jsonl
```

**Verifica**:

```bash
# {"tcp":0.00013945,"servidor":0.301373,"transferencia":7.65e-05}
```

Trescientos milisegundos de servidor y casi nada de lo demás: el problema está
en el backend, no en la red. Es la misma regla de la teoría 04, ahora sobre
veinte medidas. Repite contra `https://localhost:8443/delay/0.3` con
`--cacert "$CA"` y añade la fase tls: ¿cuánto pesa frente a la del servidor?
Apúntalo en `metricas.md`.

---

## Paso 7: Las peticiones que no llegaron

**Por qué**: si el servidor está caído, no hay código HTTP que registrar, pero
es el evento que más importa. Una métrica que solo registra respuestas no ve
las caídas.

**Comando**:

```bash
medir http://127.0.0.1:9/
tail -1 metricas.jsonl
```

**Verifica**:

```bash
tail -1 metricas.jsonl
# {"url":"http://127.0.0.1:9/","codigo":0,"salida":7,"dns":2e-05,"conexion":0,"tls":0,"ttfb":0,"total":0.000152}
jq -s 'map(select(.salida != 0)) | length' metricas.jsonl
# 1
```

`codigo: 0` y `salida: 7`. `-w '%{json}'` se escribe también cuando curl
falla, y por eso la línea existe. El proyecto hace lo mismo: `medir` se llama
**antes** de `fallo_de_red`, no después, porque `fallo_de_red` termina el
script.

---

## Paso 8: Por endpoint

**Por qué**: un archivo de métricas real mezcla endpoints. Las cifras globales
esconden al que falla.

**Comando**:

```bash
for i in $(seq 10); do medir http://localhost:8080/get; done
for i in $(seq 5);  do medir http://localhost:8080/status/503; done

jq -s -c 'group_by(.url) | map({
  url: .[0].url,
  n: length,
  errores: map(select(.codigo >= 500 or .salida != 0)) | length
})[]' metricas.jsonl
```

**Verifica**:

```bash
# {"url":"http://127.0.0.1:9/","n":1,"errores":1}
# {"url":"http://localhost:8080/get","n":10,"errores":0}
# {"url":"http://localhost:8080/status/200:0.9,500:0.1","n":100,"errores":13}
# {"url":"http://localhost:8080/status/503","n":5,"errores":5}
```

Un endpoint con el 100 % de errores escondido entre 116 peticiones con un 16 %
global. Es la razón de cortar la query string en el paso 2: sin cortarla, cada
`?token=` distinto sería un endpoint distinto y `group_by` no agruparía nada.

---

## ✅ Resultado

- [ ] `medir` escribe una línea JSON por petición, sin la query string
- [ ] `metricas.md` tiene la tasa de error de cien peticiones, y por qué un 4xx no cuenta
- [ ] `metricas.md` tiene p50, p95, máximo y media, y por qué la media engaña
- [ ] He encontrado la fase culpable de `/delay/0.3` sobre veinte medidas
- [ ] Una petición a un puerto cerrado también deja su línea, con `codigo` 0
- [ ] He agrupado las métricas por endpoint

```bash
./scripts/verificar-semana.sh 06
```

Esta práctica prepara la parte de `METRICS_FILE` de `medir` (TODO 5):
`jq -c`, `>>`, la query string fuera y el `000` convertido en `0`.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| `jq: error: syntax error` en `medir` | Copiaste el filtro partido entre líneas de forma distinta | Copia la función entera; las líneas pueden partirse dentro de las comillas simples |
| `metricas.jsonl` tiene objetos de varias líneas | Falta `-c` en el `jq` de `medir` | `jq -c` |
| El paso 3 da 100 de 200 o 100 de 500 | Tu shell interpretó la `,` o los `:` | La URL entre comillas simples |
| `jq: Cannot index number with "total"` | Mezclaste en el archivo líneas de otra práctica | `: > metricas.jsonl` y repite desde el paso 3 |
| La tasa sale con decimales raros | División en coma flotante | `(... * 100 \| round)` si lo quieres entero |
| El paso 6 no da 0,3 s de servidor | `/delay/0.3` no acepta decimales en tu laboratorio | Usa `/delay/1`; la conclusión es la misma |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 03 — `.curlrc` sin romper scripts](03-curlrc-sin-romper-scripts.md) | [Proyecto](../3-proyecto/README.md) |
