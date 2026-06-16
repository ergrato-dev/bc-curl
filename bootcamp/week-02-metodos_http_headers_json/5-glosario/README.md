# Glosario - Semana 2

---

**Accept**
Header HTTP que envía el cliente para indicar qué formatos de respuesta acepta. Ejemplo: `Accept: application/json` le dice al servidor "quiero la respuesta en JSON". Si el servidor soporta varios formatos, elige el que coincida con el Accept.

---

**Body (cuerpo)**
La parte de un request o response que contiene los datos. En HTTP, va después de los headers, separado por una línea en blanco. En requests GET y DELETE no hay body. En POST, PUT y PATCH es donde va el JSON u otro payload.

---

**Content-Type**
Header que indica el formato del body. El emisor lo usa para decirle al receptor cómo interpretar los datos. Ejemplos: `application/json`, `text/html`, `multipart/form-data`. Sin Content-Type, el servidor puede rechazar el request o parsearlo incorrectamente.

---

**CRUD**
Acrónimo de Create, Read, Update, Delete — las cuatro operaciones básicas sobre un recurso. En REST: Create=POST, Read=GET, Update=PUT/PATCH, Delete=DELETE.

---

**DELETE**
Método HTTP para eliminar un recurso. No tiene body. Devuelve 200 (con body) o 204 (sin body) si el recurso fue eliminado, o 404 si no existía. Es idempotente: borrar algo ya borrado no cambia el estado del sistema.

---

**Idempotente**
Un método es idempotente si ejecutarlo múltiples veces produce el mismo resultado que ejecutarlo una sola vez. GET, PUT y DELETE son idempotentes. POST no lo es (cada llamada puede crear un recurso nuevo). PATCH puede o no serlo según la implementación.

---

**PATCH**
Método HTTP para modificar parcialmente un recurso. Solo se envían los campos que cambian; el resto se mantiene. Ejemplo: `PATCH /users/1` con `{"email": "nuevo@email.com"}` solo actualiza el email, sin tocar nombre, teléfono, etc.

---

**Payload**
Sinónimo de body o datos útiles del mensaje. En el contexto de APIs, el payload es el JSON (u otro formato) que enviás en el body de un request.

---

**POST**
Método HTTP para crear un recurso nuevo. Requiere body con los datos del recurso a crear. El servidor devuelve 201 Created con el recurso generado (incluyendo el id asignado). No es idempotente.

---

**PUT**
Método HTTP para reemplazar completamente un recurso. Se envía la representación completa del recurso — si omitís un campo, ese campo queda vacío o desaparece. Es idempotente: hacer el mismo PUT dos veces produce el mismo resultado.

---

**REST**
Representational State Transfer. Estilo arquitectural para APIs web que usa HTTP y sus métodos (GET, POST, PUT, PATCH, DELETE) para operar sobre recursos identificados por URLs. Una API REST trata los recursos como sustantivos y los métodos HTTP como verbos.
