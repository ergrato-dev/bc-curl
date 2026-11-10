# Práctica 01 — Confiar y verificar

> **Duración**: 50 min · **Entregables**: `tls.md`, `certificado.md`

Vas a provocar los dos fallos TLS más comunes (el 60 y el 35), resolver el
primero con la CA del laboratorio de tres formas distintas, descubrir qué hace
`--cacert` con las CAs públicas en tu curl, y abrir el certificado del
servidor para leer lo que de verdad presenta.

**Antes de empezar**, desde la raíz del repositorio:

```bash
./scripts/start.sh
export CA="$PWD/docs/lab-ca.pem"
curl -s --cacert "$CA" -o /dev/null -w '%{http_code}\n' --max-time 5 https://localhost:8443/get
# 200
```

`$CA` lleva la ruta absoluta: la vas a usar desde otra carpeta. Crea la de
trabajo **fuera** del repositorio:

```bash
mkdir -p ~/bc-curl-trabajo/semana-05/p1 && cd ~/bc-curl-trabajo/semana-05/p1
```

---

## Paso 1: El 60

**Por qué**: es el error TLS que más vas a ver. Hay que reconocerlo por su
mensaje y saber que **no** se arregla con `-k`.

**Comando**:

```bash
curl -sS https://localhost:8443/get -o /dev/null; echo "codigo: $?"
```

**Verifica**:

```
curl: (60) SSL certificate problem: unable to get local issuer certificate
codigo: 60
```

Apunta en `tls.md` qué comprobación del certificado falló (cadena, nombre o
fechas) y cómo lo sabes por el mensaje.

---

## Paso 2: El 35

**Por qué**: el 35 parece "otro error TLS", pero ocurre **antes**: no hay
certificado que verificar. Distinguirlo ahorra horas buscando una CA que no
es el problema.

**Comando**:

```bash
curl -sS --cacert "$CA" https://127.0.0.1:8443/get -o /dev/null; echo "codigo: $?"
curl -sv --cacert "$CA" https://127.0.0.1:8443/get -o /dev/null 2>&1 | grep -E 'TLS|SSL' | tail -3
```

**Verifica**:

```
codigo: 35
* TLSv1.2 (IN), TLS header, Unknown (21):
* TLSv1.3 (IN), TLS alert, internal error (592):
* error:0A000438:SSL routines::tlsv1 alert internal error
```

El servidor corta con una **alerta** en mitad del handshake. Con la CA
correcta y todo, falla. Apunta en `tls.md` por qué: ¿qué nombre
manda curl en el SNI cuando la URL es una IP? ¿Para qué nombres tiene
certificado Caddy? (Pista: lo verás en el paso 6.)

---

## Paso 3: Tres formas de presentar la CA

**Por qué**: un comando suelto, una sesión de shell y un directorio de CAs
son tres situaciones reales. Cada una tiene su mecanismo.

**Comando**:

```bash
# 1. En el comando.
curl -s --cacert "$CA" -o /dev/null -w 'cacert: %{http_code}\n' https://localhost:8443/get

# 2. En el entorno (solo para este comando; con export, para toda la sesion).
CURL_CA_BUNDLE="$CA" curl -s -o /dev/null -w 'env: %{http_code}\n' https://localhost:8443/get

# 3. En un directorio indexado por hash.
mkdir -p cas && cp "$CA" cas/
curl -s --capath cas --cacert /dev/null -o /dev/null https://localhost:8443/get; echo "capath sin rehash: $?"
openssl rehash cas
curl -s --capath cas -o /dev/null -w 'capath: %{http_code}\n' https://localhost:8443/get
ls cas
```

**Verifica**:

```
cacert: 200
env: 200
capath sin rehash: 77
capath: 200
fe4a7346.0  lab-ca.pem
```

El nombre del enlace (`fe4a7346.0`) puede ser otro: es un hash del nombre de
tu CA, que Caddy genera al arrancar por primera vez. El `77` sin rehash
viene del `--cacert /dev/null` vacío: curl no puede cargar ninguna CA. Apunta
en `tls.md` qué hace `openssl rehash` y por qué `--capath` lo necesita.

---

## Paso 4: Lo que `--cacert` no quita

**Por qué**: el curl de Ubuntu tiene un CApath por defecto que `--cacert` no
toca. Si crees que `--cacert` restringe la confianza a tu CA, te equivocas, y
conviene descubrirlo aquí y no en una auditoría.

**Comando**:

```bash
curl -sv --cacert "$CA" https://localhost:8443/get -o /dev/null 2>&1 | grep -E 'CAfile|CApath'

# Una web publica con la CA del laboratorio como unica CA... en teoria.
curl -s --max-time 10 --cacert "$CA" -o /dev/null -w 'solo cacert: %{http_code}\n' https://curl.se/
curl -s --max-time 10 --cacert "$CA" --capath /dev/null -o /dev/null https://curl.se/; echo "cacert y capath vacio: $?"
```

**Verifica** (necesita salida a Internet):

```
*  CAfile: /home/tu/.../docs/lab-ca.pem
*  CApath: /etc/ssl/certs
solo cacert: 200
cacert y capath vacio: 60
```

Si tu curl no es el de Ubuntu (macOS, la imagen oficial de Docker), el
primero puede dar 60 directamente: depende de cómo se compiló. Apunta en
`tls.md` qué comando usarías para confiar **solo** en la CA interna, en
cualquier curl.

---

## Paso 5: Comprobar la CA antes de confiar

**Por qué**: cualquier CA en tu `--cacert` puede firmar un certificado para
cualquier nombre. Saber qué es y que valida al servidor, sin curl de por
medio, es la comprobación previa.

**Comando**:

```bash
openssl x509 -in "$CA" -noout -subject -ext basicConstraints
openssl x509 -in "$CA" -noout -fingerprint -sha256
openssl s_client -connect localhost:8443 -servername localhost -CAfile "$CA" \
  </dev/null 2>/dev/null | grep 'Verify return code'
openssl s_client -connect localhost:8443 -servername localhost \
  </dev/null 2>/dev/null | grep 'Verify return code'
```

**Verifica**:

```
subject=CN = Caddy Local Authority - 2026 ECC Root
X509v3 Basic Constraints: critical
    CA:TRUE, pathlen:1
sha256 Fingerprint=...
Verify return code: 0 (ok)
Verify return code: 20 (unable to get local issuer certificate)
```

El año del `subject` es el de la primera vez que arrancaste el laboratorio.
Apunta en `certificado.md` la huella y qué significa `pathlen:1`.

---

## Paso 6: Abrir el certificado del servidor

**Por qué**: el certificado que importa es el que el servidor **presenta**,
no el que alguien dice que instaló.

**Comando**:

```bash
openssl s_client -connect localhost:8443 -servername localhost -showcerts \
  </dev/null 2>/dev/null | grep -c 'BEGIN CERTIFICATE'

openssl s_client -connect localhost:8443 -servername localhost </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -startdate -enddate -ext subjectAltName
```

**Verifica**:

```
2
subject=
issuer=CN = Caddy Local Authority - ECC Intermediate
notBefore=...
notAfter=...
X509v3 Subject Alternative Name: critical
    DNS:localhost
```

Apunta en `certificado.md`:

- Cuántos certificados viajan y cuál falta (y por qué tiene que faltar).
- Cuánto vive el certificado: resta `notBefore` de `notAfter`.
- Por qué el `subject` vacío no impide que curl valide `localhost`.
- La respuesta al paso 2: qué nombres cubre el certificado.

---

## Paso 7: ¿Caduca pronto?

**Por qué**: `-checkend` es la base de cualquier alerta de caducidad.

**Comando**:

```bash
for segundos in 3600 86400; do
  echo | openssl s_client -connect localhost:8443 -servername localhost 2>/dev/null \
    | openssl x509 -noout -checkend "$segundos" >/dev/null
  echo "caduca en menos de $segundos s: $([ $? -eq 1 ] && echo si || echo no)"
done
```

**Verifica**:

```
caduca en menos de 3600 s: no
caduca en menos de 86400 s: si
```

El de una hora puede dar `si` si el certificado está a punto de renovarse;
espera unos minutos y repite. Apunta en `certificado.md` qué umbral pondrías
para un certificado de Let's Encrypt (dura 90 días y se renueva a los 60).

---

## Paso 8: Hablar con una IP sin cambiar el nombre

**Por qué**: es como se prueba un nodo concreto de un balanceador. El paso 2
mostró que cambiar la URL a la IP no sirve.

**Comando**:

```bash
curl -s --cacert "$CA" --resolve localhost:8443:127.0.0.1 \
  -o /dev/null -w 'resolve: %{http_code} %{remote_ip}\n' https://localhost:8443/get
curl -s --cacert "$CA" --connect-to localhost:8443:127.0.0.1:8443 \
  -o /dev/null -w 'connect-to: %{http_code} %{remote_ip}\n' https://localhost:8443/get
```

**Verifica**:

```
resolve: 200 127.0.0.1
connect-to: 200 127.0.0.1
```

Apunta en `tls.md` la diferencia con el paso 2: qué viaja en el SNI en cada
caso.

---

## Paso 9: Pinear y romper el pin

**Por qué**: `--pinnedpubkey` es una defensa fuerte y frágil a la vez.
Romperlo a propósito enseña por qué.

**Comando**:

```bash
pin=$(openssl s_client -connect localhost:8443 -servername localhost </dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary | base64)
echo "$pin"

curl -s --cacert "$CA" --pinnedpubkey "sha256//$pin" -o /dev/null -w 'pin bueno: %{http_code}\n' \
  https://localhost:8443/get
curl -s --cacert "$CA" --pinnedpubkey "$CA" -o /dev/null https://localhost:8443/get; echo "pin de la CA: $?"
```

**Verifica**:

```
pin bueno: 200
pin de la CA: 90
```

Apunta en `certificado.md` contra qué clave se compara el pin, y qué pasaría
con este script el día que Caddy renueve con una clave nueva.

---

## ✅ Resultado

- [ ] `tls.md` explica el 60 y el 35, las tres formas de presentar la CA y el efecto del CApath
- [ ] `certificado.md` tiene la huella de la CA, los campos del certificado del servidor y su duración
- [ ] He usado `--resolve` y `--connect-to` y sé en qué se diferencian de cambiar la URL
- [ ] He provocado un 90 con `--pinnedpubkey`

```bash
./scripts/verificar-semana.sh 05
```

Esta práctica prepara `API_CACERT` del proyecto: la comprobación de que sin
CA el toolkit falla, y con ella valida.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| `docs/lab-ca.pem` no existe | El laboratorio no se arrancó con el script | `./scripts/start.sh`, que la exporta |
| Con `--cacert` sigue dando 60 | La CA cambió: borraste el volumen de Caddy y generó otra | `./scripts/start.sh` de nuevo para reexportarla |
| El paso 4 da `000` | No hay salida a Internet | Sáltalo y anota que no se pudo; el resto no la necesita |
| `openssl rehash: command not found` | OpenSSL 1.0 o anterior | `c_rehash cas` |
| `s_client` se queda esperando | Falta el `</dev/null` | Añádelo, o pulsa `Ctrl+D` |
| `--resolve` da 35 | Escribiste la IP en la URL en vez de `localhost` | La URL no cambia: solo el `--resolve` lleva la IP |

---

| Anterior | Siguiente |
|---|---|
| [Teoría 08 — Reintentos](../1-teoria/08-reintentos.md) | [Práctica 02 — Certificado de cliente](02-certificado-de-cliente.md) |
