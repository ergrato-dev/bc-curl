# Semana 5: SSL/TLS, Cookies y Redirects

## Objetivos de Aprendizaje

Al finalizar esta semana, serás capaz de:

- Entender cómo curl verifica certificados SSL/TLS automáticamente
- Manejar certificados auto-firmados y CAs privadas con `--cacert`
- Configurar certificados cliente para mTLS con `--cert` y `--key`
- Guardar y enviar cookies con `-c` y `-b`
- Implementar flujos de sesión completos (login → requests autenticados)
- Controlar el seguimiento de redirects con `-L` y `--max-redirs`
- Inspeccionar la cadena completa de redirects con `-v`
- Configurar timeouts y reintentos de forma correcta para producción

---

## Requisitos Previos

- Semanas 1 a 4 completadas
- curl instalado (7.x o superior)
- openssl disponible en el sistema (`openssl version`)
- Acceso a internet

---

## Estructura de la Semana

```
week-05-ssl_tls_cookies_redirects/
├── README.md
├── rubrica-evaluacion.md
├── 1-teoria/
│   ├── 01-ssl-tls-curl.md
│   ├── 02-certificados-custom.md
│   ├── 03-cookies.md
│   ├── 04-redirects.md
│   └── 05-timeouts-y-reintentos.md
├── 2-practicas/
│   ├── README.md
│   ├── 01-ejercicio-ssl/
│   ├── 02-ejercicio-cookies/
│   ├── 03-ejercicio-redirects/
│   └── 04-ejercicio-timeouts/
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
| [01 - SSL/TLS con curl](1-teoria/01-ssl-tls-curl.md) | 25 min | Verificación de certificados, `--insecure`, cuándo y por qué |
| [02 - Certificados custom](1-teoria/02-certificados-custom.md) | 25 min | `--cacert`, `--cert`, `--key`, mTLS, cert auto-firmado |
| [03 - Cookies](1-teoria/03-cookies.md) | 25 min | Guardar con `-c`, enviar con `-b`, flujo de sesión |
| [04 - Redirects](1-teoria/04-redirects.md) | 20 min | `-L`, `--max-redirs`, cadena de redirects, métodos en redirect |
| [05 - Timeouts y reintentos](1-teoria/05-timeouts-y-reintentos.md) | 25 min | `--connect-timeout`, `--max-time`, `--retry`, estrategias |

### Practica (4 horas)

| Ejercicio | Duración | Descripción |
|-----------|----------|-------------|
| [01 - SSL](2-practicas/01-ejercicio-ssl/) | 45 min | Verificar SSL, inspeccionar certs, entender errores |
| [02 - Cookies](2-practicas/02-ejercicio-cookies/) | 60 min | Guardar y reenviar cookies, flujo de sesión completo |
| [03 - Redirects](2-practicas/03-ejercicio-redirects/) | 45 min | Seguir y limitar redirects, ver cadena completa |
| [04 - Timeouts](2-practicas/04-ejercicio-timeouts/) | 90 min | Forzar timeouts, configurar reintentos |

### Proyecto (2 horas)

SSL & Session checker: script `session.sh` que simula login con cookies, mantiene sesión en archivo, hace requests autenticados y tiene configuración de timeout y retry.

---

## Checklist de Verificacion

Antes de pasar a la Semana 6:

- [ ] Verificar que curl valida SSL por defecto en un site HTTPS
- [ ] Ver información del certificado con `-v` en un site real
- [ ] Entender cuándo es aceptable usar `--insecure` (solo desarrollo)
- [ ] Guardar cookies en archivo con `-c cookies.txt`
- [ ] Reenviar cookies desde archivo con `-b cookies.txt`
- [ ] Completar flujo login → request autenticado con cookies
- [ ] Seguir redirect con `-L` y ver la diferencia sin el flag
- [ ] Usar `--max-redirs 3` para limitar la cadena de redirects
- [ ] Configurar `--connect-timeout` y `--max-time` correctamente
- [ ] Completar los 4 ejercicios prácticos
- [ ] Entregar el proyecto semanal

---

## APIs Publicas para Practicar

- `https://httpbin.org/cookies` — inspeccionar cookies que curl envía
- `https://httpbin.org/cookies/set?nombre=valor` — que el servidor setee una cookie
- `https://httpbin.org/redirect/N` — cadena de N redirects
- `https://httpbin.org/delay/N` — respuesta demorada N segundos (para probar timeouts)

---

## Navegacion

Anterior: [Semana 4: Archivos, Formularios y Multipart](../week-04-archivos_formularios_multipart/README.md)

Siguiente: [Semana 6: Output, Debug y Configuración](../week-06-output_debug_configuracion/README.md)
