# Reintentos

> Un 503 a las tres de la mañana suele arreglarse solo en dos segundos. Un
> script que falla al primer error despierta a alguien por nada; uno que
> reintenta un POST puede cobrar dos veces. `--retry` resuelve lo primero, y
> lo segundo es cosa tuya.

![Diagrama de una petición con --retry 3: el primer intento recibe un 503, curl espera 1 segundo, el segundo intento recibe otro 503, espera 2, el tercero un timeout, espera 4, y el cuarto un 200; debajo, qué errores reintenta curl por defecto (timeout, 408, 429, 500, 502, 503, 504) y cuáles no (conexión rechazada, 404, error TLS), con los flags que amplían la lista](../0-assets/08-reintentos.svg)

## 🎯 Objetivos

- Saber qué errores considera curl "transitorios" y reintenta con `--retry`
- Entender la espera por defecto entre intentos y cómo cambiarla
- Acotar el tiempo total con `--retry-max-time`
- Ampliar lo que se reintenta con `--retry-connrefused` y `--retry-all-errors`
- Decidir qué peticiones se pueden reintentar: la idempotencia

---

## 1. Qué problema resuelve

Muchos fallos son momentáneos: un despliegue que reinicia los pods, un
balanceador que aún no ve el nodo nuevo, un límite de peticiones que se libera
al segundo siguiente. La misma petición, repetida un poco después, funciona.

Repetirla a mano en un script es un bucle con `sleep` y lógica de códigos de
salida que todo el mundo escribe distinto y casi siempre mal. curl lo trae
hecho.

---

## 2. Cómo funciona

### 2.1 Qué reintenta `--retry`

```bash
curl -s --retry 3 -o /dev/null -w '%{http_code}\n' http://localhost:8080/status/503
```

`--retry N` repite la petición hasta N veces más si el error es
**transitorio**. Para curl lo son:

| Error | Ejemplo |
|---|---|
| Timeout (código 28) | `--max-time` o `--connect-timeout` vencidos |
| HTTP `408` | Request Timeout |
| HTTP `429` | Too Many Requests |
| HTTP `500` | Internal Server Error |
| HTTP `502`, `503`, `504` | Bad Gateway, Service Unavailable, Gateway Timeout |

Y **no** lo son, aunque a veces lo parezcan:

| Error | Por qué no | Cómo incluirlo |
|---|---|---|
| Conexión rechazada (código 7) | Un puerto cerrado suele seguir cerrado | `--retry-connrefused` (7.52+) |
| Cualquier otro 4xx | `404`, `401`: repetir no cambia nada | `--retry-all-errors` (7.71+), con cuidado |
| Errores TLS (35, 60...) | Un certificado que no valida no se arregla solo | No se deben reintentar |

Ojo: `--retry` reintenta los códigos HTTP de la tabla **con o sin** `--fail`.
Sin `--fail`, si el último intento vuelve a dar 503, curl sale con 0 y el
cuerpo del 503: el reintento no te salva de mirar el código.

### 2.2 La espera entre intentos

Por defecto, curl espera **1 segundo** antes del primer reintento y dobla la
espera en cada uno, hasta un máximo de 10 minutos. Sin `-s` lo cuenta:

```bash
curl --retry 3 -o /dev/null http://localhost:8080/status/503 2>&1 \
  | grep -o 'Will retry in [0-9]* seconds'
# Will retry in 1 seconds
# Will retry in 2 seconds
# Will retry in 4 seconds
```

Con `-s` el aviso desaparece. Con `-sS` también: `-S` solo devuelve los
**errores**, y un aviso de reintento no lo es. `--no-progress-meter` (7.67+)
quita la barra de progreso y conserva los avisos.

`--retry-delay N` sustituye la espera creciente por una **fija** de N segundos.
Casi nunca es mejor: la espera creciente es la que da tiempo a un servicio
saturado a recuperarse.

### 2.3 Cuánto puede tardar en total

Cada intento tiene su propio `--max-time`. Con `--retry 3 --max-time 2`
contra un servidor que nunca responde:

```
4 intentos × 2 s  +  esperas 1 + 2 + 4 s  =  15 s
```

`--retry-max-time N` acota el conjunto: no empieza un reintento nuevo si han
pasado más de N segundos desde el principio.

```bash
s=$(date +%s)
curl -s --retry 5 --max-time 2 --retry-max-time 4 \
  http://localhost:8080/delay/5 -o /dev/null
echo "codigo: $? en $(( $(date +%s) - s )) s"
# codigo: 28 en 5 s
```

Sin `--retry-max-time`, esos 5 reintentos habrían tardado más de 40 s.

### 2.4 Cuántos intentos hizo

curl 8.9 añadió `%{num_retries}` a `--write-out`. En 7.81 **no existe**: curl
sale con `unknown --write-out variable`. La alternativa es contar los avisos
de stderr sin `-s`.

---

## 3. Cómo se usa

### 3.1 Idempotencia: qué se puede reintentar

curl no sabe qué hace tu petición. Si un `POST /pagos` da timeout, el pago
puede haberse hecho (el servidor procesó, la respuesta se perdió). Repetirlo
crea un segundo pago.

| Método | ¿Idempotente? | ¿Reintentar? |
|---|---|---|
| `GET`, `HEAD` | Sí: solo lee | Sí |
| `PUT` | Sí: deja el recurso igual cuantas veces se repita | Sí |
| `DELETE` | Sí: borrar lo borrado no cambia nada | Sí |
| `POST` | **No**: cada uno puede crear algo | Solo si la API acepta una clave de idempotencia |
| `PATCH` | Depende de la operación | Solo si sabes que lo es |

Algunas APIs aceptan un header `Idempotency-Key` con un valor único por
operación: si el POST llega dos veces con la misma clave, el servidor hace la
operación una sola vez. Sin eso, un POST no se reintenta automáticamente.

### 3.2 Una llamada de producción

```bash
curl --fail-with-body -sS \
  --connect-timeout 5 --max-time 10 \
  --retry 3 --retry-connrefused --retry-max-time 30 \
  http://localhost:8080/get
```

- `--retry 3`: hasta cuatro intentos.
- `--retry-connrefused`: un servicio reiniciando rechaza conexiones unos
  segundos; eso también es transitorio.
- `--retry-max-time 30`: el conjunto no pasa de unos 30 s más el último
  intento.

### 3.3 `--retry-all-errors`, con cuidado

Reintenta **cualquier** error, incluidos los 4xx que `--fail` convierte en el
código 22:

```bash
curl -s --fail --retry 2 --retry-all-errors -o /dev/null \
  http://localhost:8080/status/404; echo "codigo: $?"
# codigo: 22    (tras tres intentos)
```

Tiene sentido con servidores que devuelven códigos raros en fallos
transitorios. Por defecto, no: un 404 o un 401 repetidos solo retrasan el
fallo y multiplican la carga.

El 429 (`Too Many Requests`) merece su propio tratamiento: leer el
`Retry-After` y esperar lo que dice el servidor. Es de la Semana 07.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `--retry` en un POST que crea o cobra | Un timeout con éxito en el servidor se convierte en un duplicado | Solo métodos idempotentes, o `Idempotency-Key` |
| `--retry` sin `--max-time` | Cada intento puede colgarse para siempre: nunca llega a reintentar | `--max-time` siempre al lado |
| `--retry 10` sin `--retry-max-time` | Con esperas que se doblan, el último intento llega minutos después | `--retry-max-time` como techo |
| `--retry-delay 0` | Martillea a un servicio que ya está saturado | La espera creciente por defecto |
| `--retry-all-errors` "por si acaso" | Reintenta 401, 404 y errores TLS que no se arreglan solos | Solo `--retry`, más `--retry-connrefused` |
| Un bucle `for` con `sleep` alrededor de curl | Reinventa `--retry`, normalmente sin espera creciente y sin distinguir errores | `--retry` |

---

## 5. Trucos

```bash
# Simular un servicio que falla de forma transitoria.
curl --retry 2 -o /dev/null http://localhost:8080/status/503
```

```bash
# Simular un servicio caido que vuelve: nada escucha en el puerto 9.
curl -sS --retry 2 --retry-connrefused http://localhost:9/ -o /dev/null
```

```bash
# Contar intentos en curl 7.81, donde no existe %{num_retries}.
curl --retry 3 -o /dev/null http://localhost:8080/status/503 2>&1 \
  | grep -c 'Will retry'
# 3
```

---

## 📚 Recursos Adicionales

- [everything.curl.dev — Retry](https://everything.curl.dev/usingcurl/downloads/retry.html) — qué reintenta y cómo espera
- [manpage de curl — `--retry`](https://curl.se/docs/manpage.html#--retry) — la lista exacta de errores transitorios
- [manpage de curl — `--retry-all-errors`](https://curl.se/docs/manpage.html#--retry-all-errors) — y su advertencia
- [RFC 9110 §9.2.2 — Idempotent Methods](https://datatracker.ietf.org/doc/html/rfc9110#section-9.2.2) — qué métodos se pueden repetir
- [Stripe — Idempotent requests](https://docs.stripe.com/api/idempotent_requests) — un ejemplo real de `Idempotency-Key`

---

## ✅ Checklist de Verificación

- [ ] Sé qué errores reintenta `--retry` por defecto y cuáles no
- [ ] He visto la espera de 1, 2 y 4 segundos en los avisos de curl
- [ ] Sé calcular cuánto puede tardar en total una petición con reintentos
- [ ] He acotado el total con `--retry-max-time`
- [ ] Sé por qué un POST no se reintenta automáticamente
- [ ] Sé cuándo `--retry-connrefused` tiene sentido y cuándo no `--retry-all-errors`

---

| Anterior | Siguiente |
|---|---|
| [07 — Timeouts](07-timeouts.md) | [Prácticas](../2-practicas/01-confiar-y-verificar.md) |
