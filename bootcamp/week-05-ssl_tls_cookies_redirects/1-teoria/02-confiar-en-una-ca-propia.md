# Confiar en una CA propia

> El error 60 casi nunca significa "hay un atacante". Casi siempre significa
> "este servidor usa una CA que tu curl no conoce". La respuesta es presentarle
> esa CA, no apagar la verificación.

![Diagrama de la cadena de confianza: el certificado del servidor firmado por una intermedia, la intermedia firmada por la raíz; a la izquierda el almacén del sistema con las CAs públicas, que no contiene la raíz del laboratorio y acaba en el error 60; a la derecha --cacert con lab-ca.pem, que contiene esa raíz y acaba en verify ok](../0-assets/02-confiar-en-una-ca-propia.svg)

## 🎯 Objetivos

- Explicar por qué un certificado de una CA interna falla con el 60
- Pasar una CA a curl con `--cacert`, `CURL_CA_BUNDLE` y `--capath`
- Saber qué hace `--cacert` con el almacén del sistema en curl 7.81 de Ubuntu
- Comprobar una CA con `openssl` antes de confiar en ella
- Distinguir confiar en una CA para un comando de instalarla en todo el sistema

---

## 1. Qué problema resuelve

Las CAs públicas (Let's Encrypt, DigiCert...) solo firman certificados para
nombres de Internet que puedes demostrar que controlas. Para todo lo demás las
empresas montan su propia CA:

- APIs internas en `*.corp.local` o `*.svc.cluster.local`
- Entornos de staging y desarrollo
- Proxies corporativos que inspeccionan el TLS saliente
- Laboratorios como el de este bootcamp, con la CA interna de Caddy

curl no conoce esas CAs. Ve un certificado firmado por alguien que no está en
su almacén y hace exactamente lo que tiene que hacer: negarse.

---

## 2. Cómo funciona

### 2.1 La cadena de confianza

El frontal del laboratorio presenta **dos** certificados:

```bash
openssl s_client -connect localhost:8443 -servername localhost -showcerts \
  </dev/null 2>/dev/null | grep -c 'BEGIN CERTIFICATE'
# 2
```

El del servidor y el de la intermedia que lo firmó. La raíz **no** viaja: es la
que el cliente tiene que tener ya. Esa raíz es la que exporta
`./scripts/start.sh` a `docs/lab-ca.pem`:

```bash
openssl x509 -in docs/lab-ca.pem -noout -subject -ext basicConstraints
# subject=CN = Caddy Local Authority - 2026 ECC Root
# X509v3 Basic Constraints: critical
#     CA:TRUE, pathlen:1
```

`CA:TRUE` dice que es una CA, que puede firmar otros certificados. `pathlen:1`,
que por debajo solo puede haber un nivel de intermedias.

### 2.2 Dónde busca curl las CAs

curl tiene dos sitios donde mirar, y los dos se ven en `-v`:

```bash
curl -sv https://localhost:8443/get -o /dev/null 2>&1 | grep -E 'CAfile|CApath'
#  CAfile: /etc/ssl/certs/ca-certificates.crt
#  CApath: /etc/ssl/certs
```

| Sitio | Qué es | Flag | Variable de entorno |
|---|---|---|---|
| **CAfile** | Un archivo PEM con una o varias CAs seguidas | `--cacert` | `CURL_CA_BUNDLE` |
| **CApath** | Un directorio con una CA por archivo, indexado por hash | `--capath` | — |

`SSL_CERT_FILE` y `SSL_CERT_DIR` también funcionan con el curl de Ubuntu, pero
porque los lee OpenSSL, no curl: con otro backend TLS no tienen efecto. La
variable propia de curl es `CURL_CA_BUNDLE`.

### 2.3 Lo que `--cacert` cambia en 7.81, y lo que no

`--cacert` **sustituye** el CAfile. Pero el curl de Ubuntu 22.04 viene
compilado con un CApath por defecto, y `--cacert` no lo toca:

```bash
curl -sv --cacert docs/lab-ca.pem https://localhost:8443/get -o /dev/null 2>&1 \
  | grep -E 'CAfile|CApath'
#  CAfile: docs/lab-ca.pem
#  CApath: /etc/ssl/certs
```

Consecuencia: con `--cacert docs/lab-ca.pem`, curl 7.81 **sigue** confiando en
las CAs públicas a través del CApath. Una petición a `https://curl.se` con esa
CA funciona.

La imagen `curlimages/curl:8.21.0` está compilada sin CApath, y ahí
`--cacert` sí deja **solo** la CA que le das: la misma petición a `curl.se`
sale con 60. No es una diferencia de versión sino de compilación. Si quieres
confiar únicamente en tu CA, sea cual sea el curl, anula también el
directorio:

```bash
# Solo la CA del laboratorio: ni el CAfile ni el CApath del sistema.
curl --fail-with-body --max-time 10 --retry 3 -sS \
  --cacert docs/lab-ca.pem --capath /dev/null \
  https://localhost:8443/get
```

### 2.4 `--capath`: un directorio de CAs

Un directorio con un PEM por CA no basta: OpenSSL busca por el **hash** del
nombre de la CA, y necesita enlaces con ese nombre.

```bash
mkdir -p cas && cp docs/lab-ca.pem cas/
openssl rehash cas
ls cas
# fe4a7346.0  lab-ca.pem
curl -s --capath cas -o /dev/null -w '%{http_code}\n' https://localhost:8443/get
# 200
```

Sin el `openssl rehash`, curl no encuentra la CA. En la práctica, `--cacert`
con un bundle es más simple; `--capath` existe porque es como se organiza
`/etc/ssl/certs`.

---

## 3. Cómo se usa

### 3.1 Un comando, una CA

```bash
curl --fail-with-body --max-time 10 --retry 3 -sS \
  --cacert docs/lab-ca.pem \
  https://localhost:8443/get
```

El caso más común y el más limpio: la confianza vive en el comando, y no
afecta a nada más del sistema.

### 3.2 Toda una sesión de shell

```bash
export CURL_CA_BUNDLE="$PWD/docs/lab-ca.pem"
curl -sS https://localhost:8443/get -o /dev/null -w '%{http_code}\n'
# 200
```

Útil cuando un script llama a curl muchas veces y no quieres repetir el flag.
Ruta absoluta: la variable se hereda y el siguiente proceso puede estar en otro
directorio.

### 3.3 La CA interna y las públicas a la vez

Si tu script habla con la API interna **y** con APIs públicas, y tu curl no
tiene CApath (como el de la imagen oficial), un bundle con todo:

```bash
cat /etc/ssl/certs/ca-certificates.crt docs/lab-ca.pem > bundle.pem
curl -s --cacert bundle.pem -o /dev/null -w '%{http_code}\n' https://localhost:8443/get
# 200
```

### 3.4 Comprobar la CA antes de confiar en ella

Una CA en tu `--cacert` puede firmar un certificado para **cualquier** nombre.
Antes de usarla, confirma que es la que dices:

```bash
# La huella: compárala con la que publica quien administra la CA.
openssl x509 -in docs/lab-ca.pem -noout -fingerprint -sha256

# Y que de verdad valida al servidor, sin curl de por medio.
openssl s_client -connect localhost:8443 -servername localhost \
  -CAfile docs/lab-ca.pem </dev/null 2>/dev/null | grep 'Verify return code'
# Verify return code: 0 (ok)
```

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `-k` porque "es un certificado interno" | El impostor también tiene un certificado "interno". `-k` acepta cualquiera | `--cacert` con la CA interna |
| `alias curl='curl -k'` en el `.bashrc` | Apaga la verificación en **todos** los comandos, también contra Internet | Ningún alias; `CURL_CA_BUNDLE` si hace falta para una sesión |
| Bajar la CA por HTTP sin verificar y meterla en `--cacert` | Quien controle esa descarga controla en quién confías | Obtenerla por un canal de confianza y comprobar la huella |
| Pasar el certificado del **servidor** a `--cacert` | Funciona hasta que el servidor renueva, horas o días después | La raíz (o la intermedia) que firma, no la hoja |
| Instalar la CA de un laboratorio en todo el sistema | Todos los programas pasan a confiar en ella, para siempre | `--cacert` en el comando que la necesita |

---

## 5. Trucos

```bash
# Que CAfile y CApath usa tu curl por defecto, sin hacer nada mas.
curl -sv https://localhost:8443/ -o /dev/null 2>&1 | grep -E 'CAfile|CApath'
```

```bash
# Cuantas CAs trae el bundle del sistema.
grep -c 'BEGIN CERTIFICATE' /etc/ssl/certs/ca-certificates.crt
```

```bash
# Sacar la cadena que presenta un servidor, para inspeccionarla. Ojo: la raiz
# no viene; esto NO es una forma de obtener la CA en la que confiar.
openssl s_client -connect localhost:8443 -servername localhost -showcerts \
  </dev/null 2>/dev/null | sed -n '/BEGIN/,/END/p' > cadena.pem
```

---

## 📚 Recursos Adicionales

- [curl — SSL CA certificates](https://curl.se/docs/sslcerts.html) — dónde busca curl las CAs y cómo cambiarlo
- [manpage de curl — `--cacert`](https://curl.se/docs/manpage.html#--cacert) — incluida `CURL_CA_BUNDLE`
- [manpage de curl — `--capath`](https://curl.se/docs/manpage.html#--capath) — el directorio indexado por hash
- [OpenSSL — `openssl rehash`](https://docs.openssl.org/3.0/man1/openssl-rehash/) — cómo se generan los enlaces por hash
- [Caddy — `tls internal`](https://caddyserver.com/docs/caddyfile/directives/tls) — la CA interna que usa el laboratorio

---

## ✅ Checklist de Verificación

- [ ] Sé por qué el frontal del laboratorio falla con 60 sin `--cacert`
- [ ] Sé qué certificados viajan en el handshake y cuál no
- [ ] He visto en `-v` el CAfile y el CApath, con y sin `--cacert`
- [ ] Sé por qué `--cacert` en el curl de Ubuntu no deja de confiar en las CAs públicas
- [ ] He montado un `--capath` con `openssl rehash`
- [ ] He comprobado la huella de una CA y validado un servidor con `openssl s_client`

---

| Anterior | Siguiente |
|---|---|
| [01 — Qué hace TLS por ti](01-que-hace-tls-por-ti.md) | [03 — Inspeccionar un certificado](03-inspeccionar-un-certificado.md) |
