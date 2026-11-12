#!/usr/bin/env bash
#
# api-toolkit.sh — Capa 8 de api-toolkit (Semana 08): OAuth2
#
# La Semana 07 hizo el toolkit robusto. Esta capa le ensena a conseguir su
# propio token: auth login lo pide al servidor OAuth2 con las credenciales del
# cliente, lo guarda en un archivo de sesion con permisos 600, y cada peticion
# con AUTH_MODE=oauth lo usa y lo renueva sola cuando caduca o cuando la API
# responde 401. auth logout lo revoca en el servidor antes de borrarlo.
#
# Uso:
#   ./api-toolkit.sh [flags] <subcomando> ENDPOINT [ARGUMENTO]
#   ./api-toolkit.sh auth login|status|logout
#
# Subcomandos:
#   get      ENDPOINT           Lee un recurso
#   post     ENDPOINT DATOS     Crea un recurso con el cuerpo JSON DATOS
#   put      ENDPOINT DATOS     Reemplaza un recurso entero
#   delete   ENDPOINT           Elimina un recurso
#   download ENDPOINT DESTINO   Descarga a DESTINO, pasando por DESTINO.part
#   upload   ENDPOINT ARCHIVO   Sube ARCHIVO como multipart/form-data
#   fetch-all ENDPOINT          Sigue el Link rel="next" pagina a pagina e
#                               imprime todas las paginas como una sola lista
#   auth login                  Pide un token con client credentials y abre
#                               una sesion nueva en OAUTH_SESSION_FILE
#   auth status                 Dice si hay sesion, cuando caduca y de quien
#                               es. Nunca imprime el token
#   auth logout                 Revoca el token en el servidor y borra la sesion
#
# Flags globales:
#   --dry-run      Imprime el comando curl que se habria ejecutado, y termina.
#                  La credencial sale REDACTADA: lo que imprime acaba en un log
#   --resume       Con download: continua DESTINO.part en vez de empezar de cero
#   --sha256 HASH  Con download: falla si el archivo no tiene ese SHA-256
#   --verbose      Traza la peticion por stderr, con las credenciales y las
#                  cookies tachadas. stdout sigue llevando solo el cuerpo
#   --timing       Imprime por stderr el tiempo de cada fase de la peticion.
#                  No aplica a download
#   -h, --help     Esta ayuda
#
# Variables de entorno:
#   BASE_URL        Raiz de la API. Por defecto http://localhost:8080
#   AUTH_MODE       none | basic | bearer | apikey | oauth. Por defecto none
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
#   METRICS_FILE    Si esta definida, cada peticion anade a ese archivo una
#                   linea JSON con su codigo y sus tiempos. No aplica a download
#   OAUTH_CLIENT_ID     Identificador del cliente OAuth2
#   OAUTH_CLIENT_SECRET Su secreto. Como el resto: entorno o BC_CURL_FILE
#   OAUTH_SCOPE         Scopes que pide auth login, separados por espacios
#   OAUTH_TOKEN_URL     Endpoint de token. Por defecto el del laboratorio,
#                       http://localhost:8081/default/token
#   OAUTH_REVOKE_URL    Endpoint de revocacion (RFC 7009). Por defecto
#                       http://localhost:8081/default/revoke
#   OAUTH_SESSION_FILE  Donde vive la sesion. Por defecto ~/.bc-curl-session.
#                       Se crea con permisos 600; si existe, tiene que tenerlos
#
# Las variables de entorno mandan sobre el archivo. Si una no esta en el
# entorno, se busca en BC_CURL_FILE, que tiene que tener permisos 600.
#
# El ~/.curlrc de quien ejecuta el script NO se lee: el toolkit tiene que
# comportarse igual en todas las maquinas.
#
# Ejemplos:
#   ./api-toolkit.sh download /range/1000 datos.bin
#   ./api-toolkit.sh --resume download /range/1000 datos.bin
#   ./api-toolkit.sh --sha256 2ac1...35bd download /range/100 datos.bin
#   ./api-toolkit.sh upload /post informe.pdf
#   BASE_URL=https://localhost:8443 API_CACERT=docs/lab-ca.pem ./api-toolkit.sh get /get
#   COOKIE_JAR=~/.bc-curl-cookies ./api-toolkit.sh get '/cookies/set?sesion=1'
#   ./api-toolkit.sh --verbose get /get
#   METRICS_FILE=metricas.jsonl ./api-toolkit.sh --timing get /delay/1
#   BASE_URL=https://localhost:8443 API_CACERT=docs/lab-ca.pem ./api-toolkit.sh fetch-all /paginas
#   ./api-toolkit.sh auth login
#   AUTH_MODE=oauth BASE_URL=http://localhost:8081/default ./api-toolkit.sh get /userinfo
#
# stdout solo lleva el cuerpo de una respuesta 2xx o 3xx. El de un error va a
# stderr, detras del mensaje: un "| jq" nunca procesa un error como si fueran
# datos. fetch-all no imprime nada hasta tener todas las paginas.
#
# Codigos de salida:
#   0   la API respondio 2xx o 3xx (y en download, el archivo esta completo)
#   1   error de uso, archivo inexistente, hash que no coincide, la API
#       respondio un 4xx/5xx definitivo, fetch-all encontro una pagina que
#       no es una lista, un Link a otro host o mas de MAX_PAGINAS paginas,
#       o auth status no encontro una sesion vigente
#   75  fallo temporal (EX_TEMPFAIL): la API respondio 429, 502, 503 o 504
#       despues de los reintentos, o un download se corto a medias.
#       Repetir mas tarde puede funcionar; con download, usa --resume
#   77  la API respondio 401 o 403 (EX_NOPERM), con OAuth2 incluso despues
#       de renovar el token; no hay sesion; o el servidor OAuth2 rechazo
#       las credenciales del cliente o el refresh_token
#   69  no hubo respuesta HTTP: DNS, conexion, timeout, TLS o demasiados
#       redirects (EX_UNAVAILABLE). El mensaje dice cual
#
# Este archivo es el punto de partida, no la solucion. Cada TODO es un hueco que
# tienes que rellenar. Cuando no quede ninguno, ./scripts/verificar-semana.sh 08
# deberia pasar las diecisiete comprobaciones.

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
METRICS_FILE="${METRICS_FILE:-}"
OAUTH_SCOPE="${OAUTH_SCOPE:-}"
OAUTH_TOKEN_URL="${OAUTH_TOKEN_URL:-http://localhost:8081/default/token}"
OAUTH_REVOKE_URL="${OAUTH_REVOKE_URL:-http://localhost:8081/default/revoke}"
OAUTH_SESSION_FILE="${OAUTH_SESSION_FILE:-${HOME}/.bc-curl-session}"

# Con que nombre se presenta el toolkit al servidor. En los logs de la API,
# "curl/7.81.0" no distingue tu script de cualquier otro curl.
readonly VERSION=0.8.0

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
# fetch-all para aqui aunque queden paginas: un Link que apunta a si mismo
# convertiria el script en un bucle infinito contra la API.
readonly MAX_PAGINAS=100
# Un token al que le quedan menos de estos segundos se renueva antes de usarlo.
# shellcheck disable=SC2034  # la usara sesion_caducada
readonly MARGEN_CADUCIDAD=30

readonly REDACTADO='<REDACTADO>'

# El -w de las peticiones con cuerpo de texto: una ultima linea, detras del
# cuerpo, con el codigo y los instantes en los que termino cada fase (segundos
# desde el principio, acumulados) y los bytes recibidos.
readonly FORMATO_W='\n%{http_code} %{time_namelookup} %{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total} %{size_download}'

CONFIG_CURL=""
CONFIG_OAUTH=""
TRAZA=""
CUERPO=""
CABECERAS=""
PAGINAS=""
CODIGO=""
RED_CURL=()
VERBOSE=0
TIMING=0
DRY_RUN=0

limpiar() {
  [ -n "$CONFIG_CURL" ] && rm -f "$CONFIG_CURL"
  [ -n "$CONFIG_OAUTH" ] && rm -f "$CONFIG_OAUTH"
  [ -n "$TRAZA" ] && rm -f "$TRAZA"
  [ -n "$CUERPO" ] && rm -f "$CUERPO"
  [ -n "$CABECERAS" ] && rm -f "$CABECERAS"
  [ -n "$PAGINAS" ] && rm -f "$PAGINAS"
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

# temporal_privado
#
# Crea un archivo temporal que solo puede leer su dueno, e imprime su ruta.
temporal_privado() {
  (umask 077 && mktemp "${TMPDIR:-/tmp}/api-toolkit.XXXXXX")
}

permisos_de() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null
}

cargar_credenciales() {
  API_USER="${API_USER:-}"
  API_PASSWORD="${API_PASSWORD:-}"
  API_TOKEN="${API_TOKEN:-}"
  API_KEY="${API_KEY:-}"
  OAUTH_CLIENT_ID="${OAUTH_CLIENT_ID:-}"
  OAUTH_CLIENT_SECRET="${OAUTH_CLIENT_SECRET:-}"

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
      OAUTH_CLIENT_ID)
        if [ -z "$OAUTH_CLIENT_ID" ]; then OAUTH_CLIENT_ID="$valor"; fi ;;
      OAUTH_CLIENT_SECRET)
        if [ -z "$OAUTH_CLIENT_SECRET" ]; then OAUTH_CLIENT_SECRET="$valor"; fi ;;
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

# rechazar_saltos TEXTO...
#
# Un salto de linea no se puede escapar en un --config: cerraria la opcion, y
# lo que viniera detras se leeria como OTRA opcion de curl. Se rechaza.
rechazar_saltos() {
  case "$*" in
    *$'\n'*|*$'\r'*) error "la credencial contiene un salto de linea" ;;
    *) ;;
  esac
}

construir_config() {
  [ "$AUTH_MODE" = none ] && return 0
  [ "$AUTH_MODE" = oauth ] && token_de_sesion

  # Con OAuth2 se reescribe despues de renovar el token: el mismo archivo, que
  # ARGS_CURL ya nombra en su --config.
  [ -n "$CONFIG_CURL" ] || CONFIG_CURL="$(temporal_privado)"

  rechazar_saltos "$API_USER" "$API_PASSWORD" "$API_TOKEN" "$API_KEY"

  case "$AUTH_MODE" in
    basic)
      [ -n "$API_USER" ] && [ -n "$API_PASSWORD" ] \
        || error "AUTH_MODE=basic necesita API_USER y API_PASSWORD"
      printf 'user = "%s:%s"\n' "$(escapar_config "$API_USER")" "$(escapar_config "$API_PASSWORD")" > "$CONFIG_CURL"
      ;;
    bearer|oauth)
      [ -n "$API_TOKEN" ] || error "AUTH_MODE=$AUTH_MODE necesita API_TOKEN"
      printf 'header = "Authorization: Bearer %s"\n' "$(escapar_config "$API_TOKEN")" > "$CONFIG_CURL"
      ;;
    apikey)
      [ -n "$API_KEY" ] || error "AUTH_MODE=apikey necesita API_KEY"
      printf 'header = "%s: %s"\n' "$(escapar_config "$API_KEY_HEADER")" "$(escapar_config "$API_KEY")" > "$CONFIG_CURL"
      ;;
    *)
      error "AUTH_MODE desconocido: $AUTH_MODE (usa none, basic, bearer, apikey u oauth)"
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

  RED_CURL=(--connect-timeout "$CONNECT_TIMEOUT"
            --user-agent "api-toolkit/${VERSION}")

  [ "$VERBOSE" -eq 1 ] && RED_CURL+=(--verbose)

  if [ -n "$API_CACERT" ]; then
    [ -r "$API_CACERT" ] || error "API_CACERT no existe o no se puede leer: $API_CACERT"
    RED_CURL+=(--cacert "$API_CACERT")
  fi

  if [ -n "$API_CLIENT_CERT" ] || [ -n "$API_CLIENT_KEY" ]; then
    [ -n "$API_CLIENT_CERT" ] && [ -n "$API_CLIENT_KEY" ] \
      || error "mTLS necesita API_CLIENT_CERT y API_CLIENT_KEY, las dos"
    [ -r "$API_CLIENT_CERT" ] || error "no se puede leer: $API_CLIENT_CERT"
    [ -r "$API_CLIENT_KEY" ] || error "no se puede leer: $API_CLIENT_KEY"
    exigir_600 "$API_CLIENT_KEY"
    RED_CURL+=(--cert "$API_CLIENT_CERT" --key "$API_CLIENT_KEY")
  fi

  if [ -n "$COOKIE_JAR" ]; then
    # curl crea el tarro con la umask del proceso (644 normalmente), y una
    # cookie de sesion vale lo que una password. Se crea antes, con 600: curl
    # respeta los permisos de un archivo que ya existe.
    [ -e "$COOKIE_JAR" ] || (umask 077 && : > "$COOKIE_JAR")
    exigir_600 "$COOKIE_JAR"
    RED_CURL+=(--cookie "$COOKIE_JAR" --cookie-jar "$COOKIE_JAR")
  fi

  # Redirects: solo en GET. Un POST que sigue un 301 o un 302 llega como GET y
  # pierde el cuerpo sin avisar. Y nunca con AUTH_MODE=apikey: curl quita el
  # Authorization al saltar a otro host, pero NO un header propio como
  # X-API-Key, que llegaria entero al host nuevo.
  # ponytail: con apikey ni siquiera se siguen los redirects al mismo host;
  # seguirlos a mano, comparando el host de %{redirect_url}, si hace falta.
  if [ "$metodo" = GET ] && [ "$AUTH_MODE" != apikey ]; then
    RED_CURL+=(--location --max-redirs "$MAX_REDIRECTS")
    # Desde https, nunca bajar a http: el redirect viajaria en claro.
    case "$BASE_URL" in
      https://*) RED_CURL+=(--proto-redir "=https") ;;
      *)         RED_CURL+=(--proto-redir "=http,https") ;;
    esac
  fi

  # Reintentos: solo lo que se puede repetir sin efectos dobles. Un POST que
  # dio timeout puede haber creado el recurso; repetirlo crearia otro.
  case "$metodo" in
    GET|PUT|DELETE)
      RED_CURL+=(--retry "$REINTENTOS" --retry-connrefused
                 --retry-max-time "$RETRY_MAX_TIME")
      ;;
    *) ;;
  esac
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
    get|download|fetch-all) echo GET ;;
    post|upload)  echo POST ;;
    put)          echo PUT ;;
    delete)       echo DELETE ;;
    *)            return 1 ;;
  esac
}

# construir_args METODO URL [DATOS]
#
# Los argumentos de las peticiones que devuelven un cuerpo de texto: los cuatro
# verbos y fetch-all. Aqui NO entra ningun secreto: lo lleva el --config.
# Recibe la URL entera, no el endpoint: fetch-all pide las paginas por la URL
# que trae el Link.
construir_args() {
  local metodo="$1" url="$2" datos="${3:-}"

  ARGS_CURL=(
    --max-time "$MAX_TIME"
    --request "$metodo"
    --silent --show-error
    --write-out "$FORMATO_W"
  )

  [ -n "$CONFIG_CURL" ] && ARGS_CURL+=(--config "$CONFIG_CURL")

  if [ -n "$datos" ]; then
    ARGS_CURL+=(
      --header 'Content-Type: application/json'
      --header 'Accept: application/json'
      --data-raw "$datos"
    )
  fi

  ARGS_CURL+=("${RED_CURL[@]}" "$url")
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
    --write-out "$FORMATO_W"
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
  printf 'curl --disable'
  printf ' %q' "${ARGS_CURL[@]}"
  printf '\n'

  if [ "$AUTH_MODE" != none ]; then
    printf '# AUTH_MODE=%s, credencial: %s\n' "$AUTH_MODE" "$REDACTADO"
  fi
}

# salir_por_codigo CODIGO_HTTP
#
# Traduce el codigo HTTP al codigo de salida del script. Un 429 o un 503 no es
# un error de quien llama: es "ahora no". Quien automatiza necesita distinguir
# lo que merece la pena repetir (75) de lo que va a fallar siempre (1).
salir_por_codigo() {
  case "$1" in
    401|403) exit 77 ;;
    429|502|503|504) exit 75 ;;
    [123]??) exit 0 ;;
    *)       exit 1 ;;
  esac
}

# redactar_traza
#
# Filtro: copia la traza de -v de stdin a stdout tachando el valor de los
# headers que llevan una credencial o una sesion, y las cookies que el motor de
# curl anuncia en sus lineas '*'. La traza acaba en un terminal compartido, en
# un ticket o en un log de CI: nada de lo que sale de aqui puede dar acceso.
# ponytail: la linea de la peticion (> GET /ruta?query) no se toca; un secreto
# en la query string se filtra igual. Ningun secreto va en la URL.
redactar_traza() {
  awk -v propio="$(tr '[:upper:]' '[:lower:]' <<<"$API_KEY_HEADER")" -v tachado="$REDACTADO" '
    /^[<>] [^ ]+:/ {
      nombre = tolower($2)
      sub(/:$/, "", nombre)
      if (nombre == "authorization" || nombre == "proxy-authorization" ||
          nombre == "cookie" || nombre == "set-cookie" || nombre == propio) {
        print $1, $2, tachado
        next
      }
    }
    /^\* (Added|Replaced) cookie / { print "* cookie", tachado; next }
    { print }
  '
}

# lanzar_curl ARGUMENTOS...
#
# El unico sitio donde se ejecuta curl. --disable tiene que ser el PRIMER
# argumento: es lo que impide que curl lea el ~/.curlrc de quien ejecuta el
# script. Todo lo que curl escribe en stderr (errores y traza) pasa por
# redactar_traza antes de llegar al terminal.
lanzar_curl() {
  local rc=0
  curl --disable "$@" 2>"$TRAZA" || rc=$?
  redactar_traza < "$TRAZA" >&2
  return "$rc"
}

# fases DNS CONEXION TLS PRIMER_BYTE TOTAL
#
# Los time_* de curl son instantes acumulados desde el principio. Imprime la
# duracion de cada fase: dns, tcp, tls, servidor y transferencia, y el total.
# Sin TLS, time_appconnect vale 0 y la fase tls dura 0. En una peticion que
# falla, las fases que no llegaron a empezar valen 0, nunca un negativo.
fases() {
  awk -v dns="$1" -v con="$2" -v tls="$3" -v ttfb="$4" -v total="$5" '
    function dur(desde, hasta) { return (hasta > desde) ? hasta - desde : 0 }
    BEGIN {
      fin_tls = (tls > 0) ? tls : con
      # Sin primer byte no hubo respuesta: ni servidor ni transferencia.
      fin_ttfb = (ttfb > 0) ? ttfb : total
      printf "%.6f %.6f %.6f %.6f %.6f %.6f\n", dns, dur(dns, con),
        dur(con, fin_tls), dur(fin_tls, ttfb), dur(fin_ttfb, total), total
    }'
}

# medir METODO ENDPOINT MEDIDAS
#
# MEDIDAS es la ultima linea del -w. Con --timing imprime las fases por
# stderr; con METRICS_FILE anade una linea JSON. Se llama tambien cuando la
# peticion fallo: un fallo es justo lo que mas interesa medir.
medir() {
  local metodo="$1" endpoint="$2"
  local codigo dns con tls ttfb total bytes
  read -r codigo dns con tls ttfb total bytes <<<"$3"

  local f_dns f_tcp f_tls f_servidor f_transferencia f_total
  read -r f_dns f_tcp f_tls f_servidor f_transferencia f_total \
    <<<"$(fases "$dns" "$con" "$tls" "$ttfb" "$total")"

  if [ "$TIMING" -eq 1 ]; then
    printf 'tiempos: dns=%ss tcp=%ss tls=%ss servidor=%ss transferencia=%ss total=%ss\n' \
      "$f_dns" "$f_tcp" "$f_tls" "$f_servidor" "$f_transferencia" "$f_total" >&2
  fi

  if [ -n "$METRICS_FILE" ]; then
    # Sin la query string: agrupar por endpoint necesita la ruta sola, y la
    # query puede llevar algo que no debe acabar en un archivo de metricas.
    jq -cn \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg metodo "$metodo" \
      --arg endpoint "${endpoint%%\?*}" \
      --argjson codigo "$((10#$codigo))" \
      --argjson dns "$f_dns" --argjson tcp "$f_tcp" --argjson tls "$f_tls" \
      --argjson servidor "$f_servidor" \
      --argjson transferencia "$f_transferencia" \
      --argjson total "$f_total" --argjson bytes "$bytes" \
      '{ts: $ts, metodo: $metodo, endpoint: $endpoint, codigo: $codigo,
        dns: $dns, tcp: $tcp, tls: $tls, servidor: $servidor,
        transferencia: $transferencia, total: $total, bytes: $bytes}' \
      >> "$METRICS_FILE"
  fi
}

# cabecera NOMBRE
#
# Imprime el valor del header NOMBRE en la respuesta guardada en CABECERAS, sin
# distinguir mayusculas y sin el \r final. Si curl reintento o siguio un
# redirect, CABECERAS tiene un bloque por respuesta: vale el del ultimo.
# ponytail: si el header se repite en la misma respuesta, gana el ultimo;
# juntarlos con ", " si alguna API parte el Link en varias lineas.
cabecera() {
  awk -v nombre="$(tr '[:upper:]' '[:lower:]' <<<"$1")" '
    { sub(/\r$/, "") }
    /^HTTP\// { valor = ""; next }
    {
      i = index($0, ":")
      if (i > 0 && tolower(substr($0, 1, i - 1)) == nombre) {
        valor = substr($0, i + 1)
        sub(/^[ \t]+/, "", valor)
      }
    }
    END { if (valor != "") print valor }
  ' "$CABECERAS"
}

# peticion METODO ENDPOINT
#
# Lanza ARGS_CURL. Deja el codigo HTTP en CODIGO, el cuerpo en el archivo
# CUERPO y los headers en el archivo CABECERAS. Sin respuesta HTTP, sale con 69.
#
# El cuerpo va a un archivo y no a stdout: con --retry, curl escribe en stdout
# el cuerpo de CADA intento, uno detras de otro. Un archivo lo trunca antes de
# reintentar, y solo queda el del ultimo.
peticion() {
  local salida rc=0
  salida="$(lanzar_curl --output "$CUERPO" --dump-header "$CABECERAS" "${ARGS_CURL[@]}")" || rc=$?

  # La ultima linea es la del -w. curl la escribe tambien cuando falla, con
  # codigo 000: la medida se registra igual.
  local medidas="${salida##*$'\n'}"
  CODIGO="${medidas%% *}"

  medir "$1" "$2" "$medidas"

  [ "$rc" -eq 0 ] || fallo_de_red "$rc"
}

# exigir_exito
#
# Si CODIGO no es 2xx ni 3xx, escribe el cuerpo de la respuesta y un mensaje
# por stderr, y sale con el codigo que toca. stdout queda vacio.
exigir_exito() {
  case "$CODIGO" in
    [123]??) return 0 ;;
    *) ;;
  esac

  cat "$CUERPO" >&2
  local espera
  espera="$(cabecera retry-after)"
  echo "error: la API respondio ${CODIGO}${espera:+; Retry-After: ${espera}}" >&2
  salir_por_codigo "$CODIGO"
}

# ejecutar METODO ENDPOINT
#
# Con OAuth2, un 401 puede llegar con un token que aun no ha caducado: el
# servidor rota sus claves, o alguien revoco el token. Se renueva UNA vez y se
# repite UNA vez; si vuelve a dar 401, el 401 es de verdad. Repetir es seguro
# incluso en un POST: un 401 dice que la API no llego a procesarlo.
# ponytail: fetch-all no repite ante un 401; solo renueva el token caducado
# antes de empezar.
ejecutar() {
  peticion "$1" "$2"
  # TODO 5: si CODIGO es 401 y AUTH_MODE es oauth: renovar, construir_config
  # (reescribe el mismo --config con el token nuevo) y peticion otra vez. Una
  # sola vez: si vuelve a dar 401, exigir_exito sale con 77.
  # Practica 03, pasos 5 y 6.
  exigir_exito
  cat "$CUERPO"
}

# siguiente_pagina LINK
#
# Imprime la URL marcada con rel="next" en el valor de un header Link (RFC
# 8288), o nada si no hay. El orden de los rel no esta garantizado: next puede
# ir detras de prev, first o last.
#   <https://api/x?page=1>; rel="prev", <https://api/x?page=3>; rel="next"
# ponytail: parte por comas, y una URL con una coma dentro se rompe; un parser
# de verdad recorreria los <...> si alguna API las usa.
siguiente_pagina() {
  local enlaces enlace
  IFS=',' read -ra enlaces <<<"$1"
  for enlace in "${enlaces[@]}"; do
    case "$enlace" in
      *'rel="next"'*)
        enlace="${enlace#*<}"
        printf '%s\n' "${enlace%%>*}"
        return 0
        ;;
      *) ;;
    esac
  done
}

# misma_api URL
#
# Falla si URL no esta dentro de BASE_URL. Cada peticion de fetch-all lleva la
# credencial: seguir un Link a otro host se la entregaria a ese host. La / del
# final importa: sin ella, https://api.ejemplo.com.otro.com pasaria por buena.
# ponytail: un Link relativo (</x?page=2>) tambien se rechaza; resolverlo
# contra BASE_URL si alguna API lo usa.
misma_api() {
  case "$1" in
    "$BASE_URL"/*) ;;
    *) error "fetch-all no sigue un Link fuera de la API: $1" ;;
  esac
}

# fetch_all ENDPOINT
#
# Pide ENDPOINT y sigue el Link rel="next" hasta que no haya mas. Cada pagina
# tiene que ser una lista JSON. Imprime todas juntas, como una sola lista, y
# solo al final: si una pagina falla, stdout queda vacio, nunca a medias.
fetch_all() {
  local url="${BASE_URL}$1"

  local paginas=0 endpoint

  while [ -n "$url" ]; do
    paginas=$((paginas + 1))
    [ "$paginas" -le "$MAX_PAGINAS" ] \
      || error "fetch-all paro en $MAX_PAGINAS paginas: ¿un Link que apunta a si mismo?"
    misma_api "$url"
    endpoint="${url#"$BASE_URL"}"

    construir_args GET "$url"
    peticion GET "$endpoint"
    exigir_exito

    if [ ! -s "$CUERPO" ] || ! jq -e 'type == "array"' "$CUERPO" >/dev/null 2>&1; then
      error "$endpoint no es una lista JSON"
    fi
    jq -c . "$CUERPO" >> "$PAGINAS"

    url="$(siguiente_pagina "$(cabecera link)")"
  done

  jq -s 'add // []' "$PAGINAS"
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
  lanzar_curl "${args[@]}" "$1" | tr -d '\r' \
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

  if codigo="$(lanzar_curl "${ARGS_CURL[@]}")"; then rc=0; else rc=$?; fi

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

# --- OAuth2 (capa 8) --------------------------------------------------------

# peticion_oauth URL CAMPO=VALOR...
#
# POST de formulario al servidor OAuth2: al endpoint de token o al de
# revocacion. El cliente se autentica con HTTP Basic (client_secret_basic, RFC
# 6749 2.3.1) y cada CAMPO viaja con data-urlencode. Todo eso, el secreto y el
# refresh_token incluidos, va en un --config temporal: nada sale en la linea de
# comandos, que ve cualquiera con ps. Deja el codigo en CODIGO y la respuesta
# en CUERPO.
#
# Sin --retry: un refresh_token que rota se gasta en el primer intento, y el
# reintento lo presentaria ya invalido. Un 503 aqui sale con 75 y quien llama
# decide.
# ponytail: el RFC pide pasar id y secreto por form-urlencoding antes del Basic;
# curl no lo hace, y un secreto con ':' o '%' fallaria. Mandarlos como
# client_id y client_secret en el cuerpo si alguna API los genera asi.
peticion_oauth() {
  local url="$1"
  shift

  [ -n "$OAUTH_CLIENT_ID" ] && [ -n "$OAUTH_CLIENT_SECRET" ] \
    || error "OAuth2 necesita OAUTH_CLIENT_ID y OAUTH_CLIENT_SECRET"
  rechazar_saltos "$OAUTH_CLIENT_ID" "$OAUTH_CLIENT_SECRET" "$@"

  # TODO 1: escribe el --config de la peticion y lanzala:
  #   - CONFIG_OAUTH: si esta vacia, temporal_privado. Una linea
  #     user = "ID:SECRETO" y, por cada argumento que queda en "$@", una linea
  #     data-urlencode = "CAMPO=VALOR". Todo pasa por escapar_config
  #   - construir_red POST
  #   - lanzar_curl con --config "$CONFIG_OAUTH", --max-time, --silent
  #     --show-error, --output "$CUERPO" y --write-out '%{http_code}', mas
  #     "${RED_CURL[@]}" y "$url". Lo que imprime es el codigo: a CODIGO
  #   - si curl sale distinto de 0, fallo_de_red
  # Practica 01, pasos 3 a 5.
  error "peticion_oauth todavia no esta implementada: $url"
}

# rechazo_oauth
#
# El servidor OAuth2 respondio un error. Lo explica con los campos "error" y
# "error_description" del cuerpo (RFC 6749, 5.2) y sale. invalid_client e
# invalid_grant son credenciales que no valen: 77, como un 401. Un 503, 75.
rechazo_oauth() {
  local tipo motivo
  tipo="$(jq -r '.error // empty' "$CUERPO" 2>/dev/null || true)"
  motivo="$(jq -r '.error_description // empty' "$CUERPO" 2>/dev/null || true)"
  echo "error: el servidor OAuth2 respondio ${CODIGO}${tipo:+: $tipo}${motivo:+ ($motivo)}" >&2

  case "$tipo" in
    invalid_grant)
      echo "error: la sesion ya no se puede renovar: ejecuta auth login" >&2
      exit 77
      ;;
    invalid_client|unauthorized_client) exit 77 ;;
    *) salir_por_codigo "$CODIGO" ;;
  esac
}

# exigir_token_ok
#
# Si el servidor OAuth2 no respondio 2xx, rechazo_oauth.
exigir_token_ok() {
  case "$CODIGO" in
    2??) return 0 ;;
    *)   rechazo_oauth ;;
  esac
}

# pedir_client_credentials
#
# El flujo de una maquina que habla en nombre propio: sin persona, sin
# navegador, y sin refresh_token (RFC 6749, 4.4.3): cuando caduca, se pide otro.
pedir_client_credentials() {
  if [ -n "$OAUTH_SCOPE" ]; then
    peticion_oauth "$OAUTH_TOKEN_URL" grant_type=client_credentials "scope=$OAUTH_SCOPE"
  else
    peticion_oauth "$OAUTH_TOKEN_URL" grant_type=client_credentials
  fi
}

# guardar_sesion CONSERVAR
#
# CUERPO tiene la respuesta del endpoint de token; la guarda como sesion, con
# un campo mas: expires_at, el instante (epoch) en que caduca. expires_in
# cuenta desde que el servidor respondio, y una hora despues nadie sabe cuando
# fue eso. Sin expires_in, la sesion nace caducada: el siguiente uso la renueva.
#
# Con CONSERVAR=1 (al renovar), si la respuesta no trae refresh_token se
# conserva el anterior: el servidor PUEDE no rotarlo (RFC 6749, 6). Con 0 (en
# auth login), la sesion empieza de cero.
#
# Se escribe en un temporal del MISMO directorio y se renombra: mv dentro de un
# sistema de archivos es atomico, y un corte a medias deja la sesion vieja,
# nunca un JSON partido. mktemp lo crea ya con permisos 600.
guardar_sesion() {
  # TODO 2: comprueba con jq -e que CUERPO trae un access_token de tipo
  # string, y escribe la sesion:
  #   - anterior=/dev/null, o OAUTH_SESSION_FILE si "$1" es 1 y existe
  #   - nueva=$(mktemp "${OAUTH_SESSION_FILE}.XXXXXX"): mismo directorio, 600
  #   - jq --slurpfile anterior ... --argjson ahora "$(date +%s)": el
  #     refresh_token del anterior, mas CUERPO, mas expires_at = ahora +
  #     expires_in (0 si no viene), sin los campos null
  #   - si jq falla, borra nueva y error; si no, mv -f nueva a la sesion
  # Practica 03, pasos 1 y 2.
  error "guardar_sesion todavia no esta implementada"
}

# sesion_caducada
#
# Verdadero si al token le quedan menos de MARGEN_CADUCIDAD segundos. El margen
# cubre un reloj desajustado y la peticion que sale con el token vivo y llega
# al servidor con el token muerto.
sesion_caducada() {
  # TODO 3: lee expires_at de la sesion (un numero; 0 si falta) y devuelve
  # verdadero si date +%s ya ha llegado a expires_at - MARGEN_CADUCIDAD.
  # Practica 03, paso 3.
  return 1
}

# renovar
#
# Consigue un access_token nuevo y lo guarda. Con refresh_token, lo usa; sin el
# (client credentials no lo da), pide otro token con las credenciales del
# cliente. Si el refresh_token ya no vale, NO cae a client credentials: el
# refresh_token era de una persona (sub=alumno), las credenciales son del
# cliente (sub=api-toolkit), y caer en silencio cambiaria la identidad con la
# que actua el script.
# ponytail: dos procesos que renuevan a la vez con un refresh_token que rota se
# pisan, y el segundo recibe invalid_grant. flock sobre la sesion si el toolkit
# corre en paralelo (Semana 09).
renovar() {
  # TODO 4: si la sesion trae refresh_token, pide el token con
  # grant_type=refresh_token y refresh_token=...; si no, con
  # pedir_client_credentials. Si el refresh_token falla, NO pruebes client
  # credentials: exigir_token_ok ya sale con 77.
  # Practica 04, pasos 5 y 7.
  pedir_client_credentials
  exigir_token_ok

  guardar_sesion 1
  echo "aviso: token OAuth2 renovado" >&2
}

# token_de_sesion
#
# Deja en API_TOKEN el access_token de la sesion, renovandolo antes si caduca.
# Con --dry-run no toca la red ni la sesion.
token_de_sesion() {
  if [ "$DRY_RUN" -eq 1 ]; then
    API_TOKEN="$REDACTADO"
    return 0
  fi

  if [ ! -f "$OAUTH_SESSION_FILE" ]; then
    echo "error: no hay sesion OAuth2 en $OAUTH_SESSION_FILE: ejecuta auth login" >&2
    exit 77
  fi
  exigir_600 "$OAUTH_SESSION_FILE"

  if sesion_caducada; then
    renovar
  fi
  API_TOKEN="$(jq -r '.access_token // empty' "$OAUTH_SESSION_FILE")"
}

# claims_jwt TOKEN
#
# Imprime el payload de un JWT: el segundo trozo, en base64url. Sirve para
# MIRAR (de quien es, cuando caduca), nunca para decidir: el cliente no puede
# comprobar la firma, y un JWT se lee igual de bien siendo falso. Un token
# opaco, que no es un JWT, no imprime nada.
claims_jwt() {
  local payload
  payload="$(cut -d. -f2 <<<"$1" | tr '_-' '/+')"
  # base64url quita el relleno '='; base64 -d lo necesita.
  while [ $(( ${#payload} % 4 )) -ne 0 ]; do payload+='='; done
  base64 -d <<<"$payload" 2>/dev/null | jq -c . 2>/dev/null || true
}

# iniciar_sesion
#
# auth login. Abre una sesion NUEVA: no hereda el refresh_token de la anterior,
# que podria ser de otra identidad.
iniciar_sesion() {
  pedir_client_credentials
  exigir_token_ok
  guardar_sesion 0
  echo "sesion guardada en $OAUTH_SESSION_FILE" >&2
}

# estado_sesion
#
# auth status. Una linea por stdout con lo que hace falta para decidir, y nunca
# el token. Sale con 0 si la sesion sigue vigente, y con 1 si no hay o caduco.
estado_sesion() {
  if [ ! -f "$OAUTH_SESSION_FILE" ]; then
    echo "sin sesion: ejecuta auth login"
    exit 1
  fi
  exigir_600 "$OAUTH_SESSION_FILE"

  local expira resto sujeto refresh=no
  expira="$(jq -r '(.expires_at | numbers) // 0 | floor' "$OAUTH_SESSION_FILE")"
  resto=$(( expira - $(date +%s) ))
  sujeto="$(claims_jwt "$(jq -r '.access_token // empty' "$OAUTH_SESSION_FILE")" \
    | jq -r '.sub // empty')"
  if jq -e '.refresh_token' "$OAUTH_SESSION_FILE" >/dev/null; then
    refresh=si
  fi

  if [ "$resto" -gt 0 ]; then
    echo "activa: expira en ${resto} s, sub=${sujeto:-?}, refresh_token: ${refresh}"
  else
    echo "caducada hace $(( -resto )) s, sub=${sujeto:-?}, refresh_token: ${refresh}"
    exit 1
  fi
}

# cerrar_sesion
#
# auth logout. Borrar el archivo no basta: el refresh_token sigue vivo en el
# servidor, y quien lo haya copiado puede seguir usandolo. Primero se revoca
# (RFC 7009): el refresh_token si lo hay, y si no el access_token. Si la
# revocacion falla, la sesion NO se borra: asi el logout se puede repetir.
#
# Un servidor puede negarse a revocar access tokens (unsupported_token_type):
# un JWT se valida sin preguntarle, y revocarlo le obligaria a consultarse en
# cada peticion. Entonces la sesion se borra igual y se avisa: el token vale
# hasta su exp, y por eso conviene que viva poco.
cerrar_sesion() {
  if [ ! -f "$OAUTH_SESSION_FILE" ]; then
    echo "aviso: no habia sesion" >&2
    return 0
  fi
  exigir_600 "$OAUTH_SESSION_FILE"

  # TODO 6: revoca y borra:
  #   - el token a revocar es el refresh_token; si no hay, el access_token
  #   - peticion_oauth "$OAUTH_REVOKE_URL" "token=..." "token_type_hint=..."
  #   - un 400 con error unsupported_token_type: avisa de que el token sigue
  #     valido hasta que caduque, y sigue. Cualquier otro error:
  #     exigir_token_ok, y la sesion NO se borra
  #   - rm -f la sesion
  # Practica 04, pasos 8 y 9.
  error "auth logout todavia no esta implementado"
}

# auth ACCION
auth() {
  case "$1" in
    login)  iniciar_sesion ;;
    status) estado_sesion ;;
    logout) cerrar_sesion ;;
    *)      error "auth: usa login, status o logout" ;;
  esac
}

# --- Programa principal -----------------------------------------------------

crear_temporales() {
  TRAZA="$(temporal_privado)"
  CUERPO="$(temporal_privado)"
  CABECERAS="$(temporal_privado)"
  PAGINAS="$(temporal_privado)"
}


main() {
  local reanudar=0 hash=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run) DRY_RUN=1; shift ;;
      --resume)  reanudar=1; shift ;;
      --verbose) VERBOSE=1; shift ;;
      --timing)  TIMING=1; shift ;;
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

  if [ "$1" = auth ]; then
    [ "$DRY_RUN" -eq 0 ] || error "--dry-run no aplica a auth"
    cargar_credenciales
    crear_temporales
    auth "$2"
    exit 0
  fi

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

  # ponytail: download no mide; su -w solo lleva %{http_code}. Ampliarlo con
  # FORMATO_W cuando haga falta medir descargas.
  if [ "$subcomando" = download ] && [ "$TIMING" -eq 1 ]; then
    error "--timing no aplica a download"
  fi

  [[ "$endpoint" == /* ]] \
    || error "el endpoint tiene que empezar por /: $endpoint"

  cargar_credenciales
  # Antes de construir_config: con OAuth2, renovar el token ya es una peticion.
  crear_temporales
  construir_config
  construir_red "$metodo"

  case "$subcomando" in
    download) construir_args_descarga "$endpoint" "${argumento}.part" "$reanudar" ;;
    upload)   construir_args_upload "$endpoint" "$argumento" ;;
    fetch-all) construir_args GET "${BASE_URL}${endpoint}" ;;
    *)        construir_args "$metodo" "${BASE_URL}${endpoint}" "$argumento" ;;
  esac

  if [ "$DRY_RUN" -eq 1 ]; then
    imprimir_dry_run
    exit 0
  fi

  case "$subcomando" in
    download)  descargar "${argumento}.part" "$argumento" "$reanudar" "$hash" ;;
    fetch-all) fetch_all "$endpoint" ;;
    *)         ejecutar "$metodo" "$endpoint" ;;
  esac
}

main "$@"
