# `init` sin pisar nada

> Crear un archivo de configuración parece una línea: `echo ... > ~/.bc-curl`.
> Esa línea, ejecutada dos veces, borra el token que pegaste ayer; ejecutada
> con la umask de siempre, deja tus secretos legibles por otros usuarios; y
> escrita como `API_TOKEN=xxx api-toolkit init`, deja el token en el
> historial del shell. Esta teoría construye un `init` que no hace ninguna de
> las tres cosas.

![Tres intentos de crear ~/.bc-curl. El primero, con > a secas, pisa un archivo que ya tenía el token. El segundo, comprobando antes con test -e, deja un hueco en el que otro proceso puede crear el archivo. El tercero, con set -o noclobber dentro de un subshell con umask 077, abre con O_EXCL: si el archivo existe, falla sin tocarlo, y si no, nace con permisos 600](../0-assets/03-init-sin-pisar-nada.svg)

## 🎯 Objetivos

- Crear un archivo nuevo sin pisar uno existente, también si dos procesos compiten
- Hacer que un archivo nazca con permisos 600, sin una ventana con 644
- Decidir qué escribe `init` y qué deja para el editor
- Preferir un `init` que se configura por entorno a uno con preguntas
- Saber cuándo un `init` debe fallar y con qué código

---

## 1. Qué problema resuelve

Un `init` ingenuo:

```bash
iniciar_configuracion() {
  echo "BASE_URL=$BASE_URL" > ~/.bc-curl
  chmod 600 ~/.bc-curl
}
```

Tiene tres fallos, y los tres hacen daño de verdad:

1. **Pisa.** Si ya existía `~/.bc-curl` con tu token, el `>` lo trunca. Un
   `init` es lo que alguien ejecuta "por si acaso" al seguir un tutorial.
2. **Nace abierto.** Entre el `>` y el `chmod`, el archivo existe con la
   umask de quien ejecuta, casi siempre 022: 644, legible por cualquiera.
   Hoy solo tiene la URL, pero es el archivo donde irán los secretos.
3. **Invita a pasar secretos.** Si `init` escribiera `API_TOKEN` desde el
   entorno, la forma natural de usarlo sería `API_TOKEN=... api-toolkit init`,
   y el token quedaría en `~/.bash_history`.

---

## 2. Cómo funciona

### 2.1 No pisar: `noclobber`

`set -o noclobber` (o `set -C`) cambia el significado de `>`: si el archivo
existe, la redirección **falla** en lugar de truncarlo.

```bash
echo hola > x.txt
( set -o noclobber; echo adios > x.txt )
# bash: x.txt: cannot overwrite existing file
cat x.txt
# hola
```

Lo importante es **cómo** lo hace: bash abre el archivo con `O_CREAT|O_EXCL`,
y el kernel garantiza que esa apertura crea el archivo o falla, en un solo
paso. Comprobar antes con `[ -e ]` no basta: entre la comprobación y el `>`
cabe otro proceso (la misma carrera que la teoría 08 de la Semana 09). El
toolkit hace las dos cosas: la comprobación da un mensaje claro, y
`noclobber` cierra la carrera.

`>|` se salta `noclobber` a propósito. No lo uses aquí.

### 2.2 Nacer con 600: `umask 077`

La umask decide los permisos con los que **nace** un archivo. Con `077`, nace
`600`:

```bash
( umask 077 && set -o noclobber && plantilla_configuracion > "$BC_CURL_FILE" )
```

- Los paréntesis abren un **subshell**: la umask y el `noclobber` solo valen
  dentro. El resto del toolkit sigue con los de quien lo ejecuta.
- No hay `chmod` después, y por tanto no hay ventana con 644.
- Es el mismo patrón que `temporal_privado` desde la Semana 03 y que el
  `.lock` de la Semana 09.

### 2.3 Qué escribe `init`

```text
# Configuracion de api-toolkit, creada por api-toolkit init.
# Permisos 600: aqui pueden ir los secretos. El entorno manda sobre este
# archivo. Una clave por linea, CLAVE=valor, sin comillas.
BASE_URL=https://api.github.com
AUTH_MODE=bearer
# API_CACERT=
# API_TOKEN=
# API_USER=
# ...
```

- **Valores no secretos**, tomados del entorno o, si no hay, de los valores
  por defecto: `BASE_URL`, `AUTH_MODE` y, si está definida, `API_CACERT`.
- **Las claves de los secretos, comentadas y vacías.** El archivo le dice a
  quien lo abre qué puede poner, y el secreto entra con el editor: nunca
  pasa por la línea de comandos ni por el historial.
- **Sin comillas**: el toolkit lee `CLAVE=valor` tal cual (teoría 02). Una
  comilla sería parte del valor.

Un valor con salto de línea rompería el formato, y podría colar una línea
`API_TOKEN=` que nadie escribió. `init` lo rechaza antes de escribir.

### 2.4 Sin preguntas

Muchos `init` preguntan: "¿URL de la API?". El del toolkit no:

| | Con preguntas (`read -p`) | Por entorno |
|---|---|---|
| Desde un script o la CI | Se queda esperando, o hay que inyectar respuestas | `BASE_URL=... api-toolkit init` |
| Con bats | Hay que alimentar stdin | Una variable |
| Para una persona | Guiado | Necesita leer `--help` |

Se puede tener los dos: preguntar solo si stdin es una terminal
(`[ -t 0 ]`). Es más código para lo que una línea de la ayuda resuelve.

### 2.5 Fallar con 1, y decir qué hacer

Si el archivo existe, `init` sale con **1** (error de uso: no tiene sentido
repetirlo) y el mensaje dice cómo seguir:

```text
error: /home/ana/.bc-curl ya existe; no lo piso. Editalo, o borralo y repite
```

No hay `--force`. Borrar un archivo con secretos debe ser una decisión con
`rm`, no un flag que se copia de un tutorial.

---

## 3. Cómo se usa

```bash
BASE_URL=http://localhost:8080/anything API_TOKEN=valor-de-prueba api-toolkit init
# configuracion creada en /home/ana/.bc-curl (permisos 600)

ls -l ~/.bc-curl | cut -c1-10
# -rw-------
grep -c valor-de-prueba ~/.bc-curl
# 0

api-toolkit init; echo "salida: $?"
# error: /home/ana/.bc-curl ya existe; no lo piso. Editalo, o borralo y repite
# salida: 1
```

El token del entorno no llegó al archivo. El segundo `init` no tocó nada.

---

## 4. Antipatrones

- **`echo ... > archivo` sin `noclobber`.** Trunca lo que hubiera.
- **`[ -e archivo ] || echo ... > archivo`.** Entre la prueba y el `>` cabe
  otro proceso. La prueba sirve para el mensaje; la garantía la da `O_EXCL`.
- **`chmod 600` después de crear.** Deja una ventana con los permisos de la
  umask. La umask va antes.
- **`umask 077` fuera de un subshell.** Cambia los permisos de todo lo que
  el script cree después, incluidos los archivos que el usuario espera
  legibles (un `download`, por ejemplo).
- **`init --force`.** Convierte el borrado de un secreto en un flag.
- **Escribir los secretos del entorno.** Enseña a pasarlos por la línea de
  comandos.

---

## 5. Trucos

- **Ver tu umask**: `umask` imprime `0022` casi siempre; `umask -S`, en
  letras (`u=rwx,g=rx,o=rx`).
- **`noclobber` para tu shell** interactivo: `set -o noclobber` en el
  `~/.bashrc` evita truncar un archivo por un `>` de más. Cuando quieras
  pisar, `>|`.
- **Crear un archivo vacío con 600 en una línea**:
  `( umask 077 && : > archivo )`.
- **Probar `init` sin tocar tu configuración**:
  `HOME="$(mktemp -d)" api-toolkit init`. Tu `~/.bc-curl` no se entera.

---

## 📚 Recursos Adicionales

- [Bash Reference Manual — The Set Builtin (`-C`, noclobber)](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html)
- [open(2) — `O_EXCL`](https://man7.org/linux/man-pages/man2/open.2.html)
- [umask(2)](https://man7.org/linux/man-pages/man2/umask.2.html)

---

## ✅ Checklist de Verificación

- [ ] Explicas por qué `[ -e ]` no basta y qué añade `O_EXCL`
- [ ] Creas un archivo con 600 sin `chmod` posterior
- [ ] Sabes por qué la umask va dentro de un subshell
- [ ] Explicas por qué `init` no escribe secretos y no tiene `--force`
- [ ] Sabes con qué código sale `init` si el archivo existe, y por qué
