# Ejercicio 03: Refresh Token

## Objetivo

Entender y practicar el flujo de renovacion de access token usando un refresh token, incluyendo el manejo del escenario mas comun: detectar un 401 y renovar automaticamente.

## Contexto

El servidor de demo `demo.duendesoftware.com` tiene un cliente con soporte de refresh token. Para este ejercicio se usa un cliente diferente al del ejercicio 01:

- client_id: `interactive.public`
- client_secret: (no tiene — es un cliente publico)
- scope: `openid profile api offline_access`

El scope `offline_access` es el que le indica al servidor que queremos un refresh token.

Nota: Para obtener el refresh token en un flujo interactivo real necesitamos Authorization Code. En este ejercicio vamos a simular haberlo obtenido previamente y trabajar directamente con el refresh token.

## Alternativa con Keycloak Local

Si tienes Docker disponible, levantar Keycloak local es mas practico:

```bash
docker run -d --name keycloak -p 8080:8080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin \
  quay.io/keycloak/keycloak:latest start-dev
```

Keycloak permite crear un cliente con Client Credentials que devuelva refresh tokens, lo que simplifica el ejercicio.

## Tareas

### 1. Obtener access + refresh token (simulado)

Para este ejercicio, vamos a trabajar con un servidor local simple usando Python que simula tokens:

```bash
# Servidor mock (ejecutar en otra terminal)
python3 -c "
import http.server, json, time, base64

class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length).decode()
        params = dict(p.split('=') for p in body.split('&') if '=' in p)
        
        if params.get('grant_type') == 'refresh_token' and params.get('refresh_token') == 'valid-refresh-token':
            # Nuevo access token
            resp = json.dumps({'access_token': 'new-access-token-' + str(int(time.time())), 'expires_in': 3600, 'token_type': 'Bearer'})
            self.send_response(200)
        elif params.get('refresh_token') == 'expired-refresh-token':
            resp = json.dumps({'error': 'invalid_grant', 'error_description': 'Token has expired'})
            self.send_response(400)
        else:
            resp = json.dumps({'error': 'invalid_request'})
            self.send_response(400)
        
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(resp.encode())
    
    def log_message(self, *args): pass

http.server.HTTPServer(('', 9999), Handler).serve_forever()
"
```

### 2. Simular refresh con token valido

```bash
curl -s -X POST "http://localhost:9999/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token" \
  -d "refresh_token=valid-refresh-token" \
  -d "client_id=mi-app"
```

Que devuelve? El nuevo `access_token` tiene el timestamp en el nombre — ejecutar dos veces y ver que cambia.

### 3. Simular refresh con token expirado

```bash
curl -s -X POST "http://localhost:9999/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token" \
  -d "refresh_token=expired-refresh-token" \
  -d "client_id=mi-app"
```

Que error devuelve? Que deberia hacer el script en este caso?

### 4. Implementar funcion de retry con refresh

Escribir una funcion `api_call_with_retry` que:
1. Hace el request con el access token actual
2. Si recibe 401, intenta renovar el token con el refresh token
3. Si la renovacion falla, informa al usuario que necesita hacer login de nuevo
4. Si la renovacion es exitosa, reintenta el request original una vez

```bash
api_call_with_retry() {
  local method="$1"
  local url="$2"
  local access_token="$3"
  local refresh_token="$4"
  
  # Primer intento
  response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
    -H "Authorization: Bearer $access_token")
  
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)
  
  if [ "$http_code" = "401" ]; then
    echo "Token expirado, intentando renovar..." >&2
    
    # TODO: implementar renovacion y reintento
    # - POST al token endpoint con grant_type=refresh_token
    # - Si falla (status != 200), imprimir error y retornar 1
    # - Si funciona, extraer nuevo access_token
    # - Reintentar el request con el nuevo token
    # - Retornar el resultado
  else
    echo "$body"
    return 0
  fi
}
```

### 5. Probar el flujo completo

Con el servidor mock corriendo:

```bash
# Simular que tenemos access token vencido y refresh token valido
EXPIRED_ACCESS="expired-access-token"
VALID_REFRESH="valid-refresh-token"
API_URL="https://httpbin.org/bearer"  # verifica Bearer tokens

# Esto deberia: fallar con 401, renovar, reintentar con el nuevo token
api_call_with_retry GET "$API_URL" "$EXPIRED_ACCESS" "$VALID_REFRESH"
```

## Reflexion

Responder en `respuestas.md`:
1. Por que el refresh token es mas largo-lived que el access token?
2. Que deberia hacer el script cuando el refresh token también expira?
3. Si detectas `invalid_grant` al hacer refresh, que le mostras al usuario?

## Entrega

Archivo `respuestas.md` con:
1. Output de los comandos del paso 2 y 3
2. Implementacion completa de `api_call_with_retry`
3. Output del flujo completo del paso 5
4. Respuestas a las preguntas de reflexion
