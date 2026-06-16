# Bearer Tokens y JWT

## Qué es un Bearer Token

Un Bearer Token es un token de acceso que obtenés después de autenticarte exitosamente. "Bearer" significa "portador" — cualquiera que tenga el token puede usarlo, de ahí la importancia de no compartirlo.

El formato en el header:
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## El flujo completo

A diferencia de Basic Auth (que manda usuario y contraseña en cada request), el flujo con Bearer Token tiene dos pasos:

```
Paso 1: POST /login
  → Enviar: { "email": "ana@example.com", "password": "1234" }
  ← Recibir: { "token": "eyJhbGciO..." }

Paso 2: GET /datos-privados
  → Enviar: Authorization: Bearer eyJhbGciO...
  ← Recibir: datos privados de Ana
```

Las credenciales solo viajan una vez (en el login). El token resultante tiene una vida útil limitada y puede ser revocado.

---

## Flujo con reqres.in

reqres.in es una API de prueba que implementa autenticación real:

```bash
# Paso 1: Login y obtener token
curl -s \
     -X POST \
     -H "Content-Type: application/json" \
     -d '{"email": "eve.holt@reqres.in", "password": "cityslicka"}' \
     https://reqres.in/api/login
```

Respuesta:
```json
{
  "token": "QpwL5tpe83ilfN2"
}
```

```bash
# Paso 2: Guardar el token en variable
TOKEN="QpwL5tpe83ilfN2"

# Paso 3: Usar el token en el siguiente request
curl -s \
     -H "Authorization: Bearer $TOKEN" \
     https://reqres.in/api/users/2
```

---

## Qué es un JWT

JWT (JSON Web Token) es el formato de token más usado. Un JWT tiene tres partes separadas por puntos:

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjEsImVtYWlsIjoiYW5hQGV4YW1wbGUuY29tIiwiZXhwIjoxNzE4MDAwMDAwfQ.FIRMA
```

Las partes son:
1. **Header** — algoritmo de firma y tipo de token (en base64)
2. **Payload** — datos del usuario y metadatos (en base64)
3. **Signature** — firma criptográfica para verificar integridad

---

## Decodificar el payload de un JWT sin librerías

El payload es simplemente base64. Podés leerlo sin herramientas especiales:

```bash
# Token de ejemplo
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjEsImVtYWlsIjoiYW5hQGV4YW1wbGUuY29tIiwiZXhwIjoxNzE4MDAwMDAwfQ.firma"

# Extraer el payload (segunda parte, entre los dos puntos)
PAYLOAD=$(echo "$TOKEN" | cut -d'.' -f2)

# Agregar padding de base64 si es necesario y decodificar
echo "${PAYLOAD}==" | base64 -d 2>/dev/null | python3 -m json.tool
```

Resultado:
```json
{
  "userId": 1,
  "email": "ana@example.com",
  "exp": 1718000000
}
```

El campo `exp` es el timestamp Unix de expiración. Para verlo como fecha:

```bash
python3 -c "import datetime; print(datetime.datetime.fromtimestamp(1718000000))"
```

---

## Probar Bearer Token con httpbin

```bash
TOKEN="mi-token-de-prueba"

curl -s \
     -H "Authorization: Bearer $TOKEN" \
     https://httpbin.org/bearer
```

Si el header `Authorization: Bearer` está presente y bien formado, httpbin responde 200:
```json
{
  "authenticated": true,
  "token": "mi-token-de-prueba"
}
```

Sin el header o con formato incorrecto, responde 401.

---

## Tokens con expiración

Un JWT tiene expiración (`exp`). Cuando el token expira:

```bash
# El servidor responde 401 con mensaje de expiración
curl -s -H "Authorization: Bearer TOKEN-EXPIRADO" https://api.ejemplo.com/datos
# {"error": "token expired", "code": 401}
```

El cliente debe volver al paso 1 (login) para obtener un token nuevo. Algunos servicios usan refresh tokens para renovar sin requerir login de nuevo.

---

## Diferencia entre los tres mecanismos

| | Basic Auth | API Key | Bearer Token |
|-|-----------|---------|-------------|
| Credenciales en cada request | Sí | Sí | No (solo en el login) |
| Representa | Usuario | Aplicación | Sesión de usuario |
| Tiene expiración | No | Opcional | Sí |
| Se puede revocar | No (sin cambiar pwd) | Sí | Sí |
| Estándar moderno | No | Parcialmente | Sí (OAuth2) |
