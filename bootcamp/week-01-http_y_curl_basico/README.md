# Semana 1: HTTP y curl básico

## Objetivos de Aprendizaje

Al finalizar esta semana, serás capaz de:

- Explicar el modelo cliente-servidor y el ciclo request/response
- Identificar los componentes de una URL (esquema, host, puerto, path, query, fragment)
- Instalar y verificar la versión de curl
- Realizar peticiones GET con curl
- Leer e interpretar respuestas HTTP (status codes, headers, body)
- Usar flags básicos: `-v`, `-i`, `-o`, `-s`, `-L`
- Distinguir entre HTTP/1.1 y HTTPS

---

## Requisitos Previos

- Terminal funcional (Linux, macOS o WSL)
- curl instalado (`curl --version` debe responder 7.x o superior)
- Acceso a internet

---

## Estructura de la Semana

```
week-01-http_y_curl_basico/
├── README.md
├── rubrica-evaluacion.md
├── 0-assets/
├── 1-teoria/
│   ├── 01-que-es-http.md
│   ├── 02-anatomia-url.md
│   ├── 03-instalacion-curl.md
│   ├── 04-primer-request-get.md
│   └── 05-status-codes-y-headers.md
├── 2-practicas/
│   ├── README.md
│   ├── 01-ejercicio-instalacion/
│   ├── 02-ejercicio-get-basico/
│   ├── 03-ejercicio-flags/
│   └── 04-ejercicio-status-codes/
├── 3-proyecto/
│   └── README.md
├── 4-recursos/
└── 5-glosario/
    └── README.md
```

---

## Contenidos

### Teoria (2 horas)

| Tema | Duración | Descripción |
|------|----------|-------------|
| [01 - Qué es HTTP](1-teoria/01-que-es-http.md) | 25 min | Modelo cliente-servidor, request/response, verbos |
| [02 - Anatomía de una URL](1-teoria/02-anatomia-url.md) | 20 min | Esquema, host, puerto, path, query string, fragment |
| [03 - Instalación de curl](1-teoria/03-instalacion-curl.md) | 15 min | Instalación en Linux/macOS/WSL, verificación |
| [04 - Primer request GET](1-teoria/04-primer-request-get.md) | 30 min | Sintaxis curl, flags esenciales `-v -i -o -s -L` |
| [05 - Status codes y headers](1-teoria/05-status-codes-y-headers.md) | 30 min | 1xx/2xx/3xx/4xx/5xx, headers comunes |

### Practica (4 horas)

| Ejercicio | Duración | Descripción |
|-----------|----------|-------------|
| [01 - Instalación](2-practicas/01-ejercicio-instalacion/) | 30 min | Verificar curl, explorar `--help` y man page |
| [02 - GET básico](2-practicas/02-ejercicio-get-basico/) | 60 min | Peticiones a APIs públicas, inspeccionar respuestas |
| [03 - Flags](2-practicas/03-ejercicio-flags/) | 90 min | Dominar `-v`, `-i`, `-o`, `-s`, `-L`, `-I` |
| [04 - Status codes](2-practicas/04-ejercicio-status-codes/) | 60 min | Provocar y leer diferentes códigos de respuesta |

### Proyecto (2 horas)

Explorador de APIs públicas: script que consulta 3 APIs públicas diferentes, muestra status code, tiempo de respuesta y primeros 100 chars del body.

---

## Checklist de Verificacion

Antes de pasar a la Semana 2:

- [ ] `curl --version` muestra 7.x o superior
- [ ] Realizar GET a `https://httpbin.org/get` sin flags
- [ ] Realizar GET con `-v` y leer la negociación HTTP
- [ ] Realizar GET con `-i` y distinguir headers del body
- [ ] Guardar respuesta en archivo con `-o`
- [ ] Seguir redirect con `-L`
- [ ] Identificar status 200, 301, 404, 500 en ejemplos reales
- [ ] Completar los 4 ejercicios prácticos
- [ ] Entregar el proyecto semanal

---

## APIs Publicas para Practicar

- `https://httpbin.org` — refleja tus requests, ideal para aprender
- `https://api.github.com` — API REST real, sin auth para endpoints públicos
- `https://jsonplaceholder.typicode.com` — datos de prueba JSON

---

## Navegacion

Siguiente: [Semana 2: Métodos HTTP, Headers y JSON](../week-02-metodos_http_headers_json/README.md)
