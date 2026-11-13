# Integración continua

> Los tests solo sirven si alguien los ejecuta, y "alguien" se olvida. La
> integración continua los ejecuta en cada push, en una máquina limpia que
> no tiene tu `~/.bc-curl` ni tu curl, y pone una marca roja en el commit
> que rompe algo. Esta teoría monta un workflow de GitHub Actions para el
> toolkit: shellcheck y bats, con curl 7.81 y con curl 8.5, y con los
> permisos justos para que un paso comprometido no pueda hacer daño.

![Un push dispara el workflow. GitHub arranca un runner ubuntu-24.04 y, dentro, dos contenedores en paralelo: ubuntu:22.04 con curl 7.81 y bats 1.2.1, y ubuntu:24.04 con curl 8.5 y bats 1.10. En cada uno: checkout fijado por SHA, apt-get install de curl, jq, shellcheck y bats, shellcheck -S warning y bats tests/. El token del workflow solo tiene contents: read. El resultado vuelve al commit como una marca verde o roja](../0-assets/08-integracion-continua.svg)

## 🎯 Objetivos

- Leer y escribir un workflow de GitHub Actions: disparadores, jobs, pasos
- Probar con varias versiones de curl con una matriz de contenedores
- Fijar las acciones de terceros por SHA y no por etiqueta
- Limitar los permisos del token del workflow
- Saber qué no se prueba en la CI y por qué

---

## 1. Qué problema resuelve

Tú pruebas con tu curl (el de Ubuntu 22.04, o uno más nuevo), tu bats y tu
HOME. Quien instale el toolkit tendrá otro. La CI resuelve tres cosas:

1. **Nadie se olvida**: los tests corren en cada push, también en el de las
   prisas.
2. **Una máquina limpia**: lo que funciona allí no depende de tu
   configuración (teoría 05 llevada al extremo).
3. **Más de una versión**: la misma suite con curl 7.81, el suelo del
   bootcamp, y con uno moderno.

---

## 2. Cómo funciona

### 2.1 Anatomía de un workflow

Un archivo YAML en `.github/workflows/` del repositorio:

```yaml
name: CI

on:                       # cuándo se ejecuta
  push:
  pull_request:

permissions:              # qué puede hacer el token del workflow
  contents: read

jobs:
  test:                   # un job: una máquina, unos pasos en orden
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@<sha>    # una acción: código de otro repositorio
      - run: bats tests/                # un comando
```

- **`on`**: `push` en cualquier rama y `pull_request`.
- **`jobs`**: cada job arranca en una máquina nueva (un *runner*). Si un
  paso sale con distinto de 0, el job falla y los pasos siguientes no se
  ejecutan.
- **`timeout-minutes`**: sin él, un test colgado gasta hasta 6 horas de
  runner.

### 2.2 La versión de curl: contenedor, no runner

Los runners `ubuntu-22.04` de GitHub traen curl 7.81, pero GitHub los
retira cuando decide: los de Ubuntu 22 empezaron su retirada el 17 de
septiembre de 2026 y dejan de existir el 17 de abril de 2027. Un
**contenedor** fija la versión mientras exista la imagen:

```yaml
    strategy:
      fail-fast: false
      matrix:
        imagen: ["ubuntu:22.04", "ubuntu:24.04"]
    runs-on: ubuntu-24.04
    container: ${{ matrix.imagen }}
```

- **`matrix`** crea un job por cada valor: dos jobs en paralelo, uno por
  imagen.
- **`fail-fast: false`**: si falla el de 22.04, el de 24.04 termina igual, y
  se ve si el fallo es de una versión o de las dos.
- Etiquetas completas, `ubuntu:22.04`; nunca `ubuntu:latest`, que cambia de
  versión sin que nadie lo decida.

| Imagen | curl | bats (apt) | shellcheck (apt) |
|---|---|---|---|
| `ubuntu:22.04` | 7.81.0 | 1.2.1 | 0.8.0 |
| `ubuntu:24.04` | 8.5.0 | 1.10.0 | 0.9.0 |

### 2.3 Fijar las acciones por SHA

`actions/checkout@v6` apunta a una **etiqueta**, y el dueño del repositorio
puede moverla a otro commit cuando quiera; si alguien le roba la cuenta,
también. Ese código se ejecuta con acceso a tu repositorio. Un **SHA** de
commit no se puede mover:

```yaml
      - uses: actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803 # v6.1.0
```

El comentario dice qué versión es para las personas. El SHA se consulta sin
clonar:

```bash
git ls-remote https://github.com/actions/checkout refs/tags/v6.1.0
# d23441a48e516b6c34aea4fa41551a30e30af803	refs/tags/v6.1.0
```

Si la línea trae una segunda entrada terminada en `^{}`, la etiqueta es
anotada, y el SHA del commit es el de esa segunda línea.

### 2.4 Permisos mínimos

Cada workflow recibe un token (`GITHUB_TOKEN`) para hablar con la API de
GitHub. Según la configuración del repositorio, puede escribir en él. El
bloque `permissions` lo limita:

```yaml
permissions:
  contents: read
```

Con eso, aunque una acción o una dependencia de `apt` estuvieran
comprometidas, el token no puede empujar commits ni crear versiones. Y
`persist-credentials: false` en el checkout evita que el token se quede
guardado en `.git/config` para los pasos siguientes.

### 2.5 Los pasos

```yaml
      - name: Instalar dependencias
        run: |
          apt-get update
          apt-get install -y --no-install-recommends ca-certificates curl jq shellcheck bats
      - name: shellcheck
        run: shellcheck -S warning api-toolkit.sh install.sh
      - name: Tests
        run: bats tests/
```

- Dentro del contenedor eres root: `apt-get` sin `sudo`.
- Las imágenes `ubuntu:` vienen casi vacías: ni curl, ni certificados. Por
  eso `ca-certificates` va en la lista.
- Un paso de "Versiones" con `curl --version | head -n 1` deja escrito en el
  log contra qué se probó.

### 2.6 Lo que la CI no prueba

En la CI no hay laboratorio: los tests que lo necesitan se **saltan**
(teoría 04, `skip`). Las alternativas tienen su coste:

| Opción | Coste |
|---|---|
| Levantar el laboratorio con `docker compose` en la CI | El repositorio del toolkit tendría que llevar el compose y la CA del laboratorio |
| Probar contra una API real | Un secreto en la CI, rate limit y fallos cuando la API cambia |
| Saltar los de red y probar el resto con `--dry-run` | Lo de red se prueba en tu máquina con `bats` y `verificar-semana.sh` |

Para el toolkit, la tercera. El `ponytail:` de la decisión está en el
propio workflow, como comentario.

---

## 3. Cómo se usa

```bash
git add .github/workflows/ci.yml && git commit -m "ci: shellcheck y bats" && git push
gh run list --limit 1
# completed  success  ci: shellcheck y bats  CI  main  push  ...
gh run view --log-failed      # si falló, solo las líneas de los pasos rojos
```

Antes de empujar, ejecuta en tu máquina los mismos comandos que la CI:
`shellcheck -S warning api-toolkit.sh install.sh && bats tests/`. La CI
confirma; no es para descubrir errores de sintaxis.

---

## 4. Antipatrones

- **`uses: accion@main` o `@v6`**: ejecutas lo que haya hoy en esa rama o
  etiqueta.
- **Sin `permissions`**: el token tiene lo que diga la configuración del
  repositorio, que puede ser escritura.
- **`runs-on: ubuntu-latest`** para probar una versión concreta de curl:
  cambia de Ubuntu cuando GitHub decide.
- **Secretos en el log**: un `echo "$API_TOKEN"` o un `set -x` en un paso
  que los usa. GitHub tapa los secretos que conoce, no los que tú derivas.
- **Sin `timeout-minutes`**: un test colgado consume horas de runner.
- **La CI como primer sitio donde se ejecutan los tests.** Un ciclo de
  empujar y esperar dos minutos por cada error tipográfico.

---

## 5. Trucos

- **Una marca en el `README`** con el estado de la CI:
  `![CI](https://github.com/<usuario>/api-toolkit/actions/workflows/ci.yml/badge.svg)`.
- **Ejecutar el workflow a mano** desde la pestaña Actions: añade
  `workflow_dispatch:` en `on`.
- **Validar el YAML antes de empujar**: un error de indentación no da
  ningún aviso hasta que GitHub lo rechaza. `actionlint`, si lo tienes,
  revisa también las expresiones `${{ }}`.
- **Probar la imagen en local**, si tienes Docker:
  `docker run --rm -v "$PWD":/w -w /w ubuntu:22.04 bash -c 'apt-get update -qq && apt-get install -y -qq curl jq bats && bats tests/'`.

---

## 📚 Recursos Adicionales

- [GitHub Actions — Workflow syntax](https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions)
- [GitHub Actions — Security hardening: using third-party actions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions#using-third-party-actions)
- [actions/runner-images — imágenes disponibles y retiradas](https://github.com/actions/runner-images)

---

## ✅ Checklist de Verificación

- [ ] Lees un workflow: `on`, `permissions`, `jobs`, `steps`, `uses` y `run`
- [ ] Pruebas con dos versiones de curl con una matriz de contenedores
- [ ] Fijas una acción por SHA y sabes sacarlo con `git ls-remote`
- [ ] Explicas qué evita `permissions: contents: read`
- [ ] Sabes qué tests se saltan en la CI y dónde se prueban
