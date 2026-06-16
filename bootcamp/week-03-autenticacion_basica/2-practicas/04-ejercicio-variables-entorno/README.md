# Ejercicio 04: Variables de entorno y seguridad

## Objetivo

Crear un script que lea credenciales de variables de entorno, valide que estén definidas antes de usarlas, y maneje el error correctamente cuando no lo están. Practicar el flujo seguro de manejo de credenciales.

---

## Tareas

### 1. Crear el archivo .env

```bash
# Crear el archivo de credenciales
cat > .env <<'EOF'
BASIC_USER=alumno
BASIC_PASS=secreto123
API_KEY=mi-api-key-de-prueba-bootcamp
BEARER_TOKEN=mi-bearer-token-de-prueba
EOF

# Verificar que se creó correctamente
cat .env
```

**Inmediatamente** agregar al .gitignore:

```bash
echo ".env" >> .gitignore
cat .gitignore
```

### 2. Crear el .env.example (este SÍ va en git)

```bash
cat > .env.example <<'EOF'
# Credenciales para auth-test.sh
# Copiar este archivo como .env y completar los valores reales
BASIC_USER=
BASIC_PASS=
API_KEY=
BEARER_TOKEN=
EOF
```

### 3. Cargar las variables y verificar

```bash
# Cargar el archivo .env
source .env

# Verificar sin imprimir el valor completo
echo "BASIC_USER: $BASIC_USER"
echo "API_KEY: ${API_KEY:0:6}****"
echo "BEARER_TOKEN: ${BEARER_TOKEN:0:4}****"
```

### 4. Crear el script auth-test.sh

```bash
cat > auth-test.sh <<'SCRIPT'
#!/bin/bash

# Verificar que las variables requeridas están definidas
check_var() {
    local var_name="$1"
    local var_value="${!var_name}"
    if [ -z "$var_value" ]; then
        echo "Error: la variable $var_name no está definida"
        echo "Cargá las credenciales con: source .env"
        return 1
    fi
    return 0
}

# Verificar todas las variables antes de empezar
check_var "BASIC_USER" || exit 1
check_var "BASIC_PASS" || exit 1
check_var "API_KEY" || exit 1
check_var "BEARER_TOKEN" || exit 1

echo "Todas las variables están definidas."
echo ""

# Prueba 1: Basic Auth
echo "=== Prueba 1: Basic Auth ==="
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -u "$BASIC_USER:$BASIC_PASS" \
    "https://httpbin.org/basic-auth/$BASIC_USER/$BASIC_PASS")
echo "Status Basic Auth: $STATUS"
echo ""

# Prueba 2: API Key en header
echo "=== Prueba 2: API Key ==="
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "X-API-Key: $API_KEY" \
    https://httpbin.org/headers)
echo "Status API Key: $STATUS"
curl -s -H "X-API-Key: $API_KEY" https://httpbin.org/headers | python3 -m json.tool | grep -i "api"
echo ""

# Prueba 3: Bearer Token
echo "=== Prueba 3: Bearer Token ==="
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $BEARER_TOKEN" \
    https://httpbin.org/bearer)
echo "Status Bearer Token: $STATUS"

SCRIPT
chmod +x auth-test.sh
```

### 5. Probar el script sin las variables definidas

```bash
# Descargar las variables del entorno actual
unset BASIC_USER BASIC_PASS API_KEY BEARER_TOKEN

# Intentar correr el script
./auth-test.sh
```

Debería fallar con un mensaje claro indicando qué variable falta.

### 6. Probar el script con las variables cargadas

```bash
# Cargar las variables del archivo .env
source .env

# Correr el script
./auth-test.sh
```

### 7. Probar con una sola variable faltante

```bash
source .env
unset API_KEY

./auth-test.sh
```

Debería identificar exactamente cuál variable está faltando.

---

## Bonus: verificar que .env no está en git

Si hay un repositorio git en el directorio:

```bash
# Ver qué archivos están siendo trackeados
git status

# .env NO debe aparecer en "Changes to be committed" ni en "Untracked files"
# .env.example SÍ debe aparecer o estar en el repo

# Verificar explícitamente que .gitignore está funcionando
git check-ignore -v .env
# Debería mostrar: .gitignore:1:.env  .env
```

---

## Preguntas para responder

1. ¿Por qué `${API_KEY:0:6}****` muestra solo los primeros 6 caracteres?
2. ¿Qué diferencia hay entre `unset VAR` y `export VAR=""`?
3. ¿Por qué `.env.example` sí va en git pero `.env` no?
4. ¿Qué pasa con las variables definidas con `export` cuando cerrás la terminal?

---

## Entrega

Archivo `respuestas.md` con:
1. El script `auth-test.sh` completo
2. Output del paso 5 (sin variables — fallo controlado)
3. Output del paso 6 (con variables — éxito)
4. Contenido del `.env.example`
5. Respuestas a las 4 preguntas
