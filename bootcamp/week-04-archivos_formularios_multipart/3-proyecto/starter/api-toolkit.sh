#!/usr/bin/env bash
#
# api-toolkit.sh — Capa 4 de api-toolkit (Semana 04): las transferencias
#
# La Semana 03 dejo los cuatro verbos autenticados, con la credencial fuera de
# la linea de comandos. Esta capa le ensena a mover archivos: descargarlos sin
# guardar una pagina de error en su lugar, reanudarlos cuando la conexion se
# corta, comprobar que llegaron enteros, y subirlos como multipart.
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
#
# Las variables de entorno mandan sobre el archivo. Si una no esta en el
# entorno, se busca en BC_CURL_FILE, que tiene que tener permisos 600.
#
# Ejemplos:
#   ./api-toolkit.sh download /range/1000 datos.bin
#   ./api-toolkit.sh --resume download /range/1000 datos.bin
#   ./api-toolkit.sh --sha256 2ac1...35bd download /range/100 datos.bin
#   ./api-toolkit.sh upload /post informe.pdf
#
# Codigos de salida:
#   0   la API respondio 2xx o 3xx (y en download, el archivo esta completo)
#   1   error de uso, archivo inexistente, hash que no coincide, o la API
#       respondio un 4xx/5xx que no es de credencial
#   75  download cortado a medias (EX_TEMPFAIL). DESTINO.part se conserva:
#       repite con --resume y continua donde se quedo
#   77  la API respondio 401 o 403 (EX_NOPERM)
#
# Este archivo es el punto de partida, no la solucion. Cada TODO es un hueco que
# tienes que rellenar. Cuando no quede ninguno, ./scripts/verificar-semana.sh 04
# deberia pasar las dieciocho comprobaciones.

set -euo pipefail

# --- Configuracion ----------------------------------------------------------

BASE_URL="${BASE_URL:-http://localhost:8080}"
AUTH_MODE="${AUTH_MODE:-none}"
API_KEY_HEADER="${API_KEY_HEADER:-X-API-Key}"
BC_CURL_FILE="${BC_CURL_FILE:-${HOME}/.bc-curl}"
UPLOAD_FIELD="${UPLOAD_FIELD:-file}"

# Segundos maximos por peticion. Sin esto, un servidor colgado cuelga el script.
readonly MAX_TIME=10

# Una descarga grande no cabe en 10 segundos, pero tampoco puede quedarse
# colgada para siempre. Dos limites distintos: un techo absoluto, y un minimo
# de velocidad — si baja de 1 KB/s durante 30 s, la conexion esta muerta
# aunque no se haya cerrado.
readonly MAX_TIME_DESCARGA=600
readonly VELOCIDAD_MINIMA=1024
readonly TIEMPO_VELOCIDAD=30

readonly REDACTADO='<REDACTADO>'

CONFIG_CURL=""

limpiar() {
  [ -n "$CONFIG_CURL" ] && rm -f "$CONFIG_CURL"
  return 0
}
trap limpiar EXIT

# --- Utilidades -------------------------------------------------------------

uso() {
  sed -n '3,61p' "${BASH_SOURCE[0]}" | sed 's|^# \?||'
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

  ARGS_CURL+=("${BASE_URL}${endpoint}")
}

# construir_args_upload ENDPOINT ARCHIVO
#
# Como construir_args, pero el cuerpo es un formulario multipart con el archivo
# en el campo UPLOAD_FIELD.
construir_args_upload() {
  local endpoint="$1" archivo="$2"

  # Sin esta comprobacion curl sale con 26 ("read error"), que no le dice nada
  # a quien llama al script.
  [ -f "$archivo" ] && [ -r "$archivo" ] \
    || error "no existe o no se puede leer: $archivo"

  ARGS_CURL=(
    --max-time "$MAX_TIME_DESCARGA"
    --silent --show-error
    --write-out '\n%{http_code}'
  )

  [ -n "$CONFIG_CURL" ] && ARGS_CURL+=(--config "$CONFIG_CURL")

  # TODO 1: anade a ARGS_CURL la parte del formulario con el archivo.
  #   El campo se llama $UPLOAD_FIELD y el valor es el CONTENIDO del archivo,
  #   no su ruta: eso es la @ de --form. Pon la ruta entre comillas dobles
  #   dentro del valor — sin ellas, un nombre como 'informe;type=x.pdf' se lee
  #   como una directiva de -F. Y NO anadas ningun header Content-Type: el
  #   boundary lo genera curl, y uno escrito a mano que no coincida con el
  #   del cuerpo hace que el servidor responda 400.

  ARGS_CURL+=("${BASE_URL}${endpoint}")
}

# construir_args_descarga ENDPOINT PARTE REANUDAR
#
# Los argumentos de download. El cuerpo no pasa por bash: va directo a PARTE.
construir_args_descarga() {
  local endpoint="$1" parte="$2" reanudar="$3"

  ARGS_CURL=(
    --max-time "$MAX_TIME_DESCARGA"
    --speed-limit "$VELOCIDAD_MINIMA" --speed-time "$TIEMPO_VELOCIDAD"
    --retry 3
    --silent --show-error
    --write-out '%{http_code}'
  )

  [ -n "$CONFIG_CURL" ] && ARGS_CURL+=(--config "$CONFIG_CURL")

  # TODO 2: anade los tres argumentos que convierten esto en una descarga:
  #   - --fail: sin el, un 404 se guarda en $parte como si fuera el archivo.
  #   - --output "$parte": el cuerpo va al .part, nunca directo al destino.
  #   - --continue-at -   SOLO si $reanudar es 1. El guion le dice a curl que
  #     mire el tamano de $parte y pida desde ahi con un header Range.

  ARGS_CURL+=("${BASE_URL}${endpoint}")
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
  local args=(--max-time "$MAX_TIME" --silent --head)
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
    if [ "$codigo" = 000 ] || [[ "$codigo" == 2?? ]]; then
      # Sin codigo (000) o con un 2xx y aun asi fallo: la conexion se corto a
      # medias. El .part se conserva para que --resume continue desde ahi.
      echo "error: descarga cortada en $parte (curl salio con $rc). Repite con --resume" >&2
      exit 75
    fi

    # TODO 3: un 416 con $reanudar a 1 no es necesariamente un error. Puede
    #   significar que $parte ya llega hasta el final del recurso (la descarga
    #   termino pero el script murio antes de renombrar), o que $parte es MAS
    #   GRANDE que el recurso porque este cambio. Distinguelos comparando
    #   `wc -c < "$parte"` con `tamano_remoto "${ARGS_CURL[-1]}"`:
    #     - iguales: avisa por stderr y sigue hacia la verificacion y el mv.
    #     - distintos: borra $parte y falla con `error`.
    #   Tiene que ir ANTES del bloque de abajo, que trata cualquier otro codigo
    #   como error.

    # TODO 4: cualquier otro codigo es un error de la API. Antes de salir,
    #   borra $parte: con --fail curl no escribe el cuerpo del 404, pero un
    #   .part viejo de otra descarga seguiria ahi. Despues, sal con
    #   `salir_por_codigo "$codigo"`.
    echo "error: la API respondio $codigo" >&2
    salir_por_codigo "$codigo"
  fi

  # TODO 5: si $hash no esta vacio, calcula el SHA-256 de $parte con
  #   `sha256_de` y comparalo. Si no coincide, borra $parte y falla con
  #   `error` diciendo el esperado y el recibido. Un archivo que no es el que
  #   pediste no puede quedarse con el nombre del que pediste.

  # TODO 6: el archivo esta completo y verificado. Ahora, y solo ahora, pasa
  #   de $parte a $destino con un mv. Un mv dentro del mismo sistema de
  #   archivos es atomico: quien mire $destino ve el archivo entero o nada.
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
