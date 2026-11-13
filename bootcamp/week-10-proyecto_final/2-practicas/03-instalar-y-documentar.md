# Práctica 03 — Instalar y documentar

> **Duración**: 50 min · **Entregables**: `instalacion.md` y tu repositorio `api-toolkit/` con `README.md` y `CHANGELOG.md`

Vas a escribir el instalador (TODO 5), probarlo primero en una carpeta de
usar y tirar y después de verdad en `~/.local/bin`, y comprobar que
desinstalar no se lleva tu configuración. Después montas el repositorio que
vas a entregar: los archivos del starter, un `README` con las secciones que
necesita, un `CHANGELOG` y la etiqueta `v1.0.0`.

**Antes de empezar**, desde la raíz del repositorio, con las prácticas 01 y
02 terminadas:

```bash
export ST="$PWD/bootcamp/week-10-proyecto_final/3-proyecto/starter"
mkdir -p ~/bc-curl-trabajo/semana-10/p3 && cd ~/bc-curl-trabajo/semana-10/p3
bash
```

En las salidas de ejemplo, tu HOME aparece como `/home/ana`.

---

## Paso 1: Dónde busca el shell

**Por qué**: un comando "existe" si está en una carpeta del `PATH` y es
ejecutable. Antes de instalar, mira si `~/.local/bin` está en el tuyo
(teoría 07, apartado 2.1).

**Comando**:

```bash
echo "$PATH" | tr ':' '\n' | grep -n '\.local/bin'
command -v api-toolkit; echo "salida: $?"
```

**Verifica**:

```bash
# 1:/home/ana/.local/bin
# salida: 1
```

Si la primera línea no sale, `~/.local/bin` no está en tu PATH: en Ubuntu,
el `~/.profile` la añade al iniciar sesión **si la carpeta existe**. La
creará el instalador; el paso 3 te dirá qué hacer. `command -v` no
encuentra nada todavía.

---

## Paso 2: El instalador (TODO 5)

**Por qué**: instalar es copiar con los permisos correctos, comprobar que
la copia arranca y avisar de lo que falta. Primero en una carpeta temporal,
para no tocar nada (teoría 07, apartados 2.2 a 2.4).

**Comando**: mira primero el starter:

```bash
P="$(mktemp -d)"
PREFIX="$P" "$ST/install.sh"; echo "salida: $?"
```

Después, sustituye los dos TODO 5 de `install.sh`:

```bash
instalar() {
  [ -f "$ORIGEN" ] || error "no encuentro $ORIGEN"

  install -d "${PREFIX}/bin"
  install -m 755 "$ORIGEN" "$DESTINO"

  "$DESTINO" --version > /dev/null || error "$DESTINO no arranca"
  echo "instalado: $DESTINO ($("$DESTINO" --version))"

  case ":${PATH}:" in
    *":${PREFIX}/bin:"*) ;;
    *)
      echo "aviso: ${PREFIX}/bin no esta en el PATH. Anade a tu ~/.bashrc o ~/.zshrc:" >&2
      echo "  export PATH=\"${PREFIX}/bin:\$PATH\"" >&2
      ;;
  esac
}

desinstalar() {
  rm -f "$DESTINO"
  echo "desinstalado: $DESTINO"
}
```

Y repite:

```bash
PREFIX="$P" "$ST/install.sh"
ls -l "$P/bin/api-toolkit" | cut -c1-10
```

**Verifica**:

```bash
# error: instalar todavia no esta hecho
# salida: 1
# instalado: /tmp/tmp.wtwiGyDfH2/bin/api-toolkit (api-toolkit 1.0.0)
# aviso: /tmp/tmp.wtwiGyDfH2/bin no esta en el PATH. Anade a tu ~/.bashrc o ~/.zshrc:
#   export PATH="/tmp/tmp.wtwiGyDfH2/bin:$PATH"
# -rwxr-xr-x
```

El aviso es correcto: una carpeta temporal no está en el PATH. Es un aviso,
no un error: el archivo se instaló.

---

## Paso 3: Instalar de verdad

**Por qué**: con el `PREFIX` por defecto, `~/.local/bin`, no hace falta
`sudo`. Y el instalador tiene que funcionar lances desde donde lo lances
(teoría 07, apartado 2.3).

**Comando**:

```bash
"$ST/install.sh"
command -v api-toolkit
cd /tmp && api-toolkit --version
cd / && "$ST/install.sh" | tail -1
cd ~/bc-curl-trabajo/semana-10/p3
```

**Verifica**:

```bash
# instalado: /home/ana/.local/bin/api-toolkit (api-toolkit 1.0.0)
# /home/ana/.local/bin/api-toolkit
# api-toolkit 1.0.0
# instalado: /home/ana/.local/bin/api-toolkit (api-toolkit 1.0.0)
```

Desde `/`, el instalador encontró `api-toolkit.sh` a su lado, no en el
directorio actual. Si en la primera línea te sale el aviso del PATH, añade
la línea `export` que te da a tu `~/.bashrc` (o `~/.zshrc`) y abre otra
terminal.

---

## Paso 4: `install` frente a `cp`

**Por qué**: `cp` copia los permisos del origen; `install -m` los fija. Un
origen que perdió el bit de ejecución da una copia que no arranca (teoría
07, apartado 2.2).

**Comando**:

```bash
cp "$ST/api-toolkit.sh" origen.sh && chmod 644 origen.sh
cp origen.sh copia-cp
install -m 755 origen.sh copia-install
ls -l copia-cp copia-install | cut -c1-10
```

**Verifica**:

```bash
# -rw-r--r--
# -rwxr-xr-x
```

La copia de `cp` no se puede ejecutar. Hay otra diferencia que no se ve con
`ls`: `install` sustituye el archivo por uno nuevo, y `cp` escribe dentro
del que había; un proceso que estaba ejecutando la versión vieja la sigue
leyendo entera con `install`, pero no con `cp`.

---

## Paso 5: Desinstalar sin borrar lo tuyo

**Por qué**: `~/.bc-curl` y la sesión OAuth2 son del usuario, no del
programa. Y bash recuerda dónde encontró cada comando (teoría 07,
apartados 2.5 y 5).

**Comando**:

```bash
"$ST/install.sh" uninstall
command -v api-toolkit; echo "salida: $?"
hash -r
command -v api-toolkit; echo "salida: $?"
ls -l ~/.bc-curl 2>/dev/null | cut -c1-10
"$ST/install.sh" > /dev/null    # vuelve a instalarlo para el resto de la semana
```

**Verifica**:

```bash
# desinstalado: /home/ana/.local/bin/api-toolkit
# /home/ana/.local/bin/api-toolkit
# salida: 0
# salida: 1
# -rw-------
```

Después de desinstalar, `command -v` aún da la ruta: bash la apuntó la
primera vez que ejecutaste `api-toolkit` en esta terminal. `hash -r` la
olvida. Tu `~/.bc-curl` (si lo tienes) sigue ahí. Si no tienes, la última
línea no imprime nada.

---

## Paso 6: La ayuda dice la verdad

**Por qué**: `--help` es la referencia en la terminal. El check
`ayuda-completa` comprueba que cada subcomando tiene su línea, y la tabla de
códigos de salida es parte de la interfaz (teoría 06, apartados 2.1 y 2.3).

**Comando**:

```bash
for s in init get post put delete download upload fetch-all auth bench; do
  api-toolkit --help | grep -qE "^  $s " || echo "falta $s"
done; echo fin
api-toolkit --help | sed -n '/^Codigos de salida:/,/^$/p' | grep -E '^  [0-9]+ '
```

**Verifica**:

```bash
# fin
#   0   la API respondio 2xx o 3xx (y en download, el archivo esta completo)
#   1   error de uso, archivo inexistente, hash que no coincide, la API
#   75  fallo temporal (EX_TEMPFAIL): la API respondio 429, 502, 503 o 504
#   77  la API respondio 401 o 403 (EX_NOPERM), con OAuth2 incluso despues
#   69  no hubo respuesta HTTP: DNS, conexion, timeout, TLS o demasiados
```

Ningún `falta`. Esa tabla es la que copiarás al `README`.

---

## Paso 7: Tu repositorio y su `README`

**Por qué**: lo que entregas es un repositorio que otra persona clona. El
`README` responde qué es, cómo se instala y cómo se empieza, y remite a
`--help` para el detalle (teoría 06, apartado 2.4).

**Comando**:

```bash
mkdir -p ~/bc-curl-trabajo/api-toolkit && cd ~/bc-curl-trabajo/api-toolkit
cp -a "$ST/api-toolkit.sh" "$ST/install.sh" "$ST/tests" "$ST/.github" .
git init -q
```

Escribe `README.md` con estas siete secciones, en este orden: **qué es**
(una frase), **requisitos** (bash, curl 7.81 o posterior, jq),
**instalar** (`./install.sh`, y qué hacer con el aviso del PATH),
**empezar** (`init`, editar `~/.bc-curl`, la primera petición, cinco
líneas), **configuración** (la precedencia y un "ver `--help`"), **códigos
de salida** (la tabla del paso 6) y **desarrollo** (`shellcheck` y
`bats tests/`). Después:

```bash
grep -c '^## ' README.md
ls -A
```

**Verifica**:

```bash
# 7
# .git  .github  README.md  api-toolkit.sh  install.sh  tests
```

Siete secciones de segundo nivel, y `.github` copiado: `cp -a` incluye las
carpetas ocultas si las nombras.

---

## Paso 8: `CHANGELOG`, commit y etiqueta

**Por qué**: la versión vive en `VERSION`, en el `CHANGELOG` y en una
etiqueta de git que marca el commit exacto que se entregó (teoría 06,
apartados 2.5 y 2.6).

**Comando**: escribe `CHANGELOG.md` con una entrada `## [1.0.0] - AAAA-MM-DD`
(la fecha de `date +%F`) y sus grupos *Añadido* y *Cambiado*, como en la
teoría 06. Después:

```bash
git add -A && git commit -qm "api-toolkit 1.0.0"
git tag -a v1.0.0 -m "api-toolkit 1.0.0"
git tag -n
git describe --tags
```

**Verifica**:

```bash
# v1.0.0          api-toolkit 1.0.0
# v1.0.0
```

`git describe` dice en qué versión está el commit actual; tras el siguiente
commit dirá `v1.0.0-1-g` y un hash. Apunta en `instalacion.md` lo que hiciste
en cada paso.

---

## ✅ Resultado

- [ ] Mi `install.sh` (TODO 5) instala con 755, comprueba que arranca y avisa del PATH
- [ ] `api-toolkit --version` funciona desde cualquier carpeta
- [ ] `uninstall` borra el ejecutable y deja `~/.bc-curl`
- [ ] Sé por qué `command -v` recuerda un comando borrado
- [ ] Mi repositorio tiene `README.md` con siete secciones, `CHANGELOG.md` y la etiqueta `v1.0.0`

Desde la raíz del repositorio del bootcamp:

```bash
./scripts/verificar-semana.sh 10
```

Esta práctica cierra el TODO 5: pasan `instalar` y `ayuda-completa`.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| `install: cannot create regular file ... Permission denied` | `PREFIX` del sistema sin `sudo` | `~/.local` no lo necesita; para `/usr/local`, `sudo PREFIX=/usr/local ./install.sh` |
| `api-toolkit: command not found` tras instalar | `~/.local/bin` no está en el PATH | La línea `export` del aviso, en tu `~/.bashrc`, y otra terminal |
| `no encuentro .../api-toolkit.sh` | `ORIGEN` se calcula desde el directorio actual | `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` |
| `install: illegal option -- D` en macOS | `install -D` es de GNU | `install -d` para la carpeta y `install -m 755` para el archivo |
| El paso 5 da `salida: 1` también antes de `hash -r` | En esa terminal no habías ejecutado `api-toolkit` | Normal: bash solo recuerda lo que ejecutó |
| `grep -c '^## '` da otro número | Secciones con `#` o `###` | Las siete con `## ` |
| `git commit` falla con `Please tell me who you are` | git sin nombre ni correo en esta máquina | `git config --global user.name ...` y `user.email`, y repite |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 02 — Tests con bats](02-tests-con-bats.md) | [Práctica 04 — Integración continua](04-integracion-continua.md) |
