# Practicas — Semana 8: OAuth2 y Autenticacion Avanzada

Cuatro ejercicios progresivos que cubren los flujos OAuth2 de mayor uso en scripting. Completal en orden — cada uno introduce conceptos que el siguiente usa.

## Ejercicios

| # | Carpeta | Tiempo | Objetivo |
|---|---------|--------|----------|
| 01 | [01-ejercicio-client-credentials](01-ejercicio-client-credentials/) | 60 min | Obtener token con Client Credentials y usarlo |
| 02 | [02-ejercicio-token-lifecycle](02-ejercicio-token-lifecycle/) | 60 min | Gestionar el ciclo de vida del token entre ejecuciones |
| 03 | [03-ejercicio-refresh](03-ejercicio-refresh/) | 60 min | Simular expiracion y renovar con refresh token |
| 04 | [04-ejercicio-oauth-real](04-ejercicio-oauth-real/) | 60 min | Flujo completo contra una API real |

## Servidor de Prueba Recomendado

Para los ejercicios 01, 02 y 03 se usa el servidor de demo de Duende IdentityServer:

- Token endpoint: `https://demo.duendesoftware.com/connect/token`
- Credenciales de prueba: `client_id=m2m`, `client_secret=secret`, `scope=api`
- API de prueba: `https://demo.duendesoftware.com/api/test`

Este servidor es publico, gratuito y no requiere registro. Los tokens son reales y funcionales.

## Como Entregar

Crear un archivo `respuestas.md` en cada carpeta de ejercicio con:
- Los comandos curl usados
- El output obtenido (redactar datos sensibles si los hay)
- Tu interpretacion del resultado
- Dificultades encontradas y como las resolviste
