# Stage 3: Módulo de Requests

**Tiempo estimado:** 75 minutos
**Objetivo:** Implementar get/post/put/delete con autenticación automática, retry y logging

---

## Objetivo

Agregar los subcomandos de requests HTTP a `api-toolkit.sh`. Cada request debe autenticarse automáticamente si hay sesión, loguear el resultado, y reintentar en caso de 401 con refresh de token.

---

## Tarea 1: Función `do_request`

Función central que ejecuta cualquier request con curl:

```bash
do_request() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"
  local retry_count=0

  local url="${BASE_URL}${endpoint}"
  local args=(-sS --max-time "$TIMEOUT" --connect-timeout "$CONNECT_TIMEOUT")

  # Autenticación automática
  if is_token_valid 2>/dev/null; then
    local token
    token=$(load_token)
    args+=(-H "Authorization: Bearer $token")
  fi

  [ "$method" != "GET" ] && [ "$method" != "DELETE" ] && args+=(-X "$method")
  [ -n "$data" ] && args+=(-H "Content-Type: application/json" -d "$data")

  while [ "$retry_count" -le 1 ]; do
    local http_code response
    http_code=$(curl "${args[@]}" -o /tmp/api_toolkit_response_$$.json -w "%{http_code}" "$url")
    local curl_exit=$?

    response=$(cat /tmp/api_toolkit_response_$$.json 2>/dev/null || echo "{}")

    log_request "$method" "$endpoint" "$http_code"

    # Si es 401 y no hemos reintentado, refrescar token
    if [ "$http_code" = "401" ] && [ "$retry_count" -eq 0 ]; then
      if do_refresh; then
        retry_count=1
        # Actualizar el header con el nuevo token
        local new_token
        new_token=$(load_token)
        # Reconstruir args con nuevo token
        args=($(echo "${args[@]}" | sed "s/Bearer [^ ]*/Bearer $new_token/"))
        continue
      fi
    fi

    printf "%s\n" "$response"
    return "$curl_exit"
  done
}

log_request() {
  local method="$1" endpoint="$2" http_code="$3"
  local log_file="$CONFIG_DIR/requests.log"
  echo "[$(date -Iseconds)] $method $endpoint → $http_code" >> "$log_file"
}
```

---

## Tarea 2: Subcomandos `get`, `post`, `put`, `delete`

```bash
cmd_get() {
  local endpoint="${1:?Error: especificá un endpoint}"
  ensure_auth || return 1
  do_request "GET" "$endpoint"
}

cmd_post() {
  local endpoint="${1:?Error: especificá un endpoint}"
  local data="${2:?Error: especificá el body JSON}"
  ensure_auth || return 1
  do_request "POST" "$endpoint" "$data"
}

cmd_put() {
  local endpoint="${1:?Error: especificá un endpoint}"
  local data="${2:?Error: especificá el body JSON}"
  ensure_auth || return 1
  do_request "PUT" "$endpoint" "$data"
}

cmd_delete() {
  local endpoint="${1:?Error: especificá un endpoint}"
  ensure_auth || return 1
  do_request "DELETE" "$endpoint"
}
```

---

## Tarea 3: `do_refresh`

Refresca el token si tiene refresh_token:

```bash
do_refresh() {
  local refresh_token
  refresh_token=$(jq -r '.refresh_token // empty' "$TOKEN_FILE" 2>/dev/null)
  [ -z "$refresh_token" ] && return 1

  info "Token expirado, refrescando..."

  local response
  response=$(curl -sS --max-time "$TIMEOUT" \
    -d "grant_type=refresh_token" \
    -d "refresh_token=$refresh_token" \
    -d "client_id=$CLIENT_ID" \
    -d "client_secret=$CLIENT_SECRET" \
    "$TOKEN_URL") || return 1

  local new_token new_refresh expires_in
  new_token=$(echo "$response" | jq -r '.access_token // empty')
  new_refresh=$(echo "$response" | jq -r '.refresh_token // empty')
  expires_in=$(echo "$response" | jq -r '.expires_in // 3600')

  [ -z "$new_token" ] && return 1

  save_token "$new_token" "$expires_in"

  # Si el servidor devolvió un nuevo refresh_token, actualizarlo
  if [ -n "$new_refresh" ]; then
    jq --arg rt "$new_refresh" '.refresh_token = $rt' "$TOKEN_FILE" > "${TOKEN_FILE}.tmp"
    mv "${TOKEN_FILE}.tmp" "$TOKEN_FILE"
  fi

  info "Token refrescado exitosamente"
  return 0
}
```

---

## Tarea 4: `--output` flag

Agrega soporte para guardar la respuesta en archivo:

```bash
cmd_get() {
  local endpoint="${1:?Error: especificá un endpoint}"
  shift
  local output_file=""

  # Parsear --output
  while [ $# -gt 0 ]; do
    case "$1" in
      --output) output_file="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  ensure_auth || return 1

  if [ -n "$output_file" ]; then
    do_request "GET" "$endpoint" > "$output_file"
    info "Respuesta guardada en $output_file"
  else
    do_request "GET" "$endpoint"
  fi
}
```

---

## Tarea 5: `--dry-run`

Modo que muestra qué haría sin ejecutar:

```bash
do_request() {
  # ... args ...

  if $DRY_RUN; then
    info "[DRY RUN] $method $url"
    [ -n "$data" ] && info "[DRY RUN] body: $data"
    echo "{}"
    return 0
  fi

  # ... curl real ...
}
```

Activar con `--dry-run` como flag global en el dispatcher.

---

## Verificación

```bash
# 1. GET a jsonplaceholder sin auth
./api-toolkit.sh get /posts/1
# Debe mostrar el JSON del post (funciona sin auth si no se requiere)

# 2. GET con --output
./api-toolkit.sh get /posts/1 --output post.json
cat post.json | jq '.title'

# 3. POST a jsonplaceholder
./api-toolkit.sh post /posts '{"title":"Test","body":"Contenido","userId":1}'

# 4. Verificar log
cat ~/.api-toolkit/requests.log

# 5. --dry-run
./api-toolkit.sh --dry-run post /posts '{"title":"x"}'
```

---

## Entregables

- `do_request` con retry y logging en `api-toolkit.sh`
- Subcomandos `get`, `post`, `put`, `delete` funcionales
- `do_refresh` implementado
- `--output` y `--dry-run` funcionales
- `respuestas.md` con:
  - Cómo manejás el error 401 (refresh + retry)
  - Qué pasa si hacés un request sin haber hecho `auth login`
  - Diferencia entre `log_request` y `info`/`error`
