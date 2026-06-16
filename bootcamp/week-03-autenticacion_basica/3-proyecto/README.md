# Proyecto Semana 3: Auth Explorer

## Descripcion

Vas a crear un script `auth-check.sh` que prueba los tres mecanismos de autenticación (Basic Auth, API Key y Bearer Token) contra endpoints reales y reporta el resultado de cada uno. El output debe ser claro: cada prueba indica si tuvo éxito o falla, el status code obtenido, y un mensaje descriptivo.

---

## Requerimientos

El script:
1. Lee todas las credenciales de variables de entorno (nunca hardcodeadas)
2. Verifica que las variables estén definidas antes de empezar
3. Prueba Basic Auth contra `httpbin.org/basic-auth/{user}/{pass}`
4. Prueba API Key en header contra `httpbin.org/headers`
5. Prueba Bearer Token contra `httpbin.org/bearer`
6. Imprime un reporte claro al final

---

## Output esperado

```
Auth Explorer - bc-curl bootcamp
================================

[1/3] Basic Auth
  Usuario: alumno
  URL: https://httpbin.org/basic-auth/alumno/secreto123
  Status: 200
  Resultado: OK - autenticación exitosa

[2/3] API Key (header X-API-Key)
  Key: mi-api****
  URL: https://httpbin.org/headers
  Status: 200
  Resultado: OK - key presente en headers

[3/3] Bearer Token
  Token: mi-be****
  URL: https://httpbin.org/bearer
  Status: 200
  Resultado: OK - token aceptado

================================
Resumen: 3/3 pruebas exitosas
```

---

## Estructura sugerida

```bash
#!/bin/bash

# Función para verificar variables de entorno
check_vars() { ... }

# Función para imprimir resultados
print_result() {
    local num="$1"
    local name="$2"
    local status="$3"
    local detail="$4"

    if [ "$status" = "200" ] || [ "$status" = "201" ]; then
        echo "  Resultado: OK - $detail"
        return 0
    else
        echo "  Resultado: FALLO - Status $status"
        return 1
    fi
}

# Variables globales para el contador de éxitos
TOTAL=3
EXITOSOS=0

# Prueba 1: Basic Auth
# Prueba 2: API Key
# Prueba 3: Bearer Token

# Resumen final
echo "================================"
echo "Resumen: $EXITOSOS/$TOTAL pruebas exitosas"
```

---

## Variables de entorno requeridas

```bash
# En tu archivo .env
BASIC_USER=alumno
BASIC_PASS=secreto123
API_KEY=mi-api-key-de-prueba
BEARER_TOKEN=cualquier-string-para-httpbin
```

Ejecutar con:
```bash
source .env && ./auth-check.sh
```

---

## Criterios de evaluacion

### Lo mínimo (aprobado)

- [ ] El script lee credenciales de variables de entorno
- [ ] Prueba los 3 mecanismos de auth
- [ ] Imprime el status code de cada uno
- [ ] Verifica si fue exitoso o no

### Completo (notable)

- [ ] Verifica que las variables estén definidas antes de empezar
- [ ] El output es claro y bien formateado
- [ ] Muestra un resumen final con contador
- [ ] Oculta parcialmente las credenciales en el output (primeros 4 chars + ****)

### Destacado (sobresaliente)

- [ ] Agrega manejo de timeout (`--max-time 5`) con mensaje de error específico
- [ ] Agrega prueba de Basic Auth con credenciales incorrectas (verifica que el 401 es correcto)
- [ ] El script acepta un argumento `--verbose` para mostrar el body completo de las respuestas
- [ ] Genera un archivo `auth-report.txt` con los resultados y la fecha/hora

---

## Entrega

En la carpeta `starter/`:

- `auth-check.sh` — el script completo
- `.env.example` — con los nombres de las variables pero sin valores
- `respuestas.md` — output completo de una ejecución exitosa y una fallida (con alguna variable faltante)
