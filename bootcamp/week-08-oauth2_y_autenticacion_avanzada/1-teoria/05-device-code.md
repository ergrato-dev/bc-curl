# Device code

> Authorization code necesita un navegador en la misma máquina que el
> programa. Una sesión SSH, un contenedor de CI o una televisión no lo tienen.
> Device code (RFC 8628) parte el login en dos aparatos: el programa enseña un
> código corto, la persona lo escribe en su móvil o su portátil, y el programa
> pregunta cada pocos segundos si ya está.

![Secuencia de device code con dos aparatos: el programa en el servidor SSH pide a /device/code un device_code y un user_code; enseña al usuario la URL de verificación y el código corto; la persona, desde su portátil, abre la URL, escribe el código y aprueba; mientras tanto el programa sondea /token cada interval segundos recibiendo authorization_pending, sube la espera al recibir slow_down, y al final recibe el access_token](../0-assets/05-device-code.svg)

## 🎯 Objetivos

- Explicar en qué situación device code es el único flujo razonable
- Recorrer las dos fases: la petición de códigos y el sondeo
- Escribir un bucle de sondeo que respeta `interval`, `slow_down` y `expires_in`
- Distinguir los errores que piden seguir esperando de los que piden parar

---

## 1. Qué problema resuelve

Estás conectado por SSH a un servidor y quieres que un CLI de allí actúe con
tu cuenta. Authorization code no funciona: abriría el navegador **en el
servidor**, que no tiene pantalla, y la redirección a `127.0.0.1` llegaría
al servidor, no a tu portátil.

Las alternativas malas son conocidas: pegar un token personal de larga vida
en el servidor, o copiar a mano una URL larguísima con un código dentro. Device
code resuelve el problema con un código de **ocho caracteres** que una persona
puede leer en una pantalla y escribir en otra.

Es lo que hacen `gh auth login` en una sesión sin navegador, `az login
--use-device-code`, o la app de una plataforma de vídeo en una televisión.

---

## 2. Cómo funciona

### 2.1 Las dos fases

| Fase | Petición | Respuesta |
|---|---|---|
| 1. Pedir los códigos | `POST /device/code` (el nombre varía; el discovery lo publica como `device_authorization_endpoint`) con `client_id` y `scope` | `device_code`, `user_code`, `verification_uri`, `expires_in`, `interval` |
| 2. Sondear | `POST /token` con `grant_type=urn:ietf:params:oauth:grant-type:device_code`, `device_code` y `client_id`, cada `interval` segundos | Un error mientras la persona no aprueba; el token cuando aprueba |

Entre las dos, la persona abre `verification_uri` en otro aparato, escribe el
`user_code` y aprueba los permisos. Algunos servidores devuelven también
`verification_uri_complete`, con el código ya puesto, para enseñarlo como QR.

### 2.2 Los dos códigos

| Código | Para quién | Cómo es | Secreto |
|---|---|---|:--:|
| `device_code` | El programa, para sondear | Largo, aleatorio | Sí: quien lo tenga recibe el token |
| `user_code` | La persona, para escribirlo | Corto, sin caracteres ambiguos (`WDJB-MJHT`) | No: se enseña en pantalla |

El `device_code` no se imprime nunca; el `user_code` es lo único que se
enseña.

### 2.3 Los errores del sondeo

Mientras la persona no ha terminado, el endpoint de token responde con un
error que **no es un fallo** (RFC 8628, 3.5):

| `error` | Qué significa | Qué hace el programa |
|---|---|---|
| `authorization_pending` | La persona todavía no ha aprobado | Esperar `interval` segundos y repetir |
| `slow_down` | Estás sondeando demasiado deprisa | Sumar **5 segundos** a `interval`, para siempre, y repetir |
| `access_denied` | La persona dijo que no | Parar. Salir con 77 |
| `expired_token` | Pasó `expires_in` sin aprobación | Parar. Empezar de cero |

Cualquier otro error (`invalid_client`, `invalid_grant`) también es parar.

### 2.4 Device code y el bucle de backoff

El sondeo es primo hermano del backoff de la Semana 07, con dos diferencias:

| Backoff ante un 429 | Sondeo de device code |
|---|---|
| La espera crece exponencialmente | La espera es fija; solo crece con `slow_down`, de 5 en 5 |
| Se rinde tras N intentos | Se rinde cuando pasa `expires_in` |
| Lleva azar para no sincronizar clientes | No hace falta: cada cliente tiene su propio código |

### 2.5 Por qué no está en el laboratorio

El simulador del laboratorio (mock-oauth2-server 6.0.2) no implementa device
code: su discovery no publica `device_authorization_endpoint` y su `/token`
responde `grant_type ... not supported`. Compruébalo:

```bash
curl -sS --max-time 5 http://localhost:8081/default/.well-known/openid-configuration \
  | jq .device_authorization_endpoint
# null
```

Por eso esta semana el flujo se estudia aquí y se prueba, si quieres, contra
GitHub (apartado 3.2), que sí lo soporta. Ni el proyecto ni el autograding
dependen de él.

---

## 3. Cómo se usa

### 3.1 El bucle de sondeo

La estructura vale para cualquier servidor. `peticion_token` es una función
tuya que hace el `POST` a `/token` y deja la respuesta en `respuesta.json`:

```bash
# Los valores de la fase 1, leidos con jq de la respuesta de /device/code.
interval=$(jq -r '.interval // 5' codigos.json)
limite=$(( $(date +%s) + $(jq -r .expires_in codigos.json) ))

echo "Abre $(jq -r .verification_uri codigos.json) y escribe $(jq -r .user_code codigos.json)" >&2

while [ "$(date +%s)" -lt "$limite" ]; do
  sleep "$interval"
  peticion_token        # grant_type=urn:ietf:params:oauth:grant-type:device_code
  if jq -e .access_token respuesta.json >/dev/null; then
    break               # aprobado
  fi
  case "$(jq -r '.error // empty' respuesta.json)" in
    authorization_pending) ;;                          # sigue esperando
    slow_down)     interval=$((interval + 5)) ;;       # y no vuelvas a bajarla
    access_denied) echo "denegado" >&2; exit 77 ;;
    *)             echo "error: $(jq -r .error respuesta.json)" >&2; exit 1 ;;
  esac
done
```

Detalles que el bucle cuida:

- **`sleep` antes de la primera petición**, no después: la persona tarda al
  menos unos segundos en llegar a la URL, y la primera petición seguro que da
  `authorization_pending`.
- **`interval // 5`**: si el servidor no lo manda, el RFC dice 5 segundos.
- **El límite es un instante**, calculado al principio con `expires_in`, como
  el `expires_at` de la teoría 06.
- **El código HTTP no decide**: distintos servidores devuelven estos errores
  con códigos distintos. Decide el campo `error`.

### 3.2 Contra GitHub (necesita internet)

GitHub implementa device code para sus OAuth Apps. Necesitas registrar una
(Settings → Developer settings → OAuth Apps) y activar *Enable Device Flow*
en su configuración. El `client_id` no es secreto; device code no usa
`client_secret`.

```bash
# Necesita internet. Comprobado contra la documentacion de GitHub en
# noviembre de 2026. Sin Accept: application/json, GitHub responde
# form-urlencoded. umask 077: codigos.json lleva el device_code.
umask 077
curl -sS --fail-with-body --max-time 10 -H 'Accept: application/json' \
  -d "client_id=$GITHUB_CLIENT_ID" -d scope=read:user \
  https://github.com/login/device/code > codigos.json
jq '{user_code, verification_uri, expires_in, interval}' codigos.json
# {
#   "user_code": "WDJB-MJHT",
#   "verification_uri": "https://github.com/login/device",
#   "expires_in": 899,
#   "interval": 5
# }
```

El sondeo va a `https://github.com/login/oauth/access_token` con `client_id`,
`device_code` y el `grant_type` largo. GitHub añade errores propios
(`device_flow_disabled`, `incorrect_device_code`) que el `*)` del bucle trata
como fallo.

> [!WARNING]
> El token que devuelve GitHub vale para tu cuenta real. No lo imprimas, no
> lo guardes en el repositorio, borra `codigos.json` y `respuesta.json` al
> terminar, y revócalo desde Settings →
> Applications → Authorized OAuth Apps.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Sondear sin `sleep`, o con un `sleep` menor que `interval` | `slow_down` en bucle y, en algunos servidores, bloqueo del cliente | `sleep "$interval"` antes de cada petición |
| Ignorar `slow_down` | El servidor seguirá respondiendo `slow_down` y la persona nunca entra | Sumar 5 a `interval` y no volver a bajarlo |
| Imprimir el `device_code` | Quien lo vea recibe el token en cuanto la persona apruebe | Solo se enseña el `user_code` |
| Un bucle sin límite de tiempo | El script se queda esperando para siempre si la persona se va | Parar en `expires_in` |
| Tratar `authorization_pending` como un error | El script se rinde en la primera vuelta | Es el estado normal mientras se espera |
| Usar device code donde hay navegador | El usuario cambia de aparato sin necesidad, y el flujo es más fácil de usar para *phishing* | Authorization code + PKCE |

---

## 5. Trucos

- **`verification_uri_complete` como QR**: `qrencode -t ansiutf8 "$URI"` lo
  pinta en el terminal, si el servidor lo devuelve.
- **El *phishing* de device code existe**: un atacante pide un código y te lo
  manda diciendo "escribe esto para verificar tu cuenta". Si apruebas, el
  token es suyo. Por eso solo se aprueba un código que tú mismo has visto
  aparecer en tu terminal.
- **El `interval` del servidor es un mínimo, no un objetivo.** Sondear un
  poco más despacio no tiene coste para la persona y sí ahorra peticiones.

---

## 📚 Recursos Adicionales

- [RFC 8628 — OAuth 2.0 Device Authorization Grant](https://datatracker.ietf.org/doc/html/rfc8628)
- [GitHub — Device flow](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow)
- [oauth.net — Device Code](https://oauth.net/2/grant-types/device-code/)

---

## ✅ Checklist de Verificación

- [ ] Explicas por qué authorization code no funciona en una sesión SSH
- [ ] Sabes qué código se enseña y cuál no se imprime nunca
- [ ] Clasificas los cuatro errores del sondeo en "seguir" o "parar"
- [ ] Escribes el bucle respetando `interval`, `slow_down` y `expires_in`
- [ ] Compruebas en el discovery si un servidor soporta device code
