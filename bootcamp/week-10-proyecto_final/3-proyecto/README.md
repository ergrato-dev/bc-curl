# Proyecto — Capa 10: entregable

> Nueve capas después, `api-toolkit.sh` sabe hablar con casi cualquier API
> REST. Lo que no sabe es salir de tu carpeta. Esta capa no le añade nada de
> HTTP: le añade un `init` que crea su configuración sin pisar nada, una
> configuración que se lee y no se ejecuta, un instalador, una suite de
> tests que se puede creer y una CI que la ejecuta con curl 7.81 y con 8.5.
> Es la versión `1.0.0`, y es la que entregas.

---

## 🎯 Objetivo

Que el toolkit **lo pueda usar otra persona**, en otra máquina, sin leer el
código y sin preguntarte. Concretamente:

- `BASE_URL`, `AUTH_MODE`, `API_CACERT` y las URLs de OAuth2 se leen también
  de `~/.bc-curl`, con el entorno por encima y sin ejecutar el archivo.
- `api-toolkit init` crea ese archivo con permisos 600, sin pisar uno que ya
  existe y sin escribir ningún secreto.
- `--version` y un `--help` que documenta todos los subcomandos.
- `install.sh` lo instala en `~/.local/bin` y lo desinstala sin tocar tu
  configuración.
- `tests/api-toolkit.bats`: al menos 13 tests, aislados de tu HOME y de tu
  entorno, que fallan si el toolkit no hace nada.
- `.github/workflows/ci.yml`: shellcheck y bats en cada push, con permisos de
  solo lectura y las acciones fijadas por SHA.

Y, fuera del autograding, tu repositorio `api-toolkit/` con `README.md`,
`CHANGELOG.md`, la etiqueta `v1.0.0` y la CI en verde.

---

## 📦 Qué añade esta capa

La Semana 09 hizo al toolkit rápido. Esta lo hace entregable.

| Viene de la Semana 09 | Lo añade esta capa |
|---|---|
| `BASE_URL` y `AUTH_MODE` solo del entorno; su valor por defecto en la primera línea | `cargar_configuracion`: entorno, después `BC_CURL_FILE`, después el valor por defecto |
| `~/.bc-curl` con seis claves de credenciales, una por una en un `case` | `CLAVES_ARCHIVO`: una lista; `${!clave}` y `printf -v` en un bucle |
| El archivo se escribía a mano | `init`: `plantilla_configuracion` e `iniciar_configuracion`, con `umask 077` y `noclobber` |
| La versión solo en el User-Agent | `--version`, y la versión `1.0.0` |
| Se ejecutaba con su ruta | `install.sh`: `install -m 755` en `PREFIX/bin`, y `uninstall` |
| Lo probaba `verificar-semana.sh`, desde fuera | `tests/api-toolkit.bats`: 14 tests, 8 de ellos ya escritos |
| — | `.github/workflows/ci.yml`: matriz `ubuntu:22.04` y `ubuntu:24.04` |

Tres decisiones que conviene entender antes de empezar:

- **Un solo archivo.** 1400 líneas, pero se instala copiando uno. Partirlo
  en `lib/` añade rutas que resolver al instalar y no aporta nada a quien
  lo usa (teoría 01, apartado 2.3).
- **`init` no pregunta.** Se configura por entorno:
  `BASE_URL=... AUTH_MODE=bearer api-toolkit init`. Así funciona desde un
  script, desde la CI y desde bats (teoría 03, apartado 2.4).
- **La CI no levanta el laboratorio.** Los tests que lo necesitan se saltan
  solos; el `ponytail:` del workflow dice cómo añadirlo si un día hace falta
  (teoría 08, apartado 2.6).

---

## ✅ Requisitos verificables

`./scripts/verificar-semana.sh 10` comprueba estas dieciocho cosas. Las
descripciones son literales: si una falla, es la que tienes que buscar aquí.

1. bats 1.2.1 o posterior esta instalado
2. api-toolkit.sh e install.sh son ejecutables y arrancan con set -euo pipefail
3. No queda ningun TODO por resolver en el starter
4. --version imprime api-toolkit 1.0.0
5. get sigue funcionando contra el laboratorio
6. --help documenta todos los subcomandos, init incluido
7. init crea ~/.bc-curl con permisos 600 y sin los secretos del entorno
8. init no pisa un ~/.bc-curl que ya existe y sale con 1
9. La BASE_URL de ~/.bc-curl se usa si no esta en el entorno
10. Una BASE_URL del entorno manda sobre la del archivo
11. El archivo de configuracion se lee, no se ejecuta
12. install.sh instala en PREFIX/bin/api-toolkit y uninstall lo borra
13. tests/ tiene al menos 13 tests
14. bats tests/ pasa entero
15. Los tests pasan aunque tu HOME y tu entorno esten rotos
16. Los tests fallan si el toolkit no hace nada
17. El workflow de CI tiene permisos de solo lectura, acciones fijadas por SHA, shellcheck y bats
18. shellcheck -S warning no encuentra nada en api-toolkit.sh ni en install.sh

Las comprobaciones de `init` y de la configuración se ejecutan con un HOME
temporal: tu `~/.bc-curl` real no se toca.

---

## 🎨 Criterios de calidad

Lo que el autograding no ve y la rúbrica sí:

- **Ningún `source` ni `eval`** sobre el archivo de configuración, y ninguna
  clave fuera de `CLAVES_ARCHIVO`.
- **Los valores por defecto, después de leer el archivo**, y en un solo
  sitio.
- **`umask 077` y `noclobber` dentro de un subshell**: el resto del toolkit
  sigue con la umask de quien lo ejecuta.
- **`init` no tiene `--force`**: borrar un archivo con secretos es una
  decisión con `rm`.
- **`install.sh` busca el origen a su lado**, avisa del PATH sin tocar el
  `~/.bashrc` de nadie, y `uninstall` solo borra el ejecutable.
- **Cada test se puede leer por su nombre**, comprueba la salida además del
  código, y no depende de otro.
- **`teardown` borra `$DIR`, nunca `$HOME`.**
- **Ningún `! comando` en medio de un test** (teoría 04, apartado 2.3).
- **El workflow lleva `timeout-minutes`** y `persist-credentials: false`, y
  el comentario de cada acción dice su versión.
- **El `README` de tu repositorio** tiene las siete secciones de la teoría
  06 y no copia `--help` entero; el `CHANGELOG` habla de lo que cambia para
  quien lo usa.

---

## 💡 Adaptación a tu dominio

La configuración es lo que hace que tu toolkit hable con tu API sin
exportar nada. En tu repositorio, deja en el `README` el `init` de tu
dominio:

| Dominio | `init` | Qué va después en `~/.bc-curl` |
|---|---|---|
| GitHub | `BASE_URL=https://api.github.com AUTH_MODE=bearer api-toolkit init` | `API_TOKEN=` con un token de grano fino, solo lectura |
| Open-Meteo | `BASE_URL=https://api.open-meteo.com AUTH_MODE=none api-toolkit init` | Nada: no necesita credencial |
| TfL | `BASE_URL=https://api.tfl.gov.uk AUTH_MODE=apikey api-toolkit init` | `API_KEY=`, y `API_KEY_HEADER` en el entorno si no es la de por defecto |
| TMDB | `BASE_URL=https://api.themoviedb.org/3 AUTH_MODE=bearer api-toolkit init` | `API_TOKEN=` con el token de lectura de la API |

`API_KEY_HEADER` no está en `CLAVES_ARCHIVO`: si tu API la necesita
distinta, o la exportas, o la añades a la lista (y a la cabecera). Es una
decisión tuya; anótala en el `CHANGELOG`.

Ningún test de tu suite debe llamar a la API de tu dominio: gastaría rate
limit en cada push y necesitaría un secreto en la CI (teoría 05, apartado 4).

---

## 🚦 Cómo entregarlo

**1.** El starter trae la capa 9 resuelta y el esqueleto de la 10: el
toolkit, `install.sh`, `tests/` y `.github/`. Edítalos en su sitio: el
autograding comprueba esos archivos.

```bash
cd bootcamp/week-10-proyecto_final/3-proyecto/starter/
ls -A
# .github  api-toolkit.sh  install.sh  tests
```

**2.** Resuelve los seis TODOs, en orden:

| TODO | Archivo | Qué | Dónde se practica |
|---|---|---|---|
| 1 | `api-toolkit.sh` | `cargar_configuracion`: leer el archivo sin ejecutarlo | Teoría 02 §2.2 a §2.4; práctica 01, pasos 3 a 5 |
| 2 | `api-toolkit.sh` | `iniciar_configuracion`: `init` con 600 y sin pisar | Teoría 03 §2.1 a §2.3; práctica 01, pasos 6 y 7 |
| 3 | `tests/api-toolkit.bats` | `setup`: sin las variables del toolkit (el HOME vacío ya viene) | Teoría 05 §2.1; práctica 02, pasos 3 y 4 |
| 4 | `tests/api-toolkit.bats` | Los tests de `init` y de la configuración | Teoría 05 §2.2; práctica 02, pasos 6 y 7 |
| 5 | `install.sh` | `instalar` y `desinstalar` | Teoría 07 §2.2 a §2.5; práctica 03, pasos 2 a 5 |
| 6 | `.github/workflows/ci.yml` | Permisos y los cuatro pasos | Teoría 08 §2.4 y §2.5; práctica 04, pasos 2 y 3 |

El starter ya aísla el HOME de cada test: no quites ese `export`, o los tests
de `init` escribirán en tu `~/.bc-curl` real. El 4 prueba lo que hacen el 1 y
el 2.

**3.** Pruébalo a mano, desde la raíz del repositorio:

```bash
ST=bootcamp/week-10-proyecto_final/3-proyecto/starter
H="$(mktemp -d)"

HOME="$H" BASE_URL=http://localhost:8080/anything "$ST/api-toolkit.sh" init
# configuracion creada en /tmp/tmp.XXXXXXXXXX/.bc-curl (permisos 600)
HOME="$H" "$ST/api-toolkit.sh" get /x | jq -r .url
# http://localhost:8080/anything/x

P="$(mktemp -d)"
PREFIX="$P" "$ST/install.sh" 2> /dev/null
# instalado: /tmp/tmp.YYYYYYYYYY/bin/api-toolkit (api-toolkit 1.0.0)

(cd "$ST" && bats tests/ | tail -1)
# ok 14 un archivo de configuracion legible por otros se rechaza
rm -rf "$H" "$P"
```

**4.** Pásale el autograding y shellcheck:

```bash
./scripts/verificar-semana.sh 10
shellcheck -S warning "$ST/api-toolkit.sh" "$ST/install.sh"
```

**5.** Llévalo a tu repositorio (prácticas 03 y 04): los cuatro archivos del
starter, tu `README.md` y tu `CHANGELOG.md`, la CI en verde y la etiqueta
`v1.0.0` sobre ese commit. La URL del repositorio es lo que entregas.

---

## 🧯 Errores comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `bats-instalado` falla | bats no está, o es anterior a 1.2.1 | `sudo apt install bats` o `brew install bats-core` |
| `config-del-archivo` da `localhost:8080/x` | El bucle no asigna, o los valores por defecto siguen arriba del todo | TODO 1; `BASE_URL="${BASE_URL:-}"` arriba, el valor por defecto al final de `cargar_configuracion` |
| `config-no-ejecuta` dice `ejecutado` | `source` o `eval` sobre el archivo | El bucle con `read` y `printf -v` |
| `config-no-ejecuta` sale con 1 | `PATH=/nada` se aplicó: la clave no se filtró por `CLAVES_ARCHIVO` | El `case " $CLAVES_ARCHIVO " in *" $clave "*)` |
| `init-crea-600` da `-rw-r--r--` | `umask` fuera del subshell, o `chmod` después | `( umask 077 && set -o noclobber && ... )` |
| `init-crea-600` termina en `1` | La plantilla escribe el `API_TOKEN` del entorno | Los secretos, comentados y vacíos |
| `instalar` termina en `1` en lugar de `0` | `desinstalar` no borra, o borra otra ruta | `rm -f "$DESTINO"` |
| `tests-aislados` falla | Falta el TODO 3, o una variable en el `unset` | Práctica 02, paso 4 |
| `tests-detectan-fallos` falla | Todos los tests solo miran `$status`, o comprueban solo ausencias | Práctica 02, paso 7 |
| `ci-workflow` falla con todo escrito | Una acción con `@v6`, o el `permissions` comentado | Práctica 04, paso 6 |

---

## 🔗 Navegación

| Anterior | Siguiente |
|---|---|
| [Práctica 04 — Integración continua](../2-practicas/04-integracion-continua.md) | [Rúbrica de evaluación](../rubrica-evaluacion.md) |

[← Volver a la Semana 10](../README.md)
