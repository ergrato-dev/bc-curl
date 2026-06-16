# Semana 9: HTTP/2, Paralelismo y Performance

## Objetivos de Aprendizaje

Al finalizar esta semana, serás capaz de:

- Explicar las diferencias entre HTTP/1.1 y HTTP/2 a nivel de protocolo
- Verificar y activar el soporte HTTP/2 en curl
- Ejecutar requests paralelos con `--parallel` y controlar el nivel de concurrencia
- Medir cada fase de un request con `--write-out` (DNS, TCP, TLS, TTFB, total)
- Construir un script de benchmark que produce estadísticas de performance
- Conectar a un WebSocket server y realizar el handshake de upgrade

---

## Requisitos Previos

- Semana 8 completada (OAuth2 y autenticacion avanzada)
- curl compilado con soporte HTTP/2 (`curl --version | grep HTTP2`)
- `jq` instalado para procesamiento de JSON
- Python 3 disponible (para algunos ejercicios de prueba local)

---

## Estructura de la Semana

```
week-09-http2_paralelismo_performance/
├── README.md
├── rubrica-evaluacion.md
├── 1-teoria/
│   ├── 01-http2-conceptos.md
│   ├── 02-parallel-requests.md
│   ├── 03-connection-reuse.md
│   ├── 04-write-out-performance.md
│   └── 05-websockets-curl.md
├── 2-practicas/
│   ├── README.md
│   ├── 01-ejercicio-http2/
│   ├── 02-ejercicio-parallel/
│   ├── 03-ejercicio-benchmark/
│   └── 04-ejercicio-websocket/
├── 3-proyecto/
│   └── README.md
└── 5-glosario/
    └── README.md
```

---

## Contenidos

### Teoria (2.5 horas)

| Tema | Duracion | Descripcion |
|------|----------|-------------|
| [01 - HTTP/2 conceptos](1-teoria/01-http2-conceptos.md) | 30 min | Multiplexing, compresion de headers, HTTP/3 |
| [02 - Requests paralelos](1-teoria/02-parallel-requests.md) | 30 min | `--parallel`, `--parallel-max`, comparacion vs bash & |
| [03 - Connection reuse](1-teoria/03-connection-reuse.md) | 30 min | Keepalive, persistent connections, HTTP/2 multiplexing |
| [04 - Write-out performance](1-teoria/04-write-out-performance.md) | 30 min | Variables de tiempo, profiling de fases del request |
| [05 - WebSockets con curl](1-teoria/05-websockets-curl.md) | 30 min | Upgrade de HTTP a WS, handshake, limitaciones |

### Practica (4 horas)

| Ejercicio | Duracion | Descripcion |
|-----------|----------|-------------|
| [01 - HTTP/2](2-practicas/01-ejercicio-http2/) | 45 min | Verificar soporte, comparar HTTP/1.1 vs HTTP/2 |
| [02 - Parallel](2-practicas/02-ejercicio-parallel/) | 60 min | Descargas paralelas, medir speedup |
| [03 - Benchmark](2-practicas/03-ejercicio-benchmark/) | 75 min | Script perf.sh con metricas por fase |
| [04 - WebSocket](2-practicas/04-ejercicio-websocket/) | 60 min | Conectar y hacer handshake WS con curl |

### Proyecto (2 horas)

Script `perf-test.sh`: toma una lista de endpoints, hace N requests a cada uno, reporta p50/p90/p99 de tiempo de respuesta, % de errores, TTFB promedio. Output legible y CSV opcional.

---

## Verificacion Rapida del Entorno

Antes de empezar, verificar que curl tiene soporte HTTP/2:

```bash
# Verificar soporte HTTP/2
curl --version | grep -i "HTTP2\|nghttp2"

# Si no aparece, instalar:
# Ubuntu/Debian: sudo apt-get install curl libnghttp2-dev
# macOS: brew install curl nghttp2
# (despues del brew install, usar /opt/homebrew/bin/curl en macOS)

# Test rapido de HTTP/2
curl -sI --http2 https://www.google.com | head -5
# Debe mostrar: HTTP/2 200
```

---

## Checklist de Verificacion

Antes de pasar a la Semana 10:

- [ ] `curl --version` muestra `HTTP2` en la lista de features
- [ ] Completar un request con `--http2` verificando la respuesta
- [ ] Descargar 10 URLs en paralelo con `--parallel`
- [ ] Medir `time_starttransfer` (TTFB) con `--write-out`
- [ ] Construir el script `perf.sh` funcional
- [ ] Conectar a un WebSocket server y observar el handshake
- [ ] Completar los 4 ejercicios practicos
- [ ] Entregar el proyecto `perf-test.sh`

---

## APIs Publicas para Esta Semana

- `https://jsonplaceholder.typicode.com` — 100 posts, ideal para descargas paralelas
- `https://www.google.com`, `https://cloudflare.com` — soportan HTTP/2 y HTTP/3
- `https://httpbin.org` — para medir performance de requests simples
- `wss://ws.postman-echo.com/raw` — WebSocket de prueba publico (verificar disponibilidad)

---

## Navegacion

Anterior: [Semana 8: OAuth2 y Autenticacion Avanzada](../week-08-oauth2_y_autenticacion_avanzada/README.md)
Siguiente: [Semana 10: Proyecto Final](../week-10-proyecto_final/README.md)
