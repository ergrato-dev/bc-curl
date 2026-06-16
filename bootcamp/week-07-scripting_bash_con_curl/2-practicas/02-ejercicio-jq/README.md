# Ejercicio 2: Procesamiento JSON con jq

## Objetivo

Practicar los filtros mas comunes de jq usando la API de jsonplaceholder.
Cada parte introduce nuevos conceptos de forma incremental.

## Setup: guardar datos localmente

Para no hacer demasiados requests durante el ejercicio, guarda los datos de la
API una sola vez:

```bash
curl -s https://jsonplaceholder.typicode.com/users > users.json
curl -s https://jsonplaceholder.typicode.com/posts > posts.json
curl -s "https://jsonplaceholder.typicode.com/comments?postId=1" > comments.json

# Verificar que se guardaron correctamente
jq 'length' users.json posts.json comments.json
```

## Parte 1: filtros basicos

```bash
# Ver el primer usuario formateado
jq '.[0]' users.json

# Ver solo el nombre del primer usuario
jq '.[0].name' users.json

# Con -r para obtener el string sin comillas
jq -r '.[0].name' users.json

# Campo anidado: ciudad del primer usuario
jq -r '.[0].address.city' users.json

# Campo doblemente anidado: latitud geografica
jq -r '.[0].address.geo.lat' users.json
```

Anota los valores que obtienes.

## Parte 2: iterar arrays

```bash
# Nombre de TODOS los usuarios (uno por linea)
jq -r '.[].name' users.json

# Todos los emails
jq -r '.[].email' users.json

# Estructura: id y nombre de cada usuario
jq -r '.[] | "\(.id): \(.name)"' users.json

# Titulos de todos los posts
jq -r '.[].title' posts.json | head -10
```

La interpolacion `"\(.campo)"` dentro de strings de jq permite construir
texto con valores de los campos.

## Parte 3: select y filtros condicionales

```bash
# Todos los posts del usuario 3
jq '.[] | select(.userId == 3)' posts.json

# Solo los titulos de posts del usuario 3
jq -r '.[] | select(.userId == 3) | .title' posts.json

# Usuarios cuyo email termina en .biz
jq -r '.[] | select(.email | endswith(".biz")) | .name + " -> " + .email' users.json

# Usuarios cuya compania tenga "LLC" en el nombre
jq -r '.[] | select(.company.name | contains("LLC")) | .name' users.json
```

## Parte 4: transformaciones y nuevos objetos

```bash
# Array con solo {id, nombre} de cada usuario
jq '[.[] | {id: .id, nombre: .name}]' users.json

# Con map() - equivalente mas conciso
jq 'map({id, nombre: .name})' users.json

# Contar posts por usuario (requires group_by)
jq 'group_by(.userId) | map({userId: .[0].userId, count: length})' posts.json

# Cuantos comentarios tiene el post 1
jq 'length' comments.json

# Emails de quienes comentaron el post 1
jq -r '.[].email' comments.json | sort
```

## Parte 5: crear JSON con jq -n

```bash
# Crear un usuario nuevo (sin enviarlo a la API)
jq -n \
   --arg nombre "Maria Lopez" \
   --arg email "maria@ejemplo.com" \
   --arg ciudad "Buenos Aires" \
   '{
       name: $nombre,
       email: $email,
       address: {
           city: $ciudad
       }
   }'

# Crear desde variables bash
USERNAME="carlos"
USEREMAIL="carlos@test.com"
USERID=42

jq -n \
   --arg name "$USERNAME" \
   --arg email "$USEREMAIL" \
   --argjson id "$USERID" \
   '{id: $id, username: $name, email: $email}'
```

## Parte 6: combinar curl y jq en una linea

Ahora sin usar los archivos guardados:

```bash
# Usuario 5: nombre y empresa
curl -s https://jsonplaceholder.typicode.com/users/5 | \
    jq -r '"\(.name) trabaja en \(.company.name)"'

# Cuantos posts tiene el usuario 7
curl -s "https://jsonplaceholder.typicode.com/posts?userId=7" | jq 'length'

# Titulos de posts del usuario 2, en mayusculas
curl -s "https://jsonplaceholder.typicode.com/posts?userId=2" | \
    jq -r '.[].title | ascii_upcase' | head -5

# Crear JSON de un nuevo post y enviarlo a la API
NUEVO_POST=$(jq -n \
               --arg titulo "Mi post de prueba" \
               --arg cuerpo "Contenido del post" \
               --argjson userId 1 \
               '{title: $titulo, body: $cuerpo, userId: $userId}')

curl -s -X POST \
     -H "Content-Type: application/json" \
     -d "$NUEVO_POST" \
     https://jsonplaceholder.typicode.com/posts | jq '.'
```

## Preguntas (respuestas.md)

1. Que diferencia hay entre `jq '.[].nombre'` y `jq -r '.[].nombre'`?
   Cuando usas cada uno en un script?
2. Que retorna jq cuando accedes a un campo que no existe en el objeto?
3. Como buscar usuarios cuyo nombre contiene la letra "a" (minuscula)?
4. Que hace `jq 'map(select(.userId == 1))'` y como es diferente de
   `jq '.[] | select(.userId == 1)'`?

## Entregables

- `filtros.sh`: todos los comandos de las partes 1-6 en un script anotado
- `output.txt`: output de cada filtro
- `respuestas.md`: respuestas a las preguntas
