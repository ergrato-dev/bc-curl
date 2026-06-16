# Rubrica de Evaluacion - Semana 6

## Competencias evaluadas

### C1 - Uso de --write-out con multiples variables

| Nivel | Descripcion |
|-------|-------------|
| 0 - No logrado | No usa --write-out o solo extrae una variable |
| 1 - Basico | Extrae http_code o time_total de forma aislada |
| 2 - Competente | Combina 3 o mas variables en un formato personalizado |
| 3 - Avanzado | Formato legible, escribe output a stderr, aplica en script funcional |

Evidencia esperada: ejercicio 01 completado con tabla de metricas.

---

### C2 - Depuracion con verbose y trace

| Nivel | Descripcion |
|-------|-------------|
| 0 - No logrado | No sabe diferenciar -v de --trace |
| 1 - Basico | Usa -v y puede leer los headers en el output |
| 2 - Competente | Genera un trace-ascii, identifica las fases del protocolo |
| 3 - Avanzado | Compara traces HTTP/1.1 vs HTTP/2, identifica donde ocurre un error |

Evidencia esperada: ejercicio 02 con archivo de trace anotado.

---

### C3 - Configuracion con .curlrc

| Nivel | Descripcion |
|-------|-------------|
| 0 - No logrado | No sabe que existe .curlrc |
| 1 - Basico | Crea ~/.curlrc con al menos una opcion |
| 2 - Competente | Tiene curlrc global con opciones utiles y curlrc local para un proyecto |
| 3 - Avanzado | Sabe hacer override desde CLI, entiende la precedencia |

Evidencia esperada: ejercicio 03 con ambos archivos curlrc y demo de override.

---

### C4 - Script de metricas funcional

| Nivel | Descripcion |
|-------|-------------|
| 0 - No logrado | El script no ejecuta o no produce output correcto |
| 1 - Basico | Hace requests en loop y muestra tiempos |
| 2 - Competente | Calcula promedio, minimo y maximo correctamente |
| 3 - Avanzado | Maneja errores de red, formato de salida claro, comentado |

Evidencia esperada: benchmark.sh funcionando con output de estadisticas.

---

## Proyecto: API Monitor

| Criterio | Puntos |
|----------|--------|
| Lee URLs desde archivo | 20 |
| Muestra status code + tiempo para cada URL | 20 |
| Clasifica OK / WARN / ERROR correctamente | 25 |
| Genera resumen al final | 20 |
| Sin dependencias externas (solo curl + bash) | 15 |

**Total: 100 puntos. Aprobacion: 60 puntos.**

### Clasificacion recomendada para el proyecto

- **OK**: HTTP 2xx, tiempo < 1 segundo
- **WARN**: HTTP 3xx, o tiempo entre 1 y 3 segundos
- **ERROR**: HTTP 4xx/5xx, timeout, o error de red
