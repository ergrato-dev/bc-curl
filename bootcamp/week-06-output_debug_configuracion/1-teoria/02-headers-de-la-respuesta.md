# Los headers de la respuesta

> El cuerpo dice qué te devolvieron; los headers dicen cómo interpretarlo, cuánto
> tiempo vale y a dónde ir después. Leerlos bien desde un script tiene dos
> trampas: van pegados al cuerpo, y cada línea acaba en un `\r` invisible.

![Diagrama de una respuesta HTTP partida en dos: la línea de estado y los headers, cada uno terminado en CR LF, y después una línea vacía y el cuerpo; -i los manda juntos a stdout, -D archivo manda los headers a un archivo y deja el cuerpo en stdout, -I pide solo los headers con un HEAD](../0-assets/02-headers-de-la-respuesta.svg)

## 🎯 Objetivos

- Elegir entre `-i`, `-I` y `-D` según lo que necesites después
- Separar los headers del cuerpo sin cortar a mano por la línea vacía
- Extraer el valor de un header sin que el `\r` final rompa la comparación
- Saber qué pasa con los headers cuando hay redirects por medio
- Usar `%header{nombre}` cuando tu curl lo tenga, y la alternativa cuando no

---

## 1. Qué problema resuelve

Un script tiene que guardar el `ETag` de un recurso para pedirlo después solo
si cambió. La primera versión:

```bash
etag=$(curl -si http://localhost:8080/response-headers?ETag=abc123 | grep -i '^etag' | cut -d' ' -f2)
[ "$etag" = abc123 ] && echo igual || echo distinto
# distinto
```

El valor parece `abc123` al imprimirlo, pero la comparación falla. Y si el
recurso hubiera pasado por un redirect, habría dos bloques de headers y el
`grep` podría devolver el del primero.

---

## 2. Cómo funciona

### 2.1 Qué hay en el cable

Una respuesta HTTP/1.1 es texto con una forma fija:

```
HTTP/1.1 200 OK\r\n
Content-Type: application/json; charset=utf-8\r\n
Etag: abc123\r\n
Content-Length: 96\r\n
\r\n
{ ...el cuerpo... }
```

Cada línea de la cabecera termina en **CR LF** (`\r\n`), no en `\n` solo. Una
línea vacía separa la cabecera del cuerpo. curl entrega las líneas tal como
llegan, con su `\r`:

```bash
curl -s -D - -o /dev/null 'http://localhost:8080/response-headers?ETag=abc123' | cat -A | head -5
# HTTP/1.1 200 OK^M$
# Access-Control-Allow-Credentials: true^M$
# Access-Control-Allow-Origin: *^M$
# Content-Type: application/json; charset=utf-8^M$
# Etag: abc123^M$
```

Ese `^M` es el `\r`. La variable del primer ejemplo valía `abc123\r`: siete
caracteres, no seis. Por eso `[ "$etag" = abc123 ]` fallaba.

Y fíjate en el nombre: el script pidió `ETag` y el servidor (escrito en Go)
devuelve `Etag`. **Los nombres de header no distinguen mayúsculas.** Toda
comparación tiene que hacerse en minúsculas.

### 2.2 Tres formas de ver los headers

| Opción | Qué pide | Dónde van los headers | Cuándo |
|---|---|---|---|
| `-i` / `--include` | GET normal | stdout, delante del cuerpo | Mirar a ojo |
| `-I` / `--head` | `HEAD`: solo la cabecera | stdout | Ver headers sin bajar el cuerpo |
| `-D archivo` / `--dump-header` | GET normal | Al archivo; el cuerpo sigue en stdout | Scripts |

`-D -` manda los headers a stdout: con `-o /dev/null` al lado, obtienes solo los
headers de un GET sin mezclas.

> [!WARNING]
> `-I` no es "un GET sin cuerpo": es otro método. Hay servidores que responden
> distinto a un `HEAD`, o que no lo implementan. Si necesitas los headers que
> acompañan **a un GET**, usa `-D - -o /dev/null`.

### 2.3 `-X HEAD` no es `-I`

```bash
curl -s -X HEAD --max-time 3 -o /dev/null -w '%{http_code}\n' http://localhost:8080/get
echo "salida: $?"
# 200
# salida: 28
```

Con `-X HEAD` curl cambia la palabra del método, pero sigue esperando un cuerpo
de los `Content-Length` bytes que anuncia el servidor. El servidor, que sí
entendió `HEAD`, no lo manda. curl espera hasta el timeout. `-I` le dice a curl
que no habrá cuerpo; `-X` solo cambia una palabra.

### 2.4 Con redirects, un bloque por respuesta

```bash
curl -s -L -D cabeceras.txt -o /dev/null http://localhost:8080/redirect/2
grep -E '^HTTP|^Location' cabeceras.txt
# HTTP/1.1 302 Found
# Location: /relative-redirect/1
# HTTP/1.1 302 Found
# Location: /get
# HTTP/1.1 200 OK
```

`-D` (y `-i`) escriben los headers de **todas** las respuestas de la cadena,
una detrás de otra. El header que te interesa casi siempre es el del último
bloque.

---

## 3. Cómo se usa

### 3.1 Headers y cuerpo, cada uno a su archivo

```bash
curl -sS -D cabeceras.txt -o cuerpo.json http://localhost:8080/get
head -1 cabeceras.txt
# HTTP/1.1 200 OK
jq -r .url cuerpo.json
# http://localhost:8080/get
```

Nada de partir por la línea vacía con `sed`: curl ya lo separa.

### 3.2 El valor de un header, bien

```bash
# tr quita los \r, tolower compara sin mayusculas, y quedarse con la ultima
# coincidencia elige el bloque final si hubo redirects.
leer_header() {
  tr -d '\r' | awk -F': ' -v h="$1" 'tolower($1) == h { v = $2 } END { print v }'
}

etag=$(curl -s -D - -o /dev/null 'http://localhost:8080/response-headers?ETag=abc123' | leer_header etag)
[ "$etag" = abc123 ] && echo igual || echo distinto
# igual
```

### 3.3 `%header{nombre}`: curl lo hace por ti (7.84+)

Desde 7.84, `--write-out` sabe leer un header de la última respuesta, sin el
`\r` y sin distinguir mayúsculas:

```bash
# Requiere curl 7.84 o posterior.
curl -s -o /dev/null -w '%header{etag}\n' 'http://localhost:8080/response-headers?ETag=abc123'
# abc123
# En 7.81 no da error: imprime el texto tal cual, '%header{etag}'. Un script
# que compare ese valor nunca vera un fallo, solo un ETag que no coincide.
```

Fíjate en la sintaxis: es `%header{etag}`, **sin** llaves alrededor de
`header`, a diferencia del resto de variables. `%{header{etag}}` no existe.
Con un 7.81, la función `leer_header` de arriba hace lo mismo.

`%{header_json}` (7.83+) devuelve todos los headers de la última respuesta como
un objeto JSON, con cada valor en un array porque un header puede repetirse.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `grep '^ETag'` | El servidor puede escribir `Etag` o `etag` | `tolower($1) == "etag"` |
| Comparar el valor sin quitar el `\r` | Nunca es igual a lo que esperas | `tr -d '\r'` antes de nada |
| `curl -i ... \| jq` | `jq` recibe los headers primero y falla | `-D archivo` y el cuerpo solo en stdout |
| `-X HEAD` | curl espera un cuerpo que no llega | `-I` |
| `-I` para saber qué headers acompañan a un GET | Es otro método; la respuesta puede diferir | `-D - -o /dev/null` |
| Leer el primer bloque con `-L` | Es el header del redirect, no del destino | La última coincidencia, o `%header{}` |

---

## 5. Trucos

- **`-D -` con `-o /dev/null`** es la forma más directa de ver los headers
  exactos de un GET.
- **`-w '%{num_headers}'`** (7.73+) dice cuántos headers trajo la última
  respuesta. Útil para detectar un proxy que añade o quita.
- **`-w '%{content_type}'`** devuelve el `Content-Type` sin parsear nada, en
  cualquier versión.
- **Los headers de la petición no están aquí**: los que *envías* se ven con
  `-v` (teoría 05), en las líneas que empiezan por `>`.

---

## 📚 Recursos Adicionales

- [RFC 9110 §5 — Field syntax](https://datatracker.ietf.org/doc/html/rfc9110#section-5)
- [RFC 9112 §2.1 — Message format, CRLF](https://datatracker.ietf.org/doc/html/rfc9112#section-2.1)
- [everything.curl.dev — Response headers](https://everything.curl.dev/http/response.html)
- [Manpage: `--dump-header`](https://curl.se/docs/manpage.html#-D)

---

## ✅ Checklist de Verificación

- [ ] `curl -s -D - -o /dev/null URL | cat -A` enseña el `^M` al final de cada línea
- [ ] `leer_header etag` devuelve `abc123` y la comparación da `igual`
- [ ] Con `-L -D h.txt` sobre `/redirect/2` ves tres bloques de headers
- [ ] Explicas por qué `-X HEAD` acaba en un 28 y `-I` no
- [ ] Sabes si tu curl tiene `%header{}` y qué usar si no
