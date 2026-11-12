# Proyecto — Capa 8: con sesión propia

> Hasta ahora, el token de `api-toolkit.sh` llegaba de fuera: alguien lo
> pegaba en `~/.bc-curl` y, cuando caducaba, el script fallaba con 77. Esta
> capa le da una sesión OAuth2 propia: la abre, la guarda sin enseñarla, la
> renueva antes de que caduque, sobrevive a un 401 inesperado y, al cerrarla,
> la revoca en el servidor.

---

## 🎯 Objetivo

Que el toolkit **consiga y cuide su propio token**. Un subcomando nuevo,
`auth`, con tres acciones: `login` pide un token con client credentials y lo
guarda en un archivo 600; `status` dice cuánto le queda y de quién es, sin
imprimirlo; `logout` revoca y borra. Con `AUTH_MODE=oauth`, cada petición usa
el token de la sesión, lo renueva con margen si caduca, y repite **una vez**
si la API responde 401. Si la sesión trae refresh token, la renovación lo usa
y conserva la identidad; si ese refresh token ya no vale, sale con 77 y nunca
cambia de identidad en silencio.

---

## 📦 Qué añade esta capa

La Semana 07 hizo el toolkit robusto ante fallos del servidor. Esta capa lo
hace responsable de su credencial.

| Viene de la Semana 07 | Lo añade esta capa |
|---|---|
| `AUTH_MODE` = `none`, `bearer`, `apikey`, `basic` | `oauth`: el token sale de la sesión, y viaja como `bearer` |
| Un 401 sale con 77 | Con `oauth`, un 401 renueva y repite una vez; el segundo 401 sale con 77 |
| El token caduca y nadie se entera hasta el 401 | `sesion_caducada` con `MARGEN_CADUCIDAD=30`: se renueva antes |
| — | `auth login`, `auth status`, `auth logout` |
| — | `peticion_oauth`: un `POST` de formulario con el secreto en un `--config` |
| — | `guardar_sesion`: `expires_at`, permisos 600, escritura atómica |
| — | `renovar`: con refresh token si lo hay, con client credentials si no |
| — | `rechazo_oauth`: el campo `error` del RFC 6749 traducido a 77, 75 o 1 |
| — | Variables nuevas: `OAUTH_CLIENT_ID`, `OAUTH_CLIENT_SECRET`, `OAUTH_SCOPE`, `OAUTH_TOKEN_URL`, `OAUTH_REVOKE_URL`, `OAUTH_SESSION_FILE` |

Tres decisiones que conviene entender antes de empezar:

- **`auth login` usa client credentials, y nada más.** El toolkit es un
  script: actúa en nombre propio. Authorization code + PKCE lo haces a mano en
  la práctica 02, y el toolkit **renueva** esa sesión, pero no la abre: un
  servidor local que escuche la redirección es más código que toda esta capa.
- **El secreto del cliente vive donde vivía el token**: en el entorno o en
  `~/.bc-curl`. `OAUTH_CLIENT_ID` y `OAUTH_CLIENT_SECRET` se leen igual que
  `API_TOKEN` desde la Semana 03.
- **`auth status` y `auth logout` no necesitan `AUTH_MODE=oauth`.** Gestionan
  la sesión; `AUTH_MODE` dice cómo se autentica cada petición a la API.

Lo que desbloquea: la Semana 09 lanza peticiones en paralelo, y varias pueden
querer renovar a la vez (el `ponytail:` de `renovar` lo apunta); la 10 empaqueta
el toolkit con su `auth` incluido.

---

## ✅ Requisitos verificables

`./scripts/verificar-semana.sh 08` comprueba estas dieciocho cosas. Las
descripciones son literales: si una falla, es la que tienes que buscar aquí.

1. El servidor OAuth2 del laboratorio responde en el puerto 8081
2. api-toolkit.sh existe, es ejecutable y arranca con set -euo pipefail
3. No queda ningun TODO por resolver
4. get sigue imprimiendo el cuerpo JSON por stdout
5. auth login guarda una sesion con access_token y expires_at
6. El archivo de sesion se crea con permisos 600
7. auth login no imprime el token: ni por stdout ni por stderr
8. --verbose auth login no muestra el client_secret en la traza
9. auth status de una sesion recien abierta dice cuanto le queda y de quien es
10. auth status sin sesion sale con 1
11. AUTH_MODE=oauth usa el token de la sesion contra la API
12. Una sesion caducada se renueva antes de la peticion
13. Un 401 con OAuth2 renueva el token y repite la peticion una vez
14. Con refresh_token, la renovacion lo usa y conserva la identidad
15. Un refresh_token revocado sale con 77, sin caer a client credentials
16. auth logout borra la sesion
17. auth logout revoca el refresh_token en el servidor
18. shellcheck -S warning no encuentra nada

---

## 🎨 Criterios de calidad

Lo que el autograding no ve y la rúbrica sí:

- **Ningún secreto en la línea de un proceso.** Ni el `client_secret`, ni el
  refresh token, ni el access token: todo va en `CONFIG_OAUTH` o en
  `CONFIG_CURL`, escrito con `printf` (orden interna). Compruébalo con `ps`
  durante un `auth login` contra `/delay`, como en la práctica 01.
- **Cada valor pasa por `escapar_config`**, también el refresh token: un `"`
  o una `\` dentro de un valor romperían el `--config`.
- **`guardar_sesion` no deja temporales** si `jq` falla, y nunca deja la
  sesión a medias: el `mv` es lo último.
- **`auth login` no hereda el refresh token** de una sesión anterior;
  `renovar` sí lo conserva si la respuesta no trae uno nuevo.
- **`cerrar_sesion` no borra si la revocación falla** por red o por un 5xx: el
  `logout` se tiene que poder repetir.
- **El reintento ante un 401 es uno**, nunca un bucle, y solo con
  `AUTH_MODE=oauth`: con `bearer`, el token es de otro y el toolkit no sabe
  renovarlo.
- **El `--help` sigue siendo verdad**: el starter ya documenta `auth` y las
  variables `OAUTH_*`; si cambias un comportamiento, cámbialo también ahí.
- **Comentarios que dicen por qué**: por qué `expires_at`, por qué el margen,
  por qué no caer a client credentials, por qué revocar antes de borrar.

---

## 💡 Adaptación a tu dominio

Lleva la capa a la API que elegiste en la Semana 01:

| Dominio | OAuth2 | Qué flujo | Ojo con |
|---|---|---|---|
| GitHub | Sí, para OAuth Apps y GitHub Apps | Device code o authorization code; una GitHub App usa un JWT propio para pedir tokens de instalación | Un *fine-grained token* personal sigue siendo lo más simple para un script tuyo: `AUTH_MODE=bearer` |
| Open-Meteo | No: es abierta | — | `AUTH_MODE=none`. La capa no aplica, y es una respuesta válida |
| TfL | No: `app_key` en la query | — | `AUTH_MODE=apikey` desde la Semana 03 |
| TMDB | No en la v3; la v4 usa un *read access token* fijo | — | Ese token es un bearer de larga vida: `AUTH_MODE=bearer` |

```bash
# ¿Tu API publica un servidor OAuth2? Busca su discovery.
curl -sS --max-time 5 https://<servidor-de-tu-api>/.well-known/openid-configuration \
  | jq '{token_endpoint, grant_types_supported}'
```

Que tu API no use OAuth2 no te deja sin proyecto: el autograding va contra el
laboratorio. Apunta en tu `README` de dominio qué modo de autenticación usa y
por qué, y si mañana pasara a OAuth2, qué variables `OAUTH_*` tendrías que
configurar.

---

## 🚦 Cómo entregarlo

**1.** El starter trae la capa 7 resuelta y el esqueleto de la 8, así que
puedes partir de él aunque tu versión de la Semana 07 sea distinta. Edítalo en
su sitio: el autograding comprueba ese archivo.

```bash
cd bootcamp/week-08-oauth2_y_autenticacion_avanzada/3-proyecto/starter/
# Guarda antes tu version de la Semana 07: el cp del paso 4 la sobrescribe.
cp ~/api-toolkit.sh ~/api-toolkit.semana07.sh 2>/dev/null || true
```

**2.** Resuelve los seis TODOs. El orden recomendado no es el numérico:

| TODO | Qué | Dónde se practica |
|---|---|---|
| 1 | `peticion_oauth`: el `--config` con `user` y un `data-urlencode` por campo, y `lanzar_curl` | Teoría 02 §3; práctica 01, pasos 3 a 5 y 7 |
| 2 | `guardar_sesion`: `expires_at`, `mktemp` en el mismo directorio, `mv` | Teoría 08 §2.2 a §2.4; práctica 03, paso 2 |
| 3 | `sesion_caducada`: `expires_at` contra `date +%s` y el margen | Teoría 06 §2.2; práctica 03, paso 3 |
| 5 | `ejecutar`: ante un 401 con `oauth`, `renovar`, `construir_config` y `peticion` | Teoría 06 §2.5; práctica 03, pasos 6 y 7 |
| 4 | `renovar`: con refresh token si lo hay, y sin caer a client credentials si falla | Teoría 06 §2.3 y §2.6; práctica 04, pasos 5 y 7 |
| 6 | `cerrar_sesion`: revocar con `token_type_hint`, y borrar | Teoría 06 §2.7, teoría 08 §2.6; práctica 04, pasos 8 y 9 |

El 2 necesita el 1: sin petición no hay respuesta que guardar. El 4 necesita
el 3 o el 5 para probarse: sin ellos, nada llama a `renovar`.

**3.** Pruébalo a mano, desde la raíz del repositorio:

```bash
T=bootcamp/week-08-oauth2_y_autenticacion_avanzada/3-proyecto/starter/api-toolkit.sh
export OAUTH_CLIENT_ID=api-toolkit OAUTH_CLIENT_SECRET=secreto-de-laboratorio
export OAUTH_SESSION_FILE="$HOME/.bc-curl-session-prueba"

# Abrir, mirar y usar la sesion.
"$T" auth login
# sesion guardada en /home/tu-usuario/.bc-curl-session-prueba
"$T" auth status
# activa: expira en 3599 s, sub=api-toolkit, refresh_token: no
AUTH_MODE=oauth BASE_URL=http://localhost:8081/default "$T" get /userinfo | jq -r .sub
# api-toolkit

# Un 401 que no se arregla: una renovacion, una repeticion, y 77.
AUTH_MODE=oauth BASE_URL=http://localhost:8080 "$T" get /status/401; echo "salida: $?"
# aviso: token OAuth2 renovado
# error: la API respondio 401
# salida: 77

# Cerrar.
"$T" auth logout
# aviso: el servidor no revoca el access_token: sigue valido hasta que caduque
# sesion cerrada
"$T" auth status; echo "salida: $?"
# sin sesion: ejecuta auth login
# salida: 1
unset OAUTH_CLIENT_ID OAUTH_CLIENT_SECRET OAUTH_SESSION_FILE
```

La parte del refresh token se prueba con `pkce.sh` de la práctica 02, como en
la práctica 04.

**4.** Pásale el autograding y shellcheck:

```bash
./scripts/verificar-semana.sh 08
shellcheck -S warning "$T"
```

Cuando pase, cópialo a tu sitio de trabajo: `cp "$T" ~/api-toolkit.sh`.

---

## 🧯 Errores comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `laboratorio-oauth` falla | El contenedor `oauth` no está arrancado | `./scripts/start.sh`; si sigue, `docker compose logs oauth` |
| `auth login` da 401 `invalid_client` | El `--config` no tiene la línea `user` | TODO 1: `user = "ID:SECRETO"`, con `escapar_config` |
| `auth login` da 400 `invalid_request` | Los campos van en JSON, o falta `grant_type` | Una línea `data-urlencode = "CAMPO=VALOR"` por argumento de `peticion_oauth` |
| `toolkit-login-sin-token` falla | El cuerpo de la respuesta sale por stdout o en un mensaje | `--output "$CUERPO"` en `peticion_oauth`; nunca `cat "$CUERPO"` |
| `toolkit-login-600` falla | La sesión se escribe con `>` a un archivo nuevo | `mktemp "${OAUTH_SESSION_FILE}.XXXXXX"` y `mv` |
| `toolkit-renueva-caducado` falla | `sesion_caducada` sigue con `return 1` | TODO 3 |
| `toolkit-refresh-token` da `api-toolkit` | `renovar` siempre pide client credentials | TODO 4: mira primero si la sesión trae `refresh_token` |
| `toolkit-refresh-revocado-77` sale con 0 | `renovar` prueba client credentials cuando el refresh falla | Quita esa rama: `exigir_token_ok` ya sale con 77 |
| `toolkit-logout-borra` falla con una sesión de `auth login` | `unsupported_token_type` se trata como un fallo y no se borra | Ese error se avisa y se sigue: el servidor no revocará nunca ese tipo |
| El 401 renueva dos veces | El TODO 5 llama a `ejecutar` dentro de `ejecutar` | Repite con `peticion`, no con `ejecutar` |

---

## 🔗 Navegación

| Anterior | Siguiente |
|---|---|
| [Práctica 04 — Refrescar y revocar](../2-practicas/04-refrescar-y-revocar.md) | [Rúbrica de evaluación](../rubrica-evaluacion.md) |

[← Volver a la Semana 08](../README.md)
