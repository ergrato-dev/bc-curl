# Práctica 03 — `.curlrc` sin romper scripts

> **Duración**: 50 min · **Entregables**: `curlrc.md`

Vas a escribir un `.curlrc` en un directorio de pruebas, sin tocar el tuyo, y
ver cómo cambia tus comandos. Después romperás un script con una sola línea de
configuración, lo arreglarás con `-q`, comprobarás el orden de precedencia con
tres tipos de opción, y moverás la configuración de una tarea a un archivo `-K`
con la credencial entrando por stdin, sin que `ps` la vea.

**Antes de empezar**, desde la raíz del repositorio:

```bash
./scripts/start.sh
export TOOLKIT="$PWD/bootcamp/week-06-output_debug_configuracion/3-proyecto/starter/api-toolkit.sh"
mkdir -p ~/bc-curl-trabajo/semana-06/p3/rc && cd ~/bc-curl-trabajo/semana-06/p3
export CURL_HOME="$PWD/rc"
```

> [!IMPORTANT]
> `CURL_HOME` hace que curl busque el `.curlrc` en `./rc` y **no** en tu `$HOME`.
> Mientras esté exportada, en esta terminal tu `~/.curlrc` real no se lee. Al
> terminar: `unset CURL_HOME`, o cierra la terminal.

---

## Paso 1: ¿Ya tienes uno?

**Por qué**: si tu máquina ya lee un `.curlrc`, cada resultado de las semanas
anteriores estaba condicionado por él. Hay que saberlo antes de seguir.

**Comando**:

```bash
ls -l ~/.curlrc "${XDG_CONFIG_HOME:-$HOME/.config}/curlrc" \
      "${XDG_CONFIG_HOME:-$HOME/.config}/.curlrc" 2>/dev/null
ls -l "$CURL_HOME/.curlrc" 2>/dev/null; echo "en rc: $?"
```

**Verifica**:

```bash
ls -l "$CURL_HOME/.curlrc" 2>/dev/null; echo "en rc: $?"
# en rc: 2      ← todavia no existe: el directorio de pruebas esta limpio
```

Si el primer `ls` encontró algo, cópialo en `curlrc.md` y revisa si tiene algo
de la tabla 3.2 de la teoría 07.

---

## Paso 2: Un `.curlrc` razonable

**Por qué**: un `.curlrc` puede hacerte la vida más fácil en la terminal sin
cambiar qué hace curl. Este es el modelo.

**Comando**:

```bash
cat > rc/.curlrc <<'EOF'
# Solo para uso interactivo
show-error
no-progress-meter
connect-timeout = 10
max-time = 60
user-agent = "curl-interactivo"
EOF

curl http://localhost:8080/user-agent
```

**Verifica**:

```bash
curl -s http://localhost:8080/user-agent | jq -r '."user-agent"'
# curl-interactivo
curl -q -s http://localhost:8080/user-agent | jq -r '."user-agent"'
# curl/7.81.0            ← con -q, el .curlrc no se lee
```

`-q` delante es la prueba más rápida de si un `.curlrc` está interviniendo.

---

## Paso 3: Una línea que rompe un script

**Por qué**: un script correcto puede romperse en la máquina de otro sin
cambiar una coma. Hay que verlo pasar.

**Comando**:

```bash
cat > url-de.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Imprime la URL que el laboratorio dice haber recibido.
curl --fail-with-body -sS --max-time 10 "http://localhost:8080/$1" | jq -r .url
EOF
chmod +x url-de.sh

./url-de.sh get
echo include >> rc/.curlrc
./url-de.sh get; echo "salida: $?"
```

**Verifica**:

```bash
sed -i '/^include$/d' rc/.curlrc; ./url-de.sh get
# http://localhost:8080/get
echo include >> rc/.curlrc; ./url-de.sh get; echo "salida: $?"
# parse error: Invalid numeric literal at line 1, column 9
# salida: 4
```

El script no cambió. `jq` recibió `HTTP/1.1 200 OK` antes del JSON. Apunta en
`curlrc.md` el error y por qué un compañero sin esa línea no lo ve.

---

## Paso 4: `-q`, y solo en primera posición

**Por qué**: la defensa es `-q`. Pero tiene una condición que no avisa si no
se cumple.

**Comando**:

```bash
# -q en segunda posicion
sed -i 's/curl --fail-with-body/curl --fail-with-body -q/' url-de.sh
./url-de.sh get; echo "salida: $?"

# -q en primera posicion
sed -i 's/curl --fail-with-body -q/curl -q --fail-with-body/' url-de.sh
./url-de.sh get; echo "salida: $?"
```

**Verifica**:

```bash
grep -o 'curl -q --fail-with-body' url-de.sh
# curl -q --fail-with-body
./url-de.sh get; echo "salida: $?"
# http://localhost:8080/get
# salida: 0
```

En segunda posición falló igual, sin ningún aviso. Ahora con el toolkit de
esta semana:

```bash
"$TOOLKIT" get /get | head -1
# HTTP/1.1 200 OK    ← antes del TODO 1: el toolkit tambien lee tu .curlrc
```

Cuando completes el TODO 1, esa línea será `{`. Es la comprobación
`toolkit-ignora-curlrc`. Quita el `include` del `.curlrc` antes de seguir:

```bash
sed -i '/^include$/d' rc/.curlrc
```

---

## Paso 5: Qué gana, según la opción

**Por qué**: el `.curlrc` y el comando no se pisan siempre igual. Depende de
si la opción tiene un valor, se acumula, o es un interruptor.

**Comando**:

```bash
# 1. Valor unico: max-time
printf 'max-time = 1\n' > rc/.curlrc
curl -s -o /dev/null -w '%{exitcode}\n' http://localhost:8080/delay/2
curl -s -o /dev/null -w '%{exitcode}\n' --max-time 5 http://localhost:8080/delay/2

# 2. Acumulativa: header
printf 'header = "X-Del-Curlrc: 1"\n' > rc/.curlrc
curl -s -H 'X-Del-Comando: 2' http://localhost:8080/headers \
  | jq -c '.headers | {"X-Del-Curlrc", "X-Del-Comando"}'

# 3. Interruptor: location
printf 'location\n' > rc/.curlrc
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/redirect/1
curl -s -o /dev/null -w '%{http_code}\n' --no-location http://localhost:8080/redirect/1
```

**Verifica**:

```bash
# 1. Valor unico
# 28        ← el del .curlrc
# 0         ← el del comando lo piso
# 2. Acumulativa
# {"X-Del-Curlrc":["1"],"X-Del-Comando":["2"]}     ← los dos viajan
# 3. Interruptor
# 200       ← siguio el redirect, aunque el comando no lo pidio
# 302       ← apagado con su --no-
```

Copia la tabla de los tres casos en `curlrc.md`. El tercero es el peligroso:
nadie escribe `--no-location` "por si acaso".

---

## Paso 6: La configuración de una tarea en un `-K`

**Por qué**: las opciones de una tarea concreta tienen que estar juntas y
versionadas, pero no aplicarse a todo lo demás.

**Comando**:

```bash
: > rc/.curlrc        # vaciamos el .curlrc de pruebas

cat > tarea.cfg <<'EOF'
fail-with-body
silent
show-error
connect-timeout = 5
max-time = 1
header = "Accept: application/json"
EOF

curl -q -K tarea.cfg -o /dev/null -w '%{exitcode}\n' --max-time 5 http://localhost:8080/delay/2
curl -q --max-time 5 -K tarea.cfg -o /dev/null -w '%{exitcode}\n' http://localhost:8080/delay/2
```

**Verifica**:

```bash
# 0        ← -K primero, --max-time 5 despues: gana el comando
# curl: (28) Operation timed out after 1000 milliseconds with 0 bytes received
# 28       ← --max-time 5 primero, -K despues: gana el archivo
```

El `-K` se expande en su sitio. Ponlo **primero** y escribe detrás solo las
excepciones. Apúntalo en `curlrc.md`.

---

## Paso 7: La credencial por stdin

**Por qué**: `tarea.cfg` puede ir al repositorio porque no tiene nada secreto.
El token tiene que llegar por otro camino que no sea el disco ni los
argumentos.

**Comando**:

```bash
export API_TOKEN=token-de-prueba

# Una peticion lenta en segundo plano, para que de tiempo a mirar ps
printf 'header = "Authorization: Bearer %s"\n' "$API_TOKEN" \
  | curl -q -K tarea.cfg -K - --max-time 5 -o respuesta.json \
      http://localhost:8080/delay/2 &
sleep 1
ps -o args= -C curl
wait
```

**Verifica**:

```bash
# ps -o args= -C curl, mientras curl esperaba:
# curl -q -K tarea.cfg -K - --max-time 5 -o respuesta.json http://localhost:8080/delay/2
jq -r '.headers.Authorization[0]' respuesta.json
# Bearer token-de-prueba     ← llego al servidor
ps -o args= -C curl | grep -c token-de-prueba
# 0                          ← y nunca estuvo en los argumentos
```

Repite con `-H "Authorization: Bearer $API_TOKEN"` en vez de `-K -` y mira
`ps` otra vez: el token sale entero. En macOS, `ps -o args= -C curl` no
existe: usa `ps -ax -o args | grep '[c]url'`.

---

## Paso 8: Varias peticiones en un archivo

**Por qué**: una tarea que consulta tres endpoints no necesita tres comandos.

**Comando**:

```bash
cat > lote.cfg <<'EOF'
url = "http://localhost:8080/get"
output = "uno.json"
url = "http://localhost:8080/uuid"
output = "dos.json"
EOF

curl -q -sS -K lote.cfg -w '%{url_effective} %{num_connects}\n'
```

**Verifica**:

```bash
curl -q -sS -K lote.cfg -w '%{url_effective} %{num_connects}\n'
# http://localhost:8080/get 1
# http://localhost:8080/uuid 0      ← segunda peticion, misma conexion
jq -r .uuid dos.json | grep -cE '^[0-9a-f-]{36}$'
# 1
```

El `-w` se aplica a cada URL. Y el `0` de la segunda dice que reutilizó la
conexión: lo que la Semana 09 convierte en velocidad.

---

## Paso 9: Dejarlo todo como estaba

**Por qué**: un `CURL_HOME` olvidado en un `.zshrc` es un `.curlrc` fantasma
durante meses.

**Comando**:

```bash
unset CURL_HOME API_TOKEN
grep -n 'CURL_HOME' ~/.bashrc ~/.zshrc 2>/dev/null
```

**Verifica**:

```bash
echo "CURL_HOME=[${CURL_HOME:-}]"
# CURL_HOME=[]
grep -c 'CURL_HOME' ~/.bashrc ~/.zshrc 2>/dev/null
# 0 en los dos, o "No such file" si no los tienes
```

---

## ✅ Resultado

- [ ] Sé si mi máquina tiene un `.curlrc` y qué contiene
- [ ] `curlrc.md` tiene el script roto por `include`, el error de `jq` y el arreglo con `-q`
- [ ] He comprobado que `-q` en segunda posición no hace nada
- [ ] `curlrc.md` tiene la tabla de valor único, acumulativa e interruptor, comprobada
- [ ] He visto que el orden del `-K` decide qué gana
- [ ] Mandé un token por `-K -` y `ps` no lo vio

```bash
./scripts/verificar-semana.sh 06
```

Esta práctica prepara el `--disable` de `lanzar_curl` (TODO 1) y el User-Agent
del TODO 2.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| El paso 2 sigue dando `curl/7.81.0` sin `-q` | `CURL_HOME` no está exportada en esta terminal | `export CURL_HOME="$PWD/rc"` desde `p3/` |
| El paso 3 no se rompe | El `.curlrc` tiene otra línea antes con `--no-include`, o hay un espacio tras `include` | `cat -A rc/.curlrc`: tiene que ser `include$` |
| `sed -i` falla en macOS | El `-i` de BSD sed necesita un argumento | `sed -i '' ...` |
| El paso 7 no enseña nada en `ps` | curl terminó antes del `sleep 1` | Sube el `/delay/2` a `/delay/4` y el `--max-time` a 6 |
| `ps: error: unsupported option` | `-C` es de procps (Linux) | `ps -ax -o args \| grep '[c]url'` |
| El paso 8 da `num_connects` 1 en las dos | Tu versión no reutiliza entre URLs de un `-K` con `output` | Es correcto igualmente; lo que importa son los dos archivos |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 02 — Medir con `--write-out`](02-medir-con-write-out.md) | [Práctica 04 — Métricas de un endpoint](04-metricas-de-un-endpoint.md) |
