# Client Credentials Flow

## El Flujo Mas Simple

Client Credentials es el flujo OAuth2 para comunicacion maquina a maquina. No hay usuario, no hay browser, no hay intervencion humana. La aplicacion se autentica directamente con sus propias credenciales.

```
Client                          Authorization Server
  |                                      |
  |--- POST /token ---------------------->|
  |    client_id, client_secret           |  verifica credenciales
  |    grant_type=client_credentials      |  genera token
  |<-- 200 OK {access_token, expires_in} -|
  |                                      |
  |             Resource Server          |
  |--- GET /api/datos ------------------>|
  |    Authorization: Bearer TOKEN       |  valida token
  |<-- 200 OK {datos} -------------------|
```

---

## Paso 1: Obtener el Token

La peticion al token endpoint usa `Content-Type: application/x-www-form-urlencoded` (no JSON):

```bash
TOKEN_RESPONSE=$(curl -s -X POST "https://demo.duendesoftware.com/connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=m2m" \
  -d "client_secret=secret" \
  -d "scope=api")

echo "$TOKEN_RESPONSE"
```

Respuesta tipica:

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjI5QT...",
  "expires_in": 3600,
  "token_type": "Bearer",
  "scope": "api"
}
```

---

## Paso 2: Extraer el Token

Con `jq` para extraer el access_token:

```bash
ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

# Verificar que lo obtuvimos
if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
  echo "Error: no se pudo obtener el token" >&2
  echo "Respuesta del servidor: $TOKEN_RESPONSE" >&2
  exit 1
fi
```

---

## Paso 3: Usar el Token

El token se envia como `Bearer` en el header `Authorization`:

```bash
curl -s "https://demo.duendesoftware.com/api/test" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Este patron — obtener token, usar token — se repite en todos los flujos OAuth2.

---

## Verificar la Expiracion

La respuesta incluye `expires_in` (segundos hasta que expira). Para calcular el timestamp de expiracion:

```bash
EXPIRES_IN=$(echo "$TOKEN_RESPONSE" | jq -r '.expires_in')
EXPIRES_AT=$(( $(date +%s) + EXPIRES_IN ))

echo "El token expira en: $(date -d @$EXPIRES_AT)"
```

---

## Script Completo: Obtener y Usar Token

```bash
#!/bin/bash
# client-credentials-demo.sh

TOKEN_ENDPOINT="https://demo.duendesoftware.com/connect/token"
API_ENDPOINT="https://demo.duendesoftware.com/api/test"
CLIENT_ID="m2m"
CLIENT_SECRET="secret"
SCOPE="api"

# Obtener token
echo "Obteniendo token..."
TOKEN_RESPONSE=$(curl -s -X POST "$TOKEN_ENDPOINT" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=$SCOPE")

# Extraer campos
ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
EXPIRES_IN=$(echo "$TOKEN_RESPONSE" | jq -r '.expires_in')
TOKEN_TYPE=$(echo "$TOKEN_RESPONSE" | jq -r '.token_type')

# Validar
if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "Error al obtener token: $TOKEN_RESPONSE" >&2
  exit 1
fi

echo "Token obtenido: ${ACCESS_TOKEN:0:20}..."
echo "Tipo: $TOKEN_TYPE"
echo "Expira en: ${EXPIRES_IN}s"

# Usar el token
echo ""
echo "Llamando a la API..."
RESPONSE=$(curl -s -w "\n%{http_code}" "$API_ENDPOINT" \
  -H "Authorization: $TOKEN_TYPE $ACCESS_TOKEN")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

echo "Status: $HTTP_CODE"
echo "Respuesta: $BODY"
```

---

## Alternativa: Basic Auth para Client Credentials

Algunos Authorization Servers aceptan `client_id:client_secret` como Basic Auth en el header en lugar de en el body:

```bash
curl -s -X POST "$TOKEN_ENDPOINT" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "scope=api"
```

Ambos metodos son validos segun el RFC. Consultar la documentacion del servidor que uses para saber cual prefiere.

---

## Errores Comunes

| Error | Causa | Solucion |
|-------|-------|---------|
| `invalid_client` | client_id o client_secret incorrectos | Verificar credenciales |
| `invalid_scope` | Scope no registrado para ese cliente | Revisar scopes configurados |
| `401 Unauthorized` en el API | Token expirado o mal formado | Obtener nuevo token |
| `403 Forbidden` en el API | Token valido pero sin permiso para ese recurso | Verificar scopes del token |
