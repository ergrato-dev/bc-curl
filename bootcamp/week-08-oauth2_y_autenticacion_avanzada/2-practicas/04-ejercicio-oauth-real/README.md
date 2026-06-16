# Ejercicio 04: OAuth2 con una API Real

## Objetivo

Implementar el flujo OAuth2 completo contra una API real de produccion usando curl. El ejercicio usa la GitHub API con OAuth Apps, que tiene una implementacion bien documentada y no requiere datos de pago.

## Opcion A: GitHub API con Personal Access Token (mas simple)

GitHub permite usar Personal Access Tokens como Bearer tokens — tecnicamente no es OAuth2 completo pero usa el mismo patron de uso:

```bash
# Crear un PAT en: https://github.com/settings/tokens
# Scopes recomendados para este ejercicio: repo, user

GITHUB_TOKEN="ghp_tu_token_aqui"

# Obtener tu perfil
curl -s "https://api.github.com/user" \
  -H "Authorization: Bearer $GITHUB_TOKEN" | jq '{login, name, public_repos}'

# Listar tus repos
curl -s "https://api.github.com/user/repos?per_page=5" \
  -H "Authorization: Bearer $GITHUB_TOKEN" | jq '.[].full_name'

# Verificar los scopes del token (en los headers de respuesta)
curl -sI "https://api.github.com/user" \
  -H "Authorization: Bearer $GITHUB_TOKEN" | grep -i "x-oauth-scopes"
```

## Opcion B: GitHub OAuth App (flujo completo)

Para el flujo Authorization Code real con GitHub:

### Paso 1: Crear una OAuth App en GitHub

1. Ir a `https://github.com/settings/developers`
2. Hacer click en "New OAuth App"
3. Completar:
   - Application name: `curl-bootcamp-test`
   - Homepage URL: `http://localhost`
   - Authorization callback URL: `http://localhost:8080/callback`
4. Guardar `Client ID` y `Client Secret`

### Paso 2: Construir la URL de autorizacion

```bash
CLIENT_ID="tu-client-id-de-github"
REDIRECT_URI="http://localhost:8080/callback"
SCOPE="read:user repo"
STATE=$(openssl rand -hex 16)

AUTH_URL="https://github.com/login/oauth/authorize?client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=${SCOPE// /+}&state=${STATE}"

echo "Abrir en el browser:"
echo "$AUTH_URL"
```

### Paso 3: Capturar el code del callback

Abrir la URL en el browser. Despues de autorizar, GitHub redirige a `http://localhost:8080/callback?code=XXXX&state=YYYY`.

Para capturar el code con un server temporario en bash:

```bash
# Server HTTP minimo para capturar el callback
# Escucha en puerto 8080 por una sola conexion
CODE=$(nc -l -p 8080 -q1 | grep -oP 'code=\K[^& ]+')
echo "Code obtenido: $CODE"
```

O mas robusto con Python:

```bash
python3 -c "
import http.server, urllib.parse, sys

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        params = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        code = params.get('code', [''])[0]
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'Autorizado! Podes cerrar esta ventana.')
        print('CODE=' + code, flush=True)
        sys.exit(0)
    def log_message(self, *args): pass

http.server.HTTPServer(('', 8080), Handler).serve_forever()
" &
SERVER_PID=$!
# ...abrir browser, esperar callback...
```

### Paso 4: Intercambiar el code por tokens

```bash
CLIENT_SECRET="tu-client-secret"

TOKEN_RESPONSE=$(curl -s -X POST "https://github.com/login/oauth/access_token" \
  -H "Accept: application/json" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "code=$CODE" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "redirect_uri=$REDIRECT_URI")

echo "$TOKEN_RESPONSE" | jq '.'
ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
```

Nota: GitHub no devuelve un JWT sino un token opaco, y no incluye `expires_in` por defecto (los tokens no expiran hasta que se revocan). La estructura del token es `gho_XXXXX`.

### Paso 5: Usar el token

```bash
# Obtener tu perfil
curl -s "https://api.github.com/user" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq '{login, name, public_repos, followers}'

# Verificar repositorios privados (si autorizaste el scope repo)
curl -s "https://api.github.com/user/repos?type=private&per_page=3" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq '.[].name'
```

## Opcion C: Spotify (tiene refresh tokens de verdad)

Spotify tiene un excelente OAuth2 con refresh tokens si preferis practicar con eso. Ver: `https://developer.spotify.com/documentation/web-api/tutorials/getting-started`

## Documentar Tu Implementacion

En `respuestas.md` incluir:

1. **Que API elegiste** y por que
2. **Los pasos que seguiste** para crear la app y obtener credenciales
3. **Los comandos curl** usados en cada paso (con datos sensibles redactados)
4. **Output de al menos dos endpoints** de la API autenticados con tu token
5. **Una reflexion**: que fue mas dificil de lo esperado? Que harías diferente en produccion?

## Consideraciones de Seguridad

- **Nunca commitear** client_secret ni access_token al repositorio
- Usar variables de entorno o un archivo `.env` ignorado por git
- En `respuestas.md`, redactar los tokens: `gho_XXXX...` (mostrar solo el prefijo)
- Los tokens de GitHub creados para este ejercicio pueden revocarse en `https://github.com/settings/applications`
