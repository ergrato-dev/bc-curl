# Semana 8: OAuth2 y Autenticación Avanzada

## Objetivos de Aprendizaje

Al finalizar esta semana, serás capaz de:

- Explicar el protocolo OAuth2 y sus cuatro flujos principales
- Implementar el flujo Client Credentials con curl
- Ejecutar manualmente el flujo Authorization Code (pasos 3 y 4)
- Usar y renovar refresh tokens desde scripts bash
- Decodificar e inspeccionar tokens JWT sin herramientas externas
- Implementar un sistema de token lifecycle que gestiona expiración automáticamente

---

## Requisitos Previos

- Semana 7 completada (scripting bash con curl)
- Conocimiento de variables bash, funciones y manejo de archivos
- Acceso a un OAuth2 server de prueba (se usa httpbin y servicios demo gratuitos)

---

## Estructura de la Semana

```
week-08-oauth2_y_autenticacion_avanzada/
├── README.md
├── rubrica-evaluacion.md
├── 1-teoria/
│   ├── 01-oauth2-conceptos.md
│   ├── 02-client-credentials.md
│   ├── 03-authorization-code.md
│   ├── 04-refresh-tokens.md
│   └── 05-jwt-inspeccion.md
├── 2-practicas/
│   ├── README.md
│   ├── 01-ejercicio-client-credentials/
│   ├── 02-ejercicio-token-lifecycle/
│   ├── 03-ejercicio-refresh/
│   └── 04-ejercicio-oauth-real/
├── 3-proyecto/
│   └── README.md
└── 5-glosario/
    └── README.md
```

---

## Contenidos

### Teoría (2.5 horas)

| Tema | Duracion | Descripción |
|------|----------|-------------|
| [01 - OAuth2: conceptos](1-teoria/01-oauth2-conceptos.md) | 30 min | Protocolo, roles, flujos, tokens |
| [02 - Client Credentials](1-teoria/02-client-credentials.md) | 30 min | Flujo app-a-app, obtener y usar token |
| [03 - Authorization Code](1-teoria/03-authorization-code.md) | 30 min | Flujo con usuario, PKCE |
| [04 - Refresh tokens](1-teoria/04-refresh-tokens.md) | 30 min | Renovación automatica de tokens |
| [05 - JWT: inspeccion](1-teoria/05-jwt-inspeccion.md) | 30 min | Decodificar y verificar JWT con bash |

### Práctica (4 horas)

| Ejercicio | Duracion | Descripción |
|-----------|----------|-------------|
| [01 - Client Credentials](2-practicas/01-ejercicio-client-credentials/) | 60 min | Obtener token y acceder a recurso protegido |
| [02 - Token lifecycle](2-practicas/02-ejercicio-token-lifecycle/) | 60 min | Script que gestiona token de forma transparente |
| [03 - Refresh token](2-practicas/03-ejercicio-refresh/) | 60 min | Simular expiración y renovar token |
| [04 - OAuth real](2-practicas/04-ejercicio-oauth-real/) | 60 min | Flujo completo con API real |

### Proyecto (2 horas)

Script `oauth-client.sh`: cliente OAuth2 completo con subcomandos `login`, `logout`, `call`. Gestiona token lifecycle de forma transparente. Funciona contra cualquier OAuth2 server configurable.

---

## Checklist de Verificación

Antes de pasar a la Semana 9:

- [ ] Explicar la diferencia entre Authorization Server y Resource Server
- [ ] Obtener un token con Client Credentials usando curl
- [ ] Usar ese token como Bearer en un request subsiguiente
- [ ] Decodificar el payload de un JWT con base64
- [ ] Extraer el campo `exp` de un JWT y compararlo con `date +%s`
- [ ] Implementar renovacion automatica de token en un script
- [ ] Completar los 4 ejercicios practicos
- [ ] Entregar el proyecto `oauth-client.sh`

---

## Recursos Clave

- RFC 6749 — OAuth 2.0 Authorization Framework
- `https://oauth.tools` — visualizador interactivo de flujos OAuth2
- `https://jwt.io` — decodificador JWT (solo para tokens de desarrollo)
- `https://demo.duendesoftware.com` — servidor OAuth2 de demo publico
- `https://httpbin.org/bearer` — endpoint de prueba para Bearer tokens

---

## Navegación

Anterior: [Semana 7: Scripting bash con curl](../week-07-scripting_bash_con_curl/README.md)
Siguiente: [Semana 9: HTTP/2, Paralelismo y Performance](../week-09-http2_paralelismo_performance/README.md)
