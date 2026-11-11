# Los reintentos de curl, por dentro

> La Semana 05 presentó `--retry` como la red de seguridad ante la red
> hostil. Esta semana toca ver lo que hace exactamente: qué reintenta, cuánto
> espera, qué escribe en cada intento y en qué se equivoca si no le preparas
> la salida.

![Línea de tiempo de curl --retry 3 contra un servidor que responde 503: cuatro intentos separados por esperas de 1, 2 y 4 segundos, siete en total; debajo, lo que queda en cada destino tras los cuatro intentos: stdout con los cuatro cuerpos concatenados, el archivo de -D con los cuatro bloques de headers, y el archivo de -o con solo el cuerpo del último intento](../0-assets/06-reintentos-de-curl.svg)

## 🎯 Objetivos

- Saber qué errores reintenta curl y cuáles no
- Calcular cuánto puede tardar un `--retry N` antes de rendirse
- Entender qué queda en stdout, en `-D` y en `-o` después de varios intentos
- Decidir qué peticiones pueden llevar `--retry` y cuáles no

---

## 1. Qué problema resuelve

```bash
export CA="$PWD/docs/lab-ca.pem"
curl -sS --retry 2 --cacert "$CA" https://localhost:8443/limitado; echo
# {"error":"demasiadas peticiones"}{"error":"demasiadas peticiones"}{"error":"demasiadas peticiones"}
```

Tres intentos, tres cuerpos, uno detrás de otro en stdout. Si la API hubiera
contestado 503 en el primer intento y 200 en el segundo, la salida sería el
error **pegado** a los datos buenos: un JSON inválido, o peor, uno válido que
no es el que pediste.

`--retry` es útil, pero no es transparente. Hay que saber qué hace para que
lo que queda al final sea solo la respuesta buena.

---

## 2. Cómo funciona

### 2.1 Qué es un error transitorio

`--retry N` reintenta hasta N veces si el intento acaba en un **error
transitorio**:

| Reintenta | No reintenta |
|---|---|
| Timeout (28) | DNS (6): el nombre no va a aparecer en un segundo |
| HTTP 408, 429, 500, 502, 503, 504 | Cualquier otro 4xx: 400, 401, 403, 404, 422... |
| Conexión rechazada (7), **solo con `--retry-connrefused`** | Conexión rechazada sin ese flag |
| | Certificado inválido (60) |

```bash
curl --retry 1 -o /dev/null http://localhost:8080/status/404 2>&1 | grep -c Warning
# 0
curl --retry 1 -o /dev/null http://localhost:8080/status/503 2>&1 | tr '\r' '\n' | grep Warning
# Warning: Problem : HTTP error. Will retry in 1 seconds. 1 retries left.
```

El aviso `Warning: ... Will retry` va a stderr, y `-s` lo oculta: con `-sS`
los reintentos son **silenciosos**.

`--retry-all-errors` (7.71+) reintenta cualquier fallo. La propia
documentación lo llama "el mazo" y desaconseja usarlo por defecto: reintentar
un 400 da otro 400, y reintentar una subida con la entrada redirigida puede
mandar datos duplicados.

### 2.2 Cuánto espera

Sin más opciones, la primera espera es de **1 segundo** y cada una dobla la
anterior: 1, 2, 4, 8... hasta un máximo de 10 minutos entre intentos.

```bash
time curl -s --retry 3 -o /dev/null http://localhost:8080/status/503
# real  0m7,01s       1 + 2 + 4
```

Tres opciones lo cambian:

| Opción | Efecto | Ejemplo con `--retry 3` contra un 503 |
|---|---|---|
| `--retry-delay S` | Espera fija de S segundos, sin backoff | `--retry-delay 1`: 3 s |
| `--retry-max-time S` | No **empieza** un reintento si ya han pasado S segundos | `--retry 5 --retry-max-time 2`: 3 s |
| `Retry-After` en la respuesta | curl espera lo que diga (7.66+) | `/limitado` manda `1`: 1 s entre intentos |

Lee bien la segunda fila: `--retry-max-time 2` acabó en **3** segundos.
curl decide antes de cada reintento si queda tiempo; si queda, espera lo que
toque aunque se pase. Para un tope duro de la operación entera, combínalo con
`--max-time`... sabiendo que `--max-time` limita **cada intento**, no la
suma.

### 2.3 Sin `--fail`, el último intento manda

```bash
curl -s --retry 3 -o /dev/null http://localhost:8080/status/503; echo $?
# 0
curl -s --retry 1 --fail-with-body -o /dev/null http://localhost:8080/status/503; echo $?
# 22
```

Después de agotar los reintentos, curl sale como saldría el último intento: un
503 sin `--fail` es 0. `--retry` no convierte nada en error; decide cuántas
veces intentarlo.

### 2.4 Qué queda en cada salida

Cada intento escribe su respuesta. Lo que pasa con lo anterior depende del
destino:

| Destino | Qué queda después de 3 intentos |
|---|---|
| stdout | Los tres cuerpos, concatenados. curl no puede borrar lo que ya escribió en una tubería |
| `-o archivo` | Solo el del último: curl **trunca** el archivo antes de cada reintento |
| `-D archivo` | Los tres bloques de headers, uno detrás de otro |
| `-w` | Una sola vez, al final, con los datos del último intento |

```bash
curl -sS --retry 2 --cacert "$CA" -o cuerpo.json -D cab.txt \
  https://localhost:8443/limitado
cat cuerpo.json; echo
# {"error":"demasiadas peticiones"}
tr -d '\r' < cab.txt | grep -c '^HTTP'
# 3
```

De ahí salen dos reglas que el toolkit aplica en la capa 7:

- **El cuerpo, a un archivo con `-o`**, nunca capturado de stdout, si la
  petición lleva `--retry`.
- **Los headers, leídos del último bloque** del archivo de `-D`. Cada línea
  `HTTP/` empieza un bloque nuevo.

En 7.81 hay además un fallo con `-o /dev/null`: si el cuerpo no está vacío,
el reintento intenta truncar `/dev/null`, no puede, y curl sale con
`(23) Failed to truncate file`. En 8.x está corregido. Si solo quieres el
`-w`, `-o` a un temporal funciona en todas.

### 2.5 Qué se puede reintentar

curl no mira el método: reintenta un `POST` igual que un `GET`.

```bash
curl --retry 1 -o /dev/null -X POST -d x http://localhost:8080/status/503 2>&1 \
  | tr '\r' '\n' | grep Warning
# Warning: Problem : HTTP error. Will retry in 1 seconds. 1 retries left.
```

Y un timeout no dice si el servidor procesó la petición antes de que se
cortara. Un `POST` que creó un pedido y tardó en contestar, reintentado, crea
**otro** pedido. Por eso el toolkit solo añade `--retry` a `GET`, `PUT` y
`DELETE`, que son idempotentes: repetirlos deja el servidor igual que hacerlos
una vez (Semana 02).

---

## 3. Cómo se usa

### 3.1 La línea de producción

```bash
curl -sS --fail-with-body --max-time 10 \
  --retry 3 --retry-max-time 30 --retry-connrefused \
  -o respuesta.json \
  https://api.ejemplo.com/v1/estado
```

- **`--max-time 10`** por intento: un servidor colgado no cuelga el script.
- **`--retry 3`**: 1 + 2 + 4 segundos de espera como mucho, más los intentos.
- **`--retry-max-time 30`**: aunque la API mande un `Retry-After` de diez
  minutos, curl no empieza un reintento pasados 30 segundos.
- **`--retry-connrefused`** (7.52+): un servicio que se está reiniciando
  rechaza conexiones durante un par de segundos.
- **`-o`**: un solo cuerpo, el del último intento.

### 3.2 Contar los reintentos

`%{num_retries}` es 8.9+. En 7.81, cuenta los avisos de stderr, sin `-s`:

```bash
curl --retry 3 -o cuerpo.json http://localhost:8080/status/503 2>&1 \
  | tr '\r' '\n' | grep -c 'Will retry'
# 3
```

### 3.3 Cuando `--retry` no basta

- **Un `POST` que se puede repetir**, porque la API acepta una clave de
  idempotencia (`Idempotency-Key`, como Stripe): curl no sabe que es seguro, y
  hay que reintentar a mano.
- **Un `Retry-After` más largo** que tu `--retry-max-time`: curl se rinde, y
  quizá prefieras esperar y avisar.
- **Un 200 con un cuerpo de error** (`{"ok": false}`): para curl es un éxito.

Los tres llevan a un bucle propio en bash, que es la teoría 07.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `cuerpo=$(curl --retry 3 ...)` | Los cuerpos de los intentos se concatenan | `-o archivo` y leer el archivo |
| `--retry` en un `POST` | Puede crear el recurso dos veces | Solo en métodos idempotentes |
| `--retry-all-errors` por defecto | Reintenta errores que no van a cambiar, y puede duplicar datos | `--retry`, y el resto a mano |
| `--retry 10` sin `--retry-max-time` | Hasta 1+2+...+512 s: casi 17 minutos | `--retry-max-time` |
| Leer el primer `HTTP/` del archivo de `-D` | Es el del primer intento, no el de la respuesta final | El último bloque |
| `-o /dev/null --retry` en 7.81 | Sale con 23 si el cuerpo no está vacío | `-o` a un temporal |

---

## 5. Trucos

- **`--retry-delay 1`** en pruebas: tiempos predecibles, sin esperar al
  backoff exponencial.
- **`-sS` oculta los reintentos.** Para verlos sin el medidor de progreso,
  `--no-progress-meter` y sin `-s`.
- **`--retry 0`** anula un `--retry` anterior en la misma línea: si una
  opción se repite, gana la última.

---

## 📚 Recursos Adicionales

- [Manpage: `--retry`](https://curl.se/docs/manpage.html#--retry)
- [everything.curl.dev — Retry](https://everything.curl.dev/usingcurl/downloads/retry.html)
- [Stripe — Idempotent requests](https://docs.stripe.com/api/idempotent_requests)

---

## ✅ Checklist de Verificación

- [ ] Sabes qué códigos reintenta curl y cuáles no
- [ ] Calculas el tiempo de un `--retry 3` contra un 503
- [ ] Reproduces los cuerpos concatenados en stdout, y el cuerpo único con `-o`
- [ ] Lees el último bloque de headers de un archivo de `-D`
- [ ] Sabes por qué el toolkit no reintenta un `POST`
