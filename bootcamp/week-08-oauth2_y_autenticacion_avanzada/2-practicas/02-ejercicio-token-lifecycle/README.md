# Ejercicio 02: Token Lifecycle Management

## Objetivo

Implementar un script `token-manager.sh` que gestiona el ciclo de vida del access token de forma transparente: obtiene el token la primera vez, lo guarda en disco, lo reutiliza en llamadas siguientes, y lo renueva automaticamente cuando expira.

## El Problema a Resolver

Sin gestion de tokens, cada llamada a una API OAuth2 requiere un nuevo token:

```bash
# Ineficiente: 2 requests por llamada a la API
TOKEN=$(obtener_token)
curl -H "Authorization: Bearer $TOKEN" https://api/recurso
```

Con gestion, el token se reutiliza hasta que expira:

```bash
# Eficiente: token reutilizado hasta expiracion
TOKEN=$(get_valid_token)  # obtiene del cache o renueva si expiro
curl -H "Authorization: Bearer $TOKEN" https://api/recurso
```

## Estructura del Archivo de Token

El token se guarda en `$HOME/.token-manager/token.json`:

```json
{
  "access_token": "eyJhbGci...",
  "refresh_token": "1//0gLd...",
  "expires_at": 1728003600,
  "token_type": "Bearer"
}
```

`expires_at` es el Unix timestamp en que expira el access token (calculado como `date +%s + expires_in`).

## Tareas

### 1. Funcion: save_token

Implementar una funcion que recibe la respuesta JSON del token endpoint y la guarda en disco:

```bash
save_token() {
  local response="$1"
  # TODO: implementar
  # - Extraer access_token, expires_in, refresh_token (puede no existir)
  # - Calcular expires_at = now + expires_in
  # - Guardar JSON en TOKEN_FILE
  # - chmod 600 al archivo
}
```

### 2. Funcion: is_token_valid

Funcion que retorna 0 si el token existe y no expiró (con margen de 60 segundos), 1 si no:

```bash
is_token_valid() {
  # TODO: implementar
  # - Verificar que TOKEN_FILE existe
  # - Leer expires_at del archivo
  # - Comparar (expires_at - 60) con $(date +%s)
  # - Retornar 0 si valido, 1 si expirado/ausente
}
```

### 3. Funcion: get_token

Si el token es valido, retornarlo. Si no, obtener uno nuevo:

```bash
get_token() {
  if is_token_valid; then
    jq -r '.access_token' "$TOKEN_FILE"
  else
    echo "Obteniendo nuevo token..." >&2
    local response
    response=$(curl -s -X POST "$TOKEN_ENDPOINT" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "grant_type=client_credentials" \
      -d "client_id=$CLIENT_ID" \
      -d "client_secret=$CLIENT_SECRET" \
      -d "scope=$SCOPE")
    save_token "$response"
    jq -r '.access_token' "$TOKEN_FILE"
  fi
}
```

### 4. Funcion: api_call

Funcion que hace un request a la API usando siempre un token valido:

```bash
api_call() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"
  local token
  token=$(get_token)
  
  curl -s -X "$method" "$BASE_URL$endpoint" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    ${data:+-d "$data"}
}
```

### 5. Probar el lifecycle

Ejecutar el script varias veces y verificar:

```bash
# Primera ejecucion: debe obtener token nuevo
./token-manager.sh
# "Obteniendo nuevo token..."

# Segunda ejecucion: debe reutilizar token
./token-manager.sh
# (sin mensaje de "Obteniendo nuevo token...")

# Ver el token guardado
cat ~/.token-manager/token.json | jq '{expires_at: .expires_at, token_prefix: (.access_token | .[0:20])}'

# Cuanto tiempo falta para que expire?
exp=$(jq -r '.expires_at' ~/.token-manager/token.json)
echo "Expira en: $(( exp - $(date +%s) )) segundos"
```

### 6. Simular expiracion

Para probar la renovacion sin esperar una hora, modificar manualmente el `expires_at` del archivo de token a un timestamp pasado:

```bash
# Hacer que el token "expire" (timestamp del pasado)
jq '.expires_at = 1000000' ~/.token-manager/token.json > /tmp/token.json \
  && mv /tmp/token.json ~/.token-manager/token.json

# Ejecutar de nuevo — debe obtener un token nuevo
./token-manager.sh
# "Obteniendo nuevo token..."
```

## Script Completo a Entregar

El archivo `token-manager.sh` debe:
- Tener las 4 funciones implementadas
- Ser sourceable (poder hacer `source token-manager.sh`) o ejecutable directamente
- Tener las variables de configuracion al inicio (TOKEN_ENDPOINT, CLIENT_ID, etc.)
- Cuando se ejecuta directamente, hacer una llamada de prueba a la API y mostrar la respuesta

## Entrega

Archivo `respuestas.md` con:
1. Codigo completo de `token-manager.sh`
2. Output de la primera ejecucion (con mensaje de "Obteniendo token")
3. Output de la segunda ejecucion (sin mensaje, token reutilizado)
4. Output despues de simular expiracion (nuevo token obtenido)
5. Una reflexion breve: por que es importante el margen de 60 segundos?
