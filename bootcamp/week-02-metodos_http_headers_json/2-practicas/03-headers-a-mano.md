# Práctica 03 — Headers a mano

> ⏱️ 50 minutos · Laboratorio local · Entregable: `respuestas.md` y `cabeceras.txt`

Cuatro cosas se pueden hacer con `-H`, y tres de ellas casi nadie las conoce.
Al final de la práctica el token deja de estar en la línea de comandos.

## 🎯 Qué vas a conseguir

- Distinguir en la práctica añadir, sustituir, vaciar y suprimir un header
- Ver qué headers pone curl solo y comprobar cuáles puedes cambiar
- Mandar dos veces el mismo header y ver que **no** se pisan
- Leer los headers de respuesta sin cambiar el método
- Sacar una credencial de `ps` con `-H @archivo`

## 📋 Antes de empezar

```bash
./scripts/start.sh
curl -sf --max-time 5 -o /dev/null http://localhost:8080/get && echo "laboratorio OK"
cd ~/bc-curl-s02 || { mkdir -p ~/bc-curl-s02 && cd ~/bc-curl-s02; }
```

El endpoint de esta práctica es `/headers`, que devuelve exactamente los headers
que le llegaron. Es la única fuente de verdad: lo que **creías** mandar no
cuenta.

---

## Paso 1: Lo que curl pone sin pedírselo

**Por qué**: antes de añadir nada, hay que saber qué hay. Son tres, y los tres
se pueden cambiar.

**Comando**:

```bash
curl -s http://localhost:8080/headers | jq -c '.headers | keys'
# ["Accept","Host","User-Agent"]
```

**Verifica**: los valores.

```bash
curl -s http://localhost:8080/headers | jq -c .headers
# {"Accept":["*/*"],"Host":["localhost:8080"],"User-Agent":["curl/7.81.0"]}
```

> [!NOTE]
> Los valores son **listas**, no cadenas. En HTTP un header puede repetirse, y
> `go-httpbin` lo refleja. Por eso en `jq` hace falta el índice:
> `.headers["User-Agent"][0]`.

Anota en `respuestas.md` qué versión de curl delata tu `User-Agent`.

---

## Paso 2: Añadir un header nuevo

**Por qué**: es el caso del 90%. Una versión de API, un identificador de
petición para correlacionar logs, un `X-` cualquiera.

**Comando**:

```bash
curl -s http://localhost:8080/headers \
  -H 'X-Api-Version: 2' \
  -H 'X-Peticion-Id: abc-123' | jq -c '.headers | keys'
# ["Accept","Host","User-Agent","X-Api-Version","X-Peticion-Id"]
```

**Verifica**: en la traza, que son los bytes que salieron de verdad.

```bash
curl -sv http://localhost:8080/get -H 'X-Api-Version: 2' 2>&1 | grep '^> '
# > GET /get HTTP/1.1
# > Host: localhost:8080
# > User-Agent: curl/7.81.0
# > Accept: */*
# > X-Api-Version: 2
```

---

## Paso 3: Sustituir uno de los que pone curl

**Por qué**: hay APIs (la de GitHub, sin ir más lejos) y WAF que rechazan el
`User-Agent` de curl. Y poner el nombre de tu herramienta es buena educación: el
operador del servidor sabe a quién escribir si algo va mal.

**Comando**:

```bash
curl -s http://localhost:8080/headers -H 'User-Agent: api-toolkit/0.2' \
  | jq -c '.headers["User-Agent"]'
# ["api-toolkit/0.2"]
```

**Verifica**: el de curl ya no aparece. Con los headers que pone curl, `-H`
**sustituye**; no se acumulan.

```bash
curl -s http://localhost:8080/headers -H 'User-Agent: api-toolkit/0.2' \
  | jq -c '.headers["User-Agent"] | length'
# 1
```

---

## Paso 4: Los tuyos sí se acumulan

**Por qué**: es la causa de un fallo intermitente clásico. Añades un
`Content-Type` sin darte cuenta de que ya había otro, se mandan los dos, y el
servidor coge el primero, o el último, o devuelve 400.

**Comando**:

```bash
curl -s http://localhost:8080/headers \
  -H 'X-Prueba: uno' -H 'X-Prueba: dos' | jq -c '.headers["X-Prueba"]'
# ["uno","dos"]
```

**Verifica**: con `Content-Type`, que es donde duele.

```bash
curl -s http://localhost:8080/post \
  -H 'Content-Type: application/json' \
  -H 'Content-Type: text/plain' \
  -d '{"a":1}' | jq -c '.headers["Content-Type"]'
# ["application/json","text/plain"]
```

Anota en `respuestas.md`: si una API te devuelve un 415 intermitente, ¿qué
comprobarías primero?

---

## Paso 5: Vaciar frente a suprimir

**Por qué**: dos puntos y punto y coma parecen intercambiables y hacen cosas
opuestas. Es el truco de `-H` que no viene en ningún tutorial.

**Comando**:

```bash
# Punto y coma: el header VIAJA, con valor vacio.
curl -s http://localhost:8080/headers -H 'Accept;' | jq -c '.headers.Accept'
# [""]
```

```bash
# Dos puntos sin valor: el header NO viaja. Fijate en que Accept ya no esta.
curl -s http://localhost:8080/headers -H 'Accept:' | jq -c '.headers | keys'
# ["Host","User-Agent"]
```

**Verifica**: los tres casos juntos.

```bash
for h in 'Accept: application/json' 'Accept;' 'Accept:'; do
  printf '%-28s -> ' "$h"
  curl -s http://localhost:8080/headers -H "$h" | jq -c '.headers.Accept'
done
# Accept: application/json     -> ["application/json"]
# Accept;                      -> [""]
# Accept:                      -> null
```

`null` significa que el header no llegó. Anota en `respuestas.md` para qué
serviría suprimir `Accept` en una depuración.

---

## Paso 6: Leer los headers de la respuesta

**Por qué**: `-H` es solo para los que envías. Para los que llegan hay cuatro
flags, y tres de ellos tienen un efecto secundario.

**Comando**:

```bash
# -D - manda los headers a stdout y -o separa el cuerpo. Hace el GET de verdad,
# sin cambiar el metodo.
curl -sS --max-time 10 -o cuerpo.json -D - http://localhost:8080/json | head -4
# HTTP/1.1 200 OK
# Access-Control-Allow-Credentials: true
# Access-Control-Allow-Origin: *
# Content-Type: application/json; charset=utf-8
```

**Verifica**: la trampa de `-I`, que hace un HEAD y por tanto **otro método**.

```bash
# /post solo acepta POST. El -I manda un HEAD y se lleva un 405 que no dice
# nada del GET.
curl -sI -o /dev/null -w 'con -I:   %{http_code}\n' http://localhost:8080/post
curl -s  -o /dev/null -D /dev/null -w 'con -D -: %{http_code}\n' \
  -d '' http://localhost:8080/post
# con -I:   405
# con -D -: 200
```

---

## Paso 7: Provocar los headers que quieras

**Por qué**: para probar cómo reacciona tu script a un `X-RateLimit` o a un
`Location` no hace falta montar un servidor: el laboratorio los devuelve a la
carta.

**Comando**:

```bash
curl -s -o /dev/null -D - \
  'http://localhost:8080/response-headers?X-Limite=100&X-Restante=99' \
  | grep -i '^x-'
# X-Limite: 100
# X-Restante: 99
```

**Verifica**: sacarlo a una variable de bash, que es para lo que sirve.

```bash
# tolower() en awk para no depender de las mayusculas del servidor, y tr -d '\r'
# para quitar el retorno de carro con el que HTTP termina cada linea.
RESTANTE=$(curl -s -o /dev/null -D - \
  'http://localhost:8080/response-headers?X-Restante=99' \
  | awk -F': ' 'tolower($1)=="x-restante"{print $2}' | tr -d '\r')
echo "quedan [$RESTANTE] peticiones"
# quedan [99] peticiones
```

---

## Paso 8: Sacar el token de la línea de comandos

> [!WARNING]
> Un token en la línea de comandos es visible con `ps aux` para **cualquier
> usuario de la máquina**, queda en `~/.bash_history` y aparece en los logs de
> CI, que se guardan años. No es un detalle de estilo.

**Por qué**: la Semana 03 va entera de autenticación. Esta es la costumbre que
hay que tener adquirida antes de llegar.

**Comando**:

```bash
# umask 077 hace que el archivo nazca con permisos 600: solo tu lo lees.
umask 077
cat > cabeceras.txt <<'EOF'
Authorization: Bearer <TOKEN>
Accept: application/json
X-Api-Version: 2
EOF

ls -l cabeceras.txt
# -rw------- 1 ... cabeceras.txt
```

**Verifica**: `-H @archivo` (curl 7.55+) lee un header por línea.

```bash
curl -s http://localhost:8080/headers -H @cabeceras.txt | jq -c '.headers | keys'
# ["Accept","Authorization","Host","User-Agent","X-Api-Version"]
```

Compara las dos formas de escribir lo mismo:

```bash
# ❌ El token aparece en `ps aux` mientras dure la peticion.
# curl -H "Authorization: Bearer <TOKEN>" URL

# ✅ El token esta en un archivo con permisos 600. En `ps` solo se ve la ruta.
curl -s -H @cabeceras.txt http://localhost:8080/headers \
  | jq -c '.headers.Authorization | length'
# 1
```

`cabeceras.txt` es el entregable de esta práctica. **No lo comitees.** El
`.gitignore` de este repositorio ya lo ignora, pero tu copia de trabajo vive
fuera: comprueba que el `.gitignore` de tu repo lo cubre **antes** de crear el
archivo, no después. Un token comiteado se queda en el historial de git aunque
lo borres en el commit siguiente, y entonces lo único que sirve es rotarlo.

---

## Paso 9: Todo junto

**Por qué**: así es como queda un comando de escritura completo, con los headers
fuera de la línea y los tres flags de producción.

**Comando**:

```bash
curl -sS --fail-with-body --max-time 10 \
  -H @cabeceras.txt \
  -H 'Content-Type: application/json' \
  -d '{"nombre":"Ada"}' \
  http://localhost:8080/post | jq -c '.headers | keys'
```

**Verifica**:

```bash
curl -sS --fail-with-body --max-time 10 -H @cabeceras.txt \
  -H 'Content-Type: application/json' -d '{"nombre":"Ada"}' \
  http://localhost:8080/post | jq -c '.headers | keys'
# ["Accept","Authorization","Content-Length","Content-Type","Host","User-Agent","X-Api-Version"]
```

Siete headers, y solo dos están escritos en la línea de comandos.

---

## ✅ Resultado

- [ ] Nombras los tres headers que pone curl solo y sabes leer su valor con `jq`
- [ ] Añades dos headers custom y los ves en la traza `-v`
- [ ] Sustituyes el `User-Agent` y compruebas que el de curl desapareció
- [ ] Mandas dos veces `X-Prueba` y ves los dos valores en la respuesta
- [ ] Distingues `-H 'Accept;'` de `-H 'Accept:'` ejecutando los dos
- [ ] Explicas por qué `-I` sobre `/post` da 405 y `-D -` da 200
- [ ] Sacas un header de respuesta a una variable de bash, sin el `\r`
- [ ] Tienes `cabeceras.txt` con permisos 600 y lo usas con `-H @`

```bash
./scripts/verificar-semana.sh 02
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `.headers.Accept` da error en `jq` | El valor es una lista | Añade el índice: `.headers.Accept[0]` |
| El header custom no aparece en `/headers` | Falta el espacio tras los dos puntos, o sobran comillas | `-H 'X-Cosa: valor'`, con comillas simples |
| Querías mandar `Accept` vacío y desapareció | `-H 'Accept: '` (con espacio) también suprime. El que lo manda vacío es el punto y coma | `-H 'Accept;'` |
| Se mandan dos `Content-Type` | Un `-H` tuyo más otro de un `.curlrc` o un alias | `curl -v` y cuenta cuántos salen |
| `-I` devuelve 405 y con el navegador funciona | `-I` manda HEAD, y ese recurso solo acepta GET o POST | `-s -o /dev/null -D -` |
| La comparación del header en bash nunca coincide | El valor acaba en `\r` | `\| tr -d '\r'` |
| `-H @cabeceras.txt: option unknown` | curl anterior a 7.55 | Variable de entorno, y actualiza curl cuando puedas |
| `cabeceras.txt` tiene permisos 644 | El `umask 077` se ejecutó después de crear el archivo | `chmod 600 cabeceras.txt` |

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [Práctica 02 — El CRUD completo](02-el-crud-completo.md) | **Práctica 03 — Headers a mano** | [Práctica 04 — JSON que no cabe en la línea](04-json-desde-archivo.md) |

[← Volver a la Semana 02](../README.md)
