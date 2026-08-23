# Práctica 01 — Enviar el primer cuerpo

> ⏱️ 50 minutos · Laboratorio local · Entregable: `respuestas.md`

Toda la práctica va contra el reflector del laboratorio, que devuelve en JSON
exactamente lo que recibió. No hay que adivinar qué mandó curl: se lee.

## 🎯 Qué vas a conseguir

- Mandar un cuerpo con `-d` y ver los tres headers que curl añadió sin pedírselo
- Comprobar que `-d` cambia el método a POST sin escribir `POST` en ningún sitio
- Provocar el fallo silencioso de `-d @archivo-que-no-existe`
- Distinguir en la práctica `-d`, `--data-raw`, `--data-binary` y `--data-urlencode`
- Sacar el cuerpo de una tubería con `-d @-`

## 📋 Antes de empezar

```bash
./scripts/start.sh
curl -sf --max-time 5 -o /dev/null http://localhost:8080/get && echo "laboratorio OK"
jq --version
# jq-1.6
```

Trabaja en un directorio aparte, fuera del repositorio:

```bash
mkdir -p ~/bc-curl-s02 && cd ~/bc-curl-s02
```

---

## Paso 1: El primer cuerpo, y lo que curl pone solo

**Por qué**: `-d` parece que solo añade datos. Hace tres cosas, y las otras dos
son las que explican la mitad de los errores de esta semana.

**Comando**:

```bash
# -d pone el cuerpo, cambia el metodo a POST y anade un Content-Type.
# Ninguna de las tres se la has pedido.
curl -s http://localhost:8080/post -d 'nombre=Ada&rol=admin' | jq
```

**Verifica**: busca las tres cosas en la respuesta.

```bash
curl -s http://localhost:8080/post -d 'nombre=Ada&rol=admin' | jq -c '{metodo: .method, tipo: .headers["Content-Type"][0], longitud: .headers["Content-Length"][0], data}'
# {"metodo":"POST","tipo":"application/x-www-form-urlencoded","longitud":"20","data":"nombre=Ada&rol=admin"}
```

Anota en `respuestas.md`: **no escribiste `POST` en ningún sitio.** ¿Quién lo
puso? ¿Y de dónde salió el `20`?

---

## Paso 2: La petición en crudo

**Por qué**: la respuesta del reflector es cómoda, pero es una interpretación.
La traza `-v` son los bytes que salieron de tu máquina.

**Comando**:

```bash
# La traza va por stderr: sin 2>&1 el pipe no ve nada. Las lineas '>' son lo
# que sale; las '<', lo que entra.
curl -sv http://localhost:8080/post -d 'nombre=Ada' 2>&1 | grep '^>'
# > POST /post HTTP/1.1
# > Host: localhost:8080
# > User-Agent: curl/7.81.0
# > Accept: */*
# > Content-Length: 10
# > Content-Type: application/x-www-form-urlencoded
# >
```

**Verifica**: la última línea `>` sola es la **línea en blanco** que separa los headers del
cuerpo. Todo lo que va después es cuerpo, y el servidor sabe cuánto leer por el
`Content-Length`.

---

## Paso 3: El mismo JSON, con y sin `Content-Type`

**Por qué**: es el error más común de la semana, y no da un mensaje claro. La
API contesta 415, o peor: acepta la petición y guarda basura.

**Comando**:

```bash
# ❌ El cuerpo es JSON, la etiqueta dice formulario.
curl -s http://localhost:8080/post -d '{"nombre":"Ada"}' \
  | jq -c '{tipo: .headers["Content-Type"][0], json}'
# {"tipo":"application/x-www-form-urlencoded","json":null}
```

```bash
# ✅ Se declara el formato real.
curl -s http://localhost:8080/post -H 'Content-Type: application/json' \
  -d '{"nombre":"Ada"}' | jq -c '{tipo: .headers["Content-Type"][0], json}'
# {"tipo":"application/json","json":{"nombre":"Ada"}}
```

**Verifica**: el campo `json` es lo que importa, no solo el `tipo`. En el primer
caso vale `null` porque el servidor **ni lo intentó**: le dijiste que era un
formulario.

Anota en `respuestas.md`: el cuerpo era **idéntico** en las dos peticiones. Lo
único que cambió fue un header.

---

## Paso 4: `-X POST` no envía nada

**Por qué**: `-X POST` es lo primero que sale en cualquier tutorial. Sin `-d` no
manda datos, y el error que devuelve la API habla del cuerpo, así que se busca
en el sitio equivocado.

**Comando**:

```bash
# Un POST sin cuerpo: ni Content-Length, ni Content-Type, ni datos.
curl -s -X POST http://localhost:8080/post \
  | jq -c '{method, data, longitud: .headers["Content-Length"]}'
# {"method":"POST","data":"","longitud":null}
```

**Verifica**: el equivalente correcto cuando el cuerpo va vacío a propósito.

```bash
curl -s http://localhost:8080/post -d '' | jq -c '{method, longitud: .headers["Content-Length"][0]}'
# {"method":"POST","longitud":"0"}
```

La diferencia: el primero **no tiene** `Content-Length`; el segundo lo tiene y
vale `0`. Para un servidor estricto, eso es un 411 frente a un 200.

---

## Paso 5: El fallo silencioso de la `@`

> [!WARNING]
> Este paso enseña un fallo que **no da error**. Léelo entero antes de dar por
> bueno cualquier script que use `-d` con una variable.

**Por qué**: en `-d`, una `@` al principio del valor significa "abre este
archivo". Si el archivo no existe, curl **no falla**: manda un cuerpo vacío y
sale con 0.

**Comando**:

```bash
# Sin -s, para ver el aviso. El archivo no existe.
curl http://localhost:8080/post -d '@no-existe.json' -o /dev/null
```

**Verifica**:

```bash
curl http://localhost:8080/post -d '@no-existe.json' -o /dev/null
# Warning: Couldn't read data from file "no-existe.json", this makes an empty
# Warning: POST.
echo "codigo de salida: $?"
# codigo de salida: 0
```

Ahora el mismo comando como aparecería en un script, con `-s`:

```bash
# Con -s el aviso desaparece. El cuerpo llega vacio y nadie se entera.
curl -s http://localhost:8080/post -d '@no-existe.json' | jq -c '{data, method}'
# {"data":"","method":"POST"}
```

Y el caso real, con una variable que empieza por `@`:

```bash
CUERPO='@urgente: revisar esto'

# ❌ curl busca un archivo llamado "urgente: revisar esto".
curl -s http://localhost:8080/post -d "$CUERPO" | jq -c .data
# ""

# ✅ --data-raw no interpreta la @: el contenido va literal.
curl -s http://localhost:8080/post --data-raw "$CUERPO" | jq -c .data
# "@urgente: revisar esto"
```

Anota en `respuestas.md`: en un script que recibe datos de fuera, ¿cuál de los
dos usarías por defecto y por qué?

---

## Paso 6: `-d @archivo` frente a `--data-binary @archivo`

**Por qué**: `-d` quita los saltos de línea del archivo. Con un JSON cuela —
JSON ignora los espacios — pero el mismo comportamiento sobre una clave PEM o un
CSV rompe el contenido sin decir nada.

**Comando**:

```bash
printf '{\n  "nombre": "Ada",\n  "rol": "admin"\n}\n' > usuario.json
cat usuario.json
```

**Verifica**: los dos mandan el mismo archivo. Compara el resultado.

```bash
curl -s http://localhost:8080/post --data @usuario.json | jq -c .data
# "{  \"nombre\": \"Ada\",  \"rol\": \"admin\"}"
#   ^^ los \n han desaparecido

curl -s http://localhost:8080/post --data-binary @usuario.json | jq -c .data
# "{\n  \"nombre\": \"Ada\",\n  \"rol\": \"admin\"\n}\n"
#   ^^^ intactos
```

**Este resultado es el entregable 1 de la semana.** Cópialo a `respuestas.md`
con una frase que explique cuál usarías para subir un JSON de disco.

---

## Paso 7: El cuerpo desde una tubería

**Por qué**: en un script, el cuerpo casi nunca es una cadena literal: lo genera
otro comando. `@-` evita tener que escribir un archivo temporal y borrarlo
después.

**Comando**:

```bash
# @- significa "el cuerpo lo lees de stdin".
echo '{"nombre":"Ada"}' | curl -s http://localhost:8080/post \
  -H 'Content-Type: application/json' -d @- | jq -c .json
```

**Verifica**: ahora con `jq` construyendo el cuerpo, que es como se hace de
verdad.

```bash
# jq -n construye el objeto desde cero; --arg mete el valor ya escapado.
NOMBRE='Ada "la primera"'
jq -n --arg n "$NOMBRE" --arg r admin '{nombre: $n, rol: $r}' \
  | curl -sS --max-time 10 -H 'Content-Type: application/json' -d @- \
    http://localhost:8080/post | jq -c .json
# {"nombre":"Ada \"la primera\"","rol":"admin"}
```

Las comillas dentro del nombre llegaron intactas. Prueba a construir ese mismo
JSON a mano con `-d "{\"nombre\":\"$NOMBRE\"}"` y anota qué pasa.

---

## Paso 8: `--data-urlencode` y el query string

**Por qué**: un valor con un espacio o un `&` dentro parte el parámetro en dos
si lo escribes a mano. Y los acentos no los escapa bien nadie a la primera.

**Comando**:

```bash
# -G mueve el contenido del cuerpo a la query, y el metodo se queda en GET.
curl -s -G http://localhost:8080/get --data-urlencode 'q=hola mundo&x' \
  | jq -c '{args, url}'
```

**Verifica**:

```bash
curl -s -G http://localhost:8080/get --data-urlencode 'q=hola mundo&x' \
  | jq -c '{args, url}'
# {"args":{"q":["hola mundo&x"]},"url":"http://localhost:8080/get?q=hola+mundo%26x"}
```

El espacio se convirtió en `+` y el `&` en `%26`, así que llegó **un** parámetro
`q` cuyo valor contiene un `&`. Compáralo con la versión ingenua:

```bash
# ❌ Sin codificar: el & parte la query y aparece un parametro "x" de la nada.
curl -s 'http://localhost:8080/get?q=hola&x' | jq -c .args
# {"q":["hola"],"x":[""]}
```

Y con el espacio dentro, curl ni siquiera lo intenta:

```bash
curl -sS 'http://localhost:8080/get?q=hola mundo&x' -o /dev/null
# curl: (3) URL using bad/illegal format or missing URL
echo "salida=$?"
# salida=3
```

Con acentos:

```bash
TERMINO='café & té'
curl -sS --max-time 10 -G http://localhost:8080/get \
  --data-urlencode "q=${TERMINO}" --data-urlencode 'limite=10' | jq -c .args
# {"limite":["10"],"q":["café & té"]}
```

---

## Paso 9: Cerrar el círculo

**Por qué**: junta todo lo anterior en el comando que vas a repetir el resto del
bootcamp, con los tres flags de producción.

**Comando**:

```bash
# --fail-with-body  sale con 22 ante 4xx/5xx y conserva el cuerpo del error (7.76+)
# --max-time        sin el, un servidor colgado cuelga el script
# -sS               sin barra de progreso, pero sin tragarse los errores de red
curl -sS --fail-with-body --max-time 10 \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  --data-binary @usuario.json \
  http://localhost:8080/post | jq -c '{method, json}'
```

**Verifica**:

```bash
curl -sS --fail-with-body --max-time 10 \
  -H 'Content-Type: application/json' -H 'Accept: application/json' \
  --data-binary @usuario.json http://localhost:8080/post | jq -c '{method, json}'
# {"method":"POST","json":{"nombre":"Ada","rol":"admin"}}

# Y que falla cuando debe fallar. El -S es el que deja pasar el mensaje.
curl -sS --fail-with-body --max-time 10 -d 'a=1' \
  http://localhost:8080/status/422 -o /dev/null
echo "salida=$?"
# curl: (22) The requested URL returned error: 422
# salida=22
```

---

## ✅ Resultado

- [ ] Nombras las tres cosas que hace `-d`, y compruebas las tres en `/post`
- [ ] Identificas en la traza `-v` la línea en blanco que separa headers de cuerpo
- [ ] Demuestras que el mismo cuerpo con y sin `Content-Type` da `.json` distinto
- [ ] Distingues `-X POST` (sin `Content-Length`) de `-d ''` (con `Content-Length: 0`)
- [ ] Provocas el aviso de `-d @archivo-inexistente` y compruebas que el exit es 0
- [ ] Tienes en `respuestas.md` la comparación de `-d @` frente a `--data-binary @`
- [ ] Construyes un cuerpo con `jq -n --arg` y lo mandas con `-d @-`
- [ ] Codificas un query string con `-G --data-urlencode` y ves el `%26`

```bash
./scripts/verificar-semana.sh 02
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `jq: command not found` | `jq` no está instalado | `sudo apt install jq`. Esta semana no es opcional |
| `.json` sale `null` y el cuerpo era JSON | Falta el `Content-Type` | `-H 'Content-Type: application/json'` |
| `.headers["Content-Type"]` da error en `jq` | Es una lista, no una cadena | Añade el índice: `.headers["Content-Type"][0]` |
| El `grep '^>'` no encuentra nada | La traza de `-v` va por stderr | `curl -v ... 2>&1 \| grep '^>'` |
| El cuerpo llega vacío y curl sale con 0 | El valor empezaba por `@` y el archivo no existe | `--data-raw`, o comprueba la ruta |
| `Warning: Couldn't read data from file` | El mismo caso, con el aviso visible | Es el comportamiento correcto de curl: avisa y no falla |
| El JSON del archivo llega en una línea | Usaste `-d @archivo` | `--data-binary @archivo` |
| El query string se parte en dos parámetros | El `&` no estaba codificado | `-G --data-urlencode 'k=v'` |
| `--fail-with-body: option unknown` | curl anterior a 7.76 | Usa `-w '%{http_code}'` y compara en bash. Teoría 08, sección 2.5 |

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| — | **Práctica 01 — Enviar el primer cuerpo** | [Práctica 02 — El CRUD completo](02-el-crud-completo.md) |

[← Volver a la Semana 02](../README.md)
