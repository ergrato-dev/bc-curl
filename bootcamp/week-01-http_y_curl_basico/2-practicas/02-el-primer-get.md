# Práctica 02 — El primer GET

> ⏱️ 50 minutos · Laboratorio local + una API pública · Entregable: `respuestas.md`

Un GET es la petición más simple que existe y aun así hay cinco cosas que curl
hace por su cuenta y que conviene ver antes de dar nada por sentado. Aquí las
ves todas, contra un servidor que te devuelve exactamente lo que le llegó.

## 🎯 Qué vas a conseguir

- Hacer un GET y saber qué mandó curl, no lo que tú creías que mandaba
- Poner parámetros en la query string sin romperlos con un espacio
- Guardar la respuesta en un archivo con `-o` y con `-O`, y saber cuándo usar cada uno
- Hablar con una API pública real y leer sus headers de rate limit
- Distinguir "el servidor no contestó" de "el servidor contestó que no"

## 📋 Antes de empezar

```bash
./scripts/start.sh
curl -sf --max-time 5 -o /dev/null http://localhost:8080/get && echo "laboratorio OK"
# laboratorio OK
```

---

## Paso 1: El GET más simple que existe

**Por qué**: es la línea base. Todo lo demás de esta semana es este comando con
algo añadido, y hasta que no sabes qué imprime **por defecto** no puedes saber
qué cambia cada flag.

**Comando**:

```bash
# /get del laboratorio devuelve un JSON con lo que le llego: parametros,
# headers, metodo y URL. Es un espejo.
curl http://localhost:8080/get
```

**Verifica**: la respuesta contiene cuatro claves de primer nivel.

```bash
curl -s http://localhost:8080/get
# {
#   "args": {},
#   "headers": {
#     "Accept": [ "*/*" ],
#     "Host": [ "localhost:8080" ],
#     "User-Agent": [ "curl/7.81.0" ]
#   },
#   "method": "GET",
#   "origin": "172.25.0.1",
#   "url": "http://localhost:8080/get"
# }
```

Tres observaciones que hay que anotar:

1. `"method": "GET"` — curl usa GET sin que se lo pidas
2. `"headers"` trae tres que tú no escribiste (teoría 07)
3. **No se ven los headers de la respuesta**: curl imprime solo el cuerpo

---

## Paso 2: Parámetros en la query string

**Por qué**: es como se filtra, se pagina y se busca en cualquier API REST. Y
es donde aparece el primer problema de comillas de tu vida con curl.

**Comando**:

```bash
# Las comillas NO son opcionales: sin ellas, el shell interpreta el & como
# "ejecuta esto en segundo plano" y el segundo parametro se pierde.
curl -s "http://localhost:8080/get?semana=1&tema=http"
```

**Verifica**: los parámetros aparecen en `args`, ya separados.

```bash
curl -s "http://localhost:8080/get?semana=1&tema=http" | head -10
# {
#   "args": {
#     "semana": [
#       "1"
#     ],
#     "tema": [
#       "http"
#     ]
#   },
```

Prueba ahora **sin** comillas y compara. Anota qué pasó.

---

## Paso 3: Cuando el valor lleva espacios o acentos

**Por qué**: una URL no admite espacios. Si metes uno, curl no lo arregla: falla
con código 3 antes de mandar nada. Es un fallo que aparece en cuanto un
parámetro viene de una variable con contenido real.

**Comando**:

```bash
# Mal: hay un espacio dentro de la URL.
curl -s -o /dev/null "http://localhost:8080/get?q=curl y http"
echo "codigo de salida: $?"
# codigo de salida: 3      ← URL malformed. No llego a salir de tu maquina
```

```bash
# Bien: -G convierte los --data-urlencode en query string, codificandolos.
curl -s -G \
  --data-urlencode 'q=curl y http' \
  --data-urlencode 'page=2' \
  http://localhost:8080/get
```

**Verifica**: el espacio llega intacto al otro lado.

```bash
curl -s -G --data-urlencode 'q=curl y http' http://localhost:8080/get | head -6
# {
#   "args": {
#     "q": [
#       "curl y http"
#     ]
#   },
```

> [!NOTE]
> `-G` (`--get`) dice: "lo que te pase con `--data-*` no lo mandes en el cuerpo,
> ponlo en la query string". Sin `-G`, esos mismos `--data-urlencode` harían un
> POST. Eso es la Semana 02.

---

## Paso 4: Guardar la respuesta en un archivo

**Por qué**: en cuanto la respuesta no es texto —un PNG, un ZIP— imprimirla en
la terminal la llena de basura y a veces deja el terminal inservible. Y en un
script casi nunca quieres el cuerpo por pantalla.

**Comando**:

```bash
# -o: TU eliges el nombre del archivo.
curl -s -o respuesta.json http://localhost:8080/json

# -O: curl usa el ultimo segmento de la URL como nombre. Aqui saldria "json".
curl -sO http://localhost:8080/json
```

**Verifica**:

```bash
ls -l respuesta.json json
# -rw-r--r-- 1 usuario usuario 421 ... json
# -rw-r--r-- 1 usuario usuario 421 ... respuesta.json

head -4 respuesta.json
# {
#   "slideshow": {
#     "author": "Yours Truly",
#     "date": "date of publication",
```

> [!WARNING]
> `-O` toma el nombre **de la URL**, que la controla el servidor, no tú. Una URL
> acabada en `/../../.bashrc` es exactamente el problema que parece. En un
> script, `-o` con un nombre que elijas tú; `-O` solo a mano y con URLs que
> conoces.

Limpia antes de seguir:

```bash
rm -f respuesta.json json
```

---

## Paso 5: Una API pública de verdad

**Por qué**: el laboratorio te devuelve lo que le mandas; una API real te
devuelve datos que no controlas, con headers que no esperabas. Es la primera vez
que lees una respuesta ajena.

> Este paso necesita internet. Si no lo tienes, sáltalo y anótalo: el resto de
> la práctica va contra el laboratorio.

**Comando**:

```bash
curl -s https://api.github.com/users/octocat | head -6
# {
#   "login": "octocat",
#   "id": 583231,
#   "node_id": "MDQ6VXNlcjU4MzIzMQ==",
#   "avatar_url": "https://avatars.githubusercontent.com/u/583231?v=4",
#   "gravatar_id": "",
```

**Verifica**: mira los headers, que es donde está lo interesante.

```bash
curl -s -o /dev/null -D - https://api.github.com/users/octocat \
  | grep -iE '^(HTTP|content-type|x-ratelimit)'
# HTTP/2 200
# content-type: application/json; charset=utf-8
# x-ratelimit-limit: 60
# x-ratelimit-remaining: 58
```

Tres cosas que anotar:

1. `HTTP/2`, no `HTTP/1.1`: GitHub lo habla y tu curl también (paso 3 de la
   práctica 01)
2. `x-ratelimit-limit: 60` — sesenta peticiones por hora **sin autenticar**. Con
   credencial son 5.000: es la Semana 03
3. Los nombres de header van en minúscula, porque en HTTP/2 siempre lo van

---

## Paso 6: Qué pasa cuando la URL no existe

**Por qué**: es la trampa central de la semana. curl **no** se queja de un 404.
Sale con código 0, porque desde su punto de vista la transferencia fue
impecable: pidió y le contestaron.

**Comando**:

```bash
curl -s -o /dev/null http://localhost:8080/no-existe
echo "codigo de salida: $?"
# codigo de salida: 0      ← y sin embargo fue un 404
```

**Verifica**: pregunta por el código HTTP, que es otra cosa.

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/no-existe
# 404
```

Compara con un fallo de verdad, donde no hubo respuesta ninguna:

```bash
curl -s -o /dev/null http://localhost:9/ ; echo "sin servidor: $?"
# sin servidor: 7

curl -s -o /dev/null http://no-existe.invalido/ ; echo "sin DNS: $?"
# sin DNS: 6
```

Tres situaciones, tres desenlaces: **404 → exit 0**, puerto cerrado → exit 7,
nombre que no resuelve → exit 6. La práctica 04 vive de esta distinción.

---

## Paso 7: Ver lo que curl no enseña

**Por qué**: hasta ahora solo has visto el cuerpo. La mitad de la información de
una respuesta HTTP está en los headers, y por defecto curl se los calla.

**Comando**:

```bash
# -i mezcla los headers de respuesta con el cuerpo.
curl -s -i http://localhost:8080/get | head -8
# HTTP/1.1 200 OK
# Access-Control-Allow-Credentials: true
# Access-Control-Allow-Origin: *
# Content-Type: application/json; charset=utf-8
# Date: Sun, 23 Aug 2026 09:46:44 GMT
# Content-Length: 245
#
# {
```

**Verifica**: la línea vacía separa headers de cuerpo. Cuéntalos:

```bash
curl -s -o /dev/null -w '%{num_headers}\n' http://localhost:8080/get
# 5
```

---

## Paso 8: Dejarlo por escrito

**Por qué**: `respuestas.md` es el entregable evaluable de esta práctica, y
además es tu propia referencia dentro de tres semanas.

**Comando**:

```bash
# Un ejemplo de como capturar salida real en el archivo, sin copiar a mano.
{
  echo '## Paso 1 — GET simple'
  echo '```json'
  curl -s http://localhost:8080/get
  echo '```'
} >> respuestas.md
```

**Verifica**:

```bash
grep -c '^## Paso' respuestas.md
# 1     ← ira creciendo segun anotes los demas pasos
```

---

## ✅ Resultado

- [ ] Sabes qué imprime `curl URL` sin ningún flag, y qué se calla
- [ ] Has mandado dos parámetros de query y los has visto en `args`
- [ ] Has provocado un exit 3 con un espacio y lo has arreglado con `-G --data-urlencode`
- [ ] Has guardado la respuesta con `-o` y con `-O`, y sabes por qué `-O` es arriesgado
- [ ] Has leído los headers de rate limit de una API real (o lo has anotado como pendiente)
- [ ] Puedes explicar por qué un 404 sale con código 0 y un puerto cerrado con 7
- [ ] `respuestas.md` tiene la salida real de tu máquina, no la de este archivo

```bash
./scripts/verificar-semana.sh 01
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| Solo llega el primer parámetro de la query | El `&` sin comillas manda el comando a segundo plano | Comillas dobles alrededor de toda la URL |
| `curl: (3) URL using bad/illegal format or missing URL` | Hay un espacio en la URL | `-G --data-urlencode 'clave=valor con espacios'` |
| La terminal se llena de símbolos raros | Descargaste algo binario sin `-o` | `reset` para recuperar la terminal; y usa `-o archivo` |
| `curl: (6) Could not resolve host` con la API de GitHub | Sin DNS o sin internet | Sáltate el paso 5, anótalo, y sigue con el laboratorio |
| `x-ratelimit-remaining: 0` | Agotaste las 60 peticiones/hora sin autenticar | Espera a la hora siguiente, o usa el laboratorio |
| `-O` no crea ningún archivo | La URL termina en `/` y no hay nombre que extraer | Usa `-o nombre.json` |
| El 404 no te da error en el script | Es el comportamiento correcto de curl | Teoría 06, sección 5. Se resuelve en la práctica 04 |

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [Práctica 01 — Conocer tu curl](01-conocer-tu-curl.md) | **Práctica 02 — El primer GET** | [Práctica 03 — Los flags esenciales](03-los-flags-esenciales.md) |
