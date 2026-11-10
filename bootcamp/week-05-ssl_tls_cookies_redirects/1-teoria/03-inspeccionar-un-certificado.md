# Inspeccionar un certificado

> Cuando curl dice 60, la siguiente pregunta es "¿qué certificado me está
> enseñando ese servidor?". Responderla sin navegador, desde la terminal, es la
> mitad de depurar TLS.

![Diagrama de un certificado abierto en sus campos: subject, subjectAltName con los nombres DNS, issuer, ventana de validez y clave pública; cada campo enlazado con la herramienta que lo enseña (curl -v, openssl x509, --write-out con certs en 7.88+) y con el fallo que provoca cuando no cuadra](../0-assets/03-inspeccionar-un-certificado.svg)

## 🎯 Objetivos

- Sacar el certificado de un servidor con `openssl s_client`
- Leer sus campos útiles con `openssl x509`: nombres, emisor, fechas
- Avisar antes de que caduque con `-checkend`
- Probar un servidor por IP o por otro nombre con `--resolve` y `--connect-to`
- Saber qué es `--pinnedpubkey` y por qué es frágil

---

## 1. Qué problema resuelve

Los fallos TLS de verdad rara vez son "no tengo la CA". Son:

- Un certificado que se renovó sin el nombre nuevo en el `subjectAltName`
- Un balanceador con un certificado viejo en uno de sus nodos
- Un certificado que caduca el sábado a las tres de la mañana
- Un servidor que no manda la intermedia, y unos clientes funcionan y otros no

Todos se diagnostican igual: mirando el certificado que el servidor presenta
**de verdad**, no el que crees que tiene instalado.

---

## 2. Cómo funciona

### 2.1 Lo que enseña curl

La sección `Server certificate` de `-v` ([archivo 01](01-que-hace-tls-por-ti.md))
es el resumen rápido: `subject`, `subjectAltName`, `issuer` y fechas. Para algo
más, se pasa a `openssl`.

### 2.2 Sacar el certificado con `openssl s_client`

```bash
openssl s_client -connect localhost:8443 -servername localhost </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -enddate -ext subjectAltName
# subject=
# issuer=CN = Caddy Local Authority - ECC Intermediate
# notAfter=Nov 11 09:29:21 2026 GMT
# X509v3 Subject Alternative Name: critical
#     DNS:localhost
```

Las piezas:

| Pieza | Para qué |
|---|---|
| `-connect host:puerto` | A dónde conectar |
| `-servername host` | El nombre que se manda en el SNI. **Sin él**, un servidor con varios certificados no sabe cuál darte |
| `</dev/null` | Cierra la conexión en cuanto termina el handshake |
| `openssl x509 -noout` | Lee el primer certificado de la entrada y no lo vuelve a imprimir |

El `subject` vacío no es un error: los certificados modernos ponen los nombres
en el `subjectAltName`, que es el **único** campo que miran los clientes
actuales. Un `CN=` en el subject sin SAN ya no vale.

### 2.3 El SNI, la razón del 35 por IP

En el handshake, antes del certificado, el cliente dice a qué nombre quiere
hablar: es el **SNI** (*Server Name Indication*). Un servidor con muchos
sitios elige el certificado por ese nombre. Por IP no hay nombre que mandar, y
Caddy no tiene certificado que dar: por eso el 35 del archivo 01.

### 2.4 Fechas y `-checkend`

```bash
echo | openssl s_client -connect localhost:8443 -servername localhost 2>/dev/null \
  | openssl x509 -noout -checkend 86400
# Certificate will expire
echo "codigo: $?"
# codigo: 1
```

`-checkend N` sale con 1 si el certificado caduca en los próximos N segundos.
El de Caddy vive unas doce horas, así que "en 24 h" siempre es que sí. Contra
un servidor real, `-checkend 1209600` (14 días) es la base de una alerta.

### 2.5 En curl 7.88+: `%{certs}`

curl 7.88 añadió dos variables de `--write-out`: `%{num_certs}` y
`%{certs}`, la cadena entera en texto. En 7.81 no existen; con la imagen
oficial:

```bash
docker run --rm --network host -v "$PWD/docs:/d:ro" curlimages/curl:8.21.0 \
  -s --cacert /d/lab-ca.pem -o /dev/null -w '%{num_certs}\n%{certs}' \
  https://localhost:8443/get | grep -E '^[0-9]+$|^(Issuer|Expire date)'
# 2
# Issuer:CN = Caddy Local Authority - ECC Intermediate
# Expire date:Nov 11 09:29:21 2026 GMT
# Issuer:CN = Caddy Local Authority - 2026 ECC Root
# Expire date:Nov 17 21:29:21 2026 GMT
```

---

## 3. Cómo se usa

### 3.1 Probar un nodo concreto: `--resolve` y `--connect-to`

Un balanceador con tres nodos, y uno da el 60. Hay que hablar con cada nodo
**manteniendo el nombre**, para que el SNI y la verificación sean los de
verdad:

```bash
# --resolve HOST:PUERTO:IP — "cuando resuelvas este nombre, usa esta IP".
curl -s --cacert docs/lab-ca.pem --resolve localhost:8443:127.0.0.1 \
  -o /dev/null -w '%{http_code} %{remote_ip}\n' https://localhost:8443/get
# 200 127.0.0.1

# --connect-to HOST:PUERTO:DESTINO:PUERTO — "conecta allí en su lugar".
curl -s --cacert docs/lab-ca.pem --connect-to localhost:8443:127.0.0.1:8443 \
  -o /dev/null -w '%{http_code} %{remote_ip}\n' https://localhost:8443/get
# 200 127.0.0.1
```

La URL no cambia, así que el SNI, el header `Host` y la comprobación del
nombre siguen siendo `localhost`. Cambiar la URL a la IP no prueba lo mismo:
es el 35 de antes. `--resolve` cambia la resolución; `--connect-to` permite
además cambiar el puerto. Las dos existen en 7.81.

### 3.2 Comparar lo instalado con lo servido

```bash
# Lo que sirve el servidor, en una huella corta.
openssl s_client -connect localhost:8443 -servername localhost </dev/null 2>/dev/null \
  | openssl x509 -noout -fingerprint -sha256
```

Si la huella cambia entre dos nodos con `--connect-to`, tienes el nodo con el
certificado viejo.

### 3.3 `--pinnedpubkey`: confiar en una clave, no en una CA

`--pinnedpubkey` (7.39+; el formato `sha256//`, 7.44+ con OpenSSL) exige que la clave
pública del **servidor** sea una concreta, además de la verificación normal:

```bash
# La huella de la clave del servidor, en el formato que espera curl.
pin=$(openssl s_client -connect localhost:8443 -servername localhost </dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary | base64)

curl -s --cacert docs/lab-ca.pem --pinnedpubkey "sha256//$pin" \
  -o /dev/null -w '%{http_code}\n' https://localhost:8443/get
# 200

curl -s --cacert docs/lab-ca.pem --pinnedpubkey docs/lab-ca.pem \
  -o /dev/null https://localhost:8443/get; echo "codigo: $?"
# codigo: 90
```

El segundo falla con **90**: el pin se compara con la clave de la hoja, no con
la de la CA. Y ahí está su fragilidad: si el servidor cambia de clave al
renovar, el pin rompe y tu script deja de funcionar a la vez que el resto del
mundo sigue bien. Úsalo solo si controlas el servidor y su rotación de claves,
y lleva siempre dos pines (`sha256//A;sha256//B`): la clave actual y la
siguiente.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `openssl s_client` sin `-servername` | Puedes recibir el certificado por defecto, no el del sitio que pruebas | `-servername` con el mismo nombre que la URL |
| Probar un nodo cambiando la URL por su IP | Cambia el SNI y el nombre que se verifica: pruebas otra cosa | `--resolve` o `--connect-to` |
| Mirar el certificado en el disco del servidor | El que sirve puede ser otro: un proxy delante, un reload que no se hizo | `s_client` contra el puerto real |
| Un solo pin en `--pinnedpubkey` | La primera rotación de clave deja el script roto | Dos pines, actual y siguiente, o no pinear |
| Comprobar la caducidad a mano "cuando me acuerdo" | Caduca en fin de semana | `-checkend` en un cron o en el monitor |

---

## 5. Trucos

```bash
# Dias que le quedan al certificado de un servidor.
fin=$(echo | openssl s_client -connect localhost:8443 -servername localhost 2>/dev/null \
  | openssl x509 -noout -enddate | cut -d= -f2)
echo $(( ( $(date -d "$fin" +%s) - $(date +%s) ) / 86400 )) dias
```

```bash
# Todos los nombres que cubre un certificado, uno por linea.
echo | openssl s_client -connect localhost:8443 -servername localhost 2>/dev/null \
  | openssl x509 -noout -ext subjectAltName | grep -oE 'DNS:[^,]+'
```

```bash
# El resultado de la verificacion segun OpenSSL: 0 es correcto.
curl -s --cacert docs/lab-ca.pem -o /dev/null -w '%{ssl_verify_result}\n' \
  https://localhost:8443/get
```

---

## 📚 Recursos Adicionales

- [OpenSSL — `s_client`](https://docs.openssl.org/3.0/man1/openssl-s_client/) — todas las opciones de conexión
- [OpenSSL — `x509`](https://docs.openssl.org/3.0/man1/openssl-x509/) — `-noout`, `-ext`, `-checkend`, `-fingerprint`
- [manpage de curl — `--resolve`](https://curl.se/docs/manpage.html#--resolve) y [`--connect-to`](https://curl.se/docs/manpage.html#--connect-to)
- [manpage de curl — `--pinnedpubkey`](https://curl.se/docs/manpage.html#--pinnedpubkey) — formatos y versiones
- [RFC 6066 §3 — Server Name Indication](https://datatracker.ietf.org/doc/html/rfc6066#section-3) — el SNI

---

## ✅ Checklist de Verificación

- [ ] He sacado el certificado del laboratorio con `s_client` y leído SAN, emisor y fecha
- [ ] Sé por qué un `subject` vacío no es un problema
- [ ] Sé qué es el SNI y por qué explica el 35 por IP
- [ ] He usado `-checkend` y sé qué código devuelve
- [ ] He probado un servidor con `--resolve` y con `--connect-to` sin cambiar la URL
- [ ] He provocado un 90 con `--pinnedpubkey` y sé por qué es frágil

---

| Anterior | Siguiente |
|---|---|
| [02 — Confiar en una CA propia](02-confiar-en-una-ca-propia.md) | [04 — Certificado de cliente: mTLS](04-certificado-de-cliente-mtls.md) |
