# Práctica 02 — Tests con bats

> **Duración**: 50 min · **Entregables**: `tests.md`

Vas a ejecutar la suite que trae el starter, romperla a propósito para
aprender a leer un fallo, y descubrir que pasa en tu máquina y falla en
otra. Después aíslas cada test de tu entorno (TODO 3), escribes
los tests de la configuración y de `init` (TODO 4), y compruebas que tu
suite es capaz de fallar.

**Antes de empezar**, desde la raíz del repositorio, con la práctica 01
terminada:

```bash
./scripts/start.sh
export RAIZ="$PWD"
export ST="$PWD/bootcamp/week-10-proyecto_final/3-proyecto/starter"
mkdir -p ~/bc-curl-trabajo/semana-10/p2
cd "$ST"
bash
```

Esta práctica se hace **dentro** de la carpeta del starter: los tests viven
en `tests/` y buscan el toolkit en la carpeta de arriba. Las notas, en
`~/bc-curl-trabajo/semana-10/p2/tests.md`.

---

## Paso 1: La suite del starter

**Por qué**: antes de escribir un test, mira cómo se ejecutan y qué dicen
los que ya hay (teoría 04, apartados 2.1 y 2.6).

**Comando**:

```bash
sudo apt install bats       # o: brew install bats-core
bats --version
bats tests/
```

**Verifica**:

```bash
# Bats 1.2.1
# 1..8
# ok 1 --version imprime el nombre y una version semver
# ok 2 --help sale con 0 y documenta init
# ok 3 sin argumentos sale con 1 y dice que faltan
# ok 4 un subcomando desconocido sale con 1
# ok 5 un endpoint sin / se rechaza antes de llamar a curl
# ok 6 --dry-run no imprime la credencial
# ok 7 una API que no responde sale con 69
# ok 8 get contra el laboratorio devuelve el cuerpo
```

Con Ubuntu 24.04 verás `Bats 1.10.0`; los tests son los mismos. Abre
`tests/api-toolkit.bats` y localiza `run`, `$status` y `$output` en el
primero.

---

## Paso 2: Leer un fallo

**Por qué**: un test se escribe una vez y se lee cada vez que falla. Hay que
saber ir de un `not ok` a la línea exacta (teoría 04, apartado 2.6).

**Comando**: sustituye el toolkit por `echo`, que imprime sus argumentos y
sale con 0, y lanza solo el test de la versión:

```bash
TK=/bin/echo bats -f version tests/
```

**Verifica**:

```bash
# 1..1
# not ok 1 --version imprime el nombre y una version semver
# # (in test file tests/api-toolkit.bats, line 43)
# #   `[[ "$output" =~ ^api-toolkit\ [0-9]+\.[0-9]+\.[0-9]+$ ]]' failed
```

`echo --version` sale con 0, así que la primera aserción pasa; la segunda
no, porque imprime `--version`. El número de línea te lleva a ella. `TK`
viene de la primera línea del `.bats`: `TK="${TK:-...}"`.

---

## Paso 3: Pasa aquí, falla allí

**Por qué**: el toolkit lee el entorno y `~/.bc-curl`. Si los tests no se
protegen, dependen de los de quien los ejecuta (teoría 05, apartado 2.1).
Simula una máquina con otra configuración:

**Comando**:

```bash
H="$(mktemp -d)"
echo BASE_URL=http://127.0.0.1:9 > "$H/.bc-curl"
chmod 644 "$H/.bc-curl"
HOME="$H" BASE_URL=http://127.0.0.1:9 AUTH_MODE=bearer bats tests/ | grep -E '^(not )?ok'
```

**Verifica**:

```bash
# ok 1 --version imprime el nombre y una version semver
# ok 2 --help sale con 0 y documenta init
# ok 3 sin argumentos sale con 1 y dice que faltan
# ok 4 un subcomando desconocido sale con 1
# ok 5 un endpoint sin / se rechaza antes de llamar a curl
# ok 6 --dry-run no imprime la credencial
# not ok 7 una API que no responde sale con 69
# not ok 8 get contra el laboratorio devuelve el cuerpo
```

El código no ha cambiado; solo el entorno. El `~/.bc-curl` con 644 no hace
daño: el starter ya trae `export HOME="$DIR"` en `setup`, y cada test mira
un HOME vacío. Pero las variables se cuelan: el 7 hereda `AUTH_MODE=bearer`
sin token y sale con 1, y el 8 hereda `BASE_URL` y no llega al laboratorio.
Apunta en `tests.md` cuáles fallan y por qué.

---

## Paso 4: Sin las variables de quien ejecuta (TODO 3)

**Por qué**: cada test tiene que empezar en un mundo vacío: un HOME sin
archivos, que el starter ya da, y sin ninguna variable del toolkit, que es
lo que falta (teoría 05, apartado 2.1).

**Comando**: en `setup`, debajo de `export HOME="$DIR"`, sustituye el TODO 3:

```bash
  unset BASE_URL AUTH_MODE API_USER API_PASSWORD API_TOKEN API_KEY API_KEY_HEADER \
        BC_CURL_FILE UPLOAD_FIELD API_CACERT API_CLIENT_CERT API_CLIENT_KEY \
        COOKIE_JAR METRICS_FILE OAUTH_CLIENT_ID OAUTH_CLIENT_SECRET OAUTH_SCOPE \
        OAUTH_TOKEN_URL OAUTH_REVOKE_URL OAUTH_SESSION_FILE BENCH_PARALELO \
        API_CACHE_DIR
```

La lista sale de la cabecera del toolkit:
`grep -oE '^#   [A-Z_]+' api-toolkit.sh | tr -d '# ' | sort -u`. Repite el
paso 3:

```bash
HOME="$H" BASE_URL=http://127.0.0.1:9 AUTH_MODE=bearer bats tests/ | grep -c '^ok'
```

**Verifica**:

```bash
# 8
```

Los ocho pasan con el entorno roto. El `export HOME` viene hecho a propósito:
sin él, los tests de `init` del paso 6 escribirían en tu `~/.bc-curl` de
verdad. Y `teardown` borra `$DIR`, no `$HOME`: si `setup` fallara antes del
`export`, `$HOME` sería el tuyo.

---

## Paso 5: Sin laboratorio, saltado

**Por qué**: en la CI no hay laboratorio. Un test que lo necesita tiene que
saltarse, no fallar (teoría 04, apartado 2.5).

**Comando**:

```bash
"$RAIZ/scripts/stop.sh"
bats tests/ | sed -n 9p
"$RAIZ/scripts/start.sh"
```

**Verifica**:

```bash
# ok 8 get contra el laboratorio devuelve el cuerpo # skip el laboratorio no responde en localhost:8080
```

`ok` con `# skip`: bats sale con 0. Mira la función `laboratorio` en el
`.bats`: un `curl` de dos segundos como máximo, y `skip` si falla.

---

## Paso 6: Los tests de la configuración (TODO 4)

**Por qué**: lo que hiciste en la práctica 01 no tiene ningún test. Cada
comprobación que hiciste a mano se convierte en uno (teoría 05, apartado 2.2).

**Comando**: sustituye el comentario del TODO 4 por, como mínimo, cinco de
estos seis. Dos de ellos completos, para que veas la forma:

```bash
@test "init crea ~/.bc-curl con permisos 600" {
  run "$TK" init
  [ "$status" -eq 0 ]
  [ "$(permisos "$HOME/.bc-curl")" = "-rw-------" ]
}

@test "la BASE_URL del archivo se usa" {
  BASE_URL=http://ejemplo.invalid "$TK" init 2> /dev/null
  run "$TK" --dry-run get /x
  [ "$status" -eq 0 ]
  [[ "$output" == *"http://ejemplo.invalid/x"* ]]
}
```

Los otros cuatro: `init` no pisa (prepara un `~/.bc-curl` con 600 y
comprueba el `status` 1 y que el contenido sigue igual); `init` no escribe
los secretos del entorno (con `run grep -c`, no con `! grep`: teoría 04,
apartado 2.3); el entorno manda sobre el archivo; y un archivo con 644 se
rechaza.

```bash
bats --count tests/
bats tests/ | grep -c '^ok'
```

**Verifica**:

```bash
# 14
# 14
```

Con los seis, 14. El check `tests-cuentan` pide al menos 13.

---

## Paso 7: ¿Tus tests pueden fallar?

**Por qué**: una suite que nunca falla no se distingue de una que no
comprueba nada. Sustituye el toolkit por uno que no hace nada (teoría 05,
apartado 2.5).

**Comando**:

```bash
TK=/bin/true bats tests/ | grep -E '^ok'
```

**Verifica**:

```bash
# ok 6 --dry-run no imprime la credencial
```

Un test pasa con un programa que no imprime nada: solo comprueba que la
credencial **no** sale. Añádele una aserción positiva, debajo de la que hay:

```bash
  # Sin esta linea, un toolkit que no imprime nada tambien pasaria.
  [[ "$output" == *"credencial:"* ]]
```

Repite: `TK=/bin/true bats tests/ | grep -c '^ok'` tiene que dar `0`.
Después, una mutación a mano: en `iniciar_configuracion` cambia `umask 077`
por `umask 022`, lanza `bats -f 600 tests/`, mira el `not ok`, y **deshaz el
cambio**. Copia las dos salidas en `tests.md`.

---

## Paso 8: Filtrar, medir y TAP

**Por qué**: con la suite creciendo, se lanza un grupo mientras trabajas, y
se mira cuál tarda (teoría 04, apartado 3).

**Comando**:

```bash
bats --tap -f init tests/
bats -T -f laboratorio tests/ | tail -1
rm -rf "$H"
```

**Verifica**:

```bash
# 1..4
# ok 1 --help sale con 0 y documenta init
# ok 2 init crea ~/.bc-curl con permisos 600
# ok 3 init no pisa un archivo que ya existe
# ok 4 init no escribe los secretos que hay en el entorno
# ok 1 get contra el laboratorio devuelve el cuerpo in 0sec
```

`-f` filtra por el **nombre** del test: el de `--help` entra porque dice
"init". Con nombres descriptivos, el filtro es útil.

---

## ✅ Resultado

- [ ] Leo un `not ok` y voy a la línea que falló
- [ ] He visto la suite fallar con otro HOME y otro entorno, y pasar tras el TODO 3
- [ ] Mis tests de la configuración y de `init` (TODO 4) pasan
- [ ] Con `TK=/bin/true`, ningún test pasa
- [ ] Una mutación en `init` pone rojo el test de los permisos

Desde la raíz del repositorio:

```bash
./scripts/verificar-semana.sh 10
```

Esta práctica cierra los TODOs 3 y 4: pasan `tests-cuentan`, `tests-pasan`,
`tests-aislados` y `tests-detectan-fallos`.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| `bats: command not found` | No está instalado | `sudo apt install bats` o `brew install bats-core` |
| Todos los tests fallan con `No such file or directory` | Lanzas `bats` con una ruta a `tests/` que no es la del starter, o el toolkit no está al lado | `TK` se resuelve desde `$BATS_TEST_DIRNAME/..`: `tests/` y `api-toolkit.sh` tienen que ser hermanos |
| El paso 4 sigue dando fallos | Falta alguna variable en el `unset` | Compara tu lista con la del `grep` de la cabecera |
| Un test de `init` falla con `ya existe` | Has borrado el `export HOME` de `setup`, y el test usa tu `~/.bc-curl` real | Devuélvelo: `export HOME="$DIR"` debajo del `mktemp` |
| Un test con `! grep` pasa aunque el secreto esté | `!` no activa `set -e` salvo en la última línea | `run grep -c ...` y `[ "$output" = 0 ]` |
| El paso 5 no salta el test | El laboratorio sigue arriba, o tu `laboratorio()` no llama a `skip` | `docker compose ps`; el `\|\| skip` tiene que ir detrás del `curl` |
| `bats -T` dice `invalid option` | bats anterior a 1.2 | Actualiza: el suelo es 1.2.1 |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 01 — Configuración e `init`](01-configuracion-e-init.md) | [Práctica 03 — Instalar y documentar](03-instalar-y-documentar.md) |
