# El endpoint de token

> Todos los flujos de OAuth2 acaban en la misma puerta: un `POST` a `/token`.
> Es un formulario de los de siempre, con tres trampas: cómo se codifican los
> campos, cómo se autentica el cliente sin dejar el secreto en `ps`, y cómo
> se lee un error que no viene en el código HTTP sino en el cuerpo.

![Anatomía de una petición al endpoint de token: a la izquierda, el archivo --config con permisos 600 que contiene la línea user con el id y el secreto y una línea data-urlencode por campo; en el centro, la petición POST que curl construye con el header Authorization Basic y el cuerpo form-urlencoded; a la derecha, las dos respuestas posibles: 200 con access_token, token_type, expires_in y scope, o 400/401 con los campos error y error_description](../0-assets/02-el-endpoint-de-token.svg)

## 🎯 Objetivos

- Construir la petición de token con el método, el tipo de contenido y la codificación correctos
- Elegir entre `-d` y `--data-urlencode` según lo que lleve el valor
- Autenticar al cliente con Basic o en el cuerpo, y sin que el secreto llegue a la línea de comandos
- Leer la respuesta y los errores del RFC 6749 y traducirlos a un código de salida

---

## 1. Qué problema resuelve

Tres versiones del mismo `POST`. Las tres "funcionan" un día y fallan otro:

```bash
# 1. JSON: la API de tu proyecto acepta JSON, asi que el token tambien, ¿no?
curl -sS --max-time 5 -u api-toolkit:secreto-de-laboratorio \
  -H 'Content-Type: application/json' -d '{"grant_type":"client_credentials"}' \
  http://localhost:8081/default/token | jq -r .error
# invalid_request      ← el endpoint de token SOLO acepta formularios

# 2. -d con un scope que lleva un +: el servidor lee un espacio.
# 3. -u id:secreto: funciona, y el secreto queda en /proc/PID/cmdline.
```

El RFC 6749 (apartado 3.2) fija el formato: `POST`, cuerpo
`application/x-www-form-urlencoded`, codificación UTF-8. No es negociable, y
no es lo que la mayoría de las APIs REST piden en sus otros endpoints.

---

## 2. Cómo funciona

### 2.1 La petición

| Pieza | Valor | Por qué |
|---|---|---|
| Método | `POST` | El token no puede ir en una URL: acabaría en logs de proxy y en el historial |
| `Content-Type` | `application/x-www-form-urlencoded` | Lo pone curl solo con `-d` o `--data-urlencode` |
| `grant_type` | `client_credentials`, `authorization_code`, `refresh_token`... | Qué flujo es. Obligatorio |
| Campos del flujo | `scope`, `code`, `redirect_uri`, `code_verifier`, `refresh_token`... | Dependen del `grant_type` |
| Autenticación del cliente | Header `Authorization: Basic`, o `client_id` y `client_secret` en el cuerpo | Ver 2.3 |

Con `-d` o `--data-urlencode`, curl ya hace `POST` y pone el `Content-Type`
correcto. No hace falta `-X POST` ni `-H 'Content-Type: ...'`.

### 2.2 `-d` frente a `--data-urlencode`

`-d` manda el texto **tal cual**: no codifica nada. En un formulario, `&`
separa campos, `=` separa nombre y valor, y `+` significa espacio.

| Valor | Con `-d 'campo=VALOR'` llega | Con `--data-urlencode 'campo=VALOR'` llega |
|---|---|---|
| `leer escribir` | `leer escribir` (el servidor suele tolerarlo) | `leer%20escribir` |
| `a+b` | `a b` ← el `+` se lee como espacio | `a%2Bb` |
| `x&admin=1` | dos campos: `campo=x` y `admin=1` | `x%26admin%3D1` |
| un refresh token con `/` y `=` | depende del servidor | codificado siempre |

Regla: **`-d` solo para valores fijos que escribes tú** (`grant_type=...`).
Todo lo que viene de fuera (un scope configurable, un código, un refresh
token) va con `--data-urlencode`.

`--data-urlencode` (7.18+) tiene varias formas. Las que importan aquí:

| Forma | Qué manda |
|---|---|
| `nombre=valor` | `nombre=` + `valor` codificado |
| `nombre@archivo` | `nombre=` + el contenido del archivo, codificado. Con `@-`, de stdin |
| `@archivo` | El contenido entero codificado, **`=` incluido**: casi nunca es lo que quieres |

> [!WARNING]
> `nombre@archivo` codifica también el salto de línea final: `token%0A`. Si
> guardas un valor para mandarlo así, escríbelo con `printf %s`, nunca con
> `echo`.

### 2.3 Cómo se autentica el cliente

Un cliente con secreto (*confidential client*) se identifica en cada
petición al endpoint de token. El RFC 6749 (2.3.1) describe dos formas:

| Método | Cómo va | Notas |
|---|---|---|
| `client_secret_basic` | `Authorization: Basic base64(id:secreto)` | El que todo servidor **debe** soportar. curl lo construye con `-u` o con `user =` en un `--config` |
| `client_secret_post` | `client_id=...&client_secret=...` en el cuerpo | El RFC lo desaconseja, pero es el único que aceptan algunos proveedores |

El discovery dice cuál acepta el servidor en
`token_endpoint_auth_methods_supported`. El del laboratorio no publica ese
campo, y acepta los dos.

Un detalle del RFC que casi nadie cumple: antes de juntar `id:secreto` en el
Basic, los dos se codifican como formulario. curl no lo hace, porque `-u` es
el Basic genérico de HTTP. Con un secreto alfanumérico da igual; con uno que
lleve `:` o `%`, el servidor lee otra cosa. Si te pasa, usa
`client_secret_post`.

### 2.4 Dónde va el secreto

`-u id:secreto` y `-d client_secret=...` dejan el secreto en los argumentos
de curl, y los argumentos de un proceso los ve cualquier usuario de la
máquina mientras dura la petición:

```bash
# Lo que ve otro usuario con ps mientras curl espera la respuesta.
ps -eo args | grep '[c]url'
# curl -sS -u api-toolkit:secreto-de-laboratorio -d grant_type=...
```

La solución es la misma de la Semana 03: un `--config` temporal, con permisos
600, que curl lee al arrancar. En un `--config` caben **todas** las opciones,
no solo la credencial:

```text
user = "api-toolkit:secreto-de-laboratorio"
data-urlencode = "grant_type=client_credentials"
data-urlencode = "scope=leer escribir"
```

En la línea de comandos solo queda `--config /tmp/api-toolkit.XXXXXX`. El
toolkit lo construye en `peticion_oauth`, pasando cada valor por
`escapar_config` para que unas comillas o una `\` no rompan la línea.

### 2.5 La respuesta

Un `200` con JSON (RFC 6749, 5.1):

| Campo | Obligatorio | Qué es |
|---|:--:|---|
| `access_token` | Sí | El token. Opaco para el cliente, aunque sea un JWT |
| `token_type` | Sí | Casi siempre `Bearer`. No distingue mayúsculas |
| `expires_in` | Recomendado | Segundos de vida **desde que el servidor respondió** |
| `scope` | Si difiere del pedido | El servidor puede darte menos de lo que pediste |
| `refresh_token` | Opcional | Solo en flujos con persona |

El RFC exige además `Cache-Control: no-store` en esa respuesta, para que
ningún proxy la guarde. El servidor del laboratorio no lo manda: es un
simulador. Si lo ves en una API real, es buena señal.

### 2.6 Los errores

Un error del endpoint de token llega como `400` (o `401` si falla la
autenticación del cliente) con un JSON (RFC 6749, 5.2):

| `error` | Qué significa | Salida del toolkit |
|---|---|:--:|
| `invalid_request` | Falta un campo, sobra uno o está repetido | 1 |
| `invalid_client` | El cliente no se autenticó o el secreto no vale | 77 |
| `invalid_grant` | El código, el refresh token o el verifier no valen, caducaron o se revocaron | 77 |
| `unauthorized_client` | Este cliente no puede usar este flujo | 77 |
| `unsupported_grant_type` | El servidor no conoce ese `grant_type` | 1 |
| `invalid_scope` | El scope no existe o no se puede conceder | 1 |

El campo `error_description` es texto para personas: imprímelo, no lo
compares. Decide con `error`.

---

## 3. Cómo se usa

```bash
# El --config con el secreto, creado ya con 600 gracias a la umask.
config=$(umask 077 && mktemp)
cat > "$config" <<'EOF'
user = "api-toolkit:secreto-de-laboratorio"
data-urlencode = "grant_type=client_credentials"
data-urlencode = "scope=leer escribir"
EOF

# El cuerpo a un archivo, el codigo por -w: asi se decide con el codigo y se
# lee el error del cuerpo, como en la capa 7.
codigo=$(curl -sS --max-time 10 --config "$config" -o respuesta.json \
  -w '%{http_code}' http://localhost:8081/default/token)
echo "$codigo"; jq '{token_type, expires_in, scope}' respuesta.json
# 200
# {
#   "token_type": "Bearer",
#   "expires_in": 3599,
#   "scope": "leer escribir"
# }
rm -f "$config" respuesta.json
```

Un error, leído como lo lee el toolkit:

```bash
# Sin autenticacion de cliente: invalid_client.
codigo=$(curl -sS --max-time 10 -d grant_type=client_credentials -d client_id=api-toolkit \
  -o respuesta.json -w '%{http_code}' http://localhost:8081/default/token)
echo "$codigo $(jq -r '[.error, .error_description] | join(": ")' respuesta.json)"
# 401 invalid_client: client authentication failed: missing client authentication
rm -f respuesta.json
```

> [!NOTE]
> El simulador del laboratorio responde a un `grant_type` desconocido con
> `invalid_grant`, no con `unsupported_grant_type` como pide el RFC. Por eso
> se decide con `error` y se imprime `error_description`: los servidores
> reales también se desvían del estándar.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `-u id:secreto` o `-d client_secret=...` en un script | El secreto en `ps`, en el historial y en la traza de `set -x` | `user =` y `data-urlencode =` en un `--config` 600 |
| `-d "scope=$SCOPE"` | Un `+` o un `&` en el valor cambia lo que llega | `--data-urlencode "scope=$SCOPE"` |
| Mandar JSON al endpoint de token | `invalid_request`: el RFC solo admite formularios | `-d` y `--data-urlencode` |
| `--fail` en la petición de token | Descarta el cuerpo, que es justo donde viene `invalid_grant` | `-o archivo -w '%{http_code}'`, o `--fail-with-body` |
| Decidir comparando `error_description` | Es texto libre y cambia entre versiones | Decide con `error` |
| `--retry` en la petición de token | Con un refresh token que rota, el reintento presenta uno ya gastado | Sin `--retry`; un 503 sale con 75 y quien llama decide |

---

## 5. Trucos

- **`--trace-ascii -` enseña el cuerpo que manda curl**, codificado. Es la
  forma de ver si un `+` salió como `%2B`. Ojo: también enseña el secreto;
  hazlo solo con el del laboratorio.
- **`printf %s "$valor" | curl --data-urlencode campo@- ...`** manda un valor
  codificado sin ponerlo en la línea de comandos y sin `--config`. Sirve para
  un único campo.
- **`--oauth2-bearer "$TOKEN"`** (7.61+ para HTTP) construye el header de la API, pero
  pone el token en los argumentos. En un script, el header va en el
  `--config`, como hace el toolkit desde la Semana 03.

---

## 📚 Recursos Adicionales

- [RFC 6749, apartados 2.3.1, 3.2, 5.1 y 5.2](https://datatracker.ietf.org/doc/html/rfc6749#section-5)
- [Manpage: `--data-urlencode`](https://curl.se/docs/manpage.html#--data-urlencode)
- [Manpage: `--config`](https://curl.se/docs/manpage.html#-K)

---

## ✅ Checklist de Verificación

- [ ] Explicas por qué el endpoint de token rechaza JSON
- [ ] Sabes qué hace `-d` con un `+` y qué hace `--data-urlencode`
- [ ] Distingues `nombre@archivo` de `@archivo` en `--data-urlencode`
- [ ] Pides un token con todo, secreto incluido, dentro de un `--config` 600
- [ ] Traduces `invalid_client`, `invalid_grant` e `invalid_request` a un código de salida
