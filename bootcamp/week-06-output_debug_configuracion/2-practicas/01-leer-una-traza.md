# Práctica 01 — Leer una traza

> **Duración**: 50 min · **Entregables**: `salida.md`, `traza.md`, `traza-compartible.txt`

Vas a separar lo que curl escribe en cada flujo, leer una traza sana línea a
línea, provocar cinco fallos distintos y señalar en cada traza la línea que lo
delata. Después tacharás una traza con credencial y cookie hasta que se pueda
pegar en un ticket, y bajarás un nivel con `--trace-ascii` para ver el cuerpo
que `-v` no enseña.

**Antes de empezar**, desde la raíz del repositorio:

```bash
./scripts/start.sh
export CA="$PWD/docs/lab-ca.pem"
mkdir -p ~/bc-curl-trabajo/semana-06/p1 && cd ~/bc-curl-trabajo/semana-06/p1
```

> [!NOTE]
> Esta práctica redirige stderr a archivos en vez de usar `2>&1 >/dev/null`.
> En zsh esa construcción duplica stdout y el cuerpo vuelve a aparecer
> (teoría 01, trucos).

---

## Paso 1: Qué va a cada flujo

**Por qué**: antes de leer una traza hay que saber dónde está. Si la mezclas
con el cuerpo, ni la traza se lee ni el cuerpo se procesa.

**Comando**:

```bash
# Cuerpo a un archivo, todo lo demas a otro
curl -sS -v -o cuerpo.json http://localhost:8080/get 2> traza.txt
# El medidor: aparece solo con stdout redirigido
curl http://localhost:8080/get > /dev/null 2> medidor.txt
# Sin -S, el error desaparece
curl -s http://127.0.0.1:9/ 2> error-s.txt;  echo "s: $?"
curl -sS http://127.0.0.1:9/ 2> error-sS.txt; echo "sS: $?"
```

**Verifica**:

```bash
jq -r .url cuerpo.json
# http://localhost:8080/get
grep -c '^[*<>]' traza.txt
# 16          ← el numero exacto cambia con la version; lo importante: no es 0
head -1 medidor.txt
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
wc -c < error-s.txt; cat error-sS.txt
# 0
# curl: (7) Failed to connect to 127.0.0.1 port 9 after 0 ms: Connection refused
```

Apunta en `salida.md` una tabla con cuatro filas (`-s`, `-sS`, `-o archivo`,
`-v`) y dos columnas (qué cambia en stdout, qué cambia en stderr).

---

## Paso 2: Headers y cuerpo por separado

**Por qué**: un script que necesita un header (un `ETag`, un `Location`, el
`Retry-After` de la Semana 07) no puede leerlo de un `-i` mezclado con el
cuerpo.

**Comando**:

```bash
curl -sS -D cabeceras.txt -o cuerpo2.json \
  'http://localhost:8080/response-headers?ETag=abc123'
```

**Verifica**:

```bash
head -1 cabeceras.txt
# HTTP/1.1 200 OK
grep -i '^etag' cabeceras.txt | cat -A
# Etag: abc123^M$          ← el \r al final, y el nombre en otra capitalizacion
tr -d '\r' < cabeceras.txt | awk -F': ' 'tolower($1) == "etag" { print $2 }'
# abc123
jq -r .ETag cuerpo2.json
# abc123                   ← el cuerpo, limpio, en su archivo
```

Añade a `salida.md` por qué `grep '^ETag'` no encuentra nada y qué es el `^M`.

---

## Paso 3: Una traza sana, línea a línea

**Por qué**: para ver qué falta en una traza rota hay que conocer de memoria
una completa.

**Comando**:

```bash
curl -sS -v -o /dev/null http://localhost:8080/get 2> sana.txt
cat sana.txt
```

**Verifica**:

```bash
grep -c '^\*' sana.txt; grep -c '^>' sana.txt; grep -c '^<' sana.txt
# 4     ← lo que curl hizo por su cuenta
# 5     ← lo que envio: linea de peticion, 3 headers y la linea vacia
# 7     ← lo que recibio: linea de estado, 5 headers y la linea vacia
grep -E '^\* Connected|^> GET|^< HTTP' sana.txt
# * Connected to localhost (127.0.0.1) port 8080 (#0)
# > GET /get HTTP/1.1
# < HTTP/1.1 200 OK
```

Copia la traza en `traza.md` y anota al lado de cada línea quién la escribió:
curl, tú o el servidor.

---

## Paso 4: Tres fallos antes de HTTP

**Por qué**: DNS, TCP y TLS fallan antes de que exista una petición HTTP. La
traza se corta en una fase distinta en cada caso, y ese corte es el
diagnóstico.

**Comando**:

```bash
curl -sS -v -o /dev/null http://no-existe.invalid/ 2> f-dns.txt
curl -sS -v -o /dev/null http://127.0.0.1:9/ 2> f-tcp.txt
curl -sS -v -o /dev/null https://localhost:8443/get 2> f-tls.txt
```

**Verifica** con las tres preguntas de la teoría 05:

```bash
for f in f-dns.txt f-tcp.txt f-tls.txt; do
  printf '%-10s conectado=%s envio=%s respuesta=%s | ' "$f" \
    "$(grep -c '^\* Connected' "$f")" "$(grep -c '^>' "$f")" "$(grep -c '^< HTTP' "$f")"
  grep -E '^\* (Could not|connect to|SSL certificate problem)' "$f"
done
# f-dns.txt  conectado=0 envio=0 respuesta=0 | * Could not resolve host: no-existe.invalid
# f-tcp.txt  conectado=0 envio=0 respuesta=0 | * connect to 127.0.0.1 port 9 failed: Connection refused
# f-tls.txt  conectado=1 envio=0 respuesta=0 | * SSL certificate problem: unable to get local issuer certificate
```

El de TLS sí conectó y aun así no envió nada: falló en medio. Repite el
tercero con `--cacert "$CA"` y comprueba que `envio` pasa a 5.

Apunta en `traza.md` la línea que delata cada fallo y el código de salida que
le corresponde (6, 7, 60).

---

## Paso 5: Dos fallos después de HTTP

**Por qué**: un 401 y un bucle de redirects tienen la traza completa: la
conversación HTTP sucedió. El fallo está en lo que se dijo, no en la red.

**Comando**:

```bash
# Password incorrecta
curl -sS -v -o /dev/null -u user:mal \
  http://localhost:8080/basic-auth/user/passwd 2> f-401.txt
# Cinco saltos con un maximo de dos
curl -sS -v -L --max-redirs 2 -o /dev/null \
  http://localhost:8080/redirect/5 2> f-bucle.txt; echo "salida: $?"
```

**Verifica**:

```bash
grep -E '^> Authorization|^< HTTP' f-401.txt
# > Authorization: Basic dXNlcjptYWw=
# < HTTP/1.1 401 Unauthorized
grep -c '^> GET' f-bucle.txt; tail -2 f-bucle.txt
# 3
# * Maximum (2) redirects followed
# curl: (47) Maximum (2) redirects followed
```

En el 401 la credencial **sí** viajó: el servidor la rechazó. Es justo lo que
hay que saber antes de culpar al script. Decodifícala:

```bash
bash -c 'echo dXNlcjptYWw= | base64 -d'; echo
# user:mal
```

(En zsh, `=` al principio de una palabra se expande; por eso va dentro de
`bash -c`, o entre comillas.)

Completa `traza.md` con estos dos fallos.

---

## Paso 6: Una traza que se pueda compartir

**Por qué**: la traza del paso 5 lleva la password en base64, que se
decodifica en un segundo. Las cookies de sesión valen lo mismo. Antes de
pegarla en ningún sitio, se tacha.

**Comando**:

```bash
# Una traza con las tres cosas: Authorization, cookie recibida y cookie enviada
export API_TOKEN=token-de-prueba
printf 'header = "Authorization: Bearer %s"\n' "$API_TOKEN" \
  | curl -q -sS -v -K - -L -b '' -o /dev/null \
      'http://localhost:8080/cookies/set?sesion=valor-secreto' 2> con-secretos.txt

tachar() {
  sed -E 's/^([<>] (Authorization|Proxy-Authorization|Cookie|Set-Cookie|X-API-Key):).*/\1 <REDACTADO>/I;
          s/^(\* (Added|Replaced) cookie).*/\1 <REDACTADO>/'
}
tachar < con-secretos.txt > traza-compartible.txt
```

**Verifica**:

```bash
grep -c -E 'token-de-prueba|valor-secreto' con-secretos.txt
# 6            ← el token en los dos saltos, Set-Cookie, Added cookie, Cookie
#                 enviada al segundo salto y la linea de peticion
grep -E 'token-de-prueba|valor-secreto' traza-compartible.txt
# > GET /cookies/set?sesion=valor-secreto HTTP/1.1
```

Queda una: la de la línea de petición. La cookie iba en la **query string**, y
esa línea no se tacha porque es la que dice qué endpoint se pidió. Moraleja:
ningún secreto viaja en la URL. Para este ejercicio, táchala a mano con
`sed -i 's/valor-secreto/<REDACTADO>/' traza-compartible.txt` y vuelve a
comprobar:

```bash
grep -c -E 'token-de-prueba|valor-secreto' traza-compartible.txt
# 0
grep -c '<REDACTADO>' traza-compartible.txt
# 6            ← cada linea tachada sigue ahi, con su nombre
rm -f con-secretos.txt
```

`con-secretos.txt` se borra: no tiene sentido guardar la versión sin tachar.

---

## Paso 7: El cuerpo que `-v` no enseña

**Por qué**: `-v` resume el cuerpo en `} [7 bytes data]`. Cuando la API dice
"JSON inválido", hay que ver esos siete bytes.

**Comando**:

```bash
# El error clasico: -d sin Content-Type
curl -s --trace-ascii envio.txt -o /dev/null -d '{"a":1}' http://localhost:8080/post
```

**Verifica**:

```bash
grep '^0[0-9a-f]*: Content-Type' envio.txt
# 0064: Content-Type: application/x-www-form-urlencoded   ← el que enviaste
# 0000: Content-Type: application/json; charset=utf-8     ← el de la respuesta
grep -A1 'Send data' envio.txt
# => Send data, 7 bytes (0x7)
# 0000: {"a":1}
```

El cuerpo es JSON, el `Content-Type` dice formulario. Repite con
`-H 'Content-Type: application/json'` y comprueba que la línea cambia.

Ahora un archivo con final de línea de Windows, que solo se ve en
hexadecimal:

```bash
printf '{"a":1}\r\n' > windows.json
curl -s --trace - -o /dev/null -H 'Content-Type: application/json' \
  --data-binary @windows.json http://localhost:8080/post | grep -A1 'Send data'
# => Send data, 9 bytes (0x9)
# 0000: 7b 22 61 22 3a 31 7d 0d 0a                      {"a":1}..
```

`0d 0a` al final: dos bytes que el servidor puede rechazar y que en
`--trace-ascii` serían dos puntos indistinguibles.

---

## Paso 8: La fase lenta, con reloj

**Por qué**: cuando no sabes qué medir, la traza con hora te dice dónde mirar.

**Comando**:

```bash
curl -sS -v --trace-time -o /dev/null http://localhost:8080/delay/2 2> lenta.txt
grep -E '^[0-9:.]+ (> GET|< HTTP)' lenta.txt
```

**Verifica**:

```bash
# Dos lineas: la hora en que envio y la hora en que recibio
grep -E '^[0-9:.]+ (> GET|< HTTP)' lenta.txt
# 19:43:10.710833 > GET /delay/2 HTTP/1.1
# 19:43:12.713769 < HTTP/1.1 200 OK         ← dos segundos despues
```

Dos segundos entre `>` y `<`: el servidor. Ni DNS, ni conexión, ni TLS.
Apunta en `traza.md` la diferencia que mediste.

---

## ✅ Resultado

- [ ] `salida.md` explica qué cambia en cada flujo con `-s`, `-sS`, `-o` y `-v`, y cómo separar headers y cuerpo
- [ ] `traza.md` tiene la traza sana anotada y los cinco fallos con su línea y su código
- [ ] `traza-compartible.txt` no contiene ni el token ni la cookie
- [ ] He visto el cuerpo de un POST con `--trace-ascii` y un `\r\n` con `--trace`
- [ ] He encontrado la fase lenta con `--trace-time`

```bash
./scripts/verificar-semana.sh 06
```

Esta práctica prepara `redactar_traza` (TODO 6) y la mitad de `lanzar_curl`
(TODO 1) del proyecto.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| En el paso 1 `medidor.txt` está vacío | Añadiste `-s`, o tu curl tiene un `.curlrc` con `silent` | Copia el comando tal cual; prueba con `curl -q` |
| El paso 4 da `conectado=1` en el de DNS | Tu resolver devuelve una IP para cualquier nombre (algunos ISP lo hacen) | Usa un dominio `.invalid`, que ningún resolver honesto responde |
| `f-tls.txt` termina en un 35, no en un 60 | El frontal TLS no está arriba | `./scripts/start.sh` y `curl --cacert "$CA" https://localhost:8443/get` |
| `sed: -e expression #1: unknown option to s'` | Estás en macOS: el `I` es de GNU sed | `brew install gnu-sed` y usa `gsed`, o la versión con `awk` del proyecto |
| El paso 6 cuenta otro número de apariciones | Tu curl escribe las líneas de cookies de otra forma | Lo que importa es el 0 final |
| `--trace-time` no pone hora a las líneas | Lo pusiste antes de `-v` en un curl muy antiguo | Ponlo detrás de `-v` |

---

| Anterior | Siguiente |
|---|---|
| [Teoría 08 — Configuración por tarea](../1-teoria/08-configuracion-por-tarea.md) | [Práctica 02 — Medir con `--write-out`](02-medir-con-write-out.md) |
