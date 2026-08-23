#!/usr/bin/env bash
#
# api-explorer.sh — Capa 1 de api-toolkit (Semana 01)
#
# Consulta una o varias URLs y, para cada una, imprime el codigo de estado HTTP
# y el tiempo total de respuesta. Termina con una linea de resumen y sale
# distinto de 0 si alguna URL respondio con un error.
#
# Uso:
#   ./api-explorer.sh                      # usa la lista por defecto
#   ./api-explorer.sh URL [URL...]         # usa las URLs que le pases
#
# Ejemplo:
#   ./api-explorer.sh http://localhost:8080/get http://localhost:8080/status/503
#
# Codigos de salida:
#   0  todas las URLs respondieron 2xx o 3xx
#   1  al menos una respondio 4xx, 5xx, o no respondio
#
# Este archivo es el punto de partida, no la solucion. Cada TODO es un hueco
# que tienes que rellenar. Cuando no quede ninguno, ./scripts/verificar-semana.sh 01
# deberia pasar las diez comprobaciones.

set -euo pipefail

# --- Configuracion ----------------------------------------------------------

# Segundos maximos por peticion. Sin esto, un servidor colgado cuelga el script.
readonly MAX_TIME=10

# URLs que se consultan si no pasas ninguna por argumento. Cambialas por las de
# la API de tu dominio cuando la tengas elegida.
readonly URLS_POR_DEFECTO=(
  "http://localhost:8080/get"
  "http://localhost:8080/json"
  "http://localhost:8080/status/404"
)

# --- Funciones --------------------------------------------------------------

# consultar_url URL
#
# Hace UNA peticion a URL e imprime dos valores separados por un espacio:
# el codigo de estado y el tiempo total en segundos.
#
# Si la peticion no llega a completarse (DNS, puerto cerrado, timeout), el
# codigo tiene que ser 000 y el tiempo 0 — el script no puede morir aqui.
consultar_url() {
  local url="$1"

  # TODO 1: construye la llamada a curl.
  #   - -o /dev/null   el cuerpo no interesa en esta capa
  #   - -s -S          sin barra de progreso, pero sin tragarse los errores
  #   - -w             imprime '%{http_code} %{time_total}'
  #   - --max-time     usa la constante MAX_TIME
  #   Termina la linea con `|| echo "000 0"` para que un fallo de red no mate
  #   el script y se pueda seguir con las demas URLs.
  #
  # Sustituye la linea de abajo por tu comando.
  echo "000 0"

  # Recuerda: la verificacion del certificado no se apaga nunca. Si un
  # certificado no valida, se arregla con --cacert.
}

# es_error CODIGO
#
# Devuelve 0 (exito en bash) si el codigo representa un error: 4xx, 5xx o 000.
es_error() {
  local codigo="$1"

  # TODO 2: devuelve exito cuando el codigo sea 000 o mayor o igual que 400.
  #   Pista: [ "$codigo" -ge 400 ] compara numeros; el 000 hay que tratarlo
  #   aparte porque no es un codigo HTTP, es "no hubo respuesta".
  [ "$codigo" = "no-implementado" ]
}

# --- Programa principal -----------------------------------------------------

main() {
  local -a urls
  if [ "$#" -gt 0 ]; then
    urls=("$@")
  else
    urls=("${URLS_POR_DEFECTO[@]}")
  fi

  local total="${#urls[@]}"
  local correctas=0
  local url resultado codigo tiempo

  echo "=== api-explorer — ${total} URL(s), maximo ${MAX_TIME}s cada una ==="

  for url in "${urls[@]}"; do
    resultado="$(consultar_url "$url")"
    codigo="${resultado%% *}"
    tiempo="${resultado##* }"

    # TODO 3: dale formato a esta linea. Tal como esta imprime los datos, pero
    #   el tiempo sale sin decimales y el autograding busca un numero decimal.
    #   Formato sugerido:  printf '%-4s %8.3fs  %s\n' "$codigo" "$tiempo" "$url"
    echo "$codigo $tiempo $url"

    if es_error "$codigo"; then
      : # TODO 4: no hagas nada aqui, pero deja constancia del fallo si quieres
    else
      correctas=$((correctas + 1))
    fi
  done

  # TODO 5: imprime la linea de resumen. Tiene que ser la ULTIMA linea de la
  #   salida y contener cuantas URLs respondieron bien sobre el total.
  #   Por ejemplo:  echo "=== Resumen: 2/3 respondieron correctamente ==="
  :

  # TODO 6: sal con 0 si todas fueron bien, y distinto de 0 si alguna fallo.
  #   Pista: en bash el codigo de salida del script es el del ultimo comando,
  #   asi que una comparacion como ultima linea ya hace el trabajo.
  [ "$correctas" -ge 0 ]
}

main "$@"
