# El ciclo de vida del token

> Pedir un token es fácil. Lo que hace fallar a un script a las tres de la
> mañana es todo lo que viene después: el token caduca, el refresh token rota,
> alguien lo revoca, o el servidor deja de aceptarlo una hora antes de lo que
> decía su `exp`. Este archivo es el mapa de esos estados y de qué hacer en
> cada uno.

![Ciclo de vida de una sesión OAuth2 como máquina de estados: vigente, a punto de caducar dentro del margen, caducada, y muerta antes de tiempo por revocación o rotación de claves. Las transiciones muestran cuándo se renueva antes de la petición (margen alcanzado), cuándo después (un 401), con qué se renueva (refresh_token si hay, client credentials si no), y los dos finales: sesión renovada, o salida con 77 porque el refresh_token ya no vale](../0-assets/06-ciclo-de-vida-del-token.svg)

## 🎯 Objetivos

- Convertir `expires_in` en un instante que siga teniendo sentido después
- Decidir cuándo renovar: antes de la petición, con margen, o después de un 401
- Usar un refresh token y entender la rotación
- Revocar un token y saber qué puede y qué no puede revocar un servidor
- Reintentar un 401 una sola vez, y nunca cambiando de identidad

---

## 1. Qué problema resuelve

Un script pide un token a las 22:00 y lo guarda. El cron lo usa a las 22:05,
a las 22:35 y a las 23:05. La última falla con 401: el token duraba 3600
segundos. El script no sabe por qué; solo ve un 401 y sale con 77, como si
la credencial estuviera mal.

Lo que faltaba es un **ciclo de vida**: saber cuándo caduca, renovarlo antes,
y distinguir un 401 que se arregla renovando de uno que no.

---

## 2. Cómo funciona

### 2.1 `expires_in` no se guarda: se convierte

`expires_in: 3599` significa "3599 segundos **desde ahora**", y ese "ahora"
es el instante en que el servidor respondió. Guardado tal cual, una hora
después el número no dice nada. Se convierte en el momento de recibirlo:

```bash
jq --argjson ahora "$(date +%s)" '. + {expires_at: ($ahora + .expires_in)}' respuesta.json
```

`expires_at` es un instante absoluto (segundos desde 1970, UTC): se compara
con `date +%s` en cualquier momento, en cualquier proceso. Es lo que guarda
`guardar_sesion` en el toolkit.

Si la respuesta no trae `expires_in` (el RFC solo lo recomienda), no hay forma
de saberlo. El toolkit pone `expires_at = ahora`: la sesión nace caducada y el
siguiente uso la renueva. Mejor pedir de más que fallar a ciegas.

### 2.2 El margen

Un token que caduca a las 23:00:00 y se usa a las 22:59:59 puede llegar
muerto: la petición tarda, y el reloj de tu máquina y el del servidor no
coinciden exactamente. Por eso se renueva **antes**:

```bash
[ "$(date +%s)" -ge $(( expires_at - 30 )) ] && echo "renovar"
```

| Margen | Problema |
|---|---|
| 0 | Peticiones que salen vivas y llegan muertas |
| 30 s | El del toolkit (`MARGEN_CADUCIDAD`). Cubre la red y un reloj algo desajustado |
| Un porcentaje (renovar al 80 % de la vida) | Más robusto con tokens muy cortos; más complejo |

El margen no sustituye a NTP: un reloj diez minutos adelantado renueva en cada
petición, y uno atrasado usa tokens muertos.

### 2.3 Renovar: con qué

| La sesión trae | Se renueva con | Identidad del token nuevo |
|---|---|---|
| `refresh_token` | `grant_type=refresh_token` | La misma persona |
| Nada más (client credentials) | `grant_type=client_credentials` otra vez | El mismo cliente |

El grant de refresh (RFC 6749, 6) es otro `POST` a `/token`:

```text
grant_type=refresh_token&refresh_token=...    + autenticación del cliente
```

La respuesta es como la del login: un `access_token` nuevo, su `expires_in`, y
**quizá** un `refresh_token` nuevo.

### 2.4 Rotación

| El servidor... | Qué haces con el refresh token anterior |
|---|---|
| Devuelve el mismo `refresh_token`, o ninguno | Lo conservas: sigue valiendo |
| Devuelve uno distinto (rotación) | Lo sustituyes. El anterior ya no vale |

El RFC 9700 pide rotación para clientes públicos: si un atacante roba un
refresh token y lo usa, el siguiente uso del legítimo presenta uno ya gastado,
el servidor detecta la reutilización y revoca toda la familia. Consecuencias
para un script:

- **El refresh token nuevo se guarda antes de hacer nada más.** Si el script
  muere entre recibirlo y guardarlo, la sesión queda inservible.
- **Nada de `--retry` en el refresh.** Si la primera petición llegó y la
  respuesta se perdió, el reintento presenta el token ya rotado.
- **Dos procesos que renuevan a la vez se pisan.** El segundo recibe
  `invalid_grant`. Si el toolkit corre en paralelo (Semana 09), un `flock`
  sobre la sesión lo evita.

El servidor del laboratorio no rota: devuelve el mismo refresh token. El
toolkit funciona igual con los dos comportamientos.

### 2.5 El 401 antes del `exp`

El `exp` es lo que el servidor **prometió**, no lo que va a cumplir. Un token
deja de valer antes cuando:

- Alguien lo revoca, o revoca la sesión de la persona
- El servidor rota sus claves de firma (el simulador del laboratorio no lo
  hace; la práctica 03 lo imita estropeando la firma del token)
- Cambian los permisos del cliente o de la persona

Lo único que lo dice es un 401 de la API. La regla:

1. Ante un 401 con OAuth2, **renovar una vez** y **repetir la petición una vez**.
2. Si vuelve a dar 401, ese 401 es de verdad: salir con 77.

Repetir es seguro incluso en un `POST`: un 401 significa que la API rechazó la
petición antes de procesarla. Y nunca más de una vez: un bucle "401, renovar,
401, renovar" contra un cliente sin permisos machaca el servidor de tokens.

### 2.6 Cuando renovar falla

Un `invalid_grant` al refrescar significa que el refresh token ya no vale:
caducó, se revocó o se usó dos veces. No tiene arreglo automático.

La tentación es caer a client credentials, que "siempre funciona". Es un
error grave: el refresh token era de una persona (`sub=alumno`) y client
credentials da un token del cliente (`sub=api-toolkit`). El script seguiría
funcionando, **con otra identidad y otros permisos**, sin que nadie lo sepa.
Lo correcto es salir con 77 y pedir `auth login`.

### 2.7 Revocar

El endpoint de revocación (RFC 7009) recibe el token y, opcionalmente, una
pista de qué tipo es:

```text
POST /revoke     token=...&token_type_hint=refresh_token    + autenticación del cliente
```

| Respuesta | Qué significa |
|---|---|
| `200` | Revocado, **o el token no existía**. El RFC responde 200 a tokens desconocidos para no revelar cuáles existen |
| `400 unsupported_token_type` | El servidor no revoca ese tipo de token |
| `503` | Repetir más tarde |

Revocar el refresh token es lo que importa: corta la renovación. Muchos
servidores no revocan access tokens que son JWT, porque la API los valida sin
preguntarle a nadie; ese token vale hasta su `exp`, y por eso conviene que
viva poco.

El simulador del laboratorio exige `token_type_hint`: sin él responde `400
unsupported_token_type: null`, y con `access_token` responde lo mismo.

---

## 3. Cómo se usa

Con el `tokens.json` de la teoría 04 (lleva refresh token), y el secreto en un
`--config` como en la teoría 02:

```bash
config=$(umask 077 && mktemp)
printf 'user = "%s"\ndata-urlencode = "grant_type=refresh_token"\ndata-urlencode = "refresh_token=%s"\n' \
  api-toolkit:secreto-de-laboratorio "$(jq -r .refresh_token tokens.json)" > "$config"
curl -sS --max-time 10 --config "$config" -o nuevo.json -w '%{http_code}\n' \
  http://localhost:8081/default/token
# 200
jq --slurpfile viejo tokens.json '.refresh_token == $viejo[0].refresh_token' nuevo.json
# true      ← el laboratorio no rota
```

Revocar y comprobar que el refresh token ya no sirve:

```bash
printf 'user = "%s"\ndata-urlencode = "token=%s"\ndata-urlencode = "token_type_hint=refresh_token"\n' \
  api-toolkit:secreto-de-laboratorio "$(jq -r .refresh_token tokens.json)" > "$config.revoke"
curl -sS --max-time 10 --config "$config.revoke" -o /dev/null -w '%{http_code}\n' \
  http://localhost:8081/default/revoke
# 200
curl -sS --max-time 10 --config "$config" http://localhost:8081/default/token | jq -r .error
# invalid_grant
rm -f "$config" "$config.revoke" nuevo.json
```

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Guardar `expires_in` | Una hora después no se sabe desde cuándo contaba | Guardar `expires_at` |
| Renovar justo en el `exp` | Peticiones que llegan con el token muerto | Un margen de 30 s |
| Renovar en cada petición "por si acaso" | Duplica las peticiones y castiga al servidor de tokens | Solo dentro del margen, o tras un 401 |
| Reintentar un 401 en bucle | Un cliente sin permisos se convierte en un ataque al servidor de tokens | Una renovación y una repetición |
| Caer a client credentials si el refresh falla | Cambia la identidad del script en silencio | Salir con 77 |
| Borrar la sesión local sin revocar | El refresh token sigue vivo para quien lo haya copiado | Revocar primero (teoría 08) |
| `--retry` en el refresh | Gasta un refresh token que rota | Sin reintentos automáticos |

---

## 5. Trucos

- **`date +%s` es UTC siempre**: el número no cambia con la zona horaria ni
  con el horario de verano. `expires_at` se puede comparar entre máquinas.
- **`date -d @1794448596`** (GNU) o **`date -r 1794448596`** (BSD) convierten
  un `expires_at` en fecha legible para depurar.
- **El `exp` del JWT y el `expires_at` deberían coincidir**, con un segundo de
  diferencia. Si no, tu reloj está desajustado: compáralos con `auth status`
  y la teoría 07.

---

## 📚 Recursos Adicionales

- [RFC 6749, apartado 6 — Refreshing an Access Token](https://datatracker.ietf.org/doc/html/rfc6749#section-6)
- [RFC 7009 — OAuth 2.0 Token Revocation](https://datatracker.ietf.org/doc/html/rfc7009)
- [RFC 9700, apartado 4.14 — Refresh Token Protection](https://datatracker.ietf.org/doc/html/rfc9700#section-4.14)

---

## ✅ Checklist de Verificación

- [ ] Conviertes `expires_in` en `expires_at` en el momento de recibirlo
- [ ] Explicas para qué sirve el margen y qué no puede arreglar
- [ ] Refrescas un token y compruebas si el servidor rota
- [ ] Revocas un refresh token y provocas el `invalid_grant` posterior
- [ ] Explicas por qué un 401 se reintenta una vez y nunca cambiando de identidad
