# Redirects

> Sin `-L`, curl se queda en el `302` y te enseña una página vacía. Con `-L`,
> sigue el salto... y con él puede cambiar el método, perder el cuerpo, mandar
> tu credencial a otro host o bajar de HTTPS a HTTP.

![Diagrama de una cadena de redirects con -L: la petición original, un 302 que la convierte en GET y pierde el cuerpo, un 307 que conserva el método, y un salto a otro host donde curl quita el Authorization pero conserva el header X-API-Key; a la derecha, los límites: --max-redirs con el código 47 y --proto-redir que bloquea el paso de https a http con el código 1](../0-assets/06-redirects.svg)

## 🎯 Objetivos

- Ver un redirect sin seguirlo, y saber a dónde apunta
- Seguirlo con `-L` y limitar la cadena con `--max-redirs`
- Saber qué códigos cambian un `POST` a `GET` y cuáles no
- Saber qué credenciales quita curl al cambiar de host, y cuáles no
- Impedir que un redirect baje de HTTPS a HTTP con `--proto-redir`

---

## 1. Qué problema resuelve

Las APIs redirigen más de lo que parece: una versión antigua que apunta a la
nueva, `http://` que manda a `https://`, una barra final que falta, una
descarga que salta a un CDN, un login que te devuelve al panel. curl, por
defecto, **no sigue ninguno**: devuelve la respuesta del `3xx` y termina.

```bash
curl -s -o /dev/null -w '%{http_code} -> %{redirect_url}\n' \
  http://localhost:8080/redirect/3
# 302 -> http://localhost:8080/relative-redirect/2
```

`%{redirect_url}` dice a dónde iría sin ir. Es la forma de inspeccionar un
redirect antes de decidir si seguirlo.

---

## 2. Cómo funciona

### 2.1 `-L` y la cadena

```bash
curl -sL -o /dev/null -w '%{http_code} %{num_redirects} %{url_effective}\n' \
  http://localhost:8080/redirect/3
# 200 3 http://localhost:8080/get
```

| Variable | Qué dice |
|---|---|
| `%{num_redirects}` | Cuántos saltos siguió |
| `%{url_effective}` | La URL de la última petición: donde acabó |
| `%{redirect_url}` | Sin `-L`, a dónde apunta el `Location` |

### 2.2 `--max-redirs`

curl 7.81 sigue hasta **50** saltos por defecto. Un bucle entre dos URLs se
detecta, pero tarda 50 peticiones:

```bash
curl -sL --max-redirs 5 -o /dev/null http://localhost:8080/redirect/9; echo "codigo: $?"
# codigo: 47
```

**47** (`CURLE_TOO_MANY_REDIRECTS`). Una cadena legítima rara vez pasa de dos o
tres saltos; 5 es un límite generoso.

### 2.3 El método tras el salto

Aquí está la trampa principal. Lo que hace curl depende del código:

| Código | Significado | curl con `-d` y `-L` |
|---|---|---|
| `301` Moved Permanently | Movido para siempre | Cambia a **GET** y tira el cuerpo |
| `302` Found | Movido temporalmente | Cambia a **GET** y tira el cuerpo |
| `303` See Other | "Ve a buscar el resultado allí" | Cambia a **GET**: es lo que pide la norma |
| `307` Temporary Redirect | Igual que 302, pero conservando el método | Mantiene **POST** y el cuerpo |
| `308` Permanent Redirect | Igual que 301, pero conservando el método | Mantiene **POST** y el cuerpo |

```bash
U='http://localhost:8080/redirect-to?url=/anything&status_code'
curl -sL -d a=1 "$U=302" | jq -r .method
# GET
curl -sL -d a=1 "$U=307" | jq -r .method
# POST
```

El cambio a GET en 301 y 302 es una costumbre de los navegadores que la norma
acabó aceptando. Por eso existen 307 y 308. Para forzar curl a mantener el
POST en un 301, 302 o 303: `--post301`, `--post302`, `--post303`.

La segunda trampa: `-X POST` **fuerza** el método en todas las peticiones de
la cadena, incluso tras un 303 que pide expresamente un GET:

```bash
curl -sL -X POST -d a=1 "$U=303" | jq -r .method
# POST
```

`-X` con `-L` casi siempre es un error. Si el método es POST porque hay `-d`,
no hace falta `-X`.

### 2.4 Credenciales y cambio de host

Cuando un salto lleva a **otro host**, curl quita las credenciales que sabe
que lo son:

```bash
# localhost redirige a 127.0.0.1: para curl, otro host.
# La credencial en un --config con permisos 600, nunca en el argv (Semana 03).
(umask 077 && printf 'user = "ana:%s"\n' "$APP_PASSWORD" > user.cfg)
curl -sL --config user.cfg \
  'http://localhost:8080/redirect-to?url=http://127.0.0.1:8080/headers' \
  | jq -c '.headers.Authorization'
# null
```

Lo hace con `-u` y con un `-H 'Authorization: ...'` propio. Pero **no** con
cualquier otro header:

```bash
(umask 077 && printf 'header = "X-API-Key: %s"\n' "$API_KEY" > clave.cfg)
curl -sL --config clave.cfg \
  'http://localhost:8080/redirect-to?url=http://127.0.0.1:8080/headers' \
  | jq -c '.headers["X-Api-Key"]'
# ["...tu clave..."]
```

curl no sabe que `X-API-Key` es secreto: viaja entero al host nuevo, en 7.81
y en 8.21. Un servidor que redirige a un dominio que no controlas recibe tu
clave. Con una API key en un header propio, **no sigas redirects a ciegas**:
mira `%{redirect_url}` y decide.

`--location-trusted` hace lo contrario: manda las credenciales a cualquier
host de la cadena. Es un antipatrón casi siempre.

### 2.5 `--proto-redir`: no bajar a HTTP

Un salto de `https://` a `http://` hace que la siguiente petición (con sus
cookies y headers) viaje en claro. `--proto-redir` limita los protocolos a los
que se permite saltar:

```bash
curl -sSL --cacert docs/lab-ca.pem --proto-redir '=https' \
  'https://localhost:8443/redirect-to?url=http://localhost:8080/get' -o /dev/null
# curl: (1) Protocol "http" not supported or disabled in libcurl
```

El `=` significa "solo estos". **Las comillas importan en zsh**: `=https` sin
comillas es una expansión de zsh (busca un comando llamado `https`) y falla
con `zsh: https not found` antes de ejecutar curl.

---

## 3. Cómo se usa

### 3.1 Un GET de producción que sigue redirects

```bash
curl --fail-with-body --max-time 10 --retry 3 -sS \
  -L --max-redirs 5 --proto-redir '=https' \
  --cacert docs/lab-ca.pem \
  https://localhost:8443/redirect/2
```

### 3.2 Un POST: no seguir, mirar

```bash
codigo_y_destino=$(curl -sS --max-time 10 -o respuesta.json \
  -w '%{http_code} %{redirect_url}' -d a=1 \
  'http://localhost:8080/redirect-to?url=/anything&status_code=302')
echo "$codigo_y_destino"
# 302 http://localhost:8080/anything
```

Con el código y el destino en la mano, el script decide: repetir el POST en el
destino nuevo si es el mismo host y el código es 307/308, o fallar con un
mensaje claro si no.

### 3.3 Ver la cadena entera

```bash
curl -sL -o /dev/null -D - http://localhost:8080/redirect/3 \
  | grep -iE '^(HTTP|location)'
# HTTP/1.1 302 Found
# Location: /relative-redirect/2
# HTTP/1.1 302 Found
# Location: /relative-redirect/1
# HTTP/1.1 302 Found
# Location: /get
# HTTP/1.1 200 OK
```

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `-L` sin `--max-redirs` | Un bucle cuesta 50 peticiones antes de fallar | `--max-redirs 5` |
| `-X POST -L` | Fuerza POST incluso donde el servidor pidió GET | Quitar `-X`; `--post30x` si de verdad hace falta |
| `-L` en un POST que crea algo | Un 302 lo convierte en GET y el cuerpo se pierde sin error | No seguir; leer `%{redirect_url}` |
| `--location-trusted` | La credencial viaja a cualquier host de la cadena | `-L` normal, que la quita al cambiar de host |
| `-L` con la clave en un header propio | `X-API-Key` no se quita: llega al host nuevo | No seguir, o comprobar el host del destino |
| `-L` desde HTTPS sin `--proto-redir` | Un salto a `http://` manda la siguiente petición en claro | `--proto-redir '=https'` |

---

## 5. Trucos

```bash
# A donde lleva un enlace acortado, sin seguirlo.
curl -s -o /dev/null -w '%{redirect_url}\n' http://localhost:8080/redirect/1
```

```bash
# El destino final de una cadena, sin descargar el cuerpo.
curl -sIL -o /dev/null -w '%{url_effective}\n' http://localhost:8080/redirect/3
```

```bash
# Contar los saltos de una cadena.
curl -sL -o /dev/null -w '%{num_redirects}\n' http://localhost:8080/redirect/3
```

---

## 📚 Recursos Adicionales

- [RFC 9110 §15.4 — Redirection 3xx](https://datatracker.ietf.org/doc/html/rfc9110#section-15.4) — qué significa cada código y qué hace con el método
- [everything.curl.dev — Redirects](https://everything.curl.dev/http/redirects.html) — `-L`, el método y las credenciales
- [manpage de curl — `-L`](https://curl.se/docs/manpage.html#-L) — incluida la nota sobre `-X`
- [manpage de curl — `--proto-redir`](https://curl.se/docs/manpage.html#--proto-redir) — la sintaxis `=`, `+` y `-`

---

## ✅ Checklist de Verificación

- [ ] Sé ver a dónde apunta un redirect sin seguirlo
- [ ] He seguido una cadena y he leído `%{num_redirects}` y `%{url_effective}`
- [ ] He cortado una cadena larga con `--max-redirs` y sé qué código sale
- [ ] Sé qué códigos cambian POST a GET, y por qué `-X POST -L` es una trampa
- [ ] He comprobado que `Authorization` se quita al cambiar de host y `X-API-Key` no
- [ ] He bloqueado un salto de HTTPS a HTTP, con las comillas que pide zsh

---

| Anterior | Siguiente |
|---|---|
| [05 — Cookies y sesiones](05-cookies-y-sesiones.md) | [07 — Timeouts](07-timeouts.md) |
