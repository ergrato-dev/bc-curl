# Tests que prueban algo

> Que `bats tests/` diga `ok` no significa que el toolkit funcione. Puede
> significar que los tests leyeron tu `~/.bc-curl` y por eso pasaron, que
> solo comprueban que el código de salida es 0, o que dependen de que el
> laboratorio esté arriba. Esta teoría va de los tres fallos que hacen que un
> test mienta, y de cómo comprobar que tus tests son capaces de fallar.

![Tres tests que mienten y su arreglo. El primero pasa porque lee el ~/.bc-curl y el BASE_URL de quien lo ejecuta; se arregla con un HOME vacío y unset de las variables en setup. El segundo solo mira $status, y un toolkit que no hace nada también sale con 0; se arregla comprobando $output. El tercero necesita red; se arregla con --dry-run, que enseña el comando sin ejecutarlo, o con skip si falta el laboratorio. Abajo, la prueba de que los tests sirven: con TK=/bin/true, la suite tiene que fallar](../0-assets/05-tests-que-prueban-algo.svg)

## 🎯 Objetivos

- Aislar cada test del HOME y del entorno de quien lo ejecuta
- Comprobar la salida y no solo el código de salida
- Probar sin red con `--dry-run` y con un puerto cerrado
- Comprobar que una suite es capaz de fallar sustituyendo el programa
- Decidir qué probar como caja negra y qué no probar

---

## 1. Qué problema resuelve

Un test de la configuración, escrito deprisa:

```bash
@test "la BASE_URL del archivo se usa" {
  run "$TK" --dry-run get /x
  [[ "$output" == *"http://localhost:8080/x"* ]]
}
```

Pasa en tu máquina. Y pasa por tres razones que no tienen nada que ver con
que funcione:

1. No hay archivo en el test: lee **tu** `~/.bc-curl`, o ninguno.
2. `http://localhost:8080` es también el valor por defecto: si el toolkit
   ignorara el archivo, pasaría igual.
3. Si tienes `BASE_URL` exportada para otra cosa, falla, y no por culpa del
   código.

Un test que pasa o falla según quién lo ejecute no es un test.

---

## 2. Cómo funciona

### 2.1 Aislar: un HOME vacío y sin variables

El toolkit lee dos cosas que no son suyas: el entorno y `~/.bc-curl`. Cada
test tiene que empezar sin ninguna de las dos:

```bash
setup() {
  DIR="$(mktemp -d)"
  export HOME="$DIR"
  unset BASE_URL AUTH_MODE API_TOKEN BC_CURL_FILE ...   # todas las del --help
}
```

- **`HOME` apunta a un directorio vacío**: `~/.bc-curl`,
  `~/.bc-curl-session` y cualquier otro archivo del usuario dejan de existir
  para el toolkit. Y un test de `init` escribe en ese directorio, no en tu
  configuración real.
- **`unset` de todas las variables** que lista la cabecera del toolkit. Si
  mañana añades una variable y no la añades aquí, un test puede heredarla.
- El `export` y el `unset` solo valen dentro del proceso del test: tu shell
  no se entera.

La prueba de que funciona: lanzar los tests con un entorno roto a propósito.

```bash
H="$(mktemp -d)"; echo BASE_URL=http://127.0.0.1:9 > "$H/.bc-curl"; chmod 644 "$H/.bc-curl"
HOME="$H" BASE_URL=http://127.0.0.1:9 AUTH_MODE=bearer bats tests/
```

Sin aislamiento, el toolkit se niega a leer un `~/.bc-curl` con 644 y medio
`tests/` falla. Con aislamiento, nadie lo ve.

### 2.2 Valores que no pueden salir por casualidad

En el ejemplo de arriba, `localhost:8080` puede venir del archivo o del
valor por defecto. Un buen test usa un valor que **solo** puede venir de
donde dice:

```bash
@test "la BASE_URL del archivo se usa" {
  BASE_URL=http://ejemplo.invalid "$TK" init 2> /dev/null
  run "$TK" --dry-run get /x
  [[ "$output" == *"http://ejemplo.invalid/x"* ]]
}
```

`.invalid` es un dominio reservado (RFC 2606): nunca resolverá, así que si
algo intentara conectarse, fallaría en vez de hablar con alguien.

### 2.3 Caja negra con `--dry-run`

Los tests prueban el toolkit **desde fuera**, como lo usa cualquiera: con
argumentos, entorno y archivos, mirando la salida y el código. No llaman a
funciones internas. Así, reorganizar el código no rompe ningún test si el
comportamiento no cambia.

`--dry-run` (desde la Semana 02) es la puerta para probar sin red: imprime el
comando curl que habría ejecutado. Con él se prueban la configuración, los
flags, la URL final y que la credencial salga tachada.

### 2.4 Probar un fallo de red sin red

Para un error de red no hace falta red: basta un puerto donde nadie escucha.

```bash
@test "una API que no responde sale con 69" {
  export BASE_URL=http://127.0.0.1:9
  run "$TK" post /post '{}'
  [ "$status" -eq 69 ]
}
```

El puerto 9 (`discard`) casi nunca tiene nada escuchando, y la conexión se
rechaza al momento. Con `post` y no con `get`: el toolkit no reintenta un
POST, y un `get` esperaría sus tres reintentos, unos 7 segundos.

### 2.5 ¿Mis tests pueden fallar?

Una suite que nunca falla no se distingue de una que no comprueba nada. La
prueba más barata: sustituir el toolkit por un programa que no hace nada y
sale con 0.

```bash
TK=/bin/true bats tests/
# not ok 1 --version imprime el nombre y una version semver
# ...
echo $?
# 1
```

Para que funcione, el `.bats` toma el ejecutable de una variable:

```bash
TK="${TK:-${BATS_TEST_DIRNAME}/../api-toolkit.sh}"
```

Si con `/bin/true` algún test **pasa**, ese test solo mira `$status`. Es la
versión mínima de una idea con nombre, el *mutation testing*: estropear el
programa a propósito y comprobar que algún test se entera.

### 2.6 Qué no probar

- **Lo que ya prueba `verificar-semana.sh`**: `bench`, la caché, OAuth2.
  Necesitan el laboratorio y ya tienen su comprobación.
- **Mensajes exactos**: comprueba la parte que importa (`*"chmod 600"*`), no
  la frase entera; si no, cada cambio de redacción rompe un test.
- **Lo que hace curl**: los tests prueban lo que el toolkit le pide a curl,
  no si curl sabe hacer HTTP.

---

## 3. Cómo se usa

```bash
bats tests/                                     # en tu máquina, con el laboratorio
# ok 8 get contra el laboratorio devuelve el cuerpo

./scripts/stop.sh && bats tests/                # sin laboratorio, como en la CI
# ok 8 get contra el laboratorio devuelve el cuerpo # skip el laboratorio no responde en localhost:8080

TK=/bin/true bats tests/ > /dev/null; echo $?   # ¿pueden fallar?
# 1
```

---

## 4. Antipatrones

- **Tests que leen tu HOME.** Pasan en tu máquina y fallan en la de otra
  persona, o al revés.
- **Valores que coinciden con el valor por defecto.** No distinguen "lo leyó"
  de "no lo leyó".
- **Tests contra una API real** (GitHub, por ejemplo): gastan rate limit,
  necesitan un token en la CI y fallan cuando la API cambia o se cae.
- **`sleep` para esperar a algo.** Lento siempre y, aun así, a veces corto.
- **Un test que nunca has visto fallar.** Antes de darlo por bueno, rompe el
  código a propósito y mira que se pone rojo.
- **`rm -rf "$HOME"` en `teardown`** después de cambiar HOME. Si `setup`
  fallara antes del `export`, borrarías tu HOME de verdad. Borra la variable
  propia, `$DIR`.

---

## 5. Trucos

- **Un HOME de usar y tirar para probar a mano**: `HOME="$(mktemp -d)" ./api-toolkit.sh init`.
- **Ver qué variables lee el toolkit** para la lista del `unset`:
  `grep -oE '^#   [A-Z_]+' api-toolkit.sh | tr -d '# ' | sort -u`.
- **Mutación a mano**: cambia `umask 077` por `umask 022` en `init`, lanza
  `bats -f 600 tests/`, y deshaz el cambio. Si sigue en verde, el test no
  mira los permisos.
- **`-f` con el nombre**: nombres descriptivos permiten lanzar un grupo,
  `bats -f init tests/`.

---

## 📚 Recursos Adicionales

- [RFC 2606 — Reserved Top Level DNS Names (`.invalid`)](https://www.rfc-editor.org/rfc/rfc2606)
- [bats-core — Gotchas](https://bats-core.readthedocs.io/en/stable/gotchas.html)
- [Martin Fowler — Test Double](https://martinfowler.com/bliki/TestDouble.html)

---

## ✅ Checklist de Verificación

- [ ] Aíslas cada test con un HOME vacío y `unset` de las variables
- [ ] Eliges valores que solo pueden venir de donde el test dice
- [ ] Pruebas la configuración con `--dry-run`, sin red
- [ ] Pruebas un error de red con un puerto cerrado, sin esperar reintentos
- [ ] Compruebas con `TK=/bin/true` que tus tests pueden fallar
