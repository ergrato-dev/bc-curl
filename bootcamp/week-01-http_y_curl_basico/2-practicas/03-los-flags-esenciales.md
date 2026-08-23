# Práctica 03 — Los flags esenciales

> ⏱️ 50 minutos · Laboratorio local · Entregable: `respuestas.md`

Nueve flags. No se aprenden de memoria: se aprenden por el problema que quitan
de en medio. Cada paso de esta práctica empieza por el problema, y el flag
aparece después.

## 🎯 Qué vas a conseguir

- Leer una traza `-v` completa y decir en qué fase está cada línea
- Elegir entre `-i`, `-I` y `-D -` sabiendo qué te da cada uno
- Usar `-s` sin quedarte ciego ante los errores
- Seguir una cadena de redirecciones y contarla
- Sacar código, tiempos y tamaño de una transferencia con `-w`
- Poner un límite de tiempo y comprobar que se cumple

## 📋 Antes de empezar

```bash
./scripts/start.sh
curl -sf --max-time 5 -o /dev/null http://localhost:8080/get && echo "laboratorio OK"
```

---

## Paso 1: `-v`, o dejar de trabajar a ciegas

**Por qué**: sin `-v` no ves la petición. Cuando una API contesta 400 y tú juras
que mandaste bien los headers, `-v` es lo que enseña que no.

**Comando**:

```bash
# -v escribe la traza en STDERR, no en stdout. Por eso el cuerpo sigue
# pudiendo ir a un pipe sin mezclarse con la traza.
curl -sv http://localhost:8080/get
```

**Verifica**: identifica las cuatro clases de línea.

```bash
curl -sv http://localhost:8080/get 2>&1 | grep -E '^[*<>{]' | head -14
# *   Trying 127.0.0.1:8080...
# * Connected to localhost (127.0.0.1) port 8080 (#0)
# > GET /get HTTP/1.1
# > Host: localhost:8080
# > User-Agent: curl/7.81.0
# > Accept: */*
# >
# < HTTP/1.1 200 OK
# < Content-Type: application/json; charset=utf-8
# < Content-Length: 245
# <
# { [245 bytes data]
```

El `2>&1` no es opcional: sin él, `grep` recibe solo el cuerpo y no encuentra
ninguna de esas líneas. Pruébalo sin él y anota el resultado.

---

## Paso 2: `-i`, `-I` y `-D -`, que no son lo mismo

**Por qué**: los tres enseñan headers de respuesta, pero uno cambia el método,
otro ensucia el cuerpo y el tercero no hace ninguna de las dos cosas. Elegir mal
es cómo se acaba diagnosticando un 405 que no existía.

**Comando**:

```bash
# -i: headers + cuerpo, mezclados en stdout.
curl -s -i http://localhost:8080/get | head -3
# HTTP/1.1 200 OK
# Access-Control-Allow-Credentials: true
# Access-Control-Allow-Origin: *
```

```bash
# -I: hace un HEAD. Es OTRO METODO: el servidor puede responder distinto.
curl -sI http://localhost:8080/get | head -3
```

```bash
# -D -: hace el GET de verdad y vuelca los headers donde le digas
# ('-' es stdout). Con -o /dev/null el cuerpo no estorba.
curl -s -o /dev/null -D - http://localhost:8080/get | head -3
```

**Verifica**: compruébalo sobre un endpoint que **solo** acepta GET.

```bash
curl -s -o /dev/null -w 'con -I:  %{http_code}\n' -I http://localhost:8080/post
curl -s -o /dev/null -w 'con -D -: %{http_code}\n' -D /dev/null http://localhost:8080/post
# con -I:  405
# con -D -: 405
```

Anota qué método manda cada uno y por qué `-I` puede engañarte.

---

## Paso 3: `-s` calla demasiado, y `-S` lo arregla

**Por qué**: `-s` silencia la barra de progreso, que es lo que quieres en un
script. Pero también silencia los mensajes de error, que es justo lo que **no**
quieres. `-sS` es la combinación correcta, y por eso aparecen siempre juntas.

**Comando**:

```bash
# -s a secas: ni una palabra. El servidor no existe y no te enteras.
curl -s http://localhost:9/ ; echo "exit=$?"
# exit=7        ← el unico rastro es el codigo de salida
```

```bash
# -sS: sigue sin barra de progreso, pero el error SI sale.
curl -sS http://localhost:9/ ; echo "exit=$?"
# curl: (7) Failed to connect to localhost port 9 after 0 ms: Connection refused
# exit=7
```

**Verifica**:

```bash
curl -s  http://localhost:9/ 2>&1 | wc -l   # 0  ← silencio total
curl -sS http://localhost:9/ 2>&1 | wc -l   # 1  ← una linea de diagnostico
```

En todo lo que escribas a partir de hoy: `-sS`, no `-s`.

---

## Paso 4: `-o` y `-O`, para que el cuerpo no acabe en la pantalla

**Por qué**: ya lo viste en la práctica 02. Aquí la novedad es combinarlo:
`-o /dev/null` es la forma estándar de decir "no me interesa el cuerpo, solo lo
demás".

**Comando**:

```bash
# El cuerpo se tira; lo que interesa es el codigo.
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/get
# 200
```

**Verifica**: comprueba que efectivamente no imprimió nada más.

```bash
salida=$(curl -s -o /dev/null http://localhost:8080/get)
echo "longitud de la salida: ${#salida}"
# longitud de la salida: 0
```

---

## Paso 5: `-L`, porque curl no sigue redirecciones solo

**Por qué**: sin `-L`, una URL que redirige te devuelve un cuerpo vacío y un
301. Muchos "la API no devuelve nada" son exactamente esto.

**Comando**:

```bash
# Sin -L: curl se para en la primera respuesta.
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/redirect/3
# 302
```

```bash
# Con -L: sigue la cadena hasta el final.
curl -sL -o /dev/null \
  -w 'final=%{http_code} saltos=%{num_redirects} url=%{url_effective}\n' \
  http://localhost:8080/redirect/3
# final=200 saltos=3 url=http://localhost:8080/get
```

**Verifica**: mira la cadena entera, salto a salto.

```bash
curl -sL -o /dev/null -D - http://localhost:8080/redirect/3 | grep -iE '^(HTTP|Location)'
# HTTP/1.1 302 Found
# Location: /relative-redirect/2
# HTTP/1.1 302 Found
# Location: /relative-redirect/1
# HTTP/1.1 302 Found
# Location: /get
# HTTP/1.1 200 OK
```

> [!WARNING]
> `-L` reenvía la petición a donde diga el servidor. Por eso curl **no** manda
> la cabecera `Authorization` a un host distinto del original, y por eso
> `--location-trusted`, que sí lo hace, es un flag que hay que pensarse dos
> veces. Semana 05.

---

## Paso 6: `-w`, para extraer datos sin parsear nada

**Por qué**: es lo que convierte curl en una herramienta de scripting. Sin `-w`,
sacar el código de estado obliga a leer los headers y cortarlos con `sed`.

**Comando**:

```bash
# Cada %{...} es una variable de la transferencia. El \n final hace falta:
# curl no anade salto de linea por su cuenta.
curl -s -o /dev/null -w 'code=%{http_code}
connect=%{time_connect}
start=%{time_starttransfer}
total=%{time_total}
size=%{size_download}
type=%{content_type}
' http://localhost:8080/get
# code=200
# connect=0.000133
# start=0.000944
# total=0.000985
# size=245
# type=application/json; charset=utf-8
```

**Verifica**: la variable más útil de todas, `%{json}` (7.70+), trae todas a la
vez.

```bash
curl -s -o /dev/null -w '%{json}' http://localhost:8080/get | head -c 120
# {"content_type":"application/json; charset=utf-8","errormsg":null,"exitcode":0,
# "filename_effective":"/dev/null","ftp_entry_path":null
```

> [!NOTE]
> `%{time_total}` existe; `%{total_time}` **no**. `%{http_code}` y
> `%{response_code}` son sinónimos; `%{status_code}` no existe. Cuando dudes:
> `curl --manual | grep -A2 'time_total'`.

---

## Paso 7: `--max-time`, o el script que no vuelve nunca

**Por qué**: curl no tiene límite de tiempo por defecto. Un servidor que acepta
la conexión y luego no contesta deja tu comando esperando indefinidamente. En un
cron eso es un proceso zombi cada hora.

**Comando**:

```bash
# /delay/5 tarda cinco segundos en responder. --max-time 2 corta antes.
curl -sS -o /dev/null --max-time 2 http://localhost:8080/delay/5
echo "exit=$?"
# curl: (28) Operation timed out after 2001 milliseconds with 0 bytes received
# exit=28
```

**Verifica**: con margen suficiente, la misma petición termina bien.

```bash
curl -sS -o /dev/null --max-time 8 -w '%{http_code} en %{time_total}s\n' \
  http://localhost:8080/delay/5
# 200 en 5.005512s
```

Dos tiempos, no uno:

| Flag | Limita |
|---|---|
| `--connect-timeout` | Solo el establecimiento de la conexión |
| `--max-time` | La transferencia **entera**, conexión incluida |

En un script quieres los dos: `--connect-timeout 5 --max-time 30`.

---

## Paso 8: Todos juntos

**Por qué**: así se ve un curl de producción. Cada flag está por una razón
concreta que ya has comprobado tú.

**Comando**:

```bash
# -sS            sin barra de progreso, pero con errores
# -L             sigue redirecciones
# -o /dev/null   el cuerpo no interesa
# -w             lo que si interesa
# --max-time     no se cuelga
# --fail-with-body  sale != 0 ante 4xx/5xx, conservando el cuerpo del error
curl -sS -L --fail-with-body --max-time 10 \
  -o /dev/null -w '%{http_code} %{time_total}s %{num_redirects} saltos\n' \
  http://localhost:8080/redirect/2
# 200 0.002214s 2 saltos
```

**Verifica**: comprueba que ahora un 503 sí rompe el comando.

```bash
curl -sS -L --fail-with-body --max-time 10 -o /dev/null \
  http://localhost:8080/status/503
echo "exit=$?"
# curl: (22) The requested URL returned error: 503
# exit=22
```

---

## ✅ Resultado

- [ ] Distingues las líneas `*`, `>`, `<` y `{` de una traza `-v`
- [ ] Explicas por qué `-v` necesita `2>&1` para pasar por un pipe
- [ ] Sabes cuándo `-I` te da una respuesta engañosa y qué usar en su lugar
- [ ] Usas `-sS` en vez de `-s` y sabes qué te habrías perdido
- [ ] Sigues una cadena de tres redirecciones y la cuentas con `%{num_redirects}`
- [ ] Sacas código, tiempo y tamaño en una sola invocación con `-w`
- [ ] Provocas un exit 28 con `--max-time` y sabes qué lo diferencia de un 7
- [ ] Escribes el comando "completo" del paso 8 de memoria

```bash
./scripts/verificar-semana.sh 01
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `grep` no encuentra nada en la salida de `-v` | La traza va por stderr | `curl -v URL 2>&1 \| grep ...` |
| `-I` devuelve 405 y con el navegador funciona | `-I` manda HEAD, y ese recurso solo acepta GET | `curl -s -o /dev/null -D - URL` |
| `-w` imprime todo pegado en una línea | Falta el `\n` al final del formato | `-w '%{http_code}\n'` |
| `-w` imprime literalmente `%{total_time}` | Esa variable no existe | Es `%{time_total}`. Compruébalo en `curl --manual` |
| `--max-time 2` no corta un `/delay/1` | El servidor respondió antes del límite | Es lo esperado: sube el retardo o baja el límite |
| El comando se queda colgado para siempre | Falta `--max-time` | Ctrl-C, y añádelo. No hay límite por defecto |
| `--fail-with-body: option unknown` | curl anterior a 7.76 | Usa `-w '%{http_code}'` y compara en bash. Teoría 06, sección 5.3 |

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [Práctica 02 — El primer GET](02-el-primer-get.md) | **Práctica 03 — Los flags esenciales** | [Práctica 04 — Provocar y leer códigos de estado](04-provocar-y-leer-status-codes.md) |
