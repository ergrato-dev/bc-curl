#!/usr/bin/env bash
#
# api-toolkit.sh — Capa 2 de api-toolkit (Semana 02): los verbos
#
# La Semana 01 dejo un explorador de solo lectura. Esta capa le anade la
# escritura: cuatro subcomandos con el cuerpo JSON y los headers correctos, y un
# --dry-run que imprime el comando en vez de ejecutarlo.
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
#   --dry-run   Imprime el comando curl que se habria ejecutado, y termina
#   -h, --help  Esta ayuda
#
# Variables de entorno:
#   BASE_URL    Raiz de la API. Por defecto http://localhost:8080
#
# Ejemplos:
#   ./api-toolkit.sh get /get
#   ./api-toolkit.sh post /post '{"nombre":"Ada"}'
#   ./api-toolkit.sh --dry-run delete /anything/42
#   BASE_URL=https://api.ejemplo.com ./api-toolkit.sh get /v1/usuarios
#
# Codigos de salida:
#   0  la API respondio 2xx o 3xx
#   1  error de uso, o la API respondio 4xx o 5xx
#
# Este archivo es el punto de partida, no la solucion. Cada TODO es un hueco que
# tienes que rellenar. Cuando no quede ninguno, ./scripts/verificar-semana.sh 02
# deberia pasar las catorce comprobaciones.

set -euo pipefail

# --- Configuracion ----------------------------------------------------------

# Raiz de la API. Cambiala por la de tu dominio cuando trabajes contra ella.
BASE_URL="${BASE_URL:-http://localhost:8080}"

# Segundos maximos por peticion. Sin esto, un servidor colgado cuelga el script.
readonly MAX_TIME=10

# --- Utilidades -------------------------------------------------------------

# uso
#
# Imprime la cabecera de este archivo como ayuda. No hay que tocarla.
uso() {
  sed -n '3,32p' "${BASH_SOURCE[0]}" | sed 's|^# \?||'
}

# error MENSAJE
#
# Escribe en stderr y sale con 1. Los mensajes de error NUNCA van a stdout: si
# fueran ahi, un `... | jq` se los tragaria como si fueran datos.
error() {
  echo "error: $*" >&2
  exit 1
}

# --- Construccion de la peticion --------------------------------------------

# metodo_de SUBCOMANDO
#
# Traduce el subcomando al verbo HTTP correspondiente.
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
# Deja en el array global ARGS_CURL todos los argumentos de curl menos el
# ejecutable. Se hace asi, y no como una cadena, porque una cadena se rompe en
# cuanto un valor lleva un espacio dentro.
construir_args() {
  local metodo="$1" endpoint="$2" datos="${3:-}"

  ARGS_CURL=()

  ARGS_CURL+=(--max-time "$MAX_TIME")

  # TODO 1: anade los flags que faltan y que van en TODAS las peticiones.
  #   --request "$metodo"   el verbo. Con --request y no con -X: se lee solo
  #   --silent --show-error sin barra de progreso, pero sin tragarse los errores
  #   --write-out           pega '\n%{http_code}' al final de la respuesta, para
  #                         poder separar el codigo del cuerpo en ejecutar()
  #
  # Sustituye esta linea por tus ARGS_CURL+=(...).
  ARGS_CURL+=(--silent)

  if [ -n "$datos" ]; then
    # TODO 2: anade lo que hace falta cuando hay cuerpo.
    #   --header 'Content-Type: application/json'  declara lo que mandas
    #   --header 'Accept: application/json'        pide como quieres la respuesta
    #   --data-raw "$datos"                        el cuerpo, literal
    #
    #   Por que --data-raw y no -d: $datos viene de la linea de comandos, o sea
    #   de fuera. Si empezara por @, -d intentaria abrir un archivo, y si no
    #   existe manda un cuerpo VACIO sin fallar. --data-raw no interpreta la @.
    :
  fi

  # La URL siempre va la ultima, para que se lea de un vistazo.
  ARGS_CURL+=("${BASE_URL}${endpoint}")
}

# --- Ejecucion --------------------------------------------------------------

# imprimir_dry_run
#
# Imprime el comando curl que se habria ejecutado, en una sola linea y con las
# comillas puestas donde hacen falta.
imprimir_dry_run() {
  # TODO 3: imprime 'curl' seguido de cada elemento de ARGS_CURL, entrecomillado.
  #   Pista: printf ' %q' "${ARGS_CURL[@]}" entrecomilla cada argumento como lo
  #   haria el shell, asi que el comando impreso se puede copiar y pegar.
  #   No ejecutes nada aqui: --dry-run imprime y termina.
  echo "curl (sin implementar)"
}

# ejecutar
#
# Lanza la peticion, imprime el cuerpo y devuelve un codigo de salida acorde con
# el codigo HTTP.
ejecutar() {
  local salida codigo cuerpo

  # El --write-out del TODO 1 pega '\n<codigo>' al final de la respuesta, asi
  # que la ultima linea es el codigo y el resto es el cuerpo. De esta forma se
  # obtienen los dos con UNA sola peticion.
  salida="$(curl "${ARGS_CURL[@]}")"

  codigo="${salida##*$'\n'}"
  cuerpo="${salida%$'\n'*}"

  # El cuerpo va a stdout aunque la peticion haya fallado: en un 422 es donde la
  # API explica que campo esta mal.
  printf '%s\n' "$cuerpo"

  # TODO 4: devuelve 0 si el codigo es menor que 400, y distinto de 0 si es 400
  #   o mas. Ojo con el 000: es lo que pone curl cuando no hubo respuesta (DNS,
  #   puerto cerrado, timeout). Tambien tiene que salir distinto de 0, y no es
  #   un numero con el que se pueda comparar directamente.
  [ "$codigo" = "no-implementado" ]
}

# --- Programa principal -----------------------------------------------------

main() {
  local dry_run=0

  # Flags globales, antes del subcomando.
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

  # TODO 5: post y put necesitan cuerpo. Si falta, no llegues a hacer la
  #   peticion: falla aqui con un mensaje claro.
  #   Pista: `error "..."` ya sale con 1 y escribe en stderr.

  [[ "$endpoint" == /* ]] \
    || error "el endpoint tiene que empezar por /: $endpoint"

  construir_args "$metodo" "$endpoint" "$datos"

  if [ "$dry_run" -eq 1 ]; then
    imprimir_dry_run
    exit 0
  fi

  ejecutar
}

main "$@"
