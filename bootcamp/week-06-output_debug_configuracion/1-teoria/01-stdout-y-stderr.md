# stdout y stderr

> curl escribe en dos sitios a la vez. En uno va lo que pediste; en el otro,
> todo lo que curl tiene que contarte sobre cómo fue. Un script que los mezcla
> le pasa basura al siguiente comando del pipe.

![Diagrama de los dos flujos de salida de curl: el cuerpo de la respuesta va a stdout, o a un archivo con -o; el medidor de progreso, los mensajes de error, la traza de -v y lo que sigue a %{stderr} en -w van a stderr; -s apaga el medidor y los errores, -S devuelve los errores](../0-assets/01-stdout-y-stderr.svg)

## 🎯 Objetivos

- Saber qué escribe curl en stdout y qué en stderr, sin adivinar
- Entender por qué el medidor de progreso aparece unas veces sí y otras no
- Elegir entre `-s`, `-sS` y `--no-progress-meter` según quién lea la salida
- Mandar el cuerpo a un archivo y los diagnósticos a otro
- Mantener stdout limpio para que `jq` y compañía no se atraganten

---

## 1. Qué problema resuelve

Un script de la Semana 02 hacía esto:

```bash
curl http://localhost:8080/get > respuesta.json
jq -r .url respuesta.json
```

En la terminal funciona. En un cron, el log se llena de esto:

```
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   245  100   245    0     0   239k      0 --:--:-- --:--:-- --:--:--  239k
```

Y el día que el servidor no responde, el log no dice nada útil, porque alguien
añadió `-s` para quitar esa tabla y con ella se fue también el mensaje de error.

Las dos cosas tienen la misma causa: no saber qué escribe curl en cada flujo.

---

## 2. Cómo funciona

### 2.1 Dos flujos, dos destinatarios

Todo proceso Unix tiene dos salidas: **stdout** (descriptor 1) y **stderr**
(descriptor 2). La convención es que stdout lleva el resultado y stderr lleva
los diagnósticos. curl la sigue al pie de la letra:

| Qué | Flujo | Cómo se controla |
|---|---|---|
| El cuerpo de la respuesta | stdout | `-o archivo` lo manda a un archivo |
| Los headers, con `-i` | stdout | Van delante del cuerpo, mezclados |
| La salida de `-w` | stdout | `%{stderr}` la cambia de flujo |
| El medidor de progreso | stderr | `-s` o `--no-progress-meter` lo apagan |
| Los mensajes de error `curl: (7) ...` | stderr | `-s` los apaga, `-S` los devuelve |
| La traza de `-v` | stderr | `--stderr archivo` la redirige |
| La traza de `--trace-ascii -` | stdout | El `-` es stdout, no stderr |

La consecuencia práctica: **si redirige stdout a un archivo o a un pipe,
nada de stderr se mezcla con el cuerpo.** El cuerpo llega limpio a `jq`, y los
diagnósticos siguen saliendo en la terminal o en el log.

### 2.2 El medidor de progreso

El medidor tiene una regla que despista: **curl solo lo muestra cuando stdout
no es una terminal.** Si el cuerpo va a la pantalla, imprimir la tabla
encima lo destrozaría, así que curl se calla. En cuanto rediriges stdout, la
tabla aparece en stderr:

```bash
curl http://localhost:8080/get
# {                         ← el cuerpo, sin tabla: stdout es la terminal
#   "args": {},
# ...

curl http://localhost:8080/get > respuesta.json
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                  Dload  Upload   Total   Spent    Left  Speed
# 100   245  100   245    0     0   239k      0 --:--:-- --:--:-- --:--:--  239k
```

Por eso el comando que "funcionaba" en la terminal llena el log del cron: en
la terminal no había tabla, en el cron sí.

### 2.3 Tres formas de callar a curl

| Opción | Medidor | Errores | Para quién |
|---|:--:|:--:|---|
| `-s` / `--silent` | ❌ | ❌ | Nadie. Un script que no informa de sus errores |
| `-sS` / `--silent --show-error` | ❌ | ✅ | Scripts: silencio cuando va bien, motivo cuando va mal |
| `--no-progress-meter` | ❌ | ✅ | Lo mismo que `-sS`, con nombre explícito (7.67+) |

```bash
curl -s http://127.0.0.1:9/
echo "codigo: $?"
# codigo: 7          ← falló, y no lo dijo

curl -sS http://127.0.0.1:9/
# curl: (7) Failed to connect to 127.0.0.1 port 9 after 0 ms: Connection refused
```

`-s` a secas solo tiene sentido cuando lees el código de salida y escribes tú
el mensaje. Es lo que hace `api-toolkit.sh` en `fallo_de_red`, y aun así lleva
`--show-error`: el mensaje de curl es más preciso que cualquier traducción.

---

## 3. Cómo se usa

### 3.1 El cuerpo a un archivo, el diagnóstico a otro

```bash
# El cuerpo a respuesta.json; errores y traza a diagnostico.log.
curl -sS -v -o respuesta.json http://localhost:8080/get 2> diagnostico.log
jq -r .url respuesta.json
# http://localhost:8080/get
grep -c '^>' diagnostico.log
# 5          ← las lineas que envio curl: peticion, headers y la vacia final
```

`--stderr archivo` hace lo mismo que `2> archivo`, pero desde dentro de curl.
Sirve cuando no controlas la redirección del shell, por ejemplo dentro de un
archivo `-K`:

```bash
curl -s -v --stderr diagnostico.log -o /dev/null http://localhost:8080/get
wc -l < diagnostico.log
# 17
```

### 3.2 El cuerpo directo al siguiente comando

```bash
# stdout va por el pipe; si curl falla, el mensaje sale por la terminal y jq
# recibe una entrada vacia.
curl -sS http://localhost:8080/get | jq -r .url
# http://localhost:8080/get
```

Con `set -o pipefail`, el código de salida del pipe es el del primer comando
que falló. Sin él, un `curl` que falla seguido de un `jq` que no se queja da
un 0 y el script sigue como si nada.

### 3.3 Capturar las dos cosas en un script

```bash
# El cuerpo en una variable, el error en otra. 2>&1 dentro de $( ) mezclaria
# los dos: el cuerpo dejaria de ser JSON.
error_log="$(mktemp)"
if cuerpo="$(curl -sS --max-time 5 http://localhost:8080/get 2>"$error_log")"; then
  jq -r .url <<<"$cuerpo"
else
  echo "fallo: $(cat "$error_log")" >&2
fi
rm -f "$error_log"
# http://localhost:8080/get
```

Es el patrón que usa `lanzar_curl` en el proyecto: stderr va a un archivo
temporal, y el script decide qué hacer con él antes de enseñarlo.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `curl -s` en un script | El fallo no deja rastro en el log | `curl -sS`, o `--no-progress-meter` |
| `curl ... 2>&1 \| jq` | La traza o el error se mezclan con el JSON y `jq` falla con un mensaje que no apunta al culpable | Deja stderr fuera del pipe |
| `respuesta=$(curl -v ... 2>&1)` | El cuerpo ya no es el cuerpo | `2>archivo` y leer el archivo aparte |
| Apagar el medidor con `2>/dev/null` | Se va también el mensaje de error | `--no-progress-meter`: solo apaga el medidor |
| Asumir que la tabla no sale porque en la terminal no salía | En el cron, con stdout redirigido, sí sale | `-sS` desde el principio |

---

## 5. Trucos

- **`-#` / `--progress-bar`** cambia la tabla por una barra de una línea.
  Útil en descargas grandes hechas a mano; en un script, `-sS` igual.
- **`2>&1 >/dev/null` no es portable entre shells.** En bash deja solo stderr
  en el pipe. En zsh, con `MULTIOS` activado por defecto, stdout se duplica y
  el cuerpo vuelve a salir. Para quedarte solo con stderr, `2>traza.txt
  >/dev/null`, o ejecútalo dentro de `bash -c`.
- **`-o /dev/null`** cuando solo quieres el `-w` o la traza: el cuerpo no
  estorba y el medidor tampoco sale si añades `-s`.

---

## 📚 Recursos Adicionales

- [everything.curl.dev — Progress meter](https://everything.curl.dev/cmdline/progressmeter.html)
- [Manpage: `--silent`, `--show-error`, `--stderr`](https://curl.se/docs/manpage.html#-s)
- [Bash Reference Manual — Redirections](https://www.gnu.org/software/bash/manual/html_node/Redirections.html)

---

## ✅ Checklist de Verificación

- [ ] `curl http://localhost:8080/get > r.json` enseña el medidor y `curl http://localhost:8080/get` no, y sabes por qué
- [ ] `curl -s http://127.0.0.1:9/` no imprime nada y `curl -sS http://127.0.0.1:9/` imprime el `(7)`
- [ ] Separas cuerpo y traza: `curl -sS -v -o r.json URL 2> d.log` y los dos archivos tienen lo esperado
- [ ] `curl -sS URL | jq .` funciona aunque añadas `-v`
- [ ] Sabes qué hace `2>&1 >/dev/null` en tu shell, sea bash o zsh
