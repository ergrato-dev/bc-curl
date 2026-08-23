# Rúbrica de Evaluación - Semana 5

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
| C1 | Verifica y entiende certificados SSL/TLS; sabe cuándo y por qué NO usar `-k` |
| C2 | Completa el flujo de cookies: guardar con `-c`, reenviar con `-b`, inspeccionar el archivo |
| C3 | Controla el seguimiento de redirects con `-L` y `--max-redirs` |
| C4 | Configura timeouts (`--connect-timeout`, `--max-time`) y reintentos (`--retry`) correctamente |

---

## Conocimiento — 30%

### C1: SSL/TLS y certificados

| Nivel | Descripción | Puntos |
|-------|-------------|--------|
| 4 - Excelente | Explica la diferencia entre `--cacert`, `--cert` y `-k`; cuándo usar cada uno; qué es mTLS y en qué contextos se requiere | 4 |
| 3 - Logrado | Entiende por qué curl valida certificados, sabe usar `--cacert` para CAs personalizadas y reconoce cuándo `-k` es un riesgo | 3 |
| 2 - En desarrollo | Sabe que `-k` desactiva la validación pero no puede explicar la diferencia con `--cacert` | 2 |
| 1 - Inicial | No puede explicar qué valida curl en una conexión HTTPS | 1 |

### C2: Cookies

| Nivel | Descripción | Puntos |
|-------|-------------|--------|
| 4 - Excelente | Explica el formato del archivo cookie jar, la diferencia entre session cookies y persistentes, y los atributos HttpOnly/Secure/SameSite | 4 |
| 3 - Logrado | Usa `-c` para guardar y `-b` para reenviar cookies; puede combinarlos para mantener sesión entre requests | 3 |
| 2 - En desarrollo | Puede enviar una cookie con `-b "clave=valor"` pero no entiende el ciclo completo con archivo | 2 |
| 1 - Inicial | No puede manejar cookies con curl | 1 |

### C3: Redirects

| Nivel | Descripción | Puntos |
|-------|-------------|--------|
| 4 - Excelente | Explica los códigos 301/302/307/308 y su semántica respecto al método HTTP; cuándo usar `--post301`; riesgo de `--location-trusted` | 4 |
| 3 - Logrado | Usa `-L` correctamente y entiende para qué sirve `--max-redirs`; sabe que curl no sigue redirects por defecto | 3 |
| 2 - En desarrollo | Sabe que `-L` existe pero no puede explicar qué pasa sin él | 2 |
| 1 - Inicial | No sabe cómo curl maneja los redirects | 1 |

---

## Desempeño — 40%

### Ejercicio 01: SSL

| Criterio | Puntos máx |
|----------|-----------|
| Inspecciona certificado de una API real con `-v` | 2 |
| Ve las fechas del certificado con openssl o `-v` | 2 |
| Demuestra el error con un cert auto-firmado sin `--cacert` | 2 |
| Usa `-k` y explica el riesgo | 2 |
| Verifica `%{ssl_verify_result}` y entiende el valor 0 | 2 |

### Ejercicio 02: Cookies

| Criterio | Puntos máx |
|----------|-----------|
| Guarda cookies con `-c` y lee el archivo | 3 |
| Reenvía cookies con `-b` y verifica que el servidor las recibe | 3 |
| Acumula múltiples cookies con `-b archivo -c archivo` | 2 |
| Envía cookie manual con `-b "clave=valor"` | 2 |

### Ejercicio 03: Redirects

| Criterio | Puntos máx |
|----------|-----------|
| Observa un redirect sin seguirlo y lee el status | 2 |
| Sigue redirects con `-L` y documenta la cadena | 3 |
| Usa `--max-redirs` y verifica el error al superarlo | 3 |
| Obtiene URL de destino con `%{redirect_url}` | 2 |

### Ejercicio 04: Timeouts

| Criterio | Puntos máx |
|----------|-----------|
| Fuerza timeout con `--max-time` y lee el exit code 28 | 3 |
| Usa `--connect-timeout` con host inaccesible | 3 |
| Configura `--retry` con `--retry-all-errors` | 2 |
| Crea script con backoff exponencial | 2 |

---

## Producto — 30%

### Script session.sh

| Criterio | Puntos |
|----------|--------|
| Subcomando `login` guarda cookies con `-c` | 5 |
| Subcomando `status` muestra cookies activas con `-b` | 5 |
| Subcomando `get` usa la sesión para requests autenticados | 5 |
| Subcomando `get` falla con mensaje claro si no hay sesión | 5 |
| Todos los requests usan `--connect-timeout` y `--max-time` | 5 |
| Subcomando `logout` borra el archivo de sesión | 3 |
| Manejo de errores y mensajes de uso | 4 |
| `demo.md` con flujo completo documentado | 4 |

---

## Escala de calificacion

| Porcentaje | Calificación |
|-----------|-------------|
| 90-100% | Sobresaliente |
| 75-89% | Notable |
| 60-74% | Aprobado |
| < 60% | Pendiente de revisión |
