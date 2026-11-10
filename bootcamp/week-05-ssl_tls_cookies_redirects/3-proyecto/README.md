# Proyecto — Capa 5: red hostil

> Hasta ahora `api-toolkit.sh` hablaba con un laboratorio en `http://` que
> siempre responde. Esta capa lo prepara para la red de verdad: CAs que no son
> públicas, APIs que piden certificado, sesiones, redirects que no hay que
> seguir a ciegas y servidores que tardan o fallan un segundo.

---

## 🎯 Objetivo

Añadir a `api-toolkit.sh` una función, `construir_red`, que reúne en un solo
sitio las opciones de red de **todas** las peticiones: la CA con la que
validar el servidor, el certificado de cliente, el tarro de cookies, la
política de redirects y la de reintentos. Y traducir los fallos sin respuesta
HTTP a un código de salida propio, el **69**, con un mensaje que diga la
causa.

---

## 📦 Qué añade esta capa

La Semana 04 dejó cuatro verbos autenticados más `download` y `upload`. Esta
capa no añade subcomandos: cambia **cómo** sale cada petición a la red.

| Viene de la Semana 04 | Lo añade esta capa |
|---|---|
| Solo `http://`, o `https://` con CA pública | `API_CACERT`: la CA de un servidor interno |
| Autenticación por usuario, token o API key | `API_CLIENT_CERT` y `API_CLIENT_KEY`: mTLS |
| Cada llamada empieza sin memoria | `COOKIE_JAR`: una sesión entre llamadas, en un tarro con 600 |
| Un `3xx` se devuelve tal cual | `get` sigue redirects, con límite y sin bajar a HTTP |
| `--max-time` | Además `--connect-timeout 5` en todas las peticiones |
| `--retry 3` solo en `download` | Reintentos en GET, PUT y DELETE; nunca en POST |
| curl sale con 60, 47, 28... y el script con él | Código **69** (`EX_UNAVAILABLE`) y un mensaje con la causa |

La política de redirects merece una línea más. `get` sigue redirects **salvo**
con `AUTH_MODE=apikey`: curl quita el `Authorization` al saltar a otro host,
pero no un header propio como `X-API-Key` (teoría 06 §2.4). Y `post`, `put`,
`delete` y `upload` no los siguen nunca: un 302 convierte el POST en GET y el
cuerpo se pierde sin error.

Lo que desbloquea: la Semana 06 instrumenta estas mismas peticiones con
`--write-out` (las fases que mediste en la práctica 04), y la 07 añade el
backoff ante 429 sobre los reintentos que pones aquí.

---

## ✅ Requisitos verificables

Estos son los enunciados exactos de `checks.json`. Si uno falla,
`./scripts/verificar-semana.sh 05` te dice cuál y con qué pista.

1. El frontal HTTPS del laboratorio valida con la CA exportada
2. api-toolkit.sh existe, es ejecutable y arranca con set -euo pipefail
3. No queda ningun TODO por resolver
4. La capa 4 sigue funcionando: download guarda el archivo entero
5. Contra el frontal HTTPS sin API_CACERT, el certificado no valida y sale con 69
6. Con API_CACERT, la peticion HTTPS valida y devuelve el cuerpo
7. Un API_CACERT que no existe es un error de uso, antes de llamar a curl
8. El frontal mTLS rechaza al toolkit sin certificado de cliente: sale con 69
9. Con API_CLIENT_CERT y API_CLIENT_KEY, el frontal mTLS acepta la conexion
10. Una clave privada legible por otros usuarios se rechaza con exit 1
11. Con COOKIE_JAR, una cookie fijada en una llamada se envia en la siguiente
12. El tarro de cookies se crea con permisos 600
13. get sigue los redirects y devuelve el destino final
14. Una cadena de 9 redirects supera el maximo y sale con 69
15. Desde https, un redirect a http no se sigue
16. Con AUTH_MODE=apikey, la clave no viaja a otro host tras un redirect
17. post no sigue redirects: un 302 convertiria el POST en GET
18. get reintenta y post no
19. Todas las peticiones llevan --connect-timeout
20. El script no desactiva la verificacion TLS
21. shellcheck -S warning no encuentra nada

---

## 🎨 Criterios de calidad

Lo que el autograding no ve y la rúbrica sí:

- **Una sola función decide la red.** `construir_red` rellena `RED_CURL` una
  vez y los tres constructores de argumentos lo añaden antes de la URL. Si
  `tamano_remoto` (el HEAD de `--resume`) no lo lleva, una descarga
  reanudada contra HTTPS falla con 60 en el HEAD.
- **Los errores de configuración salen antes de llamar a curl.** Una CA que
  no existe, una clave sin su certificado o una clave con 644 son `exit 1`
  con un mensaje, no un 58 de curl.
- **El tarro nace con 600.** Crearlo con `umask 077` antes de que curl lo
  toque, en un subshell para no cambiar la `umask` del resto del script.
- **`--proto-redir` entre comillas** en el código: `"=https"`. Sin ellas,
  shellcheck avisa, y quien copie la línea a zsh se encuentra un error raro.
- **Ni un `-k`.** Si un servidor no valida, la respuesta es `API_CACERT`.
- **El 69 no tapa el error de curl.** El mensaje de curl (con `-sS`) sigue
  saliendo por stderr; el de `fallo_de_red` va debajo, con la causa en
  palabras.

---

## 💡 Adaptación a tu dominio

| Dominio | CA | mTLS | Cookies | Redirects |
|---|---|---|---|---|
| Código (GitHub) | Pública: `API_CACERT` vacío | No | No: token | La API de *releases* redirige las descargas a otro host: con `bearer`, curl quita el `Authorization` al saltar, que es justo lo correcto |
| Clima (Open-Meteo) | Pública | No | No | Pocas |
| Banca / pagos (sandbox) | A veces propia | **Sí**, muy habitual | No | Raros |
| Una aplicación interna sin API | Propia de la empresa | A veces | **Sí**: el login es un formulario | Login que redirige al panel |

Antes de configurar nada, con lo de la práctica 01:

```bash
# ¿Que CA firma el certificado de tu API, y para que nombres vale?
openssl s_client -connect api.de-tu-dominio.com:443 -servername api.de-tu-dominio.com \
  </dev/null 2>/dev/null | openssl x509 -noout -issuer -ext subjectAltName

# ¿Redirige? ¿A donde?
curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' https://api.de-tu-dominio.com/
```

---

## 🚦 Cómo entregarlo

**1.** Copia el starter. Trae la capa 4 resuelta, así que puedes partir de él
aunque tu versión de la Semana 04 sea distinta:

```bash
cd bootcamp/week-05-ssl_tls_cookies_redirects/3-proyecto/starter/
# Guarda antes tu version de la Semana 04: el cp de abajo la sobrescribe.
cp ~/api-toolkit.sh ~/api-toolkit.semana04.sh 2>/dev/null || true
cp api-toolkit.sh ~/api-toolkit.sh
```

**2.** Resuelve los seis TODOs, en orden. Cada uno es una pieza de
`construir_red` salvo el último:

| TODO | Qué | Teoría |
|---|---|---|
| 1 | `API_CACERT`: comprobar que se lee y añadir `--cacert` | 02 §3.1 |
| 2 | mTLS: las dos variables, la clave con 600, `--cert` y `--key` | 04 §3.1 |
| 3 | `COOKIE_JAR`: crear con 600, `--cookie` y `--cookie-jar` | 05 §3.1 y §3.2 |
| 4 | Redirects: solo GET, nunca `apikey`, `--max-redirs` y `--proto-redir` | 06 §2.4 y §2.5 |
| 5 | Reintentos solo para GET, PUT y DELETE | 08 §3.1 |
| 6 | `ejecutar`: capturar el código de curl y pasarlo a `fallo_de_red` | 07, 08 |

**3.** Pruébalo a mano, desde la raíz del repositorio:

```bash
export CA="$PWD/docs/lab-ca.pem"

# Sin la CA: 60 de curl, 69 del toolkit.
BASE_URL=https://localhost:8443 ~/api-toolkit.sh get /get >/dev/null; echo $?
# curl: (60) SSL certificate problem: unable to get local issuer certificate
# ...
# error: el certificado del servidor no valida: ¿falta API_CACERT? (curl: 60)
# 69

# Con la CA.
BASE_URL=https://localhost:8443 API_CACERT="$CA" ~/api-toolkit.sh get /get | jq -r .url
# https://localhost:8443/get

# Una sesion: el tarro nace con 600.
COOKIE_JAR=/tmp/prueba-tarro.txt ~/api-toolkit.sh get '/cookies/set?sesion=abc' | jq -c .
# {"cookies":{"sesion":"abc"}}
stat -c %a /tmp/prueba-tarro.txt && rm /tmp/prueba-tarro.txt
# 600

# Un bucle de redirects se corta.
~/api-toolkit.sh get /redirect/9 >/dev/null; echo $?
# curl: (47) Maximum (5) redirects followed
# error: demasiados redirects (maximo 5) (curl: 47)
# 69

# Un POST: ni --location ni --retry.
~/api-toolkit.sh --dry-run post /post '{}'
# curl --max-time 10 --request POST ... --data-raw \{\} --connect-timeout 5 http://localhost:8080/post
```

**4.** Pásale el autograding y shellcheck:

```bash
./scripts/verificar-semana.sh 05
shellcheck -S warning ~/api-toolkit.sh
```

---

## 🧯 Errores comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `toolkit-tls-sin-ca-falla` da `exit=60` | Falta el TODO 6: el script sale con el código de curl | Captura el código en un `if` y llama a `fallo_de_red` |
| `--resume` contra HTTPS falla con 60 | `tamano_remoto` no lleva `RED_CURL` | El HEAD necesita la misma CA que la descarga |
| El tarro sale con 644 | Lo creó curl, o lo creaste sin `umask 077` | `(umask 077 && : > "$COOKIE_JAR")` antes de añadir los flags |
| El tarro no guarda nada | Solo `--cookie`, sin `--cookie-jar` | Los dos, sobre el mismo archivo |
| `zsh: https not found` al probar a mano | `=https` sin comillas en zsh | `'=https'` |
| `toolkit-no-filtra-apikey` falla | El `--location` no mira `AUTH_MODE` | Condición doble: GET **y** no `apikey` |
| `toolkit-reintenta-solo-idempotentes` da `post=1` | El `--retry` del starter sigue fuera del `case` | Muévelo dentro de `GET\|PUT\|DELETE)` |
| `toolkit-mtls-con-certificado` falla con `exit=1` | `exigir_600` rechaza la clave generada por el check | Revisa que `exigir_600` acepta `600` y `400` |

---

## 🔗 Navegación

| Anterior | Siguiente |
|---|---|
| [Práctica 04 — Timeouts y reintentos](../2-practicas/04-timeouts-y-reintentos.md) | [Rúbrica de evaluación](../rubrica-evaluacion.md) |

[← Volver a la Semana 05](../README.md)
