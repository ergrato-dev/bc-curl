# Reutilizar la conexión

> La forma más barata de acelerar un script que habla con una API no es un
> flag: es dejar de cerrar la conexión después de cada petición. Un curl con
> veinte URLs abre una conexión; un bucle con veinte curl abre veinte. Mismo
> resultado, varias veces el tiempo.

![Comparación entre un bucle bash que lanza un curl por petición, donde cada proceso abre y cierra su propia conexión con DNS, TCP y TLS, y un solo curl con varias URLs, que abre una conexión y la reutiliza para todas. Al pie, las tres formas de dar varias URLs a un mismo curl: en la línea, con --next y en un --config con líneas url y output](../0-assets/02-reutilizar-la-conexion.svg)

## 🎯 Objetivos

- Explicar qué es una conexión persistente y quién decide cerrarla
- Dar varias URLs a un mismo curl de tres formas: en la línea, con `--next` y
  en un `--config`
- Comprobar la reutilización con `%{num_connects}`
- Reconocer lo que la impide: procesos distintos, `Connection: close`, otro
  host
- No confundir la reutilización de HTTP con `--no-keepalive`

---

## 1. Qué problema resuelve

El script ingenuo:

```bash
while read -r id; do
  curl -s "https://api.ejemplo.com/items/$id"
done < ids.txt
```

Cada vuelta arranca un proceso curl nuevo. El proceso abre la conexión, hace
el handshake TLS, pide, recibe… y **muere**, y la conexión muere con él. La
vuelta siguiente vuelve a empezar de cero.

Con 200 ids y una API a 90 ms de RTT, son 200 handshakes: entre 40 y 60
segundos solo en abrir conexiones.

---

## 2. Cómo funciona

### 2.1 Conexión persistente

En HTTP/1.1, una conexión **sigue abierta** después de la respuesta salvo que
alguno de los dos lados diga `Connection: close`. curl guarda las conexiones
abiertas en un *pool*, y antes de abrir una nueva mira si ya tiene una al
mismo host, puerto y esquema.

La condición importante: **el pool vive dentro del proceso**. Dos curl
distintos no comparten nada, aunque se lancen uno detrás de otro.

### 2.2 Cómo saber si se reutilizó

Lo viste en la Semana 06 (teoría 04), al medir: `%{num_connects}` cuenta las conexiones **nuevas** que abrió esa
transferencia:

- `1`: abrió conexión. Pagó DNS, TCP y TLS.
- `0`: reutilizó una del pool.

Con `-v`, curl lo dice con palabras:

```
* Re-using existing connection! (#0) with host localhost
```

### 2.3 Tres formas de dar varias URLs a un curl

Las tres salieron ya: `--next` en la Semana 02 (teoría 03) y la lista en un
`--config` en la Semana 06 (teoría 08). Aquí se repasan por lo que importa
esta semana: las tres reutilizan la conexión.

**En la línea de comandos.** Las opciones valen para todas; cada `-o` se
empareja con una URL, en orden:

```bash
curl -s -o a.json -o b.json https://api/a https://api/b
```

**Con `--next` (7.36.0+)**, también `-:`. Separa operaciones con opciones
distintas: un GET y luego un POST, cada uno con sus headers. La conexión se
reutiliza igual:

```bash
curl -s -o /dev/null -w '%{num_connects}\n' http://localhost:8080/get \
  --next -s -o /dev/null -w '%{num_connects}\n' -X POST http://localhost:8080/post
# 1
# 0
```

Lo que va antes de `--next` no pasa a la siguiente operación: `-s`, `-o` y
`-w` se repiten.

**En un `--config`.** Cada `url = ...` añade una URL, y cada `output = ...` se
empareja con la URL de su posición, como en la línea:

```
url = "http://localhost:8080/get"
output = "/dev/null"
url = "http://localhost:8080/get"
output = "/dev/null"
```

```bash
curl -s -K lista.txt -w '%{num_connects}\n'
# 1
# 0
```

Es la que escala: la lista la escribe un bucle, y la línea de comandos no
crece. Además, en un `--config` las URLs no aparecen en `ps`.

### 2.4 Lo que impide reutilizar

| Causa | Por qué |
|---|---|
| Procesos distintos | El pool es del proceso: muere con él |
| `Connection: close` | Lo pide el cliente (`-H 'Connection: close'`) o lo responde el servidor |
| Otro host, puerto o esquema | `http://x` y `https://x` son conexiones distintas |
| El servidor cerró por inactividad | curl lo detecta al reutilizar y abre otra, sin error |
| HTTP/1.0 sin `keep-alive` | 1.0 cierra por defecto |

Con el laboratorio:

```bash
curl -s -o /dev/null -o /dev/null -H 'Connection: close' \
  -w '%{num_connects} ' http://localhost:8080/get http://localhost:8080/get
# 1 1
```

### 2.5 `--no-keepalive` no es lo que parece

El nombre engaña. `--no-keepalive` (7.18.0+) apaga el **keepalive de TCP**:
los paquetes vacíos que el sistema operativo manda en una conexión inactiva
para que un router no la olvide. **No** tiene nada que ver con la conexión
persistente de HTTP: con `--no-keepalive`, curl sigue reutilizando.

| Lo que quieres | Flag |
|---|---|
| Que curl no reutilice la conexión | `-H 'Connection: close'` |
| Que una conexión inactiva no muera en un NAT | `--keepalive-time 30` (7.18.0+) |
| Apagar las sondas TCP | `--no-keepalive` |

### 2.6 Y el toolkit

`api-toolkit.sh` lanza un curl por llamada: entre dos llamadas no hay
reutilización posible, y no la necesita, porque cada llamada es una petición.
Donde sí importa es en **`bench`**, que lanza N peticiones: las pone en un
solo `--config` y las manda en un solo curl (práctica 01).

`fetch-all` es el caso intermedio: cada página es un curl, porque la URL de la
siguiente solo se sabe al leer el `Link` de la anterior.

---

## 3. Cómo se usa

Bucle frente a una sola invocación, veinte peticiones HTTPS al laboratorio:

```bash
time (for i in $(seq 20); do
  curl --cacert docs/lab-ca.pem -s -o /dev/null https://localhost:8443/get
done)
# real    0m0,250s

for i in $(seq 20); do
  printf 'url = "https://localhost:8443/get"\noutput = "/dev/null"\n'
done > lista.txt
time curl --cacert docs/lab-ca.pem -s -K lista.txt
# real    0m0,030s
```

Ocho veces menos, y eso con el servidor en tu propia máquina. Contra una API
a 90 ms de RTT, el bucle pagaría veinte handshakes de 200-300 ms cada uno.

---

## 4. Antipatrones

- **Un curl por vuelta de bucle** cuando todas las peticiones van al mismo
  host. Genera la lista y lanza un curl.
- **`--no-keepalive` para "cerrar la conexión"**: no la cierra.
- **Poner las URLs con credenciales en la línea**: con veinte URLs, la línea es
  enorme y está entera en `ps`. El `--config` las saca de ahí.
- **Asumir que la conexión vive para siempre.** El servidor la cierra tras unos
  segundos de inactividad (en nginx, 75 s por defecto). Un script que
  "guarda" la conexión entre llamadas espaciadas no gana nada.
- **Mezclar hosts y esperar reutilización.** Cada host tiene su conexión, y el
  pool tiene un tamaño limitado: muchos hosts alternados se expulsan unos a
  otros. Agrupa las peticiones por host.

---

## 5. Trucos

- **`-w` se aplica a cada transferencia**: con N URLs imprime N líneas. Es la
  forma de medir N peticiones con un solo proceso.
- **`-K -`** lee el `--config` de stdin: `generar_lista | curl -K -` sin
  archivo temporal.
- **`--remote-name-all`** (7.19.0+) guarda cada URL con su nombre remoto sin
  escribir un `-O` por URL.
- **Para forzar una conexión nueva en una prueba**, `-H 'Connection: close'`.
  Es la forma de medir "el peor caso" con el mismo comando.
- **`-v` con varias URLs** dice qué conexión usa cada una: `Connection #0`,
  `Re-using existing connection`.

---

## 📚 Recursos Adicionales

- [Everything curl — Connection reuse](https://everything.curl.dev/transfers/conn/reuse.html)
- [Everything curl — Config file](https://everything.curl.dev/cmdline/configfile.html)
- [RFC 9112, apartado 9 — Connection Management](https://datatracker.ietf.org/doc/html/rfc9112#section-9)

---

## ✅ Checklist de Verificación

- [ ] Explicas por qué un bucle de curl no reutiliza la conexión
- [ ] Das varias URLs a un curl en la línea, con `--next` y con `--config`
- [ ] Compruebas la reutilización con `%{num_connects}`
- [ ] Fuerzas una conexión nueva con `Connection: close`
- [ ] Explicas la diferencia entre `--no-keepalive` y la conexión persistente
