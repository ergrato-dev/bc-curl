# Práctica 02 — Reintentos sin sorpresas

> **Duración**: 50 min · **Entregables**: `reintentos.md`

Vas a cronometrar `--retry`, ver qué reintenta y qué no, y comprobar con tus
ojos lo que deja en cada salida después de varios intentos: tres cuerpos
pegados en stdout, un cuerpo solo en `-o`, tres bloques en `-D`. Terminas con
una función que lee un header del último bloque. Son los TODOs 1 y 2 del
proyecto, hechos a mano.

**Antes de empezar**, desde la raíz del repositorio:

```bash
./scripts/start.sh
export CA="$PWD/docs/lab-ca.pem"
mkdir -p ~/bc-curl-trabajo/semana-07/p2 && cd ~/bc-curl-trabajo/semana-07/p2
bash    # los pasos estan escritos para bash
```

Algunos pasos esperan varios segundos a propósito: es el backoff de curl.

---

## Paso 1: Cuánto tarda `--retry`

**Por qué**: un `--retry 3` puede añadir siete segundos a una petición. Hay que
saberlo antes de ponerlo en un bucle de cien páginas.

**Comando**:

```bash
time curl -s --retry 1 -o /dev/null http://localhost:8080/status/503
time curl -s --retry 2 -o /dev/null http://localhost:8080/status/503
time curl -s --retry 3 -o /dev/null http://localhost:8080/status/503
echo "salida: $?"
```

**Verifica**:

```bash
# real  0m1,01s
# real  0m3,01s
# real  0m7,01s
# salida: 0
```

1, 1 + 2, 1 + 2 + 4: la espera se dobla. Y tras agotar los reintentos, curl
sale con **0**: el último intento fue un 503 sin `--fail`, y eso es una
transferencia correcta. Apunta los tres tiempos en `reintentos.md`, y repite
el último con `--retry-delay 1`.

---

## Paso 2: Qué reintenta y qué no

**Por qué**: `--retry` solo reintenta errores transitorios, y no mira el método
(teoría 06).

**Comando**:

```bash
intentos() { curl --retry 1 --retry-delay 1 -o /dev/null "$@" 2>&1 | tr '\r' '\n' | grep -c 'Will retry'; }

echo "404:                      $(intentos http://localhost:8080/status/404)"
echo "503:                      $(intentos http://localhost:8080/status/503)"
echo "POST 503:                 $(intentos -X POST -d x http://localhost:8080/status/503)"
echo "conexion rechazada:       $(intentos http://127.0.0.1:9/)"
echo "  con --retry-connrefused: $(intentos --retry-connrefused http://127.0.0.1:9/)"
```

**Verifica**:

```bash
# 404:                      0
# 503:                      1
# POST 503:                 1
# conexion rechazada:       0
#   con --retry-connrefused: 1
```

Sin `-s`, curl avisa de cada reintento en stderr (`Warning: ... Will retry`), y
`grep -c` los cuenta. El `POST` se reintentó igual que un `GET`: si hubiera
creado algo antes de fallar, ahora habría dos. Por eso `construir_red` solo
añade `--retry` a `GET`, `PUT` y `DELETE`.

---

## Paso 3: Los cuerpos se concatenan en stdout

**Por qué**: es el fallo que corrige el TODO 1. Hay que verlo para creérselo.

**Comando**:

```bash
curl -sS --retry 2 --cacert "$CA" https://localhost:8443/limitado; echo
curl -sS --retry 2 --cacert "$CA" -o cuerpo.json https://localhost:8443/limitado
cat cuerpo.json; echo
```

**Verifica**:

```bash
# {"error":"demasiadas peticiones"}{"error":"demasiadas peticiones"}{"error":"demasiadas peticiones"}
# {"error":"demasiadas peticiones"}
```

Tres intentos, tres cuerpos en stdout. curl ya los había escrito y no puede
borrarlos de una tubería o una terminal. Con `-o`, trunca el archivo antes de
cada reintento y solo queda el último. Imagina el primer intento con un 503
y el segundo con un 200: stdout tendría el error **pegado** a los datos.

Apunta las dos salidas en `reintentos.md`.

---

## Paso 4: Cuerpo al archivo, código por stdout

**Por qué**: con el cuerpo en `-o`, stdout queda libre para el `-w`. Es
exactamente lo que hace `peticion` en el proyecto.

**Comando**:

```bash
codigo=$(curl -sS --retry 2 --cacert "$CA" -o cuerpo.json -w '%{http_code}' \
  https://localhost:8443/limitado)
echo "codigo: $codigo"
cat cuerpo.json; echo
```

**Verifica**:

```bash
# codigo: 429
# {"error":"demasiadas peticiones"}
```

El `-w` se escribe **una vez**, al final, con los datos del último intento.
`$(...)` captura solo esa línea; el cuerpo, entero y único, está en el
archivo. En el toolkit, `FORMATO_W` lleva más campos, pero la idea es la
misma: `--output "$CUERPO"` y el `-w` por stdout.

---

## Paso 5: `-D` acumula un bloque por respuesta

**Por qué**: `-D` no se trunca como `-o`. El archivo de headers tiene una
respuesta por intento, y también una por cada redirect.

**Comando**:

```bash
curl -sS --retry 2 --cacert "$CA" -o cuerpo.json -D cab.txt https://localhost:8443/limitado
tr -d '\r' < cab.txt | grep -c '^HTTP'

curl -sS -L --cacert "$CA" -o cuerpo.json -D cab.txt \
  'https://localhost:8443/redirect-to?url=/limitado'
tr -d '\r' < cab.txt | grep -iE '^HTTP|^location|^retry-after'
```

**Verifica**:

```bash
# 3
# HTTP/2 302
# location: /limitado
# HTTP/2 429
# retry-after: 1
```

En el segundo caso, el primer bloque es el del redirect, con su `location` y
sin `retry-after`, y el segundo es el de la respuesta final. Quien lea el
primer `HTTP/` del archivo cree que la respuesta fue un 302.

---

## Paso 6: Leer un header del último bloque

**Por qué**: es el TODO 2. `cabecera retry-after` tiene que devolver el valor
de la **última** respuesta, sin el `\r` y sin distinguir mayúsculas.

**Comando**:

```bash
cabecera() {
  tr -d '\r' < cab.txt | awk -v nombre="$1" '
    /^HTTP\// { valor = "" }
    {
      i = index($0, ":")
      if (i > 0 && tolower(substr($0, 1, i - 1)) == nombre) {
        valor = substr($0, i + 1)
        sub(/^[ \t]+/, "", valor)
      }
    }
    END { print valor }'
}

echo "location:     [$(cabecera location)]"
echo "retry-after:  [$(cabecera retry-after)]"
echo "content-type: [$(cabecera content-type)]"
```

**Verifica**:

```bash
# location:     []
# retry-after:  [1]
# content-type: [application/json]
```

Tres decisiones, una por línea del `awk`:

- **`/^HTTP\// { valor = "" }`**: cada respuesta nueva borra lo anterior. Por
  eso `location`, que solo estaba en el 302, sale vacío.
- **`index` y `substr`**, no `-F': '`: un valor puede llevar `: ` dentro (una
  fecha, una URL), y partir por ahí lo cortaría.
- **`tolower`**: HTTP/2 manda los nombres en minúsculas y HTTP/1.1 no. El
  toolkit convierte también el nombre que recibe con `tr`, para que
  `cabecera Retry-After` funcione igual.

Copia la función a `reintentos.md` y explica con tus palabras la primera
línea del `awk`.

---

## Paso 7: curl respeta `Retry-After`

**Por qué**: con `Retry-After`, la espera la decide el servidor, no el backoff.

**Comando**:

```bash
time curl -s --retry 2 --cacert "$CA" -o cuerpo.json https://localhost:8443/limitado
time curl -s --retry 2 -o cuerpo.json http://localhost:8080/status/503
```

**Verifica**:

```bash
# real  0m2,01s
# real  0m3,01s
```

`/limitado` dice `Retry-After: 1`: curl espera 1 s antes de cada reintento, en
vez de 1 y 2. El 503 de httpbin no trae el header, y curl aplica su backoff.
Es lo que hace que el toolkit no necesite un bucle de backoff propio para los
`GET`.

---

## Paso 8: `-o /dev/null` en 7.81

**Por qué**: el truco de "solo quiero el `-w`" tiene un fallo en 7.81 cuando hay
reintentos.

**Comando**:

```bash
curl -sS --retry 1 --cacert "$CA" -o /dev/null https://localhost:8443/limitado
echo "salida: $?"
curl -sS --retry 1 --cacert "$CA" -o "$(mktemp)" https://localhost:8443/limitado
echo "salida: $?"
```

**Verifica**:

```bash
# curl: (23) Failed to truncate file
# salida: 23
# salida: 0
```

Para reintentar, curl intenta truncar la salida, y `/dev/null` no se deja. Con
un cuerpo vacío (el 503 de httpbin) no hay nada que truncar y no pasa; con
uno de verdad, sí. En curl 8.x está corregido. Si tu curl es 8.x, el primero
sale con 0: apúntalo igual.

---

## ✅ Resultado

- [ ] `reintentos.md` tiene los tiempos de `--retry 1`, `2` y `3` contra un 503
- [ ] He visto qué reintenta curl: 503 y `POST` sí; 404 y conexión rechazada, no
- [ ] He visto tres cuerpos en stdout y uno en `-o`
- [ ] Sé por qué el archivo de `-D` tiene varios bloques
- [ ] Mi función `cabecera` lee el header del último bloque

```bash
./scripts/verificar-semana.sh 07
```

Esta práctica prepara los TODOs 1 y 2: `--output "$CUERPO"`,
`--dump-header "$CABECERAS"` y la función `cabecera`.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| `/limitado` responde 200 con un JSON de httpbin | El Caddyfile del laboratorio es anterior a la Semana 07 | Actualiza el repositorio y `docker compose restart tls` |
| El paso 2 cuenta 0 en todo | Pusiste `-s`, que oculta los avisos | La función no lleva `-s` a propósito |
| `cabecera` devuelve el valor con un espacio delante | Falta el `sub(/^[ \t]+/, "", valor)` | Cópialo de la función |
| `cabecera Retry-After` no encuentra nada | La función de la práctica compara con el nombre tal cual | Pásalo en minúsculas, o conviértelo con `tr` como el toolkit |
| El paso 7 tarda lo mismo en los dos | Tu curl es anterior a 7.66 y no lee `Retry-After` | `curl --version`: con el laboratorio y Ubuntu 22.04 deberías tener 7.81 |
| El paso 8 sale con 0 | Tu curl es 8.x | Es lo esperado; apúntalo |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 01 — Cada fallo, su código](01-cada-fallo-su-codigo.md) | [Práctica 03 — Recorrer un listado paginado](03-recorrer-un-listado-paginado.md) |
