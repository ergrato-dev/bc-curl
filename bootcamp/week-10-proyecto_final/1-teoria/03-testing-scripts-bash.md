# Testing de scripts bash con bats-core

[← 02: Configuracion persistente](02-configuracion-persistente.md) | [→ 04: Documentacion CLI](04-documentacion-cli.md)

---

## Por que testear scripts bash

Los scripts bash suelen crecer sin tests porque "se ve que funciona". Pero un script sin tests es fragil: cualquier cambio puede romper algo que funcionaba, y no te enteras hasta que falla en produccion.

Para `api-toolkit`, tests bien escritos permiten:
- Refactorizar con confianza
- Verificar que el manejo de errores funciona
- Probar casos borde sin hacer requests reales a una API
- Integrar en CI/CD para que el pipeline valide cada cambio

---

## bats-core: Bash Automated Testing System

`bats` es el framework de testing estandar para bash. Instalar:

```bash
# Ubuntu/Debian
sudo apt install bats

# macOS con Homebrew
brew install bats-core

# Sin instalacion (descarga directa)
git clone https://github.com/bats-core/bats-core.git
./bats-core/bin/bats test/
```

Verificar instalacion:

```bash
bats --version
# Bats 1.10.0
```

---

## Estructura de un archivo de tests

```bash
# test/test_api_toolkit.bats

#!/usr/bin/env bats

# setup() se ejecuta ANTES de cada test
setup() {
  # Variables de entorno para tests
  export BASE_URL="https://httpbin.org"
  export AUTH_TYPE="none"

  # Directorio de config aislado para cada test
  export CONFIG_DIR="/tmp/test-config-$$"
  mkdir -p "$CONFIG_DIR"

  # Ruta al script bajo test
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/api-toolkit.sh"
}

# teardown() se ejecuta DESPUES de cada test (aunque falle)
teardown() {
  rm -rf "$CONFIG_DIR"
}

# Cada test empieza con @test "descripcion"
@test "muestra version con --version" {
  run bash "$SCRIPT" --version
  [ "$status" -eq 0 ]
  [[ "$output" == "1.0.0" ]]
}

@test "muestra ayuda con --help" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Uso:"* ]]
  [[ "$output" == *"Comandos:"* ]]
}

@test "cmd_get retorna status 200" {
  run bash "$SCRIPT" get /get
  [ "$status" -eq 0 ]
  [[ "$output" == *'"url"'* ]]
}

@test "muestra error si BASE_URL no esta configurada" {
  unset BASE_URL
  run bash "$SCRIPT" get /anything
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]] || [[ "$stderr" == *"ERROR"* ]]
}

@test "comando desconocido retorna exit code 1" {
  run bash "$SCRIPT" no-existe
  [ "$status" -ne 0 ]
}

@test "--dry-run muestra el comando curl sin ejecutarlo" {
  run bash "$SCRIPT" --dry-run get /anything
  [ "$status" -eq 0 ]
  # Debe contener "curl" en el output (es el comando que se ejecutaria)
  [[ "$output" == *"curl"* ]]
}
```

### La variable `$output`

Cuando usas `run comando`, bats captura stdout en `$output` y el exit code en `$status`. Para capturar stderr por separado, usa `run --separate-stderr`:

```bash
@test "errores van a stderr" {
  run --separate-stderr bash "$SCRIPT" get /anything
  [[ "$stderr" == *"[ERROR]"* ]] || true  # condicional
}
```

### Aserciones comunes

```bash
# Exit code exacto
[ "$status" -eq 0 ]
[ "$status" -ne 0 ]
[ "$status" -eq 1 ]

# Contenido del output
[[ "$output" == *"texto esperado"* ]]  # contiene
[[ "$output" != *"texto inesperado"* ]]  # no contiene
[[ "$output" == "texto exacto" ]]  # igualdad exacta

# Lineas especificas (bats lo divide en array $lines)
[ "${lines[0]}" = "primera linea esperada" ]
[ "${#lines[@]}" -gt 3 ]  # al menos 4 lineas de output
```

---

## Mock de curl para tests rapidos

Los tests que hacen requests reales a internet son lentos e impredecibles (fallan si no hay internet). Para tests unitarios, es mejor mockear `curl`:

```bash
setup() {
  export BASE_URL="https://api.ejemplo.com"
  export CONFIG_DIR="/tmp/test-config-$$"
  mkdir -p "$CONFIG_DIR"

  # Crear un directorio temporal con el mock de curl
  export MOCK_BIN="/tmp/test-bin-$$"
  mkdir -p "$MOCK_BIN"

  cat > "${MOCK_BIN}/curl" <<'EOF'
#!/bin/bash
# Mock de curl: responde JSON fijo para cualquier request
# Simula los flags que usa api-toolkit
while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--write-out) shift; FORMAT="$1" ;;
    -o|--output) shift ;;  # ignorar
    *) ;;
  esac
  shift
done

# Respuesta simulada
echo '{"id": 1, "name": "Test User", "email": "test@ejemplo.com"}'
exit 0
EOF
  chmod +x "${MOCK_BIN}/curl"

  # Poner el mock PRIMERO en el PATH
  export PATH="${MOCK_BIN}:${PATH}"
}

teardown() {
  rm -rf "$CONFIG_DIR" "${MOCK_BIN}"
}

@test "cmd_get parsea respuesta correctamente" {
  run bash "$SCRIPT" get /users/1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Test User"* ]]
}
```

### Mock de curl con respuesta variable

Para tests mas sofisticados, el mock puede inspeccionar los argumentos:

```bash
cat > "${MOCK_BIN}/curl" <<'EOF'
#!/bin/bash
# Leer todos los argumentos y responder segun la URL
URL=""
for arg in "$@"; do
  case "$arg" in
    http*) URL="$arg" ;;
  esac
done

if [[ "$URL" == *"/users"* ]]; then
  echo '[{"id":1,"name":"Ana"},{"id":2,"name":"Bob"}]'
elif [[ "$URL" == *"/health"* ]]; then
  echo '{"status":"ok"}'
else
  echo '{"error":"not found"}' >&2
  exit 22  # curl exit code para HTTP error
fi
EOF
```

---

## Organizacion de tests

```
test/
├── test_estructura.bats      # --help, --version, dispatcher
├── test_config.bats          # load_config, init_config
├── test_auth.bats            # login, logout, status (con mock)
├── test_requests.bats        # get, post, put, delete (con mock)
├── test_features.bats        # monitor, bench
└── fixtures/
    ├── urls.txt              # lista de URLs para test de monitor
    └── response_users.json   # respuestas JSON de ejemplo
```

Ejecutar todos los tests:

```bash
bats test/
```

Ejecutar un archivo especifico:

```bash
bats test/test_requests.bats
```

Ejecutar con output detallado:

```bash
bats --verbose-run test/
```

---

## CI con GitHub Actions

```yaml
# .github/workflows/test.yml
name: Tests

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Instalar dependencias
        run: |
          sudo apt-get update
          sudo apt-get install -y bats jq curl

      - name: Verificar sintaxis del script
        run: bash -n api-toolkit.sh

      - name: Ejecutar tests
        run: bats test/

      - name: Test de integracion contra httpbin
        run: |
          export BASE_URL="https://httpbin.org"
          bash api-toolkit.sh get /get | jq -e '.url'
```

### `bash -n`: verificacion de sintaxis sin ejecutar

Antes de correr los tests, verificar que el script no tiene errores de sintaxis:

```bash
bash -n api-toolkit.sh && echo "Sintaxis OK" || echo "Error de sintaxis"
```

Esto es rapido (no ejecuta nada) y atrapa errores basicos como parentesis sin cerrar.

---

## Tests de integracion vs tests unitarios

| Tipo | Velocidad | Usa internet | Cuando usarlo |
|------|-----------|--------------|---------------|
| Unitario (mock curl) | Rapido | No | Cada push, en CI siempre |
| Integracion (API real) | Lento | Si | En CI, pero puede fallar por razones externas |
| Smoke test post-deploy | Muy rapido | Si | Despues de cada deploy |

Para `api-toolkit`, la estrategia recomendada:
1. Tests unitarios con mock para la logica interna (auth, retry, parsing)
2. Un test de integracion contra JSONPlaceholder o httpbin para verificar el flujo completo
3. El smoke test lo corre el deploy pipeline

---

## Siguiente

[→ 04: Documentacion CLI](04-documentacion-cli.md) — como documentar tu herramienta para que otros (y tu del futuro) la puedan usar.
