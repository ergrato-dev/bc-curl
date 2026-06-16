# Rubrica de Evaluacion — Semana 9: HTTP/2, Paralelismo y Performance

## Competencias Evaluadas

| Codigo | Competencia | Peso |
|--------|-------------|------|
| C1 | HTTP/2 habilitado y verificado | 20% |
| C2 | Requests paralelos implementados correctamente | 30% |
| C3 | Metricas de performance extraidas | 25% |
| C4 | Benchmark script funcional | 25% |

---

## C1 — HTTP/2 Habilitado y Verificado

**Descripcion**: El estudiante verifica el soporte HTTP/2 en su instalacion de curl y demuestra la diferencia en el protocolo de negociacion comparado con HTTP/1.1.

| Nivel | Descripcion | Puntos |
|-------|-------------|--------|
| 4 - Avanzado | Verifica soporte, muestra negociacion ALPN en `-v`, mide diferencia de performance entre HTTP/1.1 y HTTP/2, explica por que HTTP/2 es mas eficiente con multiples requests | 100 |
| 3 - Competente | Verifica soporte con `--version`, hace un request HTTP/2 exitoso y muestra `HTTP/2 200` en la respuesta | 75 |
| 2 - Basico | Sabe usar `--http2` pero no puede verificar que realmente uso HTTP/2 o no entiende la salida | 50 |
| 1 - Inicial | Conoce el flag `--http2` pero no puede demostrar su uso | 25 |
| 0 - No logrado | No entrega o curl no tiene soporte HTTP/2 y no se intento resolver | 0 |

Criterios especificos:
- `curl --version` muestra `HTTP2` en las features
- Request con `--http2 -I` devuelve `HTTP/2 200` (no `HTTP/1.1 200`)
- El uso de `-v` muestra la negociacion ALPN (`h2`) en el TLS handshake

---

## C2 — Requests Paralelos Implementados

**Descripcion**: El estudiante implementa correctamente descargas paralelas con `--parallel` y demuestra la mejora de performance respecto a requests secuenciales.

| Nivel | Descripcion | Puntos |
|-------|-------------|--------|
| 4 - Avanzado | Compara secuencial vs paralelo con `time`, ajusta `--parallel-max` para distintos escenarios, explica la diferencia entre paralelismo con `&` en bash vs `--parallel` en curl | 100 |
| 3 - Competente | Descarga multiples URLs en paralelo correctamente, mide el tiempo y verifica que es mas rapido que secuencial | 75 |
| 2 - Basico | Usa `--parallel` pero no puede medir la mejora ni controlar la concurrencia | 50 |
| 1 - Inicial | Conoce el flag pero no puede hacer funcionar requests paralelos | 25 |
| 0 - No logrado | No entrega o no implementa paralelismo | 0 |

Criterios especificos:
- `--parallel` con multiples URLs funciona correctamente
- Cada URL tiene su propio `-o` para guardar el resultado
- El tiempo total paralelo es menor al tiempo secuencial (al menos 30% mejor)
- `--parallel-max` demostrado con al menos dos valores distintos

---

## C3 — Metricas de Performance Extraidas

**Descripcion**: El estudiante usa `--write-out` para medir las fases individuales de un request HTTP y puede identificar en que fase hay mas latencia.

| Nivel | Descripcion | Puntos |
|-------|-------------|--------|
| 4 - Avanzado | Mide todas las fases (DNS, TCP, TLS, TTFB, total), presenta tabla comparativa para 3 o mas endpoints, identifica correctamente cual fase es el cuello de botella en cada caso | 100 |
| 3 - Competente | Mide al menos 4 fases con `--write-out` para un endpoint y puede explicar que representa cada variable de tiempo | 75 |
| 2 - Basico | Mide `time_total` y `time_starttransfer` pero no las fases intermedias | 50 |
| 1 - Inicial | Usa `--write-out` pero solo para variables no relacionadas con tiempo | 25 |
| 0 - No logrado | No usa `--write-out` para metricas de tiempo | 0 |

Criterios especificos:
- Variables usadas: al minimo `time_namelookup`, `time_connect`, `time_starttransfer`, `time_total`
- Los valores se presentan en formato legible (ms o s con 3 decimales)
- Para al menos un endpoint, se puede identificar la fase mas lenta

---

## C4 — Benchmark Script Funcional

**Descripcion**: El estudiante construye un script `perf.sh` que realiza multiples requests a un endpoint, calcula estadísticas y presenta un reporte.

| Nivel | Descripcion | Puntos |
|-------|-------------|--------|
| 4 - Avanzado | Script calcula p50/p90/p99, reporta porcentaje de errores, acepta parametros configurables (URL, N repeticiones), tiene opcion de output CSV | 100 |
| 3 - Competente | Script hace N requests, registra `time_total` de cada uno, calcula promedio y minimo/maximo, reporta en tabla legible | 75 |
| 2 - Basico | Script hace requests en loop y muestra tiempos individuales pero no calcula estadísticas | 50 |
| 1 - Inicial | Script hace un solo request con metricas | 25 |
| 0 - No logrado | No hay script funcional | 0 |

Criterios especificos:
- El script acepta al menos dos parametros: URL y numero de repeticiones
- Calcula y muestra minimo, maximo y promedio de tiempo de respuesta
- Muestra el porcentaje de requests con status 2xx vs otros
- El output es legible en la terminal (tabla o formato estructurado)

---

## Evaluacion del Proyecto

El script `perf-test.sh` se evalua sobre los criterios C2, C3 y C4 con mayor peso en C4.

Criterios adicionales para el proyecto:
- **Escalabilidad** (bonus 10%): funciona bien con listas grandes de URLs (20+) sin quedarse sin recursos
- **Robustez** (bonus 10%): maneja endpoints que dan error sin romper el loop, timeout configurable

---

## Escala de Calificacion

| Puntaje | Calificacion |
|---------|--------------|
| 90-100 | Excelente — puede hacer profiling profesional de APIs |
| 75-89 | Competente — puede medir y comparar performance de forma autonoma |
| 60-74 | Basico — entiende los conceptos pero necesita reforzar el scripting |
| < 60 | Insuficiente — requiere repasar scripting bash (semana 7) |
