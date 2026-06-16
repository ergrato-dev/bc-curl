# Semana 3: Autenticación básica

## Objetivos de Aprendizaje

Al finalizar esta semana, serás capaz de:

- Distinguir entre autenticación (quién sos) y autorización (qué podés hacer)
- Usar HTTP Basic Auth con curl: `-u user:pass`
- Enviar API Keys en header con `-H` y en query string
- Usar Bearer tokens (JWT) con `-H "Authorization: Bearer TOKEN"`
- Decodificar el payload de un JWT sin librerías externas
- Guardar credenciales en variables de entorno y evitar hardcodearlas
- Saber cuándo usar cada mecanismo de autenticación

---

## Requisitos Previos

- Semanas 1 y 2 completadas
- Conocimiento básico de headers HTTP
- Saber hacer POST y leer el response

---

## Estructura de la Semana

```
week-03-autenticacion_basica/
├── README.md
├── rubrica-evaluacion.md
├── 1-teoria/
│   ├── 01-por-que-autenticacion.md
│   ├── 02-basic-auth.md
│   ├── 03-api-keys.md
│   ├── 04-bearer-tokens-jwt.md
│   └── 05-variables-entorno-seguridad.md
├── 2-practicas/
│   ├── README.md
│   ├── 01-ejercicio-basic-auth/
│   ├── 02-ejercicio-api-key/
│   ├── 03-ejercicio-bearer-token/
│   └── 04-ejercicio-variables-entorno/
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
| [01 - Por qué autenticación](1-teoria/01-por-que-autenticacion.md) | 20 min | Autenticación vs autorización, mecanismos comunes |
| [02 - Basic Auth](1-teoria/02-basic-auth.md) | 25 min | `-u user:pass`, base64, por qué requiere HTTPS |
| [03 - API Keys](1-teoria/03-api-keys.md) | 25 min | Header vs query string, buenas prácticas |
| [04 - Bearer tokens y JWT](1-teoria/04-bearer-tokens-jwt.md) | 30 min | Flujo de login, estructura JWT, decodificar |
| [05 - Variables de entorno y seguridad](1-teoria/05-variables-entorno-seguridad.md) | 20 min | No hardcodear, .env, .gitignore, .netrc |

### Practica (4 horas)

| Ejercicio | Duración | Descripción |
|-----------|----------|-------------|
| [01 - Basic Auth](2-practicas/01-ejercicio-basic-auth/) | 45 min | Probar con httpbin, observar header generado |
| [02 - API Key](2-practicas/02-ejercicio-api-key/) | 45 min | Header vs query string, buenas prácticas |
| [03 - Bearer Token](2-practicas/03-ejercicio-bearer-token/) | 60 min | Flujo login → token → request autenticado |
| [04 - Variables de entorno](2-practicas/04-ejercicio-variables-entorno/) | 60 min | Script con credenciales en variables |

### Proyecto (2 horas)

Auth explorer: script `auth-check.sh` que prueba los tres mecanismos de autenticación y reporta qué responde cada uno.

---

## Checklist de Verificacion

Antes de pasar a la Semana 4:

- [ ] Realizar Basic Auth con `-u user:pass` y ver el header generado con `-v`
- [ ] Intentar acceder sin credenciales y recibir 401
- [ ] Usar una API Key en header con `-H "X-API-Key: ..."`
- [ ] Usar una API Key en query string y entender por qué es menos seguro
- [ ] Completar el flujo login → token → request con reqres.in
- [ ] Decodificar un JWT a mano con base64
- [ ] Leer credenciales desde variables de entorno en un script
- [ ] Completar los 4 ejercicios prácticos
- [ ] Entregar el proyecto semanal

---

## APIs Publicas para Practicar

- `https://httpbin.org/basic-auth/user/passwd` — prueba Basic Auth
- `https://httpbin.org/bearer` — prueba Bearer token
- `https://reqres.in/api/login` — devuelve token real (simulado)
- `https://reqres.in/api/users` — endpoint protegido por token

---

## Navegacion

Anterior: [Semana 2: Métodos HTTP, Headers y JSON](../week-02-metodos_http_headers_json/README.md)

Siguiente: [Semana 4: Archivos, formularios y multipart](../week-04-archivos_formularios_multipart/README.md)
