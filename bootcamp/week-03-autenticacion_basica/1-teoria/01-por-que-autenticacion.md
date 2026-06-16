# Por qué existe la autenticación en APIs

![Autenticación en APIs](../0-assets/01-por-que-autenticacion.svg)

## El problema del request anónimo

Sin autenticación, cualquier persona con acceso a internet puede hacer requests a una API. Eso es aceptable para datos públicos (clima, noticias, tipos de cambio), pero no para datos privados (cuentas bancarias, mensajes, información médica).

La autenticación resuelve la pregunta: ¿quién está haciendo este request?

---

## Autenticación vs Autorización

Dos conceptos que se confunden constantemente pero son distintos:

**Autenticación** — Verificar la identidad. Quién sos.
- "Soy el usuario Ana con contraseña xyz123"
- "Soy el cliente con API Key abc-456"
- "Tengo este token que obtuvo el usuario Ana"

**Autorización** — Verificar permisos. Qué podés hacer.
- "Ana puede leer sus propios datos pero no los de otros usuarios"
- "Este API Key solo permite lectura, no escritura"
- "Este token tiene permiso para acceder a /reports pero no a /admin"

El servidor primero autentica (¿quién sos?) y luego autoriza (¿podés hacer esto?).

```
Request → Autenticación → ¿Quién sos? → Autorización → ¿Podés hacer esto? → Respuesta
```

---

## Los mecanismos más comunes en APIs REST

### 1. HTTP Basic Authentication

Envía usuario y contraseña codificados en base64 en el header `Authorization`.

```
Authorization: Basic dXNlcjpwYXNzd29yZA==
```

- Simple de implementar
- Requiere HTTPS obligatoriamente (las credenciales viajan en cada request)
- Se usa en: APIs internas, servicios simples, herramientas de desarrollo

### 2. API Keys

Token estático generado por el servicio que identifica a un cliente.

```
X-API-Key: sk-abc123def456...
```

- Fácil de generar y rotar
- No identifica un usuario específico, sino una aplicación
- Se usa en: servicios públicos con límite de uso, SDKs, herramientas de terceros

### 3. Bearer Tokens / JWT

Token temporal obtenido después de un login exitoso. Se incluye en el header `Authorization`.

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

- El token tiene fecha de expiración
- Puede contener información del usuario (claims) en el propio token
- Es el estándar moderno para APIs web y móviles
- Se usa en: aplicaciones con usuarios, OAuth2, SSO

---

## Cuándo usar cada uno

| Mecanismo | Cuándo usarlo |
|-----------|--------------|
| Basic Auth | APIs internas, prototipos, autenticación de servicios servidor-a-servidor simple |
| API Key | Acceso de aplicaciones a servicios externos, webhooks, rate limiting |
| Bearer/JWT | Aplicaciones con usuarios humanos, tokens de sesión, OAuth2 |

---

## Qué pasa sin autenticación: el 401

Cuando hacés un request a un endpoint protegido sin credenciales (o con credenciales incorrectas), el servidor responde 401 Unauthorized.

```bash
curl -v https://httpbin.org/basic-auth/user/pass 2>&1 | grep "< HTTP"
# < HTTP/2 401
```

El 401 significa "no sabemos quién sos" (no es lo mismo que 403, que significa "sabemos quién sos pero no tenés permiso").

| Status | Significado |
|--------|------------|
| 401 Unauthorized | Sin autenticación o credenciales inválidas |
| 403 Forbidden | Autenticado pero sin permiso para este recurso |

---

## El flujo general

```
1. Cliente → POST /login (usuario + contraseña)
2. Servidor → 200 OK (token de acceso)
3. Cliente → GET /datos (Authorization: Bearer TOKEN)
4. Servidor → 200 OK (datos del usuario)
```

Con Basic Auth y API Keys el paso 1-2 no existe: las credenciales van directamente en cada request.
