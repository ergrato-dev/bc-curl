# Semana 4: Archivos, Formularios y Multipart

## Objetivos de Aprendizaje

Al finalizar esta semana, serás capaz de:

- Descargar archivos con curl (imágenes, PDFs, binarios)
- Continuar descargas interrumpidas con `-C -`
- Subir archivos con multipart form-data usando `-F`
- Enviar form data URL-encoded con `-d` y `--data-urlencode`
- Diferenciar `multipart/form-data` de `application/x-www-form-urlencoded`
- Especificar tipos MIME explícitos en uploads
- Usar `--progress-bar` para monitorear descargas grandes
- Controlar ancho de banda, timeouts y reintentos de transferencia

---

## Requisitos Previos

- Semanas 1, 2 y 3 completadas
- curl instalado (7.x o superior)
- Acceso a internet
- Espacio en disco para archivos de prueba

---

## Estructura de la Semana

```
week-04-archivos_formularios_multipart/
├── README.md
├── rubrica-evaluacion.md
├── 1-teoria/
│   ├── 01-descargar-archivos.md
│   ├── 02-form-urlencoded.md
│   ├── 03-multipart-upload.md
│   ├── 04-upload-json-vs-multipart.md
│   └── 05-transferencia-avanzada.md
├── 2-practicas/
│   ├── README.md
│   ├── 01-ejercicio-descargas/
│   ├── 02-ejercicio-form-post/
│   ├── 03-ejercicio-upload/
│   └── 04-ejercicio-combinado/
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
| [01 - Descargar archivos](1-teoria/01-descargar-archivos.md) | 20 min | `-o`, `-O`, `-C -`, `--progress-bar`, múltiples URLs |
| [02 - Form URL-encoded](1-teoria/02-form-urlencoded.md) | 25 min | Formularios HTML clásicos, `-d`, `--data-urlencode` |
| [03 - Multipart upload](1-teoria/03-multipart-upload.md) | 30 min | `-F`, subir archivos, MIME type explícito |
| [04 - JSON vs multipart](1-teoria/04-upload-json-vs-multipart.md) | 20 min | Cuándo usar cada formato, casos mixtos |
| [05 - Transferencia avanzada](1-teoria/05-transferencia-avanzada.md) | 25 min | `--limit-rate`, timeouts, `--retry`, rango de bytes |

### Practica (4 horas)

| Ejercicio | Duración | Descripción |
|-----------|----------|-------------|
| [01 - Descargas](2-practicas/01-ejercicio-descargas/) | 45 min | Descargar varios tipos de archivo, reanudar descarga |
| [02 - Form POST](2-practicas/02-ejercicio-form-post/) | 45 min | Formularios URL-encoded con caracteres especiales |
| [03 - Upload](2-practicas/03-ejercicio-upload/) | 60 min | Subir archivos con multipart a httpbin |
| [04 - Combinado](2-practicas/04-ejercicio-combinado/) | 90 min | Request con texto + archivo, simular perfil de usuario |

### Proyecto (2 horas)

File manager CLI: script `file-ops.sh` con subcomandos `download`, `upload` y `form-post` usando httpbin como backend.

---

## Checklist de Verificacion

Antes de pasar a la Semana 5:

- [ ] Descargar un archivo con `-o nombre.ext` y verificar con `wc -c`
- [ ] Descargar con `-O` y confirmar que usa el nombre del servidor
- [ ] Usar `--progress-bar` en una descarga
- [ ] Enviar form data URL-encoded a `https://httpbin.org/post`
- [ ] Usar `--data-urlencode` con un valor que tenga espacios
- [ ] Subir un archivo con `-F "campo=@archivo.txt"`
- [ ] Combinar campo de texto y archivo en un mismo request multipart
- [ ] Especificar MIME type explícito en un upload con `;type=`
- [ ] Completar los 4 ejercicios prácticos
- [ ] Entregar el proyecto semanal

---

## APIs Publicas para Practicar

- `https://httpbin.org/post` — refleja todo lo que envías, ideal para inspeccionar multipart
- `https://httpbin.org/get` — para pruebas GET con descarga de respuesta
- `https://httpbin.org/stream-bytes/N` — generar archivos de tamaño N para practicar descargas

---

## Navegacion

Anterior: [Semana 3: Autenticación básica](../week-03-autenticacion_basica/README.md)

Siguiente: [Semana 5: SSL/TLS, Cookies y Redirects](../week-05-ssl_tls_cookies_redirects/README.md)
