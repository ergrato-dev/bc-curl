# Proyecto Semana 5: SSL & Session Checker

## Descripcion

Crear un script `session.sh` que implementa un cliente con sesión persistente. El script simula el flujo completo de una aplicación que:

1. Hace "login" (el servidor setea cookies de sesión)
2. Mantiene la sesión en un archivo local
3. Hace requests autenticados usando esa sesión
4. Tiene configuración de timeout y retry robusta
5. Puede hacer "logout" (borra el archivo de sesión)

Usa `https://httpbin.org` como backend simulado.

---

## Subcomandos requeridos

### login

Inicia sesión: hace request al endpoint de login, guarda las cookies en `~/.session-checker/sesion.txt`.

```bash
./session.sh login usuario contraseña
```

Comportamiento:
- Crea el directorio `~/.session-checker/` si no existe
- Hace POST a `https://httpbin.org/cookies/set?user=USUARIO&logged_in=true` con `-c`
- Imprime confirmación de login exitoso
- Si ya hay sesión activa, preguntar si reemplazar

### status

Verifica si hay sesión activa y muestra la información de la sesión actual.

```bash
./session.sh status
```

Comportamiento:
- Revisa si existe `~/.session-checker/sesion.txt`
- Si existe, hace GET a `https://httpbin.org/cookies` con `-b` y muestra las cookies activas
- Si no existe, imprime "Sin sesión activa"

### get URL

Hace un GET autenticado a la URL indicada, usando la sesión guardada.

```bash
./session.sh get https://httpbin.org/get
./session.sh get https://httpbin.org/headers
```

Comportamiento:
- Falla con error si no hay sesión activa
- Usa `--connect-timeout 5 --max-time 30 --retry 3 --retry-delay 2`
- Imprime la respuesta formateada con `python3 -m json.tool`
- Imprime el tiempo total del request al final

### logout

Cierra la sesión borrando el archivo de cookies.

```bash
./session.sh logout
```

Comportamiento:
- Borra `~/.session-checker/sesion.txt`
- Imprime confirmación de logout

---

## Estructura del script

```bash
#!/bin/bash
# session.sh - Cliente con sesión persistente

set -e

SESSION_DIR="$HOME/.session-checker"
SESSION_FILE="$SESSION_DIR/sesion.txt"
BASE_URL="https://httpbin.org"

CURL_OPTS="--connect-timeout 5 --max-time 30 --retry 3 --retry-delay 2"

cmd_login() { ... }
cmd_status() { ... }
cmd_get() { ... }
cmd_logout() { ... }

case "$1" in
    login)   cmd_login "$2" "$3" ;;
    status)  cmd_status ;;
    get)     cmd_get "$2" ;;
    logout)  cmd_logout ;;
    *)       echo "Uso: $0 {login|status|get|logout}"; exit 1 ;;
esac
```

---

## Flujo de prueba esperado

```bash
# Sin sesión
./session.sh status
# Sin sesion activa

# Login
./session.sh login ana secreto
# Login exitoso como 'ana'

# Verificar sesión
./session.sh status
# Sesion activa: usuario=ana, logged_in=true

# Request autenticado
./session.sh get https://httpbin.org/get
# { ... respuesta formateada ... }
# Tiempo total: 0.234s

# Logout
./session.sh logout
# Sesion cerrada

# Sin sesión de nuevo
./session.sh get https://httpbin.org/get
# Error: no hay sesion activa. Ejecuta './session.sh login usuario contraseña' primero
```

---

## Criterios de evaluacion

| Criterio | Puntos |
|----------|--------|
| `login` guarda cookies con `-c` correctamente | 20 |
| `status` verifica sesión y muestra cookies con `-b` | 15 |
| `get` falla con mensaje claro si no hay sesión | 15 |
| `get` usa todos los flags de timeout y retry | 20 |
| `get` imprime tiempo total del request | 10 |
| `logout` borra el archivo de sesión | 10 |
| Manejo de errores y mensajes de uso claros | 10 |

**Total: 100 puntos**

---

## Entrega

Archivo `session.sh` en esta carpeta con permisos de ejecución (`chmod +x session.sh`).

Archivo `demo.md` con el output completo del flujo de prueba descrito arriba.

---

## Pistas

Para obtener el tiempo total de un request con curl:

```bash
TIEMPO=$(curl $CURL_OPTS -s -o respuesta.json -w "%{time_total}" "$URL")
cat respuesta.json | python3 -m json.tool
echo "Tiempo total: ${TIEMPO}s"
```

Para verificar si existe el archivo de sesión:

```bash
if [ ! -f "$SESSION_FILE" ]; then
    echo "Error: no hay sesion activa."
    exit 1
fi
```

Para crear directorio si no existe:

```bash
mkdir -p "$SESSION_DIR"
```
