# Glosario — Semana 10

Términos de configuración, tests, documentación, instalación e integración
continua que aparecen esta semana. El término real en inglés va entre
paréntesis, y las funciones que no son universales llevan **su versión
mínima**. Los términos de todo el bootcamp están en
[`docs/glosario-global.md`](../../../docs/glosario-global.md).

---

## Símbolos

**`${!clave}`** · Expansión indirecta: el valor de la variable cuyo nombre
está en `clave`. Junto con `printf -v`, sustituye a `eval`.

## A

**Acción** (*action*) · Código reutilizable de otro repositorio que un
workflow ejecuta con `uses:`. Se fija por el SHA de un commit, no por una
etiqueta.

**Aislamiento** (de un test) · Que el resultado no dependa de quien lo
ejecuta. En bats: un HOME vacío y `unset` de las variables en `setup`.

## B

**bats** (*Bash Automated Testing System*) · Herramienta de tests para bash.
Cada `@test` corre en su propio proceso. Suelo del bootcamp: **bats-core
1.2.1**, el de Ubuntu 22.04.

**`$BATS_TEST_DIRNAME`** · La carpeta del `.bats` en ejecución. Sirve para
encontrar el programa que se prueba sin depender del directorio actual.

**`$BATS_TEST_TMPDIR`** · Un directorio temporal por test. **bats 1.4.0**;
en 1.2.1, `mktemp -d` en `setup`.

## C

**Caja negra** (*black-box testing*) · Probar un programa desde fuera, con
sus argumentos, su entorno y su salida, sin llamar a sus funciones internas.

**`CHANGELOG`** · Lista de cambios por versión, la más nueva arriba, escrita
para quien usa el programa. Formato habitual: *Keep a Changelog*.

**CI** (*continuous integration*, integración continua) · Ejecutar los tests
automáticamente en cada push, en una máquina limpia.

**`CLAVES_ARCHIVO`** · La lista de claves que el toolkit acepta de
`~/.bc-curl`. Cualquier otra, `PATH` incluida, se ignora.

## E

**Etiqueta anotada** (*annotated tag*) · `git tag -a v1.0.0 -m ...`: guarda
autor, fecha y mensaje. La que marca una versión.

## H

**`hash -r`** · Hace que bash olvide las rutas de los comandos que ya
ejecutó. Tras desinstalar, `command -v` puede seguir dando la ruta vieja.

## I

**`init`** · Subcomando que crea la configuración inicial. El del toolkit:
permisos 600, sin pisar un archivo existente, sin escribir secretos y sin
preguntas.

**`install`** (comando) · Copia un archivo **fijando** sus permisos
(`-m 755`) y sustituyéndolo en vez de escribir dentro. `-D` es de GNU: en
macOS, `install -d` y después `install -m`.

**Interfaz de una CLI** · Argumentos, entorno y archivo de configuración,
stdout, stderr y código de salida. Cambiar cualquiera rompe a alguien.

## M

**Matriz** (*matrix*) · En GitHub Actions, `strategy.matrix`: un job por
cada combinación de valores. El toolkit usa una por imagen.

**Mutación** (*mutation testing*) · Estropear el programa a propósito y
comprobar que algún test se entera. La versión mínima: `TK=/bin/true`.

## N

**`noclobber`** (`set -C`) · Hace que `>` falle si el archivo existe. Bash
abre con `O_EXCL`: crear o fallar, en un solo paso. `>|` se lo salta.

## O

**`O_EXCL`** · Opción de `open(2)` que, junto con `O_CREAT`, garantiza que
el archivo se crea en esa llamada o la llamada falla.

## P

**`permissions`** (en un workflow) · Lo que puede hacer el `GITHUB_TOKEN`.
`contents: read` lo deja en solo lectura.

**`persist-credentials: false`** · Opción de `actions/checkout` que no deja
el token guardado en `.git/config` para los pasos siguientes.

**Precedencia** · El orden en que se busca un valor de configuración. En el
toolkit: entorno, después `~/.bc-curl`, después el valor por defecto.

**`PREFIX`** · La raíz de una instalación. Los ejecutables van en
`PREFIX/bin`. Por defecto `~/.local`, que no necesita `sudo`.

**`printf -v`** · Asigna a una variable cuyo nombre está en otra:
`printf -v "$clave" '%s' "$valor"`. **bash 3.1**; existe en el 3.2 de macOS.

## R

**`run`** (bats) · Ejecuta un comando sin que su fallo pare el test, y deja
`$status`, `$output` y `${lines[@]}`. En 1.2.1, `$output` mezcla stdout y
stderr; `--separate-stderr` es de **bats 1.5.0**.

**Runner** · La máquina en la que GitHub ejecuta un job. Los de Ubuntu 22
dejan de existir el 17 de abril de 2027.

## S

**Semver** (*Semantic Versioning*) · `MAYOR.MENOR.PARCHE`. La mayor sube
cuando un cambio rompe la interfaz; `1.0.0` promete que es estable.

**SHA** (de un commit) · Su identificador de 40 caracteres hexadecimales.
No se puede mover a otro código, como sí una etiqueta.

**`skip`** (bats) · Marca un test como saltado en lugar de fallado. Para lo
que depende de algo externo, como el laboratorio.

**`source`** · Ejecuta un archivo en el shell actual. Con un archivo de
configuración, ejecuta lo que contenga: por eso el toolkit lo lee con
`read`.

## T

**TAP** (*Test Anything Protocol*) · El formato de salida de bats: `1..N` y
una línea `ok` o `not ok` por test.

**`teardown`** (bats) · Función que bats llama después de cada test, también
si falló. Borra lo que creó `setup`.

## U

**`umask`** · Los permisos que se quitan a todo archivo que nace. Con `077`,
nace con 600. Dentro de un subshell, para no cambiar el resto del script.

## W

**Workflow** · Archivo YAML en `.github/workflows/` que define cuándo y cómo
se ejecuta la CI en GitHub Actions.

**`workflow_dispatch`** · Disparador que permite lanzar un workflow a mano
desde la pestaña Actions.

## X

**XDG** · Especificación de dónde guardar configuración (`~/.config`),
datos y ejecutables del usuario (`~/.local/bin`).

---

| Anterior | Siguiente |
|---|---|
| [Recursos](../4-recursos/README.md) | [README de la Semana 10](../README.md) |

[← Glosario global del bootcamp](../../../docs/glosario-global.md)
