# Rúbrica de evaluación — Semana 03

> Autenticación básica. Se evalúa que entiendas los esquemas, sí, pero sobre
> todo que la credencial no acabe donde no debe.

---

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales |
| 💪 Desempeño | 40% | Las 4 prácticas, verificadas por `checks.json` |
| 📦 Producto | 30% | `api-toolkit.sh`: 60 pts de autograding + 40 pts de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio. Un producto impecable no
compensa no saber por qué el `403` no se reintenta.

---

## 🧠 Conocimiento (30%)

| # | Pregunta |
|:--:|---|
| 1 | Un servidor devuelve `401` y otro `403` ante la misma petición. ¿Qué está diciendo cada uno, y por qué un script sensato los trata de forma distinta al decidir si reintenta? |
| 2 | `base64` aparece en Basic Auth y en los JWT. ¿Qué aporta en cada caso, y por qué en ninguno de los dos es una medida de seguridad? |
| 3 | Tienes el token en la variable `$API_TOKEN` y lo pasas con `-H "Authorization: Bearer $API_TOKEN"`. Explica por qué la variable de entorno no evita que el token sea visible en `ps`, y cuál es el mecanismo que sí lo evita. |
| 4 | Una API acepta la clave en un header y en la query string. Ambas van por HTTPS. Argumenta por qué no son equivalentes, y nombra al menos tres sitios donde acaba la de la query. |
| 5 | ¿Por qué Digest necesita dos peticiones y Basic solo una? Relaciónalo con lo que el servidor manda en su reto, y di qué coste tiene eso en un bucle de mil peticiones. |
| 6 | Al decodificar el payload de un JWT, `base64 -d` imprime el JSON correcto **y además** escribe `invalid input`. ¿Qué está pasando, por qué es peligroso en un script con `set -o pipefail`, y cómo se calcula lo que falta? |
| 7 | Puedes leer el payload de un JWT sin ninguna clave. ¿Por qué eso no significa que puedas confiar en lo que dice, y qué haría falta para verificarlo de verdad? |
| 8 | `curl -s` sale con código 0 ante un `401`. Explica por qué curl considera eso un éxito, qué cambia `--fail-with-body`, y qué información se pierde usando `--fail` a secas. |
| 9 | Un script recibe `401`, renueva el token y reintenta. ¿Por qué ese reintento tiene que estar limitado a uno, y qué pasa si se pone en un `while` hasta que funcione? |
| 10 | `chmod 600 cred.txt` justo después de crear el archivo deja un problema abierto. ¿Cuál es, cuánto dura, y cuál es la forma de crear el archivo que no lo tiene? |

<details>
<summary><strong>Respuestas</strong></summary>

**1.** El `401` significa «no sé quién eres»: falta la credencial, está mal
escrita o ha caducado. El `403` significa «sé quién eres y no puedes»: la
credencial es válida pero no alcanza para ese recurso. La diferencia práctica es
que el `401` **puede** arreglarse presentando otra credencial —un token
renovado—, así que un script sensato renueva y reintenta una vez. El `403` no se
arregla con nada que el cliente pueda hacer: hacen falta otros permisos, que los
concede un humano. Reintentar un `403` es repetir exactamente el mismo no, y
contra APIs que cuentan intentos fallidos, un camino directo al bloqueo. El
nombre `401 Unauthorized` es un error histórico del estándar: el que habla de
autorización es el `403`.

**2.** En Basic Auth, base64 convierte `usuario:password` en ASCII imprimible
para que quepa sin problemas en un header HTTP, que es un formato de texto. En un
JWT, base64url —con `-` y `_` en lugar de `+` y `/`, y sin relleno— hace lo mismo
para que el token pueda viajar en una URL sin romper nada. En los dos casos la
operación es **reversible sin ninguna clave**: `base64 -d` la deshace en un
segundo. No es cifrado, es transporte. Lo que aporta confidencialidad es TLS,
que cifra el canal entero incluidos los headers. Por eso un `Authorization:
Basic` en un log es la password en claro con dos segundos de trabajo, y por eso
`-k` es especialmente grave con Basic: desactiva la única comprobación que te
decía con quién estabas hablando antes de mandarle la password.

**3.** Porque el shell expande la variable **antes** de lanzar el proceso. Lo
que curl recibe en su `argv` es el valor literal del token, no el nombre de la
variable. Y el `argv` de cualquier proceso es legible por cualquier usuario de la
máquina a través de `ps` o de `/proc/<pid>/cmdline`, sin privilegios. El
mecanismo que sí lo evita es pasarle a curl una **referencia** en vez de un
valor: `--config archivo` con una línea `header = "Authorization: Bearer …"`,
`--netrc-file` para Basic, o `-H @archivo` desde curl 7.55. En el `argv` queda
solo la ruta, y el contenido lo lee curl del disco. Se comprueba lanzando la
petición contra `/delay/3` en segundo plano y mirando `ps -eo args | grep '^curl '`.

**4.** No son equivalentes porque TLS protege el **tránsito**, y el problema de
la query string ocurre en los **extremos**. El servidor descifra la petición y
entonces escribe su log de acceso, que incluye la ruta completa con su query. Lo
mismo hace el proxy o el balanceador que haya delante. Tres sitios más, todos
fuera de tu control: el header `Referer`, que manda la URL entera al tercero al
que enlaces; el historial y los marcadores del navegador, con sus copias de
seguridad; y cualquier captura de pantalla o ticket, porque la URL es lo que la
gente copia y pega. Los headers de petición, en cambio, no se registran en los
logs de acceso por defecto.

**5.** Porque la respuesta de Digest se calcula con un `nonce` —un número de un
solo uso— que **lo genera el servidor** y viaja en el reto `WWW-Authenticate`. El
cliente no puede calcular el hash antes de tenerlo, así que la primera petición
va sin credencial solo para provocar el `401` y leer el nonce; la segunda ya
lleva la respuesta. Basic no necesita nada del servidor —el header es
`base64(usuario:password)` y punto—, así que curl lo manda de entrada. En un
bucle de mil peticiones eso son mil idas y vueltas extra, que en localhost no se
notan y en un enlace con latencia sí. Es también el motivo para no usar
`--anyauth` en bucles: gasta esa petición incluso cuando el servidor pide Basic.

**6.** base64url no lleva relleno, y `base64 -d` espera una cadena cuya longitud
sea múltiplo de 4. GNU base64 decodifica lo que puede, lo imprime, y **además**
escribe `invalid input` en stderr con código de salida distinto de cero. En una
sesión interactiva parece que funcionó; en un script con `set -o pipefail` la
tubería entera falla y tumba la ejecución, con la particularidad de que la
salida correcta ya se había impreso. Es un bug intermitente, porque depende de
si la longitud del payload concreto era múltiplo de 4 o no. Lo que falta se
calcula como `(4 - longitud % 4) % 4`, y ese es el número de `=` a añadir; el
`% 4` final evita añadir cuatro cuando la longitud ya era exacta.

**7.** Porque el payload solo está codificado, no firmado *para ti*. Cualquiera
puede escribir un JSON con los campos que quiera, codificarlo en base64url,
ponerle una tercera parte inventada y obtener algo que se decodifica
perfectamente. Lo que impide falsificarlo es la firma, y verificarla requiere la
clave: la secreta compartida con `HS256` —que si estuviera en el cliente le
permitiría emitir tokens— o la pública del emisor con `RS256`, que hay que bajar
de su `/.well-known/…`, elegir por el `kid` del header y verificar
criptográficamente. Nada de eso se hace con `base64` y `jq`. Y no hace falta: el
que decide si el token vale es el servidor cuando se lo mandas. Del lado del
cliente, el payload sirve para una sola cosa —saber cuándo caduca— y nunca para
tomar decisiones de permisos.

**8.** Porque para curl el trabajo era transferir, y transfirió: mandó la
petición y recibió una respuesta completa. Que esa respuesta sea un `401` es
información de la capa HTTP, no un fallo de transferencia. `--fail-with-body`
cambia eso: ante un `4xx` o `5xx` curl sale con `22` y **conserva el cuerpo**.
`--fail` a secas también sale con `22`, pero descarta el cuerpo, y ahí es justo
donde muchas APIs explican el motivo —si el token caducó o si nunca fue válido,
qué campo falta, qué scope hace falta—. Sin esa información el script no puede
distinguir un caso recuperable de uno que no lo es. `--fail-with-body` existe
desde curl 7.76.

**9.** Porque si el token recién renovado también devuelve `401`, el problema no
es el token: es que la credencial está revocada, es del entorno equivocado, o el
usuario ha perdido el permiso. Ninguna de esas cosas mejora pidiendo más tokens.
Un `while` hasta que funcione se convierte en un bucle que martillea el endpoint
de token indefinidamente, que es una de las formas más rápidas de que bloqueen
una cuenta de servicio, y además puede consumir cuota de la API. El patrón
correcto es: un reintento tras renovar, y si vuelve a fallar, abortar con un
código de salida que diga «problema de credencial» para que un humano lo mire.

**10.** El archivo existe entre las dos operaciones con los permisos por defecto
del `umask`, normalmente `644`, y ya tiene el secreto dentro. Cualquier proceso
de cualquier usuario que lo lea en esa ventana se lleva la credencial. La
ventana dura milisegundos, lo cual es despreciable en tu portátil y no lo es en
una máquina compartida o en un runner de CI con trabajos en paralelo. La forma
que no tiene ese problema es crear el archivo ya con los permisos correctos:
`(umask 077; printf '…' > cred.txt)`. Los paréntesis limitan el cambio de
`umask` a esa subshell, para no afectar al resto del script.

</details>

---

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Basic Auth y el reto | `reto.md` con los tres retos y la frase de la diferencia; `authorization-a-mano.txt` con los dos base64 coincidiendo | 10 |
| 02 — Sacar la credencial de la línea | `prueba-ps.md` con las dos salidas de `ps`; `auth.conf` y `cabeceras.txt` con permisos `600` y funcionando | 10 |
| 03 — Bearer y el JWT por dentro | `jwt.md` con el payload decodificado, el `exp` legible, el veredicto y la frase sobre la firma | 10 |
| 04 — Cuando la credencial falla | `clasificar-error.sh` devolviendo `0`, `77` y `1` en los casos correctos, y limpio de `shellcheck` | 10 |

---

## 📦 Producto (30%)

### Verificable por el autograding — 60 puntos

| Comprobación | Puntos |
|---|:--:|
| `toolkit-ejecutable` | 4 |
| `toolkit-sin-todos` | 4 |
| `toolkit-basic-auth` | 5 |
| `toolkit-basic-auth-credencial-mala` | 4 |
| `toolkit-bearer` | 5 |
| `toolkit-bearer-token-intacto` | 4 |
| `toolkit-apikey-en-header` | 5 |
| `toolkit-sin-credencial-da-77` | 4 |
| `toolkit-403-tambien-da-77` | 4 |
| `toolkit-otro-error-no-es-77` | 4 |
| `toolkit-token-no-en-la-linea-de-comandos` | 6 |
| `toolkit-dry-run-oculta-el-secreto` | 4 |
| `toolkit-rechaza-credenciales-legibles` | 4 |
| `toolkit-sin-credencial-escrita-dentro` | 3 |
| **Total** | **60** |

### Calidad — 40 puntos

| Criterio | Qué se mira | Puntos |
|---|---|:--:|
| Limpieza garantizada | El archivo de credenciales se borra con `trap ... EXIT`, no con un `rm` al final | 6 |
| Permisos desde el nacimiento | `(umask 077; ...)`, no `chmod` después | 6 |
| Precedencia correcta | El entorno manda sobre `~/.bc-curl`, y está documentado | 5 |
| El archivo se lee, no se ejecuta | Nada de `source`: se filtra con `grep` y se asigna a mano | 5 |
| Mensajes accionables | El error de permisos dice el `chmod` exacto; todos van a stderr | 5 |
| Redacción total | `--dry-run` usa un texto fijo, sin ningún fragmento del valor | 5 |
| Documentación de salida | La cabecera explica qué significa cada código, incluido el `77` | 4 |
| Legibilidad | Funciones con una responsabilidad, comentarios que explican el porqué | 4 |
| **Total** | | **40** |

---

### Penalizaciones

| Situación | Deducción |
|---|---|
| Un `-k` o `--insecure` en la entrega | **−20** |
| Una credencial real comiteada, aunque sea en el histórico | **−30** y hay que rotarla ya |
| Un token con formato válido en el material, aunque sea inventado | −10 |
| El secreto aparece en el `argv` de curl | −15 |
| `--dry-run` imprime parte del secreto | −10 |
| El archivo de credenciales dentro del repositorio | −10 |
| `source ~/.bc-curl` en vez de leerlo | −8 |
| Sin `--max-time` en alguna petición | −6 |
| Bucle de renovación sin límite de reintentos | −6 |
| Mensajes de error en stdout | −4 |
| Avisar de los permisos abiertos y continuar | −6 |
| `shellcheck -S warning` con avisos | −5 |

Las dos primeras no son puntos: son la diferencia entre un script que se puede
poner en producción y uno que no. Un `-k` en la entrega de la semana que enseña
a manejar credenciales invalida el ejercicio entero.

---

[← README de la Semana 03](README.md)
