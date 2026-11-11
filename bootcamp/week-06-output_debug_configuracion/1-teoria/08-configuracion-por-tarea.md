# Configuración por tarea

> El `.curlrc` es la configuración de una persona; un archivo `-K` es la de
> una tarea. Lo llamas tú, explícitamente, cuando lo necesitas, y puede llevar
> lo que el `.curlrc` nunca debería: la credencial, el destino, el formato de
> la salida.

![Diagrama de cómo curl compone la configuración de un comando: primero el .curlrc si no hay -q, después cada argumento de la línea de comandos en orden, y cada -K se expande en su sitio como si sus líneas estuvieran escritas ahí; -K - lee de stdin, de modo que una credencial puede llegar por un pipe desde printf sin aparecer en la lista de procesos ni en el disco](../0-assets/08-configuracion-por-tarea.svg)

## 🎯 Objetivos

- Usar `-K archivo` para agrupar las opciones de una tarea
- Predecir qué gana cuando un `-K` y el comando dicen cosas distintas
- Pasar una credencial con `-K -` sin que toque el disco ni salga en `ps`
- Lanzar varias peticiones desde un solo archivo
- Conocer `--variable` (8.3+) y saber qué usar en su lugar en 7.81

---

## 1. Qué problema resuelve

Hay tareas que repites con las mismas quince opciones: el informe diario contra
la API de facturación, la comprobación de salud de los tres entornos. Ponerlas
en el `.curlrc` las aplicaría a todo lo demás que hagas con curl. Ponerlas en
un alias no vale para un script. Copiarlas en cada script las desincroniza.

Y luego está la credencial. La Semana 03 enseñó que en la línea de comandos se
ve en `ps` y en el historial. Pero en algún sitio tiene que estar.

`-K` resuelve las dos cosas.

---

## 2. Cómo funciona

### 2.1 `-K`: el archivo se expande en su sitio

`-K archivo` (`--config`) lee opciones de un archivo con la **misma sintaxis
que el `.curlrc`** (teoría 07). La diferencia es que lo pides tú, y que sus
líneas se aplican **en la posición donde está el `-K`**, como si las hubieras
escrito ahí.

```bash
printf 'max-time = 1\n' > tarea.cfg

curl -q -s -o /dev/null -w '%{exitcode}\n' --max-time 5 -K tarea.cfg http://localhost:8080/delay/2
# 28           ← el -K va despues: su max-time 1 gana
curl -q -s -o /dev/null -w '%{exitcode}\n' -K tarea.cfg --max-time 5 http://localhost:8080/delay/2
# 0            ← el --max-time 5 va despues: gana el
```

Las reglas de la teoría 07 siguen valiendo: las opciones de valor único las
gana la última, las acumulativas como `-H` se suman. Se pueden poner varios
`-K` en el mismo comando, y el `.curlrc` se sigue leyendo antes de todo salvo
que haya un `-q` delante.

### 2.2 `-K -`: desde stdin

Con `-` como nombre, curl lee la configuración de stdin. Es la pieza que
faltaba para la credencial:

```bash
export API_TOKEN=token-de-prueba     # en la vida real, de un gestor de secretos

printf 'header = "Authorization: Bearer %s"\n' "$API_TOKEN" \
  | curl -q -sS -K - http://localhost:8080/bearer
# {
#   "authenticated": true,
#   "token": "token-de-prueba"
# }
```

Por qué es seguro:

| Dónde podría verse el token | ¿Se ve? | Por qué |
|---|:--:|---|
| `ps` / `/proc/*/cmdline` | ❌ | `printf` es un builtin de bash: no es un proceso con argumentos. curl solo tiene `-K -` |
| El historial del shell | ❌ | Solo queda `"$API_TOKEN"`, la variable, no su valor |
| El disco | ❌ | El pipe vive en memoria |
| La traza `-v` | ✅ | El header viaja, así que sale. Táchala (teoría 05) |

> [!IMPORTANT]
> Que `printf` no salga en `ps` depende de que sea un builtin. `/usr/bin/printf`
> o `echo` desde un `sh` que no lo tenga integrado sí serían un proceso con el
> token en sus argumentos. En bash y zsh, `printf` y `echo` son builtins.

Los valores van entre comillas dobles, así que una comilla o una barra dentro
del token romperían la línea. El proyecto de la Semana 03 lo resolvió con
`escapar_config`; el mismo cuidado vale aquí.

### 2.3 Un archivo, varias peticiones

Un `-K` puede llevar varias URLs, cada una con su `output`:

```bash
cat > lote.cfg <<'EOF'
url = "http://localhost:8080/get"
output = "uno.json"
url = "http://localhost:8080/uuid"
output = "dos.json"
EOF

curl -q -sS -K lote.cfg
ls uno.json dos.json
# dos.json  uno.json
```

curl las hace en orden y reutiliza la conexión entre ellas (teoría 04, `num_connects`).
Las opciones globales del archivo (timeouts, headers) valen para todas.

---

## 3. Cómo se usa

### 3.1 Separar la tarea de la credencial

Dos archivos, cada uno con su responsabilidad:

```bash
# informe.cfg — se puede versionar: no tiene nada secreto
cat > informe.cfg <<'EOF'
fail-with-body
show-error
silent
connect-timeout = 5
max-time = 30
retry = 3
header = "Accept: application/json"
EOF

# La credencial llega por stdin; la tarea, por archivo
printf 'header = "Authorization: Bearer %s"\n' "$API_TOKEN" \
  | curl -q -K informe.cfg -K - http://localhost:8080/bearer | jq -r .authenticated
# true
```

`informe.cfg` puede ir al repositorio. La credencial nunca está en un archivo.

### 3.2 `--variable` y `--expand-*` (8.3+)

curl 8.3 añadió variables propias: `--variable` las define y las opciones
`--expand-*` (`--expand-url`, `--expand-header`, `--expand-data`...) las
sustituyen en `{{nombre}}`:

```bash
# Requiere curl 8.3 o posterior.
# %API_TOKEN lee la variable de entorno del mismo nombre.
curl -q -s --variable %API_TOKEN \
  --expand-header 'Authorization: Bearer {{API_TOKEN}}' \
  http://localhost:8080/bearer
# { "authenticated": true, "token": "token-de-prueba" }
```

Dos detalles que la hacen útil:

- **Si la variable de entorno no existe, curl falla** (`variable expansion
  failure`, salida 2) en vez de mandar un header vacío. Con
  `--variable '%API_TOKEN=valor'` se da un valor por defecto.
- **Funciones**: `{{nombre:url}}` la codifica para una URL, `{{nombre:json}}`
  para un JSON, `{{nombre:trim}}` le quita espacios.

Sin 8.3, el equivalente es lo que ya haces: variables de bash y `-K -` para lo
secreto. `--variable` no hace nada que bash no pueda hacer; la ventaja es que
funciona dentro de un archivo `-K`, donde no hay bash que expanda nada.

### 3.3 Variables de entorno que curl lee solo

curl no necesita `-K` para algunas cosas: las lee del entorno.

| Variable | Qué hace |
|---|---|
| `http_proxy`, `https_proxy` | Proxy para ese esquema. `http_proxy` **solo en minúsculas** |
| `NO_PROXY` / `no_proxy` | Hosts que no pasan por el proxy, separados por comas |
| `CURL_CA_BUNDLE` | CA con la que validar, como `--cacert` (Semana 05) |
| `CURL_HOME` | Dónde buscar el `.curlrc` (teoría 07) |

Son las responsables de muchos "en mi máquina funciona": una petición que en tu
portátil sale directa y en el servidor de CI pasa por un proxy corporativo.
`-v` lo delata con una línea `* Uses proxy env variable https_proxy == ...`.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `-H "Authorization: Bearer $API_TOKEN"` | El token expandido está en los argumentos de curl: `ps` lo ve | `printf ... \| curl -K -` |
| La credencial en un `-K` versionado | Acaba en el repositorio | Tarea en archivo, credencial por stdin |
| Escribir la credencial a un temporal para el `-K` | Queda en disco si el script muere | `-K -`, o el temporal con `umask 077` y `trap` como hace el toolkit |
| Poner el `-K` antes de lo que quieres que lo pise | Gana el último: el `-K` no manda por ser un archivo | Ordena: `-K` primero, excepciones después |
| `--variable` en un script que corre en Ubuntu 22.04 | 7.81 no la tiene: `option --variable: is unknown` | Variables de bash |
| Ignorar `https_proxy` al depurar | La petición va por un sitio que no estás mirando | `env \| grep -i proxy` y `-v` |

---

## 5. Trucos

- **`-K -` admite heredoc**: `curl -K - URL <<EOF` con las opciones dentro.
  Cuidado: el heredoc **sin** comillas expande variables, que es lo que
  quieres para la credencial y lo que no quieres para un `%{http_code}`.
- **`curl --no-proxy '*' ...`** ignora todos los proxys del entorno para una
  prueba rápida.
- **Un `-K` con `write-out`** da a todos los scripts de un equipo el mismo
  formato de log, sin copiarlo.
- **`--next`** separa grupos de opciones dentro de un mismo comando o
  archivo: cada grupo, sus propias URLs y opciones. La Semana 09 lo usa.

---

## 📚 Recursos Adicionales

- [Manpage: `--config`](https://curl.se/docs/manpage.html#-K)
- [Manpage: `--variable`](https://curl.se/docs/manpage.html#--variable)
- [everything.curl.dev — Variables](https://everything.curl.dev/cmdline/variables)
- [everything.curl.dev — Proxy environment variables](https://everything.curl.dev/usingcurl/proxies/env.html)

---

## ✅ Checklist de Verificación

- [ ] Compruebas que el orden de `-K` y `--max-time` decide cuál gana
- [ ] Mandas un token con `printf ... | curl -K -` y `ps` no lo ve
- [ ] Un `lote.cfg` con dos URLs crea dos archivos
- [ ] Separas `informe.cfg` (versionable) de la credencial (por stdin)
- [ ] Sabes si tu curl tiene `--variable`, y qué hacer si no
