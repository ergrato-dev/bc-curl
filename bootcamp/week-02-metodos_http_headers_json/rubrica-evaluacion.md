# Rubrica de Evaluacion - Semana 2

## Distribución de puntaje

| Área | Porcentaje |
|------|-----------|
| Conocimiento (saber) | 30% |
| Desempeño (hacer) | 40% |
| Producto (entregar) | 30% |

---

## Competencias evaluadas

| Código | Competencia |
|--------|-------------|
| C1 | Realiza POST con JSON correctamente (Content-Type + body válido) |
| C2 | Completa ciclo CRUD (GET, POST, PUT, PATCH, DELETE) verificando status codes |
| C3 | Usa headers custom con `-H` y verifica su llegada con httpbin |
| C4 | Lee y envía JSON desde archivos externos con `-d @archivo` |

---

## Conocimiento — 30%

### C1: POST con JSON

| Nivel | Descripción | Puntos |
|-------|-------------|--------|
| 4 - Excelente | Explica qué hace `-d`, por qué Content-Type es obligatorio, diferencia entre string y `@archivo` | 4 |
| 3 - Logrado | Explica el flag `-d` y la necesidad del Content-Type | 3 |
| 2 - En desarrollo | Sabe que POST necesita body pero confunde los flags | 2 |
| 1 - Inicial | No puede explicar cómo enviar datos con curl | 1 |

### C2: Diferencia PUT vs PATCH

| Nivel | Descripción | Puntos |
|-------|-------------|--------|
| 4 - Excelente | Explica idempotencia, cuándo usar cada uno, y qué pasa si omitís campos en PUT | 4 |
| 3 - Logrado | Distingue correctamente PUT (total) de PATCH (parcial) | 3 |
| 2 - En desarrollo | Sabe que son para actualizar pero los confunde | 2 |
| 1 - Inicial | No distingue PUT de PATCH | 1 |

### C3: Headers HTTP

| Nivel | Descripción | Puntos |
|-------|-------------|--------|
| 4 - Excelente | Explica la diferencia entre Content-Type y Accept, para qué sirve User-Agent, cómo se usa `-H` | 4 |
| 3 - Logrado | Sabe usar `-H` y entiende Content-Type y Accept | 3 |
| 2 - En desarrollo | Usa `-H` pero no entiende bien qué hace cada header | 2 |
| 1 - Inicial | No puede usar headers con curl | 1 |

---

## Desempeño — 40%

### Ejercicio 01: POST

| Criterio | Puntos máx |
|----------|-----------|
| Realiza POST con JSON y recibe 201 | 2 |
| Usa httpbin para verificar que el body llegó | 2 |
| Envía body desde archivo con `-d @` | 2 |

### Ejercicio 02: CRUD completo

| Criterio | Puntos máx |
|----------|-----------|
| GET correcto con status 200 | 1 |
| POST correcto con status 201 | 2 |
| PUT con todos los campos y status 200 | 2 |
| PATCH con campo parcial y status 200 | 2 |
| DELETE con status 200/204 | 1 |
| Explica diferencia en respuesta entre PUT y PATCH | 2 |

### Ejercicio 03: Headers

| Criterio | Puntos máx |
|----------|-----------|
| Agrega headers custom con `-H` | 2 |
| Cambia User-Agent y verifica con httpbin | 2 |
| Experimenta con Accept y observa diferencias | 2 |

### Ejercicio 04: JSON desde archivo

| Criterio | Puntos máx |
|----------|-----------|
| Crea archivo JSON válido | 1 |
| Envía con `-d @archivo` correctamente | 2 |
| Guarda respuesta en archivo con `-o` | 2 |
| Formatea respuesta con python3 -m json.tool | 1 |

---

## Producto — 30%

### Script crud.sh

| Criterio | Puntos |
|----------|--------|
| El script es ejecutable | 2 |
| Subcomando `list` funciona | 3 |
| Subcomando `get ID` funciona | 3 |
| Subcomando `create` funciona | 3 |
| Subcomandos `update`, `patch`, `delete` funcionan | 6 |
| El script muestra status code | 3 |
| Respuesta JSON formateada | 2 |
| Manejo de errores (sin ID, sin argumentos) | 4 |
| Subcomando `help` | 4 |

---

## Escala de calificacion

| Porcentaje | Calificacion |
|-----------|-------------|
| 90-100% | Sobresaliente |
| 75-89% | Notable |
| 60-74% | Aprobado |
| < 60% | Pendiente de revisión |
