#!/usr/bin/env bash
#
# install.sh — instala api-toolkit como un comando mas
#
# Uso:
#   ./install.sh               Copia api-toolkit.sh a PREFIX/bin/api-toolkit
#   ./install.sh uninstall     Lo borra. Tu configuracion (BC_CURL_FILE) y tu
#                              sesion OAuth2 se quedan: son tuyas, no del programa
#
# Variables de entorno:
#   PREFIX   Donde instalar. Por defecto ~/.local, que no necesita sudo.
#            Con PREFIX=/usr/local hace falta: sudo PREFIX=/usr/local ./install.sh
#
# Codigos de salida:
#   0   instalado (o desinstalado)
#   1   error de uso, api-toolkit.sh no esta al lado, o la copia instalada no
#       arranca

set -euo pipefail

PREFIX="${PREFIX:-${HOME}/.local}"
# shellcheck disable=SC2034  # las usaran instalar y desinstalar
DESTINO="${PREFIX}/bin/api-toolkit"

# El origen se busca al lado de este script, no en el directorio actual:
# ./install.sh y ../otro/install.sh tienen que instalar lo mismo.
# shellcheck disable=SC2034
ORIGEN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/api-toolkit.sh"

error() {
  echo "error: $*" >&2
  exit 1
}

instalar() {
  # TODO 5: si ORIGEN no existe, error. Crea PREFIX/bin con install -d y
  # copia ORIGEN a DESTINO con install -m 755. Comprueba que DESTINO arranca
  # (DESTINO --version) y dilo por stdout. Si PREFIX/bin no esta en el PATH,
  # avisa por stderr con la linea export que hay que anadir.
  error "instalar todavia no esta hecho"
}

desinstalar() {
  # TODO 5 (sigue): borra DESTINO, y solo DESTINO, y dilo por stdout.
  error "desinstalar todavia no esta hecho"
}

case "${1:-install}" in
  install)   instalar ;;
  uninstall) desinstalar ;;
  *)         error "uso: $0 [install|uninstall]" ;;
esac
