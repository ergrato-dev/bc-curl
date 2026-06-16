# Semana 2: Métodos HTTP, Headers y JSON

## Objetivos de Aprendizaje

Al finalizar esta semana, serás capaz de:

- Usar POST, PUT, PATCH y DELETE con curl
- Enviar datos en el body de un request con `-d` y `--data`
- Setear Content-Type y Accept con `-H`
- Leer y enviar headers custom
- Cargar el body desde un archivo externo con `-d @archivo.json`
- Usar httpbin.org para verificar exactamente qué envía curl
- Interpretar respuestas con status 201, 204, 404, 422

---

## Requisitos Previos

- Semana 1 completada
- curl instalado y funcionando
- Conocimiento básico de JSON (clave/valor, arrays, objetos anidados)

---

## Estructura de la Semana

```
week-02-metodos_http_headers_json/
├── README.md
├── rubrica-evaluacion.md
├── 1-teoria/
│   ├── 01-metodo-post.md
│   ├── 02-put-patch-delete.md
│   ├── 03-json-con-curl.md
│   ├── 04-headers-custom.md
│   └── 05-metodo-options-head.md
├── 2-practicas/
│   ├── README.md
│   ├── 01-ejercicio-post/
│   ├── 02-ejercicio-crud/
│   ├── 03-ejercicio-headers/
│   └── 04-ejercicio-json-archivo/
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
| [01 - Método POST](1-teoria/01-metodo-post.md) | 25 min | Enviar datos al servidor, flag `-d`, desde archivo |
| [02 - PUT, PATCH y DELETE](1-teoria/02-put-patch-delete.md) | 25 min | Actualizar y eliminar recursos, diferencias entre verbos |
| [03 - JSON con curl](1-teoria/03-json-con-curl.md) | 30 min | Enviar y recibir JSON, comillas, formateo |
| [04 - Headers custom](1-teoria/04-headers-custom.md) | 20 min | `-H`, headers comunes, observar con `-v` |
| [05 - OPTIONS y HEAD](1-teoria/05-metodo-options-head.md) | 20 min | Verificar metadatos y métodos permitidos |

### Practica (4 horas)

| Ejercicio | Duración | Descripción |
|-----------|----------|-------------|
| [01 - POST](2-practicas/01-ejercicio-post/) | 45 min | Crear recursos en jsonplaceholder |
| [02 - CRUD completo](2-practicas/02-ejercicio-crud/) | 90 min | GET, POST, PUT, PATCH, DELETE sobre el mismo recurso |
| [03 - Headers](2-practicas/03-ejercicio-headers/) | 45 min | Experimentar con headers y observar httpbin |
| [04 - JSON desde archivo](2-practicas/04-ejercicio-json-archivo/) | 60 min | Leer y escribir JSON desde archivos |

### Proyecto (2 horas)

Mini cliente REST: script bash `crud.sh` que acepta argumentos (list, get, create, update, delete) y ejecuta el curl correspondiente contra jsonplaceholder/todos.

---

## Checklist de Verificacion

Antes de pasar a la Semana 3:

- [ ] Realizar POST a `https://httpbin.org/post` con JSON y verificar que lo refleja
- [ ] Crear un post en jsonplaceholder con POST y recibir 201
- [ ] Actualizar un recurso con PUT y verificar que los campos cambiaron
- [ ] Modificar un solo campo con PATCH
- [ ] Eliminar un recurso con DELETE y recibir 200
- [ ] Enviar `-H "Content-Type: application/json"` en todos los POST/PUT/PATCH
- [ ] Cargar un body desde archivo con `-d @datos.json`
- [ ] Formatear JSON de respuesta con `python3 -m json.tool`
- [ ] Completar los 4 ejercicios prácticos
- [ ] Entregar el proyecto semanal

---

## APIs Publicas para Practicar

- `https://httpbin.org` — refleja tus requests, ideal para inspeccionar lo que curl envía
- `https://jsonplaceholder.typicode.com` — datos de prueba, acepta POST/PUT/PATCH/DELETE
- `https://reqres.in` — API REST realista con respuestas predecibles

---

## Navegacion

Anterior: [Semana 1: HTTP y curl básico](../week-01-http_y_curl_basico/README.md)

Siguiente: [Semana 3: Autenticación básica](../week-03-autenticacion_basica/README.md)
