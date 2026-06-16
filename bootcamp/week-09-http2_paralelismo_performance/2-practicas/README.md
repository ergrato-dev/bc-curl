# Practicas — Semana 9: HTTP/2, Paralelismo y Performance

Cuatro ejercicios que van de conceptos de protocolo a scripting de performance. El ejercicio 03 produce el script `perf.sh` que se usa como base para el proyecto de la semana.

## Ejercicios

| # | Carpeta | Tiempo | Objetivo |
|---|---------|--------|----------|
| 01 | [01-ejercicio-http2](01-ejercicio-http2/) | 45 min | Verificar HTTP/2 y comparar con HTTP/1.1 |
| 02 | [02-ejercicio-parallel](02-ejercicio-parallel/) | 60 min | Descargas paralelas y medicion de speedup |
| 03 | [03-ejercicio-benchmark](03-ejercicio-benchmark/) | 75 min | Script perf.sh con metricas por fase |
| 04 | [04-ejercicio-websocket](04-ejercicio-websocket/) | 60 min | Handshake WebSocket y verificacion de endpoint |

## Prerequisito de Entorno

Verificar antes de empezar:

```bash
# curl con HTTP/2
curl --version | grep HTTP2
# Debe aparecer: Features: ... HTTP2 ...

# Si no aparece:
# Ubuntu/Debian: sudo apt-get install curl
# macOS: brew install curl  (y usar /opt/homebrew/bin/curl)

# Test rapido
curl -sI --http2 https://www.google.com | head -1
# Debe mostrar: HTTP/2 200
```

## Como Entregar

Crear un archivo `respuestas.md` en cada carpeta de ejercicio con:
- Los comandos usados (completos, copiados de la terminal)
- Output representativo (recortar si es muy largo)
- Respuestas a las preguntas de analisis
- Los scripts desarrollados (inline o como archivo separado en la misma carpeta)
