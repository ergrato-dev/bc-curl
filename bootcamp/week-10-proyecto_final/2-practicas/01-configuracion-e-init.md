# Práctica 01 — Configuración e `init`

> **Duración**: 50 min · **Entregables**: `configuracion.md`

Vas a hacer que el toolkit lea su configuración de `~/.bc-curl` sin
ejecutarla, con el entorno por encima (TODO 1), y a escribir el `init` que
crea ese archivo sin pisar nada y sin una ventana con permisos abiertos
(TODO 2). Todo se hace en un HOME de usar y tirar: tu `~/.bc-curl` real no
se toca en ningún paso.

**Antes de empezar**, desde la raíz del repositorio:

```bash
./scripts/start.sh
export TK="$PWD/bootcamp/week-10-proyecto_final/3-proyecto/starter/api-toolkit.sh"
mkdir -p ~/bc-curl-trabajo/semana-10/p1 && cd ~/bc-curl-trabajo/semana-10/p1
bash    # los pasos estan escritos para bash; si tu terminal es zsh, abre un bash
HP="$(mktemp -d)"     # el HOME de pruebas de toda la practica
```

El starter es la capa 9 resuelta con los huecos de la capa 10, y ya trae la
versión `1.0.0`. Si tu capa 9 tiene arreglos propios, cópialos encima antes
de seguir.

---

## Paso 1: El archivo que nadie lee

**Por qué**: hasta la capa 9, `~/.bc-curl` solo daba credenciales, y
`BASE_URL` recibía su valor por defecto en la primera línea del script. Antes
de arreglarlo, compruébalo (teoría 02, apartado 2.1).

**Comando**:

```bash
( umask 077 && printf 'BASE_URL=http://localhost:8080/anything\n' > "$HP/.bc-curl" )
HOME="$HP" "$TK" --dry-run get /x | grep -o 'http://[^ ]*'
```

**Verifica**:

```bash
# http://localhost:8080/x
```

El archivo dice `/anything` y el toolkit no lo ve. `HOME="$HP"` delante de la
orden hace que el toolkit busque `~/.bc-curl` en el HOME de pruebas. Apunta
en `configuracion.md` lo que salió y lo que esperabas.

---

## Paso 2: Por qué no `source`

**Por qué**: la forma corta de leer un archivo `CLAVE=valor` es `source`. Es
también la forma de ejecutar lo que contenga (teoría 02, apartado 2.2).

**Comando**:

```bash
printf 'BASE_URL=http://ejemplo.invalid\nAPI_KEY=$(touch ejecutado)\n' > peligroso.conf
cat peligroso.conf
( source ./peligroso.conf; echo "BASE_URL=$BASE_URL" )
ls ejecutado && rm ejecutado
```

**Verifica**:

```bash
# BASE_URL=http://ejemplo.invalid
# API_KEY=$(touch ejecutado)
# BASE_URL=http://ejemplo.invalid
# ejecutado
```

`source` leyó la URL, y de paso ejecutó `touch`. Con un `curl ... | bash` en
lugar de `touch`, habría descargado y ejecutado un programa. Los paréntesis
lo encierran en un subshell para que no toque tu shell. Copia la salida.

---

## Paso 3: Leer línea a línea (TODO 1)

**Por qué**: un archivo de configuración es datos. Se lee con `while read`,
se aceptan solo las claves de `CLAVES_ARCHIVO`, y cada una solo si el
entorno no le dio valor (teoría 02, apartados 2.2 a 2.4).

**Comando**: abre el starter en `cargar_configuracion` y sustituye el TODO 1
por el bucle:

```bash
    local clave valor
    while IFS='=' read -r clave valor; do
      case " $CLAVES_ARCHIVO " in
        *" $clave "*) if [ -z "${!clave}" ]; then printf -v "$clave" '%s' "$valor"; fi ;;
        *) ;;
      esac
    done < <(grep -E '^[A-Z_]+=' "$BC_CURL_FILE" || true)
```

Fíjate en que los valores por defecto (`BASE_URL="${BASE_URL:-http://...}"`)
están **debajo**, al final de la función: ya se ponen después de leer el
archivo. Y repite la orden del paso 1:

```bash
HOME="$HP" "$TK" --dry-run get /x | grep -o 'http://[^ ]*'
```

**Verifica**:

```bash
# http://localhost:8080/anything/x
```

Ahora sí. Si sale `http://localhost:8080/x`, el bucle no asigna: comprueba
que el `case` lleva los espacios a los dos lados.

---

## Paso 4: El entorno manda

**Por qué**: el archivo da el valor de siempre; el entorno lo cambia para una
orden. Y la regla de los 600 de la Semana 03 sigue en pie (teoría 02,
apartado 2.5).

**Comando**:

```bash
HOME="$HP" BASE_URL=http://otra.invalid "$TK" --dry-run get /x | grep -o 'http://[^ ]*'
chmod 644 "$HP/.bc-curl"
HOME="$HP" "$TK" --dry-run get /x; echo "salida: $?"
chmod 600 "$HP/.bc-curl"
```

**Verifica**:

```bash
# http://otra.invalid/x
# error: /tmp/tmp.tN8hnb4yOa/.bc-curl es legible por otros usuarios. Arreglalo con: chmod 600 "/tmp/tmp.tN8hnb4yOa/.bc-curl"
# salida: 1
```

El entorno ganó al archivo. Con 644, el toolkit se niega a leerlo aunque solo
tenga una URL: el archivo entero es secreto.

---

## Paso 5: El archivo no puede cambiar `PATH`

**Por qué**: leer sin ejecutar no basta si cualquier clave se convierte en
variable. Una línea `PATH=` cambiaría qué `curl` se ejecuta (teoría 02,
apartado 2.3).

**Comando**:

```bash
( umask 077 && cat peligroso.conf - > "$HP/.bc-curl" <<< 'PATH=/nada' )
HOME="$HP" "$TK" --dry-run get /x | grep -o 'http://[^ ]*'
ls ejecutado
```

**Verifica**:

```bash
# http://ejemplo.invalid/x
# ls: cannot access 'ejecutado': No such file or directory
```

`BASE_URL` se leyó, `$(touch ejecutado)` se quedó como texto en `API_KEY` y
`PATH=/nada` se ignoró: el toolkit siguió encontrando `curl`. Es el check
`config-no-ejecuta`. Copia la salida.

---

## Paso 6: `init` (TODO 2)

**Por qué**: escribir el archivo a mano es fácil de hacer mal: con 644, sin
una clave, con comillas. `init` lo escribe bien una vez (teoría 03).

**Comando**: primero, mira lo que hace el starter:

```bash
rm "$HP/.bc-curl"
HOME="$HP" "$TK" init; echo "salida: $?"
```

Después, sustituye el TODO 2 de `iniciar_configuracion`:

```bash
iniciar_configuracion() {
  [ ! -e "$BC_CURL_FILE" ] || error "$BC_CURL_FILE ya existe; no lo piso. Editalo, o borralo y repite"
  case "${BASE_URL}${AUTH_MODE}${API_CACERT}" in
    *$'\n'*|*$'\r'*) error "BASE_URL, AUTH_MODE y API_CACERT no pueden llevar saltos de linea" ;;
    *) ;;
  esac
  ( umask 077 && set -o noclobber && plantilla_configuracion > "$BC_CURL_FILE" ) \
    || error "no se pudo crear $BC_CURL_FILE"
  echo "configuracion creada en $BC_CURL_FILE (permisos 600)" >&2
}
```

Y pruébalo con un token en el entorno, como lo haría alguien con prisa:

```bash
HOME="$HP" BASE_URL=http://localhost:8080/anything API_TOKEN=valor-de-prueba "$TK" init
ls -l "$HP/.bc-curl" | cut -c1-10
cat "$HP/.bc-curl"
grep -c valor-de-prueba "$HP/.bc-curl"
```

**Verifica**:

```bash
# error: init todavia no esta hecho
# salida: 1
# configuracion creada en /tmp/tmp.tN8hnb4yOa/.bc-curl (permisos 600)
# -rw-------
# # Configuracion de api-toolkit, creada por api-toolkit init.
# # Permisos 600: aqui pueden ir los secretos. El entorno manda sobre este
# # archivo. Una clave por linea, CLAVE=valor, sin comillas.
# BASE_URL=http://localhost:8080/anything
# AUTH_MODE=none
# # API_CACERT=
# # API_TOKEN=
# # API_USER=
# # API_PASSWORD=
# # API_KEY=
# # OAUTH_CLIENT_ID=
# # OAUTH_CLIENT_SECRET=
# 0
```

Nació con 600, sin `chmod`. El token del entorno no llegó al archivo: el `0`
final lo cuenta.

---

## Paso 7: No pisar, ni en una carrera

**Por qué**: el segundo `init` no puede tocar el primero. Y la comprobación
con `[ -e ]` deja un hueco que solo cierra `noclobber` (teoría 03, apartado
2.1). Ocho `init` a la vez lo enseñan.

**Comando**:

```bash
HOME="$HP" "$TK" init; echo "salida: $?"

H2="$(mktemp -d)"
for r in $(seq 20); do
  rm -f "$H2/.bc-curl"
  for i in 1 2 3 4 5 6 7 8; do HOME="$H2" "$TK" init 2>> carrera.log & done
  wait
done
grep -c 'creada' carrera.log
grep -c 'no lo piso' carrera.log
grep -c 'no se pudo crear' carrera.log
```

**Verifica**:

```bash
# error: /tmp/tmp.tN8hnb4yOa/.bc-curl ya existe; no lo piso. Editalo, o borralo y repite
# salida: 1
# 20
# 121
# 19
```

Veinte rondas de ocho: exactamente **un** `creada` por ronda. Los dos números
de abajo cambian en cada ejecución: la mayoría se paran en `[ -e ]`, pero
algunos (19 aquí) llegaron a la escritura con el archivo recién creado por
otro, y `noclobber` los paró. Sin `noclobber`, esos 19 habrían pisado el
archivo. Copia los números.

---

## Paso 8: `--version` y la ayuda

**Por qué**: lo primero que se pregunta de una herramienta es qué versión es
y qué subcomandos tiene (teoría 06, apartados 2.1 y 2.2).

**Comando**:

```bash
"$TK" --version
"$TK" --help | grep -E '^  (init|--version)'
cd ~/bc-curl-trabajo/semana-10/p1 && rm -rf "$HP" "$H2" peligroso.conf
```

**Verifica**:

```bash
# api-toolkit 1.0.0
#   init                        Crea BC_CURL_FILE con BASE_URL y AUTH_MODE (los
#   --version      Imprime "api-toolkit VERSION" y termina
```

El starter ya trae los dos: `--version` sale de la misma constante `VERSION`
que el User-Agent.

---

## ✅ Resultado

- [ ] Sé por qué el archivo no se lee con `source`, y lo he visto ejecutar un `touch`
- [ ] Mi `cargar_configuracion` (TODO 1) lee el archivo con el entorno por encima
- [ ] El archivo no puede cambiar `PATH` ni ninguna clave fuera de la lista
- [ ] Mi `init` (TODO 2) crea el archivo con 600, sin secretos, y no pisa
- [ ] He visto a `noclobber` parar a los `init` que se colaron en la carrera

Desde la raíz del repositorio:

```bash
./scripts/verificar-semana.sh 10
```

Esta práctica cierra los TODOs 1 y 2: pasan `init-crea-600`, `init-no-pisa`,
`config-del-archivo`, `config-entorno-manda` y `config-no-ejecuta`.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| El paso 3 sigue dando `localhost:8080/x` | El `case` no casa: faltan los espacios, o `CLAVES_ARCHIVO` no tiene `BASE_URL` | `case " $CLAVES_ARCHIVO " in *" $clave "*)`, con espacio a los dos lados |
| `BASE_URL: unbound variable` | Una clave de la lista no está inicializada, y `${!clave}` falla con `set -u` | Las seis credenciales se inicializan al principio de la función; el resto, arriba del todo |
| El paso 5 crea `ejecutado` | Usas `source` o `eval` | El bucle con `read` y `printf -v` del paso 3 |
| `init` crea el archivo con 644 | La umask está fuera del subshell, o falta | `( umask 077 && set -o noclobber && ... > archivo )`, todo dentro de los paréntesis |
| El segundo `init` sale con 0 | Falta la comprobación, o el `>` no está bajo `noclobber` | `[ ! -e ]` antes, y `set -o noclobber` en el mismo subshell |
| `grep -c valor-de-prueba` da 1 | La plantilla escribe `API_TOKEN=${API_TOKEN}` | Las claves de los secretos van comentadas y vacías: `# API_TOKEN=` |
| El paso 1 dice `es legible por otros usuarios` | El archivo se creó fuera del subshell con `umask 077` | `( umask 077 && printf ... > "$HP/.bc-curl" )`, con los paréntesis |

---

| Anterior | Siguiente |
|---|---|
| [Teoría 08 — Integración continua](../1-teoria/08-integracion-continua.md) | [Práctica 02 — Tests con bats](02-tests-con-bats.md) |
