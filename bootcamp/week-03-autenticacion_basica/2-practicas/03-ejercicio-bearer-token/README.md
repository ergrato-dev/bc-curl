# Ejercicio 03: Bearer Token

## Objetivo

Completar el flujo de autenticación con Bearer Token: login → obtener token → usar el token en requests subsiguientes. Decodificar el payload de un JWT. Probar el endpoint con token válido, token inválido y sin token.

## API de práctica

`https://reqres.in` — API REST de prueba con autenticación real.

Credenciales de prueba que acepta reqres.in:
- Email: `eve.holt@reqres.in`
- Password: `cityslicka`

---

## Tareas

### 1. Paso 1: Login y obtener token

```bash
curl -s \
     -X POST \
     -H "Content-Type: application/json" \
     -d '{"email": "eve.holt@reqres.in", "password": "cityslicka"}' \
     https://reqres.in/api/login | python3 -m json.tool
```

Respuesta esperada:
```json
{
  "token": "QpwL5tpe83ilfN2"
}
```

Guardar el token en variable:

```bash
TOKEN=$(curl -s \
     -X POST \
     -H "Content-Type: application/json" \
     -d '{"email": "eve.holt@reqres.in", "password": "cityslicka"}' \
     https://reqres.in/api/login | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

echo "Token obtenido: $TOKEN"
```

### 2. Paso 2: Usar el token en un request

```bash
curl -s \
     -H "Authorization: Bearer $TOKEN" \
     https://reqres.in/api/users/2 | python3 -m json.tool
```

### 3. Probar sin token (401)

```bash
curl -v https://reqres.in/api/users/2 2>&1 | grep "< HTTP"
```

Nota: reqres.in en algunos endpoints devuelve 200 sin token para facilitar las pruebas. Si ese es el caso, probar con httpbin:

```bash
# httpbin valida el Bearer Token más estrictamente
curl -v \
     -H "Authorization: Bearer token-invalido" \
     https://httpbin.org/bearer 2>&1 | grep "< HTTP"
# < HTTP/2 401

curl -v \
     -H "Authorization: Bearer cualquier-token-valido" \
     https://httpbin.org/bearer 2>&1 | grep "< HTTP"
# < HTTP/2 200
```

### 4. Decodificar el payload de un JWT

reqres.in devuelve un token simple (no JWT). Para practicar con un JWT real, usar el siguiente token de ejemplo:

```bash
JWT="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjEsImVtYWlsIjoiZXZlLmhvbHRAcmVxcmVzLmluIiwicm9sZSI6InVzZXIiLCJpYXQiOjE3MTgwMDAwMDAsImV4cCI6MTcxODAwMzYwMH0.firma"

# Extraer el payload (segunda parte entre los dos puntos)
HEADER=$(echo "$JWT" | cut -d'.' -f1)
PAYLOAD=$(echo "$JWT" | cut -d'.' -f2)

# Decodificar el header
echo "=== Header ==="
echo "${HEADER}==" | base64 -d 2>/dev/null | python3 -m json.tool

# Decodificar el payload
echo "=== Payload ==="
echo "${PAYLOAD}==" | base64 -d 2>/dev/null | python3 -m json.tool
```

Identificar en el payload:
- `userId` — id del usuario
- `email` — email del usuario
- `iat` — issued at (cuándo se generó)
- `exp` — expiration (cuándo expira)

### 5. Ver la fecha de expiración en formato legible

```bash
# Extraer el campo exp del payload
EXP=$(echo "${PAYLOAD}==" | base64 -d 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('exp', 'no tiene exp'))")

echo "Token expira en timestamp: $EXP"

# Convertir a fecha legible
python3 -c "import datetime; print(datetime.datetime.fromtimestamp($EXP))"
```

### 6. Flujo completo en un script

```bash
#!/bin/bash
# auth-flow.sh

BASE="https://reqres.in/api"

echo "--- Paso 1: Login ---"
RESPONSE=$(curl -s \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"email": "eve.holt@reqres.in", "password": "cityslicka"}' \
    "$BASE/login")

echo "$RESPONSE" | python3 -m json.tool

TOKEN=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")
echo ""
echo "Token: $TOKEN"
echo ""

echo "--- Paso 2: Request autenticado ---"
curl -s \
    -H "Authorization: Bearer $TOKEN" \
    "$BASE/users/2" | python3 -m json.tool
```

---

## Preguntas para responder

1. ¿Cuántas partes tiene un JWT y qué contiene cada una?
2. ¿Por qué el payload de un JWT es legible sin la clave secreta?
3. ¿Qué pasa cuando el token expira? ¿Cómo lo detectás en el código?
4. ¿Qué ventaja tiene el flujo de Bearer Token sobre Basic Auth para una app con muchos usuarios?

---

## Entrega

Archivo `respuestas.md` con:
1. Token obtenido en el paso 1
2. Response del paso 2 (request autenticado)
3. Payload decodificado del JWT del paso 4
4. Script `auth-flow.sh` completo
5. Respuestas a las 4 preguntas
