# Rubrica de Evaluacion - Semana 3

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
| C1 | Usa Basic Auth correctamente con `-u user:pass` y puede explicar el mecanismo |
| C2 | Envía API Key en header (no en query string) y explica la diferencia |
| C3 | Completa el flujo Bearer Token: login → token → request autenticado |
| C4 | Maneja credenciales de forma segura: variables de entorno, sin hardcodear |

---

## Conocimiento — 30%

### C1: Basic Auth

| Nivel | Descripción | Puntos |
|-------|-------------|--------|
| 4 - Excelente | Explica base64, por qué requiere HTTPS, diferencia 401 vs 403, cómo construir el header manualmente | 4 |
| 3 - Logrado | Explica `-u user:pass` y entiende que base64 no es cifrado | 3 |
| 2 - En desarrollo | Usa `-u` pero no puede explicar qué pasa internamente | 2 |
| 1 - Inicial | No puede autenticarse con curl | 1 |

### C2: API Keys

| Nivel | Descripción | Puntos |
|-------|-------------|--------|
| 4 - Excelente | Explica por qué el header es más seguro que query string, cuándo se usa API Key vs Basic Auth vs Bearer | 4 |
| 3 - Logrado | Usa API Key en header con `-H` y entiende la diferencia con query string | 3 |
| 2 - En desarrollo | Envía la key pero no distingue las dos formas | 2 |
| 1 - Inicial | No puede usar API Keys con curl | 1 |

### C3: Bearer Token

| Nivel | Descripción | Puntos |
|-------|-------------|--------|
| 4 - Excelente | Explica el flujo completo, qué contiene un JWT, qué es `exp`, por qué el payload es legible | 4 |
| 3 - Logrado | Completa el flujo login → token → request y puede decodificar el payload JWT | 3 |
| 2 - En desarrollo | Usa Bearer Token en header pero no entiende el flujo completo | 2 |
| 1 - Inicial | No puede usar Bearer Token | 1 |

---

## Desempeño — 40%

### Ejercicio 01: Basic Auth

| Criterio | Puntos máx |
|----------|-----------|
| Provoca 401 sin credenciales y lo documenta | 2 |
| Autentica correctamente con `-u` y recibe 200 | 2 |
| Ve el header `Authorization: Basic` con `-v` | 2 |
| Decodifica el header con base64 -d | 2 |
| Construye el header manualmente sin `-u` | 2 |

### Ejercicio 02: API Key

| Criterio | Puntos máx |
|----------|-----------|
| Envía API Key en header y verifica con httpbin | 2 |
| Compara header vs query string y documenta diferencia | 3 |
| Usa variables de entorno para la key | 2 |
| Script con verificación de variable | 3 |

### Ejercicio 03: Bearer Token

| Criterio | Puntos máx |
|----------|-----------|
| Login exitoso y extrae el token | 3 |
| Usa el token en request subsiguiente | 3 |
| Decodifica payload JWT con base64 | 2 |
| Identifica el campo `exp` | 2 |

### Ejercicio 04: Variables de entorno

| Criterio | Puntos máx |
|----------|-----------|
| Crea `.env` y `.env.example` | 2 |
| Agrega `.env` a `.gitignore` | 2 |
| Script con verificación de variables | 3 |
| Prueba con y sin variables definidas | 3 |

---

## Producto — 30%

### Script auth-check.sh

| Criterio | Puntos |
|----------|--------|
| Lee credenciales de variables de entorno | 4 |
| Verifica variables antes de empezar | 3 |
| Prueba Basic Auth correctamente | 3 |
| Prueba API Key en header | 3 |
| Prueba Bearer Token | 3 |
| Output claro con status de cada prueba | 4 |
| Resumen final con contador | 3 |
| Oculta credenciales en el output | 3 |
| Manejo de timeout y errores | 4 |

---

## Escala de calificacion

| Porcentaje | Calificacion |
|-----------|-------------|
| 90-100% | Sobresaliente |
| 75-89% | Notable |
| 60-74% | Aprobado |
| < 60% | Pendiente de revisión |
