# Stage 2: Módulo de Autenticación

**Tiempo estimado:** 60 minutos
**Objetivo:** Implementar auth login/logout/status con token lifecycle completo

---

## Objetivo

Continuar construyendo `api-toolkit.sh`. En esta etapa agregás el módulo de autenticación OAuth2: obtención de token, almacenamiento persistente, verificación de expiración, y refresh automático.

---

## Tarea 1: `auth login`

Implementa `cmd_auth_login()` que:

1. Usa `load_config` para leer `TOKEN_URL`, `CLIENT_ID`, `CLIENT_SECRET`
2. Hace POST a `TOKEN_URL` con `grant_type=client_credentials`
3. Guarda el token en `~/.api-toolkit/token.json` con `save_token`
4. Muestra "Sesión iniciada. Token válido hasta: ..."

```bash
cmd_auth_login() {
  load_config

  local response
  response=$(curl -sS --max-time "$TIMEOUT" \
    -d "grant_type=client_credentials" \
    -d "client_id=$CLIENT_ID" \
    -d "client_secret=$CLIENT_SECRET" \
    "$TOKEN_URL") || { error "No se pudo conectar al servidor de autenticación"; return 1; }

  local token
  token=$(echo "$response" | jq -r '.access_token // empty')
  [ -z "$token" ] && { error "El servidor no devolvió access_token"; return 1; }

  local expires_in
  expires_in=$(echo "$response" | jq -r '.expires_in // 3600')

  save_token "$token" "$expires_in"
  info "Sesión iniciada. Token válido hasta $(date -d "@$(( $(date +%s) + expires_in ))" '+%H:%M:%S')"
}
```

---

## Tarea 2: `save_token` y `load_token`

Implementa las funciones de persistencia:

```bash
TOKEN_FILE="$CONFIG_DIR/token.json"

save_token() {
  local token="$1"
  local expires_in="${2:-3600}"
  local now
  now=$(date +%s)
  local expires_at=$((now + expires_in))

  mkdir -p "$(dirname "$TOKEN_FILE")"
  jq -n --arg token "$token" --argjson exp "$expires_at" \
    '{access_token: $token, expires_at: $exp}' > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
}

load_token() {
  [ -f "$TOKEN_FILE" ] || return 1
  jq -r '.access_token' "$TOKEN_FILE"
}

is_token_valid() {
  [ -f "$TOKEN_FILE" ] || return 1
  local expires_at
  expires_at=$(jq -r '.expires_at' "$TOKEN_FILE")
  local now
  now=$(date +%s)
  # Token válido si expira en más de 60 segundos
  [ "$expires_at" -gt $((now + 60)) ]
}
```

---

## Tarea 3: `auth status`

Muestra información del token actual:

```bash
cmd_auth_status() {
  if ! [ -f "$TOKEN_FILE" ]; then
    info "No hay sesión activa"
    return 1
  fi

  local expires_at token_preview
  expires_at=$(jq -r '.expires_at' "$TOKEN_FILE")
  token_preview=$(jq -r '.access_token[:20] + "..."' "$TOKEN_FILE")

  local now remaining
  now=$(date +%s)
  remaining=$((expires_at - now))

  echo "Token: $token_preview"
  echo "Expira en: ${remaining}s ($(date -d "@$expires_at" '+%Y-%m-%d %H:%M:%S'))"

  if [ "$remaining" -lt 60 ]; then
    echo "Estado: EXPIRADO"
    return 1
  elif [ "$remaining" -lt 300 ]; then
    echo "Estado: POR EXPIRAR"
  else
    echo "Estado: VÁLIDO"
  fi
}
```

---

## Tarea 4: `auth logout`

Borra el archivo de token:

```bash
cmd_auth_logout() {
  if [ -f "$TOKEN_FILE" ]; then
    rm -f "$TOKEN_FILE"
    info "Sesión cerrada"
  else
    info "No hay sesión activa"
  fi
}
```

---

## Tarea 5: `ensure_auth`

Función que verifica si hay token y si es válido antes de cada request:

```bash
ensure_auth() {
  if ! is_token_valid; then
    error "No hay sesión activa o expiró. Usá: api-toolkit auth login"
    return 1
  fi
}
```

---

## Verificación

```bash
# 1. Login (sin servidor OAuth real, usa httpbin)
# Para pruebas: simulá el token endpoint con httpbin/post y extraé access_token

# 2. Verificar que token.json se creó
cat ~/.api-toolkit/token.json | jq '.'

# 3. Verificar permisos
ls -la ~/.api-toolkit/token.json   # debe mostrar -rw-------

# 4. Status
./api-toolkit.sh auth status

# 5. Logout
./api-toolkit.sh auth logout
```

---

## Entregables

- Funciones `save_token`, `load_token`, `is_token_valid` en `api-toolkit.sh`
- Subcomandos `auth login`, `auth status`, `auth logout` funcionales
- `respuestas.md` con:
  - Cómo verificaste que el token se guarda correctamente
  - Qué pasa si intentás `auth status` sin haber hecho login
  - Cómo calculás el `expires_at`
