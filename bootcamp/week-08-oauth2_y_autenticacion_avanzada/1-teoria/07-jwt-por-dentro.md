# Un JWT por dentro

> El access token del laboratorio empieza por `eyJ` y tiene dos puntos. Es un
> JWT: un JSON firmado que cualquiera puede leer con `base64`. Leerlo sirve
> para depurar, y es tentador usarlo para decidir. Este archivo explica qué
> lleva dentro, cómo se lee, y por qué el cliente no debe fiarse de lo que lee.

![Un JWT partido en sus tres trozos separados por puntos: la cabecera en base64url, que decodificada es un JSON con alg RS256, typ JWT y kid default; el payload, con los claims iss, sub, aud, exp, iat y jti; y la firma, que solo se puede comprobar con la clave pública publicada en jwks_uri. Debajo, quién hace qué: el cliente lo lee para depurar, la API lo valida con la clave pública, y la introspección se lo pregunta al servidor](../0-assets/07-jwt-por-dentro.svg)

## 🎯 Objetivos

- Separar un JWT en sus tres partes y decodificar las dos primeras con `base64`
- Interpretar los claims que importan: `iss`, `sub`, `aud`, `exp`, `iat`, `scope`
- Explicar por qué leer un JWT no es validarlo, y quién lo valida
- Usar el JWKS y la introspección para preguntar si un token es válido

---

## 1. Qué problema resuelve

Un script recibe 401 y no sabes por qué. ¿Ha caducado el token? ¿Es de otro
cliente? ¿Le falta un scope? Con un token opaco (una cadena aleatoria) no hay
forma de saberlo sin preguntar al servidor. Con un JWT, la respuesta está
**dentro del token**:

```bash
claims_jwt "$TOKEN" | jq '{sub, aud, exp}'
# {
#   "sub": "api-toolkit",
#   "aud": "leer",
#   "exp": 1794449607
# }
```

Eso es útil para depurar. Y peligroso si el script empieza a tomar decisiones
de seguridad con lo que lee.

---

## 2. Cómo funciona

### 2.1 Tres trozos y dos puntos

```text
eyJraWQiOi...  .  eyJzdWIiOi...  .  kq9mjlvrUv...
   cabecera          payload           firma
```

| Trozo | Qué es | Se lee con `base64` |
|---|---|:--:|
| Cabecera | JSON: algoritmo de firma (`alg`), tipo (`typ`) e identificador de clave (`kid`) | Sí |
| Payload | JSON: los *claims*, lo que el token afirma | Sí |
| Firma | Bytes: la firma de `cabecera.payload` con la clave privada del servidor | No: no es texto |

`eyJ` es `{"` en base64: por eso todos los JWT empiezan igual.

### 2.2 base64url

Los trozos van en **base64url** (RFC 4648, 5), una variante de base64 que se
puede poner en una URL:

| base64 | base64url |
|---|---|
| `+` | `-` |
| `/` | `_` |
| Relleno con `=` hasta múltiplo de 4 | Sin relleno |

`base64 -d` solo entiende base64. Para decodificar un trozo: cambiar los dos
caracteres y devolver el relleno. Es lo que hace `claims_jwt` en el toolkit:

```bash
claims_jwt() {
  local payload
  payload="$(cut -d. -f2 <<<"$1" | tr '_-' '/+')"
  # base64url quita el relleno '='; base64 -d lo necesita.
  while [ $(( ${#payload} % 4 )) -ne 0 ]; do payload+='='; done
  base64 -d <<<"$payload" 2>/dev/null | jq -c . 2>/dev/null || true
}
```

El token entra por un *here-string* (`<<<`), no como argumento de un comando
externo: no aparece en `ps`.

### 2.3 Los claims que importan

| Claim | Nombre | Qué dice | Ejemplo del laboratorio |
|---|---|---|---|
| `iss` | *Issuer* | Quién lo emitió | `http://localhost:8081/default` |
| `sub` | *Subject* | De quién es: una persona o un cliente | `alumno` o `api-toolkit` |
| `aud` | *Audience* | Para qué API es. Una API debe rechazar un token con otro `aud` | `default` (el simulador pone el scope si lo pides) |
| `exp` | *Expiration* | Instante en que caduca, en segundos desde 1970 | `1794449607` |
| `iat` | *Issued at* | Cuándo se emitió | `1794446007` |
| `nbf` | *Not before* | No vale antes de este instante | Igual que `iat` |
| `jti` | *JWT ID* | Identificador único: permite revocarlo o detectar reutilización | Un UUID |
| `scope` / `scp` | — | Permisos. No está estandarizado en el JWT (sí en RFC 9068) | No lo pone |
| `azp` | *Authorized party* | El cliente al que se emitió, si `sub` es una persona | `api-toolkit` |

`exp - iat` es la vida del token: 3600 segundos en el laboratorio.

### 2.4 Leer no es validar

Cualquiera puede **fabricar** un JWT que se lea bien. Validarlo es comprobar
la firma con la clave pública del servidor, y además `iss`, `aud`, `exp` y
`nbf`. Eso lo hace **la API**, no el cliente.

| Quién | Qué hace con el access token |
|---|---|
| El cliente (tu script) | Lo guarda, lo manda, y como mucho lo lee para depurar. Lo trata como **opaco** |
| La API (servidor de recursos) | Lo valida en cada petición: firma, `iss`, `aud`, `exp`, scope |
| El servidor de autorización | Lo emite, y responde a la introspección |

¿Por qué el cliente no debería decidir con el payload?

- **El formato no es un contrato.** Un proveedor puede pasar mañana a tokens
  opacos, y el script que leía `exp` del JWT se rompe. El `expires_in` de la
  respuesta sí es contrato.
- **No puede comprobar la firma** sin descargar y manejar las claves, que no
  es su trabajo.
- **El `exp` no dice si está revocado** (teoría 06, 2.5).

Por eso el toolkit decide con `expires_at` (sacado de `expires_in`) y con el
401 de la API, y solo usa `claims_jwt` en `auth status`, para **enseñar** el
`sub`.

> [!NOTE]
> El `id_token` de OpenID Connect es lo contrario: es **para el cliente**, que
> sí debe validarlo si lo usa para saber quién hizo login. Esta semana no se
> usa.

### 2.5 JWKS: la clave pública

La API valida la firma con la clave pública del servidor, que este publica en
`jwks_uri` (un *JSON Web Key Set*). El `kid` de la cabecera del token dice
cuál de las claves del conjunto usar:

```bash
curl -sS --max-time 5 http://localhost:8081/default/jwks | jq -c '.keys[] | {kty, kid, alg, use}'
# {"kty":"RSA","kid":"default","alg":"RS256","use":"sig"}
```

Cuando el servidor rota sus claves, los tokens firmados con la vieja dejan de
validar aunque no hayan caducado: es el 401 antes del `exp` de la teoría 06.
El simulador del laboratorio no rota: conserva la misma clave aunque se
reinicie el contenedor.

### 2.6 Introspección: preguntárselo al servidor

Para un token opaco, o para saber si uno está revocado, el servidor ofrece
introspección (RFC 7662): un `POST` con el token, autenticado como cliente.

| Respuesta | Significado |
|---|---|
| `{"active": true, "sub": ..., "exp": ...}` | Vale ahora mismo |
| `{"active": false}` | No vale: caducado, revocado, inventado. No dice cuál, a propósito |

Cuesta una petición por consulta. Es la herramienta de la API, o del
operador que depura; un cliente normal no la necesita.

---

## 3. Cómo se usa

```bash
# Un token del laboratorio, a un archivo que no se imprime.
config=$(umask 077 && mktemp)
printf '%s\n' 'user = "api-toolkit:secreto-de-laboratorio"' \
  'data-urlencode = "grant_type=client_credentials"' > "$config"
curl -sS --max-time 10 --config "$config" -o r.json http://localhost:8081/default/token

# La cabecera: el primer trozo.
jq -r .access_token r.json | cut -d. -f1 | tr '_-' '/+' | base64 -d 2>/dev/null; echo
# {"kid":"default","typ":"JWT","alg":"RS256"}

# Cuanto le queda, segun el propio token.
echo $(( $(claims_jwt "$(jq -r .access_token r.json)" | jq .exp) - $(date +%s) ))
# 3600      ← o muy cerca: depende de cuanto tardes en ejecutarlo
```

Introspección, con el token por stdin para que no vaya en la línea:

```bash
# jq -j: sin salto de linea final, que --data-urlencode codificaria como %0A.
jq -j .access_token r.json \
  | curl -sS --max-time 10 --config "$config" --data-urlencode token@- \
      http://localhost:8081/default/introspect | jq '{active, sub}'
# {
#   "active": true,
#   "sub": "api-toolkit"
# }
```

El `--config` lleva la autenticación del cliente (`user =`) y
`grant_type=client_credentials`, que la introspección ignora. Un token
inventado:

```bash
printf %s 'a.b.c' | curl -sS --max-time 10 --config "$config" --data-urlencode token@- \
  http://localhost:8081/default/introspect | jq -c .
# {"active":false}
rm -f "$config" r.json
```

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Decidir en el cliente si un token vale leyendo su `exp` | El formato puede cambiar y no dice si está revocado | `expires_at` de la respuesta, y el 401 de la API |
| Validar un JWT en la API sin comprobar la firma | Cualquiera fabrica un token con `"sub": "admin"` | Firma con la clave del JWKS, `iss`, `aud` y `exp` |
| Aceptar `"alg": "none"` | Un token sin firma pasa por bueno | La API fija los algoritmos que acepta |
| Pegar un token en un decodificador web | Acabas de entregar una credencial viva a un tercero | `claims_jwt` o `base64 -d` en tu terminal |
| Imprimir el token entero en un log para depurar | Es un *bearer*: quien lea el log lo usa | Imprimir sus claims, nunca el token |

---

## 5. Trucos

- **Un token sin firma no pasa en el laboratorio**: cambia la cabecera por
  `{"alg":"none"}`, quita la firma, y `/userinfo` responde 401. Es lo que debe
  hacer cualquier API.
- **`jq -R 'split(".") | .[1] | @base64d | fromjson'`** decodifica el payload
  en jq 1.6+ sin `base64`, siempre que el trozo no lleve `-` ni `_`. Para
  base64url completo, `claims_jwt`.
- **El `jti` identifica un token sin enseñarlo**: es lo que se apunta en un
  log si hace falta saber qué token se usó.

---

## 📚 Recursos Adicionales

- [RFC 7519 — JSON Web Token (JWT)](https://datatracker.ietf.org/doc/html/rfc7519)
- [RFC 7662 — OAuth 2.0 Token Introspection](https://datatracker.ietf.org/doc/html/rfc7662)
- [RFC 9068 — JWT Profile for OAuth 2.0 Access Tokens](https://datatracker.ietf.org/doc/html/rfc9068)

---

## ✅ Checklist de Verificación

- [ ] Decodificas la cabecera y el payload de un JWT con `cut`, `tr` y `base64`
- [ ] Explicas qué son `iss`, `sub`, `aud` y `exp`, y cuál cambia entre client credentials y authorization code
- [ ] Explicas por qué el cliente trata el access token como opaco
- [ ] Encuentras en el JWKS la clave que corresponde al `kid` de un token
- [ ] Preguntas por introspección si un token está activo, sin ponerlo en la línea de comandos
