# Documentar una CLI

> La documentación de una herramienta de terminal vive en tres sitios: lo
> que imprime `--help`, el `README` del repositorio y la lista de cambios
> entre versiones. Cada uno responde a una pregunta distinta, y cada uno
> miente en cuanto el código cambia y él no. Esta teoría reparte qué va en
> cada sitio y cómo conseguir que la ayuda no se quede atrás.

![Tres documentos y la pregunta que responde cada uno. --help, generado desde la cabecera del propio script, responde cómo se usa ahora: subcomandos, flags, variables y códigos de salida. El README responde qué es, cómo se instala y cómo se empieza, con un ejemplo de cinco líneas. El CHANGELOG responde qué cambió entre versiones, agrupado en Añadido, Cambiado y Corregido. Una flecha marca la versión: --version, el User-Agent y la etiqueta git v1.0.0 dicen lo mismo](../0-assets/06-documentar-una-cli.svg)

## 🎯 Objetivos

- Repartir la documentación entre `--help`, el `README` y el `CHANGELOG`
- Seguir las convenciones de `--help` y `--version`: canal, código de salida y formato
- Mantener la ayuda en el mismo archivo que el código
- Documentar los códigos de salida como parte de la interfaz
- Versionar con semver y marcar la versión con una etiqueta de git

---

## 1. Qué problema resuelve

Tres preguntas que se hace quien llega al toolkit, en este orden:

1. **¿Qué es y cómo lo instalo?** Lo busca en el `README`, en el navegador,
   antes de clonar nada.
2. **¿Cómo hago X?** Lo busca en `api-toolkit --help`, en la terminal, con
   el toolkit ya instalado.
3. **¿Qué ha cambiado desde la versión que tenía?** Lo busca en el
   `CHANGELOG`, cuando actualiza.

Meterlo todo en el `README` hace que la terminal no tenga respuesta. Meterlo
todo en `--help` hace una ayuda de diez pantallas. Y sin `CHANGELOG`, la
única forma de saber qué cambió es leer el `git log`.

---

## 2. Cómo funciona

### 2.1 `--help`: la referencia, junto al código

Desde la Semana 01, la ayuda del toolkit es su **cabecera**: los comentarios
del principio del archivo. `uso()` los imprime quitando el `# `:

```bash
uso() {
  awk 'NR > 2 && /^#/ { sub(/^# ?/, ""); print; next } NR > 2 { exit }' "${BASH_SOURCE[0]}"
}
```

La ventaja es que la ayuda y el código están **en el mismo archivo**: quien
añade un subcomando ve la lista justo encima. Las convenciones:

| Situación | Canal | Código de salida |
|---|---|---|
| `--help` pedido | stdout | 0 |
| Error de uso (faltan argumentos, flag desconocido) | stderr, con la ayuda o una pista | 1 (algunas CLI usan 2) |

`--help` va a stdout porque es lo que se pidió: `api-toolkit --help | less`
y `| grep` tienen que funcionar. Un error de uso va a stderr porque no es
el dato de nadie.

Qué tiene que estar, como mínimo: la sintaxis, cada subcomando en su línea,
cada flag, cada variable de entorno con su valor por defecto, y los códigos
de salida.

### 2.2 `--version`

```bash
api-toolkit --version
# api-toolkit 1.0.0
```

- Una línea, a stdout, código 0. Nombre y versión: es lo que pega quien abre
  un issue.
- Sale de la misma constante que el User-Agent (`VERSION`, desde la Semana
  06): en los logs de la API y en la terminal se lee la misma versión.

### 2.3 Los códigos de salida son documentación

Para un script que llama al toolkit, el código de salida es la única forma
de saber qué pasó. La teoría 08 de la Semana 07 la dejó en `--help`, y no
en un `README` aparte, porque el toolkit aún no era un repositorio que
alguien abriera. Ahora lo es: la tabla va en `--help` y **también** en el
`README`, que es lo primero que ve quien decide si lo usa. Y no cambia sin
cambiar la versión mayor:

| Código | Significa | Qué hace quien llama |
|---|---|---|
| 0 | La API respondió 2xx o 3xx | Seguir |
| 1 | Error de uso o 4xx/5xx definitivo | No repetir: arreglar algo |
| 69 | No hubo respuesta HTTP | Revisar la red, el DNS o el TLS |
| 75 | Fallo temporal: 429, 502, 503, 504 | Repetir más tarde |
| 77 | 401 o 403 | Revisar la credencial |

### 2.4 El `README` del proyecto

Es lo que se ve al abrir el repositorio. Las secciones que necesita, y
ninguna más:

1. **Qué es**, en una frase.
2. **Requisitos**: bash, curl 7.81 o posterior, jq.
3. **Instalar**: `./install.sh`, y qué hacer si `~/.local/bin` no está en el
   PATH.
4. **Empezar**: `init`, editar el archivo, la primera petición. Cinco líneas.
5. **Configuración**: la precedencia y una tabla de variables, o un "ver
   `--help`".
6. **Códigos de salida**: la tabla de arriba.
7. **Desarrollo**: cómo lanzar los tests y shellcheck.

Lo que no va: la lista entera de flags copiada de `--help`. Dos copias de lo
mismo dejan de coincidir al primer cambio. El `README` enseña a empezar y
remite a `--help` para el detalle.

### 2.5 `CHANGELOG.md`

Una entrada por versión, la más nueva arriba, agrupada por tipo de cambio
(el formato de *Keep a Changelog*):

```markdown
## [1.0.0] - 2026-11-12

### Añadido
- `init` crea `~/.bc-curl` con permisos 600 y sin pisar uno existente.
- `--version`.
- `install.sh`, tests con bats y CI.

### Cambiado
- `BASE_URL`, `AUTH_MODE` y `API_CACERT` también se leen de `~/.bc-curl`.
```

Se escribe para personas: "qué cambia para mí", no la lista de commits.

### 2.6 Semver y la etiqueta de git

La versión vive en `VERSION`, en el `CHANGELOG` y en una **etiqueta** de
git que marca el commit exacto:

```bash
git tag -a v1.0.0 -m "api-toolkit 1.0.0"
git push origin v1.0.0
```

Con la etiqueta, `git checkout v1.0.0` reproduce exactamente lo que se
entregó, y GitHub la lista como versión.

---

## 3. Cómo se usa

```bash
api-toolkit --help | sed -n '/^Subcomandos:/,/^$/p' | head -5
# Subcomandos:
#   init                        Crea BC_CURL_FILE con BASE_URL y AUTH_MODE (los
#                               del entorno, o los de por defecto) y las claves
#                               de los secretos comentadas. Nunca pisa uno que
#                               ya existe, ni escribe un secreto

api-toolkit --help > /dev/null; echo $?
# 0
api-toolkit > /dev/null; echo $?
# ... (la ayuda entera, por stderr)
# error: faltan argumentos
# 1
```

Sin argumentos, la ayuda va a stderr: con `> /dev/null` aún se ve, y el
código es 1.

---

## 4. Antipatrones

- **`--help` que sale con 1** o que escribe en stderr: `api-toolkit --help | less` no enseña nada.
- **La ayuda en un archivo aparte** que nadie actualiza al añadir un flag.
- **El `README` como copia de `--help`.** Dos fuentes, y una se queda atrás.
- **Un `CHANGELOG` que es el `git log`.** "fix typo" no le dice nada a quien
  actualiza.
- **Cambiar un código de salida en una versión menor.** Rompe los scripts
  que lo comprobaban, y semver dice que eso es una versión mayor.
- **La versión escrita en tres sitios a mano.** `--version` y el User-Agent
  salen de la misma constante.

---

## 5. Trucos

- **Comprobar que la ayuda lista todos los subcomandos**: un bucle con
  `grep -qE "^  $s "` por cada uno; es lo que hace el check `ayuda-completa`.
- **Ver la ayuda con paginador** solo si hace falta:
  `api-toolkit --help | less -F` sale solo si cabe en una pantalla.
- **Generar una página `man` desde `--help`**: `help2man` lo hace, si algún
  día la ayuda deja de caber en la terminal.
- **Fecha para el `CHANGELOG`**: `date +%F` da `AAAA-MM-DD`, el formato que
  pide *Keep a Changelog*.

---

## 📚 Recursos Adicionales

- [Command Line Interface Guidelines — Help](https://clig.dev/#help)
- [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
- [GNU Coding Standards — `--help` y `--version`](https://www.gnu.org/prep/standards/html_node/Command_002dLine-Interfaces.html)

---

## ✅ Checklist de Verificación

- [ ] Sabes qué pregunta responde `--help`, cuál el `README` y cuál el `CHANGELOG`
- [ ] `--help` va a stdout con 0, y un error de uso a stderr con 1
- [ ] `--version` imprime una línea con nombre y versión
- [ ] La tabla de códigos de salida está en `--help` y en el `README`
- [ ] Marcas una versión con `git tag -a` y la empujas
