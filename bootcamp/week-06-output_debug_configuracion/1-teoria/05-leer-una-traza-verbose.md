# Leer una traza `-v`

> `-v` es la conversación entera entre curl y el servidor, contada por curl.
> Leerla bien es saber en qué línea se torció la petición. Compartirla mal es
> pegar tu token en un ticket.

![Diagrama de una traza -v con sus cuatro tipos de línea: las que empiezan por asterisco son lo que curl hace por su cuenta (resolver, conectar, TLS), las que empiezan por > son lo que envía, las que empiezan por < son lo que recibe, y las llaves marcan bloques de datos; a la derecha, las cinco fases y el tipo de fallo que aparece en cada una, con su código de salida](../0-assets/05-leer-una-traza-verbose.svg)

## 🎯 Objetivos

- Leer los cuatro tipos de línea de una traza `-v`
- Localizar la fase donde falló una petición por la última línea que llegó a escribirse
- Saber qué datos sensibles aparecen en una traza y en qué línea
- Tachar una traza antes de compartirla sin perder lo que la hace útil

---

## 1. Qué problema resuelve

`curl: (7) Failed to connect` dice qué pasó. No dice qué IP probó, si antes
probó otra, si había un proxy de por medio o si el nombre resolvió a algo que
no esperabas. Un `401` dice que la credencial no valió; no dice si curl llegó a
mandarla, ni con qué esquema, ni si un redirect la quitó por el camino.

La traza lo dice todo. Por eso es lo primero que se pide en un ticket, y por
eso es peligrosa: si dice todo, dice también la credencial.

---

## 2. Cómo funciona

### 2.1 Cuatro tipos de línea

```bash
curl -sS -v -o /dev/null http://localhost:8080/get
# *   Trying 127.0.0.1:8080...
# * Connected to localhost (127.0.0.1) port 8080 (#0)
# > GET /get HTTP/1.1
# > Host: localhost:8080
# > User-Agent: curl/7.81.0
# > Accept: */*
# >
# * Mark bundle as not supporting multiuse
# < HTTP/1.1 200 OK
# < Content-Type: application/json; charset=utf-8
# < Content-Length: 245
# <
# { [245 bytes data]
# * Connection #0 to host localhost left intact
```

| Marca | Qué es | De quién |
|---|---|---|
| `*` | Lo que curl hace por su cuenta: resolver, conectar, negociar TLS, decidir | curl |
| `>` | Lo que curl **envía**: línea de petición y headers | Tú, a través de curl |
| `<` | Lo que curl **recibe**: línea de estado y headers | El servidor |
| `{` / `}` | Un bloque de datos recibido / enviado, solo su tamaño | Cualquiera |

La traza va a **stderr**, así que `-v` no ensucia el cuerpo (teoría 01). Y
convive con `-s`: `-s` apaga el medidor y los errores, no la traza.

Las líneas `>` vacías y `<` vacías son la línea en blanco que separa los headers
del cuerpo. Si no ves la `>` vacía, la petición no llegó a terminar de
enviarse.

### 2.2 Dónde aparece cada fallo

La regla que lo ordena todo: **la petición avanza por fases, y la traza se
corta en la fase que falló.** La última línea `*` antes del error es el
diagnóstico.

| Fase | Última línea útil de la traza | Código |
|---|---|:--:|
| DNS | `* Could not resolve host: no-existe.invalid` | 6 |
| TCP | `* connect to 127.0.0.1 port 9 failed: Connection refused` | 7 |
| TCP, sin respuesta | `* Connection timeout after 2001 ms`, con `--connect-timeout 2` | 28 |
| TLS | `* SSL certificate problem: unable to get local issuer certificate` | 60 |
| HTTP | `< HTTP/1.1 401 Unauthorized`: la traza está completa, el fallo es de la API | 0 |
| Redirects | `* Maximum (2) redirects followed` | 47 |

Tres preguntas, en orden, localizan cualquier fallo:

1. **¿Hay alguna línea `* Connected to`?** Si no, el fallo es DNS o TCP.
2. **¿Hay alguna línea `>`?** Si no, el fallo es TLS: se conectó pero no
   llegó a hablar HTTP.
3. **¿Hay una línea `< HTTP/`?** Si sí, la conversación HTTP terminó y el
   problema lo dice el código de estado, no curl.

### 2.3 El handshake TLS en la traza

Sobre HTTPS la traza enseña el handshake y el certificado:

```bash
curl -sS -v -o /dev/null --cacert docs/lab-ca.pem https://localhost:8443/get 2>&1 \
  | grep -E 'SSL connection|ALPN, server|expire|subjectAltName|issuer|verify ok'
# * SSL connection using TLSv1.3 / TLS_AES_128_GCM_SHA256
# * ALPN, server accepted to use h2
# *  expire date: Nov 11 09:29:21 2026 GMT
# *  subjectAltName: host "localhost" matched cert's "localhost"
# *  issuer: CN=Caddy Local Authority - ECC Intermediate
# *  SSL certificate verify ok.
```

Versión de TLS, cifrado, protocolo negociado (`h2` es HTTP/2), caducidad,
nombre comprobado y emisor. La Semana 05 explicó cada uno; aquí lo importante
es saber que **están en la traza**, sin `openssl`.

Los textos exactos de las líneas `*` cambian entre versiones de curl y entre
backends TLS. Las marcas `*`, `>` y `<` no cambian. Un script que analice
trazas tiene que agarrarse a las marcas, no a las frases.

### 2.4 Qué filtra una traza

| Línea | Qué filtra |
|---|---|
| `> Authorization: Basic dXNlcjptYWw=` | Usuario y password: es base64, no cifrado. `user:mal` |
| `> Authorization: Bearer ...` | El token entero |
| `> X-API-Key: ...` (o el header que use tu API) | La clave |
| `> Cookie: sesion=...` | La sesión: vale tanto como la password |
| `< Set-Cookie: sesion=...` | La sesión que te acaba de dar el servidor |
| `* Added cookie sesion="..."` | La misma, contada por el motor de cookies |
| `> GET /ruta?token=...` | Lo que vaya en la query string |
| `* Server auth using Basic with user 'user'` | El nombre de usuario |

```bash
curl -sS -v -o /dev/null -u user:mal http://localhost:8080/basic-auth/user/passwd 2>&1 \
  | grep Authorization
# > Authorization: Basic dXNlcjptYWw=
echo 'dXNlcjptYWw=' | base64 -d; echo
# user:mal
```

Que la credencial venga de un `--config` o de una variable de entorno no
cambia nada: si viaja en un header, sale en la traza.

---

## 3. Cómo se usa

### 3.1 Tachar antes de compartir

El valor se tacha; el nombre del header se queda, porque saber que el
`Authorization` **viajó** es justo lo que necesita quien lee la traza.

```bash
tachar() {
  sed -E 's/^([<>] (Authorization|Proxy-Authorization|Cookie|Set-Cookie|X-API-Key):).*/\1 <REDACTADO>/I;
          s/^(\* (Added|Replaced) cookie).*/\1 <REDACTADO>/'
}

curl -sS -v -o /dev/null -u user:mal http://localhost:8080/basic-auth/user/passwd 2>&1 \
  | tachar | grep -E 'Authorization|< HTTP'
# > Authorization: <REDACTADO>
# < HTTP/1.1 401 Unauthorized
```

El modificador `I` de `sed` (sin distinguir mayúsculas) es de GNU sed. En macOS
no existe: el proyecto lo hace con `awk` y `tolower`, que funciona en los dos.

### 3.2 Solo la parte que interesa

Una traza HTTPS tiene decenas de líneas de handshake. Para un problema HTTP
sobran:

```bash
# Solo lo que se envia y se recibe
curl -sS -v -o /dev/null http://localhost:8080/get 2>&1 | grep -E '^[<>]'

# Solo las decisiones de curl: resolver, conectar, TLS, redirects
curl -sS -v -o /dev/null http://localhost:8080/get 2>&1 | grep '^\*'
```

### 3.3 Seguir un redirect en la traza

```bash
curl -sS -v -L --max-redirs 2 -o /dev/null http://localhost:8080/redirect/5 2>&1 \
  | grep -E '^> GET|^< HTTP|Issue|Maximum'
# > GET /redirect/5 HTTP/1.1
# < HTTP/1.1 302 Found
# * Issue another request to this URL: 'http://localhost:8080/relative-redirect/4'
# > GET /relative-redirect/4 HTTP/1.1
# < HTTP/1.1 302 Found
# * Issue another request to this URL: 'http://localhost:8080/relative-redirect/3'
# > GET /relative-redirect/3 HTTP/1.1
# < HTTP/1.1 302 Found
# * Maximum (2) redirects followed
```

Cada salto es un bloque `>` / `<` completo, unido al siguiente por una línea
`* Issue another request`. Ahí se ve si el método cambió y si el
`Authorization` siguió viajando al host nuevo (Semana 05, teoría 06).

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Pegar una traza `-v` sin tachar en un ticket o un chat | La credencial queda en el historial de un sistema que no controlas | Tachar con `sed` o `awk` antes de copiar |
| `-v` en un script de CI "por si falla" | Cada ejecución deja la credencial en los logs del CI | `-v` solo bajo demanda, y tachado |
| Tachar solo `Authorization` | La API key en `X-API-Key` y las cookies siguen ahí | Todos los headers de credencial y sesión |
| Buscar en la traza por frases exactas | Cambian entre versiones de curl y backends TLS | Agárrate a las marcas `*`, `>` y `<` |
| Leer la traza de arriba abajo entera | En HTTPS son cincuenta líneas de handshake | Ve a la última línea `*` antes del error |
| `curl -v ... 2>&1 \| jq` | La traza se mezcla con el JSON | Deja stderr fuera del pipe |

---

## 5. Trucos

- **`--trace-time`** junto a `-v` añade la hora con microsegundos a cada línea.
  El salto grande entre dos líneas es la fase lenta.
- **`-v` con `-o /dev/null`** cuando solo te interesa la conversación: el
  cuerpo no se mezcla con la traza en la terminal.
- **`--stderr traza.txt`** guarda la traza sin tocar la redirección del shell.
- **`--no-progress-meter` y `-v`** se llevan bien: traza sin la tabla del
  medidor intercalada.

---

## 📚 Recursos Adicionales

- [everything.curl.dev — Verbose](https://everything.curl.dev/usingcurl/verbose/)
- [Manpage: `--verbose`](https://curl.se/docs/manpage.html#-v)
- [Códigos de salida de curl](https://curl.se/libcurl/c/libcurl-errors.html)

---

## ✅ Checklist de Verificación

- [ ] Señalas en una traza sana las líneas `*`, `>`, `<` y `{`
- [ ] Con las tres preguntas, localizas un fallo de DNS, uno de TCP y uno de TLS
- [ ] Sabes qué hay en `Authorization: Basic ...` y lo decodificas con `base64 -d`
- [ ] Tu `tachar` deja `Authorization: <REDACTADO>` y no deja ninguna cookie
- [ ] Sigues una cadena de redirects en la traza y cuentas los saltos
