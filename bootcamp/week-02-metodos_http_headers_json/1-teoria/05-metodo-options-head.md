# Métodos OPTIONS y HEAD

## HEAD: obtener metadatos sin descargar el body

HEAD hace exactamente lo mismo que GET, pero el servidor solo devuelve los headers — el body no se transmite. Esto es útil cuando querés verificar si un recurso existe, ver su tamaño, o revisar sus metadatos sin descargarlo.

```bash
curl -I https://httpbin.org/get
```

Salida:
```
HTTP/2 200
date: Mon, 15 Jun 2026 10:00:00 GMT
content-type: application/json
content-length: 252
access-control-allow-origin: *
```

Sabés que el recurso existe (200), su tipo y tamaño, sin haber descargado nada.

---

## Casos de uso de HEAD

**Verificar si un archivo existe antes de descargarlo:**

```bash
curl -sI https://example.com/archivo-grande.zip | grep -i "HTTP/"
# HTTP/2 200  → existe
# HTTP/2 404  → no existe
```

**Conocer el tamaño de un archivo antes de descargarlo:**

```bash
curl -sI https://httpbin.org/image/jpeg | grep -i "content-length"
# content-length: 35588
```

**Verificar si un servidor está activo (health check):**

```bash
curl -sI -o /dev/null -w "%{http_code}" https://httpbin.org/get
# 200
```

**Comparar fechas de modificación:**

```bash
curl -sI https://example.com/recurso | grep -i "last-modified"
# last-modified: Sat, 01 Jun 2026 12:00:00 GMT
```

---

## -I vs -X HEAD

Ambas formas hacen HEAD request:

```bash
curl -I https://httpbin.org/get
curl -X HEAD https://httpbin.org/get
```

`-I` es el shorthand dedicado. `-X HEAD` es más explícito. En la práctica se usa `-I`.

---

## OPTIONS: consultar qué métodos acepta un endpoint

OPTIONS le pregunta al servidor qué métodos HTTP soporta en un endpoint determinado. El servidor responde con el header `Allow` listando los métodos permitidos.

```bash
curl -X OPTIONS https://httpbin.org/anything -v 2>&1 | grep -i "allow\|HTTP/"
```

Salida:
```
< HTTP/2 200
< allow: GET, HEAD, POST, OPTIONS
```

---

## OPTIONS en CORS (preflight)

El caso de uso más importante de OPTIONS es el preflight request de CORS (Cross-Origin Resource Sharing). Cuando un browser hace un request "no simple" (con Content-Type: application/json, o con métodos no-GET/POST, o con headers custom), primero envía un OPTIONS automáticamente para preguntar si el servidor lo permite.

```bash
# Simular un preflight CORS
curl -X OPTIONS \
     -H "Origin: https://mi-app.com" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: Content-Type, Authorization" \
     -v https://httpbin.org/post 2>&1 | grep -i "access-control"
```

Las headers de respuesta relevantes:
- `Access-Control-Allow-Origin` — qué orígenes están permitidos
- `Access-Control-Allow-Methods` — qué métodos están permitidos
- `Access-Control-Allow-Headers` — qué headers custom están permitidos

---

## Comparación HEAD vs OPTIONS vs GET

| | GET | HEAD | OPTIONS |
|-|-----|------|---------|
| Devuelve body | Sí | No | No |
| Devuelve headers | Sí | Sí | Sí |
| Para qué sirve | Obtener recurso | Verificar metadatos | Consultar métodos permitidos |
| Modifica el servidor | No | No | No |

---

## Ejemplo práctico: chequear una API antes de usarla

```bash
# 1. Verificar que el endpoint existe y responde
curl -sI https://jsonplaceholder.typicode.com/posts/1 | head -1

# 2. Ver qué Content-Type devuelve
curl -sI https://jsonplaceholder.typicode.com/posts/1 | grep -i content-type

# 3. Verificar qué métodos acepta
curl -sX OPTIONS https://jsonplaceholder.typicode.com/posts/1 -v 2>&1 | grep -i allow
```

Estos tres pasos te dan información suficiente sobre un endpoint sin hacer una request real que pueda modificar datos.
