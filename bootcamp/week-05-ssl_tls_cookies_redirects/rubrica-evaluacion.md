# Rúbrica de evaluación — Semana 05

> SSL/TLS, cookies y redirects. Se evalúa que curl hable con la red de verdad
> sin apagar ninguna defensa: que confíe en quien debe, que se presente cuando
> se lo piden, que no espere para siempre y que no repita lo que no se puede
> repetir.

---

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales |
| 💪 Desempeño | 40% | Las 4 prácticas, con sus entregables .md y salida real de tu máquina |
| 📦 Producto | 30% | `api-toolkit.sh`: 60 pts de autograding + 40 pts de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio. Un toolkit que pasa
todas las comprobaciones no compensa no saber por qué `-k` no arregla un 60.

---

## 🧠 Conocimiento (30%)

| # | Pregunta |
|:--:|---|
| 1 | TLS da confidencialidad, integridad y autenticidad. ¿Cuál de las tres depende de la verificación del certificado, y por qué las otras dos no sirven de nada sin ella? |
| 2 | Un script falla con 60 contra una API interna y alguien propone `-k`. ¿Qué apaga exactamente `-k`, qué ataque deja abierto, y cuál es el arreglo correcto? |
| 3 | `curl --cacert interna.pem https://curl.se` funciona en tu Ubuntu y falla con 60 en la imagen oficial de curl. ¿Por qué? ¿Qué añadirías para que se comporte igual en las dos? |
| 4 | `curl https://10.0.0.5/` falla con 35 y `curl https://api.interna/` (que resuelve a esa IP) funciona. ¿Qué tiene que ver el SNI? ¿Cómo probarías ese nodo concreto sin cambiar el nombre? |
| 5 | Explica la diferencia entre un 56 con `alert certificate required` y un 58 en una conexión mTLS: quién falla en cada caso y qué revisarías. |
| 6 | Tu clave privada de cliente está cifrada. ¿Por qué no vale `--pass "$FRASE"` aunque la frase venga de una variable, y dónde va? |
| 7 | Un login fija una cookie y redirige al panel. Con `curl -L` llegas al panel sin sesión. ¿Por qué? ¿Qué flag mínimo lo arregla, y qué harías además si la sesión tiene que sobrevivir al comando? |
| 8 | `curl -L -d dato=1 URL` y el servidor responde 302. ¿Con qué método y qué cuerpo llega la segunda petición? ¿Y con 307? ¿Qué cambia si añades `-X POST`? |
| 9 | Con `-u` y con `-H 'X-API-Key: ...'`, un redirect lleva a otro host. ¿Qué credencial llega al host nuevo y cuál no? ¿Qué política de redirects se sigue de ahí para el toolkit? |
| 10 | `curl --retry 3 --max-time 10` contra un servidor que nunca responde: ¿cuánto tarda en el peor caso? ¿Por qué el toolkit no pone `--retry` en un POST, aunque el servidor devuelva 503? |

<details>
<summary><strong>Respuestas</strong></summary>

**1.** La **autenticidad**. El cifrado y la integridad funcionan exactamente
igual con el servidor bueno que con un impostor que intercepta la conexión:
cifras perfectamente... hacia el atacante. Lo único que distingue a uno de
otro es que el certificado esté firmado por una CA en la que confías, para el
nombre que pediste, y dentro de sus fechas.

**2.** `-k` desactiva la verificación del certificado: la cadena, el nombre y
las fechas. El cifrado sigue, pero con cualquiera que esté al otro lado. Deja
abierto un ataque de intermediario: quien controle la red (una wifi, un
proxy, un DNS envenenado) presenta su propio certificado y curl lo acepta,
credenciales incluidas. El arreglo es obtener la CA interna por un canal de
confianza, comprobar su huella y pasarla con `--cacert` (o `CURL_CA_BUNDLE`).

**3.** El curl de Ubuntu está compilado con un **CApath** por defecto
(`/etc/ssl/certs`). `--cacert` sustituye el CAfile, pero el CApath sigue, así
que las CAs públicas siguen siendo de confianza y `curl.se` valida. La imagen
oficial no tiene CApath: con `--cacert` solo queda tu CA y `curl.se` falla.
Para el mismo comportamiento: `--capath /dev/null` junto al `--cacert`.

**4.** En el handshake el cliente manda el nombre al que quiere hablar (SNI).
Con una IP en la URL no hay nombre, y un servidor que elige el certificado por
SNI no tiene qué presentar: corta el handshake, 35. Con el nombre, presenta el
certificado correcto. Para probar ese nodo sin perder el nombre:
`--resolve api.interna:443:10.0.0.5` o `--connect-to`, manteniendo la URL.

**5.** El **56** es el servidor rechazándote: pidió certificado (`Request
CERT`), no lo diste o no le gustó, y mandó una alerta. Revisa que pasas
`--cert` y `--key`, y que tu certificado lo firmó la CA que el servidor
espera. El **58** es tu lado: curl no pudo cargar el certificado o la clave
(no existe, la clave no corresponde, la frase falta). Revisa rutas, formato
y que las huellas de las claves públicas coinciden.

**6.** Porque el argv de cualquier proceso es visible con `ps` para todos los
usuarios del equipo mientras curl se ejecuta, y puede quedar en logs de
auditoría. Que el valor venga de una variable no cambia nada: la shell la
expande antes de ejecutar. Va en un archivo de configuración con permisos 600
(`pass = "..."`) que se pasa con `--config`.

**7.** El motor de cookies de curl está **apagado** hasta que usas `-b` o
`-c`: el `Set-Cookie` del login se ignora y el salto llega sin cookie. `-b ''`
lo enciende sin mandar nada. Para que la sesión sobreviva al comando: un tarro
con `-b tarro -c tarro`, creado antes con `umask 077` para que tenga 600.

**8.** Con 302, la segunda petición es un **GET sin cuerpo**: curl, como los
navegadores, convierte POST en GET en 301, 302 y 303. Con 307 (y 308) llega
como **POST con el mismo cuerpo**. Con `-X POST`, curl fuerza POST en **todas**
las peticiones de la cadena, incluso tras un 303 que pide GET: casi siempre un
error. Para mantener el POST a propósito están `--post301/302/303`.

**9.** El `Authorization` de `-u` (y uno propio con `-H 'Authorization:'`) se
**quita** al cambiar de host. `X-API-Key` **no**: curl no sabe que es secreto y
lo manda entero al host nuevo, en 7.81 y en 8.21. Política del toolkit: con
`AUTH_MODE=apikey` no se siguen redirects; con `basic` y `bearer` sí, porque
curl quita la credencial al saltar.

**10.** Cuatro intentos de 10 s más las esperas 1 + 2 + 4: **47 s**. Sin
`--retry-max-time` no hay techo para el conjunto. El POST no se reintenta
porque no es idempotente: el 503 (o un timeout) puede llegar **después** de
que el servidor haya creado el recurso; repetirlo crea un segundo. Solo es
seguro con una clave de idempotencia que la API respete.

</details>

---

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Confiar y verificar | `tls.md` con el 60 y el 35 explicados, las tres formas de dar la CA y el efecto del CApath; `certificado.md` con huella, campos, duración y el pin roto | 10 |
| 02 — Certificado de cliente | `mtls.md` con el 56, los tres 58 y la comprobación de que certificado y clave casan; clave cifrada usada con la frase en un `--config` | 10 |
| 03 — Sesiones y redirects | `sesion.md` con la sesión de tres comandos y el tarro columna a columna; `redirects.md` con la tabla de los cinco códigos y las credenciales entre hosts | 10 |
| 04 — Timeouts y reintentos | `resiliencia.md` con las fases medidas, los dos 28, el cálculo del peor caso acotado con `--retry-max-time` y la respuesta sobre el POST | 10 |

---

## 📦 Producto (30%)

### Verificable por el autograding — 60 puntos

| Comprobación | Puntos |
|---|:--:|
| `toolkit-ejecutable` | 2 |
| `toolkit-sin-todos` | 2 |
| `toolkit-sigue-descargando` | 2 |
| `toolkit-tls-sin-ca-falla` | 4 |
| `toolkit-tls-con-ca` | 4 |
| `toolkit-cacert-inexistente` | 3 |
| `toolkit-mtls-sin-certificado` | 3 |
| `toolkit-mtls-con-certificado` | 4 |
| `toolkit-mtls-clave-legible` | 4 |
| `toolkit-cookies-persisten` | 3 |
| `toolkit-cookie-jar-600` | 4 |
| `toolkit-sigue-redirects` | 3 |
| `toolkit-corta-bucles` | 3 |
| `toolkit-no-baja-a-http` | 4 |
| `toolkit-no-filtra-apikey` | 4 |
| `toolkit-post-no-sigue-redirects` | 2 |
| `toolkit-reintenta-solo-idempotentes` | 3 |
| `toolkit-connect-timeout` | 2 |
| `toolkit-sin-insecure` | 2 |
| `toolkit-shellcheck` | 2 |
| **Total** | **60** |

### Calidad — 40 puntos

| Criterio | Qué se mira | Puntos |
|---|---|:--:|
| Un solo sitio para la red | `construir_red` rellena `RED_CURL` y lo usan los tres constructores y `tamano_remoto`; ninguna opción de red repetida en otra parte | 7 |
| Validar antes de llamar | CA, certificado y clave inexistentes o mal protegidos salen con 1 y un mensaje, sin que curl llegue a ejecutarse | 6 |
| Secretos protegidos | El tarro nace con 600 (en un subshell con `umask 077`); la clave se exige con 600 o 400 | 6 |
| Política de redirects razonada | Solo GET, nunca `apikey`, `--max-redirs`, `--proto-redir` entre comillas; un comentario dice por qué | 6 |
| Idempotencia | `--retry` con `--retry-connrefused` y `--retry-max-time` solo en GET, PUT y DELETE | 5 |
| Mensajes accionables | El 69 dice la causa en palabras y deja visible el error de curl; todo a stderr | 5 |
| Documentación de salida | La cabecera explica las cuatro variables nuevas y el código 69 | 5 |
| **Total** | | **40** |

### Penalizaciones

| Situación | Deducción |
|---|---|
| Un `-k` o `--insecure` en la entrega | **−20** |
| Una credencial, clave privada o tarro real comiteado, aunque sea en el histórico | **−30** y hay que rotarlo ya |
| `--pass`, o la frase en `--cert c:frase`, en el código | −15 |
| `--location-trusted` | −10 |
| `--retry` en `post` o `upload` | −8 |
| `-L` con `AUTH_MODE=apikey` | −8 |
| El tarro creado por curl (644) | −8 |
| `-X POST` junto a `--location` | −6 |
| Sin `--connect-timeout` en alguna petición | −5 |
| `--retry-all-errors` | −5 |
| Mensajes de error en stdout | −4 |
| `shellcheck -S warning` con avisos | −5 |

Las dos primeras no son puntos: son la diferencia entre un script que se puede
poner en producción y uno que no. Esta semana es justo la que enseña a no
necesitar `-k`; usarlo en la entrega es no haberla hecho.

---

[← README de la Semana 05](README.md)
