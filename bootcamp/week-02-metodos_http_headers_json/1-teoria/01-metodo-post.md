# Método POST

## Qué hace POST

GET pide datos. POST los envía. Cuando llenás un formulario en una web y hacés click en "Enviar", el browser realiza un POST. Cuando una app crea un usuario nuevo, hace un POST.

POST tiene body: información que va junto al request, en el cuerpo del mensaje, no en la URL.

---

## Flag -d / --data

El flag `-d` (de "data") envía el body del request. Automáticamente cambia el método a POST.

```bash
# Enviar datos de formulario (application/x-www-form-urlencoded)
curl -d "nombre=Ana&edad=30" https://httpbin.org/post
```

`-d` y `--data` son equivalentes. La forma larga es más legible en scripts.

Cuando usás `-d`, curl:
1. Cambia el método a POST
2. Setea `Content-Type: application/x-www-form-urlencoded` por defecto
3. Envía el string tal como está en el body

---

## Enviar desde un string literal

```bash
# JSON en string literal
curl -d '{"titulo": "mi post", "cuerpo": "contenido"}' \
     -H "Content-Type: application/json" \
     https://httpbin.org/post
```

Notá las comillas simples afuera del JSON: permiten usar comillas dobles adentro sin escapar.

---

## Enviar desde un archivo con @

Cuando el body es largo o vas a reutilizarlo, conviene guardarlo en un archivo y referenciar con `@`:

```bash
# Crear el archivo
cat datos.json
{
  "title": "mi titulo",
  "body": "el contenido del post",
  "userId": 1
}

# Enviarlo con @nombre-de-archivo
curl -d @datos.json \
     -H "Content-Type: application/json" \
     https://httpbin.org/post
```

El `@` le dice a curl "leé el contenido de este archivo y usalo como body".

---

## La importancia de Content-Type

El servidor necesita saber en qué formato llegan los datos. Sin `Content-Type` correcto, la API puede rechazar el request o parsearlo mal.

| Formato | Content-Type |
|---------|-------------|
| JSON | `application/json` |
| Formulario HTML | `application/x-www-form-urlencoded` |
| Multipart/form | `multipart/form-data` |
| Texto plano | `text/plain` |

Para APIs REST modernas, casi siempre vas a usar `application/json`.

---

## Verificar qué envía curl con httpbin

httpbin.org/post refleja exactamente lo que recibió:

```bash
curl -d '{"name": "test"}' \
     -H "Content-Type: application/json" \
     https://httpbin.org/post
```

Respuesta:
```json
{
  "args": {},
  "data": "{\"name\": \"test\"}",
  "files": {},
  "form": {},
  "headers": {
    "Content-Type": "application/json",
    "Content-Length": "16"
  },
  "json": {
    "name": "test"
  },
  "url": "https://httpbin.org/post"
}
```

El campo `json` confirma que el servidor parseó correctamente el body.

---

## Ejemplo completo: crear un post en jsonplaceholder

```bash
curl -X POST \
     -H "Content-Type: application/json" \
     -d '{"title": "foo", "body": "bar", "userId": 1}' \
     https://jsonplaceholder.typicode.com/posts
```

Respuesta esperada (status 201 Created):
```json
{
  "title": "foo",
  "body": "bar",
  "userId": 1,
  "id": 101
}
```

El `id: 101` es generado por el servidor — señal de que el recurso fue "creado".

---

## Ver el status code

Para confirmar que el servidor respondió 201:

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
     -X POST \
     -H "Content-Type: application/json" \
     -d '{"title": "foo", "body": "bar", "userId": 1}' \
     https://jsonplaceholder.typicode.com/posts
```

Salida: `201`
