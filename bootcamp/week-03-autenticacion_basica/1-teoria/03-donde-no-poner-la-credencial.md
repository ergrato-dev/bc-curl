# Dónde no poner la credencial

> La parte de la semana que se te tiene que quedar. El esquema lo elige la API;
> dónde acaba el secreto lo eliges tú, y ahí es donde se pierden las
> credenciales de verdad.

![Diagrama de los cuatro sitios donde se filtra una credencial —ps, historial, log de CI y proxy— frente a las tres formas de evitarlo: --config, --netrc-file y -H @archivo](../0-assets/03-donde-no-poner-la-credencial.svg)

## 🎯 Objetivos

- Demostrar con `ps` que una credencial en el argv es legible por cualquier usuario
- Usar `--config`, `--netrc-file` y `-H @archivo`, y elegir entre los tres
- Crear un archivo de credenciales que nazca ya con permisos 600
- Escribir un script que se niegue a usar un archivo de credenciales mal protegido

---

## 1. Qué problema resuelve

Este comando funciona. Y publica el token:

```bash
# ❌ El token es visible para cualquier usuario de la maquina mientras dure la
#    peticion, y queda en ~/.bash_history para siempre.
curl -H "Authorization: Bearer $API_TOKEN" https://api.ejemplo.com/v1/datos
```

La variable de entorno no salva nada: el shell la **expande antes** de lanzar
curl, así que lo que llega al proceso es el valor. Y el argv de un proceso lo
lee cualquiera:

```bash
# En una terminal: una peticion lenta con el token en el argv.
curl -s -H "Authorization: Bearer zzsecretozz" http://localhost:8080/delay/3 >/dev/null &

# En otra (o aqui mismo, un segundo despues): cualquier usuario lo ve.
sleep 1; ps -eo args | grep '^curl ' | grep -c zzsecretozz
# 1
```

Ese `1` es el problema entero de esta teoría. No hace falta ser root, ni estar
en el mismo grupo: `/proc/<pid>/cmdline` es legible por todo el mundo en un
Linux por defecto.

### 1.1 Los cuatro destinos de una credencial escrita en la línea

| Dónde acaba | Quién lo lee | Cuánto dura |
|---|---|---|
| `ps` y `/proc/<pid>/cmdline` | Cualquier usuario de la máquina | Lo que dure la petición |
| `~/.bash_history` / `~/.zsh_history` | Quien lea tu `$HOME`. Y tu copia de seguridad | Meses o años |
| El log del runner de CI | Todo el que tenga acceso al repositorio | Para siempre, y suele ser público en OSS |
| El log del proxy corporativo | El equipo de red, y quien acceda a ese log | Según la retención |

A los cuatro se llega sin ningún ataque: son el funcionamiento normal del
sistema.

---

## 2. Cómo funciona

### 2.1 Las tres salidas de curl

curl tiene tres formas de leer un secreto **de un archivo** en vez de del argv.
Las tres se basan en la misma idea: al proceso le pasas una **ruta**, no un
valor.

| Forma | Desde | Qué guarda | Para qué esquema |
|---|---|---|---|
| `--config archivo` | siempre | Opciones de curl, una por línea | Cualquiera |
| `--netrc-file archivo` | siempre | Máquina, login y password | Basic (y FTP) |
| `-H @archivo` | **7.55+** | Headers, uno por línea | API key, Bearer |

Y una cuarta que no es un archivo: `-u usuario` sin la password, que hace que
curl la **pregunte** por terminal. Sirve en uso interactivo, no en un script.

### 2.2 `--config`: el más general

Un archivo de `--config` es una lista de opciones largas de curl **sin los dos
guiones**, con el valor entre comillas:

```
user = "usuario:password"
header = "Authorization: Bearer el-token"
max-time = 30
```

curl lo lee como si esas opciones estuvieran en la línea de comandos, pero el
contenido nunca entra en el argv:

```bash
# El secreto entra por referencia: en el argv solo esta la ruta del archivo.
printf 'header = "Authorization: Bearer zzsecretozz"\n' > /tmp/auth.conf
chmod 600 /tmp/auth.conf
curl -s --config /tmp/auth.conf http://localhost:8080/bearer | jq -c .
# {"authenticated":true,"token":"zzsecretozz"}
```

Y ahora la misma comprobación de antes:

```bash
curl -s --config /tmp/auth.conf http://localhost:8080/delay/3 >/dev/null &
sleep 1; ps -eo args | grep '^curl ' | grep -c zzsecretozz
# 0
rm -f /tmp/auth.conf
```

Cero. Esa es la diferencia, y se puede enseñar en una revisión de código.

### 2.3 `--netrc-file`: el clásico de Basic

`.netrc` es un formato de los años ochenta que curl sigue soportando. Una línea
por máquina:

```
machine api.ejemplo.com login usuario password el-secreto
```

```bash
# El laboratorio va por localhost, asi que la maquina es "localhost".
printf 'machine localhost login user password password\n' > /tmp/lab.netrc
chmod 600 /tmp/lab.netrc
curl -s --netrc-file /tmp/lab.netrc http://localhost:8080/basic-auth/user/password | jq -c .
# {"authenticated":true,"user":"user","authorized":true}
rm -f /tmp/lab.netrc
```

| Flag | Qué hace |
|---|---|
| `--netrc` | Usa `~/.netrc`. Si no existe o no hay entrada, **falla** |
| `--netrc-file ARCHIVO` | Usa el archivo que le digas |
| `--netrc-optional` | Usa `.netrc` si lo hay, y si no sigue sin credencial |

Su ventaja sobre `--config` es que asocia la credencial a **una máquina**: si
una redirección te lleva a otro host, curl no manda esa credencial. Su
desventaja es que solo sirve para usuario y password.

### 2.4 `-H @archivo`: headers desde un archivo

Desde curl **7.55**, `-H` acepta `@ruta` y lee los headers del archivo, uno por
línea:

```bash
printf 'X-API-Key: clave-de-laboratorio\n' > /tmp/cab.txt
chmod 600 /tmp/cab.txt
curl -s -H @/tmp/cab.txt http://localhost:8080/headers | jq -c '.headers["X-Api-Key"]'
# ["clave-de-laboratorio"]
rm -f /tmp/cab.txt
```

Si tu curl es anterior a 7.55 —comprueba con `curl --version`— la alternativa es
`--config` con líneas `header = "..."`, que funciona desde mucho antes.

### 2.5 Los permisos importan tanto como el archivo

Un archivo de credenciales legible por todo el mundo es el mismo problema con un
paso más. Y hay una trampa: crear el archivo y luego darle permisos deja una
ventana en la que es legible.

```bash
# ❌ Entre las dos lineas, el archivo existe con los permisos por defecto
#    (normalmente 644) y ya tiene el secreto dentro.
printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" > cred.conf
chmod 600 cred.conf
```

```bash
# ✅ umask 077 hace que nazca ya con 600. Los parentesis limitan el cambio de
#    umask a esa subshell, para no afectar al resto del script.
(umask 077; printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" > cred.conf)
```

La ventana del primer caso dura milisegundos. En una máquina compartida o en un
runner de CI con varios trabajos, milisegundos es tiempo de sobra.

`--netrc` es el único de los tres que **comprueba los permisos él mismo** en
algunas plataformas. Con `--config` y con `-H @archivo` la comprobación la haces
tú, y es un `case` de cuatro líneas —`stat -c '%a'` en GNU, `stat -f '%Lp'` en
macOS— que **falla**, no que avisa y sigue: un aviso en stderr no lo lee nadie.
La versión completa está en la [práctica 02, paso 8](../2-practicas/02-sacar-la-credencial-de-la-linea.md).

---

## 3. Cómo se usa

### 3.1 El patrón completo, en un script

```bash
#!/usr/bin/env bash
set -euo pipefail

# El token entra por el entorno, que es lo normal en CI. Aqui todavia no es un
# problema: el peligro empieza si lo pasamos como argumento a curl.
: "${API_TOKEN:?falta API_TOKEN en el entorno}"

# Archivo temporal, con permisos desde el nacimiento, y borrado pase lo que
# pase: el trap salta tambien si el script muere a mitad.
config=$(mktemp)
trap 'rm -f "$config"' EXIT
(umask 077; printf 'header = "Authorization: Bearer %s"\n' "$API_TOKEN" > "$config")

# --fail-with-body: sale distinto de 0 ante 4xx/5xx y conserva el cuerpo, donde
# la API explica el motivo. --max-time: sin el, un servidor colgado cuelga el
# cron. --retry: solo reintenta errores transitorios.
curl --config "$config" \
  --fail-with-body --max-time 30 --retry 3 --retry-delay 2 \
  -sS "${BASE_URL}/v1/datos"
```

### 3.2 Sin tocar el disco

`--config -` lee de la entrada estándar, así que el secreto no llega a escribirse
en ningún sitio. Con un *here document* no hay tampoco ningún proceso con el
valor en su `argv`:

```bash
curl -s --config - http://localhost:8080/bearer <<EOF | jq -c .
header = "Authorization: Bearer ${API_TOKEN}"
EOF
```

### 3.3 Dónde vive el archivo

En este bootcamp, `~/.bc-curl`. Tres reglas:

1. **En `$HOME`, nunca dentro del repositorio.** Un `.gitignore` protege del
   commit distraído, no del `git add -f` ni de un `tar` del directorio
2. **`chmod 600`**, comprobado por el script antes de leerlo
3. **Una credencial por línea**, `CLAVE=valor`, y se lee con `grep`, no con
   `source`: `source` ejecutaría cualquier cosa que hubiera dentro

```bash
# Asi queda, y asi se comprueba.
ls -l ~/.bc-curl
# -rw------- 1 tu tu 42 ago 23 11:04 /home/tu/.bc-curl
```

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `-H "Authorization: Bearer $TOKEN"` | El shell expande antes de lanzar curl: el valor acaba en el argv | `--config`, `-H @archivo` o `--netrc-file` |
| `https://usuario:password@host/ruta` | Va al log del proxy, al `Referer` y al historial | `--netrc-file`, o `-u usuario` interactivo |
| `echo "$TOKEN" > f` y luego `chmod 600 f` | Ventana en la que el archivo es legible por todos | `(umask 077; echo "$TOKEN" > f)` |
| `source ~/.bc-curl` para cargar credenciales | Ejecuta lo que haya dentro. Un archivo de datos no es un script | Leerlo con `grep -E '^[A-Z_]+='` y asignar a mano |
| El archivo de credenciales dentro del repositorio | Un `git add -f`, un `tar`, un backup, y ya está fuera | En `$HOME`, con permisos 600 |
| Avisar de los permisos malos y continuar | El aviso no lo lee nadie y la credencial sigue expuesta | Fallar con un mensaje que diga el `chmod` exacto |
| Redactar el token «solo a medias» en un log | Los primeros caracteres son caracteres que ya no hay que adivinar | Un texto fijo, `<REDACTADO>`, sin ninguna parte del valor |

---

## 5. Trucos

```bash
# La prueba de que tu script no filtra: lanzalo contra /delay/3 en segundo
# plano y mira el argv de los procesos curl mientras corre.
AUTH_MODE=bearer API_TOKEN=zzsecretozz ./api-toolkit.sh get /delay/3 >/dev/null &
sleep 1; ps -eo args | grep '^curl ' | grep -c zzsecretozz
# 0
wait
```

```bash
# Un archivo de credenciales que nace con los permisos correctos.
(umask 077; printf 'API_TOKEN=%s\n' "$nuevo_token" > ~/.bc-curl)
ls -l ~/.bc-curl
# -rw------- 1 tu tu 45 ago 23 11:04 /home/tu/.bc-curl
```

> [!TIP]
> Si has escrito una credencial en la terminal, bórrala del historial
> (`history -d`) **y rótala igualmente**. Lo que estuvo en el historial hay que
> darlo por quemado: no sabes qué backup se lo llevó.

---

## 📚 Recursos Adicionales

- [manpage de curl — `-K, --config`](https://curl.se/docs/manpage.html#-K) — el formato del archivo de opciones, con sus reglas de comillas
- [manpage de curl — `--netrc-file`](https://curl.se/docs/manpage.html#--netrc-file) — y las diferencias con `--netrc` y `--netrc-optional`
- [everything.curl.dev — Config file](https://everything.curl.dev/cmdline/configfile.html) — incluido `--config -` para leer de stdin
- [OWASP — Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html) — por qué el entorno tampoco es el sitio ideal, y qué viene después

---

## ✅ Checklist de Verificación

- [ ] He visto con `ps` un token en el argv de curl, y luego el mismo comando sin él
- [ ] Sé por qué una variable de entorno **no** evita que el valor llegue al argv
- [ ] He usado `--config` con `header = "..."` y `--netrc-file` contra el laboratorio
- [ ] Sé desde qué versión existe `-H @archivo` y cuál es la alternativa si no la tengo
- [ ] Mi `~/.bc-curl` tiene permisos 600 y está fuera del repositorio
- [ ] Sé por qué `(umask 077; ...)` es mejor que `chmod 600` después

---

| Anterior | Siguiente |
|---|---|
| [02 — Basic Auth](02-basic-auth.md) | [04 — API keys](04-api-keys.md) |
