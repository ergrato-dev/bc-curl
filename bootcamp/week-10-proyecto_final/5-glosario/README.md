# Glosario - Semana 10

## Arquitectura CLI

**CLI (Command Line Interface)**
Programa que se ejecuta desde la terminal y acepta argumentos y flags. A diferencia de una GUI, el output es texto y es pipe-componible.

**set -euo pipefail**
Combinación de opciones de bash para scripts robustos. `-e`: salir si un comando falla. `-u`: error si se usa variable no definida. `-o pipefail`: el pipeline falla si cualquier parte falla.

**Dispatcher**
Función `main()` que recibe el subcomando como primer argumento y lo redirige a la función correspondiente usando `case`. Patrón: `main() { case "$1" in cmd) func "$@";; esac }; main "$@"`.

**stdout vs stderr**
Dos streams de salida estándar en Unix. stdout (fd 1) es para datos/resultados. stderr (fd 2) es para logs, errores, mensajes de estado. Separarlos permite que los scripts sean pipe-componibles.

**Exit codes**
Valores numéricos del 0 al 255 que un programa retorna al terminar. 0 = éxito. 1 = error general. 2 = error de uso. Convención para api-toolkit: 0=ok, 1=error general, 2=error de uso, 3=sin autenticación.

---

## Configuración

**Configuración persistente**
Estado que sobrevive entre ejecuciones del programa. Se guarda típicamente en `~/.nombre-app/` con archivos como `config`, `token.json`, `requests.log`.

**Precedencia de configuración**
Orden en que distintas fuentes de configuración se aplican. De menor a mayor: defaults en código → archivo config → variables de entorno → flags de CLI.

**chmod 600**
Permisos de archivo Unix que solo permiten lectura/escritura al dueño. Obligatorio para archivos con credenciales o tokens. `chmod 700` para directorios de configuración.

**Token lifecycle**
Ciclo de vida de un token OAuth2: `save_token()` → `load_token()` → `is_token_valid()` (verificar `expires_at > now + 60s`) → si expiró, `do_refresh()` → `save_token()` de nuevo.

**Log rotation**
Estrategia para evitar que los archivos de log crezcan indefinidamente. Al alcanzar un tamaño máximo (ej. 1MB), se rota el archivo: se renombra con sufijo `.1` y se crea uno nuevo.

---

## Testing

**bats-core**
Framework de testing para scripts bash. Sintaxis: `@test "descripción" { comandos; [ "$status" -eq 0 ]; }`. Provee `run`, `$status`, `$output`, `$lines`.

**Mock**
Sustituto de un comando real para tests unitarios. Ejemplo: crear un script `curl` falso en el PATH de test que devuelve respuestas predefinidas, evitando llamadas reales a la red.

**Smoke test**
Test rápido post-deploy que verifica que el servicio está vivo y responde. Típicamente un GET a `/health` o al endpoint principal. Si falla, el deploy se considera fallido.

**Unit test vs Integration test**
Unit test: verifica funciones individuales con dependencias mockeadas. Integration test: verifica el sistema completo con servicios reales (httpbin, jsonplaceholder). Ambos son necesarios.

---

## CI/CD

**CI/CD (Continuous Integration / Continuous Deployment)**
Práctica de automatizar tests y deploy. CI: cada commit dispara tests. CD: cada merge a main dispara deploy. curl se usa en ambos contextos para smoke tests y healthchecks.

**Docker healthcheck**
Instrucción en Dockerfile o docker-compose que define cómo verificar que un contenedor está saludable. Usa curl para hacer GET a un endpoint de health. Parámetros: `interval`, `timeout`, `retries`, `start_period`.

**Webhook**
HTTP callback: un servicio notifica a otro vía POST cuando ocurre un evento. curl puede tanto enviar webhooks (Slack, GitHub) como recibirlos (un servidor expone un endpoint).

**Repository dispatch**
Evento de GitHub que permite disparar workflows desde fuera de GitHub vía API. Útil para pipelines que dependen de sistemas externos.

---

## Documentación

**Semantic Versioning (SemVer)**
Esquema de versionado MAJOR.MINOR.PATCH. MAJOR: cambios incompatibles. MINOR: nuevas features compatibles. PATCH: bugfixes compatibles.

**Keep a Changelog**
Formato estándar para CHANGELOG.md con secciones: Added, Changed, Deprecated, Removed, Fixed, Security. Cada entrada agrupada por versión.

**--help**
Primer punto de contacto del usuario con la CLI. Debe mostrar: nombre, uso, subcomandos con descripción, opciones globales, ejemplos rápidos, y exit codes esperados.

**(pipe-componible)**
Propiedad de un programa CLI que permite que su output sea usado como input de otro programa mediante pipes (`|`). Requiere separar datos (stdout) de logs (stderr).

---

## Proyecto Final

**api-toolkit**
CLI construida durante la semana 10 como proyecto final del bootcamp. Integra todos los conceptos de las semanas 1-9: HTTP, auth, cookies, SSL, scripting, jq, performance, CI/CD.

**init (subcomando)**
Configuración inicial interactiva de api-toolkit. Pregunta BASE_URL, credenciales OAuth2, timeouts. Crea el directorio `~/.api-toolkit/` con `chmod 700` y el archivo `config` con `chmod 600`.

**monitor (subcomando)**
Verifica una lista de endpoints y reporta status code y tiempo de respuesta. Clasifica como OK (2xx), WARN (lento o 3xx), ERROR (4xx/5xx/timeout).

**bench (subcomando)**
Ejecuta N requests a una URL y reporta estadísticas: p50, p90, p99, errores. Mide `time_total` con `--write-out`.

**dry-run**
Modo de ejecución que muestra qué haría el comando sin realizarlo realmente. Se activa con `--dry-run`. Escribe a stderr cada acción simulada.
