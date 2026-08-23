# Práctica 04 — JSON que no cabe en la línea

> ⏱️ 50 minutos · Laboratorio local · Entregable: `respuestas.md`, `pedido.json` y `construir-cuerpo.sh`

Un cuerpo de tres campos cabe entre comillas. Uno de treinta, con objetos
anidados y un texto que lleva comillas dentro, no. Esta práctica es sobre las
tres formas de que el cuerpo salga del archivo intacto.

## 🎯 Qué vas a conseguir

- Mandar un JSON de disco sin que curl le quite los saltos de línea
- Construir el cuerpo con `jq` y comprobar que escapa lo que tú no escaparías
- Validar el JSON **antes** de gastar una petición
- Encadenar `jq | curl | jq` sin archivos temporales
- Dejar un script que genera el cuerpo a partir de variables

## 📋 Antes de empezar

```bash
./scripts/start.sh
curl -sf --max-time 5 -o /dev/null http://localhost:8080/get && echo "laboratorio OK"
jq --version
cd ~/bc-curl-s02 || { mkdir -p ~/bc-curl-s02 && cd ~/bc-curl-s02; }
```

---

## Paso 1: El JSON que no cabe

**Por qué**: en cuanto el cuerpo pasa de tres campos, escribirlo en la línea de
comandos deja de ser viable. Y un archivo trae saltos de línea, que es justo
donde `-d` mete la pata.

**Comando**:

```bash
cat > pedido.json <<'JSON'
{
  "cliente": {
    "nombre": "Ada Lovelace",
    "email": "ada@ejemplo.com"
  },
  "lineas": [
    { "sku": "AB-100", "cantidad": 2, "precio": 19.99 },
    { "sku": "CD-200", "cantidad": 1, "precio": 149.00 }
  ],
  "nota": "Entregar en portería. Preguntar por \"el de los paquetes\"."
}
JSON

jq . pedido.json | head -5
# {
#   "cliente": {
#     "nombre": "Ada Lovelace",
#     "email": "ada@ejemplo.com"
#   },
```

**Verifica**: que es JSON válido antes de mandarlo a ningún sitio.

```bash
# `jq empty` parsea y no imprime nada: sale con 0 si es valido. Sin -e: con -e
# el codigo se refiere al ultimo valor producido, y `empty` no produce ninguno.
jq empty pedido.json && echo "JSON valido"
# JSON valido
```

---

## Paso 2: El bug de `-d @archivo`

**Por qué**: es el fallo silencioso de la semana. Con este JSON cuela — JSON
ignora los espacios — pero el mismo comportamiento sobre una clave PEM rompe el
contenido sin decir nada.

**Comando**:

```bash
# -d quita los saltos de linea del archivo.
curl -s http://localhost:8080/post \
  -H 'Content-Type: application/json' -d @pedido.json \
  | jq -r '.data' | head -3
```

**Verifica**: comparado con `--data-binary`.

```bash
# Cuenta las lineas del cuerpo que llego al servidor.
echo -n "con -d:            "
curl -s http://localhost:8080/post -d @pedido.json | jq -r '.data' | wc -l
echo -n "con --data-binary: "
curl -s http://localhost:8080/post --data-binary @pedido.json | jq -r '.data' | wc -l
# con -d:            1
# con --data-binary: 12
```

Doce líneas frente a una. Anota en `respuestas.md` qué tipo de contenido se
rompería de verdad con esto.

---

## Paso 3: El envío correcto

**Por qué**: junta `--data-binary`, el `Content-Type` y los tres flags de
producción. Es el comando que va al proyecto.

**Comando**:

```bash
curl -sS --fail-with-body --max-time 10 \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  --data-binary @pedido.json \
  http://localhost:8080/post | jq -c '.json.cliente'
# {"email":"ada@ejemplo.com","nombre":"Ada Lovelace"}
#  ^ el reflector devuelve las claves en orden alfabetico
```

**Verifica**: que el servidor lo parseó de verdad, incluidas las comillas de
dentro de la nota.

```bash
curl -sS --fail-with-body --max-time 10 \
  -H 'Content-Type: application/json' --data-binary @pedido.json \
  http://localhost:8080/post | jq -r '.json.nota'
# Entregar en portería. Preguntar por "el de los paquetes".
```

Quita el `-H 'Content-Type: application/json'` y repite. Anota qué le pasa a
`.json`.

---

## Paso 4: El cuerpo desde una tubería

**Por qué**: en un script el cuerpo casi nunca es un archivo estático: lo genera
otro comando. `@-` evita el archivo temporal y el `rm` de después, que es el que
siempre se olvida.

**Comando**:

```bash
# @- significa "el cuerpo lo lees de stdin".
jq '.lineas[0]' pedido.json | curl -sS --max-time 10 \
  -H 'Content-Type: application/json' -d @- \
  http://localhost:8080/post | jq -c .json
# {"cantidad":2,"precio":19.99,"sku":"AB-100"}
```

**Verifica**: `jq | curl | jq`, los tres encadenados.

```bash
# Recorta el pedido, lo manda, y de la respuesta saca solo lo que interesa.
jq '{cliente: .cliente.nombre, total: ([.lineas[] | .cantidad * .precio] | add)}' \
  pedido.json \
  | curl -sS --max-time 10 -H 'Content-Type: application/json' -d @- \
    http://localhost:8080/post \
  | jq -c .json
# {"cliente":"Ada Lovelace","total":188.98}
```

---

## Paso 5: Construir el cuerpo con `jq`

**Por qué**: interpolar variables dentro de un JSON a mano funciona hasta que un
valor lleva una comilla, un salto de línea o un acento. Y eso pasa con los datos
raros, no con los de prueba.

**Comando**:

```bash
# ❌ Dentro de comillas simples el shell no interpola: llega el texto literal.
NOMBRE='Ada'
curl -s http://localhost:8080/post -d '{"nombre":"$NOMBRE"}' | jq -c .data
# "{\"nombre\":\"$NOMBRE\"}"
```

```bash
# ❌ Con comillas dobles interpola, pero un valor con comillas dentro rompe el
# JSON y el servidor lo rechaza.
NOMBRE='Ada "la primera"'
curl -s http://localhost:8080/post -H 'Content-Type: application/json' \
  -d "{\"nombre\":\"$NOMBRE\"}" | jq -c .json
# null    ← el JSON llego roto
```

**Verifica**: con `jq -n --arg`, que escapa por ti.

```bash
NOMBRE='Ada "la primera"'
jq -n --arg n "$NOMBRE" --arg r admin '{nombre: $n, rol: $r}' \
  | curl -sS --max-time 10 -H 'Content-Type: application/json' -d @- \
    http://localhost:8080/post | jq -c .json
# {"nombre":"Ada \"la primera\"","rol":"admin"}
```

Las comillas de dentro llegaron intactas.

---

## Paso 6: `--arg` frente a `--argjson`

**Por qué**: `--arg` mete **siempre** una cadena. Un número o un booleano
metidos con `--arg` llegan entrecomillados, y la API los rechaza con un 422 que
cuesta interpretar.

**Comando**:

```bash
# ❌ --arg convierte todo en cadena.
jq -n --arg edad 36 --arg activo true '{edad: $edad, activo: $activo}'
# {
#   "edad": "36",
#   "activo": "true"
# }
```

```bash
# ✅ --argjson lo mete como el tipo que es.
jq -n --argjson edad 36 --argjson activo true '{edad: $edad, activo: $activo}'
# {
#   "edad": 36,
#   "activo": true
# }
```

**Verifica**: comprueba los tipos que llegaron al servidor.

```bash
jq -n --arg n Ada --argjson edad 36 --argjson activo true \
  '{nombre: $n, edad: $edad, activo: $activo}' \
  | curl -sS --max-time 10 -H 'Content-Type: application/json' -d @- \
    http://localhost:8080/post | jq -c '.json | map_values(type)'
# {"activo":"boolean","edad":"number","nombre":"string"}
```

---

## Paso 7: Validar antes de enviar

**Por qué**: un JSON roto se detecta en local, sin gastar una petición ni
ensuciar los logs de la API. En un script, esta comprobación va **antes** del
`curl`, no después.

**Comando**:

```bash
printf '{"nombre":"Ada"' > roto.json

jq empty roto.json && echo "valido" || echo "roto: no lo mandes"
# parse error: Unfinished JSON term at EOF at line 1, column 15
# roto: no lo mandes
```

**Verifica**: en el patrón que se usará en el proyecto.

```bash
enviar_si_valido() {
  local archivo="$1"
  if ! jq empty "$archivo" 2>/dev/null; then
    echo "ERROR: $archivo no es JSON valido" >&2
    return 1
  fi
  curl -sS --fail-with-body --max-time 10 \
    -H 'Content-Type: application/json' --data-binary @"$archivo" \
    http://localhost:8080/post | jq -c .json
}

enviar_si_valido roto.json;   echo "salida=$?"
enviar_si_valido pedido.json | head -c 60; echo
# ERROR: roto.json no es JSON valido
# salida=1
# {"cliente":{"email":"ada@ejemplo.com","nombre":"Ada Lovelace
```

---

## Paso 8: El script del entregable

**Por qué**: es el patrón que vas a copiar al proyecto. Convierte variables de
entorno en un cuerpo JSON válido y lo envía.

**Comando**: crea `construir-cuerpo.sh`.

```bash
cat > construir-cuerpo.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

# Convierte tres variables en un cuerpo JSON y lo envia al laboratorio.
# Uso:  NOMBRE='Ada "la primera"' ROL=admin EDAD=36 ./construir-cuerpo.sh

BASE_URL="${BASE_URL:-http://localhost:8080}"
NOMBRE="${NOMBRE:?falta NOMBRE}"
ROL="${ROL:-lector}"
EDAD="${EDAD:-0}"

# --arg para cadenas, --argjson para numeros: si EDAD fuera --arg llegaria
# como "36" y una API con validacion estricta lo rechazaria con un 422.
cuerpo=$(jq -n --arg n "$NOMBRE" --arg r "$ROL" --argjson e "$EDAD" \
  '{nombre: $n, rol: $r, edad: $e}')

# Validacion antes de gastar la peticion.
jq empty <<<"$cuerpo"

curl -sS --fail-with-body --max-time 10 \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  --data-raw "$cuerpo" \
  "${BASE_URL}/post" | jq -c .json
SH
chmod +x construir-cuerpo.sh
```

**Verifica**:

```bash
NOMBRE='Ada "la primera"' ROL=admin EDAD=36 ./construir-cuerpo.sh
# {"edad":36,"nombre":"Ada \"la primera\"","rol":"admin"}
```

Fíjate en el `--data-raw` en vez de `-d`: el cuerpo viene de una variable y
podría empezar por `@`. Es la costumbre correcta en un script que recibe datos
de fuera.

```bash
# Y que falla cuando falta lo obligatorio, gracias al ${NOMBRE:?}.
./construir-cuerpo.sh; echo "salida=$?"
# ./construir-cuerpo.sh: line 10: NOMBRE: falta NOMBRE
# salida=1
```

---

## ✅ Resultado

- [ ] Tienes `pedido.json` con objetos anidados, un array y comillas dentro de un valor
- [ ] Cuentas las líneas del cuerpo con `-d @` y con `--data-binary @` y salen 1 y 12
- [ ] Mandas el pedido entero y recuperas `.json.nota` con las comillas intactas
- [ ] Encadenas `jq | curl | jq` sin ningún archivo temporal
- [ ] Provocas un `.json` a `null` interpolando una variable con comillas dentro
- [ ] Lo arreglas con `jq -n --arg` y compruebas que llega entero
- [ ] Distingues `--arg` de `--argjson` mirando los tipos con `map_values(type)`
- [ ] `construir-cuerpo.sh` funciona, falla si falta `NOMBRE` y pasa `shellcheck`

```bash
shellcheck -S warning construir-cuerpo.sh
./scripts/verificar-semana.sh 02
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `parse error: Unfinished JSON term` | El JSON está roto | Es lo que buscabas en el paso 7. En otro contexto, revisa llaves y comas |
| `.data` llega en una sola línea | Usaste `-d @archivo` | `--data-binary @archivo` |
| `.json` es `null` y el cuerpo parecía correcto | Falta el `Content-Type`, o el JSON llegó roto | Comprueba las dos cosas: `-H` y `jq empty` |
| El valor de la variable sale literal como `$NOMBRE` | Comillas simples: el shell no interpola dentro | `jq -n --arg`, no interpolación directa |
| La API rechaza un número con 422 | Lo metiste con `--arg` y llegó como `"36"` | `--argjson` |
| `jq: error: Could not open file` | La ruta del archivo está mal | `ls` primero; en `jq` el archivo va sin `@` |
| El script sale con 0 aunque el JSON estuviera roto | Falta el `set -euo pipefail`, o el `jq empty` está después del `curl` | Valida antes de enviar |
| `curl: (26) Failed to open/read local data` | El cuerpo empezaba por `@` y se interpretó como archivo | `--data-raw` |

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [Práctica 03 — Headers a mano](03-headers-a-mano.md) | **Práctica 04 — JSON que no cabe en la línea** | — |

[← Volver a la Semana 02](../README.md)
