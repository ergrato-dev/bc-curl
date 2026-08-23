# Práctica 01 — Conocer tu curl

> ⏱️ 50 minutos · Laboratorio local · Entregable: `respuestas.md`

Antes de mandar una sola petición hay que saber qué binario tienes delante. No
es un trámite: la mitad de los "no me funciona el ejemplo" de este bootcamp son
un flag que tu versión todavía no trae. Al terminar esta práctica sabrás
exactamente qué habla tu curl, qué se le compiló dentro y qué te falta.

## 🎯 Qué vas a conseguir

- Leer la salida de `curl --version` entera, campo por campo
- Distinguir `Protocols:` de `Features:` y saber para qué sirve cada lista
- Comprobar si tienes una opción concreta **sin buscar en internet**
- Moverte por `curl --help all` y por `curl --manual`
- Dejar por escrito qué te falta, para no tropezar en la Semana 02

## 📋 Antes de empezar

```bash
cd /ruta/a/bc-curl
./scripts/start.sh
```

Crea el archivo donde vas a ir apuntando:

```bash
touch 2-practicas/respuestas.md
```

---

## Paso 1: Comprobar que curl existe y cuál se está ejecutando

**Por qué**: en macOS y en algunas distribuciones conviven dos curl: el del
sistema y el que instaló Homebrew o conda. Ejecutas uno y lees la documentación
del otro. En PowerShell, además, `curl` es un alias de `Invoke-WebRequest`, que
no es curl en absoluto y acepta otros flags.

**Comando**:

```bash
# command -v dice que binario se ejecuta de verdad al escribir "curl".
command -v curl
# /usr/bin/curl

# Si hay mas de uno instalado, este los lista todos en orden de prioridad.
type -a curl
```

**Verifica**:

```bash
curl --version | head -1
# curl 7.81.0 (x86_64-pc-linux-gnu) libcurl/7.81.0 OpenSSL/3.0.2 zlib/1.2.11 ...
```

Si la salida empieza por otra cosa (`Invoke-WebRequest`, `PowerShell`), estás
fuera de WSL. Abre una terminal WSL y repite.

Apunta en `respuestas.md`: la ruta del binario y la primera línea de
`--version`.

---

## Paso 2: Leer la primera línea entera

**Por qué**: esa línea no es decorativa. Dice tu versión de curl, la de libcurl,
qué biblioteca TLS lleva y qué bibliotecas de compresión. Cuando en la Semana 05
un certificado no valide, saber si tienes OpenSSL, GnuTLS o Secure Transport es
la diferencia entre arreglarlo en dos minutos y pasarte la tarde.

**Comando**:

```bash
curl --version | head -1
# curl 7.81.0 (x86_64-pc-linux-gnu) libcurl/7.81.0 OpenSSL/3.0.2 zlib/1.2.11
# brotli/1.0.9 zstd/1.4.8 libidn2/2.3.2 libpsl/0.21.0 libssh/0.9.6 nghttp2/1.43.0
#      │        │              │           │           │        │        │
#      │        │              │           │           │        │        └ HTTP/2
#      │        │              │           │           └───────┴────────── compresión
#      │        │              │           └─ gzip
#      │        │              └─ la biblioteca TLS
#      │        └─ la version de la biblioteca; casi siempre igual a la de curl
#      └─ TU VERSION: la que decide que flags tienes
```

**Verifica**: contesta estas tres, y anótalas.

```bash
# 1. Tu version de curl:
curl --version | head -1 | cut -d' ' -f2
# 7.81.0

# 2. Tu biblioteca TLS:
curl --version | head -1 | grep -oE '(OpenSSL|GnuTLS|NSS|LibreSSL|BoringSSL|Secure Transport|Schannel)[^ ]*'
# OpenSSL/3.0.2

# 3. ¿Tienes HTTP/2 compilado?
curl --version | head -1 | grep -c nghttp2
# 1
```

---

## Paso 3: `Protocols:` no es lo mismo que `Features:`

**Por qué**: se confunden constantemente. `Protocols:` son los esquemas de URL
que tu curl entiende (`http`, `ftp`, `smtp`…). `Features:` son las capacidades
que se activaron al compilarlo (HTTP/2, brotli, IDN, Kerberos…). Un curl puede
hablar `https` y no tener `HTTP2`: son dos preguntas distintas.

**Comando**:

```bash
curl --version | grep '^Protocols:'
# Protocols: dict file ftp ftps gopher gophers http https imap imaps ldap ldaps
# mqtt pop3 pop3s rtmp rtsp scp sftp smb smbs smtp smtps telnet tftp

curl --version | grep '^Features:'
# Features: alt-svc AsynchDNS brotli GSS-API HSTS HTTP2 HTTPS-proxy IDN IPv6
# Kerberos Largefile libz NTLM NTLM_WB PSL SPNEGO SSL TLS-SRP UnixSockets zstd
```

**Verifica**:

```bash
# ¿Habla https? (protocolo)
curl --version | grep -c 'https'
# 1

# ¿Trae HTTP/2? (feature). Ojo a las mayusculas: la feature se llama HTTP2.
curl --version | grep -qw HTTP2 && echo "tiene HTTP/2" || echo "sin HTTP/2"
# tiene HTTP/2

# ¿Trae HTTP/3? En 7.81 casi seguro que no: es experimental y hay que
# compilarlo a mano. Semana 09.
curl --version | grep -qw HTTP3 && echo "tiene HTTP/3" || echo "sin HTTP/3"
# sin HTTP/3
```

Apunta las dos listas en `respuestas.md`.

---

## Paso 4: Averiguar si tienes una opción concreta

**Por qué**: esta es la comprobación que vas a repetir las diez semanas. En vez
de buscar en un blog "desde qué versión existe `--fail-with-body`", se lo
preguntas a tu binario, que es el único que sabe la respuesta correcta para tu
máquina.

**Comando**:

```bash
# --help all lista TODAS las opciones. Si el grep encuentra la opcion, la
# tienes; si no, no. No hay ambiguedad.
curl --help all | grep -- '--fail-with-body'
#      --fail-with-body  Fail on HTTP errors but save the body

curl --help all | grep -- '--json'
# (sin salida en 7.81: esta opcion llego en 7.82)
```

> [!NOTE]
> El `--` suelto antes del patrón es para que `grep` no interprete `--json`
> como una de sus propias opciones. Sin él, `grep` protesta.

**Verifica**: comprueba las cinco opciones que este bootcamp usa y que **no**
son universales. Anota cuáles te faltan.

```bash
for opcion in --fail-with-body --json --retry-all-errors --compressed --parallel; do
  if curl --help all | grep -q -- "$opcion"; then
    printf '%-22s SI\n' "$opcion"
  else
    printf '%-22s NO\n' "$opcion"
  fi
done
# --fail-with-body       SI
# --json                 NO
# --retry-all-errors     SI
# --compressed           SI
# --parallel             SI
```

La tabla de qué versión trajo cada una está en
[`docs/versiones-de-curl.md`](../../../docs/versiones-de-curl.md).

---

## Paso 5: `--help` frente a `--help all`

**Por qué**: `curl --help` a secas enseña diecisiete líneas. Hay 245. Si buscas
una opción en el resumen y no está, la conclusión equivocada es "curl no puede
hacer eso".

**Comando**:

```bash
curl --help | wc -l
# 17

curl --help all | wc -l
# 245
```

**Verifica**:

```bash
# La opcion que buscas casi nunca esta en el resumen.
curl --help | grep -c -- '--retry'
# 0
curl --help all | grep -c -- '--retry'
# 5
```

---

## Paso 6: Buscar una opción por lo que hace, no por cómo se llama

**Por qué**: el problema real nunca es "quiero usar `--connect-timeout`". Es
"quiero que esto no se quede colgado". El nombre exacto de la opción es justo lo
que no recuerdas.

**Comando**:

```bash
# Buscar por concepto en la lista completa.
curl --help all | grep -i 'timeout'
#      --connect-timeout <fractional seconds> Maximum time allowed for connection
#      --expect100-timeout <seconds> How long to wait for 100-continue
#      --happy-eyeballs-timeout-ms <milliseconds> Time for IPv6 before trying IPv4
```

Fíjate en lo que **no** sale: `-m, --max-time`, que es justo la que buscabas. Su
descripción dice *Maximum time allowed for the transfer* y no contiene la
palabra `timeout`. Buscar por concepto acierta casi siempre, pero no siempre:
por eso existe el paso siguiente.

**Verifica**: curl también agrupa las opciones por categoría.

```bash
curl --help category | head -6
# Usage: curl [options...] <url>
#  auth        Different types of authentication methods
#  connection  Low level networking operations
#  curl        The command line tool itself
#  dns         General DNS options
#  file        FILE protocol options

# Y se pide una categoria concreta:
curl --help connection | head -4
```

Busca tú una opción para cada uno de estos tres problemas y anótala:

1. Limitar la velocidad de descarga
2. Reintentar cuando el servidor responde 5xx
3. Ver los tiempos de cada fase de la petición

---

## Paso 7: El manual completo, sin internet

**Por qué**: `--help all` da una línea por opción. Cuando lo que necesitas es
saber **cómo se comporta** —qué pasa si la combinas con otra, desde qué versión
existe, cuáles son los casos raros— hace falta el manual. Y curl lo lleva
dentro: no depende de que la distribución haya instalado las páginas de manual.

**Comando**:

```bash
curl --manual | wc -l
# 5088

# Dentro de less: / para buscar, n para la siguiente coincidencia, q para salir.
curl --manual | less
```

**Verifica**: busca la sección de códigos de salida, que vas a usar en la
práctica 04.

```bash
curl --manual | grep -n 'EXIT CODES' | head -2
# 4857:EXIT CODES

# Y las primeras lineas de esa seccion, sin escribir el numero a mano:
n=$(curl --manual | grep -n 'EXIT CODES' | head -1 | cut -d: -f1)
curl --manual | sed -n "${n},$((n + 12))p"
```

> [!TIP]
> El número de línea cambia entre versiones. Por eso el comando lo calcula
> con `grep -n` en vez de darlo fijo.

---

## Paso 8: Comprobar que el laboratorio responde

**Por qué**: todas las prácticas de las diez semanas apuntan al laboratorio
local. Si no está arriba, los ejemplos fallan por una razón que no tiene nada
que ver con lo que estás aprendiendo.

**Comando**:

```bash
# -sf: silencioso y fallando ante 4xx/5xx. --max-time 5 para que no se cuelgue
# si el contenedor esta arrancando.
curl -sf --max-time 5 -o /dev/null http://localhost:8080/get
echo "codigo de salida: $?"
# codigo de salida: 0
```

**Verifica**:

```bash
curl -s http://localhost:8080/get | head -3
# {
#   "args": {},
#   "headers": {

# Y el frontal TLS, que se usara a partir de la Semana 05:
curl -s -o /dev/null -w '%{http_code}\n' --cacert docs/lab-ca.pem https://localhost:8443/get
# 200
```

Si el segundo comando falla, no es un problema de esta semana: el laboratorio
TLS se estrena en la Semana 05. Anótalo y sigue.

---

## ✅ Resultado

Tu `respuestas.md` tiene que contener:

- [ ] La ruta del binario (`command -v curl`) y la primera línea de `--version`
- [ ] Tu versión de curl y tu biblioteca TLS, separadas
- [ ] Las listas de `Protocols:` y `Features:`, y una frase explicando la diferencia
- [ ] La tabla de las cinco opciones del paso 4, con SI/NO
- [ ] Los tres nombres de opción que encontraste en el paso 6
- [ ] Confirmación de que `http://localhost:8080/get` responde

Comprueba el estado general de la semana con:

```bash
./scripts/verificar-semana.sh 01
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `curl: command not found` | No está instalado | `sudo apt install curl` en Debian/Ubuntu, `brew install curl` en macOS |
| La salida de `--version` empieza por `PowerShell` | `curl` es un alias de `Invoke-WebRequest` | Trabaja dentro de WSL, o usa `curl.exe` |
| `curl --help all` no existe | curl anterior a 7.73 | Usa `curl --help` y `curl --manual`; y plantéate actualizar |
| `--fail-with-body` sale NO | curl anterior a 7.76 | Usa `%{http_code}` con `-w`, que funciona en todas las versiones. Teoría 06, sección 5.3 |
| `curl --manual` no imprime nada | Se compiló sin el manual embebido (algunas distribuciones minimalistas) | `man curl`, o el [manpage en línea](https://curl.se/docs/manpage.html) |
| `localhost:8080` no responde | El laboratorio no está arriba | `./scripts/start.sh` y espera al healthcheck |
| `Connection refused` en 8443 | El contenedor TLS aún está generando el certificado | Espera 20 s y repite; es normal en el primer arranque |

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [README de la semana](../README.md) | **Práctica 01 — Conocer tu curl** | [Práctica 02 — El primer GET](02-el-primer-get.md) |
