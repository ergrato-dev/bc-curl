# Semana 10: Proyecto Final — api-toolkit

[← Semana 9](../week-09-automatizacion/) | [↑ Inicio](../../README.md)

---

## Objetivos finales del bootcamp

Esta semana cierra el ciclo. No hay conceptos nuevos: todo lo que se trabaja aquí fue aprendido en las semanas 1 a 9. El objetivo es integrar esos conocimientos en una herramienta real, completa y usable.

Al terminar esta semana, el estudiante habrá construido `api-toolkit`: una CLI configurable para interactuar con cualquier API REST desde la terminal.

### Lo que se integra

| Semana | Tema | Cómo aparece en api-toolkit |
|--------|------|------------------------------|
| 1-2 | HTTP methods, curl básico | `cmd_get`, `cmd_post`, `cmd_put`, `cmd_delete` |
| 3 | Auth: Basic, API Key, Bearer | `get_auth_header()`, `AUTH_TYPE` en config |
| 4 | OAuth2, token lifecycle | `cmd_auth_login`, `ensure_auth`, refresh automático |
| 5 | Manejo de errores, retry | Lógica de retry en `do_request` (401, 429) |
| 6 | SSL, certificados | Flags `--cacert`, `--insecure` condicionales |
| 7 | Scripting avanzado, jq | Output processing, `--output table/json/csv` |
| 8 | Performance, benchmarking | `cmd_bench` con percentiles p50/p90/p99 |
| 9 | Automatización, monitoring | `cmd_monitor` con `--parallel` |

---

## api-toolkit: descripción general

`api-toolkit` es una CLI configurable para interactuar con cualquier API REST. Se instala una vez y se configura por proyecto mediante `~/.api-toolkit/config`.

### Subcomandos

```
api-toolkit auth login              Obtener y guardar token de acceso
api-toolkit auth logout             Borrar token guardado
api-toolkit auth status             Mostrar estado del token actual

api-toolkit get ENDPOINT            GET request
api-toolkit post ENDPOINT [--data]  POST con body JSON
api-toolkit put ENDPOINT --data     PUT con body JSON
api-toolkit delete ENDPOINT         DELETE request

api-toolkit monitor FILE            Health check de lista de URLs
api-toolkit bench ENDPOINT [--times N]  Benchmark de latencia
api-toolkit init                    Inicializar configuración interactivamente
```

### Ejemplo de uso

```bash
# Configurar para una API
api-toolkit init

# Autenticarse (si la API usa OAuth2)
api-toolkit auth login

# Hacer requests
api-toolkit get /users | jq '.[].name'
api-toolkit post /users --data '{"name": "Ana", "email": "ana@ejemplo.com"}'
api-toolkit put /users/42 --data '{"name": "Ana Lopez"}'

# Monitoring y benchmarking
api-toolkit monitor urls.txt
api-toolkit bench /users --times 20

# Ver qué haría sin ejecutar
api-toolkit --dry-run post /users --data '{"name": "test"}'
```

---

## Estructura de la semana

```
week-10-proyecto_final/
├── README.md                        (este archivo)
├── 1-teoria/
│   ├── 01-arquitectura-cli.md       Diseño de CLIs profesionales con bash
│   ├── 02-configuracion-persistente.md  Config files y jerarquía de precedencia
│   ├── 03-testing-scripts-bash.md   Testing con bats-core
│   ├── 04-documentacion-cli.md      --help, README, CHANGELOG
│   └── 05-ci-cd-curl.md             curl en pipelines CI/CD
├── 2-practicas/
│   ├── README.md                    Descripción de las 4 etapas
│   ├── 01-ejercicio-estructura/     Scaffolding, dispatcher, --help
│   ├── 02-ejercicio-auth-module/    login/logout/status con token lifecycle
│   ├── 03-ejercicio-request-module/ get/post/put/delete con retry y logging
│   └── 04-ejercicio-features-avanzadas/  monitor, bench, dry-run
├── 3-proyecto/
│   ├── README.md                    Descripción del proyecto final
│   ├── starter/
│   │   ├── api-toolkit.sh           Punto de partida con estructura completa
│   │   └── demo.md                  Plantilla para documentar la demo
├── 5-glosario/
│   └── README.md                    Glosario completo del bootcamp
└── rubrica-evaluacion.md            Criterios de evaluación
```

**Tiempo estimado:** 5 horas (teoría) + 4 horas (prácticas) = 9 horas

Las prácticas son las etapas del proyecto. Al completar la práctica 04, el proyecto final está listo.

---

## Checklist final del bootcamp

Al terminar el bootcamp, el estudiante debe ser capaz de:

### HTTP y curl fundamentals
- [ ] Hacer GET, POST, PUT, PATCH, DELETE con curl
- [ ] Enviar headers personalizados con `-H`
- [ ] Enviar body JSON con `-d` y `Content-Type: application/json`
- [ ] Interpretar los status codes HTTP (2xx, 3xx, 4xx, 5xx)
- [ ] Usar `-v` para debugging y `-s` para silencio
- [ ] Extraer status code con `-w "%{http_code}"` y `-o /dev/null`

### Autenticación
- [ ] Implementar HTTP Basic Auth con `-u user:pass`
- [ ] Enviar API Keys en header y query string
- [ ] Obtener tokens Bearer con client_credentials grant
- [ ] Enviar Authorization: Bearer en requests subsiguientes
- [ ] Decodificar un JWT (base64) para leer `exp`
- [ ] Renovar tokens expirados automáticamente

### Manejo de errores
- [ ] Distinguir errores de curl (exit codes) de errores HTTP (status codes)
- [ ] Implementar retry con backoff exponencial
- [ ] Manejar 429 con `Retry-After`
- [ ] Manejar 401 con renovación de token

### SSL
- [ ] Verificar que curl valida SSL por defecto
- [ ] Usar `--cacert` con un CA bundle personalizado
- [ ] Entender cuándo (no) usar `--insecure`

### Scripting y jq
- [ ] Extraer campos de JSON con jq: `.field`, `.[].field`
- [ ] Filtrar arrays: `select(.active == true)`
- [ ] Transformar JSON: `{name: .name, id: .id}`
- [ ] Iterar resultados en un loop bash
- [ ] Usar `--arg` para pasar variables a jq

### Performance y monitoring
- [ ] Usar `--write-out` para métricas de tiempo
- [ ] Hacer requests en paralelo con `&` y `wait`
- [ ] Calcular percentiles (p50, p90, p99)
- [ ] Implementar un health check loop

### Scripting bash para CLIs
- [ ] Usar `set -euo pipefail`
- [ ] Implementar un dispatcher con `case`
- [ ] Escribir a stdout y a stderr correctamente
- [ ] Retornar exit codes apropiados
- [ ] Cargar configuración desde archivo con `source`
- [ ] Guardar estado entre ejecuciones en archivos

### CI/CD y automatización
- [ ] Usar curl en GitHub Actions para smoke tests
- [ ] Triggerear webhooks con curl
- [ ] Escribir un health check para docker-compose

---

## Navegación

[← Semana 9: Automatización y Monitoring](../week-09-automatizacion/) | [↑ Inicio del bootcamp](../../README.md)
