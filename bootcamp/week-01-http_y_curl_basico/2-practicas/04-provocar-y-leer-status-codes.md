# Práctica 04 — Provocar y leer códigos de estado

> ⏱️ 50 minutos · Laboratorio local · Entregable: `respuestas.md` + `check-urls.sh`

Un script que no distingue un 200 de un 503 dará por bueno un despliegue que
falló. Aquí provocas los errores a propósito, en un entorno donde no rompen
nada, y haces que el shell reaccione a ellos.

## 🎯 Qué vas a conseguir

- Provocar cualquier código de estado a voluntad
- Explicar por qué curl sale con 0 ante un 500
- Detectar un error HTTP de tres formas distintas, y elegir según tu versión
- Capturar el cuerpo **y** el código en una sola petición
- Distinguir un error de red de un error de aplicación en un script
- Escribir el bucle que es la semilla del proyecto de esta semana

## 📋 Antes de empezar

```bash
./scripts/start.sh
curl -sf --max-time 5 -o /dev/null http://localhost:8080/get && echo "laboratorio OK"
```

---

## Paso 1: Provocar un código concreto

**Por qué**: no puedes probar cómo reacciona tu código ante un 503 esperando a
que un servidor real se caiga. El laboratorio sirve el código que le pidas.

**Comando**:

```bash
# /status/NNN responde exactamente con ese codigo. Acepta cualquiera,
# incluidos los raros.
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/status/418
# 418
```

**Verifica**: el 418 trae cuerpo, y merece la pena verlo.

```bash
curl -s http://localhost:8080/status/418
# I'm a teapot!
```

---

## Paso 2: Recorrer las cinco familias

**Por qué**: hasta que no los ves seguidos, "4xx es culpa tuya y 5xx suya" es
una frase de manual. Viéndolos juntos se convierte en criterio.

**Comando**:

```bash
for c in 200 201 204 301 400 401 403 404 429 500 503; do
  printf '%s -> %s\n' "$c" \
    "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:8080/status/$c")"
done
# 200 -> 200
# 201 -> 201
# 204 -> 204
# 301 -> 301
# 400 -> 400
# 401 -> 401
# 403 -> 403
# 404 -> 404
# 429 -> 429
# 500 -> 500
# 503 -> 503
```

**Verifica**: no todos traen cuerpo. Compara el tamaño.

```bash
for c in 200 204 404; do
  printf '%s: %s bytes\n' "$c" \
    "$(curl -s -o /dev/null -w '%{size_download}' "http://localhost:8080/status/$c")"
done
# 200: 0 bytes
# 204: 0 bytes
# 404: 0 bytes
```

Un 204 **nunca** trae cuerpo, por definición. Anota en `respuestas.md` la
diferencia entre "respondió sin datos" y "no respondió".

---

## Paso 3: El 401 que llega de una API de verdad

**Por qué**: `/status/401` es un 401 de mentira. El endpoint de autenticación
del laboratorio devuelve además el header que dice **cómo** autenticarse, que es
lo que un cliente necesita.

**Comando**:

```bash
curl -s -o /dev/null -D - http://localhost:8080/basic-auth/user/pass \
  | grep -iE '^(HTTP|WWW-Authenticate)'
# HTTP/1.1 401 Unauthorized
# Www-Authenticate: Basic realm="Fake Realm"
```

**Verifica**:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/basic-auth/user/pass
# 401
```

El header `WWW-Authenticate` es la respuesta a "¿y ahora qué mando?". Con
credenciales, este mismo endpoint devuelve 200: es la Semana 03.

---

## Paso 4: La trampa — curl sale con 0

**Por qué**: es el punto central de la semana. Para curl, "el servidor me dijo
que no" es una transferencia **exitosa**: pidió y le contestaron.

**Comando**:

```bash
curl -s -o /dev/null http://localhost:8080/status/500
echo "codigo de salida: $?"
# codigo de salida: 0      ← con un 500 delante
```

**Verifica**: compáralo con un fallo de transporte de verdad.

```bash
curl -s -o /dev/null http://localhost:9/       ; echo "puerto cerrado: $?"  # 7
curl -s -o /dev/null http://no-existe.invalido/ ; echo "sin DNS:        $?"  # 6
curl -s -o /dev/null --max-time 2 \
     http://localhost:8080/delay/5              ; echo "se agoto:       $?"  # 28
```

Cuatro situaciones, cuatro desenlaces. Anótalas en una tabla.

---

## Paso 5: Detectarlo con `--fail-with-body`

**Por qué**: es la forma corta y la que querrás casi siempre. Sale con 22 ante
cualquier 4xx o 5xx **y conserva el cuerpo del error**, que es donde la API
explica qué campo estaba mal.

**Comando**:

```bash
# --fail a secas hace lo mismo pero DESCARTA el cuerpo. Casi nunca es lo que
# quieres: tiras la unica explicacion que te dieron.
curl -sS --fail-with-body --max-time 10 http://localhost:8080/status/503
echo "exit=$?"
# curl: (22) The requested URL returned error: 503
# exit=22
```

**Verifica**: con un 2xx no cambia nada.

```bash
curl -sS --fail-with-body --max-time 10 -o /dev/null http://localhost:8080/get
echo "exit=$?"
# exit=0
```

> [!NOTE]
> `--fail-with-body` es de 7.76. En 7.81 (Ubuntu 22.04) está. Si tu curl es
> anterior, el paso 6 funciona en cualquier versión.

---

## Paso 6: Detectarlo con `%{http_code}`, y hacer que el script falle

**Por qué**: esta es la forma que funciona en todas las versiones **y** la única
que te deja decidir por familia: reintentar los 5xx, abortar los 4xx. Es lo que
va a hacer `api-explorer.sh`, el proyecto de esta semana.

**Comando**:

```bash
# El codigo llega a una variable; bash decide que hacer con el.
codigo=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 \
              http://localhost:8080/status/503)

if [ "$codigo" -ge 500 ]; then
  echo "error del servidor ($codigo): reintentar tiene sentido"
  exit 1
elif [ "$codigo" -ge 400 ]; then
  echo "error del cliente ($codigo): reintentar no arregla nada"
  exit 1
else
  echo "todo bien ($codigo)"
fi
# error del servidor (503): reintentar tiene sentido
```

**Verifica**: guárdalo en un archivo y comprueba el código de salida del script
entero, que es lo que mirará quien lo llame.

```bash
cat > /tmp/comprobar.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
codigo=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "$1")
echo "$1 -> $codigo"
[ "$codigo" -lt 400 ]
EOF
chmod +x /tmp/comprobar.sh

/tmp/comprobar.sh http://localhost:8080/get        ; echo "exit=$?"
# http://localhost:8080/get -> 200
# exit=0

/tmp/comprobar.sh http://localhost:8080/status/503 ; echo "exit=$?"
# http://localhost:8080/status/503 -> 503
# exit=1
```

Ese `[ "$codigo" -lt 400 ]` como última línea es el truco: en bash, el código de
salida de un script es el del último comando. **Esta es la comprobación
`explorer-detecta-error-http` del autograding.**

---

## Paso 7: El cuerpo y el código en una sola petición

**Por qué**: la solución ingenua es llamar dos veces a curl: una para el cuerpo
y otra para el código. Son dos peticiones para lo mismo, y en una API con rate
limit eso duele.

**Comando**:

```bash
# -w '\n%{http_code}' pega el codigo al final del cuerpo, en su propia linea.
respuesta=$(curl -sS --max-time 10 -w '\n%{http_code}' \
                 http://localhost:8080/status/404)

codigo=$(printf '%s' "$respuesta" | tail -1)   # la ultima linea
cuerpo=$(printf '%s' "$respuesta" | sed '$d')  # todo menos la ultima

echo "codigo=$codigo"
echo "cuerpo=[$cuerpo]"
# codigo=404
# cuerpo=[]
```

**Verifica**: con un endpoint que sí devuelve cuerpo.

```bash
respuesta=$(curl -sS --max-time 10 -w '\n%{http_code}' http://localhost:8080/status/418)
printf '%s' "$respuesta" | tail -1
# 418
printf '%s' "$respuesta" | sed '$d'
# I'm a teapot!
```

---

## Paso 8: Reintentar, pero solo lo que tiene sentido reintentar

**Por qué**: reintentar un 404 es perder el tiempo tres veces. Reintentar un 503
es lo correcto. `--retry` de curl ya sabe la diferencia.

**Comando**:

```bash
# --retry N reintenta N veces ante errores transitorios: 5xx y fallos de red.
# --retry-delay fija la espera entre intentos.
curl -sS -o /dev/null --fail --retry 2 --retry-delay 1 --max-time 10 \
  http://localhost:8080/status/503
echo "exit=$?"
# curl: (22) The requested URL returned error: 503
# curl: (22) The requested URL returned error: 503
# curl: (22) The requested URL returned error: 503
# exit=22
```

Tres mensajes: el intento inicial y los dos reintentos.

**Verifica**: un 404 **no** se reintenta, y por eso termina al instante.

```bash
time curl -sS -o /dev/null --fail --retry 2 --retry-delay 1 --max-time 10 \
  http://localhost:8080/status/404
# curl: (22) The requested URL returned error: 404
# real  0m0.01s     ← sin esperas: curl sabe que no vale la pena
```

---

## Paso 9: El bucle que es la semilla del proyecto

**Por qué**: junta todo lo anterior. El proyecto de esta semana es esto mismo,
con un resumen y con tiempos.

**Comando**:

```bash
cat > check-urls.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

URLS=(
  "http://localhost:8080/get"
  "http://localhost:8080/status/404"
  "http://localhost:8080/status/503"
  "http://localhost:8080/json"
)

fallos=0
for url in "${URLS[@]}"; do
  codigo=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "$url" || echo "000")
  printf '%s  %s\n' "$codigo" "$url"
  [ "$codigo" -ge 400 ] && fallos=$((fallos + 1))
done

echo "fallaron $fallos de ${#URLS[@]}"
[ "$fallos" -eq 0 ]
EOF
chmod +x check-urls.sh
./check-urls.sh ; echo "exit=$?"
```

**Verifica**:

```bash
./check-urls.sh
# 200  http://localhost:8080/get
# 404  http://localhost:8080/status/404
# 503  http://localhost:8080/status/503
# 200  http://localhost:8080/json
# fallaron 2 de 4
echo $?
# 1
```

El `|| echo "000"` no es decorativo: sin él, `set -e` mataría el script en
cuanto una URL no resolviera, y perderías las que quedaban por comprobar. El
`000` es lo que devuelve `%{http_code}` cuando no hubo respuesta ninguna.

---

## ✅ Resultado

- [ ] Provocas cualquier código con `/status/NNN`, incluido el 418
- [ ] Explicas por qué `curl -s` sale con 0 ante un 500
- [ ] Distingues exit 0, 6, 7, 22 y 28 y sabes qué provocó cada uno
- [ ] Detectas un error HTTP con `--fail-with-body` y con `%{http_code}`
- [ ] Capturas cuerpo y código en **una** petición
- [ ] Sabes por qué un 404 no se reintenta y un 503 sí
- [ ] `check-urls.sh` existe, es ejecutable y sale con 1 cuando algo falla
- [ ] `respuestas.md` tiene la tabla de los cuatro desenlaces del paso 4

```bash
./scripts/verificar-semana.sh 01
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `%{http_code}` devuelve `000` | No hubo respuesta: DNS, puerto cerrado o timeout | Mira también `$?`: 6, 7 o 28 te dicen cuál de los tres |
| El script sale con 0 aunque una URL diera 503 | La última línea del script fue un `echo`, que siempre va bien | Termina en `[ "$fallos" -eq 0 ]`, o `exit 1` explícito |
| `set -e` mata el bucle en la primera URL caída | curl salió distinto de 0 y `-e` aborta | `|| echo "000"` para capturar el fallo sin abortar |
| `[: 000: integer expression expected` | El código llegó vacío | Asigna un valor por defecto: `"${codigo:-000}"` |
| `--retry` no reintenta un 500 | Falta `--fail`: sin él curl no considera que haya error | `--fail --retry 2`, o `--retry-all-errors` (7.71+) |
| Los reintentos tardan mucho más de lo esperado | `--retry-delay` sin fijar usa espera exponencial | Fija `--retry-delay 1` y acota con `--retry-max-time` |
| `curl: (22)` y no entiendes el 22 | Es el código de salida de `--fail`, no un código HTTP | Teoría 06, sección 6 |

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [Práctica 03 — Los flags esenciales](03-los-flags-esenciales.md) | **Práctica 04 — Provocar y leer códigos de estado** | [Proyecto — api-explorer.sh](../3-proyecto/README.md) |
