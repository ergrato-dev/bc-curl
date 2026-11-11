# jq en scripts

> En la terminal, `jq` es para mirar un JSON. En un script es lo que decide si
> la respuesta sirve: si tiene la forma esperada, si falta un campo, si el
> resultado es vacío. Para eso hay que usar su código de salida, y saber dónde
> miente.

![Diagrama de los códigos de salida de jq con -e: 0 si el último resultado no es false ni null, 1 si es false o null, 4 si no hubo ningún resultado, y 2 a 5 para errores de uso, de compilación, de entrada y de ejecución; con una nota en rojo sobre la entrada vacía, que en jq 1.6 sale con 0 aunque lleve -e](../0-assets/04-jq-en-scripts.svg)

## 🎯 Objetivos

- Hacer que `jq` falle cuando la respuesta no tiene la forma esperada
- Pasar valores del shell a `jq` sin construir JSON concatenando texto
- Juntar varias respuestas en una con `-s`
- Conocer las diferencias de jq 1.6 (Ubuntu 22.04) que afectan a un script

---

## 1. Qué problema resuelve

```bash
curl -sS http://localhost:8080/get | jq -r '.usuarios[0].email'
# null
echo $?
# 0
```

`.usuarios` no existe. `jq` devuelve `null`, sale con 0, y el script tiene ahora
una variable con la cadena `null`, que pasará a la siguiente petición como si
fuera un email. Con `-r`, `null` y una cadena que diga `"null"` son
**indistinguibles**.

Por defecto `jq` es tolerante: acceder a un campo que no existe no es un
error. En un script, esa tolerancia convierte una respuesta inesperada en un
dato falso.

---

## 2. Cómo funciona

### 2.1 Los códigos de salida de jq

| Código | Cuándo |
|:--:|---|
| 0 | El programa terminó sin errores |
| 1 | Con `-e`: el último resultado fue `false` o `null` |
| 2 | Error de uso (opción desconocida, `--argjson` con JSON inválido) |
| 3 | Error de compilación: el filtro está mal escrito |
| 4 | Con `-e`: no hubo ningún resultado |
| 5 | Error de ejecución: indexar un texto como si fuera un objeto |

La entrada que no es JSON sale con 4 en jq 1.6 y con 5 en jq 1.7. No compares
con un número concreto: **distinto de 0** es lo que cuenta.

### 2.2 `-e`: que `null` sea un fallo

```bash
curl -sS http://localhost:8080/get | jq -e -r '.usuarios[0].email'
# null
echo $?
# 1
```

Con `-e` (`--exit-status`), el código depende del **último** resultado:
`false` o `null` dan 1. Es la forma de convertir "falta un campo" en un fallo
que `set -e` ve.

Lo mismo sirve para validar la forma:

```bash
echo '[{"id":1}]'  | jq -e 'type == "array"' > /dev/null; echo $?   # 0
echo '{"id":1}'    | jq -e 'type == "array"' > /dev/null; echo $?   # 1
echo '{"id":1}'    | jq -e 'has("id")'       > /dev/null; echo $?   # 0
```

### 2.3 La trampa de la entrada vacía

```bash
printf '' | jq -e .
echo $?
# 0 en jq 1.6, 4 en jq 1.7
```

Un curl que falló sin escribir nada deja una entrada vacía, y jq 1.6, el de
Ubuntu 22.04, la da **por buena** aunque lleve `-e`: no hay ningún valor que
evaluar, no hay error, sale con 0. jq 1.7 lo corrigió y sale con 4.

Si el script tiene que funcionar con las dos, comprueba antes que hay algo:

```bash
[ -s respuesta.json ] && jq -e 'type == "array"' respuesta.json > /dev/null \
  || { echo "respuesta vacia o no es una lista" >&2; exit 1; }
```

`[ -s ARCHIVO ]` es verdadero si el archivo existe y no está vacío. Es la
comprobación que hace `fetch_all` en el toolkit.

### 2.4 `?` y `//`: tolerancia elegida

```bash
echo '"texto"' | jq '.a'       # error, sale con 5
echo '"texto"' | jq '.a?'      # nada, sale con 0
echo '{"a":null}' | jq -r '.a // "por defecto"'
# por defecto
```

`.a?` suprime el error de indexar algo que no es un objeto. `A // B` devuelve
`B` si `A` es `null`, `false` o no produce nada. Son las herramientas para
cuando la ausencia **sí** es normal. Úsalas a propósito, no para tapar un
`-e` que molesta.

---

## 3. Cómo se usa

### 3.1 Validar una respuesta antes de usarla

```bash
cuerpo=$(mktemp)
curl -sS --fail-with-body --max-time 10 -o "$cuerpo" http://localhost:8080/get

jq -e '.url and .headers' "$cuerpo" > /dev/null \
  || { echo "la respuesta no tiene la forma esperada" >&2; exit 1; }

url=$(jq -r .url "$cuerpo")
```

Validar primero y extraer después separa los dos errores: "la API no ha
contestado lo que esperaba" y "mi filtro está mal".

### 3.2 Pasar valores del shell: `--arg` y `--argjson`

```bash
nombre='Ana "la del 3"'
jq -nc --arg nombre "$nombre" '{nombre: $nombre}'
# {"nombre":"Ana \"la del 3\""}

jq -nc --argjson edad 41 '{edad: $edad}'
# {"edad":41}
```

`--arg` pasa siempre un texto, escapado correctamente. `--argjson` pasa un
valor JSON (un número, un booleano, un objeto) y falla con 2 si no lo es.
`-n` arranca sin leer ninguna entrada.

La alternativa, construir el JSON pegando texto, se rompe en cuanto el valor
lleva comillas:

```bash
# Mal: '{"nombre":"'"$nombre"'"}' da un JSON invalido con ese nombre,
# y con un nombre preparado, un JSON con campos que no has puesto tu.
```

Es el mismo problema que la inyección SQL. `jq -n --arg` es el `?` de una
consulta preparada.

### 3.3 Juntar varias respuestas: `-s`

```bash
printf '[1]\n[2,3]\n' | jq -c -s 'add'
# [1,2,3]
printf '' | jq -c -s 'add // []'
# []
```

`-s` (`--slurp`) lee **todas** las entradas y las mete en un array. Con una
lista por línea, `add` las concatena. Sin entradas, `add` da `null`; el
`// []` lo convierte en la lista vacía que esperaría quien recibe el
resultado.

Es el final de `fetch-all`: una línea por página en un archivo, y un
`jq -s 'add // []'` que las convierte en una sola lista.

### 3.4 De JSON a bash: `-r` y `@tsv`

```bash
echo '[{"id":1,"nombre":"Ana Ruiz"},{"id":2,"nombre":"Luis"}]' \
  | jq -r '.[] | [.id, .nombre] | @tsv' \
  | while IFS=$'\t' read -r id nombre; do
      echo "id=$id nombre=$nombre"
    done
# id=1 nombre=Ana Ruiz
# id=2 nombre=Luis
```

`@tsv` separa los campos con tabuladores y escapa los que lleve el valor. Un
espacio en el nombre no parte el campo, como pasaría con `read id nombre` sobre
una salida separada por espacios.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `jq -r .campo` sin `-e` | Un campo que falta llega como la cadena `null` | `jq -e -r .campo` |
| `jq -e .` como única comprobación en jq 1.6 | Una entrada vacía sale con 0 | `[ -s archivo ] && jq -e ...` |
| `'{"x":"'"$valor"'"}'` | Comillas en el valor rompen el JSON, o lo amplían | `jq -n --arg x "$valor" '{x: $x}'` |
| `.campo?` o `// empty` por todas partes | Esconde respuestas que no tienen la forma esperada | Tolerancia solo donde la ausencia es normal |
| `curl ... \| jq` sin `pipefail` | El código es el de jq: curl caído + entrada vacía = 0 | `set -o pipefail`, o archivo y `-s` |
| Comparar el código de jq con un número | Cambia entre 1.6 y 1.7 | Comparar con 0 |

---

## 5. Trucos

- **`jq --version`** te dice con cuál estás. Ubuntu 22.04 trae 1.6; las
  imágenes oficiales `ghcr.io/jqlang/jq` van por 1.7.
- **`jq -c`** imprime cada valor en una línea: el formato JSON Lines de la
  Semana 06, y lo que espera `jq -s` del otro lado.
- **`jq -e 'length > 0'`** sobre una lista falla si viene vacía: útil cuando
  "no hay resultados" es un error para tu script.
- **`jq -r --arg k "$campo" '.[$k]'`** lee un campo cuyo nombre está en una
  variable del shell, sin construir el filtro pegando texto.

---

## 📚 Recursos Adicionales

- [jq Manual (1.6)](https://jqlang.github.io/jq/manual/v1.6/)
- [jq Manual (1.7)](https://jqlang.github.io/jq/manual/v1.7/), con la lista de
  cambios de comportamiento
- [jq 1.7 release notes](https://github.com/jqlang/jq/releases/tag/jq-1.7)

---

## ✅ Checklist de Verificación

- [ ] Tus filtros de extracción llevan `-e`
- [ ] Sabes qué hace jq 1.6 con una entrada vacía y cómo protegerte
- [ ] Construyes JSON con `jq -n --arg`, nunca pegando texto
- [ ] Juntas varias listas en una con `jq -s 'add // []'`
- [ ] Recorres una lista de objetos en bash con `@tsv` sin partir los campos
