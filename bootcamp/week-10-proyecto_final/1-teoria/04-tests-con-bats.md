# Tests con bats

> Cada semana, `verificar-semana.sh` comprobó tu toolkit desde fuera. Esta
> semana escribes tus propias comprobaciones, y las escribes en el mismo
> idioma que el programa: bash. bats ejecuta cada `@test` en su propio
> proceso, captura lo que imprime y con qué código sale, y te dice cuál falló
> y en qué línea.

![Un archivo .bats con setup, un @test y teardown. Para cada test, bats lanza un proceso nuevo, ejecuta setup, el cuerpo del test y teardown. Dentro, run ejecuta el toolkit y guarda su código en $status y su salida en $output y $lines. Cada línea del test que falla hace fallar el test, como con set -e. A la derecha, la salida en formato TAP: 1..3, ok 1, not ok 2 con la línea que falló, ok 3 # skip](../0-assets/04-tests-con-bats.svg)

## 🎯 Objetivos

- Escribir un test de bats con `run`, `$status`, `$output` y `$lines`
- Preparar y limpiar cada test con `setup` y `teardown`
- Saltar un test con `skip` cuando falta algo que no depende de ti
- Leer la salida de bats y localizar la línea que falló
- Saber qué funciones de bats existen en la 1.2.1 de Ubuntu 22.04

---

## 1. Qué problema resuelve

Sin tests, cada cambio en el toolkit se comprueba a mano, y a mano se
comprueba lo que uno se acuerda de comprobar. El TODO 6 de la Semana 09
tocaba `renovar`: ¿probaste después que `auth status` seguía funcionando?

Un test es una comprobación que se escribe una vez y se ejecuta siempre. Para
un programa en bash, la herramienta estándar es **bats** (Bash Automated
Testing System): un archivo `.bats` es bash con una palabra más, `@test`.

---

## 2. Cómo funciona

### 2.1 Instalar y comprobar la versión

```bash
sudo apt install bats       # Ubuntu 22.04: bats 1.2.1; 24.04: 1.10.0
brew install bats-core      # macOS
bats --version
# Bats 1.2.1
```

Ubuntu 22.04 trae la **1.2.1**, de 2020, y es el suelo del bootcamp, igual
que curl 7.81. Los tests de esta semana solo usan lo que ya tenía:

| Función | Desde | ¿La usamos? |
|---|---|:--:|
| `@test`, `run`, `$status`, `$output`, `$lines`, `skip` | Siempre | Sí |
| `setup`, `teardown`, `$BATS_TEST_DIRNAME` | Siempre | Sí |
| `setup_file`, `teardown_file` | 1.2.0 | No hace falta |
| `$BATS_TEST_TMPDIR` (un directorio por test) | 1.4.0 | No: `mktemp -d` en `setup` |
| `run --separate-stderr`, `run -1` | 1.5.0 | No |
| `bats_require_minimum_version` | 1.7.0 | No |

### 2.2 Anatomía de un test

```bash
@test "--version imprime el nombre y una version semver" {
  run "$TK" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^api-toolkit\ [0-9]+\.[0-9]+\.[0-9]+$ ]]
}
```

- **`@test "nombre"`** declara un test. El nombre es lo que leerás cuando
  falle: que diga qué se espera, no qué se ejecuta.
- **`run comando`** ejecuta el comando **sin** que su fallo pare el test, y
  deja tres cosas:
  - `$status`: el código de salida.
  - `$output`: stdout **y stderr juntos** (en 1.2.1 no se pueden separar).
  - `${lines[@]}`: `$output` partido por líneas, sin las vacías.
- **Cada línea es una aserción.** El cuerpo corre con `set -e`: la primera
  que devuelve distinto de 0 hace fallar el test.

### 2.3 El caso de `!`

Bash no aplica `set -e` a un comando negado con `!`. En medio de un test, una
negación que "falla" **no** hace fallar nada:

```bash
@test "esto pasa aunque no deberia" {
  ! true          # devuelve 1, pero set -e lo ignora
  true
}
```

Solo cuenta si es la última línea, porque entonces es el código de retorno
del test. La forma segura es `run` y comprobar `$status` u `$output`:

```bash
run grep -c valor-de-prueba "$HOME/.bc-curl"
[ "$output" = 0 ]
```

### 2.4 `setup` y `teardown`

```bash
setup() {
  DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$DIR"
}
```

bats llama a `setup` antes de **cada** test y a `teardown` después, también
si el test falla. Cada test corre en su propio proceso: una variable que
exporta un test no llega al siguiente.

### 2.5 `skip`

Algunos tests necesitan algo que no depende del código: el laboratorio
arriba, una conexión a internet. `skip` los marca como saltados en vez de
fallados:

```bash
laboratorio() {
  curl -s -o /dev/null --max-time 2 http://localhost:8080/get \
    || skip "el laboratorio no responde en localhost:8080"
}

@test "get contra el laboratorio devuelve el cuerpo" {
  laboratorio
  run "$TK" get /get
  ...
}
```

Así, `bats tests/` pasa en la CI, donde no hay laboratorio, y en tu máquina
prueba también la parte de red.

### 2.6 Leer la salida

```text
1..3
ok 1 --version imprime el nombre y una version semver
not ok 2 init no pisa un archivo que ya existe
# (in test file tests/api-toolkit.bats, line 104)
#   `[ "$status" -eq 1 ]' failed
ok 3 get contra el laboratorio devuelve el cuerpo # skip el laboratorio no responde
```

Es formato **TAP** (Test Anything Protocol): `1..N` y una línea `ok` o
`not ok` por test. Debajo de un fallo, el archivo, la línea y la aserción.
bats sale con 0 si todos pasan (o se saltan) y con 1 si alguno falla.

Para ver qué imprimió el toolkit en un test que falla, escríbelo antes de la
aserción: lo que el test imprime solo se muestra si falla.

```bash
run "$TK" init
echo "salida: $output"
[ "$status" -eq 1 ]
```

---

## 3. Cómo se usa

```bash
bats tests/                       # todos
bats --count tests/               # cuántos hay, sin ejecutarlos
# 14
bats -f init tests/               # solo los que tienen "init" en el nombre
bats --tap tests/                 # TAP puro, para otra herramienta
```

Dónde va cada cosa en el proyecto:

```text
api-toolkit/
├── api-toolkit.sh
├── install.sh
└── tests/
    └── api-toolkit.bats    # TK="${BATS_TEST_DIRNAME}/../api-toolkit.sh"
```

`$BATS_TEST_DIRNAME` es la carpeta del `.bats`: los tests encuentran el
toolkit aunque lances `bats` desde otro sitio.

---

## 4. Antipatrones

- **Un test que no comprueba nada.** `run "$TK" --help` sin aserciones pasa
  siempre: `run` nunca falla.
- **Comprobar solo `$status`.** Un toolkit roto que sale con 0 sin hacer nada
  pasa todos los tests de "sale con 0" (teoría 05).
- **`!` en medio del test.** Ver el apartado 2.3.
- **Tests que dependen de otros.** Cada uno corre en su proceso, y bats puede
  filtrarlos con `-f`: si el 3 necesita lo que dejó el 2, falla solo.
- **Llamar al toolkit sin `run`** para comprobar un fallo: el primer código
  distinto de 0 para el test antes de llegar a la aserción.
- **Nombres como "test 1".** Cuando falle, el nombre es lo único que verás.

---

## 5. Trucos

- **Un test cada vez** mientras lo escribes: `bats -f 'no pisa' tests/`.
- **`--timing`** (`-T`) añade cuánto tardó cada test: los lentos suelen ser
  los que esperan a la red.
- **`${lines[0]}`** es la primera línea de la salida; `${#lines[@]}`,
  cuántas hay.
- **`[[ "$output" == *"texto"* ]]`** comprueba que la salida contiene un
  texto, sin depender del resto.
- **`run bash -c 'cmd1 | cmd2'`** para probar una tubería. Escrita a
  secas, `run cmd1 | cmd2`, la tubería se aplica a `run`, no dentro de él.

---

## 📚 Recursos Adicionales

- [bats-core — Writing tests](https://bats-core.readthedocs.io/en/stable/writing-tests.html)
- [bats-core — CHANGELOG](https://github.com/bats-core/bats-core/blob/master/docs/CHANGELOG.md)
- [Test Anything Protocol](https://testanything.org/)

---

## ✅ Checklist de Verificación

- [ ] Escribes un test con `run` y aserciones sobre `$status` y `$output`
- [ ] Sabes que `$output` mezcla stdout y stderr en bats 1.2.1
- [ ] Explicas por qué `!` en medio de un test no lo hace fallar
- [ ] Usas `setup`, `teardown` y `skip`
- [ ] Lees un `not ok` y vas a la línea que falló
