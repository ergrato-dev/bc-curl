#!/usr/bin/env bash
#
# start.sh — levanta el laboratorio del bootcamp y exporta la CA.
#
# Uso:
#   ./scripts/start.sh
#
# Deja tres servicios escuchando en localhost y el certificado raiz de la CA
# interna de Caddy en docs/lab-ca.pem, que es lo que se pasa a --cacert.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

# Si hay .env, manda: los puertos de las comprobaciones tienen que ser los
# mismos que los que publica el compose.
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

HTTPBIN_PORT="${HTTPBIN_PORT:-8080}"
OAUTH_PORT="${OAUTH_PORT:-8081}"
TLS_PORT="${TLS_PORT:-8443}"
MTLS_PORT="${MTLS_PORT:-8444}"

CA_DESTINO="docs/lab-ca.pem"
CA_ORIGEN="/data/caddy/pki/authorities/local/root.crt"
ESPERA_MAXIMA=60

rojo()  { printf '\033[0;31m%s\033[0m\n' "$*"; }
verde() { printf '\033[0;32m%s\033[0m\n' "$*"; }
gris()  { printf '\033[0;90m%s\033[0m\n' "$*"; }

# --- Dependencias ----------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  rojo "Falta docker. Instalalo antes de seguir: https://docs.docker.com/engine/install/"
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  rojo "Falta el plugin 'docker compose' (v2). 'docker-compose' v1 no sirve."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  rojo "El demonio de Docker no responde. Arrancalo y vuelve a intentarlo."
  exit 1
fi

# --- Puertos ocupados ------------------------------------------------------
# Avisar antes es mas barato que descifrar el error de bind de Docker.
for puerto in "$HTTPBIN_PORT" "$OAUTH_PORT" "$TLS_PORT" "$MTLS_PORT"; do
  if (exec 3<>"/dev/tcp/127.0.0.1/$puerto") 2>/dev/null; then
    exec 3>&-
    rojo "El puerto $puerto ya esta ocupado."
    gris "Libéralo, o cambialo en tu .env (copia .env.example si no lo tienes)."
    exit 1
  fi
done

# --- Arranque --------------------------------------------------------------
echo "Levantando el laboratorio..."
docker compose up -d

# --- Espera activa ---------------------------------------------------------
# `up -d` vuelve en cuanto los contenedores arrancan, no cuando el servicio
# dentro esta listo. Sin esta espera el primer comando del alumno falla.
echo -n "Esperando a que respondan los servicios"
transcurrido=0
while true; do
  httpbin_ok=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 \
    "http://localhost:${HTTPBIN_PORT}/get" || true)
  oauth_ok=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 \
    "http://localhost:${OAUTH_PORT}/default/.well-known/openid-configuration" || true)

  if [[ "$httpbin_ok" == "200" && "$oauth_ok" == "200" ]]; then
    echo
    break
  fi

  if (( transcurrido >= ESPERA_MAXIMA )); then
    echo
    rojo "Los servicios no respondieron en ${ESPERA_MAXIMA}s."
    gris "Mira que paso con: docker compose logs"
    exit 1
  fi

  echo -n "."
  sleep 2
  transcurrido=$(( transcurrido + 2 ))
done

# --- Exportar la CA --------------------------------------------------------
# Caddy genera su CA la primera vez que arranca. Se exporta a docs/ para que
# el alumno la pase a --cacert en vez de aprender a usar -k.
mkdir -p docs
if docker compose exec -T tls cat "$CA_ORIGEN" > "$CA_DESTINO" 2>/dev/null \
   && [[ -s "$CA_DESTINO" ]]; then
  chmod 644 "$CA_DESTINO"
  verde "CA del laboratorio exportada a $CA_DESTINO"
else
  rm -f "$CA_DESTINO"
  rojo "No se pudo exportar la CA desde el contenedor tls."
  gris "Reintentalo en unos segundos: el certificado puede tardar en emitirse."
  exit 1
fi

# --- Resumen ---------------------------------------------------------------
cat <<RESUMEN

$(verde "Laboratorio listo.")

  httpbin        http://localhost:${HTTPBIN_PORT}          metodos, status, auth, cookies
  OAuth2         http://localhost:${OAUTH_PORT}/default  tokens de verdad, firmados
  TLS            https://localhost:${TLS_PORT}         HTTP/2 y HTTP/3, CA propia
  mTLS           https://localhost:${MTLS_PORT}         exige certificado de cliente

Pruebalo:

  curl -s -o /dev/null -w '%{http_code}\\n' http://localhost:${HTTPBIN_PORT}/get
  curl --cacert $CA_DESTINO -s -o /dev/null -w '%{http_version}\\n' https://localhost:${TLS_PORT}/get

Sin --cacert el segundo falla con el codigo 60. Eso es correcto: es el punto
de partida de la Semana 05.

Para pararlo:  ./scripts/stop.sh
RESUMEN
