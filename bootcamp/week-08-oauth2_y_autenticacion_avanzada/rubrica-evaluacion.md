# Rubrica de Evaluacion — Semana 8: OAuth2 y Autenticacion Avanzada

## Competencias Evaluadas

| Codigo | Competencia | Peso |
|--------|-------------|------|
| C1 | Client Credentials flow correcto | 25% |
| C2 | Token lifecycle management | 25% |
| C3 | Refresh token implementado | 25% |
| C4 | JWT decodificado e interpretado | 25% |

---

## C1 — Client Credentials Flow

**Descripcion**: El estudiante demuestra capacidad para obtener un token de acceso usando el flujo Client Credentials y utilizarlo correctamente en requests subsiguientes.

| Nivel | Descripcion | Puntos |
|-------|-------------|--------|
| 4 - Avanzado | Obtiene token, lo usa como Bearer, verifica status code, extrae campos del token con jq, maneja el caso de error en credenciales incorrectas | 100 |
| 3 - Competente | Obtiene token correctamente y lo usa como Bearer en al menos un request exitoso | 75 |
| 2 - Basico | Construye el request de token correctamente pero falla al usarlo o no verifica el resultado | 50 |
| 1 - Inicial | Entiende el concepto pero no logra completar el flujo funcional | 25 |
| 0 - No logrado | No entrega o el flujo no funciona | 0 |

Criterios especificos:
- POST al token endpoint con los parametros correctos (`grant_type`, `client_id`, `client_secret`)
- Header `Content-Type: application/x-www-form-urlencoded` presente
- Token extraido correctamente de la respuesta JSON
- Request subsiguiente incluye `Authorization: Bearer TOKEN`
- Se verifica que el request protegido devuelve 200 (no 401)

---

## C2 — Token Lifecycle Management

**Descripcion**: El estudiante implementa un sistema que persiste el token entre ejecuciones y verifica su vigencia antes de cada uso.

| Nivel | Descripcion | Puntos |
|-------|-------------|--------|
| 4 - Avanzado | Guarda token + expiracion, verifica antes de cada uso, renueva automaticamente, maneja errores de archivo | 100 |
| 3 - Competente | Guarda token en archivo, lo lee en ejecuciones siguientes, verifica expiracion | 75 |
| 2 - Basico | Guarda token en archivo pero no verifica expiracion | 50 |
| 1 - Inicial | Obtiene token en cada ejecucion sin persistencia | 25 |
| 0 - No logrado | No implementa gestion de token | 0 |

Criterios especificos:
- Token guardado en archivo con permisos restrictivos (600)
- Expiracion calculada y guardada junto al token
- Comparacion `exp` vs `date +%s` implementada
- Renovacion automatica al detectar expiracion proxima (margen de seguridad)

---

## C3 — Refresh Token

**Descripcion**: El estudiante implementa el flujo de renovacion de token usando refresh_token.

| Nivel | Descripcion | Puntos |
|-------|-------------|--------|
| 4 - Avanzado | Detecta 401 y renueva automaticamente, reintenta el request original, actualiza ambos tokens (access + refresh) | 100 |
| 3 - Competente | Implementa la renovacion por refresh_token correctamente cuando se solicita explicitamente | 75 |
| 2 - Basico | Construye el request de refresh correctamente pero no lo integra en un flujo automatico | 50 |
| 1 - Inicial | Conoce el endpoint pero no puede construir el request correcto | 25 |
| 0 - No logrado | No implementa refresh | 0 |

Criterios especificos:
- POST al token endpoint con `grant_type=refresh_token`
- `refresh_token` enviado en el body
- Nuevo `access_token` extraido y guardado
- El nuevo `refresh_token` (si lo devuelve el server) tambien actualizado

---

## C4 — JWT Inspeccion

**Descripcion**: El estudiante decodifica e interpreta un JWT sin herramientas externas usando comandos bash.

| Nivel | Descripcion | Puntos |
|-------|-------------|--------|
| 4 - Avanzado | Decodifica header y payload, extrae campos con jq, verifica expiracion, explica la firma y sus implicaciones de seguridad | 100 |
| 3 - Competente | Decodifica el payload correctamente e identifica campos `sub`, `iat`, `exp` | 75 |
| 2 - Basico | Logra decodificar el JWT pero no puede extraer campos especificos | 50 |
| 1 - Inicial | Identifica las tres partes del JWT pero no puede decodificar | 25 |
| 0 - No logrado | No puede trabajar con JWT | 0 |

Criterios especificos:
- Separacion del JWT en sus tres partes (header.payload.signature)
- Decodificacion base64url del payload
- Extraccion de `exp` y comparacion con timestamp actual
- Comprension de que la firma NO se verifica del lado del cliente sin la clave publica

---

## Evaluacion del Proyecto

El script `oauth-client.sh` se evalua sobre los cuatro criterios anteriores con peso igual.

Criterios adicionales para el proyecto:

- **Usabilidad** (bonus 10%): Los subcomandos `login`, `logout`, `call` funcionan de forma intuitiva con `--help` util
- **Robustez** (bonus 10%): Maneja errores de red, credenciales incorrectas y archivos de token corruptos sin romper

---

## Escala de Calificacion

| Puntaje | Calificacion |
|---------|--------------|
| 90-100 | Excelente — listo para produccion |
| 75-89 | Competente — puede usar OAuth2 de forma autonoma |
| 60-74 | Basico — necesita reforzar algun flujo |
| < 60 | Insuficiente — requiere rehacer ejercicios fundamentales |
