# Práctica 01 — Cada fallo, su código

> **Duración**: 50 min · **Entregables**: `codigos.md`

Vas a provocar un fallo en cada fase de una petición y apuntar el código con
el que sale curl. Después verás qué hacen `--fail` y `--fail-with-body` con el
cuerpo de un error, cómo recoger el código con `set -e` activo, y las dos
trampas de `-e` que más scripts rompen. Terminas con la función que traduce un
código HTTP a un código de salida, la misma que necesita el TODO 3 del
proyecto.

**Antes de empezar**, desde la raíz del repositorio:

```bash
./scripts/start.sh
export CA="$PWD/docs/lab-ca.pem"
mkdir -p ~/bc-curl-trabajo/semana-07/p1 && cd ~/bc-curl-trabajo/semana-07/p1
bash    # los pasos estan escritos para bash; si tu terminal es zsh, abre un bash
```

Los pasos con `set -e` van dentro de `bash -c '...'`: un `set -e` en tu
terminal la cerraría al primer fallo.

---

## Paso 1: Un fallo por fase

**Por qué**: el código de salida es lo único que un script ve de un fallo. Cada
fase falla con el suyo (teoría 01), y hay que haberlos visto para
reconocerlos.

**Comando**:

```bash
codigo() { "$@" > /dev/null 2>&1; echo "$? <- ${*: -1}"; }

codigo curl -sS https://no-existe.invalid/
codigo curl -sS http://127.0.0.1:9/
codigo curl -sS --max-time 1 http://localhost:8080/delay/3
codigo curl -sS https://localhost:8443/get
codigo curl -sS -L --max-redirs 2 http://localhost:8080/redirect/5
codigo curl -sS -o /no/existe/x http://localhost:8080/get
codigo curl -sS http://localhost:8080/status/500
```

**Verifica**:

```bash
# 6 <- https://no-existe.invalid/
# 7 <- http://127.0.0.1:9/
# 28 <- http://localhost:8080/delay/3
# 60 <- https://localhost:8443/get
# 47 <- http://localhost:8080/redirect/5
# 23 <- http://localhost:8080/get
# 0 <- http://localhost:8080/status/500
```

`${*: -1}` es el último argumento (con el espacio delante del `-1`). Copia la
tabla a `codigos.md` con una columna más: **la fase** de cada uno. Y apunta por
qué el último es 0.

---

## Paso 2: `--fail` y `--fail-with-body`

**Por qué**: el 500 del paso 1 salió con 0. `--fail` lo arregla y pierde el
cuerpo; `--fail-with-body` lo arregla sin perderlo (teoría 02).

**Comando**:

```bash
curl -sS --cacert "$CA" https://localhost:8443/limitado; echo " -> $?"
curl -sS --fail --cacert "$CA" https://localhost:8443/limitado; echo " -> $?"
curl -sS --fail-with-body --cacert "$CA" https://localhost:8443/limitado; echo " -> $?"
```

**Verifica**:

```bash
# {"error":"demasiadas peticiones"} -> 0
# curl: (22) The requested URL returned error: 429
#  -> 22
# curl: (22) The requested URL returned error: 429
# {"error":"demasiadas peticiones"} -> 22
```

`/limitado` responde siempre 429 con un cuerpo JSON. La primera línea es el
problema: un error que sale con 0 y con un JSON válido en stdout. Prueba ahora
las dos juntas:

```bash
curl -sS --fail --fail-with-body http://localhost:8080/get; echo " -> $?"
# curl: option --fail-with-body: is badly used here
# curl: try 'curl --help' or 'curl --manual' for more information
#  -> 2
```

En 8.x ya no es un error de uso; en 7.81 sí. Apúntalo.

---

## Paso 3: Leer el código y decidir

**Por qué**: `--fail` reduce cualquier error a 22. El toolkit necesita saber si
fue un 429 o un 404, así que lee `%{http_code}` y decide él.

**Comando**:

```bash
pedir() {
  codigo=$(curl -sS --max-time 10 --cacert "$CA" -o cuerpo.txt \
    -w '%{http_code}' "$1")
  case "$codigo" in
    2??) cat cuerpo.txt ;;
    *)   cat cuerpo.txt >&2; echo >&2; echo "error: la API respondio $codigo" >&2 ;;
  esac
}

pedir https://localhost:8443/limitado
pedir https://localhost:8443/limitado 2>/dev/null | wc -c
```

**Verifica**:

```bash
# {"error":"demasiadas peticiones"}
# error: la API respondio 429
# 0
```

Con `2>/dev/null`, stdout queda **vacío**: el cuerpo del error y el mensaje
fueron a stderr. Es la regla de la teoría 08, apartado 2.2, y es lo que pide el
TODO 3 en `exigir_exito`.

---

## Paso 4: El código de curl con `set -e`

**Por qué**: con `set -e`, `curl ...; rc=$?` no llega nunca a la asignación.

**Comando**:

```bash
bash -c 'set -euo pipefail
  curl -sS http://127.0.0.1:9/ 2>/dev/null
  rc=$?
  echo "rc=$rc"'
echo "el script salio con $?"

bash -c 'set -euo pipefail
  rc=0
  curl -sS http://127.0.0.1:9/ 2>/dev/null || rc=$?
  echo "rc=$rc"'
```

**Verifica**:

```bash
# el script salio con 7
# rc=7
```

El primero aborta en curl: el `echo` no se ejecuta. El segundo sigue, porque
curl forma parte de un `||`. Borra el `rc=0` del segundo y prueba contra
`http://localhost:8080/get`: `rc` no se asigna, y `-u` aborta en el `echo`.
Apunta el mensaje.

---

## Paso 5: El código dentro de una tubería

**Por qué**: en `curl | jq`, `$?` es el de jq.

**Comando**:

```bash
curl -sS http://127.0.0.1:9/ 2>/dev/null | jq .; echo "sin pipefail: $?"
bash -c 'curl -sS http://localhost:8080/get | jq -e .nada > /dev/null; echo "PIPESTATUS: ${PIPESTATUS[*]}"'
bash -c 'set -o pipefail; curl -sS http://127.0.0.1:9/ 2>/dev/null | jq .; echo "con pipefail: $?"'
```

**Verifica**:

```bash
# sin pipefail: 0
# PIPESTATUS: 0 1
# con pipefail: 7
```

El primero es el antipatrón: un servidor caído, y la tubería sale con 0. En
zsh, `PIPESTATUS` se llama `pipestatus`, en minúsculas.

---

## Paso 6: Dónde `-e` no mira

**Por qué**: las dos trampas de la teoría 03 son las que más scripts rompen.

**Comando**:

```bash
bash -c 'set -e
  f() { false; echo "  f sigue tras el false"; }
  if f; then echo "  if: f dio 0"; fi'

bash -c 'set -e
  f() { local x=$(curl -sS http://127.0.0.1:9/ 2>/dev/null); echo "  local: f sigue"; }
  f'

bash -c 'set -e
  f() { local x; x=$(curl -sS http://127.0.0.1:9/ 2>/dev/null); echo "  no llega"; }
  f'; echo "  en dos lineas: sale con $?"
```

**Verifica**:

```bash
#   f sigue tras el false
#   if: f dio 0
#   local: f sigue
#   en dos lineas: sale con 7
```

Pásale `shellcheck` al segundo caso guardado en un archivo: avisa con SC2155.
Copia los tres resultados a `codigos.md`.

---

## Paso 7: El aborto falso de `curl | head`

**Por qué**: `pipefail` tiene un caso en el que aborta sin que haya fallado nada
importante.

**Comando**:

```bash
bash -c 'set -eo pipefail
  curl -sS http://localhost:8080/bytes/200000 | head -c 5 > /dev/null
  echo "no llega"'
echo "salio con $?"

bash -c 'set -eo pipefail
  curl -sS -o grande.bin http://localhost:8080/bytes/200000
  head -c 5 grande.bin > /dev/null
  echo "con archivo, sigue"'
```

**Verifica**:

```bash
# curl: (23) Failure writing output to destination
# salio con 23
# con archivo, sigue
```

`head` cerró la tubería tras cinco bytes y curl no pudo escribir el resto. Con
un cuerpo pequeño no pasa (curl lo escribe entero antes de que `head` cierre),
y por eso el fallo aparece "a veces" en producción.

---

## Paso 8: Del código HTTP al código de salida

**Por qué**: es la otra mitad del TODO 3. Quien llama al toolkit necesita
distinguir "repite más tarde" de "algo está mal" (teoría 08, apartado 2.3).

**Comando**:

```bash
salida_para() {
  case "$1" in
    [23]??)          echo 0 ;;
    401|403)         echo 77 ;;
    429|502|503|504) echo 75 ;;
    *)               echo 1 ;;
  esac
}

for c in 200 302 401 404 422 429 500 503; do
  echo "$c -> $(salida_para "$c")"
done
```

**Verifica**:

```bash
# 200 -> 0
# 302 -> 0
# 401 -> 77
# 404 -> 1
# 422 -> 1
# 429 -> 75
# 500 -> 1
# 503 -> 75
```

El orden de las ramas importa poco aquí porque no se solapan, pero sí en
`salir_por_codigo`: el `[123]??` va **después** de los códigos concretos. Apunta
en `codigos.md` por qué el 500 sale con 1 y no con 75.

---

## ✅ Resultado

- [ ] `codigos.md` tiene un fallo por fase con su código, y por qué un 500 es 0
- [ ] He visto la diferencia entre `--fail` y `--fail-with-body` contra `/limitado`
- [ ] Recojo el código de curl con `|| rc=$?` en un script con `set -e`
- [ ] He reproducido las dos trampas de `-e` y el 23 de `curl | head`
- [ ] Mi `salida_para` da 75 para los fallos temporales y 77 para la credencial

```bash
./scripts/verificar-semana.sh 07
```

Esta práctica prepara el TODO 3: el cuerpo de un error a stderr y el 75 en
`salir_por_codigo`.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| `curl: (60)` en todos los pasos con `$CA` | `CA` no está definida en esta terminal | `export CA="$PWD/docs/lab-ca.pem"` desde la raíz del repositorio |
| `/limitado` responde 200 con un JSON de httpbin | El Caddyfile del laboratorio es anterior a la Semana 07 | Actualiza el repositorio y `docker compose restart tls` |
| El paso 1 da 0 en `/delay/3` | Tu laboratorio responde más rápido de lo esperado | Sube el delay: `/delay/5` |
| `PIPESTATUS: ` vacío | Lo ejecutaste en zsh fuera de `bash -c` | En zsh es `${pipestatus[@]}` |
| El paso 7 no da 23 | El cuerpo cupo entero en el buffer de la tubería | Sube el tamaño: `/bytes/1000000` |
| `--fail --fail-with-body` funciona | Tu curl es 8.x | En 8.x no es un error de uso; apúntalo igual |

---

| Anterior | Siguiente |
|---|---|
| [Teoría 08 — El contrato de un script](../1-teoria/08-el-contrato-de-un-script.md) | [Práctica 02 — Reintentos sin sorpresas](02-reintentos-sin-sorpresas.md) |
