# Rúbrica de Evaluación — Semana 01

> HTTP y curl básico. Se evalúan tres evidencias por separado, y hace falta
> **70% en cada una**: un proyecto brillante no compensa no haber entendido por
> qué curl sale con 0 ante un 500.

---

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | Las 10 preguntas de esta rúbrica, respondidas por escrito |
| 💪 Desempeño | 40% | Las 4 prácticas, con `respuestas.md` y salida real de tu máquina |
| 📦 Producto | 30% | `api-explorer.sh`: 60 pts de autograding + 40 pts de calidad |

**Mínimo 70% en cada evidencia.** No en el promedio.

| Calificación | Rango |
|---|:--:|
| Sobresaliente | 90-100% |
| Notable | 80-89% |
| Aprobado | 70-79% |
| No aprobado | < 70% |

---

## 🧠 Conocimiento (30%)

Diez preguntas, 3 puntos cada una. No se pide recordar flags: se pide explicar
por qué las cosas son como son.

| # | Pregunta |
|:--:|---|
| 1 | ¿Por qué `curl -s https://api/deploy` sale con código 0 aunque el servidor responda 500, y qué dos preguntas distintas contestan el código de salida de curl y el código de estado HTTP? |
| 2 | `--fail` y `--fail-with-body` salen los dos con 22 ante un 4xx. ¿Qué diferencia hay entre ellos, y por qué importa cuando la API explica el error en el cuerpo de la respuesta? |
| 3 | Un 401 y un 403 son los dos "no puedes". ¿Qué los distingue, y por qué ante uno tiene sentido reintentar con otra credencial y ante el otro no? |
| 4 | ¿Qué diferencia hay entre `Protocols:` y `Features:` en la salida de `curl --version`, y qué pregunta contesta cada lista? |
| 5 | `-i`, `-I` y `-D -` enseñan los headers de la respuesta. ¿Cuál de los tres puede darte un 405 en un recurso que funciona perfectamente, y por qué? |
| 6 | ¿Por qué `-s` y `-S` aparecen casi siempre juntos, y qué te pierdes si usas solo `-s` en un script que corre en un cron? |
| 7 | Tienes tres comandos que fallan: uno sale con 6, otro con 7 y otro con 28. ¿Qué pasó en cada caso y en qué punto de la traza `-v` se corta cada uno? |
| 8 | `-H 'Accept: text/html'`, `-H 'Accept:'` y `-H 'Accept;'` hacen tres cosas distintas. ¿Cuáles, y para qué sirve la segunda? |
| 9 | ¿Por qué curl no sigue las redirecciones por defecto, y qué riesgo concreto tiene `-L` cuando la petición lleva una cabecera `Authorization`? |
| 10 | Un script consulta cinco URLs en un bucle con `set -euo pipefail` y curl sin `--max-time`. Describe las dos formas distintas en que ese script puede arruinarte la noche. |

<details>
<summary><strong>Respuestas</strong></summary>

**1.** Porque para curl la transferencia fue un éxito: resolvió el nombre,
conectó, mandó la petición y recibió una respuesta completa. Que esa respuesta
diga 500 es información de la aplicación, no del transporte. El código de salida
de curl contesta *"¿pude hablar con el servidor?"*; el código de estado HTTP
contesta *"¿el servidor hizo lo que le pedí?"*. Un script que solo mira `$?` da
por bueno un despliegue que falló, porque está leyendo la respuesta a una
pregunta que no era la suya.

**2.** Los dos hacen que curl salga con 22 ante un 4xx o un 5xx. La diferencia
es el cuerpo: `--fail` lo descarta y `--fail-with-body` lo conserva. Como las
APIs explican en el cuerpo *qué* campo estaba mal, `--fail` tira justo la
información que necesitas para arreglarlo y te deja con un "22" pelado. La única
razón para preferir `--fail` es tener un curl anterior a 7.76, donde
`--fail-with-body` todavía no existe.

**3.** 401 es "no sé quién eres": falta la credencial, o la que mandaste no vale.
403 es "sé quién eres perfectamente, y no tienes permiso para esto". Por eso ante
un 401 reintentar con otra credencial —o refrescar el token caducado— puede
funcionar, mientras que ante un 403 la credencial es correcta y el problema son
los permisos: reintentar con la misma identidad dará siempre 403. Un 401 además
suele traer `WWW-Authenticate` diciendo cómo autenticarse.

**4.** `Protocols:` son los esquemas de URL que tu binario entiende: `http`,
`https`, `ftp`, `smtp`… Contesta "¿puede curl hablar este protocolo?".
`Features:` son las capacidades que se activaron al compilarlo: `HTTP2`,
`brotli`, `IDN`, `Kerberos`… Contesta "¿se compiló con esto dentro?". Son
independientes: un curl puede hablar `https` y no tener `HTTP2`, porque HTTP/2 es
una feature, no un protocolo de URL.

**5.** `-I`. Los otros dos hacen la petición que tú pediste —normalmente un GET—
y solo cambian qué se imprime. `-I` cambia el **método**: manda un HEAD. Si el
recurso solo acepta GET, el servidor responde 405 Method Not Allowed y tú
concluyes que el endpoint está roto cuando lo que está mal es tu forma de
mirarlo. Para inspeccionar los headers de un GET real: `-s -o /dev/null -D -`.

**6.** `-s` silencia dos cosas a la vez: la barra de progreso, que es ruido, y
los mensajes de error, que no lo son. `-S` devuelve solo los segundos. Con `-s` a
secas en un cron, un "Could not resolve host" no aparece en ningún log: lo único
que queda del fallo es un código de salida que quizá nadie mire. Con `-sS`
tienes salida limpia **y** el diagnóstico cuando hace falta.

**7.** 6 es DNS: el nombre no se resolvió, y la traza se corta antes incluso del
`Trying`, porque no hay a qué IP ir. 7 es conexión: el nombre resolvió pero el
puerto no acepta —firewall, servicio caído—, y la traza enseña `Trying` y nunca
llega a `Connected`. 28 es tiempo agotado: `--max-time` o `--connect-timeout`
cortaron la operación; la traza puede haber llegado hasta donde sea, y el mensaje
dice cuántos milisegundos y cuántos bytes se habían recibido.

**8.** `-H 'Accept: text/html'` manda el header con ese valor, sustituyendo al
que curl pondría por su cuenta. `-H 'Accept:'` —valor vacío, con dos puntos—
**suprime** el header: no viaja. `-H 'Accept;'` —con punto y coma— manda el
header con el valor vacío, que sí viaja. La segunda forma es la única manera de
quitar uno de los tres headers que curl añade solo, cosa que hace falta cuando un
servidor se comporta de forma distinta según reciba o no un `Accept`.

**9.** Porque seguir una redirección es obedecer a ciegas a la otra parte: el
servidor decide a dónde va tu siguiente petición. Con `-L`, si la respuesta
redirige a otro host, curl deja de mandar la cabecera `Authorization`
precisamente para no filtrar la credencial a un tercero. Ese comportamiento se
puede desactivar con `--location-trusted`, y por eso es un flag que hay que
pensarse: convierte cualquier redirección en un canal para llevarse tu token.

**10.** Primera: sin `--max-time`, una URL que acepta la conexión y luego no
contesta deja el script esperando indefinidamente; en un cron eso es un proceso
colgado por cada ejecución, acumulándose. Segunda: con `set -e`, en cuanto una
URL falle —DNS, puerto cerrado— curl saldrá distinto de 0 y el script morirá ahí,
sin comprobar las URLs que quedaban y sin imprimir resumen. Las dos se arreglan a
la vez: `--max-time` en la llamada, y `|| echo "000 0"` para capturar el fallo
sin abortar el bucle.

</details>

---

## 💪 Desempeño (40%)

Diez puntos por práctica. Se evalúa el `respuestas.md`, y tiene que contener la
salida **de tu máquina**: si el `User-Agent` dice `curl/7.81.0` y tu versión es
otra, está copiado.

| Práctica | Criterio | Puntos |
|---|---|:--:|
| [01 — Conocer tu curl](2-practicas/01-conocer-tu-curl.md) | Versión, biblioteca TLS, `Protocols:` y `Features:` documentados; la tabla de las cinco opciones con SI/NO; los tres nombres de opción del paso 6 | 10 |
| [02 — El primer GET](2-practicas/02-el-primer-get.md) | GET con query string; el exit 3 provocado y arreglado con `-G --data-urlencode`; `-o` y `-O` usados; el 404 con exit 0 explicado | 10 |
| [03 — Los flags esenciales](2-practicas/03-los-flags-esenciales.md) | Traza `-v` anotada por fases; diferencia `-i`/`-I`/`-D -` razonada; cadena de tres redirecciones contada; exit 28 provocado | 10 |
| [04 — Provocar y leer códigos](2-practicas/04-provocar-y-leer-status-codes.md) | Las cinco familias provocadas; los cuatro desenlaces (0, 6, 7, 28) en una tabla; `check-urls.sh` ejecutable y saliendo con 1 | 10 |

Dentro de cada práctica: 10 puntos si están todos los pasos con salida y una
observación propia; 8 si están todos con salida; 7 si falta algún paso o alguna
salida; menos de 7 si hay comandos sin ejecutar.

---

## 📦 Producto (30%)

### Verificable por el autograding — 60 puntos

Lo ejecuta `./scripts/verificar-semana.sh 01`. Es binario: pasa o no pasa.

| Comprobación | Puntos |
|---|:--:|
| `explorer-ejecutable` — existe, es ejecutable y arranca con `set -euo pipefail` | 6 |
| `explorer-sin-todos` — no queda ningún marcador `TODO` | 6 |
| `explorer-imprime-status` — imprime el código de estado de cada URL | 8 |
| `explorer-imprime-tiempo` — imprime el tiempo de respuesta en segundos | 8 |
| `explorer-detecta-error-http` — sale distinto de 0 ante un 503 | 10 |
| `explorer-no-se-cuelga` — no se queda colgado con `/delay/10` | 8 |
| `explorer-sin-insecure` — no desactiva la verificación del certificado con `-k` | 6 |
| `explorer-shellcheck` — pasa `shellcheck -S warning` sin avisos | 4 |
| `explorer-resumen` — termina con una línea de resumen con el conteo | 4 |
| **Total** | **60** |

> `laboratorio-arriba` no puntúa: es un prerrequisito, no un entregable.

### Calidad — 40 puntos

Lo que el autograding no puede ver.

| Criterio | Excelente | Suficiente | Puntos |
|---|---|---|:--:|
| **Una sola petición por URL** | Código y tiempo salen de la misma invocación de curl | Dos llamadas, pero documenta que lo sabe | 10 |
| **Los flags con su porqué** | Cada flag lleva un comentario que explica qué problema resuelve | Comentarios genéricos | 8 |
| **Tolerancia a fallos** | Una URL caída no aborta el bucle y cuenta como fallo | Aborta, pero el resto funciona | 8 |
| **Legibilidad** | Funciones con nombre en inglés, constantes arriba, sin repetir literales | Legible pero con valores repetidos | 6 |
| **Adaptación al dominio** | La lista apunta a la API elegida, con una URL del laboratorio de control | Solo laboratorio | 4 |
| **`respuestas.md` del proyecto** | Incluye la salida real y una nota de qué costó más | Solo la salida | 4 |
| **Total** | | | **40** |

### Penalizaciones

| Situación | Deducción |
|---|:--:|
| `-k` o `--insecure` en la entrega | **−30 pts** y no se aprueba el producto. El bootcamp entero existe para no hacer esto |
| Un token, clave o contraseña comiteado, aunque sea de prueba | **−30 pts** y hay que rotarlo. Un secreto en un repositorio es un secreto quemado |
| Un secreto en la línea de comandos de un ejemplo | −15 pts. Queda en `ps`, en el historial y en los logs |
| Salida copiada de este material en vez de la de tu máquina | −15 pts. Se detecta sola: los tiempos y el `User-Agent` no coinciden |
| `curl \| bash` sin advertencia ni alternativa | −10 pts |
| Script sin `set -euo pipefail` | −10 pts |
| Ejemplo de producción sin `--max-time` | −5 pts |
| Entrega sin pasar `shellcheck` | −5 pts |

---

## 📋 Checklist de entrega

- [ ] `2-practicas/respuestas.md` con los pasos de las cuatro prácticas
- [ ] `check-urls.sh` de la práctica 04, ejecutable
- [ ] `api-explorer.sh` sin ningún `TODO`, ejecutable, con `set -euo pipefail`
- [ ] `shellcheck -S warning api-explorer.sh` limpio
- [ ] `./scripts/verificar-semana.sh 01` con las diez comprobaciones en verde
- [ ] Tu dominio anotado en `~/.bc-curl`, con permisos 600, fuera del repositorio
- [ ] Ningún secreto en ningún archivo entregado

---

[← Volver a la Semana 01](README.md)
