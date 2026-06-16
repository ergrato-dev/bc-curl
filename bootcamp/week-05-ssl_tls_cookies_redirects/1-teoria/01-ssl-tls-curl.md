# SSL/TLS con curl: verificación de certificados

## Qué hace curl automáticamente

Cuando hacés `curl https://...`, curl establece una conexión TLS antes de enviar cualquier dato. Como parte de ese proceso, realiza dos verificaciones automáticas:

1. **Peer verification**: el certificado del servidor fue firmado por una CA (Certificate Authority) de confianza
2. **Host verification**: el nombre en el certificado coincide con el hostname de la URL

Si alguna de las dos falla, curl aborta la conexión y muestra un error. No hay que hacer nada especial — esta protección está activa por defecto.

```bash
# Esto funciona: cert válido, CA conocida
curl https://httpbin.org/get

# Esto falla: cert auto-firmado o CA desconocida
curl https://servidor-con-cert-invalido.local
# curl: (60) SSL certificate problem: self-signed certificate
```

---

## El flag --insecure / -k

`--insecure` desactiva ambas verificaciones. curl establece la conexión sin validar el certificado:

```bash
curl --insecure https://servidor-con-cert-invalido.local
curl -k https://servidor-con-cert-invalido.local
```

**Cuándo se usa:**
- En entornos de desarrollo local con certificados auto-firmados
- En staging con CAs privadas cuando no tenés el CA bundle a mano
- Para diagnóstico rápido cuando no sabés si el problema es el cert o la app

**Cuándo NO se usa:**
- Nunca en producción
- Nunca en scripts que corren con credenciales reales
- Nunca en CI/CD contra servidores externos

`--insecure` no cifra menos — TLS sigue cifrando el tráfico. Lo que desactiva es la *verificación de identidad*, lo que abre la puerta a ataques de man-in-the-middle.

---

## Ver información del certificado con -v

El flag `-v` (verbose) muestra el proceso completo de TLS handshake. Podés ver qué certificado presentó el servidor:

```bash
curl -v https://httpbin.org/get 2>&1 | grep -A5 "SSL"
```

Output típico:

```
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384
* ALPN: server accepted h2
* Server certificate:
*  subject: CN=httpbin.org
*  start date: Jan 15 00:00:00 2025 GMT
*  expire date: Apr 15 23:59:59 2025 GMT
*  subjectAltName: host "httpbin.org" matched cert's "httpbin.org"
*  issuer: C=US; O=Let's Encrypt; CN=R11
*  SSL certificate verify ok.
```

Para ver el estado del certificado sin descargar el body:

```bash
curl --head --verbose https://httpbin.org 2>&1 | grep -i "cert\|SSL\|TLS"
```

---

## Especificar un CA bundle propio con --cacert

Si el servidor usa un certificado firmado por una CA que no está en el bundle del sistema (CA privada corporativa, o CA auto-generada), podés especificar el archivo CA:

```bash
# Indicar el archivo CA en formato PEM
curl --cacert /ruta/a/ca.pem https://servidor-interno.empresa.com/api
```

También podés especificar un directorio con múltiples CAs:

```bash
curl --capath /ruta/a/directorio-cas/ https://servidor-interno.empresa.com/api
```

---

## Certificados cliente con --cert y --key

Para mTLS (mutual TLS), donde el servidor también pide que el cliente se autentique con un certificado:

```bash
# Certificado y clave separados
curl --cert mi-cert.pem --key mi-clave.pem https://api-con-mtls.empresa.com

# Certificado PKCS#12 (combina cert + key)
curl --cert mi-bundle.p12:contraseña --cert-type P12 https://api-con-mtls.empresa.com
```

---

## Verificar el cert del servidor con openssl

Para inspeccionar el certificado de un servidor sin curl:

```bash
# Ver detalles completos del certificado
echo | openssl s_client -connect httpbin.org:443 2>/dev/null | openssl x509 -noout -text

# Ver solo las fechas de validez
echo | openssl s_client -connect httpbin.org:443 2>/dev/null | openssl x509 -noout -dates

# Ver el issuer (quién lo firmó)
echo | openssl s_client -connect httpbin.org:443 2>/dev/null | openssl x509 -noout -issuer
```

---

## Resumen

| Flag | Función |
|------|---------|
| (ninguno) | Verifica peer + host por defecto |
| `--insecure` / `-k` | Desactiva verificación (solo desarrollo) |
| `--cacert archivo.pem` | CA bundle personalizado |
| `--capath directorio/` | Directorio con múltiples CAs |
| `--cert cert.pem` | Certificado cliente (para mTLS) |
| `--key key.pem` | Clave privada del certificado cliente |
| `-v` | Ver detalles del handshake TLS |
