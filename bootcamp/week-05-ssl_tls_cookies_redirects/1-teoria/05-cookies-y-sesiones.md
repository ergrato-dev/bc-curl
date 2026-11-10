# Cookies y sesiones

> curl no guarda cookies si no se lo pides. Cada comando empieza sin memoria:
> el login de la línea anterior no existe para la siguiente. El tarro de
> cookies es lo que le da memoria, y esa memoria vale lo que una password.

![Diagrama de una sesión con cookies a lo largo de dos comandos curl: el primero recibe Set-Cookie y lo escribe con -c en el tarro; el segundo lee el tarro con -b y manda Cookie; debajo, una línea del tarro con sus siete columnas (dominio, subdominios, ruta, secure, caducidad, nombre, valor) y el prefijo #HttpOnly_](../0-assets/05-cookies-y-sesiones.svg)

## 🎯 Objetivos

- Leer un `Set-Cookie` y sus atributos
- Mandar cookies con `-b` como texto y como archivo
- Guardarlas con `-c` y entender el formato del tarro
- Saber cuándo se activa el motor de cookies de curl, y por qué importa con `-L`
- Proteger el tarro: permisos 600 y cookies de sesión con `-j`

---

## 1. Qué problema resuelve

HTTP no tiene estado: cada petición llega sola. Las cookies son el parche de
1994 para que el servidor reconozca a quien ya pasó por el login: responde con
un `Set-Cookie`, y el cliente lo devuelve en cada petición siguiente.

Un navegador lo hace solo. curl no, y es deliberado: un comando que no guarda
nada no puede filtrar nada. Cuando un script necesita sesión (una aplicación
que no tiene API y solo entiende de formularios y cookies, un panel de
administración, un login con CSRF), hay que pedírselo.

---

## 2. Cómo funciona

### 2.1 `Set-Cookie` y sus atributos

```bash
curl -s -D - -o /dev/null \
  'http://localhost:8080/response-headers?Set-Cookie=sesion%3Dabc%3B%20Max-Age%3D600%3B%20HttpOnly%3B%20Path%3D%2F' \
  | grep -i '^set-cookie'
# Set-Cookie: sesion=abc; Max-Age=600; HttpOnly; Path=/
```

| Atributo | Qué dice |
|---|---|
| `sesion=abc` | El nombre y el valor |
| `Max-Age=600` / `Expires=...` | Cuándo caduca. **Sin ninguno**, es una cookie de **sesión**: muere al cerrar el navegador |
| `Path=/` | A qué rutas se manda |
| `Domain=ejemplo.com` | A qué hosts se manda. Sin él, solo al host que la fijó |
| `Secure` | Solo por HTTPS |
| `HttpOnly` | El JavaScript de la página no puede leerla. A curl le da igual: la guarda y la manda |
| `SameSite=Lax` | Restricción para peticiones entre sitios. Es cosa del navegador |

### 2.2 `-b`: mandar cookies

`-b` (`--cookie`) acepta dos cosas, y las distingue por un detalle: si lleva
un `=`, es texto; si no, es un archivo.

```bash
# Texto: se manda tal cual en el header Cookie.
curl -s -b 'sesion=abc; tema=oscuro' http://localhost:8080/cookies | jq -c .
# {"cookies":{"sesion":"abc","tema":"oscuro"}}

# Archivo: lee el tarro y manda las que correspondan a la URL.
curl -s -b tarro.txt http://localhost:8080/cookies
```

### 2.3 `-c`: guardar cookies

`-c` (`--cookie-jar`) escribe, **al terminar el comando**, todas las cookies
que curl conoce en ese momento:

```bash
curl -s -c demo.txt 'http://localhost:8080/cookies/set?sesion=abc' -o /dev/null
tail -1 demo.txt
# #HttpOnly_localhost	FALSE	/	FALSE	0	sesion	abc
```

Es el formato de Netscape, siete columnas separadas por tabuladores:

| Columna | Valor | Significado |
|---|---|---|
| 1 | `#HttpOnly_localhost` | Dominio. El prefijo `#HttpOnly_` marca el atributo, **no** es un comentario |
| 2 | `FALSE` | ¿Vale para subdominios? |
| 3 | `/` | Ruta |
| 4 | `FALSE` | ¿Solo HTTPS (`Secure`)? |
| 5 | `0` | Caducidad en segundos desde 1970. `0` = cookie de sesión |
| 6 | `sesion` | Nombre |
| 7 | `abc` | Valor |

La trampa del prefijo: un `grep -v '^#'` para "quitar los comentarios" se lleva
por delante todas las cookies `HttpOnly`, que suelen ser justo las de sesión.

### 2.4 El motor de cookies y `-L`

curl tiene un motor de cookies que, mientras dura un comando, guarda los
`Set-Cookie` y los devuelve en las peticiones siguientes **del mismo
comando**. Pero está **apagado** hasta que usas `-b` o `-c`:

```bash
# /cookies/set fija la cookie y redirige a /cookies.
curl -sL 'http://localhost:8080/cookies/set?a=1' | jq -c .
# {"cookies":{}}

# -b '' no manda nada, pero enciende el motor.
curl -sL -b '' 'http://localhost:8080/cookies/set?a=1' | jq -c .
# {"cookies":{"a":"1"}}
```

Con `-L` y un login que fija la cookie y redirige al panel, sin motor llegas
al panel sin sesión. `-b ''` es el interruptor más corto.

---

## 3. Cómo se usa

### 3.1 Una sesión en varios comandos

El mismo archivo en `-b` y en `-c`: lee lo que había y guarda lo nuevo.

```bash
# Crear el tarro ANTES, con permisos 600: ver la seccion 3.2.
(umask 077 && : > tarro.txt)

# 1. Login: el servidor fija la cookie de sesion.
curl -s -b tarro.txt -c tarro.txt \
  'http://localhost:8080/cookies/set?sesion=abc' -o /dev/null

# 2. Cualquier peticion posterior la manda sola.
curl -s -b tarro.txt -c tarro.txt http://localhost:8080/cookies | jq -c .
# {"cookies":{"sesion":"abc"}}

# 3. Logout: el servidor la borra, y -c actualiza el tarro.
curl -s -b tarro.txt -c tarro.txt \
  'http://localhost:8080/cookies/delete?sesion' -o /dev/null
grep -c sesion tarro.txt
# 0
```

### 3.2 Los permisos del tarro

El tarro contiene la sesión: quien lo copie entra como tú, sin password. Y
curl lo crea con los permisos de la `umask` del proceso, normalmente 644:

```bash
curl -s -c nuevo.txt 'http://localhost:8080/cookies/set?s=1' -o /dev/null
stat -c %a nuevo.txt
# 644
```

Si el archivo **ya existe**, curl respeta sus permisos al reescribirlo (lo
hemos comprobado con 7.81 y con 8.21). La defensa es crearlo antes, vacío y
con 600, como en la sección 3.1.

### 3.3 Las cookies de sesión: `-j`

Las cookies sin caducidad (columna 5 a `0`) deberían morir "al cerrar el
navegador". curl no cierra nada, así que las conserva en el tarro para
siempre. `-j` (`--junk-session-cookies`) las descarta **al leer**, como si
empezara una sesión nueva:

```bash
curl -s -b tarro.txt http://localhost:8080/cookies | jq -c .
# {"cookies":{"p":"1","s":"1"}}
curl -s -j -b tarro.txt http://localhost:8080/cookies | jq -c .
# {"cookies":{"p":"1"}}
```

Aquí `s` era de sesión y `p` tenía `Max-Age`. Útil para probar que un login
"recuérdame" sobrevive a un reinicio y uno normal no.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Dejar que curl cree el tarro | Nace con 644: otros usuarios del equipo leen tu sesión | Crearlo antes con `umask 077` |
| Tarro en `/tmp/cookies.txt`, nombre fijo | Otro usuario puede crearlo antes y leer lo que escribas | `mktemp`, o un archivo en tu `$HOME` |
| Comitear el tarro "de ejemplo" | Es una sesión válida mientras no caduque | Fuera del repositorio; `.gitignore` |
| `-L` sin `-b` ni `-c` en un login con redirect | El motor está apagado: la cookie del login se pierde en el salto | `-b ''` como mínimo |
| `grep -v '^#'` para leer el tarro | Borra las líneas `#HttpOnly_`, que son cookies | `grep -v '^# '` (con espacio) o `awk 'NF==7'` |
| Copiar la cookie del navegador a `-b` en un script | El valor caduca, y queda en el historial de la shell | Un login del propio script, o un token de API |

---

## 5. Trucos

```bash
# Las cookies del tarro como nombre=valor, una por linea.
awk -F'\t' 'NF == 7 { print $6 "=" $7 }' tarro.txt
```

```bash
# Ver que cookies manda curl, sin que el servidor las interprete.
curl -s -b tarro.txt -v http://localhost:8080/get -o /dev/null 2>&1 | grep '^> Cookie'
```

```bash
# Cuando caduca cada cookie del tarro (0 = de sesion).
awk -F'\t' 'NF == 7 { print $6, ($5 == 0 ? "sesion" : strftime("%F %T", $5)) }' tarro.txt
# strftime es de gawk; con mawk antiguo, date -d "@$segundos".
```

---

## 📚 Recursos Adicionales

- [RFC 6265 — HTTP State Management Mechanism](https://datatracker.ietf.org/doc/html/rfc6265) — `Set-Cookie` y sus atributos
- [everything.curl.dev — Cookies](https://everything.curl.dev/http/cookies/) — el motor, `-b`, `-c` y el formato del tarro
- [curl — HTTP cookies](https://curl.se/docs/http-cookies.html) — el formato de archivo, columna a columna
- [MDN — Set-Cookie](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie) — todos los atributos con ejemplos

---

## ✅ Checklist de Verificación

- [ ] Sé qué hace cada atributo de un `Set-Cookie`, y cuál convierte una cookie en "de sesión"
- [ ] Sé cómo distingue `-b` entre texto y archivo
- [ ] He leído un tarro y sé qué significa `#HttpOnly_` y un `0` en la columna 5
- [ ] He visto una cookie perderse con `-L` sin motor, y recuperarse con `-b ''`
- [ ] He mantenido una sesión en tres comandos con `-b` y `-c` sobre el mismo archivo
- [ ] Sé por qué el tarro se crea antes y con qué permisos

---

| Anterior | Siguiente |
|---|---|
| [04 — Certificado de cliente: mTLS](04-certificado-de-cliente-mtls.md) | [06 — Redirects](06-redirects.md) |
