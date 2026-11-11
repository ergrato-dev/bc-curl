# El archivo `.curlrc`

> Cada vez que ejecutas curl, antes de mirar tu comando, curl busca un archivo
> de configuración y aplica lo que encuentre. Es cómodo en tu terminal y una
> bomba en un script: el mismo comando hace cosas distintas según quién lo
> ejecute.

![Diagrama del orden en que curl busca su archivo de configuración: primero $CURL_HOME/.curlrc, después el de $XDG_CONFIG_HOME, después $HOME/.curlrc; usa el primero que encuentra, aplica sus opciones y luego las de la línea de comandos, que pisan a las de valor único y se suman a las acumulativas como -H; -q como primer argumento corta la búsqueda antes de empezar](../0-assets/07-el-archivo-curlrc.svg)

## 🎯 Objetivos

- Escribir un `.curlrc` con la sintaxis correcta
- Saber en qué orden busca curl el archivo y cuál usa
- Predecir qué gana cuando el `.curlrc` y el comando dicen cosas distintas
- Decidir qué tiene sentido poner en un `.curlrc` y qué no
- Usar `-q` y entender por qué tiene que ir en primera posición

---

## 1. Qué problema resuelve

Escribes `-sS --max-time 30 --fail-with-body` en cada comando que tecleas.
Llevas cinco semanas. El `.curlrc` existe para eso: lo escribes una vez y
curl lo aplica siempre.

El problema llega después. Un compañero ejecuta tu script y le falla. Tú lo
ejecutas y funciona. La diferencia está en un archivo que ninguno de los dos
miró: tu `.curlrc` tiene `--location` y el suyo no; o el suyo tiene `--include`
y tu script espera JSON puro en stdout.

```bash
mkdir -p /tmp/rc && echo include > /tmp/rc/.curlrc
CURL_HOME=/tmp/rc curl -s http://localhost:8080/get | jq -r .url
# parse error: Invalid numeric literal at line 1, column 9
#                   ← jq recibe 'HTTP/1.1 200 OK' antes del JSON
```

El mismo comando, una línea de configuración distinta, un script roto.

---

## 2. Cómo funciona

### 2.1 La sintaxis

Una opción por línea. Tres formas equivalentes:

```
# Comentario: la linea empieza por #
--max-time 30          # como en la linea de comandos, con sus guiones
max-time = 30          # sin guiones, con = (o :) como separador
max-time 30            # sin guiones, con espacio
-sS                    # las cortas tambien valen
user-agent = "mi script/1.0"    # comillas dobles si hay espacios
header = "Accept: application/json"
```

Reglas que muerden:

- **Una opción por línea.** Con `-sS --max-time 30` en la misma línea, curl
  avisa (`uses unquoted whitespace in the line that may cause side-effects!`)
  y no aplica lo que esperabas.
- **Con guiones no hay `=`**: `--max-time = 30` da `expected a proper
  numerical parameter`; `max-time = 30` está bien.
- **Comillas dobles** si el valor tiene espacios o empieza por `:` o `=`. Dentro
  valen `\\`, `\"`, `\t`, `\n` y `\r`. Es la misma sintaxis que la Semana 03
  usó para el archivo `--config` de la credencial.
- **Una URL necesita `url =`**: una línea con la URL a secas da `'http' is
  ambiguous`.

### 2.2 Dónde lo busca

curl usa **el primero que encuentra**, en este orden:

| Orden | Ruta | Nota |
|:--:|---|---|
| 1 | `$CURL_HOME/.curlrc` | Si `CURL_HOME` está definida |
| 2 | `$XDG_CONFIG_HOME/curlrc` | Desde 7.73. **Ojo con el nombre**, abajo |
| 3 | `$HOME/.curlrc` | El de toda la vida |
| 4 | El home de `getpwuid` | Si `HOME` no está definida |

En Windows además busca `_curlrc` y en `%APPDATA%`.

> [!WARNING]
> El nombre dentro de `$XDG_CONFIG_HOME` ha cambiado entre versiones.
> Comprobado en el laboratorio: **curl 7.81 lee `$XDG_CONFIG_HOME/.curlrc`**
> (con punto) y **curl 8.17 lee `$XDG_CONFIG_HOME/curlrc`** (sin punto), que es
> lo que dice el manual actual. Si usas XDG, comprueba cuál lee tu versión; si
> no, quédate con `~/.curlrc`.

Solo se lee **uno**. Si existe `$CURL_HOME/.curlrc`, el de `$HOME` se ignora
aunque exista.

`CURL_HOME` es la forma limpia de probar un `.curlrc` **sin tocar el tuyo**: en
un directorio temporal, para un solo comando. Todas las pruebas de esta semana
lo hacen así.

### 2.3 Qué gana

curl aplica primero el `.curlrc` y después la línea de comandos, en orden. Lo
que pasa con una opción que aparece en los dos sitios depende de la opción:

```bash
printf 'max-time = 1\n' > /tmp/rc/.curlrc

CURL_HOME=/tmp/rc curl -s -o /dev/null -w '%{http_code} %{exitcode}\n' http://localhost:8080/delay/2
# 000 28           ← el max-time del .curlrc se aplico
CURL_HOME=/tmp/rc curl -s -o /dev/null --max-time 5 -w '%{http_code} %{exitcode}\n' http://localhost:8080/delay/2
# 200 0            ← el del comando, posterior, lo piso
```

| Tipo de opción | Ejemplos | Qué pasa |
|---|---|---|
| De valor único | `--max-time`, `-w`, `-A`, `-o` | Gana el último: el comando pisa al `.curlrc` |
| Acumulativa | `-H`, `-d`, `-F`, `-b` | Se suman: el comando **añade** a lo del `.curlrc` |
| Interruptor | `-L`, `-i`, `-s`, `-v` | Se enciende y ya. Para apagarlo hace falta su `--no-` |

Los interruptores son los traicioneros. Si el `.curlrc` tiene `--location`, tu
comando lo sigue teniendo; desactivarlo exige `--no-location`. Y la cabecera
que el `.curlrc` añade con `header =` viaja en **todas** tus peticiones, a
todos los hosts.

### 2.4 `-q`: no leer nada

`-q` (`--disable`) le dice a curl que no busque ningún `.curlrc`. Con una
condición estricta: **tiene que ser el primer argumento**.

```bash
printf 'header = "X-Uno: 1"\n' > /tmp/rc/.curlrc

CURL_HOME=/tmp/rc curl -q -s http://localhost:8080/headers | jq -c '.headers["X-Uno"]'
# null             ← -q primero: el .curlrc no se leyo
CURL_HOME=/tmp/rc curl -s -q http://localhost:8080/headers | jq -c '.headers["X-Uno"]'
# ["1"]            ← -q segundo: ya era tarde, y no avisa
```

No es un capricho: curl decide si lee el `.curlrc` antes de procesar el resto
de argumentos. En segunda posición, `-q` se ignora en silencio.

---

## 3. Cómo se usa

### 3.1 Un `.curlrc` razonable para tu terminal

```
# ~/.curlrc — solo para uso interactivo
--show-error
--no-progress-meter
connect-timeout = 10
max-time = 60
user-agent = "curl-interactivo"
```

Defaults que te protegen (timeouts, ver los errores) y que no cambian el
**formato** de la salida ni a dónde va la petición.

### 3.2 Lo que no va en un `.curlrc`

| Opción | Por qué no |
|---|---|
| `-k` / `insecure` | Apaga TLS en **todas** tus peticiones, para siempre, sin que lo veas en el comando |
| `header = "Authorization: ..."` | La credencial viaja a todos los hosts a los que hables, y está en un archivo que no se suele proteger |
| `-i` / `include` | Rompe cualquier pipe a `jq` |
| `-L` / `location` | Cambia a dónde llega la petición y qué se reenvía |
| `-o`, `-O`, `-w` | Cambian la salida de todos los comandos |
| `proxy = ...` | Todo tu tráfico pasa por otro sitio, también el que no debería |

La regla: un `.curlrc` puede hacer curl **más prudente**, nunca **distinto**.

### 3.3 En un script: `-q` siempre

Un script no sabe qué `.curlrc` tiene quien lo ejecuta. La única forma de que
haga lo mismo en todas las máquinas es no leer ninguno:

```bash
# Siempre la primera opcion. Todo lo que el script necesita, explicito detras.
curl -q --fail-with-body -sS --max-time 10 --retry 3 http://localhost:8080/get
```

Es lo que hace `api-toolkit.sh` desde esta semana: todas sus llamadas pasan por
`lanzar_curl`, que pone `--disable` delante de todo.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Un script sin `-q` | Su comportamiento depende del `.curlrc` de cada usuario | `curl -q ...`, siempre primero |
| `curl -sS -q ...` | `-q` se ignora en silencio fuera de la primera posición | `curl -q -sS ...` |
| `insecure` en el `.curlrc` "para el entorno de pruebas" | Se queda para todos los entornos | `--cacert` en el comando que lo necesita |
| Probar un `.curlrc` editando el tuyo | Te olvidas de deshacerlo | `CURL_HOME=$(mktemp -d)` |
| Un `.curlrc` con credenciales | Viajan a todos los hosts | Un `-K` por tarea (teoría 08) |
| Depurar sin mirar el `.curlrc` | Buscas el fallo en el comando y está en el archivo | Repite con `-q`; si cambia, era el archivo |

---

## 5. Trucos

- **¿Me está afectando un `.curlrc`?** Repite el comando con `-q` delante. Si
  el resultado cambia, sí.
- **¿Cuál está leyendo?** `ls -l "${CURL_HOME:-/nonexistent}/.curlrc"
  "${XDG_CONFIG_HOME:-$HOME/.config}/curlrc" ~/.curlrc 2>/dev/null`.
- **`curl -q --libcurl - URL`** contra **`curl --libcurl - URL`**: el `diff`
  de los dos programas son exactamente las opciones del `.curlrc`.
- **Un `.curlrc` por proyecto**: `CURL_HOME=$PWD curl ...` en un alias o un
  `Makefile`. Útil, siempre que el directorio no se suba al repositorio.

---

## 📚 Recursos Adicionales

- [everything.curl.dev — Config file](https://everything.curl.dev/cmdline/configfile.html)
- [Manpage: `--config`, con el orden de búsqueda](https://curl.se/docs/manpage.html#-K)
- [Manpage: `--disable`](https://curl.se/docs/manpage.html#-q)

---

## ✅ Checklist de Verificación

- [ ] Un `.curlrc` en `CURL_HOME=/tmp/rc` cambia un comando, y `-q` primero lo anula
- [ ] Compruebas que `-q` en segunda posición no hace nada
- [ ] Predices y compruebas qué gana con `max-time` y qué pasa con `header`
- [ ] Sabes qué archivo lee tu curl dentro de `$XDG_CONFIG_HOME`
- [ ] Tu `~/.curlrc`, si tienes uno, no contiene nada de la tabla 3.2
