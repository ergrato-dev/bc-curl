# Práctica 04 — Cuando la credencial falla

> **Duración**: 50 min · **Entregable**: `clasificar-error.sh`

Vas a escribir el trozo de bash que separa «no me conozco» de «no me dejas» de
«el servidor está roto». Es la pieza que convierte un script que se traga los
errores en uno que se puede poner en un cron.

**Antes de empezar**:

```bash
./scripts/start.sh
cd ~/bc-curl-trabajo/semana-03
curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 http://localhost:8080/get
# 200
```

---

## Paso 1: Ver que curl se traga el error

**Por qué**: es el comportamiento por defecto y sorprende a todo el mundo. Para
curl, recibir un `401` **es** un éxito: pidió algo y le contestaron. Un script
que confía en el código de salida procesa el cuerpo del error como si fueran
datos.

**Comando**:

```bash
# Sin --fail: codigo de salida 0 con un 401. El if de un script se cumpliria.
curl -s -o /dev/null http://localhost:8080/bearer; echo "salida: $?"
# salida: 0
```

**Verifica**:

```bash
# Con --fail-with-body: 22, que es el codigo de curl para "error HTTP". Y
# ademas conserva el cuerpo, que es donde la API explica el motivo.
curl --fail-with-body -s -o /dev/null http://localhost:8080/bearer; echo "salida: $?"
# salida: 22
```

```bash
# La diferencia entre --fail y --fail-with-body, sobre el mismo 401.
echo "--fail:"; curl --fail -s http://localhost:8080/bearer; echo "  [salida $?]"
echo "--fail-with-body:"; curl --fail-with-body -s http://localhost:8080/bearer; echo "  [salida $?]"
# --fail:
#   [salida 22]
# --fail-with-body:
# {
#   "status_code": 401,
#   "error": "Unauthorized"
# }
#   [salida 22]
```

`--fail` a secas tira justo lo que necesitas para decidir. Existe desde siempre;
`--fail-with-body` desde **curl 7.76**.

---

## Paso 2: Separar el código del cuerpo en una sola petición

**Por qué**: necesitas las dos cosas —el código para decidir, el cuerpo para
explicar— y no quieres pagar dos peticiones. `--write-out` pega el código al
final de la respuesta y bash lo separa sin archivos temporales.

**Comando**:

```bash
# El \n%{http_code} del final hace que la ultima linea sea el codigo.
salida=$(curl -sS --max-time 10 -w '\n%{http_code}' http://localhost:8080/bearer)

# ##*$'\n' se queda con lo de despues del ultimo salto: el codigo.
codigo="${salida##*$'\n'}"
# %$'\n'* se queda con lo de antes del ultimo salto: el cuerpo.
cuerpo="${salida%$'\n'*}"

echo "codigo=$codigo"
# codigo=401
```

**Verifica**:

```bash
echo "$cuerpo" | jq -c .
# {"status_code":401,"error":"Unauthorized"}
```

---

## Paso 3: Recorrer las cinco categorías

**Por qué**: antes de escribir la lógica, mira qué devuelve cada caso. El
laboratorio sirve cualquier código bajo `/status/NNN`, así que puedes provocar
los cinco sin romper nada.

**Comando**:

```bash
for c in 200 401 403 429 500; do
  printf '%s -> ' "$c"
  curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 \
    "http://localhost:8080/status/$c"
done
# 200 -> 200
# 401 -> 401
# 403 -> 403
# 429 -> 429
# 500 -> 500
```

**Verifica**:

```bash
# Y el caso sin respuesta: puerto donde no escucha nadie. curl pone 000 en
# %{http_code} y sale con 7. El 000 NO es un codigo HTTP.
curl -s -o /dev/null -w '%{http_code}\n' --max-time 3 http://localhost:9/get
echo "salida: $?"
# 000
# salida: 7
```

---

## Paso 4: Comprobar qué reintenta `--retry`

**Por qué**: la documentación lo dice, pero verlo cambia la confianza. `--retry`
no reintenta un `401` —repetirlo con la misma credencial daría lo mismo— y sí
reintenta un `503`. Contar las peticiones en la traza es la prueba.

**Comando**:

```bash
# 1 peticion + 2 reintentos = 3.
curl -s --retry 2 --retry-delay 1 --fail-with-body -o /dev/null -v \
  http://localhost:8080/status/503 2>&1 | grep -c '^> GET'
# 3
```

**Verifica**:

```bash
# El 401: una sola peticion.
curl -s --retry 2 --retry-delay 1 --fail-with-body -o /dev/null -v \
  http://localhost:8080/bearer 2>&1 | grep -c '^> GET'
# 1
```

```bash
# El 404 tampoco: no es transitorio.
curl -s --retry 2 --retry-delay 1 -o /dev/null -v \
  http://localhost:8080/status/404 2>&1 | grep -c '^> GET'
# 1
```

---

## Paso 5: Escribir el clasificador

**Por qué**: es el entregable, y es la misma lógica que va a llevar tu
`api-toolkit.sh`. La clave está en usar `case` con patrones y no comparaciones
numéricas: así el `000` se trata bien sin ningún caso especial.

**Comando**:

```bash
cat > clasificar-error.sh <<'EOF'
#!/usr/bin/env bash
#
# clasificar-error.sh — traduce el resultado de una peticion a un codigo de
# salida que quien llame al script pueda usar sin leer texto.
#
# Uso: ./clasificar-error.sh URL
#
# Codigos de salida:
#   0   la peticion fue bien (1xx, 2xx o 3xx)
#   1   error HTTP que no es de credencial, o no hubo respuesta (000)
#   77  401 o 403 (EX_NOPERM): reintentar con lo mismo no va a funcionar

set -euo pipefail

url="${1:?uso: $0 URL}"

# --write-out pega '\n<codigo>' al final: la ultima linea es el codigo y el
# resto es el cuerpo. Los dos, con UNA sola peticion.
# --max-time para que un servidor colgado no cuelgue el script.
# --retry solo actua sobre lo transitorio: no reintenta 401 ni 404.
salida=$(curl -sS --max-time 10 --retry 2 --retry-delay 1 \
  -w '\n%{http_code}' "$url" || true)

codigo="${salida##*$'\n'}"
cuerpo="${salida%$'\n'*}"

# El cuerpo va a stdout aunque haya fallado: en un 401 es donde la API suele
# distinguir "token caducado" de "token invalido".
printf '%s\n' "$cuerpo"

# case con patrones, no comparaciones numericas: asi el 000 cae en el *) sin
# necesitar un caso propio.
case "$codigo" in
  401|403)
    echo "credencial rechazada (HTTP $codigo)" >&2
    exit 77
    ;;
  [123]??)
    exit 0
    ;;
  *)
    echo "error HTTP $codigo" >&2
    exit 1
    ;;
esac
EOF
chmod +x clasificar-error.sh
```

**Verifica**:

```bash
# Los cuatro casos que definen el contrato del script.
for ruta in /get /bearer /status/403 /status/500; do
  printf '%-14s ' "$ruta"
  ./clasificar-error.sh "http://localhost:8080$ruta" >/dev/null 2>&1
  echo "salida: $?"
done
# /get           salida: 0
# /bearer        salida: 77
# /status/403    salida: 77
# /status/500    salida: 1
```

---

## Paso 6: Comprobar el caso sin respuesta

**Por qué**: el `000` es el que se cuela. No es un número comparable, y un
`if [ "$codigo" -lt 400 ]` con `000` da error de sintaxis o pasa por bueno según
cómo lo escribas. El `case` con patrones lo resuelve solo.

**Comando**:

```bash
# Puerto cerrado: no hay respuesta, no hay codigo.
./clasificar-error.sh http://localhost:9/get >/dev/null 2>&1
echo "salida: $?"
# salida: 1
```

**Verifica**:

```bash
# El mensaje de error dice 000, que es informacion util para quien lo lea.
./clasificar-error.sh http://localhost:9/get 2>&1 >/dev/null
# curl: (7) Failed to connect to localhost port 9 after 0 ms: Connection refused
# error HTTP 000
```

---

## Paso 7: Usarlo desde otro script

**Por qué**: los códigos de salida existen para esto. Quien te llama decide qué
hacer sin leer ni una línea de tu salida de texto, que es lo que permite
encadenar el script en un pipeline o en un cron.

**Comando**:

```bash
./clasificar-error.sh http://localhost:8080/bearer >/dev/null 2>&1 || case $? in
  77) echo "hay que renovar la credencial" ;;
  1)  echo "fallo del servidor: reintentar mas tarde" ;;
  *)  echo "fallo desconocido" ;;
esac
# hay que renovar la credencial
```

**Verifica**:

```bash
# El mismo bloque contra un 500: otra rama, sin cambiar una linea del case.
./clasificar-error.sh http://localhost:8080/status/500 >/dev/null 2>&1 || case $? in
  77) echo "hay que renovar la credencial" ;;
  1)  echo "fallo del servidor: reintentar mas tarde" ;;
  *)  echo "fallo desconocido" ;;
esac
# fallo del servidor: reintentar mas tarde
```

---

## Paso 8: Dejarlo limpio de `shellcheck`

**Por qué**: `shellcheck` encuentra las comillas que faltan y las expansiones que
se rompen con un espacio. Es la comprobación `toolkit-shellcheck` del
`checks.json`, y aquí la practicas sobre un script pequeño.

**Comando**:

```bash
shellcheck -S warning clasificar-error.sh && echo "limpio"
# limpio
```

**Verifica**:

```bash
# Si no tienes shellcheck instalado, puedes usarlo con docker sin instalarlo.
docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:v0.10.0 \
  -S warning clasificar-error.sh && echo "limpio"
```

---

## ✅ Resultado

- [ ] He comprobado que `curl -s` sale con `0` ante un `401`
- [ ] Sé qué conserva `--fail-with-body` que `--fail` tira, y desde qué versión existe
- [ ] He separado código y cuerpo con `--write-out` en una sola petición
- [ ] He medido que `--retry` reintenta el `503` y no el `401`
- [ ] `clasificar-error.sh` sale con `0`, `77` y `1` en los casos correctos
- [ ] Trata bien el `000` sin un caso especial para él
- [ ] Pasa `shellcheck -S warning` sin avisos

```bash
./scripts/verificar-semana.sh 03
```

Esta práctica es la base de `toolkit-sin-credencial-da-77`,
`toolkit-403-tambien-da-77` y `toolkit-otro-error-no-es-77`.

---

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `--fail-with-body: option unknown` | Tu curl es anterior a 7.76 | Usa `--fail` y acepta perder el cuerpo, o actualiza curl |
| El script sale con `1` cuando esperabas `77` | El `case` compara antes `[123]??` que `401\|403` | El orden importa: `401\|403` va primero |
| `codigo` sale vacío | Falta el `\n` en `-w '\n%{http_code}'` | Sin el salto, el código se pega al cuerpo |
| `integer expression expected` | Estás comparando `$codigo` con `-lt` y llegó `000` | `case` con patrones, no comparaciones numéricas |
| El script se cuelga con `/status/500` | `--retry` está esperando entre intentos | Es correcto: `--retry 2 --retry-delay 1` tarda unos segundos |
| `salida: 0` en `/bearer` | Falta el `case`, o el script no propaga el código | El `exit` tiene que estar dentro del `case`, no después |
| `shellcheck: command not found` | No está instalado | `sudo apt install shellcheck`, o el `docker run` del paso 8 |
| `SC2086` en shellcheck | Una variable sin comillas | Ponle comillas: `"$codigo"`, no `$codigo` |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 03 — Bearer y el JWT por dentro](03-bearer-y-el-jwt-por-dentro.md) | [Proyecto de la semana](../3-proyecto/README.md) |
