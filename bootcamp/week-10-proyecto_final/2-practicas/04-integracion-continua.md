# Práctica 04 — Integración continua

> **Duración**: 50 min · **Entregables**: `ci.md` y tu repositorio `api-toolkit/` con el workflow en verde

Vas a completar el workflow del starter (TODO 6): permisos mínimos y los
cuatro pasos que instalan, informan, revisan y prueban. Antes de empujar
nada, ejecutas en tu máquina lo mismo que ejecutará la CI, compruebas a mano
el SHA de la acción y ves cómo una etiqueta sin fijar hace fallar el check.
Al final lo subes a tu cuenta de GitHub y lees el resultado.

**Antes de empezar**, desde la raíz del repositorio, con las prácticas 01 a
03 terminadas:

```bash
export RAIZ="$PWD"
export ST="$PWD/bootcamp/week-10-proyecto_final/3-proyecto/starter"
export CI="$ST/.github/workflows/ci.yml"
mkdir -p ~/bc-curl-trabajo/semana-10/p4 && cd ~/bc-curl-trabajo/semana-10/p4
bash
```

Para los pasos 7 y 8 necesitas una cuenta de GitHub y, si quieres hacerlo
desde la terminal, `gh` con sesión iniciada (`gh auth status`). Sin ellos,
los pasos 1 a 6 se hacen igual.

---

## Paso 1: Leer el workflow del starter

**Por qué**: antes de completarlo, localiza cada pieza: cuándo se ejecuta,
dónde, con qué imagen y qué falta (teoría 08, apartado 2.1).

**Comando**:

```bash
grep -nE '^[a-z]+:|^  [a-z]+:|^    [a-z-]+:|TODO' "$CI"
```

**Verifica**:

```bash
# 4:name: CI
# 6:on:
# 7:  push:
# 10:# TODO 6: limita los permisos del token del workflow a leer el repositorio
# 16:jobs:
# 17:  test:
# 18:    strategy:
# 24:    runs-on: ubuntu-24.04
# 25:    container: ${{ matrix.imagen }}
# 26:    timeout-minutes: 10
# 27:    steps:
# 34:      # TODO 6 (sigue): cuatro pasos mas. Instalar con apt-get (en el
```

Dos huecos: el bloque `permissions`, a nivel de raíz, y los pasos detrás del
checkout. Los números de línea pueden variar en uno o dos.

---

## Paso 2: Permisos mínimos (TODO 6)

**Por qué**: el token del workflow puede escribir en el repositorio si la
configuración lo permite. Nada de este job necesita escribir (teoría 08,
apartado 2.4).

**Comando**: sustituye el comentario del TODO 6 (el primero) por:

```yaml
# El token que GitHub da al workflow solo puede leer el repositorio. Nada de
# este job necesita escribir, y un paso comprometido no puede hacer mas.
permissions:
  contents: read
```

```bash
grep -n -A1 '^permissions:' "$CI"
```

**Verifica**:

```bash
# 12:permissions:
# 13-  contents: read
```

Va a nivel de raíz, sin sangría: vale para todos los jobs.

---

## Paso 3: Los pasos (TODO 6, sigue)

**Por qué**: la imagen `ubuntu:` viene casi vacía. Hay que instalar lo que
usan los tests, dejar escrito contra qué versiones se probó, y después
revisar y probar (teoría 08, apartado 2.5).

**Comando**: sustituye el segundo comentario del TODO 6 por los cuatro
pasos, con la misma sangría que el `- uses:` del checkout:

```yaml
      - name: Instalar dependencias
        run: |
          apt-get update
          apt-get install -y --no-install-recommends ca-certificates curl jq shellcheck bats

      - name: Versiones
        run: |
          curl --version | head -n 1
          bats --version
          shellcheck --version | sed -n 2p

      - name: shellcheck
        run: shellcheck -S warning api-toolkit.sh install.sh

      - name: Tests
        run: bats tests/
```

```bash
grep -c '^      - ' "$CI"
grep -c 'TODO' "$CI"
```

**Verifica**:

```bash
# 5
# 0
```

Cinco pasos (el checkout y tus cuatro) y ningún TODO. Un error de sangría
no da aviso hasta que GitHub rechaza el archivo: cuenta los espacios.

---

## Paso 4: Lo mismo, en tu máquina

**Por qué**: la CI confirma; no es el sitio para descubrir un error de
sintaxis después de dos minutos de espera. Ejecuta sus comandos antes de
empujar (teoría 08, apartado 3).

**Comando**:

```bash
cd "$ST"
shellcheck -S warning api-toolkit.sh install.sh && echo "shellcheck: limpio"
bats tests/ | tail -2
cd ~/bc-curl-trabajo/semana-10/p4
```

**Verifica**:

```bash
# shellcheck: limpio
# ok 13 el entorno manda sobre el archivo
# ok 14 un archivo de configuracion legible por otros se rechaza
```

Si aquí falla algo, en la CI también fallará. Si aquí pasa y en la CI no, la
diferencia está en la máquina: versión de curl, de bats, o algo que tu HOME
tiene y el contenedor no.

---

## Paso 5: El SHA de la acción

**Por qué**: el starter fija `actions/checkout` por SHA. No te fíes del
comentario: compruébalo contra el repositorio de la acción (teoría 08,
apartado 2.3).

**Comando**:

```bash
grep -o 'checkout@[0-9a-f]*' "$CI"
git ls-remote https://github.com/actions/checkout refs/tags/v6.1.0
```

**Verifica**:

```bash
# checkout@d23441a48e516b6c34aea4fa41551a30e30af803
# d23441a48e516b6c34aea4fa41551a30e30af803	refs/tags/v6.1.0
```

El mismo SHA. Si `git ls-remote` devolviera una segunda línea con `^{}`, la
etiqueta sería anotada y el SHA bueno sería el de esa línea. Cuando salga
una versión nueva, así se actualiza: `ls-remote`, y se cambian el SHA y el
comentario a la vez.

---

## Paso 6: Lo que mira el check

**Por qué**: el check `ci-workflow` lee el archivo sin comentarios y exige
permisos de solo lectura, shellcheck, bats y todas las acciones con un SHA de
40 caracteres. Rómpelo a propósito para ver que se entera.

**Comando**:

```bash
cp "$CI" ci-v6.yml
sed -i 's/@d23441a48e516b6c34aea4fa41551a30e30af803 # v6.1.0/@v6/' ci-v6.yml
grep -n 'uses:' ci-v6.yml
grep -v '^ *#' ci-v6.yml | grep 'uses:' | grep -vE '@[0-9a-f]{40}'
```

**Verifica**:

```bash
# 32:      - uses: actions/checkout@v6
#       - uses: actions/checkout@v6
```

La última orden lista las acciones **sin** SHA: debe quedar vacía en tu
workflow, y aquí no lo está. En macOS, `sed -i ''` en lugar de `sed -i`.
Ahora el de verdad:

```bash
cd "$RAIZ" && ./scripts/verificar-semana.sh 10 | grep -i workflow; cd - > /dev/null
#   ✅ El workflow de CI tiene permisos de solo lectura, acciones fijadas por SHA, shellcheck y bats
```

---

## Paso 7: Subirlo a GitHub

**Por qué**: hasta aquí, el workflow solo se ha leído. Se ejecuta de verdad
cuando llega a un repositorio de GitHub. Usa **tu** cuenta y un repositorio
privado: lo que subes es tuyo.

**Comando**:

```bash
cd ~/bc-curl-trabajo/api-toolkit
cp "$CI" .github/workflows/ci.yml
cp "$ST/api-toolkit.sh" "$ST/install.sh" . && cp "$ST/tests/api-toolkit.bats" tests/
git add -A && git commit -qm "ci: shellcheck y bats con curl 7.81 y 8.5"
gh repo create api-toolkit --private --source . --push
gh run watch --exit-status; echo "salida: $?"
```

**Verifica**:

```bash
# ✓ main CI · 12345678901
# Triggered via push less than a minute ago
# JOBS
# ✓ test (ubuntu:22.04) in 41s (ID ...)
# ✓ test (ubuntu:24.04) in 38s (ID ...)
# salida: 0
```

Los números, los tiempos y la forma exacta de la salida dependen de tu
versión de `gh`; lo que importa son dos `✓`, uno por imagen, y `salida: 0`.
Sin `gh`: crea el repositorio en la web, `git remote add origin ...`,
`git push -u origin main`, y mira la pestaña **Actions**. Si un job falla,
`gh run view --log-failed` enseña solo los pasos rojos.

---

## Paso 8: La marca y la etiqueta

**Por qué**: el `README` enseña el estado de la CI, y la etiqueta `v1.0.0`
tiene que apuntar al commit que pasó la CI, no al de la práctica 03
(teoría 06, apartado 2.6, y teoría 08, apartado 5).

**Comando**: añade al principio del `README.md`, con tu usuario:

```markdown
![CI](https://github.com/<tu-usuario>/api-toolkit/actions/workflows/ci.yml/badge.svg)
```

```bash
git add README.md && git commit -qm "docs: estado de la CI en el README"
git push
gh run watch --exit-status && git tag -f -a v1.0.0 -m "api-toolkit 1.0.0"
git push origin v1.0.0
git describe --tags
```

**Verifica**:

```bash
# v1.0.0
```

La etiqueta se crea solo si el run de ese commit termina en verde: el `&&`
detrás de `gh run watch --exit-status` lo garantiza. Sin `gh`, espera al
`✓` en la pestaña **Actions** antes del `git tag`. `-f` mueve la etiqueta
local, que aún no se había empujado. Una etiqueta
**ya publicada** no se mueve: se saca otra versión. Apunta en `ci.md` la
URL de tu repositorio y la del último run en verde.

---

## ✅ Resultado

- [ ] Mi workflow (TODO 6) tiene `permissions: contents: read` y los cuatro pasos
- [ ] shellcheck y bats pasan en mi máquina con los mismos comandos que la CI
- [ ] He comprobado el SHA de `actions/checkout` con `git ls-remote`
- [ ] He visto el check `ci-workflow` rechazar una acción fijada por etiqueta
- [ ] Mi repositorio tiene la CI en verde con las dos imágenes, la marca y la etiqueta `v1.0.0`

Desde la raíz del repositorio del bootcamp:

```bash
./scripts/verificar-semana.sh 10
```

Esta práctica cierra el TODO 6. Con los seis, las 18 comprobaciones pasan.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| GitHub dice `Invalid workflow file` | Sangría: un paso con más o menos espacios que el checkout | Seis espacios antes de `- name:`, ocho antes de `run:` |
| `apt-get: Permission denied` | Has puesto `sudo`, o has quitado `container:` y estás en el runner | En el contenedor eres root: sin `sudo` |
| `curl: (77) error setting certificate` en un test | Falta `ca-certificates` en la imagen | Añádelo al `apt-get install` |
| El job de 22.04 falla y el de 24.04 pasa | Algo que funciona en curl 8.5 y no en 7.81, o en bats 1.10 y no en 1.2.1 | `--separate-stderr`, `run -1` o `$BATS_TEST_TMPDIR` no existen en 1.2.1 (teoría 04) |
| `tests-aislados` pasa en local y un test falla en la CI | El test depende de algo de tu HOME que el `unset` no cubre | Lánzalo con `env -i HOME="$(mktemp -d)" PATH="$PATH" bats tests/` |
| `gh: command not found` | `gh` no está instalado | Crea el repositorio en la web y usa `git push` |
| `gh run watch` no encuentra runs | El push no llegó, o Actions está desactivado | `git log origin/main -1`; pestaña **Actions** del repositorio |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 03 — Instalar y documentar](03-instalar-y-documentar.md) | [Proyecto — Capa 10](../3-proyecto/README.md) |
