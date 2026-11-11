# Práctica 04 — Backoff a mano

> **Duración**: 50 min · **Entregables**: `backoff.sh`

`--retry` cubre los `GET`. Esta práctica es para lo que no cubre: un `POST`
idempotente, un cliente que corre en muchas máquinas a la vez, un
`Retry-After` demasiado largo. Vas a escribir `backoff.sh`, un bucle que
respeta `Retry-After`, dobla la espera con un tope, le suma azar y, cuando no
merece la pena seguir, se rinde con 75. Es la lógica que hay detrás del TODO 3
del proyecto, vista desde el lado de quien reintenta.

**Antes de empezar**, desde la raíz del repositorio:

```bash
./scripts/start.sh
export CA="$PWD/docs/lab-ca.pem"
mkdir -p ~/bc-curl-trabajo/semana-07/p4 && cd ~/bc-curl-trabajo/semana-07/p4
bash    # los pasos estan escritos para bash
```

Dos endpoints: `/limitado` (`:8443`) responde siempre 429 con `Retry-After: 1`,
y `/status/200:0.3,429:0.7` (`:8080`) responde 200 tres de cada diez veces y
429 el resto, **sin** `Retry-After`.

---

## Paso 1: El 429 y su `Retry-After`

**Por qué**: lo primero es leer lo que dice la API.

**Comando**:

```bash
curl -sS --cacert "$CA" -i https://localhost:8443/limitado | tr -d '\r' \
  | grep -iE '^HTTP|^retry-after|^\{'
curl -sS -i 'http://localhost:8080/status/200:0.3,429:0.7' | tr -d '\r' \
  | grep -iE '^HTTP|^retry-after'
```

**Verifica**:

```bash
# HTTP/2 429
# retry-after: 1
# {"error":"demasiadas peticiones"}
# HTTP/1.1 429 Too Many Requests     <- o 200 OK; es aleatorio
```

El segundo no trae `Retry-After`. La espera, ahí, la decides tú.

---

## Paso 2: El antipatrón, insistir sin esperar

**Por qué**: es lo que hace un script sin backoff, y la API lo ve como abuso.

**Comando**:

```bash
n=0
while :; do
  n=$((n + 1))
  c=$(curl -s -o /dev/null -w '%{http_code}' 'http://localhost:8080/status/200:0.1,429:0.9')
  [ "$c" = 200 ] && break
done
echo "peticiones hasta el 200: $n"
```

**Verifica**:

```bash
# peticiones hasta el 200: 11      <- aleatorio; alrededor de 10
```

Diez peticiones rechazadas en unos milisegundos. Contra una API real, cada una
gasta cupo, y muchas APIs alargan el bloqueo a quien insiste. Apunta en un
comentario de `backoff.sh` el número que te salió.

---

## Paso 3: La espera que se dobla, con tope

**Por qué**: sin `Retry-After`, la estrategia estándar es doblar la espera. Sin
tope, en el intento 12 esperarías más de media hora.

**Comando**:

```bash
TOPE=8
for intento in 1 2 3 4 5 6; do
  base=$(( 1 << (intento - 1) ))
  [ "$base" -le "$TOPE" ] || base=$TOPE
  printf '%s ' "$base"
done; echo
```

**Verifica**:

```bash
# 1 2 4 8 8 8
```

`1 << n` es 2 elevado a n, en aritmética de bash. El tope corta la serie en
8 s: a partir de ahí, la espera es fija.

---

## Paso 4: Azar en milisegundos

**Por qué**: mil clientes con la misma fórmula vuelven a la vez (teoría 07,
apartado 2.4). bash solo sabe sumar enteros, así que el azar va en
milisegundos.

**Comando**:

```bash
for i in 1 2 3 4 5; do
  ms=$(( 2 * 1000 + RANDOM % 1000 ))
  printf '%d.%03d ' $((ms / 1000)) $((ms % 1000))
done; echo
```

**Verifica**:

```bash
# 2.891 2.584 2.450 2.228 2.684      <- tuyos, distintos
```

Cinco esperas de "2 segundos", ninguna igual. `%03d` rellena con ceros: sin
él, 2 s y 45 ms saldría `2.45`, que `sleep` lee como 2 s y 450 ms.

---

## Paso 5: `Retry-After` en segundos o en fecha

**Por qué**: RFC 9110 permite las dos formas. Un parser que solo entiende
números trata una fecha como "sin `Retry-After`" y cae al backoff propio.

**Comando**:

```bash
espera_de() {
  case "$1" in
    '')       return 1 ;;
    *[!0-9]*) local s; s=$(( $(date -d "$1" +%s) - $(date +%s) ))
              [ "$s" -gt 0 ] && echo "$s" || echo 0 ;;
    *)        echo "$1" ;;
  esac
}

espera_de 120
espera_de 'Wed, 21 Oct 2026 07:28:00 GMT'
espera_de "$(date -u -d '+30 seconds' '+%a, %d %b %Y %T GMT')"
espera_de '' || echo "sin Retry-After"
```

**Verifica**:

```bash
# 120
# 0
# 30
# sin Retry-After
```

La fecha de octubre ya pasó: espera 0, no una cifra negativa. El tercero
fabrica una fecha dentro de 30 s para comprobar la resta. `date -d` es de GNU;
en macOS, `date -j -f '%a, %d %b %Y %T %Z' "$1" +%s`.

---

## Paso 6: `backoff.sh` entero

**Por qué**: juntar las piezas en el orden de la teoría 07, apartado 2.5:
`Retry-After` primero, rendirse si es demasiado, backoff si no hay.

**Comando**: crea `backoff.sh`:

```bash
#!/usr/bin/env bash
# backoff.sh URL — pide URL y, ante un 429 o un 503, espera y repite
set -euo pipefail

MAX_INTENTOS="${MAX_INTENTOS:-5}"
TOPE="${TOPE:-8}"                      # segundos maximos de una espera
MAX_RETRY_AFTER="${MAX_RETRY_AFTER:-30}"

cuerpo=$(mktemp); cab=$(mktemp)
trap 'rm -f "$cuerpo" "$cab"' EXIT

# espera_de VALOR: segundos que pide un Retry-After, en segundos o en fecha
espera_de() {
  case "$1" in
    '')       return 1 ;;
    *[!0-9]*) local s; s=$(( $(date -d "$1" +%s) - $(date +%s) ))
              [ "$s" -gt 0 ] && echo "$s" || echo 0 ;;
    *)        echo "$1" ;;
  esac
}

intento=0
while :; do
  codigo=$(curl -sS --max-time 10 --cacert "$CA" -o "$cuerpo" -D "$cab" \
    -w '%{http_code}' "$1")
  case "$codigo" in
    429|503) ;;
    *) cat "$cuerpo"; [[ "$codigo" == 2?? ]] && exit 0 || exit 1 ;;
  esac

  intento=$((intento + 1))
  retry_after=$(tr -d '\r' < "$cab" | awk 'tolower($1) == "retry-after:" { $1 = ""; sub(/^ /, ""); print }')

  if [ "$intento" -ge "$MAX_INTENTOS" ]; then
    echo "rendido tras $intento intentos: $codigo${retry_after:+; Retry-After: $retry_after}" >&2
    exit 75
  fi

  if espera=$(espera_de "$retry_after"); then
    [ "$espera" -le "$MAX_RETRY_AFTER" ] || {
      echo "la API pide esperar ${espera}s; me rindo" >&2; exit 75; }
    ms=$((espera * 1000))
  else
    base=$(( 1 << (intento - 1) ))
    [ "$base" -le "$TOPE" ] || base=$TOPE
    ms=$(( base * 1000 + RANDOM % 1000 ))
  fi

  s="$((ms / 1000)).$(printf '%03d' $((ms % 1000)))"
  echo "intento $intento: $codigo, espero ${s}s" >&2
  sleep "$s"
done
```

```bash
chmod +x backoff.sh
shellcheck backoff.sh
```

Tres detalles:

- **El `awk` del `retry-after`** borra el nombre (`$1 = ""`) y se queda con el
  resto: una fecha tiene espacios, y `print $2` se quedaría con `Wed,`.
- **Con `Retry-After` no hay azar.** La API ha dicho cuándo; sumarle algo solo
  retrasa.
- **El cuerpo de un error final va a stdout aquí**, porque `backoff.sh` es una
  práctica. En el toolkit va a stderr (TODO 3).

---

## Paso 7: Probarlo contra los tres casos

**Por qué**: un éxito tras esperas, un rendirse con `Retry-After` y un error que
no se reintenta.

**Comando**:

```bash
./backoff.sh 'http://localhost:8080/status/200:0.3,429:0.7'; echo "salida: $?"
MAX_INTENTOS=3 ./backoff.sh https://localhost:8443/limitado; echo "salida: $?"
./backoff.sh http://localhost:8080/status/404; echo "salida: $?"
```

**Verifica**:

```bash
# intento 1: 429, espero 1.374s           <- aleatorio; puede salir a la primera
# intento 2: 429, espero 2.912s
# salida: 0
# intento 1: 429, espero 1.000s
# intento 2: 429, espero 1.000s
# rendido tras 3 intentos: 429; Retry-After: 1
# salida: 75
# salida: 1
```

En `/limitado`, las esperas son exactas (1.000 s): las marca la API. En el
primero, crecen y llevan decimales de azar. El 404 no se reintenta: repetirlo
daría otro 404. Prueba también `MAX_RETRY_AFTER=0 ./backoff.sh
https://localhost:8443/limitado`: se rinde a la primera, porque la API pide
más de lo que estás dispuesto a esperar.

---

## Paso 8 (opcional): El cupo de GitHub

**Por qué**: la mejor espera es la que no hace falta. Saber cuánto cupo queda
antes de un recorrido largo evita el 429.

**Comando**:

```bash
curl -sS --fail-with-body --max-time 10 https://api.github.com/rate_limit \
  | jq -c '.resources.core'
```

**Verifica**:

```bash
# {"limit":60,"remaining":57,"reset":1794363825,"used":3}
```

Consultar `/rate_limit` no gasta cupo. `reset` es epoch:
`date -d @1794363825` te dice a qué hora se renueva. Con 57 peticiones, un
`fetch-all` de 80 páginas no termina: mejor saberlo antes de empezar.

---

## ✅ Resultado

- [ ] He visto un 429 con `Retry-After` y otro sin él
- [ ] Sé por qué reintentar sin esperar es un antipatrón
- [ ] Mi `espera_de` entiende segundos y fechas, y nunca da un negativo
- [ ] `backoff.sh` respeta `Retry-After`, dobla la espera con tope y suma azar
- [ ] `backoff.sh` se rinde con 75, y no reintenta un 404
- [ ] `shellcheck backoff.sh` no dice nada

```bash
./scripts/verificar-semana.sh 07
```

Esta práctica cierra el TODO 3 desde el otro lado: el toolkit sale con 75 y el
`Retry-After` en el mensaje para que quien lo llame pueda hacer lo que hace
`backoff.sh`.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| `/limitado` responde 200 | El Caddyfile del laboratorio es anterior a la Semana 07 | Actualiza el repositorio y `docker compose restart tls` |
| `sleep: invalid time interval` | El número lleva coma decimal por tu locale, o le falta el `%03d` | Construye el valor con `printf '%d.%03d'` como en el paso 4 |
| `date: invalid date` en el paso 5 | macOS: su `date` no tiene `-d` | `date -j -f '%a, %d %b %Y %T %Z' "$1" +%s` |
| El paso 7 sale con 0 a la primera | `/status/200:0.3,...` acertó al primer intento | Repítelo; o baja la probabilidad: `200:0.1,429:0.9` |
| `backoff.sh` no termina con `/limitado` | `MAX_INTENTOS` vacío o muy alto | `MAX_INTENTOS=3` |
| `integer expression expected` | El `Retry-After` llegó con `\r` | Falta el `tr -d '\r'` antes del `awk` |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 03 — Recorrer un listado paginado](03-recorrer-un-listado-paginado.md) | [Proyecto](../3-proyecto/README.md) |
