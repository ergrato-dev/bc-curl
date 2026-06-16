# Ejercicio 02: CRUD completo

## Objetivo

Ejecutar el ciclo completo de operaciones sobre un recurso: leer, crear, reemplazar, modificar parcialmente y eliminar. Verificar el status code de cada operación.

## API de práctica

`https://jsonplaceholder.typicode.com/posts` — soporta GET, POST, PUT, PATCH y DELETE. Los cambios no persisten realmente, pero los status codes y respuestas son fieles al comportamiento real.

---

## Tareas

### 1. READ — Leer un recurso existente (GET)

```bash
curl -s https://jsonplaceholder.typicode.com/posts/1 | python3 -m json.tool
```

Anotar los campos del recurso: `id`, `userId`, `title`, `body`. Los vas a necesitar en los pasos siguientes.

Verificar status:
```bash
curl -s -o /dev/null -w "%{http_code}" https://jsonplaceholder.typicode.com/posts/1
```

### 2. CREATE — Crear un recurso nuevo (POST)

```bash
curl -s -i \
     -X POST \
     -H "Content-Type: application/json" \
     -d '{
       "title": "Recurso creado en el ejercicio CRUD",
       "body": "Este es el body del recurso",
       "userId": 1
     }' \
     https://jsonplaceholder.typicode.com/posts
```

Verificar que el status es 201. Anotar el `id` devuelto (será 101).

### 3. UPDATE COMPLETO — Reemplazar el recurso (PUT)

PUT reemplaza el recurso completo. Hay que enviar TODOS los campos:

```bash
curl -s \
     -X PUT \
     -H "Content-Type: application/json" \
     -d '{
       "id": 1,
       "title": "Titulo completamente reemplazado",
       "body": "Body completamente reemplazado",
       "userId": 1
     }' \
     https://jsonplaceholder.typicode.com/posts/1 | python3 -m json.tool
```

Observar que el status es 200 y que el recurso tiene exactamente los campos que enviaste.

Ahora probar PUT sin enviar el campo `body`:

```bash
curl -s \
     -X PUT \
     -H "Content-Type: application/json" \
     -d '{"id": 1, "title": "Solo titulo", "userId": 1}' \
     https://jsonplaceholder.typicode.com/posts/1 | python3 -m json.tool
```

Observar que `body` desaparece o queda vacío. Esto ilustra por qué PUT es "reemplazo total".

### 4. UPDATE PARCIAL — Modificar solo el título (PATCH)

```bash
curl -s \
     -X PATCH \
     -H "Content-Type: application/json" \
     -d '{"title": "Solo cambio el titulo con PATCH"}' \
     https://jsonplaceholder.typicode.com/posts/1 | python3 -m json.tool
```

Observar que el campo `body` original se mantiene. Solo cambió `title`. Esto es la diferencia clave entre PUT y PATCH.

### 5. DELETE — Eliminar el recurso

```bash
curl -s -i -X DELETE https://jsonplaceholder.typicode.com/posts/1
```

El status debe ser 200 (jsonplaceholder) o 204 (APIs más estrictas). El body suele ser `{}` o estar vacío.

Verificar:
```bash
curl -s -o /dev/null -w "%{http_code}" -X DELETE https://jsonplaceholder.typicode.com/posts/1
```

### 6. Verificar que ya no existe (GET post-DELETE)

```bash
curl -s -o /dev/null -w "%{http_code}" https://jsonplaceholder.typicode.com/posts/1
```

En una API real devolvería 404. jsonplaceholder sigue devolviendo el recurso porque no persiste los deletes, pero el comportamiento esperado en producción es 404.

---

## Tabla de status codes esperados

| Operación | Método | Status esperado |
|-----------|--------|-----------------|
| Leer recurso existente | GET | 200 |
| Leer recurso inexistente | GET | 404 |
| Crear recurso | POST | 201 |
| Reemplazar recurso | PUT | 200 |
| Modificar parcialmente | PATCH | 200 |
| Eliminar | DELETE | 200 o 204 |

---

## Entrega

Archivo `respuestas.md` con:
1. Comando y output de cada uno de los 6 pasos
2. El status code de cada request
3. Explicación de la diferencia entre PUT y PATCH en tus propias palabras
4. ¿Por qué PUT requiere enviar todos los campos y PATCH no?
