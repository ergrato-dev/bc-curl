<p align="center">
  <img src="assets/bootcamp-header.svg" alt="Bootcamp curl: Zero to Hero" width="900">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-CC%20BY--NC--SA%204.0-lightgrey.svg" alt="License"></a>
  <img src="https://img.shields.io/badge/semanas-10-yellow.svg" alt="10 Semanas">
  <img src="https://img.shields.io/badge/horas-80-orange.svg" alt="80 Horas">
  <img src="https://img.shields.io/badge/curl-7.x%2F8.x-blue.svg" alt="curl 7.x/8.x">
  <a href="README_EN.md"><img src="https://img.shields.io/badge/lang-English-blue.svg" alt="English Version"></a>
</p>

---

## Descripción

Bootcamp intensivo de **10 semanas (80 horas)** dedicado a dominar `curl` desde cero hasta nivel producción. Cubre HTTP, autenticación, scripting, OAuth2, HTTP/2 y automatización CI/CD.

### Objetivo final

Al terminar el bootcamp podrás:

- Interactuar con cualquier API REST desde la línea de comandos
- Debuggear problemas de red y TLS sin herramientas de GUI
- Escribir scripts bash robustos usando curl
- Implementar flujos OAuth2 completos desde terminal
- Integrar curl en pipelines CI/CD

---

## Estructura del Bootcamp

| Etapa | Semanas | Horas | Temas |
|-------|---------|-------|-------|
| **Fundamentos** | 1-3 | 24h | HTTP, métodos, headers, JSON, autenticación básica |
| **Intermedio** | 4-6 | 24h | Archivos, SSL/TLS, cookies, output, debug |
| **Avanzado** | 7-9 | 24h | Scripting bash, OAuth2, HTTP/2, performance |
| **Producción** | 10 | 8h | Proyecto final, CI/CD, integración real |

---

## Contenido por Semana

| # | Semana | Descripción |
|---|--------|-------------|
| 01 | [HTTP y curl básico](bootcamp/week-01-http_y_curl_basico/) | GET, anatomía de URLs, respuestas HTTP |
| 02 | [Métodos HTTP, headers y JSON](bootcamp/week-02-metodos_http_headers_json/) | POST/PUT/DELETE/PATCH, headers, cuerpos JSON |
| 03 | [Autenticación básica](bootcamp/week-03-autenticacion_basica/) | Basic Auth, API Keys, Bearer tokens |
| 04 | [Archivos, formularios y multipart](bootcamp/week-04-archivos_formularios_multipart/) | Upload/download, form data, multipart |
| 05 | [SSL/TLS, cookies y redirects](bootcamp/week-05-ssl_tls_cookies_redirects/) | Certificados, cookies, redirects, timeouts |
| 06 | [Output, debug y configuración](bootcamp/week-06-output_debug_configuracion/) | verbose, write-out, silent, .curlrc |
| 07 | [Scripting bash con curl](bootcamp/week-07-scripting_bash_con_curl/) | Loops, error handling, jq, automatización |
| 08 | [OAuth2 y autenticación avanzada](bootcamp/week-08-oauth2_y_autenticacion_avanzada/) | Authorization code, client credentials, JWT |
| 09 | [HTTP/2, paralelismo y performance](bootcamp/week-09-http2_paralelismo_performance/) | HTTP/2, parallel, --parallel-max, WebSockets |
| 10 | [Proyecto final](bootcamp/week-10-proyecto_final/) | Integración real, CI/CD, scripts reusables |

---

## Estructura de cada semana

```
week-XX-tema/
├── README.md                  # Objetivos, contenidos, checklist
├── rubrica-evaluacion.md      # Criterios de evaluación
├── 0-assets/                  # Diagramas y recursos visuales
├── 1-teoria/                  # Material teórico en markdown
├── 2-practicas/               # Ejercicios guiados con soluciones
├── 3-proyecto/                # Proyecto semanal
│   └── starter/               # Punto de partida
├── 4-recursos/
│   ├── ebooks-free/
│   ├── videografia/
│   └── webgrafia/
└── 5-glosario/
    └── README.md
```

---

## Requisitos Previos

- Terminal Linux/macOS o WSL en Windows
- `curl` 7.x o superior instalado (`curl --version`)
- Conocimientos básicos de terminal (ls, cd, cat, pipes)
- Editor de texto (cualquiera)

No se requiere conocimiento de programación previo. Los scripts bash se aprenden durante el bootcamp.

---

## Licencia

[CC BY-NC-SA 4.0](LICENSE) — Uso libre para fines educativos no comerciales.
