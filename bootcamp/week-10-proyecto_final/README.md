# Semana 10 — Proyecto final

> Nueve semanas después, `api-toolkit.sh` habla con casi cualquier API REST:
> verbos, credenciales fuera de la línea de comandos, descargas reanudables,
> TLS con CA propia, trazas tachadas, reintentos con códigos que se pueden
> automatizar, OAuth2, `bench` y caché. Solo hay un problema: solo funciona
> en tu carpeta, con tus variables, y nadie sabe si el cambio de ayer rompió
> algo. Esta semana no aprendes nada nuevo de HTTP. Aprendes a entregar: a
> que otra persona lo instale, lo configure, lo entienda y confíe en él.

---

## 🎯 Objetivos de la Semana

Al terminar serás capaz de:

- Reconocer la interfaz de una CLI (argumentos, entorno, stdout, stderr y código de salida) y tratarla como un contrato con versión
- Leer la configuración con la precedencia entorno, archivo y valor por defecto, sin ejecutar el archivo
- Crear un archivo de configuración con permisos 600 sin pisar uno existente, también con dos procesos a la vez
- Escribir tests con bats 1.2.1 que no dependan de quien los ejecuta y que sean capaces de fallar
- Documentar una CLI repartiendo lo que va en `--help`, en el `README` y en el `CHANGELOG`
- Instalar y desinstalar sin `sudo` y sin borrar los datos del usuario, y explicar el riesgo de `curl | bash`
- Montar una CI con GitHub Actions que pruebe con curl 7.81 y 8.5, con permisos mínimos y acciones fijadas por SHA

---

## 📋 Prerrequisitos

- **Semana 09 completada**: `api-toolkit.sh` con la capa 9 y `./scripts/verificar-semana.sh 09` en verde. El starter de esta semana parte de ella
- **Semana 03 repasada**: `~/.bc-curl` con permisos 600 y la regla de que ningún secreto pasa por la línea de comandos. Esta semana el mismo archivo guarda también la configuración
- **Semana 07 repasada**: los códigos de salida 0, 1, 69, 75 y 77, que esta semana se documentan como parte de la interfaz
- **Semana 02 repasada**: `--dry-run`, la puerta para probar el toolkit sin red
- **El laboratorio arriba**: `./scripts/start.sh`. Solo lo necesitan un check y un test; el resto se prueba sin red
- **bats 1.2.1 o posterior**: `sudo apt install bats` en Ubuntu (22.04 trae la 1.2.1, el suelo del bootcamp) o `brew install bats-core` en macOS. Compruébalo con `bats --version`
- **Una cuenta de GitHub** para la práctica 04 y la entrega. Si quieres hacerlo desde la terminal, `gh` con sesión iniciada; sin `gh`, se hace desde la web

---

## 🗂️ Estructura de la Semana

```
week-10-proyecto_final/
├── README.md                  # Este archivo
├── rubrica-evaluacion.md      # Cómo se evalúa
├── checks.json                # Las 18 comprobaciones automáticas
├── 0-assets/                  # Diagramas
├── 1-teoria/                  # 8 archivos, un concepto cada uno
├── 2-practicas/               # 4 prácticas, del toolkit a tu repositorio
├── 3-proyecto/                # La capa 10: entregable
│   └── starter/               # api-toolkit.sh, install.sh, tests/ y .github/
├── 4-recursos/                # Libros, vídeos y enlaces
└── 5-glosario/                # Términos de esta semana
```

---

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01 — De script a herramienta](1-teoria/01-de-script-a-herramienta.md) | Los cinco canales de la interfaz de una CLI, qué añade la capa 10, un archivo o varios, la versión como promesa y lo que se queda fuera | 15 min |
| [02 — Configuración y precedencia](1-teoria/02-configuracion-y-precedencia.md) | Entorno, archivo y valor por defecto, por qué no `source`, la lista de claves, `${!clave}` y `printf -v`, y dónde vive la configuración | 15 min |
| [03 — `init` sin pisar nada](1-teoria/03-init-sin-pisar-nada.md) | `noclobber` y `O_EXCL`, `umask 077` en un subshell, qué escribe `init` y qué no, por qué sin preguntas y sin `--force` | 15 min |
| [04 — Tests con bats](1-teoria/04-tests-con-bats.md) | `run`, `$status`, `$output`, `setup`, `teardown` y `skip`, qué tiene bats 1.2.1, la trampa de `!` y cómo leer un fallo | 15 min |
| [05 — Tests que prueban algo](1-teoria/05-tests-que-prueban-algo.md) | Aislar el HOME y el entorno, valores que no salen por casualidad, `--dry-run` como caja negra, un fallo de red sin red y `TK=/bin/true` | 15 min |
| [06 — Documentar una CLI](1-teoria/06-documentar-una-cli.md) | `--help` junto al código, `--version`, los códigos de salida como interfaz, el `README`, el `CHANGELOG` y la etiqueta de git | 15 min |
| [07 — Instalar y desinstalar](1-teoria/07-instalar-y-desinstalar.md) | `PREFIX` y `~/.local/bin`, `install` frente a `cp`, comprobar y avisar del PATH, desinstalar sin borrar lo del usuario y `curl \| bash` | 15 min |
| [08 — Integración continua](1-teoria/08-integracion-continua.md) | Anatomía de un workflow, una matriz de contenedores con curl 7.81 y 8.5, acciones por SHA, permisos mínimos y lo que la CI no prueba | 15 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01 — Configuración e `init`](2-practicas/01-configuracion-e-init.md) | El archivo que la capa 9 ignoraba, `source` ejecutando un `touch`, la lectura con `read`, `PATH=/nada` ignorado, `init` y ocho `init` en carrera | 50 min |
| [02 — Tests con bats](2-practicas/02-tests-con-bats.md) | La suite del starter, leer un fallo, la suite rota con otro HOME, el aislamiento, `skip`, los tests de `init` y `TK=/bin/true` | 50 min |
| [03 — Instalar y documentar](2-practicas/03-instalar-y-documentar.md) | El instalador en una carpeta temporal y en `~/.local/bin`, `cp` frente a `install`, `hash -r`, y tu repositorio con `README`, `CHANGELOG` y `v1.0.0` | 50 min |
| [04 — Integración continua](2-practicas/04-integracion-continua.md) | Permisos y pasos del workflow, lo mismo en local, el SHA con `git ls-remote`, el check roto con `@v6`, y la CI en verde en GitHub | 50 min |

### Proyecto

La **capa 10** de tu plataforma: `api-toolkit.sh` se vuelve entregable, en
su versión `1.0.0`. Lee `BASE_URL`, `AUTH_MODE` y `API_CACERT` también de
`~/.bc-curl`, con el entorno por encima y sin ejecutar el archivo; `init` lo
crea con 600 sin pisar nada; `--version` y `--help` lo documentan;
`install.sh` lo instala y lo quita; `tests/` lo prueba con bats; y un
workflow de GitHub Actions lo prueba en cada push con curl 7.81 y 8.5. La
entrega es tu repositorio, con la CI en verde. Detalles en
[3-proyecto](3-proyecto/README.md).

---

## ⏱️ Distribución del Tiempo (8 horas)

| Bloque | Tiempo |
|---|:--:|
| Teoría (8 archivos) | 2 h 00 |
| Prácticas (4 × 50 min) | 3 h 20 |
| Proyecto | 2 h 00 |
| Revisión y verificación | 40 min |
| **Total** | **8 h 00** |

> [!TIP]
> Haz la práctica 01 antes de los TODOs 1 y 2 del proyecto, la 02 antes del
> 3 y el 4, la 03 antes del 5, y la 04 antes del 6. No quites el
> `export HOME` del `setup` de los tests: sin él, los de `init` escriben en tu
> `~/.bc-curl` de verdad.

---

## 🧳 Qué entregas, y dónde vive

Al final de la semana hay dos copias del toolkit, y cada una tiene su papel:

| Dónde | Qué | Para qué |
|---|---|---|
| `3-proyecto/starter/` de este repositorio | `api-toolkit.sh`, `install.sh`, `tests/`, `.github/` | El autograding: `./scripts/verificar-semana.sh 10` |
| `~/bc-curl-trabajo/api-toolkit/`, en tu GitHub | Lo mismo, más `README.md` y `CHANGELOG.md`, con la etiqueta `v1.0.0` | La entrega: lo que otra persona clona |
| `~/.local/bin/api-toolkit` | La copia instalada | El comando que usas cada día |
| `~/.bc-curl` | Tu configuración y tus secretos, con 600 | Solo tuyo: ni en el repositorio ni en la CI |

El repositorio de la entrega **no** lleva `~/.bc-curl`, ni un `.env`, ni un
token en el workflow. Si alguna vez se coló uno en un commit, borrarlo en el
siguiente no basta: está en el historial. Rótalo.

---

## 🎩 Trucos y atajos

| Truco | Cómo |
|---|---|
| Probar el toolkit como otra persona | `env -i HOME="$(mktemp -d)" PATH="$PATH" api-toolkit --version`: sin tu entorno ni tu `~/.bc-curl` |
| Desactivar `~/.bc-curl` para una orden | `BC_CURL_FILE=/dev/null api-toolkit get /x`: no es un archivo normal, y no se lee |
| Ver de dónde sale la URL final | `api-toolkit --dry-run get /x \| grep -o 'http[^ ]*'`. Si no es la esperada, mira primero `env \| grep BASE_URL` |
| Crear un archivo vacío con 600 en una línea | `( umask 077 && : > archivo )`: nace cerrado, sin ventana con 644 |
| No truncar por un `>` de más en tu shell | `set -o noclobber` en el `~/.bashrc`; para pisar a propósito, `>\|` |
| Lanzar solo un grupo de tests | `bats -f init tests/`: filtra por el nombre del test |
| Ver qué imprimió el toolkit en un test que falla | `echo "salida: $output"` antes de la aserción: bats solo lo enseña si el test falla |
| Comprobar que tus tests pueden fallar | `TK=/bin/true bats tests/` tiene que salir con 1 |
| El SHA de una acción, sin clonar | `git ls-remote https://github.com/actions/checkout refs/tags/v6.1.0` |
| El comando borrado que el shell aún "encuentra" | `hash -r` olvida las rutas recordadas; `type -a api-toolkit` las lista todas |
| Instalar sin tocar nada para probar | `PREFIX="$(mktemp -d)" ./install.sh` |
| El paso rojo de un run de la CI | `gh run view --log-failed`: solo las líneas de los pasos que fallaron |

---

## 📌 Entregables

1. `configuracion.md` con el archivo que la capa 9 ignoraba, el `touch` de `source`, la precedencia, `PATH=/nada` ignorado, el archivo de `init` y la carrera de ocho `init`
2. `tests.md` con un fallo leído hasta su línea, la suite rota con otro HOME y arreglada, el test que pasaba con `/bin/true` y la mutación de la umask
3. `instalacion.md` con la instalación temporal y la real, `cp` frente a `install` y la desinstalación con `hash -r`
4. `ci.md` con el SHA comprobado, el check roto con `@v6` y la URL del run en verde
5. El starter con la capa 10 completa y ningún `TODO` pendiente: `api-toolkit.sh`, `install.sh`, `tests/api-toolkit.bats` y `.github/workflows/ci.yml`
6. Tu repositorio `api-toolkit` en GitHub con `README.md`, `CHANGELOG.md`, la CI en verde con las dos imágenes y la etiqueta `v1.0.0`

---

## ✅ Verificación

```bash
./scripts/start.sh
./scripts/verificar-semana.sh 10
```

Las 18 comprobaciones tienen que pasar. Si alguna falla, la pista te dice en qué
práctica y en qué paso se arregla. La CI en verde de tu repositorio no la ve
el script: va en la rúbrica.

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [Semana 09 — HTTP/2, paralelismo y rendimiento](../week-09-http2_paralelismo_performance/README.md) | **Semana 10 — Proyecto final** | — |

[← Volver al inicio del bootcamp](../README.md)
