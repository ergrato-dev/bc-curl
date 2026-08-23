# Semana 01 — HTTP y curl básico

> Todo lo que hace un navegador cuando abres una página son unas cuantas líneas
> de texto viajando por un socket. Esta semana las escribes tú a mano y las lees
> sin que nadie te las maquille.

---

## 🎯 Objetivos de la Semana

Al terminar serás capaz de:

- Explicar el ciclo request/response y nombrar las cuatro partes de cada mensaje
- Descomponer cualquier URL en esquema, host, puerto, path, query y fragmento, y decir cuál de esas partes viaja al servidor
- Saber qué versión de curl tienes, qué protocolos habla y qué se compiló en ella
- Hacer un GET y saber exactamente qué está imprimiendo curl y qué se está callando
- Usar `-v`, `-i`, `-I`, `-o`, `-s`, `-S`, `-L`, `-w` y `--max-time` sabiendo qué problema resuelve cada uno
- Leer un código de estado y decidir si el error es tuyo, del servidor, o ninguno de los dos
- Distinguir headers de petición de headers de respuesta, y saber cuáles pone curl solo
- Provocar un fallo a propósito, leer la traza `-v` entera y decir en qué línea se rompió
- Encontrar la respuesta en `curl --help all` y en `curl --manual` sin buscar en internet

---

## 📋 Prerrequisitos

- **Terminal** Linux, macOS o WSL2. En PowerShell `curl` es un alias de `Invoke-WebRequest`: trabaja dentro de WSL
- **Docker y Compose v2** instalados y con el demonio arrancado
- **El laboratorio levantado**: `./scripts/start.sh` — ver [setup-entorno](../../docs/setup-entorno.md)
- **Tu dominio elegido** para `api-toolkit`: ver [proyecto-hilo-conductor](../../docs/proyecto-hilo-conductor.md)
- No hace falta saber programar. El bash se aprende sobre la marcha

---

## 🗂️ Estructura de la Semana

```
week-01-http_y_curl_basico/
├── README.md                  # Este archivo
├── rubrica-evaluacion.md      # Cómo se evalúa
├── checks.json                # Las 10 comprobaciones automáticas
├── 0-assets/                  # Diagramas
├── 1-teoria/                  # 8 archivos, un concepto cada uno
├── 2-practicas/               # 4 prácticas sobre el laboratorio
├── 3-proyecto/                # La capa 1 de api-toolkit
├── 4-recursos/                # Libros, vídeos y enlaces
└── 5-glosario/                # Términos de esta semana
```

---

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01 — Qué es HTTP](1-teoria/01-que-es-http.md) | Cliente-servidor, request/response, las cuatro partes de cada mensaje, sin estado | 15 min |
| [02 — Anatomía de la URL](1-teoria/02-anatomia-de-la-url.md) | Esquema, host, puerto, path, query, fragmento. Qué viaja y qué no. Codificación | 15 min |
| [03 — Instalación y versiones de curl](1-teoria/03-instalacion-y-versiones.md) | Instalar, leer `--version`, `Protocols` frente a `Features`, curl y libcurl | 15 min |
| [04 — El primer GET](1-teoria/04-el-primer-get.md) | Qué manda curl sin que se lo pidas, qué imprime, qué se calla, `-o` y `-O` | 15 min |
| [05 — Los flags esenciales](1-teoria/05-los-flags-esenciales.md) | `-v`, `-i`, `-I`, `-s`, `-S`, `-L`, `-w`, `--max-time` y por qué van juntos | 20 min |
| [06 — Códigos de estado](1-teoria/06-codigos-de-estado.md) | Las cinco familias, los que verás de verdad, y por qué curl sale con 0 ante un 500 | 15 min |
| [07 — Headers HTTP](1-teoria/07-headers-http.md) | Petición y respuesta, los que pone curl solo, `Content-Type`, `Content-Length`, `Host` | 15 min |
| [08 — Leer la traza y el manual](1-teoria/08-leer-la-traza-y-el-manual.md) | Los símbolos de `-v`, los códigos de salida, `--help all` y `--manual` | 10 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01 — Conocer tu curl](2-practicas/01-conocer-tu-curl.md) | Versión, protocolos, features, la ayuda y el manual. Detectar qué te falta | 50 min |
| [02 — El primer GET](2-practicas/02-el-primer-get.md) | GET al laboratorio y a una API real, query strings, guardar en archivo | 50 min |
| [03 — Los flags esenciales](2-practicas/03-los-flags-esenciales.md) | Los nueve flags, uno a uno, cada uno resolviendo un problema concreto | 50 min |
| [04 — Provocar y leer códigos de estado](2-practicas/04-provocar-y-leer-status-codes.md) | Provocar 2xx, 3xx, 4xx y 5xx a propósito y hacer que el shell los detecte | 50 min |

### Proyecto

La **capa 1** de tu plataforma: `api-explorer.sh`, un script que consulta varias
URLs, imprime código de estado y tiempo de respuesta de cada una, y termina con
un resumen. Es la semilla de `api-toolkit`. Detalles en
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
> Haz la práctica 01 aunque te parezca trivial. Saber que tu curl es 7.81 y no
> 8.5 te va a ahorrar media hora de desconcierto en la Semana 02, cuando un
> ejemplo con `--json` no funcione en tu máquina y sí en el vídeo que estés
> viendo.

---

## 🧭 Lo que curl no te dice

Tres silencios que confunden a todo el mundo la primera semana, y que conviene
tener presentes desde ya:

| Lo que ves | Lo que está pasando |
|---|---|
| curl imprime el cuerpo y nada más | Los headers viajaron igual. Están ahí, solo que curl no los enseña salvo que se lo pidas con `-i` o `-v` |
| curl "no da error" ante un 404 | Para curl la transferencia fue un éxito: pidió y le contestaron. El 404 es la respuesta del servidor, no un fallo de curl. Sale con código **0** |
| curl "se queda parado" | No hay timeout por defecto en la transferencia. Sin `--max-time`, curl espera lo que haga falta |

Los tres se resuelven con un flag. El problema no es que curl haga algo raro:
es que su comportamiento por defecto está pensado para pipes, no para humanos.

---

## 🎩 Trucos y atajos

| Truco | Cómo |
|---|---|
| Ver **todas** las opciones, no el resumen | `curl --help all`. `curl --help` a secas enseña 17 líneas de 245 |
| El manual completo sin salir de la terminal | `curl --manual \| less`. Son ~5.000 líneas y responde casi todo |
| Buscar una opción por lo que hace, no por su nombre | `curl --help all \| grep -i timeout` |
| Saber si tu curl habla un protocolo | `curl --version` — `Protocols:` lo que habla, `Features:` lo que se compiló |
| Solo el código de estado, nada más | `curl -s -o /dev/null -w '%{http_code}\n' URL` |
| Toda la información de la transferencia en JSON | `curl -s -o /dev/null -w '%{json}' URL \| jq` (7.70+) |
| Ver la petición **sin** enviar el cuerpo de la respuesta | `curl -I URL` hace un HEAD; `curl -s -o /dev/null -D - URL` hace un GET real y enseña solo los headers |
| Repetir la última URL sin volver a escribirla | `!!` en bash, o `!curl` para el último comando que empezó por curl |
| Que un fallo de red no se confunda con un HTML vacío | `curl -sS URL`: `-s` calla la barra de progreso, `-S` deja pasar los errores |
| Quitar uno de los headers que curl pone solo | `-H 'Accept:'` — valor vacío con dos puntos lo **suprime**; con punto y coma (`-H 'Accept;'`) lo manda vacío |
| Filtrar la traza de `-v` con `grep` | `curl -sv URL 2>&1 \| grep -E '^[<>]'`. Sin `2>&1` no funciona: la traza va por stderr |
| Contar los headers de la respuesta sin leerlos | `curl -s -o /dev/null -w '%{num_headers}\n' URL` |
| Provocar cualquier código de estado | `http://localhost:8080/status/418`. Acepta hasta los raros |
| Ver la cadena de redirecciones entera | `curl -sL -o /dev/null -D - URL \| grep -iE '^(HTTP\|Location)'` |
| Las categorías de la ayuda, cuando no sabes ni cómo se llama | `curl --help category`, y luego `curl --help connection` |

---

## 📌 Entregables

1. `respuestas.md` con la salida de `curl --version` de tu máquina y qué te falta
2. Los cuatro archivos de la práctica completados
3. `api-explorer.sh` funcionando, sin ningún `TODO` pendiente
4. El script imprime código de estado y tiempo de respuesta de cada URL
5. El script sale distinto de 0 cuando alguna URL responde 5xx
6. El script no se cuelga: usa `--max-time`
7. `shellcheck -S warning api-explorer.sh` limpio
8. Ningún `-k` en el script

---

## ✅ Verificación

```bash
./scripts/start.sh
./scripts/verificar-semana.sh 01
```

Las 10 comprobaciones tienen que pasar. Si alguna falla, la pista te dice en qué
práctica y en qué paso se arregla.

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| — | **Semana 01 — HTTP y curl básico** | [Semana 02 — Métodos HTTP, headers y JSON](../week-02-metodos_http_headers_json/README.md) |

[← Volver al inicio del bootcamp](../README.md)
