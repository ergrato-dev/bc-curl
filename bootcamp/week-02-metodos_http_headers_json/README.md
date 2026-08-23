# Semana 02 — Métodos HTTP, headers y JSON

> La Semana 01 fue leer. Esta es escribir. Cambia todo: ahora una equivocación
> no devuelve una página fea, crea un recurso duplicado en producción.

---

## 🎯 Objetivos de la Semana

Al terminar serás capaz de:

- Enviar un cuerpo con `-d` y decir qué método, qué headers y qué longitud salieron sin que se lo pidieras
- Elegir entre `-d`, `--data-raw`, `--data-binary` y `--data-urlencode` sabiendo qué le hace cada uno al contenido
- Explicar por qué `-d @archivo.json` corrompe un JSON con saltos de línea y `--data-binary @archivo.json` no
- Usar PUT, PATCH y DELETE con la semántica correcta, y decir cuál de los tres es idempotente y cuál no
- Justificar por qué casi ningún comando necesita `-X`, y qué rompe `-X` cuando hay una redirección de por medio
- Mandar y recibir JSON sin pelearte con las comillas, y construir el cuerpo con `jq` en vez de a mano
- Añadir, sustituir y suprimir headers con `-H`, y leer con `-v` cuál llegó de verdad
- Interrogar un endpoint con HEAD y con OPTIONS antes de escribir contra él
- Distinguir 201, 204, 409, 415 y 422, y saber cuál de ellos merece un reintento

---

## 📋 Prerrequisitos

- **Semana 01 completada**: `api-explorer.sh` funcionando, sin `TODO`s y con `./scripts/verificar-semana.sh 01` en verde
- **El laboratorio levantado**: `./scripts/start.sh` — ver [setup-entorno](../../docs/setup-entorno.md)
- **`jq` instalado**. Esta semana deja de ser opcional: `jq --version`
- **Tu versión de curl a mano.** Si es anterior a 7.82 no tienes `--json`, y aquí se usa. La alternativa larga va siempre al lado — ver [versiones-de-curl](../../docs/versiones-de-curl.md)
- **Tu dominio elegido** para `api-toolkit`: ver [proyecto-hilo-conductor](../../docs/proyecto-hilo-conductor.md)

---

## 🗂️ Estructura de la Semana

```
week-02-metodos_http_headers_json/
├── README.md                  # Este archivo
├── rubrica-evaluacion.md      # Cómo se evalúa
├── checks.json                # Las 14 comprobaciones automáticas
├── 0-assets/                  # Diagramas
├── 1-teoria/                  # 8 archivos, un concepto cada uno
├── 2-practicas/               # 4 prácticas sobre el laboratorio
├── 3-proyecto/                # La capa 2 de api-toolkit: los verbos
├── 4-recursos/                # Libros, vídeos y enlaces
└── 5-glosario/                # Términos de esta semana
```

---

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01 — El cuerpo de la petición](1-teoria/01-el-cuerpo-de-la-peticion.md) | Qué es un cuerpo, qué cambia `-d`, los tres headers que aparecen solos | 15 min |
| [02 — Las familias de `--data`](1-teoria/02-las-familias-de-data.md) | `-d`, `--data-raw`, `--data-binary`, `--data-urlencode` y `@archivo` | 15 min |
| [03 — PUT, PATCH y DELETE](1-teoria/03-put-patch-delete.md) | Reemplazar, modificar, borrar. Idempotencia y qué implica al reintentar | 15 min |
| [04 — `-X` y por qué casi siempre sobra](1-teoria/04-el-flag-x-y-por-que-sobra.md) | El método lo eligen los otros flags. Qué rompe `-X` con `-L` | 15 min |
| [05 — JSON con curl](1-teoria/05-json-con-curl.md) | Comillas, `@archivo`, `--json` (7.82) y su equivalente, `jq` en los dos sentidos | 15 min |
| [06 — Headers custom](1-teoria/06-headers-custom.md) | `-H` para añadir, sustituir, vaciar y suprimir. `-H @archivo` y los secretos | 15 min |
| [07 — HEAD y OPTIONS](1-teoria/07-head-y-options.md) | Preguntar antes de escribir. `Allow`, `-I` y por qué a veces miente | 15 min |
| [08 — Los códigos de la escritura](1-teoria/08-los-codigos-de-la-escritura.md) | 201 y `Location`, 204 vacío a propósito, 409, 415, 422 y cuál reintentar | 15 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01 — Enviar el primer cuerpo](2-practicas/01-enviar-el-primer-cuerpo.md) | `-d` contra el reflector, ver qué mandó curl y qué no, las cuatro familias de datos | 50 min |
| [02 — El CRUD completo](2-practicas/02-el-crud-completo.md) | Crear, leer, reemplazar, modificar y borrar el mismo recurso. Leer `Location` | 50 min |
| [03 — Headers a mano](2-practicas/03-headers-a-mano.md) | Añadir, sustituir, vaciar y suprimir. Negociar con `Accept`. Sacar el token de la línea | 50 min |
| [04 — JSON que no cabe en la línea](2-practicas/04-json-desde-archivo.md) | `@archivo`, `@-`, construirlo con `jq`, y el bug de los saltos de línea | 50 min |

### Proyecto

La **capa 2** de tu plataforma: `api-toolkit.sh` deja de ser un explorador de
solo lectura y aprende a escribir. Cuatro subcomandos — `get`, `post`, `put`,
`delete` — con el cuerpo JSON y los headers correctos, y un `--dry-run` que
imprime el comando en vez de ejecutarlo. Detalles en
[3-proyecto](3-proyecto/README.md).

---

## ⏱️ Distribución del Tiempo (8 horas)

| Bloque | Tiempo |
|---|:--:|
| Teoría (8 archivos) | 2 h 00 |
| Prácticas (4 × 50 min) | 3 h 20 |
| Proyecto | 2 h 00 |
| Revisión y verificación | 40 min |
| **Total** | **8 h 00** |

> [!TIP]
> Haz el `--dry-run` del proyecto **antes** que los cuatro verbos, no después.
> Es lo que te deja probar un `delete` contra la API de tu dominio sin borrar
> nada de verdad. Escrito al final, ya habrás borrado algo.

---

## ⚠️ Lo que cambia cuando empiezas a escribir

Leer es seguro: un GET mal escrito devuelve un error y ahí se acaba. Escribir no.
Tres diferencias que conviene interiorizar esta semana y no la que viene:

| En lectura | En escritura |
|---|---|
| Repetir la petición no cuesta nada | Repetir un POST crea el recurso **dos veces**. `--retry` sobre un POST es una decisión, no un adorno |
| El error viene en el código de estado | El motivo real viene **en el cuerpo**. Con `--fail` a secas lo tiras; se usa `--fail-with-body` |
| El `Content-Type` daba igual | Es la diferencia entre un 201 y un 415. `-d` pone `x-www-form-urlencoded`, no JSON |

Y una que muerde a todo el mundo: `curl -X POST` **no envía nada**. `-X` cambia
la etiqueta del método, el cuerpo lo pone `-d`. Un `-X POST` sin `-d` es un POST
vacío, y la API contesta 400 cuando tú creías haber mandado los datos.

---

## 🎩 Trucos y atajos

| Truco | Cómo |
|---|---|
| Mandar un cuerpo desde **stdin** sin archivo intermedio | `... \| curl -d @- URL`. La `@-` significa "el cuerpo lo lees de la entrada estándar" |
| Construir el JSON sin pelearte con las comillas | `jq -n --arg n ada '{nombre:$n}' \| curl -H 'Content-Type: application/json' -d @- URL`. `jq` escapa por ti |
| JSON desde un archivo **sin corromperlo** | `--data-binary @cuerpo.json`. Con `-d @cuerpo.json` curl **quita los saltos de línea** |
| Los tres flags de JSON en uno | `--json '{"a":1}'` (7.82+) = `-d` + `-H 'Content-Type: application/json'` + `-H 'Accept: application/json'` |
| Query string con espacios y `&` bien codificados | `curl -G --data-urlencode 'q=hola mundo&x' URL`. El `-G` lo mueve del cuerpo a la query |
| Saber qué método salió de verdad | `curl -s -o /dev/null -w '%{method}\n' -d '' URL` (7.72+). Delata el método que pusieron los flags, antes de lanzar el comando de verdad |
| Ver qué headers llegaron al servidor, no cuáles creías mandar | `curl -s http://localhost:8080/headers \| jq .headers` |
| Meter los headers en un archivo y sacar el token de `ps` | `curl -H @cabeceras.txt URL` (7.55+). Un header por línea, y `chmod 600` |
| Mandar un header **vacío** frente a **suprimirlo** | `-H 'Accept;'` lo manda vacío; `-H 'Accept:'` lo quita del todo. Punto y coma frente a dos puntos |
| Preguntar qué métodos acepta un endpoint antes de escribir | `curl -s --request OPTIONS -D - -o /dev/null URL \| grep -iE '^(allow\|access-control-allow-methods)'`. Si el servidor no contesta ninguno de los dos, provoca un 405 y lee su `Allow:` |
| Ver la URL del recurso recién creado | `curl -s -o /dev/null -D - -d '...' URL \| grep -i '^location'` |
| Encadenar varias peticiones en una sola invocación | `curl URL1 --next -d 'a=1' URL2`. Reutiliza la conexión y los flags se reinician en cada `--next` |
| Todos los headers de respuesta como JSON | `curl -s -o /dev/null -w '%{header_json}' URL \| jq` (**7.83+**; en 7.81 usa `-D -`) |
| Comprobar el `Content-Type` que devolvió la API | `curl -s -o /dev/null -w '%{content_type}\n' URL` |

---

## 📌 Entregables

1. `respuestas.md` con la comparación de `-d @archivo` frente a `--data-binary @archivo` sobre el mismo JSON
2. `crud.log` con los cuatro verbos y su código, de la práctica 02
3. `cabeceras.txt` con permisos 600 y **sin el token real dentro**, de la práctica 03
4. `construir-cuerpo.sh` funcionando y limpio de `shellcheck`, de la práctica 04
5. `api-toolkit.sh` con los cuatro verbos funcionando, sin ningún `TODO` pendiente
6. `post`, `put` y `delete` declaran `Content-Type: application/json` cuando llevan cuerpo
7. `--dry-run` imprime el comando y **no** lo ejecuta
8. El script sale distinto de 0 ante un 4xx o un 5xx
9. Ningún secreto en la línea de comandos ni en el script
10. `shellcheck -S warning api-toolkit.sh` limpio
11. Ningún `-k` en el script

---

## ✅ Verificación

```bash
./scripts/start.sh
./scripts/verificar-semana.sh 02
```

Las 14 comprobaciones tienen que pasar. Si alguna falla, la pista te dice en qué
práctica y en qué paso se arregla.

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [Semana 01 — HTTP y curl básico](../week-01-http_y_curl_basico/README.md) | **Semana 02 — Métodos HTTP, headers y JSON** | [Semana 03 — Autenticación básica](../week-03-autenticacion_basica/README.md) |

[← Volver al inicio del bootcamp](../README.md)
