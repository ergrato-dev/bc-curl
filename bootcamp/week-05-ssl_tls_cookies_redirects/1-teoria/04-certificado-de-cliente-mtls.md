# Certificado de cliente: mTLS

> En TLS normal solo el servidor demuestra quién es. En mTLS también el
> cliente: presenta su propio certificado, y sin él la conexión se corta antes
> de que exista la petición HTTP.

![Diagrama del handshake mutuo: el servidor presenta su certificado y además pide uno al cliente con Certificate Request; curl responde con el certificado de --cert y firma con la clave de --key; abajo, los tres fallos: sin certificado el servidor corta con alerta certificate required y curl sale con 56, certificado sin clave o clave que no corresponde sale con 58, clave cifrada sin frase pide la frase por terminal](../0-assets/04-certificado-de-cliente-mtls.svg)

## 🎯 Objetivos

- Explicar en qué cambia el handshake cuando el servidor pide certificado
- Generar un par certificado + clave de prueba con `openssl`
- Presentarlo con `--cert` y `--key`, separados o en un solo PEM
- Reconocer los fallos de mTLS: `56` y `58`
- Proteger la clave privada: permisos y frase de paso fuera del argv

---

## 1. Qué problema resuelve

Un token se copia. Un token en un log, en un `.env` comiteado o en el
historial de una shell vale lo mismo que en manos de su dueño. mTLS ata la
identidad a una **clave privada** que nunca viaja: el cliente demuestra que la
tiene firmando parte del handshake, y lo que viaja (el certificado) no sirve
de nada sin ella.

Dónde lo vas a ver:

- APIs de bancos y pasarelas de pago (PSD2 en Europa lo exige)
- Comunicación entre servicios en una malla (*service mesh*)
- APIs internas que no quieren depender de tokens
- Dispositivos IoT, cada uno con su certificado

---

## 2. Cómo funciona

### 2.1 Un mensaje más en el handshake

En el handshake de mTLS el servidor añade un `Certificate Request`. Se ve
en `-v`:

```bash
curl -sv --cacert docs/lab-ca.pem https://localhost:8444/ -o /dev/null 2>&1 \
  | grep 'Request CERT'
# * TLSv1.3 (IN), TLS handshake, Request CERT (13):
```

El laboratorio tiene un frontal mTLS en `https://localhost:8444`. Sin
certificado de cliente:

```bash
curl -sS --cacert docs/lab-ca.pem https://localhost:8444/
# curl: (56) OpenSSL SSL_read: error:0A00045C:SSL routines::tlsv13 alert certificate required, errno 0
```

**56** (`CURLE_RECV_ERROR`): el servidor mandó una alerta TLS y cerró. Con
TLS 1.3 el fallo llega al **leer**, no al conectar, porque el cliente da el
handshake por terminado antes de que el servidor lo valide. Por eso no es un
35. El texto que importa es `alert certificate required`.

### 2.2 Las dos piezas

| Pieza | Flag | Qué es | ¿Secreta? |
|---|---|---|---|
| Certificado | `--cert` (`-E`) | La clave pública firmada, con tu identidad | No: viaja en el handshake |
| Clave privada | `--key` | Con lo que firmas para demostrar que el certificado es tuyo | **Sí**: nunca sale de tu equipo |

Las dos tienen que **corresponderse**. Un certificado con una clave de otro par
no prueba nada, y curl se niega antes de conectar.

### 2.3 Generar un par de prueba

En producción el certificado lo emite la CA de quien te da acceso: tú generas
la clave y una petición de firma (CSR), y te devuelven el certificado. Para
practicar, uno autofirmado basta:

```bash
# umask 077: la clave nace con permisos 600, sin ventana en la que otro
# usuario pueda leerla.
(umask 077 && openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
  -nodes -keyout cliente.key -out cliente.crt -days 30 -subj /CN=alumno)

ls -l cliente.key | cut -c1-10
# -rw-------
openssl x509 -in cliente.crt -noout -subject -enddate
# subject=CN = alumno
# notAfter=Dec 10 22:27:03 2026 GMT
```

`-nodes` deja la clave **sin cifrar** (*no DES*). Para practicar está bien;
para una clave de verdad, mira la sección 3.3.

El frontal del laboratorio está configurado para **exigir** un certificado,
pero no para validarlo contra una CA: acepta cualquiera, también uno
autofirmado. Un servidor real comprobaría que lo firmó su CA, igual que tú
compruebas el suyo.

---

## 3. Cómo se usa

### 3.1 `--cert` y `--key`

```bash
curl --fail-with-body --max-time 10 --retry 3 -sS \
  --cacert docs/lab-ca.pem \
  --cert cliente.crt --key cliente.key \
  https://localhost:8444/
# mTLS OK: has presentado un certificado de cliente
```

Tres flags de TLS, cada uno con su papel: `--cacert` para confiar en el
servidor, `--cert` y `--key` para que el servidor confíe en ti.

### 3.2 Todo en un PEM

Si certificado y clave van en el mismo archivo, basta `--cert`:

```bash
(umask 077 && cat cliente.crt cliente.key > cliente.pem)
curl -s --cacert docs/lab-ca.pem --cert cliente.pem https://localhost:8444/
# mTLS OK: has presentado un certificado de cliente
```

Ese archivo contiene la clave: los mismos permisos 600. Si la clave está en
otro archivo y no la pasas, curl no la adivina:

```bash
curl -s --cacert docs/lab-ca.pem --cert cliente.crt https://localhost:8444/; echo "codigo: $?"
# codigo: 58
```

**58** (`CURLE_SSL_CERTPROBLEM`): problema con el certificado **local**. Sale
igual si el archivo no existe o si la clave no corresponde al certificado.

### 3.3 Una clave cifrada

Una clave de verdad se guarda cifrada con una frase de paso. curl la necesita
para usarla, y si no se la das, la pide **por terminal**:

```
Enter PEM pass phrase:
```

En un script eso cuelga o falla con 58. La frase tiene su flag, `--pass`,
pero en la línea de comandos sería visible en `ps`: va en un archivo de
configuración con permisos 600, igual que el `--config` de la Semana 03.

```bash
(umask 077 && printf 'pass = "%s"\n' "$CLAVE_FRASE" > ~/.bc-curl-pass)
curl --fail-with-body --max-time 10 --retry 3 -sS \
  --cacert docs/lab-ca.pem \
  --cert cliente.crt --key cliente-cifrada.key \
  --config ~/.bc-curl-pass \
  https://localhost:8444/
```

`--cert archivo:frase` también existe: el mismo problema del argv.

### 3.4 Formatos

curl con OpenSSL espera PEM por defecto. Si te dan otro formato:

| Te dan | Qué es | Qué hacer |
|---|---|---|
| `.pem`, `.crt`, `.key` en texto con `-----BEGIN` | PEM | Usarlo tal cual |
| `.der`, `.cer` binario | DER | `--cert-type DER` / `--key-type DER`, o convertir con `openssl x509 -inform DER` |
| `.p12`, `.pfx` | PKCS#12: certificado y clave juntos, cifrados | `--cert-type P12`, o convertir a PEM con `openssl pkcs12` |

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `--cert cliente.pem:frase` o `--pass frase` en el comando | La frase queda en `ps`, en el historial y en los logs | `pass = "..."` en un `--config` con permisos 600 |
| Clave privada con permisos 644 | Cualquier usuario del equipo puede copiarla y suplantarte | `umask 077` al crearla, `chmod 600` si ya existe |
| Comitear la clave "porque es de pruebas" | Las claves de pruebas acaban dando acceso a algo de verdad | Fuera del repositorio, siempre; `.gitignore` con `*.key` y `*.pem` |
| Leer el 56 como "problema de red" | Es el servidor rechazando tu identidad | Buscar `alert` en el mensaje |
| Pedir `-k` porque "falla el TLS" en mTLS | `-k` desactiva la verificación del servidor, no arregla tu certificado | `--cert` y `--key` correctos |

---

## 5. Trucos

```bash
# ¿Corresponden certificado y clave? Las dos huellas tienen que ser iguales.
openssl x509 -in cliente.crt -noout -pubkey | openssl dgst -sha256
openssl pkey -in cliente.key -pubout | openssl dgst -sha256
```

```bash
# ¿Pide certificado este servidor? Sin mandar ninguno.
curl -sv --cacert docs/lab-ca.pem https://localhost:8444/ -o /dev/null 2>&1 \
  | grep -c 'Request CERT'
# 1
```

```bash
# Cuando caduca tu certificado de cliente. Tambien caducan.
openssl x509 -in cliente.crt -noout -enddate
```

---

## 📚 Recursos Adicionales

- [manpage de curl — `--cert`](https://curl.se/docs/manpage.html#-E) — formatos, frase y backends
- [manpage de curl — `--key`](https://curl.se/docs/manpage.html#--key) — la clave privada
- [everything.curl.dev — Client certificates](https://everything.curl.dev/usingcurl/tls/clientcert.html) — el caso de uso, paso a paso
- [Cloudflare — What is mutual TLS?](https://www.cloudflare.com/learning/access-management/what-is-mutual-tls/) — el concepto, con diagramas
- [RFC 8446 §4.3.2 — Certificate Request](https://datatracker.ietf.org/doc/html/rfc8446#section-4.3.2) — el mensaje que pide el certificado

---

## ✅ Checklist de Verificación

- [ ] Sé qué mensaje del handshake revela que el servidor pide certificado
- [ ] He generado un par de prueba con la clave en 600 desde el primer momento
- [ ] He accedido al frontal mTLS con `--cert` y `--key`, y con un solo PEM
- [ ] Sé distinguir el 56 (el servidor me rechaza) del 58 (mi certificado local falla)
- [ ] Sé dónde va la frase de una clave cifrada para que no aparezca en `ps`
- [ ] He comprobado que un certificado y una clave se corresponden

---

| Anterior | Siguiente |
|---|---|
| [03 — Inspeccionar un certificado](03-inspeccionar-un-certificado.md) | [05 — Cookies y sesiones](05-cookies-y-sesiones.md) |
