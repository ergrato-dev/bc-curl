#!/usr/bin/env bash
#
# api-toolkit.sh — Capa 5 de api-toolkit (Semana 05): red hostil
#
# La Semana 04 dejo el toolkit moviendo archivos. Esta capa lo prepara para la
# red de verdad: servidores con una CA que no es publica, APIs que exigen
# certificado de cliente, sesiones con cookies, redirects que no hay que seguir
# a ciegas, conexiones que no responden y errores que se arreglan solos al
# segundo intento.
#
# Uso:
#   ./api-toolkit.sh [flags] <subcomando> ENDPOINT [ARGUMENTO]
#
# Subcomandos:
#   get      ENDPOINT           Lee un recurso
#   post     ENDPOINT DATOS     Crea un recurso con el cuerpo JSON DATOS
#   put      ENDPOINT DATOS     Reemplaza un recurso entero
#   delete   ENDPOINT           Elimina un recurso
#   download ENDPOINT DESTINO   Descarga a DESTINO, pasando por DESTINO.part
#   upload   ENDPOINT ARCHIVO   Sube ARCHIVO como multipart/form-data
#
# Flags globales:
#   --dry-run      Imprime el comando curl que se habria ejecutado, y termina.
#                  La credencial sale REDACTADA: lo que imprime acaba en un log
#   --resume       Con download: continua DESTINO.part en vez de empezar de cero
#   --sha256 HASH  Con download: falla si el archivo no tiene ese SHA-256
#   -h, --help     Esta ayuda
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
#   UPLOAD_FIELD    Campo del formulario donde viaja el archivo. Por defecto file
#   API_CACERT      CA (PEM) con la que validar el servidor, si no es publica
#   API_CLIENT_CERT Certificado de cliente (PEM), para APIs con mTLS
#   API_CLIENT_KEY  Su clave privada (PEM). Tiene que tener permisos 600
#   COOKIE_JAR      Archivo donde guardar y leer las cookies entre llamadas.
#                   Se crea con permisos 600; si existe, tiene que tenerlos
#
# Las variables de entorno mandan sobre el archivo. Si una no esta en el
# entorno, se busca en BC_CURL_FILE, que tiene que tener permisos 600.
#
# Ejemplos:
#   ./api-toolkit.sh download /range/1000 datos.bin
#   ./api-toolkit.sh --resume download /range/1000 datos.bin
#   ./api-toolkit.sh --sha256 2ac1...35bd download /range/100 datos.bin
#   ./api-toolkit.sh upload /post informe.pdf
#   BASE_URL=https://localhost:8443 API_CACERT=docs/lab-ca.pem ./api-toolkit.sh get /get
#   COOKIE_JAR=~/.bc-curl-cookies ./api-toolkit.sh get '/cookies/set?sesion=1'
#
# Codigos de salida:
#   0   la API respondio 2xx o 3xx (y en download, el archivo esta completo)
#   1   error de uso, archivo inexistente, hash que no coincide, o la API
#       respondio un 4xx/5xx que no es de credencial
#   75  download cortado a medias (EX_TEMPFAIL). DESTINO.part se conserva:
#       repite con --resume y continua donde se quedo
#   77  la API respondio 401 o 403 (EX_NOPERM)
#   69  no hubo respuesta HTTP: DNS, conexion, timeout, TLS o demasiados
#       redirects (EX_UNAVAILABLE). El mensaje dice cual
#
# Este archivo es el punto de partida, no la solucion. Cada TODO es un hueco que
# tienes que rellenar. Cuando no quede ninguno, ./scripts/verificar-semana.sh 05
# deberia pasar las veintiuna comprobaciones.

set -euo pipefail

# --- Configuracion ----------------------------------------------------------

BASE_URL="${BASE_URL:-http://localhost:8080}"
AUTH_MODE="${AUTH_MODE:-none}"
API_KEY_HEADER="${API_KEY_HEADER:-X-API-Key}"
BC_CURL_FILE="${BC_CURL_FILE:-${HOME}/.bc-curl}"
UPLOAD_FIELD="${UPLOAD_FIELD:-file}"
API_CACERT="${API_CACERT:-}"
API_CLIENT_CERT="${API_CLIENT_CERT:-}"
API_CLIENT_KEY="${API_CLIENT_KEY:-}"
COOKIE_JAR="${COOKIE_JAR:-}"

# Segundos maximos por peticion. Sin esto, un servidor colgado cuelga el script.
readonly MAX_TIME=10

# Una descarga grande no cabe en 10 segundos, pero tampoco puede quedarse
# colgada para siempre. Dos limites distintos: un techo absoluto, y un minimo
# de velocidad — si baja de 1 KB/s durante 30 s, la conexion esta muerta
# aunque no se haya cerrado.
readonly MAX_TIME_DESCARGA=600
readonly VELOCIDAD_MINIMA=1024
readonly TIEMPO_VELOCIDAD=30

# Cuanto esperar a que el servidor acepte la conexion. Separado de MAX_TIME:
# un host caido se detecta en 5 s, no en los 10 (o 600) de la peticion entera.
readonly CONNECT_TIMEOUT=5
# Una cadena legitima rara vez pasa de 2 o 3 saltos. 5 da margen y corta bucles.
readonly MAX_REDIRECTS=5
# Reintentos solo para metodos idempotentes; RETRY_MAX_TIME acota el total.
readonly REINTENTOS=3
readonly RETRY_MAX_TIME=30

readonly REDACTADO='<REDACTADO>'

CONFIG_CURL=""
RED_CURL=()

limpiar() {
  [ -n "$CONFIG_CURL" ] && rm -f "$CONFIG_CURL"
  return 0
}
trap limpiar EXIT

# --- Utilidades -------------------------------------------------------------

uso() {
  awk 'NR > 2 && /^#/ { sub(/^# ?/, ""); print; next } NR > 2 { exit }' "${BASH_SOURCE[0]}"
}

error() {
  echo "error: $*" >&2
  exit 1
}

# --- Credenciales (capa 3) --------------------------------------------------

permisos_de() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null
}

cargar_credenciales() {
  API_USER="${API_USER:-}"
  API_PASSWORD="${API_PASSWORD:-}"
  API_TOKEN="${API_TOKEN:-}"
  API_KEY="${API_KEY:-}"

  [ -f "$BC_CURL_FILE" ] || return 0

  case "$(permisos_de "$BC_CURL_FILE")" in
    600|400) ;;
    *) error "$BC_CURL_FILE es legible por otros usuarios. Arreglalo con: chmod 600 \"$BC_CURL_FILE\"" ;;
  esac

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
      printf 'user = "%s:%s"\n' "$(escapar_config "$API_USER")" "$(escapar_config "$API_PASSWORD")" > "$CONFIG_CURL"
      ;;
    bearer)
      [ -n "$API_TOKEN" ] || error "AUTH_MODE=bearer necesita API_TOKEN"
      printf 'header = "Authorization: Bearer %s"\n' "$(escapar_config "$API_TOKEN")" > "$CONFIG_CURL"
      ;;
    apikey)
      [ -n "$API_KEY" ] || error "AUTH_MODE=apikey necesita API_KEY"
      printf 'header = "%s: %s"\n' "$(escapar_config "$API_KEY_HEADER")" "$(escapar_config "$API_KEY")" > "$CONFIG_CURL"
      ;;
    *)
      error "AUTH_MODE desconocido: $AUTH_MODE (usa none, basic, bearer o apikey)"
      ;;
  esac
}

# --- Red ---------------------------------------------------------------------

# exigir_600 ARCHIVO
#
# Falla si ARCHIVO es legible por otros usuarios. Para lo que da acceso: la
# clave privada del certificado de cliente y el tarro de cookies de sesion.
exigir_600() {
  case "$(permisos_de "$1")" in
    600|400) ;;
    *) error "$1 es legible por otros usuarios. Arreglalo con: chmod 600 \"$1\"" ;;
  esac
}

# construir_red METODO
#
# Rellena RED_CURL con las opciones de red, comunes a todas las peticiones:
# confianza TLS, certificado de cliente, cookies, redirects y reintentos.
construir_red() {
  local metodo="$1"

  RED_CURL=(--connect-timeout "$CONNECT_TIMEOUT")

  # TODO 1: si API_CACERT tiene valor, comprueba que el archivo se puede leer
  #   ([ -r ]) y, si no, llama a `error`: es un error de uso y curl no tiene
  #   que llegar a ejecutarse. Si se puede leer, anade --cacert "$API_CACERT"
  #   a RED_CURL.

  # TODO 2: certificado de cliente (mTLS). Si API_CLIENT_CERT o
  #   API_CLIENT_KEY tienen valor:
  #     - hacen falta las dos; si falta una, `error`.
  #     - las dos tienen que poder leerse.
  #     - la clave privada tiene que tener permisos 600: usa exigir_600.
  #   Despues, anade --cert "$API_CLIENT_CERT" --key "$API_CLIENT_KEY".

  # TODO 3: tarro de cookies. Si COOKIE_JAR tiene valor:
  #     - si el archivo no existe, crealo vacio con permisos 600. curl lo
  #       crearia con 644, y una cookie de sesion vale lo que una password.
  #       Pista: (umask 077 && : > "$COOKIE_JAR")
  #     - si ya existe, exige 600 con exigir_600.
  #     - anade --cookie Y --cookie-jar, los dos sobre COOKIE_JAR: uno lee
  #       las cookies guardadas, el otro guarda las nuevas al terminar.

  # TODO 4: redirects. Anade --location --max-redirs "$MAX_REDIRECTS" SOLO si
  #   el metodo es GET y AUTH_MODE no es apikey:
  #     - un POST que sigue un 301 o un 302 llega como GET y pierde el cuerpo.
  #     - curl quita el Authorization al saltar a otro host, pero no un
  #       header propio como X-API-Key: la clave llegaria al host nuevo.
  #   Y con --location, limita los protocolos del salto con --proto-redir:
  #   "=https" si BASE_URL empieza por https://, "=http,https" si no. Entre
  #   comillas: sin ellas, zsh y shellcheck interpretan el =.

  # TODO 5: tal como esta, se reintenta TODO, tambien un POST. Y un POST que
  #   dio timeout puede haber creado ya el recurso: repetirlo crea otro.
  #   Limita los reintentos a GET, PUT y DELETE, que se pueden repetir sin
  #   efectos dobles. Pista: un case sobre "$metodo".
  RED_CURL+=(--retry "$REINTENTOS" --retry-connrefused
             --retry-max-time "$RETRY_MAX_TIME")
}

# fallo_de_red CODIGO_CURL
#
# curl salio sin respuesta HTTP. Explica por que y sale con 69.
fallo_de_red() {
  local pista
  case "$1" in
    6)        pista="no se resuelve el nombre del host" ;;
    7)        pista="el servidor rechaza la conexion" ;;
    28)       pista="timeout: el servidor no respondio a tiempo" ;;
    35|56)    pista="el handshake TLS fallo (¿el servidor pide certificado de cliente?)" ;;
    47)       pista="demasiados redirects (maximo $MAX_REDIRECTS)" ;;
    1)        pista="protocolo no permitido (¿un redirect de https a http?)" ;;
    58)       pista="curl no pudo usar el certificado de cliente" ;;
    60)       pista="el certificado del servidor no valida: ¿falta API_CACERT?" ;;
    *)        pista="curl salio con $1" ;;
  esac
  echo "error: $pista (curl: $1)" >&2
  exit 69
}

# --- Construccion de la peticion --------------------------------------------

metodo_de() {
  case "$1" in
    get|download) echo GET ;;
    post|upload)  echo POST ;;
    put)          echo PUT ;;
    delete)       echo DELETE ;;
    *)            return 1 ;;
  esac
}

# construir_args METODO ENDPOINT [DATOS]
#
# Los argumentos de las peticiones que devuelven un cuerpo de texto: los cuatro
# verbos y upload. Aqui NO entra ningun secreto: lo lleva el --config.
construir_args() {
  local metodo="$1" endpoint="$2" datos="${3:-}"

  ARGS_CURL=(
    --max-time "$MAX_TIME"
    --request "$metodo"
    --silent --show-error
    --write-out '\n%{http_code}'
  )

  [ -n "$CONFIG_CURL" ] && ARGS_CURL+=(--config "$CONFIG_CURL")

  if [ -n "$datos" ]; then
    ARGS_CURL+=(
      --header 'Content-Type: application/json'
      --header 'Accept: application/json'
      --data-raw "$datos"
    )
  fi

  ARGS_CURL+=("${RED_CURL[@]}" "${BASE_URL}${endpoint}")
}

# construir_args_upload ENDPOINT ARCHIVO
#
# Como construir_args, pero el cuerpo es un formulario multipart con el archivo
# en el campo UPLOAD_FIELD.
construir_args_upload() {
  local endpoint="$1" archivo="$2"

  [ -f "$archivo" ] && [ -r "$archivo" ] \
    || error "no existe o no se puede leer: $archivo"

  ARGS_CURL=(
    --max-time "$MAX_TIME_DESCARGA"
    --silent --show-error
    --write-out '\n%{http_code}'
  )

  [ -n "$CONFIG_CURL" ] && ARGS_CURL+=(--config "$CONFIG_CURL")

  # Las comillas alrededor de la ruta no son decoracion: sin ellas, un nombre
  # como 'informe;type=x.pdf' se lee como una directiva de -F.
  # ponytail: una ruta que contenga comillas dobles sigue rompiendo; escaparlas
  # con \" si algun dia hace falta subir algo asi.
  ARGS_CURL+=(--form "${UPLOAD_FIELD}=@\"${archivo}\"")

  ARGS_CURL+=("${RED_CURL[@]}" "${BASE_URL}${endpoint}")
}

# construir_args_descarga ENDPOINT PARTE REANUDAR
#
# Los argumentos de download. El cuerpo no pasa por bash: va directo a PARTE.
construir_args_descarga() {
  local endpoint="$1" parte="$2" reanudar="$3"

  ARGS_CURL=(
    --max-time "$MAX_TIME_DESCARGA"
    --speed-limit "$VELOCIDAD_MINIMA" --speed-time "$TIEMPO_VELOCIDAD"
    --silent --show-error
    --fail
    --output "$parte"
    --write-out '%{http_code}'
  )

  [ -n "$CONFIG_CURL" ] && ARGS_CURL+=(--config "$CONFIG_CURL")

  [ "$reanudar" -eq 1 ] && ARGS_CURL+=(--continue-at -)

  ARGS_CURL+=("${RED_CURL[@]}" "${BASE_URL}${endpoint}")
}

# --- Ejecucion --------------------------------------------------------------

imprimir_dry_run() {
  printf 'curl'
  printf ' %q' "${ARGS_CURL[@]}"
  printf '\n'

  if [ "$AUTH_MODE" != none ]; then
    printf '# AUTH_MODE=%s, credencial: %s\n' "$AUTH_MODE" "$REDACTADO"
  fi
}

# salir_por_codigo CODIGO_HTTP
#
# Traduce el codigo HTTP al codigo de salida del script.
salir_por_codigo() {
  case "$1" in
    401|403) exit 77 ;;
    [123]??) exit 0 ;;
    *)       exit 1 ;;
  esac
}

ejecutar() {
  local salida codigo cuerpo

  # TODO 6: si curl sale con un codigo distinto de 0, no hubo respuesta HTTP
  #   (DNS, conexion, TLS, redirects...). Captura ese codigo y pasaselo a
  #   fallo_de_red, que explica la causa y sale con 69. Con `set -e`, hay que
  #   capturarlo dentro de un if: mira como lo hace descargar().
  salida="$(curl "${ARGS_CURL[@]}")"

  codigo="${salida##*$'\n'}"
  cuerpo="${salida%$'\n'*}"

  printf '%s\n' "$cuerpo"

  salir_por_codigo "$codigo"
}

sha256_de() {
  { sha256sum "$1" 2>/dev/null || shasum -a 256 "$1"; } | cut -d' ' -f1
}

# tamano_remoto URL
#
# Imprime el Content-Length que anuncia el servidor, con un HEAD. Lleva el
# mismo --config que la descarga: si el recurso pide credencial, el HEAD tambien.
tamano_remoto() {
  local args=(--max-time "$MAX_TIME" --silent --head "${RED_CURL[@]}")
  [ -n "$CONFIG_CURL" ] && args+=(--config "$CONFIG_CURL")
  curl "${args[@]}" "$1" | tr -d '\r' \
    | awk 'tolower($1) == "content-length:" { print $2 }'
}

# descargar PARTE DESTINO REANUDAR HASH
#
# Lanza la descarga ya construida en ARGS_CURL. El archivo solo aparece con su
# nombre definitivo cuando esta completo y verificado: hasta entonces vive en
# PARTE. Quien mire DESTINO nunca ve una descarga a medias.
descargar() {
  local parte="$1" destino="$2" reanudar="$3" hash="$4"
  local codigo rc

  if codigo="$(curl "${ARGS_CURL[@]}")"; then rc=0; else rc=$?; fi

  if [ "$rc" -ne 0 ]; then
    if [ "$reanudar" -eq 1 ] && [ "$codigo" = 416 ]; then
      # 416 con --resume: el rango pedido no existe. O PARTE ya esta completo,
      # o es MAS GRANDE que el recurso (cambio y encogio). Se distingue por
      # el tamano: solo si coincide con el remoto se da por bueno.
      local remoto
      remoto="$(tamano_remoto "${ARGS_CURL[-1]}")"
      if [ "$(wc -c < "$parte" | tr -d ' ')" != "$remoto" ]; then
        rm -f "$parte"
        error "$parte no coincide con el tamano remoto ($remoto bytes): borrado, repite la descarga"
      fi
      echo "aviso: $parte ya estaba completo (416)" >&2
    elif [ "$codigo" = 000 ] || [[ "$codigo" == 2?? ]]; then
      echo "error: descarga cortada en $parte (curl salio con $rc). Repite con --resume" >&2
      exit 75
    else
      rm -f "$parte"
      echo "error: la API respondio $codigo" >&2
      salir_por_codigo "$codigo"
    fi
  fi

  if [ -n "$hash" ]; then
    local real
    real="$(sha256_de "$parte")"
    if [ "$real" != "$hash" ]; then
      rm -f "$parte"
      error "SHA-256 no coincide: esperado $hash, recibido $real"
    fi
  fi

  mv -f "$parte" "$destino"
  echo "$destino" >&2
}

# --- Programa principal -----------------------------------------------------

main() {
  local dry_run=0 reanudar=0 hash=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run) dry_run=1; shift ;;
      --resume)  reanudar=1; shift ;;
      --sha256)
        [ "$#" -ge 2 ] || error "--sha256 necesita un hash"
        hash="$(tr '[:upper:]' '[:lower:]' <<<"$2")"
        [[ "$hash" =~ ^[0-9a-f]{64}$ ]] \
          || error "--sha256 espera 64 caracteres hexadecimales"
        shift 2
        ;;
      -h|--help) uso; exit 0 ;;
      --)        shift; break ;;
      -*)        error "flag desconocido: $1" ;;
      *)         break ;;
    esac
  done

  [ "$#" -ge 2 ] || { uso >&2; error "faltan argumentos"; }

  local subcomando="$1" endpoint="$2" argumento="${3:-}"
  local metodo

  metodo="$(metodo_de "$subcomando")" \
    || error "subcomando desconocido: $subcomando"

  case "$subcomando" in
    post|put)        [ -n "$argumento" ] || error "$subcomando necesita un cuerpo" ;;
    download)        [ -n "$argumento" ] || error "download necesita un DESTINO" ;;
    upload)          [ -n "$argumento" ] || error "upload necesita un ARCHIVO" ;;
    *) ;;
  esac

  if [ "$subcomando" != download ] && { [ "$reanudar" -eq 1 ] || [ -n "$hash" ]; }; then
    error "--resume y --sha256 solo tienen sentido con download"
  fi

  [[ "$endpoint" == /* ]] \
    || error "el endpoint tiene que empezar por /: $endpoint"

  cargar_credenciales
  construir_config
  construir_red "$metodo"

  case "$subcomando" in
    download) construir_args_descarga "$endpoint" "${argumento}.part" "$reanudar" ;;
    upload)   construir_args_upload "$endpoint" "$argumento" ;;
    *)        construir_args "$metodo" "$endpoint" "$argumento" ;;
  esac

  if [ "$dry_run" -eq 1 ]; then
    imprimir_dry_run
    exit 0
  fi

  case "$subcomando" in
    download) descargar "${argumento}.part" "$argumento" "$reanudar" "$hash" ;;
    *)        ejecutar ;;
  esac
}

main "$@"
