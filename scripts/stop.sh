#!/usr/bin/env bash
#
# stop.sh — para el laboratorio del bootcamp.
#
# Uso:
#   ./scripts/stop.sh              para los contenedores, conserva la CA
#   ./scripts/stop.sh --limpiar    ademas borra los volumenes y la CA
#
# Sin --limpiar, la CA de Caddy sobrevive: al volver a arrancar el
# docs/lab-ca.pem que ya tienes sigue siendo valido.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

LIMPIAR=false
case "${1:-}" in
  --limpiar) LIMPIAR=true ;;
  "")        ;;
  *)         echo "Uso: $0 [--limpiar]" >&2; exit 1 ;;
esac

if [[ "$LIMPIAR" == true ]]; then
  # Destructivo: se pregunta antes. Borrar los volumenes regenera la CA, y
  # cualquier docs/lab-ca.pem exportado antes deja de valer.
  printf '\033[1;33m%s\033[0m\n' "Esto borra los volumenes del laboratorio y la CA exportada."
  printf '%s' "La proxima vez que arranques se generara una CA nueva. Continuar? [s/N] "
  read -r respuesta
  if [[ "${respuesta,,}" != "s" ]]; then
    echo "Cancelado."
    exit 0
  fi
  docker compose down -v
  rm -f docs/lab-ca.pem
  printf '\033[0;32m%s\033[0m\n' "Laboratorio parado y limpiado."
else
  docker compose down
  printf '\033[0;32m%s\033[0m\n' "Laboratorio parado. Los volumenes y docs/lab-ca.pem siguen ahi."
fi
