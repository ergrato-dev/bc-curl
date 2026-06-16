# curl en contextos CI/CD y automatizacion

[← 04: Documentacion CLI](04-documentacion-cli.md) | [← Semana 10](../README.md)

---

## curl como herramienta de automatizacion

Hasta ahora has usado curl interactivamente desde la terminal. En produccion, curl aparece en lugares inesperados: scripts de deploy, pipelines de CI, healthchecks de Docker, scripts de alertas. Esta seccion cubre los patrones mas comunes.

La clave para usar curl en automatizacion: comportarse bien en pipelines (exit codes correctos, sin prompts interactivos, output parseable).

---

## GitHub Actions con curl

### Smoke test post-deploy

Un smoke test verifica que el deploy funciono. Se ejecuta despues de cada deploy y bloquea el pipeline si falla:

```yaml
# .github/workflows/deploy.yml
name: Deploy y Smoke Test

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy a produccion
        run: |
          # ... tu proceso de deploy ...
          echo "Deploy completado"

      - name: Smoke test post-deploy
        run: |
          # Esperar hasta que el servicio este disponible (max 30s)
          for i in $(seq 1 6); do
            STATUS=$(curl -sf -o /dev/null -w "%{http_code}" "${{ secrets.API_URL }}/health" || echo "000")
            if [[ "$STATUS" == "200" ]]; then
              echo "Servicio disponible (HTTP $STATUS)"
              break
            fi
            echo "Intento $i: HTTP $STATUS. Esperando 5s..."
            sleep 5
          done

          # Verificacion final
          STATUS=$(curl -sf -o /dev/null -w "%{http_code}" "${{ secrets.API_URL }}/health")
          if [[ "$STATUS" != "200" ]]; then
            echo "ERROR: /health retorno HTTP $STATUS"
            exit 1
          fi

          # Verificar que el endpoint principal responde
          curl -sf "${{ secrets.API_URL }}/users" | jq -e '. | length > 0' \
            || { echo "ERROR: /users retorno respuesta invalida"; exit 1; }

          echo "Todos los smoke tests pasaron."
```

### Flags criticos para CI

```bash
# -s: silencioso (sin barra de progreso)
# -f: fail silenciosamente en HTTP errors (4xx, 5xx) — retorna exit code != 0
# -o /dev/null: descartar body (solo nos interesa el status)
# -w "%{http_code}": imprimir solo el status code
curl -sf -o /dev/null -w "%{http_code}" https://api.ejemplo.com/health

# --max-time: timeout total (segundos). SIEMPRE poner en CI.
# --retry: numero de reintentos automaticos de curl
# --retry-delay: segundos entre reintentos
curl --max-time 10 --retry 3 --retry-delay 2 https://api.ejemplo.com/health
```

En CI, sin `--max-time` un request colgado bloquea el pipeline indefinidamente.

---

## Webhook trigger desde curl

Los webhooks son requests HTTP que disparan acciones en sistemas remotos. GitHub, GitLab, Slack, PagerDuty todos los usan.

### Triggerear un workflow de GitHub desde otro sistema

```bash
# repository_dispatch: evento personalizado que puede triggerear workflows
curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -d '{"event_type": "deploy-staging", "client_payload": {"sha": "'"${GIT_SHA}"'"}}' \
  https://api.github.com/repos/ORG/REPO/dispatches
```

```yaml
# En el workflow que recibe el evento:
on:
  repository_dispatch:
    types: [deploy-staging]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy SHA
        run: echo "Deploying ${{ github.event.client_payload.sha }}"
```

### Notificacion a Slack

```bash
notify_slack() {
  local message="$1"
  local webhook_url="${SLACK_WEBHOOK_URL}"

  curl -sf -X POST \
    -H "Content-Type: application/json" \
    -d "{\"text\": \"${message}\"}" \
    "${webhook_url}" \
    || log "WARN: No se pudo notificar a Slack"
}

# Uso:
notify_slack "Deploy completado: v1.2.3 en produccion"
notify_slack "ERROR: Smoke test fallido en produccion"
```

Nota: el `|| log "WARN: ..."` es importante — si Slack esta caido, no quieres que falle el deploy.

---

## curl en Dockerfile

Para images que necesitan llamar APIs (scripts de init, health checks, tooling):

```dockerfile
FROM alpine:3.19

# Instalar curl, jq y bash
RUN apk add --no-cache curl jq bash

# Copiar la herramienta
COPY api-toolkit.sh /usr/local/bin/api-toolkit
RUN chmod +x /usr/local/bin/api-toolkit

# El script espera config en $HOME/.api-toolkit/
# En Docker, se monta como volumen o se pasan variables de entorno:
# docker run -e BASE_URL=https://api.ejemplo.com -e AUTH_TYPE=none myimage

CMD ["api-toolkit", "--help"]
```

Construir y probar:

```bash
docker build -t api-toolkit:1.0.0 .
docker run --rm \
  -e BASE_URL=https://jsonplaceholder.typicode.com \
  -e AUTH_TYPE=none \
  api-toolkit:1.0.0 \
  api-toolkit get /users/1
```

---

## Health check en docker-compose

```yaml
# docker-compose.yml
services:
  api:
    image: mi-api:latest
    ports:
      - "8000:8000"
    healthcheck:
      # curl -sf retorna exit 0 si HTTP 2xx, exit 22 si HTTP 4xx/5xx
      test: ["CMD", "curl", "-sf", "http://localhost:8000/health"]
      interval: 30s    # tiempo entre checks
      timeout: 10s     # timeout por check
      start_period: 15s  # tiempo de gracia al inicio
      retries: 3       # intentos antes de marcar como unhealthy

  worker:
    image: mi-worker:latest
    depends_on:
      api:
        condition: service_healthy  # espera hasta que api este healthy
```

Con `condition: service_healthy`, el `worker` no inicia hasta que la API pase el health check. Esto reemplaza los `sleep 10` en scripts de startup.

---

## Script de smoke tests completo

Un smoke test real para usar post-deploy:

```bash
#!/bin/bash
# smoke-test.sh — verifica endpoints criticos post-deploy
set -euo pipefail

API_URL="${API_URL:-https://api.ejemplo.com}"
MAX_WAIT=60  # segundos maximos para que el servicio este disponible

log()   { echo "[$(date '+%H:%M:%S')] $*"; }
pass()  { log "PASS: $*"; }
fail()  { log "FAIL: $*"; FAILURES=$(( FAILURES + 1 )); }

FAILURES=0

# Esperar a que el servicio este disponible
log "Esperando que ${API_URL} este disponible..."
deadline=$(( $(date +%s) + MAX_WAIT ))
while (( $(date +%s) < deadline )); do
  if curl -sf -o /dev/null "${API_URL}/health"; then
    log "Servicio disponible."
    break
  fi
  sleep 5
done

# Test 1: /health retorna 200
log "Test 1: /health"
STATUS=$(curl -sf -o /dev/null -w "%{http_code}" "${API_URL}/health" || echo "000")
if [[ "$STATUS" == "200" ]]; then
  pass "/health retorno HTTP 200"
else
  fail "/health retorno HTTP ${STATUS}"
fi

# Test 2: /users retorna array
log "Test 2: /users"
RESPONSE=$(curl -sf "${API_URL}/users" 2>/dev/null || echo "")
if echo "$RESPONSE" | jq -e '. | type == "array"' > /dev/null 2>&1; then
  pass "/users retorno un array JSON"
else
  fail "/users no retorno un array JSON valido"
fi

# Test 3: POST /users
log "Test 3: POST /users"
NEW_USER=$(curl -sf -X POST \
  -H "Content-Type: application/json" \
  -d '{"name": "smoke-test", "email": "smoke@test.local"}' \
  "${API_URL}/users" 2>/dev/null || echo "")
if echo "$NEW_USER" | jq -e '.id' > /dev/null 2>&1; then
  pass "POST /users retorno un objeto con id"
else
  fail "POST /users no retorno un objeto con id"
fi

# Resultado final
log "---"
if (( FAILURES == 0 )); then
  log "Todos los smoke tests pasaron."
  exit 0
else
  log "${FAILURES} smoke test(s) fallaron. Ver arriba."
  exit 1
fi
```

Uso en CI:

```yaml
- name: Smoke tests post-deploy
  run: bash smoke-test.sh
  env:
    API_URL: ${{ secrets.PRODUCTION_API_URL }}
```

Si el script retorna exit code 1 (hubo failures), el pipeline falla y el deploy es marcado como fallido.

---

## Patrones de curl en automatizacion: resumen

| Patron | Comando | Cuando usarlo |
|--------|---------|---------------|
| Solo status code | `curl -sf -o /dev/null -w "%{http_code}" URL` | Smoke tests, health checks |
| Solo body JSON | `curl -sf URL` | Parsear respuesta con jq |
| Con timeout | `curl --max-time 10 URL` | Siempre en CI/automatizacion |
| Con retry | `curl --retry 3 --retry-delay 2 URL` | Endpoints con downtime intermitente |
| Silencioso en error | `curl URL 2>/dev/null \|\| true` | Cuando el error es esperado/ignorable |
| Con verbose a archivo | `curl -v URL 2> debug.log` | Debugging de CI |

---

## Semana completa terminada

Has completado la teoria de la semana 10. Ahora viene lo mas importante: construir `api-toolkit`.

[→ Practicas: las 4 etapas del proyecto](../2-practicas/README.md)
