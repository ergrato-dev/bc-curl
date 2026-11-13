#!/usr/bin/env bats
#
# Tests de api-toolkit. Desde la carpeta del proyecto:
#
#   bats tests/
#
# Funcionan con bats-core 1.2.1 (el de Ubuntu 22.04) y posteriores. Los que
# necesitan el laboratorio se saltan solos si no responde: el resto corre en
# cualquier maquina, tambien en CI.
#
# TK permite probar otro ejecutable: TK=/bin/true bats tests/ tiene que fallar.

TK="${TK:-${BATS_TEST_DIRNAME}/../api-toolkit.sh}"

# Cada test arranca con un HOME vacio y sin ninguna variable del toolkit: un
# test que pasa solo en tu maquina, porque lee tu ~/.bc-curl o tu BASE_URL, no
# prueba nada.
setup() {
  DIR="$(mktemp -d)"
  export HOME="$DIR"
  # TODO 3: quita (unset) todas las variables de entorno que lee el toolkit:
  # estan en la cabecera de api-toolkit.sh.
}

teardown() {
  rm -rf "$DIR"
}

laboratorio() {
  curl -s -o /dev/null --max-time 2 http://localhost:8080/get \
    || skip "el laboratorio no responde en localhost:8080"
}

permisos() {
  ls -l "$1" | cut -c1-10
}

# --- La interfaz -------------------------------------------------------------

@test "--version imprime el nombre y una version semver" {
  run "$TK" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^api-toolkit\ [0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "--help sale con 0 y documenta init" {
  run "$TK" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"init"* ]]
}

@test "sin argumentos sale con 1 y dice que faltan" {
  run "$TK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"faltan argumentos"* ]]
}

@test "un subcomando desconocido sale con 1" {
  run "$TK" patch /get
  [ "$status" -eq 1 ]
  [[ "$output" == *"subcomando desconocido"* ]]
}

@test "un endpoint sin / se rechaza antes de llamar a curl" {
  run "$TK" get get
  [ "$status" -eq 1 ]
  [[ "$output" == *"tiene que empezar por /"* ]]
}

@test "--dry-run no imprime la credencial" {
  export AUTH_MODE=bearer API_TOKEN=valor-de-prueba
  run "$TK" --dry-run get /get
  [ "$status" -eq 0 ]
  [[ "$output" != *"valor-de-prueba"* ]]
}

@test "una API que no responde sale con 69" {
  export BASE_URL=http://127.0.0.1:9
  run "$TK" post /post '{}'
  [ "$status" -eq 69 ]
}

@test "get contra el laboratorio devuelve el cuerpo" {
  laboratorio
  run "$TK" get /get
  [ "$status" -eq 0 ]
  [[ "$output" == *'"url"'* ]]
}

# --- La configuracion --------------------------------------------------------

# TODO 4: escribe aqui, como minimo, cinco tests mas:
#   - init crea ~/.bc-curl con permisos 600 (usa la funcion permisos)
#   - init no pisa un archivo que ya existe: sale con 1 y el contenido sigue igual
#   - init no escribe los secretos que hay en el entorno
#   - la BASE_URL del archivo se usa (compruebalo con --dry-run)
#   - el entorno manda sobre el archivo
#   - un archivo de configuracion legible por otros se rechaza
