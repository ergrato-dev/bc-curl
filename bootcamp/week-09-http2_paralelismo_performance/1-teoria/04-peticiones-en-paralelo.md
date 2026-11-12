# Peticiones en paralelo

> Diez peticiones de un segundo, una detrás de otra, tardan diez segundos. A
> la vez, tardan uno. curl sabe hacerlas a la vez desde la 7.66 con un solo
> flag, `-Z`, sin `&`, sin `xargs` y sin procesos de más. Lo que hay que
> entender es cuántas a la vez, sobre cuántas conexiones, y qué hace la 7.81
> mientras decide.

![Tres formas de lanzar ocho peticiones a /delay/1: en serie, ocho segundos; con -Z y --parallel-max 4 sobre HTTP/1.1, cuatro conexiones y dos tandas, dos segundos; y con -Z sobre HTTP/2, una sola conexión con cuatro streams a la vez, también dos segundos. Debajo, la espera de curl 7.x antes de abrir más conexiones y cómo la quita --parallel-immediate](../0-assets/04-peticiones-en-paralelo.svg)

## 🎯 Objetivos

- Lanzar varias transferencias a la vez con `-Z` y limitar cuántas con
  `--parallel-max`
- Entender cómo reparte curl las transferencias entre conexiones en
  HTTP/1.1 y en HTTP/2
- Saber qué hace `--parallel-immediate` y cuándo ponerlo
- Leer el resultado de cada transferencia con `-w` y el código de salida del
  lote
- Elegir entre `-Z`, `xargs -P` y `&` con `wait`

---

## 1. Qué problema resuelve

Reutilizar la conexión (teoría 02) quita el handshake, pero las peticiones
siguen yendo **en serie**: la segunda sale cuando ha llegado la primera. Si el
servidor tarda 1 s en cada una, diez son diez segundos, con la conexión
reutilizada o sin ella.

Lo que falta es no esperar: mandar la segunda **mientras** la primera está en
el servidor.

---

## 2. Cómo funciona

### 2.1 `-Z` / `--parallel` (7.66.0+)

Con `-Z`, curl arranca todas las transferencias de la línea (o del `--config`)
a la vez, hasta un máximo, y va lanzando las que quedan según terminan las
anteriores.

```bash
curl -s -Z -o /dev/null -o /dev/null -o /dev/null \
  http://localhost:8080/delay/1 http://localhost:8080/delay/1 http://localhost:8080/delay/1
```

`-Z` es **global**: vale para todas las operaciones, aunque las separe
`--next`.

### 2.2 `--parallel-max` (7.66.0+)

El máximo de transferencias simultáneas. **Por defecto, 50.** Con 1000 URLs y
sin `--parallel-max`, curl abre 50 a la vez contra el mismo servidor: eso ya
es una prueba de carga, y la API puede responder con 429 o bloquearte.

Ocho peticiones de un segundo con un máximo de 4. `ocho-delays.txt` es un
`--config` con ocho pares `url = "http://localhost:8080/delay/1"` y
`output = "/dev/null"`, como en la teoría 02; `tres-delays.txt`, más abajo, lo
mismo con tres:

```bash
time curl -s -Z --parallel-max 4 -K ocho-delays.txt
# real    0m2,01s      ← dos tandas de cuatro
```

### 2.3 Cuántas conexiones: HTTP/1.1 frente a HTTP/2

- **HTTP/1.1**: una conexión lleva una petición a la vez. Para 4 en paralelo,
  curl abre **4 conexiones**. Cuando una termina, la siguiente transferencia
  la reutiliza.
- **HTTP/2**: una conexión lleva muchos streams. curl mete todas las
  transferencias **en la misma conexión** (hasta el `MAX_CONCURRENT_STREAMS`
  del servidor).

Se ve en `%{num_connects}`. Ocho peticiones con máximo 4:

```bash
# HTTP/1.1, http://
#   4 líneas con 1 (las cuatro primeras abren) y 4 con 0 (reutilizan)

# HTTP/2, https://
#   1 línea con 1 y 7 con 0: una sola conexión para todo
```

### 2.4 La espera de curl 7.x, y `--parallel-immediate` (7.68.0+)

Antes de abrir más conexiones, curl 7.x **espera a que la primera esté
establecida** para saber si podrá multiplexar. Tiene sentido en HTTPS: si el
servidor acepta h2, todo cabe en esa conexión y abrir más sería un
desperdicio.

Sobre `http://` esa espera no sirve de nada (no habrá HTTP/2), y en 7.81 tiene
un efecto que se mide: la primera transferencia sale sola, y las demás solo
arrancan cuando ella termina.

```bash
time curl -s -Z -K tres-delays.txt                        # http://
# real    0m2,01s      ← la primera sola, después las otras dos

time curl -s -Z --parallel-immediate -K tres-delays.txt   # http://
# real    0m1,01s      ← las tres a la vez
```

`--parallel-immediate` le dice a curl "abre conexiones nuevas sin esperar". La
regla:

| URL | `--parallel-immediate` |
|---|---|
| `http://` | **Sí**: no hay h2 que esperar |
| `https://` | **No**: la espera es lo que mete todo en una conexión h2. Con el flag, abre una conexión por transferencia |

Es lo que hace `bench` en el toolkit.

### 2.5 Una línea de `-w` por transferencia

Con `-Z`, cada transferencia escribe su `-w` **cuando termina**, no en el
orden de la línea. Para saber cuál es cuál, `%{urlnum}` (7.75.0+) da su
posición (desde 0) y `%{url_effective}` la URL:

```bash
curl -s -Z --parallel-max 2 -o /dev/null -o /dev/null -o /dev/null \
  -w '%{urlnum} %{http_code}\n' \
  http://localhost:8080/delay/1 http://localhost:8080/get http://localhost:8080/status/201
# 1 200
# 2 201
# 0 200
```

La 1 y la 2 terminan antes que la 0, que tarda un segundo.

### 2.6 El código de salida del lote

curl sale con 0 solo si **todas** las transferencias salieron bien. Con
`--fail`, un 404 en una de ellas basta para que el lote salga con 22. Pero
**no dice cuál**: eso está en las líneas del `-w`.

```bash
curl -s -Z -f -o /dev/null -o /dev/null -w '%{http_code}\n' \
  http://localhost:8080/status/404 http://localhost:8080/get; echo "exit $?"
# 404
# 200
# exit 22
```

Sin `-f`, un 500 no es un error para curl, y el lote sale con 0. Para un lote,
**cuenta los códigos del `-w`**: no te fíes del código de salida.

### 2.7 `-Z` frente a `xargs -P` y `&`

| Forma | Conexiones | Cuándo |
|---|---|---|
| `curl -Z` | Reutiliza y multiplexa | Muchas URLs, mismo host |
| `xargs -P 4 curl ...` | Una por proceso | Cada petición necesita su propio procesado |
| `curl ... &` y `wait` | Una por proceso | Dos o tres cosas distintas a la vez |

`xargs -P` y `&` lanzan **procesos**: cada uno con su conexión y su
handshake. Son la opción cuando lo que va en paralelo no es una petición, sino
un trozo de script (pedir, filtrar con jq, escribir un archivo).

---

## 3. Cómo se usa

Una lista de URLs en un `--config`, en paralelo y con el resultado de cada
una:

```bash
for id in 1 2 3 4 5 6; do
  printf 'url = "http://localhost:8080/anything/%s"\noutput = "/dev/null"\n' "$id"
done > lista.txt

curl -s -Z --parallel-max 3 --parallel-immediate -K lista.txt \
  -w '%{http_code} %{num_connects} %{url_effective}\n' | sort -k3
# 200 1 http://localhost:8080/anything/1
# 200 1 http://localhost:8080/anything/2
# ...
```

Con `--max-time` en la línea, el límite es **por transferencia**, no del
lote.

---

## 4. Antipatrones

- **`-Z` sin `--parallel-max` contra una API ajena.** 50 a la vez es una
  ráfaga que dispara el rate limit. Empieza por 4.
- **Confiar en el código de salida.** Sin `-f`, un lote con veinte 500 sale con
  0. Con `-f`, sabes que algo falló, no qué.
- **Suponer el orden del `-w`.** Llega por orden de terminación.
- **`--parallel-immediate` sobre HTTPS** cuando el servidor habla h2: abre una
  conexión por transferencia y pierde la multiplexación.
- **Paralelizar peticiones que dependen unas de otras.** Las páginas de un
  `Link: rel="next"` no se pueden pedir a la vez: la URL de la siguiente
  viene en la respuesta de la anterior.
- **`--rate` en 7.81.** Limita peticiones por minuto, pero llega en la 7.84.0.
  En 7.81 el freno es `--parallel-max`.

---

## 5. Trucos

- **Barra de progreso de lote.** Sin `-s`, `-Z` dibuja una tabla con
  transferencias vivas, completadas y bytes. Útil en descargas largas.
- **`-Z` con descargas**: `curl -Z --remote-name-all URL1 URL2 URL3` baja las
  tres a la vez con su nombre remoto.
- **`-K -` con un generador**, sin archivo: `seq 1 50 | awk '{print "url = \"http://localhost:8080/anything/" $1 "\""; print "output = \"/dev/null\""}' | curl -s -Z --parallel-max 4 -K - -w '%{http_code}\n'`.
  Un solo `-o` en la línea se emparejaría solo con la primera URL.
- **Un `--max-time` por transferencia** evita que una lenta retenga el lote.
- **Contar errores de un lote**: `... -w '%{http_code}\n' | grep -vc '^2'`.

---

## 📚 Recursos Adicionales

- [Everything curl — Parallel transfers](https://everything.curl.dev/cmdline/urls/parallel.html)
- [curl manpage — `--parallel`](https://curl.se/docs/manpage.html#-Z)
- [curl manpage — `--parallel-immediate`](https://curl.se/docs/manpage.html#--parallel-immediate)

---

## ✅ Checklist de Verificación

- [ ] Lanzas un lote con `-Z` y lo limitas con `--parallel-max`
- [ ] Explicas cuántas conexiones abre `-Z` en HTTP/1.1 y en HTTP/2
- [ ] Sabes cuándo poner `--parallel-immediate` y cuándo no
- [ ] Identificas cada transferencia del lote con `%{urlnum}` o `%{url_effective}`
- [ ] Cuentas los errores de un lote por el `-w`, no por el código de salida
