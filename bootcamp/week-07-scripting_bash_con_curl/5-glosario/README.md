# Glosario - Semana 7

## $?

Variable especial de bash que contiene el exit code del ultimo comando ejecutado.
Debe leerse inmediatamente despues del comando de interes, antes de ejecutar
cualquier otra instruccion (que lo sobreescribiria con su propio exit code).

```bash
curl -sf https://httpbin.org/status/404
echo $?   # 22 — exit code de curl con -f ante un 404
```

---

## backoff

Estrategia para reintentar operaciones fallidas esperando un tiempo entre intentos.
En el backoff exponencial, el tiempo de espera se duplica en cada reintento (1s,
2s, 4s, 8s, ...). Esto evita sobrecargar un servidor que ya esta bajo presion.
Se usa tipicamente al recibir errores 429 (Too Many Requests) o 503 (Service
Unavailable).

---

## declare -a

Sintaxis bash para declarar un array indexado. Permite acumular valores en un
array durante un loop y acceder a ellos por indice o iterar sobre todos.

```bash
declare -a resultados
resultados+=("primer elemento")
resultados+=("segundo elemento")
printf '%s\n' "${resultados[@]}"
```

---

## exit code

Numero entero (0-255) que un proceso retorna al sistema operativo al terminar. Por convencion,
0 indica exito y cualquier valor distinto de 0 indica algun tipo de fallo. En bash,
`$?` contiene el exit code del ultimo comando ejecutado. curl retorna 0 si la
transferencia completo sin errores de curl, independientemente del codigo HTTP.

---

## --fail / -f

Flag de curl que hace que retorne exit code 22 cuando la respuesta HTTP tiene
codigo 4xx o 5xx. Sin este flag, curl retorna 0 aunque el servidor responda con
un error. En scripts que verifican el exito de un request, siempre usar `-f` o
revisar el HTTP status code manualmente.

---

## --fail-with-body

Variante de `-f` disponible desde curl 7.76.0. Retorna exit code 22 en errores
HTTP 4xx/5xx igual que `-f`, pero ademas muestra el body de la respuesta en
stdout. Util para depuracion cuando necesitas leer el mensaje de error del
servidor al mismo tiempo que detectas el fallo.

---

## idempotente

Una operacion es idempotente si ejecutarla multiples veces produce el mismo
resultado que ejecutarla una sola vez. En el contexto de scripts de sincronizacion
de APIs, un script idempotente verifica si el recurso ya existe antes de crearlo,
evitando duplicados. Es una propiedad fundamental para scripts que pueden
ejecutarse varias veces por automatizacion o por error.

---

## IFS

"Internal Field Separator" — variable de bash que define los caracteres usados
para separar palabras en la expansion de variables y en la lectura con `read`.
El valor por defecto es espacio, tabulacion y salto de linea. Se cambia
temporalmente para parsear formatos de texto con otro separador, como CSV:

```bash
while IFS=, read -r id nombre email; do
    echo "$id | $nombre | $email"
done < usuarios.csv
```

---

## jq

Procesador JSON de linea de comandos. Lee JSON de stdin o un archivo, aplica un
filtro (expresion jq) y escribe el resultado en stdout. Es la herramienta estandar
para trabajar con respuestas JSON en scripts bash. Permite acceder a campos,
filtrar arrays, transformar estructuras y crear nuevo JSON desde variables bash.

---

## paginacion

Mecanismo por el que las APIs dividen colecciones grandes en "paginas" de N
elementos. El cliente hace requests sucesivos para obtener cada pagina. Los
patrones comunes son: paginacion por offset (`?page=2&limit=20`), por cursor
(`?after=ID_del_ultimo_elemento`) o por URL en campo `next` de la respuesta.
El loop termina cuando la respuesta indica que no hay mas paginas (campo `next`
es null o la pagina retornada esta vacia).

---

## pipeline (bash)

En Unix/bash, una cadena de procesos donde la salida (stdout) de cada proceso se
conecta a la entrada (stdin) del siguiente mediante el operador `|`. Ejemplo:
`curl -s URL | jq '.campo' | grep "valor"`. Con `set -o pipefail`, el pipeline
falla si cualquier proceso en la cadena retorna un exit code distinto de cero.

---

## rate limit

Limite impuesto por una API en el numero de requests que se pueden hacer en un
periodo de tiempo. Ejemplo: 100 requests por minuto. Cuando se supera el limite,
la API retorna HTTP 429 (Too Many Requests), a menudo con un header `Retry-After`
que indica cuantos segundos esperar. Los scripts deben respetar estos limites
con delays (`sleep`) entre requests y backoff al recibir 429.

---

## readonly

Palabra clave bash que marca una variable como inmutable. Cualquier intento de
reasignarla produce un error de ejecucion. Se usa para variables de configuracion
que no deben cambiar durante la ejecucion del script.

```bash
readonly BASE_URL="${BASE_URL:-https://api.ejemplo.com}"
readonly TIMEOUT=30
```

---

## set -e

Opcion de bash (`set -e` o `set -o errexit`) que hace que el script termine
inmediatamente si cualquier comando retorna un exit code distinto de cero.
Util como red de seguridad en scripts simples, pero puede interferir con scripts
que manejan errores de forma granular con estructuras `if` y `||`. Se puede
desactivar temporalmente con `set +e`.

---

## set -o pipefail

Opcion de bash que hace que el exit code de un pipeline sea el del primer
comando que falle, en lugar del exit code del ultimo comando. Sin esta opcion,
`curl_fallido | jq '.'` retorna 0 (el exit code de jq, aunque curl haya fallado
con exit code 6).

---

## set -u

Opcion de bash (`set -u` o `set -o nounset`) que hace que el script termine con
un error si se intenta usar una variable no definida. Previene bugs silenciosos
por typos en nombres de variables. Para dar un valor por defecto a una variable
que puede no estar definida, usar `${VAR:-default}`.

---

## shebang

La primera linea de un script, con formato `#!/ruta/al/interprete`. Le indica
al sistema operativo que programa usar para ejecutar el archivo. Para scripts
bash, la forma mas portable es `#!/usr/bin/env bash`, que encuentra bash en el
PATH. Sin shebang, el sistema ejecuta el script con sh, que puede tener
diferencias de comportamiento con bash.

---

## sleep

Comando que pausa la ejecucion del script por un numero de segundos (acepta
valores decimales). Indispensable en loops que hacen requests a APIs externas
para respetar los rate limits y evitar ser bloqueado por la API.

```bash
sleep 1      # 1 segundo completo
sleep 0.5    # medio segundo (500 ms)
sleep 0.2    # 200 milisegundos
```

---

## stderr

"Standard Error" — canal de salida de error de un proceso (file descriptor 2).
Por convencion, los mensajes de error, advertencias y logs van a stderr, y la
data util va a stdout. Esta separacion permite redirigir o filtrar la salida de
un script en pipelines sin que los mensajes de log interfieran con los datos.

```bash
echo "Error: fallo la conexion" >&2   # mensaje a stderr
```

---

## stdout

"Standard Output" — canal de salida principal de un proceso (file descriptor 1).
La data util que un script produce va a stdout. En bash, es el destino por
defecto de `echo` y `printf`. Redirigir stdout a un archivo: `comando > archivo.txt`.


