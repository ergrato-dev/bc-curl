# `set -euo pipefail` y sus trampas

> `set -euo pipefail` es la primera línea de todo script del bootcamp desde la
> Semana 01. Ahora toca saber lo que **no** hace: hay media docena de sitios
> donde un fallo pasa sin que el script se entere, y uno donde aborta sin que
> haya fallado nada.

![Diagrama de las tres opciones de set -euo pipefail, cada una con lo que vigila y su trampa principal: -e aborta ante un comando que falla, pero no dentro de if, ||, && ni en local x=$(...); -u aborta ante una variable sin definir, y se esquiva con ${VAR:-}; -o pipefail hace que una tubería falle si falla cualquiera de sus comandos, y por eso curl | head puede abortar con 23](../0-assets/03-errexit-y-sus-trampas.svg)

## 🎯 Objetivos

- Saber qué vigila cada una de las tres opciones
- Reconocer los contextos donde `-e` se apaga sin avisar
- Recoger el código de curl con `|| rc=$?` sin desactivar nada
- Evitar el aborto falso de `curl | head` con `pipefail`

---

## 1. Qué problema resuelve

```bash
#!/usr/bin/env bash
curl -sS --fail-with-body --max-time 10 -o datos.json "$URL"
jq '.[]' datos.json > resultado.txt
cp resultado.txt /srv/publico/
```

Sin `set -e`, si curl falla el script sigue: `jq` falla sobre un archivo que no
existe, `cp` copia un `resultado.txt` vacío, y el script termina con el código
de `cp`, que es 0. Un fallo en la primera línea ha acabado en producción como
éxito.

`set -euo pipefail` corta eso. Pero tiene reglas, y un script de producción
las rompe a menudo.

---

## 2. Cómo funciona

### 2.1 Las tres opciones

| Opción | Nombre largo | Qué hace |
|---|---|---|
| `-e` | `errexit` | Aborta cuando un comando sale con un código distinto de 0 |
| `-u` | `nounset` | Aborta cuando se usa una variable que no existe |
| `-o pipefail` | — | El código de una tubería es el del último comando que falló, no el del último comando |

Sin `pipefail`, `curl ... | jq .` sale con el código de `jq`, y un `-e` no ve
un curl caído (teoría 01). Las tres juntas son la red mínima; ninguna basta
sola.

### 2.2 Dónde `-e` no mira

`-e` se desactiva en cualquier comando cuyo resultado **ya se está
comprobando**: la condición de un `if` o un `while`, cualquier parte de un
`&&` o un `||` salvo la última, y lo que va detrás de un `!`. La idea es
razonable (si lo compruebas tú, no aborto yo) y tiene una consecuencia que
sorprende:

```bash
set -e
f() { false; echo "f sigue"; }

if f; then echo "si"; fi
# f sigue
# si
```

El `false` dentro de `f` **no aborta** porque `f` se está evaluando en un
`if`. Lo mismo con `f || echo fallo` y `f && echo ok`. Una función que confía
en `-e` para parar en su primer fallo deja de hacerlo en cuanto alguien la
llama desde un `if`.

La regla práctica: dentro de una función, comprueba lo importante de forma
explícita (`|| return 1`, `|| error ...`) en vez de fiarlo todo a `-e`.

### 2.3 `local x=$(...)` se traga el fallo

```bash
set -e
f() { local x=$(false); echo "f sigue"; }
f
# f sigue
```

El código que mira `-e` es el de `local`, que siempre es 0. El de la
sustitución se pierde. Con `x=$(false)` sin `local`, el script sí aborta.
La solución es separarlo en dos líneas:

```bash
f() {
  local x
  x=$(false)        # aqui si aborta
}
```

`shellcheck` avisa de esto (SC2155). Es una de las razones para pasarlo antes
de cada entrega.

### 2.4 Dentro de `$(...)`, `-e` no se hereda

```bash
set -e
x=$(false; echo "sigue")
echo "[$x]"
# [sigue]
```

La sustitución corre en un subshell, y en bash ese subshell **no hereda** el
`-e` a menos que actives `shopt -s inherit_errexit` (bash 4.4+). Si la
sustitución es un solo comando, como `$(curl ...)`, da igual: el código de la
asignación es el de ese comando. El problema aparece con varios comandos
dentro.

### 2.5 `pipefail` y el aborto falso

```bash
set -eo pipefail
curl -sS http://localhost:8080/bytes/200000 | head -c 5 > /dev/null
# curl: (23) Failure writing output to destination
echo $?
# 23
```

`head` lee cinco bytes y termina. curl, que aún tenía 200 KB por escribir,
se encuentra la tubería cerrada, falla con 23, y `pipefail` convierte eso en
un fallo de toda la línea. **No ha fallado nada que importe**, y el script
aborta.

Pasa con `head`, con `grep -q` (que termina en la primera coincidencia) y con
cualquier comando que deje de leer antes de tiempo. Se evita sin tocar
`pipefail`: pide menos (`--range`, un endpoint con límite) o guarda la
respuesta en un archivo y aplica `head` al archivo.

---

## 3. Cómo se usa

### 3.1 Recoger el código de curl con `-e` activo

```bash
set -euo pipefail

# Mal: con -e, el script aborta en curl y rc nunca se asigna
curl -sS --max-time 5 http://127.0.0.1:9/
rc=$?

# Bien: el || hace que -e no aborte, y rc recibe el codigo
rc=0
curl -sS --max-time 5 http://127.0.0.1:9/ || rc=$?
echo "curl salio con $rc"
# curl salio con 7
```

El `rc=0` delante no es decoración: sin él, si curl sale con 0, `rc` no
existe y el `-u` aborta en el `echo`.

Con una sustitución:

```bash
rc=0
codigo=$(curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:9/) || rc=$?
```

Es exactamente el patrón de `lanzar_curl` y `peticion` en el toolkit.

### 3.2 `-u` y las variables opcionales

```bash
set -u
echo "$API_TOKEN"            # aborta si no existe
echo "${API_TOKEN:-}"        # cadena vacia si no existe
BASE_URL="${BASE_URL:-http://localhost:8080}"   # valor por defecto
```

Los argumentos de una función también son variables: `$1` sin argumento
aborta con `-u`. Para uno opcional, `${1:-}`.

### 3.3 Limpiar al salir: `trap ... EXIT`

```bash
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

curl -sS --fail-with-body --max-time 10 -o "$tmp" http://localhost:8080/get
jq .url "$tmp"
```

El `trap` se ejecuta al salir **por cualquier motivo**: final normal, `exit`, o
un aborto de `-e`. Es la forma de que un temporal con una respuesta (que
puede llevar datos personales o un token) no se quede en `/tmp`. El toolkit lo
hace en `limpiar`.

### 3.4 Saber dónde abortó

Un `-e` aborta en silencio: el script termina con el código del comando que
falló, sin decir cuál era. Mientras depuras:

```bash
trap 'echo "fallo en la linea $LINENO: $BASH_COMMAND" >&2' ERR
```

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `curl ...; rc=$?` con `-e` | El script aborta antes de asignar `rc` | `rc=0; curl ... \|\| rc=$?` |
| `local x=$(curl ...)` | El fallo de curl desaparece | `local x` y `x=$(curl ...)` en dos líneas |
| Fiar a `-e` el control de errores de una función | Deja de funcionar cuando la llaman desde un `if` | `\|\| return 1` en lo que importa |
| `set +e` para "dejar pasar" un comando | Se olvida volver a `set -e` y el resto del script queda sin red | `cmd \|\| true`, o `\|\| rc=$?` |
| `curl URL \| head -1` con `pipefail` | Aborto falso con 23 | Guardar en un archivo y aplicar `head` al archivo |
| `$API_TOKEN` sin valor por defecto en un script con `-u` | Aborto con un mensaje que no dice qué falta | `${API_TOKEN:-}` y un error explícito |

---

## 5. Trucos

- **`bash -x script.sh`** imprime cada comando antes de ejecutarlo. Con `-e`,
  la última línea es la que falló. Cuidado: imprime también los valores, y
  con ellos cualquier token.
- **`shellcheck`** detecta `local x=$(...)` (SC2155), variables sin comillas y
  la mayoría de los usos peligrosos de `$?`.
- **`|| true`** al final de un comando que puede fallar sin que importe (un
  `grep` que no encuentra nada) es explícito: quien lo lee sabe que es
  intencionado.

---

## 📚 Recursos Adicionales

- [Bash Reference Manual — The Set Builtin](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html)
- [BashFAQ/105 — Why doesn't set -e do what I expected?](https://mywiki.wooledge.org/BashFAQ/105)
- [ShellCheck SC2155](https://www.shellcheck.net/wiki/SC2155)

---

## ✅ Checklist de Verificación

- [ ] Explicas qué vigila cada una de las tres opciones
- [ ] Reproduces el `if f` que no aborta y el `local x=$(false)`
- [ ] Recoges el código de curl con `|| rc=$?` en un script con `-e`
- [ ] Reproduces el 23 de `curl | head` y sabes evitarlo
- [ ] Tus scripts limpian sus temporales con `trap ... EXIT`
