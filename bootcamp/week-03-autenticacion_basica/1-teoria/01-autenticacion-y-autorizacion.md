# Autenticación y autorización

> Dos palabras que se parecen y que resuelven problemas distintos. Confundirlas
> es lo que hace que alguien reintente diez veces un `403` que no va a cambiar.

![Diagrama del ciclo reto-respuesta: petición sin credencial, 401 con WWW-Authenticate, petición con Authorization, 200; y aparte un 403 con credencial válida](../0-assets/01-autenticacion-y-autorizacion.svg)

## 🎯 Objetivos

- Separar autenticación de autorización con un ejemplo concreto de cada una
- Leer un `WWW-Authenticate` y decir qué esquema pide el servidor
- Distinguir `401` de `403` y decidir qué hacer con cada uno
- Nombrar los cuatro esquemas que vas a ver esta semana y en qué se diferencian

---

## 1. Qué problema resuelve

Una API abierta es un caso raro. En cuanto los datos son de alguien, el servidor
necesita responder dos preguntas antes de contestar:

1. **¿Quién eres?** → autenticación
2. **¿Puedes hacer esto?** → autorización

Son secuenciales y no intercambiables. Sin la primera, la segunda no tiene
sentido: no se pueden comprobar los permisos de nadie.

En la Semana 02 todo funcionaba porque el laboratorio no preguntaba. En cuanto
apuntes `api-toolkit` a la API de tu dominio, la primera respuesta que vas a ver
es esta:

```bash
# Sin credencial, contra un endpoint que la exige.
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/bearer
# 401
```

Y el cuerpo, que también viene:

```bash
curl -s http://localhost:8080/bearer | jq
# {
#   "status_code": 401,
#   "error": "Unauthorized"
# }
```

### 1.1 La confusión que cuesta dinero

Un script que trata los dos casos igual acaba en uno de estos dos sitios:

| Lo que hace el script | Qué pasa de verdad |
|---|---|
| Reintenta el `403` cinco veces con backoff | Cinco veces el mismo no. Y si la API cuenta intentos fallidos, te bloquea |
| Trata el `401` como un error genérico y aborta | El token había caducado. Renovarlo era una petición; abortar fue un incidente |

La regla, en una línea: **`401` puede arreglarse con otra credencial, `403` no.**

---

## 2. Cómo funciona

### 2.1 El ciclo reto-respuesta

HTTP no tiene sesión. Cada petición llega sola y tiene que traer consigo la
prueba de quién la manda. El mecanismo está en el
[RFC 9110 §11](https://datatracker.ietf.org/doc/html/rfc9110#section-11) y son
tres pasos:

1. El cliente pide algo **sin credencial**
2. El servidor responde `401` y añade un header `WWW-Authenticate` que dice
   **qué esquema** acepta — el *reto*
3. El cliente repite la petición con un header `Authorization` en ese esquema —
   la *respuesta*

Se ve entero contra el laboratorio:

```bash
# Paso 1 y 2: la peticion sin credencial y el reto que devuelve.
curl -s -o /dev/null -D - http://localhost:8080/basic-auth/user/password \
  | grep -iE '^(HTTP/|www-authenticate)'
# HTTP/1.1 401 Unauthorized
# Www-Authenticate: Basic realm="Fake Realm"
```

```bash
# Paso 3: la misma peticion con la credencial. -u construye el Authorization.
curl -s -o /dev/null -w '%{http_code}\n' \
  -u user:password http://localhost:8080/basic-auth/user/password
# 200
```

### 2.2 curl no espera al reto (y eso es bueno)

Leyendo el RFC parecería que curl siempre manda dos peticiones: una para
provocar el reto y otra con la credencial. No lo hace. Cuando le dices el
esquema, lo manda **de entrada**:

```bash
# Una sola peticion: curl ya sabe que va Basic, no necesita preguntarlo.
curl -s --basic -u user:password -o /dev/null -v \
  http://localhost:8080/basic-auth/user/password 2>&1 | grep -c '^> GET'
# 1
```

```bash
# Con --anyauth son DOS: la primera va sin credencial, solo para leer el reto
# y decidir el esquema. Es la comodidad que se paga con una ida y vuelta.
curl -s --anyauth -u user:password -o /dev/null -v \
  http://localhost:8080/basic-auth/user/password 2>&1 | grep -c '^> GET'
# 2
```

Esa diferencia importa en un bucle de mil peticiones: son mil idas y vueltas de
más. Vuelve en la teoría 07.

### 2.3 401 y 403, en concreto

| | `401 Unauthorized` | `403 Forbidden` |
|---|---|---|
| Qué dice de verdad | *No sé quién eres* | *Sé quién eres y no puedes* |
| Trae `WWW-Authenticate` | Sí, es obligatorio según el RFC | No |
| Causa típica | Falta el header, token caducado, password mala | Falta un scope, plan gratuito, recurso de otro |
| ¿Se arregla reintentando igual? | No | No |
| ¿Se arregla con **otra** credencial? | Sí, es el camino | No, hace falta otro permiso |
| Qué hace un script sensato | Renovar el token y reintentar **una** vez | Abortar y avisar a un humano |

El nombre `401 Unauthorized` es un error histórico del estándar: significa *no
autenticado*. El que habla de autorización es el `403`.

```bash
# El laboratorio sirve los dos, para poder practicar la distincion.
for c in 401 403; do
  printf '%s -> ' "$c"
  curl -s -o /dev/null -D - "http://localhost:8080/status/$c" \
    | grep -ic 'www-authenticate' | tr -d '\n'
  echo " header(s) WWW-Authenticate"
done
# 401 -> 1 header(s) WWW-Authenticate
# 403 -> 0 header(s) WWW-Authenticate
```

### 2.4 Los cuatro esquemas de esta semana

| Esquema | Qué viaja | Flag de curl | Dónde lo verás |
|---|---|---|---|
| **Basic** | Usuario y password en base64 | `-u`, `--basic` | Routers, APIs internas, registries |
| **API key** | Una cadena fija, normalmente en un header propio | `-H`, `--config` | APIs de producto: pagos, mapas, clima |
| **Bearer** | Un token, muchas veces un JWT, con caducidad | `-H`, `--oauth2-bearer` | Casi todas las APIs modernas |
| **Digest** | Un hash con `nonce`, la password no viaja | `--digest` | Equipos de red, sistemas antiguos |

El quinto —OAuth2 completo, con sus flujos y su refresco— es la Semana 08. Ahí
el token deja de ser algo que copias y pega, y pasa a ser algo que tu script
consigue y renueva solo.

---

## 3. Cómo se usa

### 3.1 Averiguar qué pide un servidor

Antes de escribir la petición autenticada, pregúntale al servidor. Una petición
sin credencial y un `grep`:

```bash
# El reto sale en el header WWW-Authenticate del 401.
curl -s -o /dev/null -D - http://localhost:8080/bearer \
  | grep -i '^www-authenticate'
# Www-Authenticate: Bearer
```

```bash
# El de Digest trae mucho mas: el nonce y el realm que hacen falta para
# calcular la respuesta. curl los gestiona por ti con --digest.
curl -s -o /dev/null -D - http://localhost:8080/digest-auth/auth/user/password \
  | grep -i '^www-authenticate' | cut -c1-70
# Www-Authenticate: Digest qop=auth, realm="go-httpbin", algorithm=MD5,
```

### 3.2 Cuando el servidor no da ninguna pista

No todos los servidores cumplen. Un caso frecuente: el endpoint devuelve `404`
en vez de `401` para no confirmar que existe. El laboratorio lo reproduce:

```bash
# Mismo recurso, misma credencial, y sin ella NO dice 401: dice 404.
curl -s -o /dev/null -w '%{http_code}\n' \
  http://localhost:8080/hidden-basic-auth/user/password
# 404
```

```bash
# Con la credencial correcta, aparece.
curl -s -o /dev/null -w '%{http_code}\n' \
  -u user:password http://localhost:8080/hidden-basic-auth/user/password
# 200
```

Se llama *seguridad por oscuridad* y no protege gran cosa, pero existe y explica
un `404` que no entiendes: puede que el recurso esté ahí y sea tu credencial la
que falta. Si la documentación dice que el endpoint existe y tú ves `404`,
prueba con credencial antes de abrir un ticket.

### 3.3 Leer el `realm`

El `realm` es la etiqueta del espacio protegido. No es un secreto ni cambia
nada técnico, pero un mismo servidor puede tener varios y te dice cuál te está
pidiendo:

```bash
curl -s -o /dev/null -D - http://localhost:8080/basic-auth/user/password \
  | grep -i '^www-authenticate' | sed 's/.*realm=//'
# "Fake Realm"
```

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Reintentar un `403` con backoff | Nunca va a cambiar. Y algunas APIs cuentan los fallos y bloquean la clave | Abortar con un código de salida propio y avisar |
| Tratar `401` y `500` con el mismo camino de error | Uno se arregla renovando el token, el otro esperando. El script no puede decidir si no los separa | Un código de salida por clase de error. Teoría 08 |
| Mandar `-k` porque «el certificado da problemas» | Basic Auth sobre TLS sin verificar es Basic Auth en claro para quien esté en medio | `--cacert` con la CA correcta. La del laboratorio está en `docs/lab-ca.pem` |
| Deducir el esquema de la documentación y no del servidor | La documentación se queda vieja; el `WWW-Authenticate` es lo que hay hoy | Una petición sin credencial y lee el reto |
| Usar `--anyauth` en un bucle | Duplica el número de peticiones sin que se note en la salida | Averigua el esquema una vez y fíjalo con `--basic`, `--digest` o el header |

---

## 5. Trucos

```bash
# El reto de un endpoint, en una linea, sin bajarte el cuerpo.
curl -s -o /dev/null -D - URL | grep -i '^www-authenticate'
```

```bash
# Comprobar de golpe si un endpoint esta protegido y con que.
# %{http_code} sale de --write-out; el \n final hace falta, curl no lo pone.
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/bearer
# 401
```

```bash
# Ver los dos lados del ciclo en una sola traza: > es lo que sale, < lo que
# entra. Aqui se ve el 401 con su reto y la reperticion ya autenticada.
curl -s --anyauth -u user:password -o /dev/null -v \
  http://localhost:8080/basic-auth/user/password 2>&1 \
  | grep -iE '^[<>] (GET|HTTP/1.1 |www-authenticate|authorization)'
# > GET /basic-auth/user/password HTTP/1.1
# < HTTP/1.1 401 Unauthorized
# < Www-Authenticate: Basic realm="Fake Realm"
# > GET /basic-auth/user/password HTTP/1.1
# > Authorization: Basic dXNlcjpwYXNzd29yZA==
# < HTTP/1.1 200 OK
```

---

## 📚 Recursos Adicionales

- [RFC 9110 §11 — HTTP Authentication](https://datatracker.ietf.org/doc/html/rfc9110#section-11) — el reto, la respuesta y el `realm`, en la fuente
- [RFC 9110 §15.5.2 — 401 Unauthorized](https://datatracker.ietf.org/doc/html/rfc9110#section-15.5.2) — incluida la nota de que el nombre es engañoso
- [RFC 9110 §15.5.4 — 403 Forbidden](https://datatracker.ietf.org/doc/html/rfc9110#section-15.5.4)
- [everything.curl.dev — Authentication](https://everything.curl.dev/http/auth.html) — el capítulo del libro oficial
- [IANA — HTTP Authentication Schemes](https://www.iana.org/assignments/http-authschemes/http-authschemes.xhtml) — el registro completo de esquemas

---

## ✅ Checklist de Verificación

- [ ] Sé decir, con mis palabras, qué pregunta responde la autenticación y cuál la autorización
- [ ] `curl -s -o /dev/null -D - http://localhost:8080/basic-auth/user/password | grep -i www-auth` me devuelve el reto
- [ ] Sé por qué `/status/403` no trae `WWW-Authenticate` y `/status/401` sí
- [ ] He comprobado que `--anyauth` manda dos peticiones y `--basic` una
- [ ] Sé qué le pasa a `/hidden-basic-auth` cuando no mando credencial, y por qué no es un `401`
- [ ] Puedo nombrar los cuatro esquemas de la semana y decir qué viaja en cada uno

---

| Anterior | Siguiente |
|---|---|
| [README de la semana](../README.md) | [02 — Basic Auth](02-basic-auth.md) |
