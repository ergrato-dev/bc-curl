# Rubrica de Evaluacion - Semana 1

## HTTP y curl básico

---

## Competencias a Evaluar

| Competencia | Descripción |
|-------------|-------------|
| **C1** | Instalar y verificar curl, explorar la ayuda |
| **C2** | Hacer peticiones GET e interpretar respuestas |
| **C3** | Usar los flags esenciales: -v, -i, -I, -o, -s, -L |
| **C4** | Leer e identificar status codes HTTP |

---

## Conocimiento (30%)

### Cuestionario Teórico (20%)

| Criterio | Excelente (100%) | Bueno (80%) | Suficiente (70%) | Insuficiente (<70%) |
|----------|------------------|-------------|------------------|---------------------|
| HTTP request/response | Explica ciclo completo con componentes | Explica el flujo general | Sabe que hay request y response | No comprende el flujo |
| Anatomía URL | Identifica los 5 componentes correctamente | Identifica 4 componentes | Identifica esquema, host y path | No identifica componentes |
| Flags curl | Explica y usa correctamente los 6 flags | Explica 5 de 6 flags | Explica 4 de 6 flags | Explica menos de 4 flags |
| Status codes | Conoce los 5 grupos y 8 códigos específicos | Conoce los 5 grupos y 5 códigos | Conoce 2xx, 4xx, 5xx | No conoce los grupos |

### Identificación de Errores (10%)

| Criterio | Puntos |
|----------|--------|
| Identifica 5/5 problemas en comandos curl dados | 100% |
| Identifica 4/5 problemas | 80% |
| Identifica 3/5 problemas | 70% |
| Identifica menos de 3 | <70% |

---

## Desempeño (40%)

### Ejercicios Prácticos

| Ejercicio | Peso | Criterios |
|-----------|------|-----------|
| **01 - Instalación** | 8% | curl instalado, version >= 7.x, exploración de --help documentada |
| **02 - GET básico** | 10% | 3 APIs consultadas, respuestas documentadas, comparación de headers |
| **03 - Flags** | 12% | Los 6 flags usados correctamente con ejemplos reales |
| **04 - Status codes** | 10% | Todos los status codes provocados y capturados, script funcional |

### Criterios por Ejercicio

| Nivel | Descripción | Porcentaje |
|-------|-------------|------------|
| **Excelente** | Comandos correctos, output documentado, análisis propio | 100% |
| **Bueno** | Comandos correctos, output documentado | 80% |
| **Suficiente** | Comandos con errores menores, output parcial | 70% |
| **Insuficiente** | Comandos incorrectos o sin output | <70% |

---

## Producto (30%)

### Proyecto: API Explorer

| Criterio | Peso | Excelente (100%) | Bueno (80%) | Suficiente (70%) | Insuficiente (<70%) |
|----------|------|------------------|-------------|------------------|---------------------|
| **Funcionalidad** | 12% | Script funciona, muestra las 3 URLs con todos los datos | Funciona con 2 URLs o datos incompletos | Funciona con 1 URL | No funciona |
| **Status code** | 6% | Capturado con -w, mostrado correctamente | Capturado pero formato incorrecto | Hardcodeado o ausente | No presente |
| **Tiempo respuesta** | 6% | Capturado con %{time_total}, mostrado en segundos | Capturado, formato incorrecto | No capturado | No presente |
| **Resumen final** | 3% | Cuenta correcta de 2xx | Cuenta pero incorrecto | Presente pero no funciona | Ausente |
| **Código limpio** | 3% | Variables nombradas bien, sin código muerto | Legible | Funcional | Ilegible |

---

## Checklist de Entrega

- [ ] `2-practicas/01-ejercicio-instalacion/respuestas.md` completado
- [ ] `2-practicas/02-ejercicio-get-basico/respuestas.md` completado
- [ ] `2-practicas/03-ejercicio-flags/respuestas.md` completado
- [ ] `2-practicas/04-ejercicio-status-codes/respuestas.md` completado
- [ ] `3-proyecto/starter/api-explorer.sh` implementado y funcional
- [ ] Script ejecuta sin errores con `bash api-explorer.sh`
- [ ] Alcanzar mínimo 70% en cada tipo de evidencia

---

## Escala de Calificacion

| Calificación | Rango | Descripción |
|--------------|-------|-------------|
| **Sobresaliente** | 90-100% | Supera expectativas |
| **Notable** | 80-89% | Cumple todos los requisitos |
| **Aprobado** | 70-79% | Cumple requisitos mínimos |
| **No Aprobado** | <70% | No cumple requisitos mínimos |

---

## Criterios de No Aprobacion Automatica

- Script no ejecuta en bash sin modificaciones
- Evidencia de copy-paste sin comprensión
- Entrega fuera de plazo sin justificación
- Respuestas vacías o con placeholders sin completar

---

## Formato de Entrega

1. **Branch**: `week-01-proyecto`
2. **Commit**: `feat(week-01): complete api explorer project`
3. Incluir todos los archivos `respuestas.md` de los ejercicios
