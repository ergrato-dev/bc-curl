# Rúbrica de evaluación — Semana 08

> OAuth2 y autenticación avanzada. Se evalúa que elijas el flujo según quién
> actúa, que ningún secreto ni token se escape por la línea de comandos, una
> traza o un archivo con permisos de más, y que tu script renueve su
> credencial sin cambiar nunca de identidad en silencio.

---

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales |
| 💪 Desempeño | 40% | Las 4 prácticas, con sus entregables y salida real de tu máquina |
| 📦 Producto | 30% | `api-toolkit.sh`: 60 pts de autograding + 40 pts de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio. Un `auth login` que pasa
los checks no compensa no saber por qué un refresh token revocado no se
arregla con client credentials.

---

## 🧠 Conocimiento (30%)

| # | Pregunta |
|:--:|---|
| 1 | Un compañero propone que el CLI del equipo pida usuario y contraseña y los mande a `/token` con `grant_type=password`, "que es lo más simple". ¿Qué tres problemas tiene? ¿Qué flujo usarías si el CLI corre en el portátil de cada persona, y cuál si corre en un servidor por SSH? |
| 2 | Un cron de backups llama a una API con OAuth2. ¿Qué flujo usa y por qué no recibe refresh token? ¿Qué hace cuando el token caduca? |
| 3 | `curl -u "$ID:$SECRETO" -d grant_type=client_credentials "$TOKEN_URL"` funciona. Di tres sitios por los que ese secreto se puede escapar, y cómo los cierra el toolkit. ¿Por qué el `Authorization: Basic` de una traza es igual de grave que el secreto en claro? |
| 4 | En authorization code, ¿qué ataque frena el `state` y cuál frena PKCE? ¿Por qué un cliente que comprueba bien el `state` pero no usa PKCE sigue expuesto si es una app pública? |
| 5 | Calculas el challenge con `echo "$verifier" \| openssl dgst -sha256 -binary \| base64` y el servidor responde `invalid_grant`. Di los tres errores de esa línea. |
| 6 | Una sesión guarda `"expires_in": 3599`. Una hora después, el script la lee. ¿Qué no puede saber? ¿Qué guarda el toolkit en su lugar, y por qué renueva 30 segundos antes y no justo en el instante? |
| 7 | Un token con `exp` dentro de 40 minutos recibe un 401 de la API. Da dos causas posibles. ¿Qué hace el toolkit, cuántas veces, y por qué no más? |
| 8 | La sesión de `alumno`, abierta con authorization code, tiene un refresh token que alguien revocó. Al renovar, el servidor responde `invalid_grant`. Un compañero propone pedir entonces un token con client credentials "para que el script no se pare". ¿Qué pasaría? ¿Qué hace el toolkit? |
| 9 | `auth logout` hace `rm ~/.bc-curl-session`. ¿Qué queda vivo, dónde y durante cuánto tiempo? ¿Por qué el toolkit no borra la sesión si la revocación falla con un 503, y sí la borra si responde `unsupported_token_type`? |
| 10 | Un script lee el `exp` del payload del access token para decidir si renovar, y en `auth status` imprime el token "para comprobar que existe". ¿Qué está mal en cada cosa? ¿Para qué sí sirve leer el payload desde el cliente? |

<details>
<summary><strong>Respuestas</strong></summary>

**1.** El CLI vería la contraseña, que vale para todo y no solo para lo que el
CLI necesita; no hay forma de usar 2FA ni el SSO de la empresa; y revocar el
acceso del CLI obliga a cambiar la contraseña. Además, el RFC 9700 prohíbe el
*password grant* y OAuth 2.1 lo retira. En el portátil, authorization code +
PKCE con una redirección a loopback; en un servidor por SSH, sin navegador,
device code.

**2.** Client credentials: el cron actúa en nombre propio, no de una persona.
No hay refresh token porque no hace falta (RFC 6749, 4.4.3): las mismas
credenciales que dieron el primer token dan el siguiente. Cuando caduca, pide
otro con client credentials; el toolkit lo hace en `renovar` cuando la sesión
no trae refresh token.

**3.** En el listado de procesos (`ps`, `/proc/PID/cmdline`), visible para
cualquier usuario de la máquina; en el historial del terminal; y en los logs
de quien registre los comandos (CI, `auditd`). El toolkit lo escribe con
`printf` (orden interna, sin proceso) en un `--config` con permisos 600. El
`Authorization: Basic` es base64 de `id:secreto`: se decodifica con `base64
-d`, no es cifrado. Por eso `redactar_traza` lo tacha en `--verbose`.

**4.** El `state` frena el CSRF: que tu cliente acepte un código que inició
otro, y acabes trabajando con la cuenta del atacante. PKCE frena el robo del
código: quien lo intercepte en la redirección no tiene el verifier y no puede
canjearlo. Una app pública no tiene secreto, así que sin PKCE el código
interceptado se canjea con solo el `client_id`, que es público. El `state`
no ayuda: el atacante no inyecta un código, roba el tuyo.

**5.** `echo` añade un salto de línea, y se hashea el verifier con él. `base64`
produce base64 con `+` y `/`, no base64url con `-` y `_`. Y deja el relleno
`=`, que base64url no lleva. Lo correcto: `printf %s "$verifier" | openssl
dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '='`.

**6.** Desde cuándo cuentan esos 3599 segundos: `expires_in` es relativo al
momento de la respuesta, que nadie guardó. El toolkit guarda `expires_at`, el
instante absoluto (`date +%s` + `expires_in`), que se compara con el reloj en
cualquier momento. Renueva con 30 segundos de margen porque una petición que
sale con el token vivo puede llegar con él muerto, y porque el reloj local y
el del servidor nunca coinciden del todo.

**7.** El token fue revocado, o el servidor rotó la clave con la que lo firmó;
también, que cambiaran los permisos del cliente. El toolkit renueva una vez y
repite la petición una vez. Si vuelve a dar 401, sale con 77. Más de una vez
convertiría un cliente sin permisos en un bucle contra el servidor de tokens,
y un 401 que sobrevive a un token recién emitido no es del token.

**8.** El script seguiría funcionando con un token de `sub=api-toolkit`: otra
identidad, con otros permisos, sin que nadie lo sepa. Un script que escribía
como `alumno` empezaría a escribir como el cliente. El toolkit sale con 77 y
pide `auth login`: `rechazo_oauth` trata `invalid_grant` como una credencial
que ya no vale, y `renovar` no prueba nada más.

**9.** El refresh token sigue vivo en el servidor, durante semanas, y
cualquier copia del archivo (una copia de seguridad, otro proceso que lo
leyó) puede seguir usándolo. Con un 503, la revocación no se hizo: si se
borrara la sesión, ya no habría forma local de revocar, así que se conserva
para repetir el `logout`. `unsupported_token_type` es una respuesta definitiva:
el servidor no revoca ese tipo de token y repetir no lo cambiará; se avisa de
que el token vale hasta su `exp` y se borra.

**10.** El formato del access token no es un contrato con el cliente: mañana
puede ser opaco, y el `exp` del payload no dice si está revocado. Se decide
con `expires_at` (de `expires_in`, que sí es contrato) y con el 401 de la API.
Imprimir el token lo deja en la terminal, en el historial del terminal y en
cualquier captura: es un *bearer*, quien lo ve lo usa. Leer el payload sirve
para **mirar**: de quién es (`sub`), para qué API (`aud`), cuándo caduca, al
depurar un 401.

</details>

---

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Pedir un token sin filtrar el secreto | `token.md` con los endpoints del discovery, el secreto visto en `ps` y decodificado de una traza, el token pedido con un `--config` 600, la tabla de los tres errores del endpoint y el token usado contra `/userinfo` sin pasar por la línea de comandos | 10 |
| 02 — Authorization code con PKCE, a mano | `pkce.sh`, `shellcheck` limpio, que genera verifier y challenge S256, comprueba el `state`, canjea con el secreto en un `--config` y deja una sesión 600 que `auth status` reconoce como `sub=alumno`; con los dos rechazos provocados y lo que el simulador deja pasar apuntado en comentarios | 10 |
| 03 — Caducidad y el 401 inesperado | `caducidad.md` con `expires_at` frente a `expires_in`, la renovación dentro y fuera del margen, el 401 con una sesión "activa" y la traza que demuestra una sola renovación y dos peticiones | 10 |
| 04 — Refrescar y revocar | `refresco.md` con un refresh a mano y si el servidor rota, la identidad del token renovado frente a client credentials, la tabla de las tres revocaciones, el 77 del refresh token revocado y la copia de sesión que deja de valer tras el `logout` | 10 |

---

## 📦 Producto (30%)

### Verificable por el autograding — 60 puntos

| Comprobación | Puntos |
|---|:--:|
| `toolkit-ejecutable` | 2 |
| `toolkit-sin-todos` | 2 |
| `toolkit-get-sigue` | 2 |
| `toolkit-login-sesion` | 4 |
| `toolkit-login-600` | 4 |
| `toolkit-login-sin-token` | 4 |
| `toolkit-login-traza-sin-secreto` | 4 |
| `toolkit-status-activa` | 3 |
| `toolkit-status-sin-sesion` | 2 |
| `toolkit-oauth-userinfo` | 4 |
| `toolkit-renueva-caducado` | 4 |
| `toolkit-reintenta-401` | 5 |
| `toolkit-refresh-token` | 5 |
| `toolkit-refresh-revocado-77` | 5 |
| `toolkit-logout-borra` | 2 |
| `toolkit-logout-revoca` | 4 |
| `toolkit-shellcheck` | 4 |
| **Total** | **60** |

### Calidad — 40 puntos

| Criterio | Qué se mira | Puntos |
|---|---|:--:|
| Ningún secreto a la vista | `client_secret`, refresh token y access token solo en `CONFIG_OAUTH` o `CONFIG_CURL`, escritos con `printf` y `escapar_config`; nada en argumentos de procesos externos ni en mensajes | 8 |
| Sesión bien escrita | `expires_at` calculado al recibir; `mktemp` en el mismo directorio y `mv` al final; ningún temporal suelto si `jq` falla; `auth login` empieza de cero y `renovar` conserva el refresh token | 7 |
| Renovación con criterio | Margen antes de la petición; un solo reintento ante un 401 y solo con `AUTH_MODE=oauth`; refresh token si lo hay; nunca client credentials tras un `invalid_grant` | 8 |
| Logout que revoca | Revoca el refresh token si lo hay; con `unsupported_token_type` avisa y borra; con un fallo de red o un 5xx conserva la sesión y sale con su código | 6 |
| Errores del servidor OAuth2 | `rechazo_oauth` explica el `error` y el `error_description`, y sale con 77, 75 o 1 según el caso, sin volcar el cuerpo | 5 |
| Documentación | El `--help` sigue siendo verdad; los comentarios dicen por qué `expires_at`, por qué el margen, por qué no caer a client credentials y por qué revocar antes de borrar | 6 |
| **Total** | | **40** |

### Penalizaciones

| Situación | Deducción |
|---|---|
| Una credencial real (secreto de cliente, refresh token) comiteada, en el código, en un temporal sin 600 o en una traza | **−30** y hay que rotarla ya |
| `renovar` cae a client credentials cuando falla el refresh token | **−20** |
| Un `-k` o `--insecure` en la entrega | **−20** |
| El access token impreso por stdout o stderr en cualquier comando | −10 |
| El reintento ante un 401 en bucle, o con `AUTH_MODE=bearer` | −10 |
| `auth logout` borra la sesión sin intentar revocar | −8 |
| La sesión escrita con `>` directamente sobre el archivo definitivo | −6 |
| `grant_type=password` en cualquier parte del toolkit | −6 |
| `--retry` en la petición de refresh | −5 |
| `shellcheck -S warning` con avisos | −5 |

Las dos primeras no son puntos: son la diferencia entre un script que se
puede dejar en un cron con una credencial ajena y uno que, el día que esa
credencial muere, sigue trabajando con otra que nadie le dio. Esta semana
enseña que la identidad de un script es parte de su contrato.

---

[← README de la Semana 08](README.md)
