# De script a herramienta

> Después de nueve semanas, `api-toolkit.sh` hace mucho: verbos, credenciales,
> descargas reanudables, TLS, trazas, reintentos, OAuth2, `bench` y caché. Pero
> solo lo puedes usar tú, desde tu carpeta, con tus variables exportadas, y
> nadie sabe si el cambio de ayer rompió algo. Esta semana no añade
> funcionalidad: añade lo que hace falta para que otra persona lo instale, lo
> configure, lo entienda y confíe en que sigue funcionando.

![Las cinco cosas que separan un script de una herramienta, alrededor de api-toolkit: se instala con un comando, se configura sin editar el código, explica su uso con --help y --version, se prueba con bats, y la CI ejecuta las pruebas en cada push. Debajo, el contrato que no cambia: stdout para los datos, stderr para los mensajes, y los códigos de salida 0, 1, 69, 75 y 77](../0-assets/01-de-script-a-herramienta.svg)

## 🎯 Objetivos

- Distinguir un script que funciona de una herramienta que otra persona puede usar
- Reconocer la interfaz de una CLI: argumentos, entorno, stdout, stderr y código de salida
- Decidir si conviene partir un script grande en varios archivos
- Saber qué entra en la capa 10 y qué se queda fuera a propósito
- Ver la versión como una promesa sobre esa interfaz

---

## 1. Qué problema resuelve

Haz la prueba: dale tu `api-toolkit.sh` a otra persona del curso. Lo primero
que va a preguntar es:

1. **¿Dónde lo pongo?** Hoy se ejecuta con su ruta entera, desde tu carpeta.
2. **¿Cómo le digo a qué API hablar?** Hoy, exportando `BASE_URL` en cada
   terminal, o editando el script.
3. **¿Qué hace y qué versión es?** `--help` existe; `--version`, no.
4. **¿Cómo sé que funciona?** Hoy, porque lo pruebas a mano cuando te
   acuerdas.
5. **¿Cómo sé que sigue funcionando?** Hoy, no lo sabes.

Ninguna de las cinco es una funcionalidad nueva de HTTP. Son lo que convierte
mil cuatrocientas líneas de bash en algo que se puede **entregar**.

---

## 2. Cómo funciona

### 2.1 La interfaz de una CLI

La teoría 08 de la Semana 07 lo llamó el contrato de un script. Una función
tiene parámetros y un valor de retorno. Una herramienta de línea de comandos
tiene cinco canales, y quien la use (una persona, un script, un
cron, la CI) depende de todos:

| Canal | En `api-toolkit` | Quién depende de él |
|---|---|---|
| Argumentos | `get /users`, `--dry-run`, `--version` | Quien la invoca |
| Entorno y archivo de configuración | `BASE_URL`, `AUTH_MODE`, `~/.bc-curl` | Quien la configura una vez |
| stdout | Solo el cuerpo de una respuesta 2xx o 3xx | El `\| jq` de detrás |
| stderr | Mensajes, errores, trazas de `--verbose` | La persona que mira la terminal |
| Código de salida | 0, 1, 69, 75, 77 | El `if`, el `&&` y el cron |

Cambiar cualquiera de los cinco rompe a alguien. Un mensaje que pasa de
stderr a stdout rompe el `| jq`. Un código que pasa de 75 a 1 rompe el cron
que reintentaba.

### 2.2 Lo que añade la capa 10

| Pregunta | Respuesta en la capa 10 | Teoría |
|---|---|---|
| ¿Cómo le digo a qué API hablar? | `~/.bc-curl` también guarda `BASE_URL` y `AUTH_MODE`; el entorno manda | 02 |
| ¿Cómo creo ese archivo sin equivocarme? | `api-toolkit init`, que nunca pisa uno existente | 03 |
| ¿Cómo sé que funciona? | `tests/api-toolkit.bats`, con bats | 04 y 05 |
| ¿Qué hace y qué versión es? | `--help` completo y `--version` | 06 |
| ¿Dónde lo pongo? | `install.sh`, en `~/.local/bin` | 07 |
| ¿Cómo sé que sigue funcionando? | Un workflow de GitHub Actions con curl 7.81 y 8.5 | 08 |

### 2.3 ¿Un archivo o varios?

El documento del hilo conductor avisaba: cuando pase de unas 600 líneas,
partirlo se plantea en la Semana 10. Va por 1400. Las dos opciones:

| | Un archivo | `bin/` + `lib/*.sh` |
|---|---|---|
| Instalar | Copiar un archivo | Copiar un árbol y que el principal encuentre sus librerías |
| Encontrar las librerías | — | `$(dirname "$(readlink -f "$0")")/../lib`: `readlink -f` no existe en el macOS antiguo |
| Probar | Como caja negra, igual | Igual, más la tentación de probar funciones sueltas |
| Leer | Un archivo largo, con secciones | Varios cortos, con saltos |
| shellcheck | Lo ve todo | Necesita `source` con directivas para seguir los `.sh` |

Para una herramienta que se instala copiando, **un archivo gana**. Las
secciones con `# --- Credenciales (capa 3) ---` ya hacen de capítulos. Se
parte cuando aparece una razón concreta: dos programas que comparten código,
o un equipo editando a la vez el mismo archivo.

### 2.4 La versión es una promesa

`1.0.0` no significa "está terminado". En versionado semántico significa:
**la interfaz es estable**. A partir de aquí:

- `1.0.1`: arreglos que no cambian la interfaz.
- `1.1.0`: algo nuevo que no rompe lo anterior (un subcomando más).
- `2.0.0`: algo que rompe a quien ya lo usa (un código de salida que cambia).

Por eso esta capa sube de `0.9.0` a `1.0.0`: es la primera vez que la
interfaz queda documentada, probada y verificada en CI. Lo verás en la
teoría 06.

### 2.5 Lo que se queda fuera, a propósito

Una herramienta "de verdad" suele traer más cosas. Ninguna entra en la capa
10, y cada una tiene su razón:

| Lo que falta | Por qué no ahora | Cuándo añadirlo |
|---|---|---|
| Página `man` | `--help` ya es la referencia, y se mantiene en el mismo archivo que el código | Cuando la ayuda no quepa en una pantalla y media |
| Autocompletado de bash o zsh | Un archivo más que instalar en una ruta distinta en cada sistema | Cuando los subcomandos lleven argumentos que se puedan listar |
| Paquete `.deb` o fórmula de Homebrew | Exige un repositorio de paquetes y firmar las versiones | Cuando haya personas que no quieran clonar un repositorio |
| Preguntas interactivas en `init` | Impiden usarlo desde un script y complican los tests | Nunca, si el entorno lo resuelve (teoría 03) |
| Actualización automática | Descargar y ejecutar código nuevo sin preguntar es el antipatrón `curl \| bash` | Nunca: se actualiza con `git pull` y `./install.sh` |

Cada una de esas cosas es código, y el código que no se escribe no hay que
probarlo ni documentar. La capa 10 entrega lo mínimo para que otra persona
pueda usar el toolkit y confiar en él.

---

## 3. Cómo se usa

Así se ve una herramienta entregada, desde cero, en una máquina que no es la
tuya:

```bash
git clone https://github.com/<tu-usuario>/api-toolkit && cd api-toolkit
./install.sh
# instalado: /home/ana/.local/bin/api-toolkit (api-toolkit 1.0.0)

BASE_URL=https://api.github.com AUTH_MODE=bearer api-toolkit init
# configuracion creada en /home/ana/.bc-curl (permisos 600)

"$EDITOR" ~/.bc-curl            # descomenta API_TOKEN y pega el token
api-toolkit get /rate_limit | jq .rate
```

Y así se comprueba que una rama no rompe nada antes de unirla:

```bash
bats tests/
# 1..14
# ok 1 --version imprime el nombre y una version semver
# ...
# ok 14 un archivo de configuracion legible por otros se rechaza
```

---

## 4. Antipatrones

- **"Funciona en mi máquina".** Un script que solo arranca con tus variables
  exportadas y desde tu carpeta no está entregado. La prueba es otra cuenta,
  otro HOME, o un contenedor.
- **Editar el código para configurarlo.** Cambiar `BASE_URL` en el script
  hace que cada actualización pise la configuración, y que el secreto acabe
  comiteado.
- **Mensajes por stdout.** "Conectando..." delante del JSON rompe el `| jq`
  de quien te usa. Todo lo que no es el dato, a stderr.
- **Partir en archivos por estética.** Cada archivo nuevo es algo más que
  instalar, encontrar y mantener en sincronía.
- **`1.0.0` sin tests.** Prometer estabilidad sin nada que la compruebe es
  una promesa que se rompe sin que nadie se entere.
- **Añadir funcionalidad en la semana de entrega.** La capa 10 no trae
  subcomandos HTTP nuevos a propósito: lo que no está probado y documentado,
  no se entrega.

---

## 5. Trucos

- **Probar como otra persona** sin crear un usuario: `env -i HOME="$(mktemp -d)" PATH="$PATH" ./api-toolkit.sh --version`.
  `env -i` vacía el entorno; lo que funcione así, funciona en otra máquina.
- **Ver la interfaz de un vistazo**: `api-toolkit --help | grep -E '^  [a-z]'`
  lista los subcomandos.
- **El código de salida del último comando**: `echo $?`, justo después.
  Cualquier otro comando en medio lo pisa.
- **Separar canales al probar**: `api-toolkit get /x > out.txt 2> err.txt; echo $?`
  enseña los tres canales de salida por separado.
- **Contar líneas por capa**: `grep -n '^# --- ' api-toolkit.sh` lista las
  secciones con su línea. Es el índice de un archivo largo, y la razón de
  que no haga falta partirlo.

---

## 📚 Recursos Adicionales

- [Command Line Interface Guidelines](https://clig.dev/)
- [Semantic Versioning 2.0.0](https://semver.org/lang/es/)
- [The Art of Unix Programming — Rule of Silence](http://www.catb.org/esr/writings/taoup/html/ch01s06.html)

---

## ✅ Checklist de Verificación

- [ ] Nombras los cinco canales de la interfaz de una CLI
- [ ] Explicas por qué un mensaje en stdout rompe a quien usa el toolkit
- [ ] Sabes por qué el toolkit sigue siendo un solo archivo
- [ ] Explicas qué promete `1.0.0` y qué cambio obligaría a `2.0.0`
- [ ] Sabes qué añade cada teoría de esta semana a la entrega
