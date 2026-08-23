# Los flags esenciales

> Nueve opciones. Con ellas cubres el 90% de lo que harás con curl durante los
> próximos diez años, y cada una existe porque el comportamiento por defecto
> muerde de una forma distinta.

## 🎯 Objetivos

- Usar `-v`, `-i`, `-I`, `-s`, `-S`, `-L`, `-o`, `-w` y `--max-time` sabiendo qué problema resuelve cada uno
- Elegir entre `-i`, `-I` y `-D -` según lo que necesites ver
- Extraer datos concretos de una transferencia con `--write-out`
- Explicar por qué `--max-time` no es opcional en un script

---

## 1. Qué problema resuelve

El comportamiento por defecto de curl está pensado para pipes: imprime el cuerpo
en stdout y todo lo demás en stderr, sin adornos. Es la decisión correcta, y
significa que **por defecto curl te oculta casi todo lo interesante**.

Cada uno de estos nueve flags destapa una parte.

| Flag | Largo | Destapa o resuelve |
|---|---|---|
| `-v` | `--verbose` | La conversación entera: qué mandaste y qué te contestaron |
| `-i` | `--include` | Los headers de respuesta, junto al cuerpo |
| `-I` | `--head` | Solo los headers, con una petición `HEAD` |
| `-s` | `--silent` | Calla la barra de progreso. Y también los errores |
| `-S` | `--show-error` | Devuelve los errores que `-s` se llevó |
| `-L` | `--location` | Sigue los redirects en vez de enseñarte la página vacía del 301 |
| `-o` | `--output` | Guarda el cuerpo en un archivo en vez de imprimirlo |
| `-w` | `--write-out` | Imprime datos de la transferencia: código, tiempos, tamaños |
| — | `--max-time` | Pone un límite. Sin él, curl espera indefinidamente |

Los nueve son anteriores a 7.68: están en cualquier curl que te encuentres.

---

## 2. Ver lo que pasa: `-v`, `-i`, `-I`

### 2.1 `-v`: la conversación entera

```bash
curl -sv http://localhost:8080/get 2>&1 | head -12
```

Tres prefijos, y saber cuál es cuál es medio trabajo de depuración:

| Prefijo | Qué es |
|---|---|
| `*` | curl hablando de sí mismo: DNS, conexión, TLS, decisiones internas |
| `>` | Lo que curl **envió** |
| `<` | Lo que curl **recibió** |

Va a **stderr**, por eso el `2>&1` cuando quieres filtrarlo con `grep`.

### 2.2 `-i`: headers y cuerpo, en stdout

```bash
curl -si http://localhost:8080/get | head -4
# HTTP/1.1 200 OK
# Access-Control-Allow-Credentials: true
# Access-Control-Allow-Origin: *
# Content-Type: application/json; charset=utf-8
```

Diferencia con `-v`: `-i` va a **stdout** y solo trae los headers de respuesta.
Es lo que quieres cuando estás mirando; es lo que **no** quieres en un pipe,
porque los headers acaban dentro de tu `jq`.

### 2.3 `-I`: solo headers — pero cambia el método

```bash
curl -sI http://localhost:8080/get | head -2
# HTTP/1.1 200 OK
# Access-Control-Allow-Credentials: true
```

Cuidado: `-I` **no es "un GET sin cuerpo"**. Es una petición `HEAD`, un método
distinto. Un servidor puede responder de otra forma a `HEAD` que a `GET`, o
directamente rechazarlo con un 405.

### 2.4 `-D -`: los headers de un GET de verdad

Cuando quieres los headers **sin** cambiar el método:

```bash
curl -s -o /dev/null -D - http://localhost:8080/get | head -2
```

`-D` vuelca los headers de respuesta en un archivo; `-` significa stdout.

| Quiero... | Uso |
|---|---|
| Depurar toda la conversación | `-v` |
| Ver headers y cuerpo, a ojo | `-i` |
| Solo headers, y me vale un `HEAD` | `-I` |
| Solo headers, pero de un `GET` real | `-s -o /dev/null -D -` |

---

## 3. Callar el ruido: `-s` y `-S`

`-s` quita la barra de progreso. Y, de paso, **quita los mensajes de error**:

```bash
curl -s http://no-existe.invalido/ ; echo "exit=$?"
# exit=6      ← ni una palabra de lo que pasó
```

Salida vacía y código 6. En un script que solo mire la salida, eso es
indistinguible de una respuesta correcta vacía.

`-S` devuelve los errores sin devolver la barra:

```bash
curl -sS http://no-existe.invalido/ ; echo "exit=$?"
# curl: (6) Could not resolve host: no-existe.invalido
# exit=6
```

**`-sS` van juntos, siempre.** Escribir `-s` a secas en un script es sembrar un
fallo silencioso.

Desde 7.67 hay una opción que hace justo eso con un solo nombre:

```bash
curl --no-progress-meter http://localhost:8080/get
```

---

## 4. Seguir el rastro: `-L`

Sin `-L`, un redirect es una respuesta como otra cualquiera: código 3xx y, casi
siempre, cuerpo vacío.

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/redirect/2
# 302
```

Con `-L`, curl sigue la cadena hasta el final:

```bash
curl -s -o /dev/null -L -w '%{http_code} %{num_redirects} %{url_effective}\n' \
  http://localhost:8080/redirect/2
# 200 2 http://localhost:8080/get
```

`%{num_redirects}` cuenta los saltos y `%{url_effective}` dice dónde acabó. Las
dos son imprescindibles cuando una URL "no devuelve lo que debería": muchas
veces devuelve lo correcto, de otro sitio.

Los redirects a fondo — y los tres que **no** deberías seguir a ciegas — están
en la Semana 05.

---

## 5. `-w`: sacar datos de la transferencia

`--write-out` imprime, al terminar, un formato que tú defines con variables.
Es la herramienta de medición de todo el bootcamp.

```bash
curl -s -o /dev/null -w 'codigo=%{http_code} tiempo=%{time_total}s bytes=%{size_download}\n' \
  http://localhost:8080/get
# codigo=200 tiempo=0.001204s bytes=245
```

Las que más se usan esta semana:

| Variable | Qué da |
|---|---|
| `%{http_code}` | El código de estado. La más usada de todas |
| `%{time_total}` | Tiempo total en segundos |
| `%{time_namelookup}` | Tiempo hasta resolver el DNS |
| `%{time_connect}` | Tiempo hasta tener el socket TCP |
| `%{time_starttransfer}` | Tiempo hasta el primer byte del cuerpo |
| `%{size_download}` | Bytes del cuerpo recibidos |
| `%{url_effective}` | La URL final, tras defaults y redirects |
| `%{num_redirects}` | Cuántos saltos hubo |
| `%{content_type}` | El `Content-Type` de la respuesta |

El desglose de los `time_*` es acumulativo: cada uno mide desde el inicio, no
desde el anterior. Restándolos sale dónde se fue el tiempo, y eso es la
Semana 09.

> [!IMPORTANT]
> Los nombres no se adivinan. `%{time_total}` existe; `%{total_time}` no. Si te
> equivocas, curl avisa por stderr y no imprime nada:
>
> ```bash
> curl -s -o /dev/null -w '%{total_time}' http://localhost:8080/get
> # curl: unknown --write-out variable: 'total_time'
> ```
>
> La lista completa de tu binario: `curl --manual` y busca `--write-out`.

curl **no añade un salto de línea**: el `\n` final lo pones tú, o la siguiente
línea de la terminal se pega al resultado.

---

## 6. `--max-time`: el que no es opcional

curl **no tiene timeout por defecto** en la transferencia. Si el servidor acepta
la conexión y luego no dice nada, curl espera. Para siempre.

```bash
# El laboratorio tarda 5 segundos a proposito. Con 2 de limite, curl se rinde.
curl -s -o /dev/null --max-time 2 http://localhost:8080/delay/5 ; echo "exit=$?"
# exit=28
```

El 28 es `Operation timeout`. Dos opciones, y no son la misma:

| Opción | Limita |
|---|---|
| `--connect-timeout` | Solo la fase de conexión |
| `--max-time` | **Toda** la operación, conexión incluida |

En un script van las dos: `--connect-timeout` corto para detectar rápido un host
caído, y `--max-time` generoso para no cortar una descarga legítima.

```bash
curl -sS --connect-timeout 5 --max-time 30 http://localhost:8080/get -o /dev/null
```

Un cron sin `--max-time` es un proceso que un día no termina, y otro proceso
que se le solapa encima.

---

## 7. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `-s` solo, en un script | Convierte un fallo de red en salida vacía sin mensaje | `-sS`, o `--no-progress-meter` |
| `-i` dentro de un pipe a `jq` | Los headers entran en el JSON y `jq` falla con un error críptico | `-s` para el pipe, `-i` solo para mirar |
| `-I` para "ver los headers" de una API | Es un `HEAD`: puede responder distinto, o con 405 | `-s -o /dev/null -D -` |
| Un `curl` en un cron sin `--max-time` | Un servidor colgado cuelga el cron, y mañana hay dos | `--connect-timeout` + `--max-time` siempre |
| Escribir `-w '%{http_code}'` sin `\n` | El resultado se pega a lo siguiente que imprima la terminal | `-w '%{http_code}\n'` |
| Inventarse el nombre de una variable de `-w` | curl avisa por stderr y no imprime nada. En un script, campo vacío | Comprobarlo con `curl --manual` |

---

## 8. Trucos

- **Todo en JSON de una vez** (7.70+), con las 39 variables:

  ```bash
  curl -s -o /dev/null -w '%{json}' http://localhost:8080/get | jq 'keys | length'
  # 39
  ```

- **Un formato largo desde un archivo**, para no ensuciar el comando:

  ```bash
  # Ojo: dentro del archivo el salto de linea se escribe \n literal, no un
  # salto de verdad. Por eso el printf lleva \\n.
  printf 'codigo:  %%{http_code}\\ntiempo:  %%{time_total}s\\n' > formato.txt
  curl -s -o /dev/null -w @formato.txt http://localhost:8080/get
  # codigo:  200
  # tiempo:  0.000995s
  ```

- **`-w` también entiende `%{stderr}`**: lo que va después sale por stderr, así
  las métricas no contaminan el pipe.

  ```bash
  curl -s -w '%{stderr}HTTP %{http_code}\n' http://localhost:8080/get | jq -r '.url'
  ```

- **Los flags cortos se agrupan**: `-sSL` es `-s -S -L`. Solo el último puede
  llevar argumento, así que `-so archivo` funciona y `-os archivo` no.

---

## 📚 Recursos Adicionales

- [curl — manpage, sección `-w`](https://curl.se/docs/manpage.html#-w) — la lista oficial de variables
- [everything.curl.dev — Write out](https://everything.curl.dev/usingcurl/verbose/writeout) — con ejemplos
- [Códigos de salida de curl](https://curl.se/libcurl/c/libcurl-errors.html) — qué significa el 28, el 6 y los demás

---

## ✅ Checklist de Verificación

- [ ] Distingues `*`, `>` y `<` en la salida de `-v`
- [ ] Explicas la diferencia entre `-i`, `-I` y `-D -`
- [ ] Reproduces el fallo silencioso de `-s` y lo arreglas con `-sS`
- [ ] Sigues un redirect con `-L` y ves `%{num_redirects}` y `%{url_effective}`
- [ ] Sacas código, tiempo y tamaño de una petición con un solo `-w`
- [ ] Provocas un timeout con `--max-time 2` contra `/delay/5` y obtienes el 28
