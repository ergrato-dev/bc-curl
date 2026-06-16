# Rubrica de Evaluacion - Semana 7

## Competencias evaluadas

### C1 - Manejo correcto de exit codes con -f

| Nivel | Descripcion |
|-------|-------------|
| 0 - No logrado | No sabe que curl retorna 0 en errores HTTP sin -f |
| 1 - Basico | Usa -f para obtener exit code 22 en errores HTTP |
| 2 - Competente | Captura exit code de curl y HTTP code por separado; usa --fail-with-body |
| 3 - Avanzado | Distingue en el script cada tipo de error (red, timeout, HTTP 4xx, HTTP 5xx) |

Evidencia esperada: ejercicio 01 con tabla de exit codes observados.

---

### C2 - jq para parsear respuestas

| Nivel | Descripcion |
|-------|-------------|
| 0 - No logrado | No puede extraer un campo de un JSON con jq |
| 1 - Basico | Extrae campos simples con `.campo` y `-r` |
| 2 - Competente | Itera arrays con `.[]`, usa `select()`, `map()` y `jq -n` |
| 3 - Avanzado | Combina filtros complejos, crea JSON con jq, usa `--arg` y `--argjson` |

Evidencia esperada: ejercicio 02 con todos los filtros pedidos funcionando.

---

### C3 - Loop robusto con error handling

| Nivel | Descripcion |
|-------|-------------|
| 0 - No logrado | El script falla o se detiene ante el primer error |
| 1 - Basico | Itera sobre lista y hace requests; no maneja errores |
| 2 - Competente | Captura errores por iteracion y continua con el siguiente elemento |
| 3 - Avanzado | Incluye sleep entre requests, logs de errores, contador de exitos/fallos |

Evidencia esperada: ejercicio 03 con archivo titulos.txt generado y script funcional.

---

### C4 - Script completo con estructura profesional

| Nivel | Descripcion |
|-------|-------------|
| 0 - No logrado | El script no ejecuta o no tiene subcomandos |
| 1 - Basico | Los subcomandos existen pero sin manejo de errores |
| 2 - Competente | Manejo de errores, mensajes de uso, exit codes correctos |
| 3 - Avanzado | Logging, validacion de argumentos, estructura de funciones clara |

Evidencia esperada: user-manager.sh con los tres subcomandos funcionando.

---

## Proyecto: API Sync

| Criterio | Puntos |
|----------|--------|
| Lee CSV y parsea campos correctamente | 15 |
| Verifica existencia via GET antes de crear | 20 |
| Crea registros nuevos via POST | 20 |
| Implementa retry con backoff en 429 | 20 |
| Reporte final: creados / existentes / errores | 15 |
| Estructura profesional (set -euo, funciones, logging) | 10 |

**Total: 100 puntos. Aprobacion: 60 puntos.**

### Nota sobre el proyecto

El proyecto usa `jsonplaceholder.typicode.com` como API destino. Esta API no
persiste datos (siempre retorna 200/201 sin guardar realmente), pero es suficiente
para demostrar la logica del script. El evaluador verificara la logica del codigo,
no el efecto en la API.
