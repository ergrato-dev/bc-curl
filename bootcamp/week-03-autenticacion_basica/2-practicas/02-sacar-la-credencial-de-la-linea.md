# Práctica 02 — Sacar la credencial de la línea

> **Duración**: 50 min · **Entregables**: `prueba-ps.md`, `cabeceras.txt`, `auth.conf`

Esta es la práctica que justifica la semana. Vas a **ver** un token en el argv de
un proceso, y luego vas a hacer que desaparezca sin que el comando deje de
funcionar. Al final tendrás la prueba escrita, que es lo que se enseña en una
revisión de código cuando alguien dice «pero si va por HTTPS».

**Antes de empezar**:

```bash
./scripts/start.sh
cd ~/bc-curl-trabajo/semana-03
curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 http://localhost:8080/get
# 200
```

---

## Paso 1: Ver la fuga

**Por qué**: la creencia de que una variable de entorno protege el secreto es
casi universal y es falsa. El shell **expande la variable antes** de lanzar
curl, así que lo que llega al proceso es el valor. Y el argv de un proceso lo
lee cualquier usuario de la máquina, sin privilegios.

**Comando**:

```bash
# El token en una variable, como en cualquier script del mundo.
export API_TOKEN=zzsecretozz

# /delay/3 tarda tres segundos: da tiempo a mirar el proceso mientras corre.
# El & lo manda a segundo plano.
curl -s -H "Authorization: Bearer $API_TOKEN" http://localhost:8080/delay/3 >/dev/null &

# Un segundo despues, miramos el argv de los procesos curl.
sleep 1; ps -eo args | grep '^curl ' | grep -c zzsecretozz
wait
# 1
```

**Verifica**:

```bash
# Y ahora el argv completo, para verlo con tus ojos.
curl -s -H "Authorization: Bearer $API_TOKEN" http://localhost:8080/delay/3 >/dev/null &
sleep 1; ps -eo args | grep '^curl ' | grep zzsecretozz
wait
# curl -s -H Authorization: Bearer zzsecretozz http://localhost:8080/delay/3
```

Ese `1`, y esa línea, son el problema entero de esta práctica.

---

## Paso 2: Meter el secreto en un archivo de `--config`

**Por qué**: `--config` le pasa a curl una **ruta**, no un valor. Las opciones se
leen del archivo, así que el secreto nunca entra en el argv. Funciona con
cualquier esquema —Basic, Bearer, API key— y está en curl desde siempre.

**Comando**:

```bash
# El formato: una opcion larga por linea, SIN los dos guiones, con el valor
# entre comillas. umask 077 hace que el archivo nazca ya con permisos 600.
(umask 077; printf 'header = "Authorization: Bearer %s"\n' "$API_TOKEN" > auth.conf)

ls -l auth.conf
# -rw------- 1 tu tu 45 ago 23 11:37 auth.conf
```

```bash
# Y funciona igual que el -H de antes.
curl -s --config auth.conf http://localhost:8080/bearer | jq -c .
# {"authenticated":true,"token":"zzsecretozz"}
```

**Verifica**:

```bash
# La misma prueba del paso 1. Ahora tiene que dar 0.
curl -s --config auth.conf http://localhost:8080/delay/3 >/dev/null &
sleep 1; ps -eo args | grep '^curl ' | grep -c zzsecretozz || true
wait
# 0
```

---

## Paso 3: Guardar la prueba

**Por qué**: «confía en mí, no se filtra» no convence a nadie en una revisión de
código. Dos salidas de `ps`, una al lado de la otra, sí.

**Comando**:

```bash
{
  echo "# El token en el argv, y sin el"
  echo
  echo '## Con -H "Authorization: Bearer $API_TOKEN"'
  echo
  echo '```'
  curl -s -H "Authorization: Bearer $API_TOKEN" http://localhost:8080/delay/3 >/dev/null &
  sleep 1; ps -eo args | grep '^curl ' | grep zzsecretozz
  wait
  echo '```'
  echo
  echo '## Con --config auth.conf'
  echo
  echo '```'
  curl -s --config auth.conf http://localhost:8080/delay/3 >/dev/null &
  sleep 1; ps -eo args | grep '^curl '
  wait
  echo '```'
} > prueba-ps.md
cat prueba-ps.md
```

**Verifica**:

```bash
# El archivo tiene que contener el token UNA vez (en el caso malo) y ninguna
# mas. Si sale 2, algo se te ha colado.
grep -c zzsecretozz prueba-ps.md
# 1
```

---

## Paso 4: `--netrc-file`, el clásico de Basic Auth

**Por qué**: `.netrc` ata la credencial a **una máquina concreta**. Si una
redirección lleva la petición a otro host, curl no manda esa credencial. Es una
protección que `--config` no te da.

**Comando**:

```bash
# Formato: machine <host> login <usuario> password <password>. Todo en una
# linea, y el host sin puerto ni esquema.
(umask 077; printf 'machine localhost login user password password\n' > lab.netrc)

curl -s --netrc-file lab.netrc http://localhost:8080/basic-auth/user/password | jq -c .
# {"authenticated":true,"user":"user","authorized":true}
```

**Verifica**:

```bash
# Que la password no esta en el argv, igual que antes.
curl -s --netrc-file lab.netrc http://localhost:8080/delay/3 >/dev/null &
sleep 1; ps -eo args | grep '^curl ' | grep -c 'password password' || true
wait
# 0
```

```bash
# Y los permisos, que aqui tambien importan.
stat -c '%a' lab.netrc 2>/dev/null || stat -f '%Lp' lab.netrc
# 600
```

---

## Paso 5: `-H @archivo` para una API key

**Por qué**: es la forma más directa cuando lo único que necesitas es un header,
y el archivo se reutiliza entre varias llamadas. Existe desde **curl 7.55**; si
tu versión es anterior, la alternativa es `--config` con una línea `header =`.

**Comando**:

```bash
# Un header por linea. Nada de comillas: el valor es todo lo que hay tras los
# dos puntos.
(umask 077; printf 'X-API-Key: clave-de-laboratorio\n' > cabeceras.txt)

# Ojo con la ruta: el shell NO expande la tilde detras de la @. Usa una ruta
# relativa, o "$HOME/...".
curl -s -H @cabeceras.txt http://localhost:8080/headers | jq -c '.headers["X-Api-Key"]'
# ["clave-de-laboratorio"]
```

**Verifica**:

```bash
# La clave tiene que llegar exactamente igual, sin comillas ni saltos.
curl -s -H @cabeceras.txt http://localhost:8080/headers \
  | jq -r '.headers["X-Api-Key"][0]'
# clave-de-laboratorio
```

```bash
# Y comprobar tu version, porque este flag no es universal.
curl --version | head -1 | awk '{print $2}'
# 7.81.0
```

---

## Paso 6: La comprobación que hace el autograding

**Por qué**: la comprobación `toolkit-token-no-en-la-linea-de-comandos` del
`checks.json` hace exactamente esto contra tu `api-toolkit.sh`. Si entiendes el
comando, sabrás por qué falla cuando falle.

**Comando**:

```bash
# Lanza la peticion en segundo plano, espera un segundo, cuenta las apariciones
# del token en el argv de los procesos curl, y espera a que termine.
API_TOKEN=zzsecretozz
curl -s --config auth.conf http://localhost:8080/delay/3 >/dev/null 2>&1 &
sleep 1
n=$(ps -eo args | grep '^curl ' | grep -c zzsecretozz || true)
wait
echo "$n"
# 0
```

**Verifica**:

```bash
# El mismo comando, pero con la version que SI filtra: tiene que dar 1.
curl -s -H "Authorization: Bearer $API_TOKEN" http://localhost:8080/delay/3 >/dev/null 2>&1 &
sleep 1
n=$(ps -eo args | grep '^curl ' | grep -c zzsecretozz || true)
wait
echo "$n"
# 1
```

Si tu proyecto da `1` en esta comprobación, el secreto está entrando por
`ARGS_CURL` en vez de por el archivo de `--config`.

---

## Paso 7: Los permisos, y la ventana del `chmod`

**Por qué**: crear el archivo y luego darle permisos deja un instante en el que
el secreto está en disco y es legible por todos. En una máquina compartida o en
un runner de CI con trabajos en paralelo, ese instante basta.

**Comando**:

```bash
# ❌ La forma con ventana: entre las dos lineas el archivo existe con 644.
printf 'header = "Authorization: Bearer %s"\n' "$API_TOKEN" > mal.conf
chmod 600 mal.conf
```

```bash
# ✅ La forma sin ventana: nace con 600. Los parentesis limitan el cambio de
#    umask a esa subshell, para no afectar al resto del script.
(umask 077; printf 'header = "Authorization: Bearer %s"\n' "$API_TOKEN" > bien.conf)
```

**Verifica**:

Los dos acaban en `600`: la diferencia no se ve al final, está en el medio. Para
verla hay que mirar con qué permisos **nace** cada uno, sin el `chmod` posterior:

```bash
printf 'x\n' > recien-nacido-mal.conf
(umask 077; printf 'x\n' > recien-nacido-bien.conf)
stat -c '%n %a' recien-nacido-*.conf 2>/dev/null \
  || stat -f '%N %Lp' recien-nacido-*.conf
# recien-nacido-bien.conf 600
# recien-nacido-mal.conf 644
rm -f recien-nacido-*.conf mal.conf
```

---

## Paso 8: Comprobar los permisos antes de leer

**Por qué**: tu proyecto tiene que **negarse** a usar un archivo de credenciales
mal protegido, no avisar y seguir. Un aviso en stderr no lo lee nadie, y la
credencial sigue expuesta. Es la comprobación
`toolkit-rechaza-credenciales-legibles` del `checks.json`.

**Comando**:

```bash
# La comprobacion, portable entre GNU (stat -c) y BSD/macOS (stat -f).
comprobar_permisos() {
  local archivo="$1" permisos
  permisos=$(stat -c '%a' "$archivo" 2>/dev/null || stat -f '%Lp' "$archivo")
  case "$permisos" in
    600|400) return 0 ;;
    *) echo "error: $archivo tiene permisos $permisos; usa: chmod 600 $archivo" >&2
       return 1 ;;
  esac
}
```

**Verifica**:

```bash
# Con permisos buenos, pasa en silencio y devuelve 0.
comprobar_permisos auth.conf; echo "salida: $?"
# salida: 0
```

```bash
# Con permisos abiertos, falla y dice exactamente como arreglarlo.
cp auth.conf abierto.conf && chmod 644 abierto.conf
comprobar_permisos abierto.conf; echo "salida: $?"
# error: abierto.conf tiene permisos 644; usa: chmod 600 abierto.conf
# salida: 1
rm -f abierto.conf
```

---

## Paso 9: Limpiar

**Por qué**: un archivo de credenciales que sobrevive a la sesión es un archivo
de credenciales olvidado. En un script esto lo hace un `trap`, que salta aunque
el script muera a mitad.

**Comando**:

```bash
# El patron que usa el proyecto de esta semana.
config=$(mktemp); trap 'rm -f "$config"' EXIT
```

**Verifica**:

```bash
# Deja auth.conf y cabeceras.txt: son entregables. Borra el resto.
rm -f bien.conf lab.netrc
unset API_TOKEN
ls
# auth.conf  authorization-a-mano.txt  cabeceras.txt  prueba-ps.md  reto.md
```

---

## ✅ Resultado

- [ ] He visto un token en el argv de un proceso curl con `ps`
- [ ] `prueba-ps.md` tiene las dos salidas y el token aparece **una** sola vez
- [ ] `auth.conf` funciona y tiene permisos `600`
- [ ] `cabeceras.txt` manda la API key por header y tiene permisos `600`
- [ ] He usado `--netrc-file` contra el endpoint de Basic Auth
- [ ] Sé por qué `(umask 077; ...)` es distinto de `chmod 600` después
- [ ] Tengo una función que **falla** ante permisos abiertos, no que avisa

```bash
./scripts/verificar-semana.sh 03
```

Esta práctica es la base de `toolkit-token-no-en-la-linea-de-comandos` y de
`toolkit-rechaza-credenciales-legibles`.

---

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| El `grep -c` del paso 1 da `0` | La petición ya terminó antes del `ps` | Sube el `sleep` a 2, o usa `/delay/5` |
| El `grep -c` da `2` en vez de `1` | El propio comando de prueba lleva el token en su línea | Filtra solo procesos curl: `grep '^curl '` |
| `--config` no aplica nada | Formato incorrecto: sobran los dos guiones o faltan las comillas | `header = "Authorization: Bearer x"`, sin `--` delante |
| `curl: option -H: requires parameter` con `@` | La ruta del archivo no existe | Ruta relativa desde donde estás, o `"@$HOME/archivo"` |
| `-H @~/archivo` manda un header vacío | El shell no expande `~` detrás de la `@` | `"@$HOME/archivo"` |
| `--netrc-file` no autentica | El `machine` no coincide con el host de la URL | Para `http://localhost:8080` el machine es `localhost`, sin puerto |
| `stat: illegal option -- c` | Estás en macOS | Es `stat -f '%Lp'`. Los comandos de aquí ya prueban las dos |
| `wait` se queda colgado | Hay otro trabajo en segundo plano de antes | `jobs` para verlos, `wait %1` para esperar solo al último |
| El token aparece en `prueba-ps.md` dos veces | Guardaste también la salida del caso bueno con el `grep zzsecretozz` | En el caso bueno se lista `grep '^curl '` sin filtrar por el token |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 01 — Basic Auth y el reto](01-basic-auth-y-el-reto.md) | [Práctica 03 — Bearer y el JWT por dentro](03-bearer-y-el-jwt-por-dentro.md) |
