# Rúbrica de Evaluación — Semana 02

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | Las 10 preguntas de abajo, con respuesta argumentada |
| 💪 Desempeño | 40% | Las 4 prácticas, verificadas por `checks.json` |
| 📦 Producto | 30% | `api-toolkit.sh`: 60 pts de autograding + 40 pts de rúbrica manual |

> **Mínimo 70% en cada evidencia**, no en el promedio. Un 100% en el producto no
> compensa un 50% en conocimiento: significa que el script funciona y no sabes
> por qué.

---

## 🧠 Conocimiento (30%)

Diez preguntas. Ninguna pide recordar un flag: todas piden contrastar dos cosas
y explicar el porqué. Respóndelas por escrito antes de mirar las respuestas.

| # | Pregunta |
|:--:|---|
| 1 | `-d` hace tres cosas a la vez. ¿Cuáles son las otras dos, además de poner el cuerpo, y cuál de ellas provoca un 415 si no la corriges? |
| 2 | ¿Por qué `-d @cuerpo.json` puede corromper un archivo y `--data-binary @cuerpo.json` no? Da un tipo de contenido en el que el daño sea visible. |
| 3 | Un valor que viene de fuera empieza por `@` y el archivo con ese nombre no existe. ¿Qué hace curl, con qué código de salida sale, y por qué eso es peor que un error? |
| 4 | Define idempotencia sin usar la frase "no cambia nada". ¿Cuál de los cuatro verbos de escritura no la tiene, y qué consecuencia práctica tiene eso sobre `--retry`? |
| 5 | Mandas `{"tel":"611"}` con PUT y luego con PATCH sobre el mismo recurso. ¿Qué le pasa a los campos que no mandaste en cada caso, y cuál de los dos da error? |
| 6 | `curl -L -X POST -d 'a=1' URL` recibe un 303. ¿Qué método llega al destino, qué habría llegado sin el `-X`, y por qué eso puede crear un recurso dos veces? |
| 7 | ¿Qué diferencia hay entre `-H 'Accept;'` y `-H 'Accept:'`? ¿Y por qué varios `-H 'X-Prueba: ...'` se acumulan pero varios `-H 'User-Agent: ...'` no? |
| 8 | El HEAD de un recurso no trae `Content-Length` y el GET sí. ¿Está mal el servidor? ¿Cómo medirías el tamaño real, y por qué `-I` puede darte un 405 donde el GET da 200? |
| 9 | Una API devuelve 415 y otra 422 ante la misma petición. ¿Dónde mira el servidor en cada caso, cuál de los dos se arregla cambiando un header, y por qué ninguno merece un `--retry`? |
| 10 | Tu script escribe con `curl -s` y sin `--fail`. La API devuelve 422. ¿Con qué código de salida termina curl, qué le pasa al script, y qué diferencia hay entre `--fail` y `--fail-with-body` en ese momento? |

<details>
<summary><strong>Respuestas</strong></summary>

**1.** Además de poner el contenido en el cuerpo, `-d` **cambia el método a
POST** y **añade `Content-Type: application/x-www-form-urlencoded`**. La tercera
es la que muerde: si el cuerpo es JSON, le estás diciendo al servidor que es un
formulario. Muchas APIs responden **415 Unsupported Media Type**; las que no lo
comprueban aceptan la petición y guardan el JSON como si fuera una cadena de
formulario. Se corrige con `-H 'Content-Type: application/json'`, o con `--json`
en curl 7.82+. La segunda cosa —el cambio de método— es la razón por la que
`-X POST` junto a `-d` es redundante.

**2.** `-d` está pensado para datos de formulario, donde los saltos de línea no
significan nada, así que **los elimina** al leer un archivo. `--data-binary`
manda el archivo byte a byte. Con un JSON el daño no se ve, porque JSON ignora
los espacios entre tokens; con una **clave privada PEM**, un **CSV** o cualquier
formato donde el salto de línea sea significativo, el contenido llega roto y el
servidor lo rechaza con un error que no menciona los saltos de línea. La regla
sin excepciones: si el cuerpo sale de un archivo, `--data-binary`.

**3.** curl interpreta la `@` como "abre este archivo", no lo encuentra, **emite
un `Warning:` por stderr, manda un cuerpo vacío y sale con 0**. Es peor que un
error porque nada falla: en un script con `-s` el aviso no se ve, el POST llega
vacío, el servidor puede contestar 200, y el script informa de éxito. Un error
habría parado la ejecución. La defensa es `--data-raw`, que no interpreta la
`@`, y es lo que debe usarse siempre que el contenido venga de fuera.

**4.** Idempotente significa que **ejecutar la petición N veces deja el servidor
en el mismo estado que ejecutarla una vez**. No significa que no cambie nada:
un PUT cambia el recurso, pero el segundo PUT lo deja igual que el primero. El
que no la tiene es **POST**: dos POST a `/usuarios` crean dos usuarios. La
consecuencia sobre `--retry`: ante un timeout no sabes si la petición llegó, así
que reintentar un GET, PUT o DELETE es seguro, y reintentar un POST puede
duplicar el recurso. PATCH depende del parche: `{"tel":"611"}` es idempotente,
`{"op":"incrementar"}` no.

**5.** Con **PUT** la semántica es "el recurso pasa a ser exactamente esto", así
que los campos que no mandaste —nombre, rol, lo que hubiera— **desaparecen**.
Con **PATCH** la semántica es "aplícale este cambio", y esos campos se quedan
como estaban. **Ninguno de los dos da error**: la API hace lo que le pediste, y
ese es el problema. El PUT parcial es la forma más rápida de borrar datos sin
darse cuenta, y solo se detecta releyendo el recurso después.

**6.** Al destino llega un **POST**. Sin `-X`, curl aplicaría la regla del
protocolo para el 303 —*See Other*— y convertiría el método a **GET**, que es el
patrón POST/Redirect/GET: creas el recurso, te mandan a verlo. Con `-X`, curl
obedece la orden explícita y fuerza POST en **todos** los saltos. Contra una API
que crea recursos con POST, el destino recibe una segunda creación que nadie
pidió: el recurso queda duplicado. El fallo no da error, no aparece en ningún
log del cliente y solo se ve contando registros en el servidor.

**7.** `-H 'Accept;'` —punto y coma— manda el header **con valor vacío**: viaja.
`-H 'Accept:'` —dos puntos sin valor— **lo suprime**: no viaja. La diferencia de
acumulación viene de que HTTP permite repetir un header, así que curl manda
todos los `-H` que le des con un nombre nuevo; pero con los tres headers que
**pone curl solo** (`Host`, `User-Agent`, `Accept`), un `-H` con ese nombre se
interpreta como sustitución del valor por defecto, no como una adición. Por eso
dos `X-Prueba` llegan como una lista de dos y dos `User-Agent` no.

**8.** El servidor **no está mal**. El RFC dice que los headers de un HEAD
*deberían* coincidir con los del GET, pero muchos servidores no generan el
cuerpo para un HEAD y por tanto no saben cuánto ocupa, así que omiten
`Content-Length`. Un `Content-Length` ausente no significa recurso vacío. El
tamaño real se mide con un GET a `/dev/null` y `%{size_download}`, o pidiendo un
rango (`-r 0-0`) y leyendo el total en `Content-Range`. Y `-I` puede dar 405
porque **hace un HEAD, que es otro método**: si el endpoint solo acepta POST, el
HEAD no está permitido. Para ver los headers de un GET, `-s -o /dev/null -D -`.

**9.** El **415** mira el header `Content-Type`: le has declarado un formato que
no sabe procesar. El **422** mira el **contenido**: el formato es correcto, el
JSON parsea, pero los datos no pasan la validación de negocio. El que se arregla
cambiando un header es el 415; el 422 exige cambiar los datos. Ninguno merece
`--retry` porque los dos son **4xx**: el problema está en la petición, y repetir
la misma petición da el mismo resultado. Los que sí se reintentan son los 5xx y
el 429.

**10.** curl termina con **0**. Para curl la transferencia fue un éxito: pidió y
le contestaron; el 422 es la respuesta del servidor, no un fallo de curl. El
script, por tanto, da la escritura por buena e informa de que creó el recurso
que no creó. La diferencia entre los dos flags es el cuerpo: los dos salen con
**22**, pero `--fail` descarta la respuesta —ni siquiera crea el archivo de
`-o`— mientras que `--fail-with-body` la conserva. Y en un 422 el cuerpo es
justo donde la API nombra el campo que está mal, así que `--fail` a secas tira
el diagnóstico. `--fail-with-body` es de curl 7.76.

</details>

---

## 💪 Desempeño (40%)

Diez puntos por práctica. Se evalúan sobre `respuestas.md` y los archivos que
deja cada una.

| Práctica | Criterio | Puntos |
|---|---|:--:|
| [01 — Enviar el primer cuerpo](2-practicas/01-enviar-el-primer-cuerpo.md) | Identifica las tres cosas que hace `-d`, provoca el aviso de `@` inexistente y documenta la diferencia entre `-d @` y `--data-binary @` | 10 |
| [02 — El CRUD completo](2-practicas/02-el-crud-completo.md) | Ejecuta los cinco verbos comprobando `%{method}`, saca un `Location` limpio de `\r` y entrega `crud.log` con los cuatro códigos | 10 |
| [03 — Headers a mano](2-practicas/03-headers-a-mano.md) | Distingue añadir, sustituir, vaciar y suprimir; entrega `cabeceras.txt` con permisos 600 y **sin token real dentro** | 10 |
| [04 — JSON que no cabe](2-practicas/04-json-desde-archivo.md) | `construir-cuerpo.sh` funciona, usa `--arg`/`--argjson` correctamente, valida antes de enviar y pasa `shellcheck` | 10 |

---

## 📦 Producto (30%)

### Verificable por el autograding — 60 puntos

Cada comprobación de [`checks.json`](checks.json) que pasa suma. Son catorce; la
primera comprueba el laboratorio y no puntúa.

| Comprobación | Puntos |
|---|:--:|
| `api-toolkit.sh` existe, es ejecutable y arranca con `set -euo pipefail` | 4 |
| No quedan marcadores `TODO` sin resolver | 4 |
| El subcomando `get` imprime el cuerpo de la respuesta | 5 |
| El subcomando `post` envía el cuerpo JSON que se le pasa | 5 |
| El subcomando `post` declara `Content-Type: application/json` | 6 |
| El subcomando `put` usa el método PUT | 5 |
| El subcomando `delete` usa el método DELETE | 5 |
| `--dry-run` imprime el comando curl que se habría ejecutado | 5 |
| `--dry-run` no llega a hacer la petición | 5 |
| El script sale distinto de 0 cuando la API responde 404 | 6 |
| El script no se queda colgado cuando el servidor tarda demasiado | 4 |
| El script no desactiva la verificación del certificado con `-k` | 3 |
| El script pasa `shellcheck` sin avisos | 3 |
| **Total** | **60** |

### Calidad — 40 puntos

Lo que el autograding no ve:

| Criterio | Qué se busca | Puntos |
|---|---|:--:|
| Separación de flujos | Los errores van a `stderr`; el cuerpo, a `stdout`. Un `\| jq` no se traga ningún mensaje de error | 6 |
| El cuerpo del error se conserva | Ante un 4xx el script imprime el cuerpo antes de salir con código distinto de 0 | 6 |
| Una sola petición | Código y cuerpo salen de la misma invocación, con `-w '\n%{http_code}'`, no de dos peticiones | 5 |
| `--data-raw` para el cuerpo que llega por argumento | Y un comentario que explica por qué no `-d` | 5 |
| `--request` en vez de `-X` | En las cuatro construcciones, con la forma larga | 4 |
| Argumentos en un array | `ARGS_CURL=(...)`, no una cadena que se rompe con el primer espacio | 4 |
| `--dry-run` copiable | El comando impreso se puede pegar en la terminal y funciona | 4 |
| Legibilidad | Funciones con una responsabilidad, nombres que se entienden, comentarios que dicen el porqué y no el qué | 6 |
| **Total** | | **40** |

### Penalizaciones

| Situación | Deducción |
|---|---|
| Un `-k` o `--insecure` en cualquier parte de la entrega | **−20** |
| Un token, clave o credencial comiteada, aunque sea de prueba | **−20** |
| Un token en la línea de comandos de un ejemplo de la entrega | −10 |
| El script sale con 0 ante un 4xx o un 5xx | −10 |
| Alguna petición sin `--max-time` | −8 |
| `-d` con un valor que llega por argumento, sin justificarlo | −6 |
| Marcadores `TODO` sin resolver en la entrega | −5 |
| `shellcheck -S warning` con avisos | −5 |
| `--dry-run` que ejecuta la petición | −5 |
| `cabeceras.txt` con permisos distintos de 600 | −3 |

Las dos primeras no son "puntos menos" y ya está: son las dos cosas que este
bootcamp existe para evitar. Un `-k` en una entrega significa que el certificado
dejó de verificarse para que el ejemplo funcionara, y un token comiteado se
queda en el historial de git aunque lo borres en el commit siguiente. Si te pasa
lo segundo, **rota el token** antes de arreglar el commit.

---

[← Volver a la Semana 02](README.md)
