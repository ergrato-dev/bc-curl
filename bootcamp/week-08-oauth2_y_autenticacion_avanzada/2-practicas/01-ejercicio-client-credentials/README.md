# Ejercicio 01: Client Credentials Flow

## Objetivo

Implementar el flujo OAuth2 Client Credentials de punta a punta: obtener un access token y usarlo para acceder a un endpoint protegido.

## Servidor de Prueba

- Token endpoint: `https://demo.duendesoftware.com/connect/token`
- API protegida: `https://demo.duendesoftware.com/api/test`
- client_id: `m2m`
- client_secret: `secret`
- scope: `api`

## Tareas

### 1. Obtener el token

Construir el request de Client Credentials. Recordar:
- Metodo: `POST`
- Content-Type: `application/x-www-form-urlencoded`
- Body: `grant_type=client_credentials`, `client_id`, `client_secret`, `scope`

```bash
curl -s -X POST "https://demo.duendesoftware.com/connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=m2m" \
  -d "client_secret=secret" \
  -d "scope=api"
```

Anotar: `access_token`, `expires_in`, `token_type`.

### 2. Inspeccionar el token

El token que devuelve este servidor es un JWT. Decodificar el payload:

```bash
# Reemplazar TOKEN con el access_token obtenido
TOKEN="..."
echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq '.'
```

Responder:
- Que valor tiene `sub`?
- Que valor tiene `iss`?
- Que valor tiene `exp`? Convertirlo a fecha legible con `date -d @TIMESTAMP`
- El scope solicitado esta en el token?

### 3. Usar el token en un request protegido

```bash
ACCESS_TOKEN="..."  # pegar el token del paso 1
curl -s "https://demo.duendesoftware.com/api/test" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Que devuelve la API?

### 4. Verificar que sin token da 401

```bash
curl -s -w "\nHTTP %{http_code}\n" "https://demo.duendesoftware.com/api/test"
```

### 5. Verificar que con token invalido da 401

```bash
curl -s -w "\nHTTP %{http_code}\n" "https://demo.duendesoftware.com/api/test" \
  -H "Authorization: Bearer token-invalido"
```

### 6. Script completo

Escribir un script `client-credentials.sh` que:
1. Obtiene el token
2. Verifica que el token no sea null (si lo es, salir con error)
3. Hace el request a la API con el token
4. Muestra el status code y el body de la respuesta

El script debe funcionar sin modificaciones si se cambia la URL de la API al inicio.

## Desafio Adicional

Intentar el mismo flujo con Basic Auth para enviar las credenciales:

```bash
curl -s -X POST "https://demo.duendesoftware.com/connect/token" \
  -u "m2m:secret" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "scope=api"
```

El resultado debe ser el mismo. En que casos preferirias Basic Auth vs body params?

## Entrega

Archivo `respuestas.md` con:
1. Output completo del request de token (puede redactar el token parcialmente)
2. Payload del JWT decodificado
3. Respuestas a las preguntas del paso 2
4. Output del request protegido (paso 3)
5. Codigo del script `client-credentials.sh`
