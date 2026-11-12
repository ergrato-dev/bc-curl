# Semana 08 — OAuth2 y autenticación avanzada

> Hasta ahora el token te lo daban hecho y lo pegabas en una variable. En una
> API de verdad el token se pide, caduca a la hora, se renueva, se revoca y
> pertenece a alguien. Esta semana aprendes a hablar con un servidor OAuth2
> con curl, sin dejar el secreto en `ps`, y a que tu script sepa cuándo su
> token ya no vale y qué hacer entonces.

---

## 🎯 Objetivos de la Semana

Al terminar serás capaz de:

- Explicar qué problema resuelve OAuth2, qué papel juega cada parte y por qué un token es mejor que una password compartida
- Pedir un token al endpoint de token con un formulario bien codificado, autenticando al cliente sin que el secreto aparezca en la línea de comandos
- Elegir el flujo según quién actúa: client credentials para una máquina, authorization code + PKCE para una persona con navegador, device code para una persona sin él
- Hacer a mano un authorization code con PKCE: `code_verifier`, `code_challenge`, `state`, el intercambio y por qué un código no se puede usar dos veces
- Gestionar el ciclo de vida de un token: `expires_in` convertido en instante, margen de caducidad, refresco, rotación, revocación y el 401 que llega antes de tiempo
- Leer un JWT por dentro sin confundir leerlo con validarlo
- Guardar una sesión OAuth2 en disco con permisos 600, escritura atómica y un `logout` que revoca de verdad

---

## 📋 Prerrequisitos

- **Semana 07 completada**: `api-toolkit.sh` con la capa 7 y `./scripts/verificar-semana.sh 07` en verde. Esta semana usa el 77 de un 401 y el 75 de un fallo temporal
- **Semana 03 repasada**: el `--config` temporal con permisos 600 y `escapar_config`. El secreto del cliente OAuth2 viaja por el mismo camino que la password de entonces
- **El laboratorio arriba**: `./scripts/start.sh`. El servidor OAuth2 responde en `http://localhost:8081/default`; compruébalo con `curl -s http://localhost:8081/default/.well-known/openid-configuration | jq .token_endpoint`
- **`jq`, `openssl` y `base64` a mano**: `openssl` calcula el `code_challenge` de PKCE y `base64` decodifica un JWT
- **Tu versión de curl**: `curl --version | head -1`. Todo lo de esta semana funciona en 7.81; `--oauth2-bearer` funciona con HTTP desde la 7.61 y `--variable` (8.3+) solo aparece como alternativa

---

## 🗂️ Estructura de la Semana

```
week-08-oauth2_y_autenticacion_avanzada/
├── README.md                  # Este archivo
├── rubrica-evaluacion.md      # Cómo se evalúa
├── checks.json                # Las 18 comprobaciones automáticas
├── 0-assets/                  # Diagramas
├── 1-teoria/                  # 8 archivos, un concepto cada uno
├── 2-practicas/               # 4 prácticas sobre el laboratorio
├── 3-proyecto/                # La capa 8 de api-toolkit: OAuth2
├── 4-recursos/                # Libros, vídeos y enlaces
└── 5-glosario/                # Términos de esta semana
```

---

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01 — El problema que resuelve OAuth2](1-teoria/01-el-problema-que-resuelve-oauth2.md) | Delegar sin dar la password, los cuatro roles, access token, scope y qué flujo usar según quién actúa | 15 min |
| [02 — El endpoint de token](1-teoria/02-el-endpoint-de-token.md) | El formulario, `--data-urlencode`, autenticar al cliente con Basic o en el cuerpo, la respuesta y los errores del RFC 6749 | 15 min |
| [03 — Client credentials](1-teoria/03-client-credentials.md) | Una máquina en nombre propio: el flujo, el scope, por qué no hay refresh token y cuándo no usarlo | 15 min |
| [04 — Authorization code y PKCE](1-teoria/04-authorization-code-y-pkce.md) | La redirección, `state`, el código de un solo uso, `code_verifier` y `code_challenge`, y qué ataque frena cada pieza | 15 min |
| [05 — Device code](1-teoria/05-device-code.md) | Una persona sin navegador en esa máquina: el código de usuario, el sondeo, `authorization_pending` y `slow_down` | 15 min |
| [06 — El ciclo de vida del token](1-teoria/06-ciclo-de-vida-del-token.md) | `expires_in` y `expires_at`, el margen, el refresh token, la rotación, la revocación y el 401 que llega antes del `exp` | 15 min |
| [07 — Un JWT por dentro](1-teoria/07-jwt-por-dentro.md) | Las tres partes, base64url, los claims que importan, por qué leer no es validar, JWKS e introspección | 15 min |
| [08 — Guardar la sesión](1-teoria/08-guardar-la-sesion.md) | Dónde vive el token, permisos 600, escritura atómica, qué no imprimir nunca y un `logout` que revoca | 15 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01 — Pedir un token sin filtrar el secreto](2-practicas/01-pedir-un-token-sin-filtrar-el-secreto.md) | Discovery, client credentials, el secreto en `ps`, el `--config`, los errores del endpoint y el token contra `/userinfo` | 50 min |
| [02 — Authorization code con PKCE, a mano](2-practicas/02-authorization-code-con-pkce-a-mano.md) | Generar el verifier y el challenge, el login, el código en la redirección, el intercambio, los dos rechazos y lo que el simulador no comprueba | 50 min |
| [03 — Caducidad y el 401 inesperado](2-practicas/03-caducidad-y-el-401-inesperado.md) | `expires_at` en disco, el margen, simular un token caducado y uno muerto antes de tiempo, y reintentar una sola vez | 50 min |
| [04 — Refrescar y revocar](2-practicas/04-refrescar-y-revocar.md) | El refresh token, la identidad que conserva, revocar con `token_type_hint` y el `invalid_grant` que no se arregla solo | 50 min |

### Proyecto

La **capa 8** de tu plataforma: `api-toolkit.sh` consigue su propio token.
`auth login` lo pide con client credentials y abre una sesión en un archivo
con permisos 600; `auth status` dice cuánto le queda y de quién es sin
imprimirlo nunca; `auth logout` lo revoca antes de borrarlo. Con
`AUTH_MODE=oauth`, cada petición usa el token de la sesión, lo renueva sola si
caduca y repite una vez si la API responde 401. Detalles en
[3-proyecto](3-proyecto/README.md).

---

## ⏱️ Distribución del Tiempo (8 horas)

| Bloque | Tiempo |
|---|:--:|
| Teoría (8 archivos) | 2 h 00 |
| Prácticas (4 × 50 min) | 3 h 20 |
| Proyecto | 2 h 00 |
| Revisión y verificación | 40 min |
| **Total** | **8 h 00** |

> [!TIP]
> Haz la práctica 01 antes del TODO 1 del proyecto, la 03 antes de los TODOs
> 2, 3 y 5, y la 04 antes de los TODOs 4 y 6. Ver tu propio secreto en la
> salida de `ps` es lo que hace obvio por qué todo va en el `--config`; ver
> cómo un refresh token revocado no tiene arreglo es lo que hace obvio por qué
> `renovar` no prueba otra cosa.

---

## 🧭 Qué flujo, según quién actúa

OAuth2 no es un flujo: son varios, y elegir mal es el primer error. La
pregunta no es "qué API uso", sino **quién está detrás de la petición**:

| Quién actúa | Flujo | Refresh token | Dónde se ve |
|---|---|:--:|---|
| Un script, un cron, un servicio, en nombre propio | Client credentials | No | Teoría 03 · Práctica 01 |
| Una persona, con navegador en la misma máquina | Authorization code + PKCE | Sí | Teoría 04 · Práctica 02 |
| Una persona, en una máquina sin navegador (SSH, TV, CI) | Device code | Sí | Teoría 05 |
| Una persona que te da su usuario y su password | Ninguno: el RFC 9700 prohíbe el *password grant*, y OAuth 2.1 lo retira | — | Teoría 01 |

El toolkit de esta semana es un script: usa client credentials. Pero renueva
también una sesión que traiga refresh token, porque esa sesión puede haberla
abierto una persona con authorization code, como harás en la práctica 02.

---

## 🎩 Trucos y atajos

| Truco | Cómo |
|---|---|
| Descubrir los endpoints de un servidor OAuth2 sin leer su documentación | `curl -s https://servidor/.well-known/openid-configuration \| jq '{token_endpoint, authorization_endpoint, revocation_endpoint, jwks_uri}'` |
| Un campo de formulario sin escaparlo a mano | `--data-urlencode 'scope=leer escribir'` codifica el espacio (`+` en 7.81) y cualquier `&` o `=` del valor. Con `-d`, un `&` dentro del valor parte el campo en dos |
| Mandar un valor secreto codificado sin ponerlo en la línea | `printf %s "$TOKEN" \| curl --data-urlencode token@- ...`. `nombre@-` lee el valor de stdin y lo codifica; `@-` a secas codificaría también el `=` |
| El secreto del cliente fuera de `ps` | Una línea `user = "id:secreto"` en un `--config` temporal con permisos 600. `-u id:secreto` lo deja en `/proc/PID/cmdline` |
| Leer un JWT sin herramientas | `cut -d. -f2 <<<"$JWT" \| tr '_-' '/+' \| base64 -d 2>/dev/null \| jq .` (añade `=` hasta que la longitud sea múltiplo de 4 si `base64` se queja) |
| Calcular un `code_challenge` S256 | `printf %s "$VERIFIER" \| openssl dgst -sha256 -binary \| base64 \| tr '+/' '-_' \| tr -d '='` |
| El código de una redirección sin seguirla | `curl -s -o /dev/null -w '%{redirect_url}' URL`. El `code` va en la query de esa URL |
| Saber si un token sigue vivo según el servidor | `POST /introspect` con `token=...`: `{"active": true, ...}`. Más fiable que leer el `exp`, y cuesta una petición |
| Convertir `expires_in` en algo que siga valiendo dentro de una hora | `jq --argjson ahora "$(date +%s)" '.expires_at = $ahora + .expires_in'`. Guarda el instante, no la duración |
| Comprobar la caducidad sin decodificar el token | `[ "$(date +%s)" -ge $(( expires_at - 30 )) ]`. El margen cubre el reloj desajustado y el viaje de la petición |

---

## 📌 Entregables

1. `token.md` con los endpoints del discovery, los sitios donde se filtra el secreto (`ps`, historial, traza) y los tres errores del endpoint de token provocados
2. `pkce.sh`, que hace el authorization code + PKCE completo contra el laboratorio y demuestra los dos rechazos: verifier incorrecto y código reutilizado; deja además una sesión con refresh token para la práctica 04
3. `caducidad.md` con una sesión caducada a mano, un token muerto antes de su `exp`, y el reintento único que lo arregla
4. `refresco.md` con un refresh, una revocación con su `token_type_hint` y el `invalid_grant` posterior
5. `api-toolkit.sh` con la capa 8 completa y ningún `TODO` pendiente
6. `auth login` guarda una sesión con `expires_at` en un archivo con permisos 600, y no imprime el token
7. Con `AUTH_MODE=oauth`, una sesión caducada se renueva antes de la petición, y un 401 la renueva y repite una sola vez
8. Un refresh token revocado sale con 77, sin caer a client credentials
9. `auth logout` revoca el refresh token en el servidor antes de borrar la sesión

---

## ✅ Verificación

```bash
./scripts/start.sh
./scripts/verificar-semana.sh 08
```

Las 18 comprobaciones tienen que pasar. Si alguna falla, la pista te dice en qué
TODO del proyecto se arregla.

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [Semana 07 — Scripting bash con curl](../week-07-scripting_bash_con_curl/README.md) | **Semana 08 — OAuth2 y autenticación avanzada** | [Semana 09 — HTTP/2, paralelismo y rendimiento](../week-09-http2_paralelismo_performance/README.md) |

[← Volver al inicio del bootcamp](../README.md)
