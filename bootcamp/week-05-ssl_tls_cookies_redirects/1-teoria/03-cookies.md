# Cookies con curl

![Cookies con curl](../0-assets/03-cookies.svg)

## Qué son las cookies HTTP

Las cookies son pequeñas piezas de datos que el servidor le pide al cliente que guarde y reenvíe en requests futuros. Son el mecanismo principal para mantener estado en HTTP, que es un protocolo stateless por diseño.

**Flujo básico:**

```
Cliente                              Servidor
  |--- GET /login ----------------->|
  |<-- Set-Cookie: session=abc123 --|   el servidor setea la cookie
  |                                 |
  |--- GET /perfil                  |
  |    Cookie: session=abc123 ----->|   el cliente la reenvía
  |<-- 200 OK (datos del perfil) ---|
```

El header `Set-Cookie` en la respuesta crea la cookie. El header `Cookie` en el request la envía de vuelta.

---

## Ver las cookies que setea un servidor

Con `-v` podés ver los headers completos:

```bash
curl -v "https://httpbin.org/cookies/set?usuario=ana&rol=admin" 2>&1 | grep -i "set-cookie\|location"
```

httpbin setea las cookies indicadas en la query string y responde con un redirect a `/cookies`.

---

## Guardar cookies en archivo con -c

`-c` (cookie-jar) le dice a curl que guarde en un archivo todas las cookies que el servidor envíe durante la sesión:

```bash
# Las cookies que httpbin seta quedan guardadas en cookies.txt
curl -c cookies.txt "https://httpbin.org/cookies/set?session=abc123&usuario=ana"

# Ver el contenido del archivo
cat cookies.txt
```

El archivo usa el formato Netscape cookie jar. Cada línea es una cookie con campos separados por tabs:

```
# Netscape HTTP Cookie File
#httpbin.org	FALSE	/	FALSE	0	session	abc123
#httpbin.org	FALSE	/	FALSE	0	usuario	ana
```

---

## Enviar cookies desde archivo con -b

`-b` (cookie) le dice a curl que envíe las cookies del archivo en el request:

```bash
# Reenviar las cookies guardadas antes
curl -b cookies.txt https://httpbin.org/cookies
```

La respuesta de `httpbin.org/cookies` muestra las cookies que recibió:

```json
{
  "cookies": {
    "session": "abc123",
    "usuario": "ana"
  }
}
```

---

## Enviar una cookie manual con -b

También podés especificar el valor de una cookie directamente, sin archivo:

```bash
# Enviar una cookie específica
curl -b "session=abc123" https://httpbin.org/cookies

# Enviar múltiples cookies
curl -b "session=abc123; usuario=ana; rol=admin" https://httpbin.org/cookies
```

---

## Flujo completo: login con cookie

El patrón más común: hacer POST de login, guardar la cookie de sesión, y usarla en requests posteriores.

```bash
# Paso 1: "Login" - el servidor setea la cookie de sesión
# (httpbin simula esto con /cookies/set)
curl -c mi-sesion.txt -L \
     "https://httpbin.org/cookies/set?session_id=secreto123&user=ana"

# Paso 2: Request autenticado - enviar la cookie de sesión
curl -b mi-sesion.txt https://httpbin.org/cookies

# Paso 3: Verificar que la sesión sigue activa
curl -b mi-sesion.txt https://httpbin.org/get
```

Para mantener la sesión activa y también guardar nuevas cookies que el servidor pueda setear durante la sesión, usá `-b` y `-c` juntos:

```bash
# Leer Y escribir cookies en el mismo archivo
curl -b mi-sesion.txt -c mi-sesion.txt https://httpbin.org/cookies
```

---

## Inspeccionar las cookies con -v

```bash
curl -v -b cookies.txt https://httpbin.org/cookies 2>&1 | grep -i "cookie"
```

Verás las cookies que curl envía en el header `Cookie:`:

```
> Cookie: session=abc123; usuario=ana
```

---

## Cuándo expiran las cookies

En el archivo cookie jar hay una columna de timestamp Unix de expiración. Si es `0` la cookie expira cuando se cierra el browser (session cookie). curl las trata igual que un browser: no reenvía cookies expiradas.

Podés ver las cookies con expiración:

```bash
# Setear cookie con expiración
curl -c cookies.txt "https://httpbin.org/cookies/set?token=xyz"
grep -v "^#" cookies.txt
```

---

## Resumen

| Flag | Función |
|------|---------|
| `-c archivo.txt` | Guardar cookies recibidas en archivo (cookie-jar) |
| `-b archivo.txt` | Enviar cookies desde archivo |
| `-b "clave=valor"` | Enviar cookie con valor literal |
| `-b archivo -c archivo` | Leer y actualizar cookies en el mismo archivo |
| `-v` | Ver headers Cookie y Set-Cookie en la sesión |
