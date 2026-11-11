#!/usr/bin/env bash
#
# api-toolkit.sh — Capa 6 de api-toolkit (Semana 06): observable
#
# La Semana 05 dejo el toolkit preparado para la red hostil. Esta capa le
# permite contar lo que hace: una traza de la conversacion HTTP con las
# credenciales tachadas, el tiempo de cada fase de la peticion, una linea de
# metricas por llamada, un User-Agent que lo identifica ante el servidor, y
# ninguna dependencia del ~/.curlrc de quien lo ejecute.
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
#   --verbose      Traza la peticion por stderr, con las credenciales y las
#                  cookies tachadas. stdout sigue llevando solo el cuerpo
#   --timing       Imprime por stderr el tiempo de cada fase de la peticion.
#                  No aplica a download
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
#   METRICS_FILE    Si esta definida, cada peticion anade a ese archivo una
#                   linea JSON con su codigo y sus tiempos. No aplica a download
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
# tienes que rellenar. Cuando no quede ninguno, ./scripts/verificar-semana.sh 06
# deberia pasar las dieciocho comprobaciones.

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

# Con que nombre se presenta el toolkit al servidor. En los logs de la API,
# "curl/7.81.0" no distingue tu script de cualquier otro curl.
# shellcheck disable=SC2034  # la usara construir_red, para el User-Agent
readonly VERSION=0.6.0

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

# El -w de las peticiones con cuerpo de texto: una ultima linea, detras del
# cuerpo, con el codigo y los instantes en los que termino cada fase (segundos
# desde el principio, acumulados) y los bytes recibidos.
# TODO 3: anade, separados por un espacio y en este orden, el instante en que
#         termino cada fase y los bytes recibidos: time_namelookup,
#         time_connect, time_appconnect, time_starttransfer, time_total y
#         size_download. medir() los lee con un read, en ese orden.
readonly FORMATO_W='\n%{http_code}'

CONFIG_CURL=""
TRAZA=""
RED_CURL=()
VERBOSE=0
TIMING=0

limpiar() {
  [ -n "$CONFIG_CURL" ] && rm -f "$CONFIG_CURL"
  [ -n "$TRAZA" ] && rm -f "$TRAZA"
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

  CONFIG_CURL="$(temporal_privado)"

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

  # TODO 2: que el servidor vea "api-toolkit/VERSION" en el User-Agent, y no
  #         el "curl/7.81.0" que pone curl por defecto.

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
# Traduce el codigo HTTP al codigo de salida del script.
salir_por_codigo() {
  case "$1" in
    401|403) exit 77 ;;
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
  # TODO 6: hoy la traza pasa entera. Tacha el valor de los headers
  #         Authorization, Proxy-Authorization, Cookie, Set-Cookie y el que
  #         diga API_KEY_HEADER, sin distinguir mayusculas: "> Authorization:
  #         Bearer xyz" tiene que salir como "> Authorization: <REDACTADO>".
  #         Tacha tambien las lineas "* Added cookie" y "* Replaced cookie".
  cat
}

# lanzar_curl ARGUMENTOS...
#
# El unico sitio donde se ejecuta curl. --disable tiene que ser el PRIMER
# argumento: es lo que impide que curl lea el ~/.curlrc de quien ejecuta el
# script. Todo lo que curl escribe en stderr (errores y traza) pasa por
# redactar_traza antes de llegar al terminal.
lanzar_curl() {
  # TODO 1: hoy curl lee el ~/.curlrc y su stderr llega sin filtrar. Pon
  #         --disable como primer argumento, manda stderr a "$TRAZA", pasa
  #         ese archivo por redactar_traza hacia stderr, y devuelve el codigo
  #         de salida de curl, no el del filtro.
  curl "$@"
}

# fases DNS CONEXION TLS PRIMER_BYTE TOTAL
#
# Los time_* de curl son instantes acumulados desde el principio. Imprime la
# duracion de cada fase: dns, tcp, tls, servidor y transferencia, y el total.
# Sin TLS, time_appconnect vale 0 y la fase tls dura 0. En una peticion que
# falla, las fases que no llegaron a empezar valen 0, nunca un negativo.
fases() {
  # TODO 4: imprime las seis duraciones en una linea, con 6 decimales:
  #         dns, tcp, tls, servidor, transferencia y total. Sin TLS, la fase
  #         tls dura 0. Si la peticion fallo, las fases que no empezaron
  #         valen 0, nunca un negativo. Los decimales necesitan awk: bash
  #         solo sabe aritmetica entera.
  echo "0 0 0 0 0 0"
}

# medir METODO ENDPOINT MEDIDAS
#
# MEDIDAS es la ultima linea del -w. Con --timing imprime las fases por
# stderr; con METRICS_FILE anade una linea JSON. Se llama tambien cuando la
# peticion fallo: un fallo es justo lo que mas interesa medir.
medir() {
  # TODO 5: lee las siete medidas de "$3" y pasalas por fases. Con TIMING=1,
  #         imprime por stderr una linea:
  #           tiempos: dns=0.000021s tcp=... tls=... servidor=...
  #           transferencia=... total=...s
  #         Con METRICS_FILE, anade al final del archivo una linea JSON con
  #         ts, metodo, endpoint (sin la query string), codigo (numero),
  #         dns, tcp, tls, servidor, transferencia, total y bytes.
  #         Ojo: el codigo de un fallo de red es "000", que no es JSON.
  :
}

# ejecutar METODO ENDPOINT
ejecutar() {
  local salida rc=0
  salida="$(lanzar_curl "${ARGS_CURL[@]}")" || rc=$?

  # La ultima linea es la del -w; todo lo anterior, el cuerpo. curl escribe el
  # -w tambien cuando falla, con codigo 000: la medida se registra igual.
  local medidas="${salida##*$'\n'}"
  local cuerpo="${salida%$'\n'*}"

  medir "$1" "$2" "$medidas"

  [ "$rc" -eq 0 ] || fallo_de_red "$rc"

  printf '%s\n' "$cuerpo"

  salir_por_codigo "${medidas%% *}"
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

# --- Programa principal -----------------------------------------------------

main() {
  local dry_run=0 reanudar=0 hash=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run) dry_run=1; shift ;;
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

  TRAZA="$(temporal_privado)"

  case "$subcomando" in
    download) descargar "${argumento}.part" "$argumento" "$reanudar" "$hash" ;;
    *)        ejecutar "$metodo" "$endpoint" ;;
  esac
}

main "$@"
