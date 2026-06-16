# Proyecto Semana 2: Mini cliente REST

## Descripcion

Vas a crear un script bash `crud.sh` que funciona como un cliente REST para la API de todos de jsonplaceholder. El script acepta argumentos por línea de comandos y ejecuta el curl correspondiente.

---

## API

`https://jsonplaceholder.typicode.com/todos` — API de tareas pendientes (todos).

Cada todo tiene esta estructura:
```json
{
  "userId": 1,
  "id": 1,
  "title": "delectus aut autem",
  "completed": false
}
```

---

## Requerimientos del script

El script `crud.sh` debe aceptar estos subcomandos:

```bash
./crud.sh list          # Lista los primeros 10 todos
./crud.sh get 5         # Obtiene el todo con id 5
./crud.sh create        # Crea un nuevo todo (datos hardcodeados en el script)
./crud.sh update 5      # Actualiza completamente el todo id 5
./crud.sh patch 5       # Modifica solo el campo "completed" del todo id 5
./crud.sh delete 5      # Elimina el todo id 5
./crud.sh help          # Muestra los subcomandos disponibles
```

---

## Estructura sugerida

```bash
#!/bin/bash

BASE_URL="https://jsonplaceholder.typicode.com/todos"

case "$1" in
  list)
    # GET todos con limit
    ;;
  get)
    # GET todo por id: $2
    ;;
  create)
    # POST nuevo todo
    ;;
  update)
    # PUT todo id $2
    ;;
  patch)
    # PATCH todo id $2 — solo cambiar completed a true
    ;;
  delete)
    # DELETE todo id $2
    ;;
  help|*)
    # Mostrar ayuda
    ;;
esac
```

---

## Criterios de evaluacion

### Lo mínimo (aprobado)

- [ ] El script existe y es ejecutable (`chmod +x crud.sh`)
- [ ] `list` devuelve una lista de todos
- [ ] `get ID` devuelve el todo correcto
- [ ] `create` hace POST y muestra el recurso creado
- [ ] `delete ID` hace DELETE y muestra el status code

### Completo (notable)

- [ ] Todos los subcomandos implementados
- [ ] Cada subcomando muestra el status HTTP además del body
- [ ] `help` sin argumentos imprime uso
- [ ] La respuesta JSON está formateada (python3 -m json.tool)

### Destacado (sobresaliente)

- [ ] Manejo de error: si falta el ID en `get`, `update`, `patch`, `delete`, muestra un mensaje útil
- [ ] `list` acepta un parámetro opcional de cantidad: `./crud.sh list 5`
- [ ] `create` acepta argumentos: `./crud.sh create "titulo del todo" 1` (title y userId)

---

## Pistas

**Para mostrar status code y body juntos:**

```bash
# Guardar status code en variable
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
BODY=$(curl -s "$URL")
echo "Status: $STATUS"
echo "$BODY" | python3 -m json.tool
```

**Para limitar resultados en list:**

```bash
curl -s "${BASE_URL}?_limit=10"
```

**Para verificar que se pasó un ID:**

```bash
if [ -z "$2" ]; then
  echo "Error: se requiere un ID. Uso: $0 get ID"
  exit 1
fi
```

---

## Entrega

En la carpeta `starter/` (o donde indique el instructor):

- `crud.sh` — el script completo
- `respuestas.md` — capturas del output de cada subcomando

El archivo `respuestas.md` debe mostrar:
1. `./crud.sh list`
2. `./crud.sh get 3`
3. `./crud.sh create`
4. `./crud.sh update 3`
5. `./crud.sh patch 3`
6. `./crud.sh delete 3`
