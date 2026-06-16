# PUT, PATCH y DELETE

## Los verbos que modifican recursos

HTTP tiene cuatro verbos principales para el ciclo de vida de un recurso:

- `POST` — crear
- `PUT` — reemplazar completamente
- `PATCH` — modificar parcialmente
- `DELETE` — eliminar

La diferencia entre PUT y PATCH es donde más se confunde la gente nueva.

---

## PUT: reemplazar el recurso completo

PUT envía la representación completa del recurso. El servidor reemplaza lo que había con lo que enviás. Si omitís un campo, ese campo queda en blanco o desaparece.

```bash
curl -X PUT \
     -H "Content-Type: application/json" \
     -d '{
       "id": 1,
       "title": "titulo actualizado",
       "body": "cuerpo actualizado",
       "userId": 1
     }' \
     https://jsonplaceholder.typicode.com/posts/1
```

Respuesta:
```json
{
  "id": 1,
  "title": "titulo actualizado",
  "body": "cuerpo actualizado",
  "userId": 1
}
```

Tenés que enviar TODOS los campos. PUT es idempotente: hacerlo dos veces produce el mismo resultado que hacerlo una vez.

---

## PATCH: modificar campos específicos

PATCH envía solo los campos que querés cambiar. El servidor aplica los cambios sobre el recurso existente, manteniendo intacto lo que no se menciona.

```bash
# Solo actualizar el título, sin tocar los demás campos
curl -X PATCH \
     -H "Content-Type: application/json" \
     -d '{"title": "solo cambio el titulo"}' \
     https://jsonplaceholder.typicode.com/posts/1
```

Respuesta:
```json
{
  "userId": 1,
  "id": 1,
  "title": "solo cambio el titulo",
  "body": "quia et suscipit\nsuscipit recusandae..."
}
```

El body original se mantiene. Solo cambió el título.

---

## Cuándo usar PUT vs PATCH

| Situación | Verbo |
|-----------|-------|
| Actualizar todos los datos de un formulario | PUT |
| Cambiar el estado de un pedido (ej: "enviado") | PATCH |
| Actualizar la foto de perfil de un usuario | PATCH |
| Reemplazar la configuración completa de un servicio | PUT |

En la práctica, muchas APIs modernas solo implementan PATCH porque es más flexible. Pero las APIs RESTful estrictas distinguen entre ambos.

---

## DELETE: eliminar un recurso

DELETE no requiere body. Solo necesita la URL del recurso a eliminar.

```bash
curl -X DELETE https://jsonplaceholder.typicode.com/posts/1
```

Respuesta de jsonplaceholder (status 200 con body vacío):
```json
{}
```

En APIs reales, DELETE puede devolver:
- `200 OK` con el recurso eliminado
- `204 No Content` sin body (más común en APIs bien diseñadas)
- `404 Not Found` si el recurso no existía

Verificar el status code:

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
     -X DELETE \
     https://jsonplaceholder.typicode.com/posts/1
```

---

## Flag -X para especificar el método

`-X` (o `--request`) permite especificar cualquier método HTTP:

```bash
curl -X PUT  ...
curl -X PATCH ...
curl -X DELETE ...
curl -X GET ...   # no necesario, es el default
```

Con `-d`, curl asume POST automáticamente. Para los demás verbos hay que ser explícito con `-X`.

---

## Idempotencia: un concepto importante

Un método es idempotente si hacer la misma operación una o N veces produce el mismo resultado en el servidor.

| Método | Idempotente | Por qué |
|--------|-------------|---------|
| GET | Sí | Solo lee, no modifica |
| PUT | Sí | Reemplaza con el mismo valor |
| DELETE | Sí | Borrar algo ya borrado no cambia nada |
| POST | No | Cada llamada puede crear un recurso nuevo |
| PATCH | Depende | Si setea un valor fijo: sí; si incrementa: no |

La idempotencia importa porque permite reintentar requests fallidos sin efectos secundarios no deseados.

---

## Resumen de flags

```bash
# PUT completo
curl -X PUT -H "Content-Type: application/json" -d @recurso.json URL/recurso/1

# PATCH parcial
curl -X PATCH -H "Content-Type: application/json" -d '{"campo": "valor"}' URL/recurso/1

# DELETE
curl -X DELETE URL/recurso/1

# Ver status code en cualquier request
curl -s -o /dev/null -w "%{http_code}" -X DELETE URL/recurso/1
```
