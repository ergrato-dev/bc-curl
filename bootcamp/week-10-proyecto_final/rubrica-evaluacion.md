# Rubrica de Evaluacion — Semana 10: Proyecto Final

Esta semana evalua el proyecto api-toolkit en su totalidad. La rubrica tiene mayor peso en el producto terminado que en componentes individuales, reflejando que el objetivo es una herramienta completa y funcional.

## Peso por Area

| Area | Peso | Descripcion |
|------|------|-------------|
| Conocimiento | 20% | Comprension de las decisiones de diseno tomadas |
| Desempeno | 30% | Calidad del codigo (code review) |
| Producto | 50% | Funcionalidad completa y documentacion |

---

## Conocimiento (20%)

Evaluado mediante preguntas sobre el codigo entregado. El estudiante debe poder explicar:

| Criterio | Descripcion | Puntos max |
|----------|-------------|------------|
| K1 | Por que elegiste esa estructura de archivos/funciones? Cuales son los tradeoffs? | 25 |
| K2 | Como funciona el token lifecycle en tu implementacion? Que pasa si el archivo de token se corrompe? | 25 |
| K3 | Como implementaste el retry? Por que elegiste ese esquema de backoff? | 25 |
| K4 | Si esta herramienta se ejecutara en produccion en CI, que cambiarías o reforzarías? | 25 |

---

## Desempeno / Code Review (30%)

Evaluacion del codigo fuente de `api-toolkit.sh`:

| Criterio | Descripcion | Puntos max |
|----------|-------------|------------|
| D1 - Correcto | El codigo hace lo que dice que hace, sin bugs obvios | 30 |
| D2 - Seguro | No hay hardcoded secrets, permisos de archivo correctos, no se logean datos sensibles | 25 |
| D3 - Legible | Nombres de funciones y variables claros, comentarios donde es necesario | 25 |
| D4 - Sin repeticion | Funciones reutilizadas, no hay copy-paste de logica similar | 20 |

Ejemplo de problema en D1:
```bash
# Mal: si $token esta vacio, el request sigue sin auth
curl -H "Authorization: Bearer $token" "$url"

# Bien: verificar antes
[[ -z "$token" ]] && { echo "Error: no hay token" >&2; return 1; }
curl -H "Authorization: Bearer $token" "$url"
```

Ejemplo de problema en D2:
```bash
# Mal: el token aparece en el log del sistema
echo "Token: $ACCESS_TOKEN" >> requests.log

# Bien: redactar o no loguear el token completo
echo "Request: $METHOD $URL [auth: bearer]" >> requests.log
```

---

## Producto (50%)

Evaluacion de la funcionalidad real. Se prueba el script contra el servidor de demo.

### Subcomandos (30 puntos)

| Subcomando | Funciona | Maneja errores | Puntos |
|------------|----------|----------------|--------|
| `auth login` | | | 5 |
| `auth logout` | | | 3 |
| `auth status` | | | 4 |
| `get ENDPOINT` | | | 4 |
| `post ENDPOINT --data` | | | 4 |
| `put ENDPOINT --data` | | | 3 |
| `delete ENDPOINT` | | | 3 |
| `monitor FILE` | | | 2 |
| `bench ENDPOINT` | | | 2 |

### Features Transversales (20 puntos)

| Feature | Descripcion | Puntos |
|---------|-------------|--------|
| Token lifecycle | Token guardado, verificado y renovado automaticamente | 6 |
| Retry | Retry con backoff en 429 y 5xx | 4 |
| dry-run | `--dry-run` muestra el comando sin ejecutarlo | 3 |
| Logging | Requests logueados en `~/.api-toolkit/requests.log` | 2 |
| Exit codes | Exit codes correctos en todos los casos de error | 3 |
| --help | Ayuda completa y util para todos los subcomandos | 2 |

---

## Escala de Calificacion Final

Puntaje total = 20% Conocimiento + 30% Desempeno + 50% Producto

| Puntaje | Calificacion | Significado |
|---------|--------------|-------------|
| 90-100 | Excelente | La herramienta esta lista para uso en un equipo real |
| 75-89 | Competente | Funciona bien, con algunas mejoras de calidad pendientes |
| 60-74 | Basico | La mayoria de los subcomandos funcionan, falta robustez |
| 45-59 | Insuficiente | Funcionalidad parcial, no cumple los requisitos del proyecto |
| < 45 | No aprobado | Requiere rehacer el proyecto |

---

## Criterios de Aprobacion del Bootcamp

Para aprobar el bootcamp (semanas 1-10), se requiere:
- Semana 10: puntaje >= 60
- Semanas 1-9: promedio >= 60 (ninguna semana por debajo de 45)
- Los 4 ejercicios practicos de la semana 10 entregados

---

## Nota sobre Originalidad

Se espera que el codigo sea propio. Es valido:
- Reutilizar funciones propias de semanas anteriores
- Consultar la documentacion de curl, bash y herramientas
- Usar fragmentos de codigo del material del curso como punto de partida

No es valido:
- Entregar el starter code sin modificaciones sustanciales
- Copiar codigo de otro estudiante
- Usar herramientas de generacion de codigo para el proyecto completo sin entenderlo
