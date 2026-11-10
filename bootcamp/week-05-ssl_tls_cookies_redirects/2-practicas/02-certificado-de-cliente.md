# Práctica 02 — Certificado de cliente

> **Duración**: 50 min · **Entregables**: `mtls.md`

Vas a llamar a un servidor que exige certificado de cliente sin tenerlo,
generar un par con la clave protegida desde el primer byte, presentarlo de
dos formas, provocar los fallos del lado del cliente, y usar una clave
cifrada sin que su frase aparezca en `ps`.

**Antes de empezar**, desde la raíz del repositorio:

```bash
./scripts/start.sh
export CA="$PWD/docs/lab-ca.pem"
mkdir -p ~/bc-curl-trabajo/semana-05/p2 && cd ~/bc-curl-trabajo/semana-05/p2
```

---

## Paso 1: Sin certificado

**Por qué**: el fallo de mTLS no se parece a un fallo de TLS normal. Hay que
verlo una vez para reconocerlo después.

**Comando**:

```bash
curl -sS --cacert "$CA" https://localhost:8444/; echo "codigo: $?"
curl -sv --cacert "$CA" https://localhost:8444/ -o /dev/null 2>&1 | grep 'Request CERT'
```

**Verifica**:

```
curl: (56) OpenSSL SSL_read: error:0A00045C:SSL routines::tlsv13 alert certificate required, errno 0
codigo: 56
* TLSv1.3 (IN), TLS handshake, Request CERT (13):
```

Apunta en `mtls.md`:

- Qué mensaje del handshake revela que el servidor pide certificado.
- Por qué el código es 56 (error al **recibir**) y no 35 (error al conectar).

---

## Paso 2: Generar el par, protegido desde el principio

**Por qué**: si creas la clave y **después** haces `chmod 600`, hay un
instante en que es legible por otros usuarios. Con `umask 077` en un subshell,
nace protegida.

**Comando**:

```bash
(umask 077 && openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
  -nodes -keyout cliente.key -out cliente.crt -days 30 -subj /CN=alumno)

ls -l cliente.key cliente.crt | cut -c1-10
openssl x509 -in cliente.crt -noout -subject -enddate
```

**Verifica**:

```
-rw-------
-rw-------
subject=CN = alumno
notAfter=...                ← dentro de 30 dias
```

El certificado también sale con 600 por la `umask`: no es secreto, pero no
pasa nada. Apunta en `mtls.md` qué significa `-nodes` y por qué no lo usarías
para una clave de verdad.

---

## Paso 3: Presentarlo

**Por qué**: tres flags TLS en el mismo comando, cada uno con un papel
distinto. Es fácil confundirlos.

**Comando**:

```bash
curl --fail-with-body --max-time 10 --retry 3 -sS \
  --cacert "$CA" --cert cliente.crt --key cliente.key \
  https://localhost:8444/; echo
```

**Verifica**:

```
mTLS OK: has presentado un certificado de cliente
```

Apunta en `mtls.md`, para cada uno de los tres flags, **quién** confía en
**quién** gracias a él.

---

## Paso 4: ¿Qué valida el servidor?

**Por qué**: el laboratorio acepta cualquier certificado, también el
autofirmado que acabas de crear. Un servidor real no. Conviene saber qué
estás probando y qué no.

**Comando**:

```bash
# Otro par, con otro nombre.
(umask 077 && openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
  -nodes -keyout otro.key -out otro.crt -days 1 -subj /CN=cualquiera 2>/dev/null)
curl -sS --cacert "$CA" --cert otro.crt --key otro.key https://localhost:8444/; echo
```

**Verifica**:

```
mTLS OK: has presentado un certificado de cliente
```

Apunta en `mtls.md` qué comprobaría un servidor de producción que este no
comprueba, y quién tendría que haber firmado tu certificado.

---

## Paso 5: Los fallos del cliente

**Por qué**: el 58 cubre tres errores distintos con el mismo número. El
mensaje es lo que los separa.

**Comando**:

```bash
# Certificado sin su clave.
curl -sS --cacert "$CA" --cert cliente.crt https://localhost:8444/ -o /dev/null; echo "solo cert: $?"

# Certificado con la clave de otro par.
curl -sS --cacert "$CA" --cert cliente.crt --key otro.key https://localhost:8444/ -o /dev/null; echo "clave ajena: $?"

# Un archivo que no existe.
curl -sS --cacert "$CA" --cert noexiste.crt --key cliente.key https://localhost:8444/ -o /dev/null; echo "no existe: $?"
```

**Verifica**:

```
curl: (58) unable to set private key file: 'cliente.crt' type PEM
solo cert: 58
curl: (58) unable to set private key file: 'otro.key' type PEM
clave ajena: 58
curl: (58) could not load PEM client certificate, OpenSSL error error:80000002:system library::No such file or directory, (no key found, wrong pass phrase, or wrong file format?)
no existe: 58
```

Los mensajes exactos dependen de la versión de OpenSSL. Apunta en `mtls.md`
cómo comprobarías **antes** de llamar si un certificado y una clave se
corresponden:

```bash
openssl x509 -in cliente.crt -noout -pubkey | openssl dgst -sha256
openssl pkey -in cliente.key -pubout | openssl dgst -sha256
openssl pkey -in otro.key -pubout | openssl dgst -sha256
```

Las dos primeras huellas son iguales; la tercera, no.

---

## Paso 6: Todo en un PEM

**Por qué**: muchos proveedores entregan certificado y clave en un solo
archivo. curl lo acepta con `--cert` solo.

**Comando**:

```bash
(umask 077 && cat cliente.crt cliente.key > cliente.pem)
grep -c 'BEGIN' cliente.pem
curl -sS --cacert "$CA" --cert cliente.pem https://localhost:8444/; echo
```

**Verifica**:

```
2
mTLS OK: has presentado un certificado de cliente
```

Apunta en `mtls.md` qué permisos necesita `cliente.pem` y por qué.

---

## Paso 7: Una clave cifrada, sin la frase en `ps`

**Por qué**: una clave sin cifrar en disco es una identidad para quien copie
el archivo. Cifrada, hace falta además la frase. Y esa frase no puede ir en
el comando.

**Comando**:

```bash
# Cifrar la clave. La frase se lee de un descriptor, no del argv.
read -rsp 'Frase para la clave: ' CLAVE_FRASE; echo
(umask 077 && openssl pkey -in cliente.key -aes256 \
  -passout fd:3 -out cliente-cifrada.key 3<<<"$CLAVE_FRASE")
head -1 cliente-cifrada.key

# Sin la frase: curl la pide por terminal. Pulsa Enter sin escribir nada.
curl -sS --cacert "$CA" --cert cliente.crt --key cliente-cifrada.key \
  https://localhost:8444/ -o /dev/null; echo "sin frase: $?"

# Con la frase en un --config de permisos 600.
(umask 077 && printf 'pass = "%s"\n' "$CLAVE_FRASE" > frase.cfg)
unset CLAVE_FRASE
curl -sS --cacert "$CA" --cert cliente.crt --key cliente-cifrada.key \
  --config frase.cfg https://localhost:8444/; echo
```

**Verifica**:

```
-----BEGIN ENCRYPTED PRIVATE KEY-----
Enter PEM pass phrase:
sin frase: 58
mTLS OK: has presentado un certificado de cliente
```

Apunta en `mtls.md`:

- Qué pasaría con el `Enter PEM pass phrase:` dentro de un cron.
- Por qué `--pass "$CLAVE_FRASE"` no es aceptable aunque la frase venga de
  una variable (pista: `ps aux` mientras curl se ejecuta).

---

## Paso 8: Limpiar

**Por qué**: una clave de pruebas olvidada en una carpeta acaba en una copia
de seguridad, en un `scp` o en un repositorio.

**Comando**:

```bash
rm -f otro.key otro.crt frase.cfg
ls
```

**Verifica**:

```
cas  cliente-cifrada.key  cliente.crt  cliente.key  cliente.pem
```

(Sin `cas` si no hiciste la práctica 01 en la misma carpeta.) Conserva
`cliente.crt` y `cliente.key`: el proyecto los usa.

---

## ✅ Resultado

- [ ] `mtls.md` explica el 56, el `Request CERT` y el papel de cada uno de los tres flags
- [ ] `mtls.md` distingue los tres 58 y cómo comprobar que certificado y clave casan
- [ ] Mi clave privada nació con permisos 600
- [ ] He usado una clave cifrada con la frase en un `--config`, nunca en el argv

```bash
./scripts/verificar-semana.sh 05
```

Esta práctica prepara `API_CLIENT_CERT` y `API_CLIENT_KEY` del proyecto: la
comprobación con y sin certificado, y el rechazo de una clave legible por
otros.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| `curl: (7)` contra el 8444 | El frontal mTLS no está arrancado | `./scripts/start.sh`; comprueba `docker ps` |
| `openssl req` pide datos interactivos | Falta `-subj` | Copia el comando entero |
| `-pkeyopt` no reconocido | OpenSSL anterior a 1.1 | `openssl ecparam -genkey -name prime256v1` y luego `openssl req -new -x509 -key` |
| El paso 7 no pide la frase y da 58 directamente | No hay terminal (lo ejecutas desde un script o un IDE) | Es justo el problema que muestra el paso; sigue |
| `frase.cfg` con la frase rota | La frase tiene `"` o `\` | Escápalos con `\` en el archivo, o elige otra frase |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 01 — Confiar y verificar](01-confiar-y-verificar.md) | [Práctica 03 — Sesiones y redirects](03-sesiones-y-redirects.md) |
