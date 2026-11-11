# Rate limit y backoff

> Una API pública no te deja hacer todas las peticiones que quieras: te da un
> cupo, y cuando lo gastas responde 429. Lo que haga tu script entonces
> decide si espera y sigue, si se rinde con un mensaje útil, o si insiste
> hasta que la API lo bloquea entero.

![Diagrama de un bucle de backoff: una petición que recibe 429, la decisión de cuánto esperar (el Retry-After de la respuesta si lo trae; si no, una espera que se dobla en cada intento, con un tope y un poco de azar), la espera, y el reintento; a la derecha, tres clientes que reintentan a la vez sin azar y vuelven a chocar, frente a tres con azar que se reparten en el tiempo](../0-assets/07-rate-limit-y-backoff.svg)

## 🎯 Objetivos

- Leer un 429 y su `Retry-After`, en segundos o en fecha
- Usar los headers de cupo para ir más despacio antes de que te corten
- Escribir un bucle de backoff exponencial con tope y azar
- Saber cuándo basta `--retry` y cuándo hace falta el bucle propio

---

## 1. Qué problema resuelve

```bash
curl -sS -D - -o /dev/null https://api.github.com/rate_limit | grep -i '^x-ratelimit'
# x-ratelimit-limit: 60
# x-ratelimit-remaining: 57
# x-ratelimit-used: 3
# x-ratelimit-resource: core
# x-ratelimit-reset: 1794363825
```

Sin token, GitHub te deja 60 peticiones por hora. Un `fetch-all` sobre un
listado de 80 páginas se queda sin cupo en la 60. Lo que pase después depende
del script:

- **Uno ingenuo** trata el 403 o el 429 como un error cualquiera, sale, y
  tira las 60 páginas que ya tenía.
- **Uno insistente** reintenta sin esperar, gasta peticiones que la API
  cuenta como abuso, y consigue que lo bloqueen más tiempo.
- **Uno robusto** lee cuándo se renueva el cupo, espera o se rinde con un
  mensaje que lo dice, y nunca empeora la situación.

---

## 2. Cómo funciona

### 2.1 429 y `Retry-After`

`429 Too Many Requests` es el código del rate limit. Suele llegar con
`Retry-After`, que dice cuándo volver. Según RFC 9110, el header admite **dos
formas**:

```
Retry-After: 120
Retry-After: Wed, 21 Oct 2026 07:28:00 GMT
```

Segundos de espera, o la fecha en la que puedes volver. Un `503 Service
Unavailable` también puede traerlo: el servidor está en mantenimiento y te
dice hasta cuándo.

El laboratorio lo reproduce en `/limitado`:

```bash
export CA="$PWD/docs/lab-ca.pem"
curl -sS --cacert "$CA" -i https://localhost:8443/limitado | tr -d '\r' \
  | grep -iE '^HTTP|^retry-after|^\{'
# HTTP/2 429
# retry-after: 1
# {"error":"demasiadas peticiones"}
```

curl `--retry` respeta `Retry-After` desde 7.66 (teoría 06). Lo que sigue es
para cuando reintentas tú.

### 2.2 Los headers del cupo

Muchas APIs dicen **antes** de cortarte cuánto te queda. No hay un estándar
cerrado, y los nombres varían:

| API | Límite | Restantes | Cuándo se renueva |
|---|---|---|---|
| GitHub | `x-ratelimit-limit` | `x-ratelimit-remaining` | `x-ratelimit-reset`: segundos desde 1970 (epoch) |
| Muchas otras | `X-RateLimit-Limit` | `X-RateLimit-Remaining` | `X-RateLimit-Reset`: epoch o segundos que faltan, según la API |
| Borrador del IETF | `RateLimit-Policy` | `RateLimit` | Dentro del propio `RateLimit` |

La columna de la derecha es la que más confunde: `Reset: 60` puede ser "dentro
de 60 segundos" o "el 1 de enero de 1970 a las 00:01". Lee la documentación de
tu API antes de hacer la cuenta.

GitHub, además, puede responder **403** en vez de 429 cuando se te acaba el
cupo principal, con `x-ratelimit-remaining: 0`. Un script que solo mira el 429
no lo ve.

### 2.3 Backoff exponencial

Sin `Retry-After`, la espera la decides tú. Esperar siempre lo mismo es mala
idea: si la API está saturada, un segundo después lo seguirá estando. La
estrategia estándar dobla la espera en cada intento, con un tope:

```
intento 1: espera 1 s
intento 2: espera 2 s
intento 3: espera 4 s
intento 4: espera 8 s
...hasta el tope, por ejemplo 60 s
```

Es lo que hace curl con `--retry`. Da tiempo a que el problema se pase y gasta
pocas peticiones mientras tanto.

### 2.4 El azar (*jitter*)

Mil clientes que reciben un 503 a la vez y esperan exactamente 1, 2 y 4
segundos vuelven a llegar **a la vez**, tres veces. El servidor recibe tres
picos en vez de un tráfico repartido. Se arregla sumando un poco de azar a
cada espera:

```bash
# intento 0, 1, 2...: 1 s, 2 s, 4 s... mas entre 0 y 999 ms de azar
espera_ms=$(( (1000 << intento) + RANDOM % 1000 ))
sleep "$(printf '%d.%03d' $((espera_ms / 1000)) $((espera_ms % 1000)))"
```

`$RANDOM` da un entero entre 0 y 32767. bash solo hace aritmética entera, así
que el azar se suma en milisegundos y se convierte a segundos con decimales
para `sleep`. curl no añade azar a sus esperas: es una de las razones para
escribir el bucle propio en un cliente que corre en muchas máquinas a la vez.

### 2.5 El orden de las decisiones

Ante un 429 o un 503:

1. **¿Trae `Retry-After`?** Espera eso. La API sabe más que tu fórmula.
2. **¿Es mayor que lo que estás dispuesto a esperar?** Ríndete ya, con un
   código de salida temporal (75) y el valor en el mensaje. Quien te llamó
   decidirá.
3. **¿No lo trae?** Backoff exponencial con tope y azar.
4. **¿Se agotaron los intentos?** Lo mismo que en el punto 2.

---

## 3. Cómo se usa

### 3.1 Un bucle de backoff en bash

```bash
# con_backoff MAX_INTENTOS URL
# Pide URL hasta que no responda 429 ni 503. Deja el cuerpo en respuesta.json.
con_backoff() {
  local max="$1" url="$2" intento=0 codigo espera

  while :; do
    codigo=$(curl -sS --max-time 10 -o respuesta.json -D cab.txt \
      -w '%{http_code}' "$url")
    case "$codigo" in
      429|503) ;;
      *) echo "$codigo"; return 0 ;;
    esac

    intento=$((intento + 1))
    if [ "$intento" -ge "$max" ]; then
      echo "rendido tras $intento intentos ($codigo)" >&2
      return 75
    fi

    espera=$(tr -d '\r' < cab.txt | awk 'tolower($1) == "retry-after:" { print $2 }')
    case "$espera" in
      ''|*[!0-9]*) espera=$(( (1 << (intento - 1)) + RANDOM % 2 )) ;;
    esac
    if [ "$espera" -gt 30 ]; then
      echo "la API pide ${espera}s; me rindo" >&2
      return 75
    fi
    echo "intento $intento: $codigo, espero ${espera}s" >&2
    sleep "$espera"
  done
}

con_backoff 5 'http://localhost:8080/status/200:0.3,429:0.7'
# intento 1: 429, espero 1s
# intento 2: 429, espero 2s
# 200
```

La salida es aleatoria: `/status/200:0.3,429:0.7` responde 200 tres de cada
diez veces. El `*[!0-9]*` descarta un `Retry-After` vacío o en forma de fecha
y cae al backoff propio; el azar es de segundos enteros para que el ejemplo
quepa en una línea. El `if` de los 30 s es el punto 2 del apartado 2.5: un
`Retry-After: 86400` no puede dejar un cron dormido un día.

### 3.2 `Retry-After` en forma de fecha

```bash
retry_after='Wed, 21 Oct 2026 07:28:00 GMT'
espera=$(( $(date -d "$retry_after" +%s) - $(date +%s) ))
[ "$espera" -gt 0 ] || espera=0
```

`date -d` es de GNU (Linux, WSL). En macOS, `date -j -f '%a, %d %b %Y %T %Z'`.
Si la fecha ya pasó, la resta es negativa: no esperes nada.

### 3.3 Ir despacio antes del 429

```bash
restantes=$(tr -d '\r' < cab.txt | awk 'tolower($1) == "x-ratelimit-remaining:" { print $2 }')
reset=$(tr -d '\r' < cab.txt | awk 'tolower($1) == "x-ratelimit-reset:" { print $2 }')

if [ "${restantes:-1}" -eq 0 ]; then
  echo "cupo agotado; se renueva en $(( reset - $(date +%s) )) s" >&2
  exit 75
fi
```

Un script que recorre muchas páginas puede mirar estos headers en cada
respuesta y parar **antes** de recibir el error, con el listado incompleto
pero sin haber gastado peticiones que la API cuenta como abuso.

### 3.4 Qué hace el toolkit

`api-toolkit` no lleva un bucle propio: para `GET`, `PUT` y `DELETE` confía en
`--retry`, que ya hace backoff y respeta `Retry-After`. Lo que añade la capa 7
es lo que pasa **después**: si tras los reintentos la respuesta sigue siendo
429, 502, 503 o 504, sale con 75 y pone el `Retry-After` en el mensaje. Quien
lo llama desde un cron sabe que "más tarde" puede funcionar, y cuándo.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Reintentar un 429 sin esperar | La API lo cuenta como abuso y alarga el bloqueo | `Retry-After`, o backoff |
| Ignorar `Retry-After` y usar tu fórmula | La API sabe cuándo se renueva el cupo; tu fórmula no | El header manda |
| Espera fija sin azar en un cliente que corre en muchas máquinas | Todos vuelven a la vez | Jitter |
| Backoff sin tope | La espera se dobla hasta horas | Tope, y rendirse con 75 |
| Tratar el 429 como un error definitivo (salir con 1) | Quien llama no sabe que repetir más tarde funciona | Código temporal: 75 |
| Mirar solo el 429 en GitHub | Su cupo agotado puede llegar como 403 con `remaining: 0` | Mira también los headers |
| Suponer que `X-RateLimit-Reset` es epoch | En algunas APIs son los segundos que faltan | La documentación de la API |

---

## 5. Trucos

- **`sleep` acepta decimales** en GNU coreutils y en macOS: `sleep 0.5`.
- **Un token sube el cupo**: GitHub pasa de 60 a 5000 peticiones por hora
  con uno. Antes de optimizar el backoff, mira si el cupo es el problema.
- **`/rate_limit` de GitHub no gasta cupo**: consúltalo antes de un
  `fetch-all` largo.

---

## 📚 Recursos Adicionales

- [RFC 9110 — Retry-After](https://www.rfc-editor.org/rfc/rfc9110#field.retry-after)
- [RFC 6585 — 429 Too Many Requests](https://www.rfc-editor.org/rfc/rfc6585#section-4)
- [GitHub — Rate limits for the REST API](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api)
- [AWS Architecture Blog — Exponential Backoff And Jitter](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/)

---

## ✅ Checklist de Verificación

- [ ] Lees el `Retry-After` de `/limitado` con `awk` y sin el `\r`
- [ ] Conviertes un `Retry-After` en fecha a segundos de espera
- [ ] Tu bucle de backoff dobla la espera, tiene tope y suma azar
- [ ] Sabes por qué el toolkit sale con 75 ante un 429 y no con 1
