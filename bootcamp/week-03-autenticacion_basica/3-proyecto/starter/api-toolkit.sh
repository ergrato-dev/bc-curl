#!/usr/bin/env bash
#
# api-toolkit.sh — Capa 3 de api-toolkit (Semana 03): las credenciales
#
# La Semana 02 dejo los cuatro verbos funcionando contra una API abierta. Esta
# capa le anade la parte que hace falta para hablar con una API real: la
# credencial. Y la anade con una regla que no se negocia — el secreto NUNCA
# aparece en la linea de comandos de ningun proceso.
#
# Uso:
#   ./api-toolkit.sh [--dry-run] <subcomando> ENDPOINT [DATOS]
#
# Subcomandos:
#   get    ENDPOINT           Lee un recurso
#   post   ENDPOINT DATOS     Crea un recurso con el cuerpo JSON DATOS
#   put    ENDPOINT DATOS     Reemplaza un recurso entero
#   delete ENDPOINT           Elimina un recurso
#
# Flags globales:
#   --dry-run   Imprime el comando curl que se habria ejecutado, y termina.
#               La credencial sale REDACTADA: lo que imprime acaba en un log
#   -h, --help  Esta ayuda
#
# Variables de entorno:
#   BASE_URL        Raiz de la API. Por defecto http://localhost:8080
#   AUTH_MODE       none | basic | bearer | apikey. Por defecto none
#   API_USER        Usuario, con AUTH_MODE=basic
#   API_PASSWORD    Password, con AUTH_MODE=basic
#   API_TOKEN       Token, con AUTH_MODE=bearer
#   API_KEY         Clave, con AUTH_MODE=apikey
#   API_KEY_HEADER  Header donde viaja la clave. Por defecto X-API-Key
#   BC_CURL_FILE    Archivo de credenciales. Por defecto ~/.bc-curl
#
# Las variables de entorno mandan sobre el archivo. Si una no esta en el
# entorno, se busca en BC_CURL_FILE, que tiene que tener permisos 600.
#
# Ejemplos:
#   AUTH_MODE=basic API_USER=user API_PASSWORD=password \
#     ./api-toolkit.sh get /basic-auth/user/password
#   AUTH_MODE=bearer ./api-toolkit.sh get /bearer          # token del archivo
#   ./api-toolkit.sh --dry-run get /bearer
#
# Codigos de salida:
#   0   la API respondio 2xx o 3xx
#   1   error de uso, o la API respondio un 4xx/5xx que no es de credencial
#   77  la API respondio 401 o 403 (EX_NOPERM). Reintentar con la misma
#       credencial no va a cambiar nada: hay que renovarla o pedir permisos
#
# Este archivo es el punto de partida, no la solucion. Cada TODO es un hueco que
# tienes que rellenar. Cuando no quede ninguno, ./scripts/verificar-semana.sh 03
# deberia pasar las diecisiete comprobaciones.

set -euo pipefail

# --- Configuracion ----------------------------------------------------------

BASE_URL="${BASE_URL:-http://localhost:8080}"
AUTH_MODE="${AUTH_MODE:-none}"
API_KEY_HEADER="${API_KEY_HEADER:-X-API-Key}"
BC_CURL_FILE="${BC_CURL_FILE:-${HOME}/.bc-curl}"

# Segundos maximos por peticion. Sin esto, un servidor colgado cuelga el script.
readonly MAX_TIME=10

# Lo que se imprime en lugar del secreto cuando algo tiene que salir por
# pantalla. Un valor fijo: si dependiera del secreto, filtraria su longitud.
readonly REDACTADO='<REDACTADO>'

# Archivo temporal con las opciones de curl que llevan el secreto. Se crea en
# construir_config() y se borra siempre, incluso si el script muere.
CONFIG_CURL=""

limpiar() {
  [ -n "$CONFIG_CURL" ] && rm -f "$CONFIG_CURL"
  return 0
}
trap limpiar EXIT

# --- Utilidades -------------------------------------------------------------

uso() {
  sed -n '3,55p' "${BASH_SOURCE[0]}" | sed 's|^# \?||'
}

# error MENSAJE
#
# Escribe en stderr y sale con 1. Los mensajes NUNCA van a stdout: ahi un
# `... | jq` se los tragaria como si fueran datos.
error() {
  echo "error: $*" >&2
  exit 1
}

# --- Credenciales -----------------------------------------------------------

# permisos_de ARCHIVO
#
# Imprime los permisos en octal (p. ej. 600). GNU y BSD usan flags distintos
# para lo mismo, asi que se prueban los dos.
permisos_de() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null
}

# cargar_credenciales
#
# Rellena las variables que falten leyendolas de BC_CURL_FILE. Lo que ya venga
# del entorno manda: asi un pipeline de CI puede inyectar el token sin tocar
# ningun archivo.
cargar_credenciales() {
  API_USER="${API_USER:-}"
  API_PASSWORD="${API_PASSWORD:-}"
  API_TOKEN="${API_TOKEN:-}"
  API_KEY="${API_KEY:-}"

  [ -f "$BC_CURL_FILE" ] || return 0

  # TODO 1: antes de leer nada, comprueba los permisos del archivo.
  #   Un archivo de credenciales legible por todo el mundo no es un archivo de
  #   credenciales. Si `permisos_de "$BC_CURL_FILE"` no devuelve 600 (ni 400),
  #   falla con `error` explicando como se arregla:
  #       chmod 600 "$BC_CURL_FILE"
  #   Que falle, y no que avise y siga: un aviso en stderr no lo lee nadie.

  # Formato del archivo: CLAVE=valor, una por linea. Se leen solo las cuatro
  # claves conocidas, y solo si la variable sigue vacia. `source` no se usa a
  # proposito: ejecutaria cualquier cosa que hubiera dentro.
  local clave valor
  while IFS='=' read -r clave valor; do
    case "$clave" in
      API_USER)     if [ -z "$API_USER" ];     then API_USER="$valor";     fi ;;
      API_PASSWORD) if [ -z "$API_PASSWORD" ]; then API_PASSWORD="$valor"; fi ;;
      API_TOKEN)    if [ -z "$API_TOKEN" ];    then API_TOKEN="$valor";    fi ;;
      API_KEY)      if [ -z "$API_KEY" ];      then API_KEY="$valor";      fi ;;
      *) ;;
    esac
  done < <(grep -E '^[A-Z_]+=' "$BC_CURL_FILE" || true)
}

# construir_config
#
# Escribe en un archivo temporal las opciones de curl que llevan el secreto, y
# deja su ruta en CONFIG_CURL. Este archivo es el corazon de la semana: es lo
# que permite pasarle la credencial a curl SIN que aparezca en su argv.
#
# Formato de un archivo de --config: una opcion larga por linea, sin los dos
# guiones, con el valor entre comillas.
#     user = "usuario:password"
#     header = "Authorization: Bearer el-token"
# escapar_config TEXTO
#
# Escapa \ y " para poder meter TEXTO entre comillas dobles en un archivo de
# --config. Sin esto, una password con comillas rompe la linea, y una con \
# se interpreta como un escape (\t, \n...) y llega cambiada al servidor.
escapar_config() {
  local v="${1//\\/\\\\}"
  printf '%s' "${v//\"/\\\"}"
}

construir_config() {
  [ "$AUTH_MODE" = none ] && return 0

  # umask 077 hace que el archivo nazca ya con permisos 600. Ponerlo con un
  # chmod despues deja una ventana, corta pero real, en la que es legible.
  local umask_previa
  umask_previa="$(umask)"
  umask 077
  CONFIG_CURL="$(mktemp "${TMPDIR:-/tmp}/api-toolkit.XXXXXX")"
  umask "$umask_previa"

  # Un salto de linea no se puede escapar: cerraria la opcion y lo que viniera
  # detras se leeria como OTRA opcion de curl. Se rechaza.
  case "${API_USER}${API_PASSWORD}${API_TOKEN}${API_KEY}" in
    *$'\n'*|*$'\r'*) error "la credencial contiene un salto de linea" ;;
  esac

  case "$AUTH_MODE" in
    basic)
      [ -n "$API_USER" ] && [ -n "$API_PASSWORD" ] \
        || error "AUTH_MODE=basic necesita API_USER y API_PASSWORD"
      # TODO 2a: escribe en "$CONFIG_CURL" la linea de Basic Auth.
      #   Es la opcion larga `user`, con el valor "usuario:password".
      #   Pasa cada valor por escapar_config: una password con " o \ romperia
      #   la linea. Pista:
      #     printf 'user = "%s:%s"\n' "$(escapar_config "$API_USER")" \
      #       "$(escapar_config "$API_PASSWORD")" > "$CONFIG_CURL"
      ;;
    bearer)
      [ -n "$API_TOKEN" ] || error "AUTH_MODE=bearer necesita API_TOKEN"
      # TODO 2b: escribe la linea del header Authorization con el token.
      #   La opcion larga es `header`, y el valor completo es
      #   "Authorization: Bearer <el token>". El token, por escapar_config.
      ;;
    apikey)
      [ -n "$API_KEY" ] || error "AUTH_MODE=apikey necesita API_KEY"
      # TODO 2c: escribe la linea del header de API key.
      #   El nombre del header esta en $API_KEY_HEADER, el valor en $API_KEY.
      #   Los dos, por escapar_config.
      #   Va en un header y NO en la query string: la query string se queda en
      #   los logs del servidor, en el proxy y en el Referer.
      ;;
    *)
      error "AUTH_MODE desconocido: $AUTH_MODE (usa none, basic, bearer o apikey)"
      ;;
  esac
}

# --- Construccion de la peticion --------------------------------------------

metodo_de() {
  case "$1" in
    get)    echo GET ;;
    post)   echo POST ;;
    put)    echo PUT ;;
    delete) echo DELETE ;;
    *)      return 1 ;;
  esac
}

# construir_args METODO ENDPOINT [DATOS]
#
# Deja en ARGS_CURL todos los argumentos de curl menos el ejecutable. Aqui NO
# entra ningun secreto: lo que lleva el secreto es el --config.
construir_args() {
  local metodo="$1" endpoint="$2" datos="${3:-}"

  ARGS_CURL=(
    --max-time "$MAX_TIME"
    --request "$metodo"
    --silent --show-error
    --write-out '\n%{http_code}'
  )

  # La credencial entra por referencia a un archivo, no por valor.
  [ -n "$CONFIG_CURL" ] && ARGS_CURL+=(--config "$CONFIG_CURL")

  if [ -n "$datos" ]; then
    ARGS_CURL+=(
      --header 'Content-Type: application/json'
      --header 'Accept: application/json'
      --data-raw "$datos"
    )
  fi

  ARGS_CURL+=("${BASE_URL}${endpoint}")
}

# --- Ejecucion --------------------------------------------------------------

# imprimir_dry_run
#
# Imprime el comando curl que se habria ejecutado. Lo que se imprime aqui acaba
# copiado en un ticket, pegado en un chat o escrito en el log de un CI: la
# credencial no puede salir.
imprimir_dry_run() {
  printf 'curl'
  printf ' %q' "${ARGS_CURL[@]}"
  printf '\n'

  if [ "$AUTH_MODE" != none ]; then
    # TODO 3: esta linea dice que hay una credencial, pero no cual es el modo.
    #   Sustituyela por una que imprima tambien $AUTH_MODE, dejando $REDACTADO
    #   en el sitio del valor. Algo como:
    #       # AUTH_MODE=bearer, credencial: <REDACTADO>
    #   Lo que NO puedes imprimir, ni entero ni a trozos, es $API_TOKEN,
    #   $API_PASSWORD ni $API_KEY: los cuatro primeros caracteres de un token
    #   siguen siendo cuatro caracteres menos que adivinar.
    printf '# credencial: %s\n' "$REDACTADO"
  fi
}

# ejecutar
#
# Lanza la peticion, imprime el cuerpo y traduce el codigo HTTP a un codigo de
# salida util para quien llame al script.
ejecutar() {
  local salida codigo cuerpo

  # --write-out pega '\n<codigo>' al final, asi que la ultima linea es el codigo
  # y el resto es el cuerpo: los dos con UNA sola peticion.
  salida="$(curl "${ARGS_CURL[@]}")"

  codigo="${salida##*$'\n'}"
  cuerpo="${salida%$'\n'*}"

  # El cuerpo va a stdout aunque haya fallado: en un 401 es donde la API suele
  # decir si el token caduco o si nunca fue valido.
  printf '%s\n' "$cuerpo"

  # TODO 4: traduce el codigo HTTP al codigo de salida.
  #   - 401 y 403     -> 77. Son los dos "no puedes": el primero dice que la
  #                     credencial no vale, el segundo que vale pero no llega.
  #                     Ninguno de los dos se arregla reintentando igual.
  #   - menor que 400 -> 0
  #   - todo lo demas -> 1. Incluido el 000, que es lo que pone curl cuando no
  #                     hubo respuesta (DNS, puerto cerrado, timeout) y que ni
  #                     siquiera es un numero comparable.
  [ "$codigo" = "no-implementado" ]
}

# --- Programa principal -----------------------------------------------------

main() {
  local dry_run=0

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run) dry_run=1; shift ;;
      -h|--help) uso; exit 0 ;;
      --)        shift; break ;;
      -*)        error "flag desconocido: $1" ;;
      *)         break ;;
    esac
  done

  [ "$#" -ge 2 ] || { uso >&2; error "faltan argumentos"; }

  local subcomando="$1" endpoint="$2" datos="${3:-}"
  local metodo

  metodo="$(metodo_de "$subcomando")" \
    || error "subcomando desconocido: $subcomando"

  case "$subcomando" in
    post|put) [ -n "$datos" ] || error "$subcomando necesita un cuerpo" ;;
    *) ;;
  esac

  [[ "$endpoint" == /* ]] \
    || error "el endpoint tiene que empezar por /: $endpoint"

  cargar_credenciales
  construir_config
  construir_args "$metodo" "$endpoint" "$datos"

  if [ "$dry_run" -eq 1 ]; then
    imprimir_dry_run
    exit 0
  fi

  ejecutar
}

main "$@"
