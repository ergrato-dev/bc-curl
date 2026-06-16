# Ejercicio 01: Basic Auth

## Objetivo

Practicar HTTP Basic Authentication con curl. Observar el header generado. Provocar 401 con credenciales incorrectas y sin credenciales. Entender qué diferencia hay en el comportamiento del servidor.

## API de práctica

`https://httpbin.org/basic-auth/{user}/{passwd}` — reemplazá `{user}` y `{passwd}` por las credenciales que querés verificar. Si el request llega con esas mismas credenciales, responde 200. Si no, 401.

---

## Tareas

### 1. Request sin credenciales (provocar 401)

```bash
curl -v https://httpbin.org/basic-auth/alumno/secreto 2>&1
```

Observar:
- El status code (debe ser 401)
- El header `WWW-Authenticate` en la respuesta (qué tipo de auth pide el servidor)
- El body de la respuesta 401

### 2. Request con credenciales incorrectas (401 también)

```bash
curl -v -u alumno:password-incorrecto https://httpbin.org/basic-auth/alumno/secreto 2>&1
```

Observar:
- ¿El servidor distingue "sin credenciales" de "credenciales incorrectas" en el status code?
- ¿Y en el body o en los headers?

### 3. Request con credenciales correctas (200)

```bash
curl -v -u alumno:secreto https://httpbin.org/basic-auth/alumno/secreto 2>&1
```

Observar:
- El status 200
- El header `Authorization` en el request (líneas con `>`)
- El body de la respuesta

### 4. Ver el header Authorization que curl genera

```bash
curl -v -u alumno:secreto https://httpbin.org/basic-auth/alumno/secreto 2>&1 | grep "Authorization"
```

Copiar el valor del header (el string `Basic XXXX`).

### 5. Decodificar el header para verificar

```bash
# El valor después de "Basic " es base64 de "usuario:contraseña"
echo "YWx1bW5vOnNlY3JldG8=" | base64 -d
```

Reemplazá `YWx1bW5vOnNlY3JldG8=` por el valor real del paso 4.

Deberías ver `alumno:secreto` — confirma que base64 no es cifrado.

### 6. Construir el header manualmente

Sin usar `-u`, construir el header `Authorization` a mano:

```bash
CREDS=$(echo -n "alumno:secreto" | base64)
echo "Header: Authorization: Basic $CREDS"

curl -s -H "Authorization: Basic $CREDS" https://httpbin.org/basic-auth/alumno/secreto
```

El resultado debe ser idéntico a usar `-u alumno:secreto`.

### 7. Ver qué refleja httpbin del header

```bash
curl -s -u alumno:secreto https://httpbin.org/headers | python3 -m json.tool
```

Verificar que `Authorization: Basic XXXX` aparece en los headers reflejados.

---

## Preguntas para responder

1. ¿Cuál es la diferencia entre 401 y 403?
2. ¿Por qué base64 no es lo mismo que cifrado?
3. ¿Por qué Basic Auth requiere HTTPS obligatoriamente?
4. ¿Qué ventaja tiene `-u user:pass` sobre construir el header manualmente?

---

## Entrega

Archivo `respuestas.md` con:
1. Output completo del paso 3 (credenciales correctas con `-v`)
2. El valor decodificado del header del paso 5
3. El output del paso 6 (header construido manualmente)
4. Respuestas a las 4 preguntas
