# Bearer y el flujo de login

> *Bearer* significa «portador»: vale por el hecho de tenerlo, como un billete de
> tren. No hay usuario, no hay password, no hay reto que resolver. Quien lo
> tenga, entra.

![Diagrama del flujo login-token-petición: credencial contra el endpoint de token, token con caducidad en la respuesta, y peticiones posteriores con el header Authorization Bearer](../0-assets/05-bearer-y-el-flujo-de-login.svg)

## 🎯 Objetivos

- Mandar un token Bearer y comprobar que llegó **intacto** al servidor
- Montar el flujo `login → token → petición` contra el laboratorio
- Elegir entre `-H`, `--oauth2-bearer` (7.61+) y `--config`, sabiendo qué hace cada uno con el argv
- Guardar un token de forma que no acabe en el historial ni en un archivo legible

---

## 1. Qué problema resuelve

Basic Auth manda la password **en cada petición**. Eso significa que la password
pasa por todos los servidores intermedios mil veces al día, y que si un log la
captura una sola vez, está comprometida para siempre.

El esquema Bearer parte eso en dos:

1. La credencial de verdad se usa **una vez**, contra un endpoint de token
2. A cambio te dan un token con **caducidad** y **alcance limitado**, y es ese
   el que viaja en las mil peticiones siguientes

Si el token se filtra, el daño está acotado: caduca solo, y se puede revocar sin
tocar la credencial original. Está en el
[RFC 6750](https://datatracker.ietf.org/doc/html/rfc6750) y su formato es el más
simple de todos los esquemas:

```
Authorization: Bearer <token>
```

Nada de base64, nada de hash. El token es una cadena opaca que el servidor sabe
verificar y tú no necesitas entender. Muchas veces es un JWT, y entonces sí se
puede leer por dentro: eso es la teoría 06.

---

## 2. Cómo funciona

### 2.1 El header, y nada más

```bash
# El laboratorio acepta cualquier token no vacio y te dice cual recibio: sirve
# justo para comprobar que llego entero.
curl -s -H 'Authorization: Bearer token-de-laboratorio' \
  http://localhost:8080/bearer | jq -c .
# {"authenticated":true,"token":"token-de-laboratorio"}
```

Sin él, el reto:

```bash
curl -s -o /dev/null -D - http://localhost:8080/bearer \
  | grep -iE '^(HTTP/|www-authenticate)'
# HTTP/1.1 401 Unauthorized
# Www-Authenticate: Bearer
```

El reto de Bearer no trae `realm` ni nada que resolver: solo dice el esquema. No
hay nada que negociar, porque el token te lo dieron antes por otro camino.

### 2.2 Las tres formas de mandarlo, y qué hace cada una con el argv

| Forma | Versión | Token en el argv | Cuándo |
|---|---|---|---|
| `-H "Authorization: Bearer $T"` | siempre | **Sí** | Solo a mano, y a sabiendas |
| `--oauth2-bearer "$T"` | **7.61+** | **Sí** | Más legible, misma exposición |
| `--config archivo` con `header = "..."` | siempre | No | Scripts. El correcto |

```bash
# --oauth2-bearer construye el header por ti. Mas corto de leer, pero el token
# sigue estando en la linea de comandos: para un script no vale.
curl -s --oauth2-bearer 'token-de-laboratorio' http://localhost:8080/bearer | jq -c .
# {"authenticated":true,"token":"token-de-laboratorio"}
```

Que `--oauth2-bearer` exista no lo convierte en la opción segura. Hace lo mismo
que escribir el header a mano, con menos texto.

### 2.3 El flujo de login, paso a paso

El laboratorio trae un servidor de tokens en el puerto **8081** que emite tokens
firmados de verdad. Lo usamos aquí solo como **fuente de token**: los flujos
OAuth2 completos, con sus refrescos y sus modos, son la Semana 08.

```bash
# Paso 1: la credencial de la aplicacion a cambio de un token. La respuesta
# trae el token, su tipo y cuanto le queda de vida.
curl -s --max-time 10 -X POST http://localhost:8081/default/token \
  -d 'grant_type=client_credentials' \
  -d 'client_id=bc-curl' \
  -d 'client_secret=lab' \
  -d 'scope=api' | jq -c '{token_type, expires_in}'
# {"token_type":"Bearer","expires_in":3599}
```

```bash
# Paso 2: quedarse solo con el token. jq -r lo saca sin las comillas del JSON;
# con comillas, el header saldria mal formado.
TOKEN=$(curl -s --max-time 10 -X POST http://localhost:8081/default/token \
  -d 'grant_type=client_credentials' -d 'client_id=bc-curl' \
  -d 'client_secret=lab' -d 'scope=api' | jq -r '.access_token')
```

```bash
# Paso 3: usarlo. Aqui va con -H porque es una sesion interactiva; en un script
# iria por --config.
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8080/bearer \
  | jq -c '.authenticated'
# true
```

> [!WARNING]
> En el paso 1, `client_secret` está en la línea de comandos. Es exactamente lo
> que la teoría 03 dice que no se hace, y aquí se hace **a propósito** para que
> el flujo se lea de un vistazo. En un script, ese `-d` sale de un archivo con
> `--config` o de `-d @archivo`. La práctica 03 lo monta bien.

### 2.4 Los tres campos de la respuesta que importan

| Campo | Qué significa | Qué hacer con él |
|---|---|---|
| `access_token` | El token | Guardarlo donde no lo lea nadie |
| `token_type` | Casi siempre `Bearer` | Construir el header con ese esquema, no asumirlo |
| `expires_in` | Segundos de vida **desde ahora** | Calcular el instante de caducidad y guardarlo al lado |

`expires_in` es relativo, y ese es el detalle que se cuela: guardarlo tal cual no
sirve de nada al día siguiente. Lo que se guarda es la suma:

```bash
# El instante en que caduca, en segundos desde epoch. Eso si se puede comparar
# mañana con `date +%s`.
caduca_en=$(( $(date +%s) + 3599 ))
echo "$caduca_en"
```

---

## 3. Cómo se usa

### 3.1 Que el token llegue intacto

Es el fallo más frecuente con Bearer, y es silencioso: el token viaja **casi**
entero y el servidor devuelve `401` sin decir por qué. Cuatro causas, todas
comprobables:

```bash
# ✅ Correcto: el laboratorio devuelve el token que recibio, y coincide.
curl -s -H 'Authorization: Bearer token-de-laboratorio' \
  http://localhost:8080/bearer | jq -r '.token'
# token-de-laboratorio
```

```bash
# ❌ Comillas de mas: si el token se saco con `jq` sin -r, se lleva las comillas
#    del JSON dentro del header.
curl -s -H 'Authorization: Bearer "token-de-laboratorio"' \
  http://localhost:8080/bearer | jq -r '.token'
# "token-de-laboratorio"
```

| Causa | Cómo se ve | Cómo se arregla |
|---|---|---|
| `jq` sin `-r` | El token llega entre comillas | `jq -r '.access_token'` |
| Un `\n` final del token | El header se corta o llega con salto | `tr -d '\n'`, o `$(...)` que ya lo quita |
| Comillas simples en bash | `'Bearer $TOKEN'` manda el texto `$TOKEN` literal | Comillas dobles cuando hay que expandir |
| El token guardado con `echo` en un archivo | `echo` añade `\n` | `printf '%s'`, sin `\n` |

La comprobación, contra el laboratorio, es una línea:

```bash
# Si lo que sale no es EXACTAMENTE tu token, el problema esta en tu lado.
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8080/bearer | jq -r '.token'
```

### 3.2 En un script, sin el token en el argv

```bash
#!/usr/bin/env bash
set -euo pipefail

: "${API_TOKEN:?falta API_TOKEN en el entorno}"

config=$(mktemp)
trap 'rm -f "$config"' EXIT
(umask 077; printf 'header = "Authorization: Bearer %s"\n' "$API_TOKEN" > "$config")

# --fail-with-body: un 401 tiene que ser un fallo, y su cuerpo explica si el
# token caduco o nunca valio. --max-time y --retry, como siempre en produccion.
curl --config "$config" \
  --fail-with-body --max-time 30 --retry 3 --retry-delay 2 \
  -sS "${BASE_URL}/v1/datos"
```

### 3.3 Guardar el token entre ejecuciones

Un token dura una hora: pedir uno nuevo en cada invocación de un script que corre
cada minuto es tráfico tirado, y algunas APIs lo limitan. Se guarda, con su
instante de caducidad al lado:

```bash
# Nace con permisos 600, y con printf %s para no meter un \n en el token.
(umask 077; printf 'API_TOKEN=%s\nAPI_TOKEN_EXP=%s\n' "$TOKEN" "$caduca_en" > ~/.bc-curl)
```

```bash
# Y antes de usarlo, se comprueba. 60 segundos de margen para que no caduque
# entre la comprobacion y la peticion.
ahora=$(date +%s)
if [ "$ahora" -ge $(( API_TOKEN_EXP - 60 )) ]; then
  echo "token caducado o a punto: hay que pedir otro" >&2
fi
```

Ese margen tiene nombre —*clock skew*— y sirve para dos cosas: para que el token
no caduque a mitad de la petición, y para absorber la diferencia de reloj entre
tu máquina y el servidor.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `-H "Authorization: Bearer $T"` en un script | El token acaba en el argv, visible en `ps` | `--config` con `header = "..."` |
| Pedir un token nuevo en cada petición | Tráfico inútil, y muchas APIs limitan el endpoint de token | Guardarlo con su caducidad y reutilizarlo |
| Guardar `expires_in` tal cual | Es relativo al momento de emisión: mañana no significa nada | Guardar `ahora + expires_in` |
| `echo "$TOKEN" > archivo` | Añade un `\n` que se cuela en el header | `printf '%s' "$TOKEN" > archivo` |
| Reintentar un `401` con el mismo token | El token no mejora reintentando | Renovarlo y reintentar **una** vez. Teoría 08 |
| Asumir que el token es un JWT | Muchos son cadenas opacas sin nada dentro | Si necesitas la caducidad, guárdala aparte |
| Mandar el token a un host distinto tras una redirección | Se lo regalas a quien controle el destino | curl no reenvía credenciales entre hosts salvo que se lo pidas. No se lo pidas |

---

## 5. Trucos

```bash
# Comprobar que el token llega intacto: el laboratorio te devuelve lo que
# recibio. Si no coincide con tu token, el fallo esta en tu comando.
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8080/bearer | jq -r .token
```

```bash
# Pedir un token y quedarte solo con lo util, en una linea.
curl -s --max-time 10 -X POST http://localhost:8081/default/token \
  -d 'grant_type=client_credentials' -d 'client_id=bc-curl' \
  -d 'client_secret=lab' -d 'scope=api' \
  | jq -c '{token_type, expires_in}'
# {"token_type":"Bearer","expires_in":3599}
```

```bash
# Saber si un endpoint quiere Bearer antes de buscar el token por ningun lado.
curl -s -o /dev/null -D - URL | grep -i '^www-authenticate'
# Www-Authenticate: Bearer
```

```bash
# El instante de caducidad a partir de expires_in, listo para guardar.
caduca_en=$(( $(date +%s) + $(jq -r '.expires_in' respuesta.json) ))
```

---

## 📚 Recursos Adicionales

- [RFC 6750 — The OAuth 2.0 Authorization Framework: Bearer Token Usage](https://datatracker.ietf.org/doc/html/rfc6750) — el formato del header y qué se puede hacer con un token robado
- [manpage de curl — `--oauth2-bearer`](https://curl.se/docs/manpage.html#--oauth2-bearer) — disponible desde 7.61
- [everything.curl.dev — HTTP authentication](https://everything.curl.dev/http/auth.html)
- [`docs/versiones-de-curl.md`](../../../docs/versiones-de-curl.md) — qué flags tienes según tu versión

---

## ✅ Checklist de Verificación

- [ ] He mandado un token al laboratorio y he comprobado con `.token` que llegó igual
- [ ] He provocado el fallo de las comillas de más y he visto cómo se ve
- [ ] He pedido un token al servidor del puerto 8081 y he leído su `expires_in`
- [ ] Sé por qué `expires_in` no se guarda tal cual, y qué se guarda en su lugar
- [ ] Sé desde qué versión existe `--oauth2-bearer` y por qué no es la opción segura
- [ ] He montado la variante con `--config` y el token no aparece en `ps`

---

| Anterior | Siguiente |
|---|---|
| [04 — API keys](04-api-keys.md) | [06 — El JWT por dentro](06-jwt-por-dentro.md) |
