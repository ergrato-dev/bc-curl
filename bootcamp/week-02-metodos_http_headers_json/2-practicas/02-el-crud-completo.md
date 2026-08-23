# Práctica 02 — El CRUD completo

> ⏱️ 50 minutos · Laboratorio local · Entregable: `respuestas.md` y `crud.log`

Crear, leer, reemplazar, modificar y borrar el mismo recurso. El laboratorio no
guarda nada — es un reflector — así que lo que se practica es **mandar la
petición correcta** y **leer bien la respuesta**, que es lo que falla de verdad.

## 🎯 Qué vas a conseguir

- Ejecutar los cinco verbos contra la misma ruta y comprobar cuál salió en cada uno
- Ver la diferencia práctica entre reemplazar con PUT y modificar con PATCH
- Sacar el `Location` de un 201 a una variable de bash, sin el `\r` que estorba
- Comprobar que `-X` con `-L` fuerza el método en una redirección 303
- Distinguir un 409, un 415 y un 422 y decidir cuál merece reintento

## 📋 Antes de empezar

```bash
./scripts/start.sh
curl -sf --max-time 5 -o /dev/null http://localhost:8080/get && echo "laboratorio OK"
cd ~/bc-curl-s02 || { mkdir -p ~/bc-curl-s02 && cd ~/bc-curl-s02; }
```

A partir de aquí, la ruta base de todos los pasos:

```bash
RECURSO='http://localhost:8080/anything/usuarios/42'
```

`/anything` acepta cualquier método y cualquier ruta debajo, así que se puede
simular una API real sin que el servidor rechace el verbo.

---

## Paso 1: Crear con POST y leer el `Location`

**Por qué**: cuando una API crea algo, lo que necesitas para el siguiente paso
no es el cuerpo: es **dónde ha quedado**. Y eso viene en un header, no en el
JSON.

**Comando**:

```bash
curl -sS --fail-with-body --max-time 10 \
  -H 'Content-Type: application/json' \
  -d '{"nombre":"Ada","rol":"admin"}' \
  http://localhost:8080/anything/usuarios | jq -c '{method, json}'
# {"method":"POST","json":{"nombre":"Ada","rol":"admin"}}
```

**Verifica**: ahora el `Location`. El laboratorio no crea recursos, así que se
simula con `/response-headers`, que devuelve los headers que le pidas.

```bash
# -D - manda los headers a stdout; -o /dev/null tira el cuerpo. El tr -d '\r'
# quita el retorno de carro que HTTP pone al final de cada linea: sin el, la
# comparacion en bash falla de forma inexplicable.
UBICACION=$(curl -sS --max-time 10 -o /dev/null -D - \
  'http://localhost:8080/response-headers?Location=%2Fusuarios%2F42' \
  | awk -F': ' 'tolower($1)=="location"{print $2}' | tr -d '\r')
echo "creado en: [$UBICACION]"
# creado en: [/usuarios/42]
```

Quita el `| tr -d '\r'` y repite. Anota en `respuestas.md` qué cambia en la
salida entre corchetes.

---

## Paso 2: Leer con GET

**Por qué**: es el único de los cinco que ya sabías, y sirve de control: si el
GET funciona y el PUT no, el problema es el verbo, no la URL.

**Comando**:

```bash
curl -sS --fail-with-body --max-time 10 "$RECURSO" | jq -c '{method, url}'
# {"method":"GET","url":"http://localhost:8080/anything/usuarios/42"}
```

**Verifica**: sin ningún flag de datos, el método es GET.

```bash
curl -s -o /dev/null -w '%{method}\n' "$RECURSO"   # GET
```

---

## Paso 3: Reemplazar con PUT

**Por qué**: PUT significa "el recurso pasa a ser **exactamente** esto". Los
campos que no mandes desaparecen. Es la diferencia entre actualizar y borrar sin
querer.

**Comando**:

```bash
# --request PUT: ningun flag de datos implica PUT, asi que aqui si hace falta.
# Y el cuerpo lleva TODOS los campos, no solo el que cambia.
curl -sS --fail-with-body --max-time 10 --request PUT \
  -H 'Content-Type: application/json' \
  -d '{"nombre":"Ada","rol":"admin","tel":"600"}' \
  "$RECURSO" | jq -c '{method, json}'
# {"method":"PUT","json":{"nombre":"Ada","rol":"admin","tel":"600"}}
```

**Verifica**: el mismo PUT con un solo campo, que es el error que se quiere
evitar. Contra una API real acaba de dejar al usuario **sin nombre y sin rol**.

```bash
curl -sS --max-time 10 --request PUT \
  -H 'Content-Type: application/json' -d '{"tel":"611"}' \
  "$RECURSO" | jq -c .json
# {"tel":"611"}
```

Anota en `respuestas.md` qué verbo debería haberse usado.

---

## Paso 4: Modificar un campo con PATCH

**Por qué**: PATCH es "aplícale este cambio". Los campos que no mandas se quedan
como están. Es lo que querías en el paso 3.

**Comando**:

```bash
curl -sS --fail-with-body --max-time 10 --request PATCH \
  -H 'Content-Type: application/json' \
  -d '{"tel":"611"}' \
  "$RECURSO" | jq -c '{method, json}'
# {"method":"PATCH","json":{"tel":"611"}}
```

**Verifica**: el cuerpo es idéntico al del PUT del paso 3. Lo único que cambia
es el verbo, y con él lo que la API hace con los campos ausentes.

```bash
curl -s -o /dev/null -w '%{method}\n' --request PATCH -d '{"tel":"611"}' "$RECURSO"
# PATCH   ← mismo cuerpo, semantica opuesta
```

---

## Paso 5: Borrar con DELETE

> [!WARNING]
> Este paso va contra el laboratorio, que no borra nada. **No lo repitas contra
> la API de tu dominio** hasta que el proyecto tenga `--dry-run` funcionando.

**Por qué**: DELETE no lleva cuerpo, y el código de éxito no es 200 sino 204 en
la mayoría de las APIs — es decir, cuerpo vacío.

**Comando**:

```bash
curl -sS --fail-with-body --max-time 10 --request DELETE \
  -o /dev/null -w 'metodo=%{method} codigo=%{http_code}\n' \
  "$RECURSO"
# metodo=DELETE codigo=200
```

**Verifica**: el 204 de una API real, y lo que le pasa a `jq`.

```bash
# El cuerpo mide 0 bytes. No es un error: es lo que significa 204.
curl -s -o /dev/null -w 'codigo=%{http_code} cuerpo=%{size_download}\n' \
  http://localhost:8080/status/204
# codigo=204 cuerpo=0
```

```bash
# Y esto es lo traicionero: jq sobre un cuerpo vacio NO da error. Sale con 0 y
# la variable se queda vacia.
ID=$(curl -s http://localhost:8080/status/204 | jq -r .id)
echo "salida de jq=$? id=[$ID]"
# salida de jq=0 id=[]
```

Anota en `respuestas.md`: ¿en qué línea del script se manifestaría ese fallo?

---

## Paso 6: Idempotencia, comprobada

**Por qué**: si el DELETE es idempotente, un timeout se puede reintentar sin
miedo. Si el POST no lo es, no. De eso depende si `--retry` es seguro.

**Comando**:

```bash
# Dos DELETE seguidos sobre el mismo recurso.
for i in 1 2; do
  curl -s -o /dev/null -w "DELETE intento $i: %{http_code}\n" \
    --request DELETE "$RECURSO"
done
# DELETE intento 1: 200
# DELETE intento 2: 200
```

**Verifica**: contra el reflector los dos dan 200; contra una API real el
segundo daría **404**, y el estado final sigue siendo el correcto. El POST, en
cambio, no es idempotente: dos POST crean **dos** recursos.

```bash
for i in 1 2; do
  curl -s -o /dev/null -w "POST intento $i: %{http_code}\n" \
    -H 'Content-Type: application/json' -d '{"nombre":"Ada"}' \
    http://localhost:8080/anything/usuarios
done
# POST intento 1: 200
# POST intento 2: 200
```

Anota en `respuestas.md`: de los cuatro verbos de escritura, ¿sobre cuál **no**
pondrías `--retry` y por qué.

---

## Paso 7: `-X` y la redirección que duplica

**Por qué**: es el fallo de `-X` que no da error, no aparece en ningún log del
cliente y solo se ve contando registros en la base de datos del servidor.

**Comando**:

```bash
# Sin -X: curl convierte el POST en GET al seguir el 303, que es la regla del
# protocolo. Correcto.
curl -s -L -d 'a=1' \
  'http://localhost:8080/redirect-to?url=%2Fanything%2Fdestino&status_code=303' \
  | jq -c '{method, data}'
# {"method":"GET","data":""}
```

**Verifica**: el mismo comando con `-X POST`. El destino recibe un **segundo
POST** que nadie pidió, y encima sin cuerpo — contra una API que crea recursos
con POST, eso es el recurso creado dos veces.

```bash
curl -s -L -X POST -d 'a=1' \
  'http://localhost:8080/redirect-to?url=%2Fanything%2Fdestino&status_code=303' \
  | jq -c '{method, data}'
# {"method":"POST","data":""}
```

Compáralo con un 307, que **sí** conserva el método por definición:

```bash
curl -s -L -d 'a=1' \
  'http://localhost:8080/redirect-to?url=%2Fanything%2Fdestino&status_code=307' \
  | jq -c '{method, data}'
# {"method":"POST","data":"a=1"}
```

---

## Paso 8: Los códigos de error, uno a uno

**Por qué**: un script que escribe tiene que decidir si reintenta. Reintentar un
409 cuatro veces es tardar cuatro veces más en fallar igual.

**Comando**:

```bash
# /status/NNN devuelve el codigo que le pidas. Es como se prueba el manejo de
# errores sin esperar a que falle de verdad.
for c in 201 204 409 415 422 500; do
  curl -s --fail-with-body -o /dev/null -w "$c: http=%{http_code} " \
    http://localhost:8080/status/$c
  echo "salida=$?"
done
# 201: http=201 salida=0
# 204: http=204 salida=0
# 409: http=409 salida=22
# 415: http=415 salida=22
# 422: http=422 salida=22
# 500: http=500 salida=22
```

**Verifica**: los 2xx salen con 0 y los demás con 22. Pero **no todos los 22 son iguales**:
anota en `respuestas.md` cuáles de esos cuatro reintentarías automáticamente.

---

## Paso 9: El ciclo entero en una invocación

**Por qué**: `--next` encadena peticiones reutilizando la conexión. Sirve para
dejar constancia del ciclo completo en un archivo.

**Comando**:

```bash
curl -sS --max-time 10 -o /dev/null -w 'POST   %{method} %{http_code}\n' \
     -H 'Content-Type: application/json' -d '{"nombre":"Ada"}' \
     http://localhost:8080/anything/usuarios \
  --next -sS -o /dev/null -w 'PUT    %{method} %{http_code}\n' \
     --request PUT -H 'Content-Type: application/json' \
     -d '{"nombre":"Ada","rol":"admin"}' "$RECURSO" \
  --next -sS -o /dev/null -w 'PATCH  %{method} %{http_code}\n' \
     --request PATCH -H 'Content-Type: application/json' -d '{"rol":"lector"}' \
     "$RECURSO" \
  --next -sS -o /dev/null -w 'DELETE %{method} %{http_code}\n' \
     --request DELETE "$RECURSO" | tee crud.log
```

**Verifica**: `cat crud.log` tiene que dar las cuatro líneas.

```
POST   POST 200
PUT    PUT 200
PATCH  PATCH 200
DELETE DELETE 200
```

`crud.log` es el segundo entregable de esta práctica.

---

## ✅ Resultado

- [ ] Sacas un `Location` a una variable y sabes qué hace el `tr -d '\r'`
- [ ] Mandas los cinco verbos y compruebas `%{method}` en cada uno
- [ ] Explicas qué le pasa a los campos ausentes en PUT y en PATCH
- [ ] Compruebas que `jq` sobre un cuerpo vacío sale con 0 y no avisa
- [ ] Reproduces el 303 con y sin `-X` y ves el método distinto en el destino
- [ ] Provocas los seis códigos y anotas cuáles reintentarías
- [ ] Tienes `crud.log` con los cuatro verbos y sus códigos

```bash
./scripts/verificar-semana.sh 02
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `$RECURSO: unbound variable` | La variable se define al principio de la práctica | Vuelve a "Antes de empezar" y ejecútala |
| La comparación con el `Location` falla sin motivo | El header trae un `\r` al final | `\| tr -d '\r'` |
| `--request PUT` y el método sale POST | Hay un `-X` posterior en el comando que lo pisa | Deja un solo flag de método |
| El PUT deja el recurso con un solo campo | Es lo que hace PUT: reemplaza | Usa PATCH para cambios parciales |
| `jq` no imprime nada y no da error | El cuerpo estaba vacío (204) | Comprueba `%{http_code}` antes de parsear |
| El 303 llega al destino como POST | Hay un `-X POST` en el comando | Quítalo: `-d` ya implica POST |
| `--next` no ejecuta la segunda petición | Falta la URL de la primera antes del `--next` | Cada tramo necesita su propia URL |

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [Práctica 01 — Enviar el primer cuerpo](01-enviar-el-primer-cuerpo.md) | **Práctica 02 — El CRUD completo** | [Práctica 03 — Headers a mano](03-headers-a-mano.md) |

[← Volver a la Semana 02](../README.md)
