# Instalar y desinstalar

> Instalar un programa de bash es copiar un archivo a una carpeta del PATH.
> Lo difícil es todo lo demás: qué carpeta, con qué permisos, sin `sudo` si
> no hace falta, qué pasa si la carpeta no está en el PATH, cómo comprobar
> que la copia arranca, y cómo quitarlo sin llevarse por delante la
> configuración de nadie. Y, sobre todo, por qué el instalador nunca debería
> ser un `curl | bash`.

![El recorrido de install.sh. Desde la carpeta del repositorio, api-toolkit.sh se copia con install -m 755 a PREFIX/bin/api-toolkit, que por defecto es ~/.local/bin y no necesita sudo. Después, la copia instalada se ejecuta con --version para comprobar que arranca, y se avisa si PREFIX/bin no está en el PATH. uninstall borra solo ese archivo: ~/.bc-curl y la sesión OAuth2 se quedan, porque son del usuario. Aparte, tachado, curl URL | bash](../0-assets/07-instalar-y-desinstalar.svg)

## 🎯 Objetivos

- Elegir dónde instalar con `PREFIX`, y cuándo hace falta `sudo`
- Copiar con `install` en lugar de `cp`, y saber por qué
- Comprobar que lo instalado arranca, y avisar si no está en el PATH
- Desinstalar sin borrar los datos del usuario
- Explicar el riesgo de `curl | bash` y la alternativa verificable

---

## 1. Qué problema resuelve

Hasta ahora el toolkit se ejecutaba con su ruta:
`~/bc-curl/bootcamp/week-09-.../starter/api-toolkit.sh get /get`. Para que
sea un comando más, `api-toolkit get /get`, tiene que estar en una carpeta
del `PATH` y ser ejecutable. Las decisiones:

1. **¿Qué carpeta?** `/usr/local/bin` necesita `sudo`; `~/.local/bin` no.
2. **¿Copiar o enlazar?** Un enlace simbólico al repositorio se rompe si
   mueves el repositorio, y cualquier `git checkout` cambia lo instalado.
3. **¿Y si la carpeta no está en el PATH?** El comando "no existe", y nadie
   sabe por qué.
4. **¿Cómo se quita?** Y sin borrar `~/.bc-curl`, que es del usuario.

---

## 2. Cómo funciona

### 2.1 `PREFIX`: dónde

La convención Unix: un **prefijo** y, debajo, `bin/` para los ejecutables.

| `PREFIX` | Ejecutable | ¿`sudo`? | Para quién |
|---|---|:--:|---|
| `~/.local` (por defecto) | `~/.local/bin/api-toolkit` | No | Tu cuenta |
| `/usr/local` | `/usr/local/bin/api-toolkit` | Sí | Todas las cuentas |
| `/opt/api-toolkit` | `/opt/api-toolkit/bin/api-toolkit` | Sí | Aislado, fácil de borrar |

```bash
./install.sh                                  # ~/.local/bin
sudo PREFIX=/usr/local ./install.sh           # para todos
```

`~/.local/bin` es la carpeta de la especificación XDG para ejecutables del
usuario. En Ubuntu, el `~/.profile` la añade al PATH si existe al iniciar
sesión; en macOS, no.

### 2.2 `install` en lugar de `cp`

```bash
install -d "${PREFIX}/bin"
install -m 755 "$ORIGEN" "$DESTINO"
```

- `install -d` crea la carpeta, como `mkdir -p`.
- `install -m 755` copia y **fija** los permisos. `cp` conservaría los del
  origen: si en tu repositorio perdiste el bit de ejecución, la copia
  tampoco lo tendría.
- Si el destino existe, `install` lo sustituye por uno nuevo en vez de
  escribir encima. Un proceso que está ejecutando la versión vieja no ve
  cambiar el archivo bajo sus pies.

`install -D` (crear la carpeta y copiar en un paso) es de GNU: en macOS no
existe. Dos llamadas funcionan en los dos.

### 2.3 Encontrar el origen

```bash
ORIGEN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/api-toolkit.sh"
```

El origen se busca **al lado del instalador**, no en el directorio actual:
`./install.sh` y `cd /tmp && ~/api-toolkit/install.sh` instalan lo mismo.

### 2.4 Comprobar, y avisar del PATH

```bash
"$DESTINO" --version > /dev/null || error "$DESTINO no arranca"

case ":${PATH}:" in
  *":${PREFIX}/bin:"*) ;;
  *) echo "aviso: ${PREFIX}/bin no esta en el PATH ..." >&2 ;;
esac
```

- Ejecutar la copia instalada detecta un `PREFIX` sin permiso de ejecución
  (una partición montada con `noexec`) o un archivo truncado.
- Los `:` a los lados evitan que `/usr/local/bin` case dentro de
  `/usr/local/bin2`, y cubren la primera y la última entrada del PATH.
- Es un **aviso**, no un error: el archivo está instalado, solo falta
  decirle al shell dónde mirar.

### 2.5 Desinstalar

```bash
rm -f "$DESTINO"
```

Solo el ejecutable. `~/.bc-curl`, la sesión OAuth2 y la caché son **del
usuario**: puede querer reinstalar mañana, u otra versión. Un desinstalador
que borra la configuración destruye un token que costó conseguir.

### 2.6 `curl | bash`

Muchos proyectos se instalan así:

```bash
curl -fsSL https://ejemplo.dev/install.sh | bash      # NO
```

Ejecuta lo que el servidor mande **en ese momento**, sin que nadie lo haya
leído. Si el servidor está comprometido, o la conexión se corta a media
línea (bash ejecuta lo que ha llegado), pasa en tu máquina. La alternativa
es descargar, mirar y verificar antes de ejecutar:

```bash
curl -fsSL --max-time 30 -o install.sh https://ejemplo.dev/v1.0.0/install.sh
less install.sh
sha256sum install.sh        # contra el hash publicado en la página de la versión
bash install.sh
```

El toolkit ni siquiera necesita eso: se instala desde un `git clone` que ya
tienes delante y puedes leer.

---

## 3. Cómo se usa

```bash
./install.sh
# instalado: /home/ana/.local/bin/api-toolkit (api-toolkit 1.0.0)

command -v api-toolkit
# /home/ana/.local/bin/api-toolkit

cd /tmp && api-toolkit --version
# api-toolkit 1.0.0

~/api-toolkit/install.sh uninstall
# desinstalado: /home/ana/.local/bin/api-toolkit
ls ~/.bc-curl
# /home/ana/.bc-curl
```

---

## 4. Antipatrones

- **`sudo` por costumbre.** Para tu cuenta, `~/.local/bin` basta, y un error
  en el instalador no puede tocar el sistema.
- **`cp` sin fijar permisos.** La copia hereda lo que tuviera el origen.
- **Enlazar al repositorio de trabajo.** Cada `git checkout` cambia lo que
  ejecutan tus crons.
- **Buscar el origen en el directorio actual.** El instalador funciona solo
  si lo lanzas desde su carpeta.
- **Un desinstalador que borra la configuración.** Los datos del usuario no
  son del programa.
- **`curl | bash`** sin leer ni verificar lo que se ejecuta.
- **Tocar el `~/.bashrc` del usuario** para añadir el PATH. Se avisa, y la
  persona decide.

---

## 5. Trucos

- **¿Qué versión se ejecuta?** `command -v api-toolkit` dice cuál encuentra
  el shell; `type -a api-toolkit` las lista todas, en orden del PATH.
- **Después de instalar**, si el shell dice que no existe: `hash -r` olvida
  las rutas que bash tenía apuntadas.
- **Probar el instalador sin tocar nada**:
  `PREFIX="$(mktemp -d)" ./install.sh`. Es lo que hace el check `instalar`.
- **Añadir `~/.local/bin` al PATH**, si no está:
  `echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc` y abre otra
  terminal.

---

## 📚 Recursos Adicionales

- [install(1) — GNU coreutils](https://www.gnu.org/software/coreutils/manual/html_node/install-invocation.html)
- [XDG Base Directory Specification — `~/.local/bin`](https://specifications.freedesktop.org/basedir-spec/latest/)
- [Command Line Interface Guidelines — Distribution](https://clig.dev/#distribution)

---

## ✅ Checklist de Verificación

- [ ] Instalas con `PREFIX` sin `sudo` y sabes cuándo hace falta
- [ ] Explicas por qué `install -m 755` y no `cp`
- [ ] Compruebas que la copia arranca y avisas si no está en el PATH
- [ ] Desinstalas sin tocar `~/.bc-curl`
- [ ] Explicas qué riesgo tiene `curl | bash` y cómo se descarga y verifica
