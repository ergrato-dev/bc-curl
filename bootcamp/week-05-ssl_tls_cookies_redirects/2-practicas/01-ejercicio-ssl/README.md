# Ejercicio 01: SSL/TLS y certificados

## Objetivo

Verificar el comportamiento de curl ante certificados SSL, inspeccionar la información de certificados reales, entender qué hace `--insecure` y cuándo es aceptable usarlo.

---

## Tarea 1: Verificación SSL por defecto

Hacer un request a un site HTTPS y verificar que curl valida el certificado automáticamente:

```bash
# Request normal a site con cert válido
curl -s -o /dev/null -w "HTTP %{http_code} - SSL OK\n" https://httpbin.org/get

# Ver el proceso de verificación SSL con -v
curl -v https://httpbin.org/get 2>&1 | grep -E "SSL|TLS|certificate|verify"
```

**Preguntas:**
- ¿Qué versión de TLS usó la conexión?
- ¿Qué mensaje aparece cuando la verificación es exitosa?
- ¿Quién firmó el certificado de httpbin.org?

---

## Tarea 2: Inspeccionar el certificado en detalle

```bash
# Ver fechas de validez del certificado
echo | openssl s_client -connect httpbin.org:443 -servername httpbin.org 2>/dev/null \
    | openssl x509 -noout -dates

# Ver quién lo firmó (issuer) y para quién (subject)
echo | openssl s_client -connect httpbin.org:443 -servername httpbin.org 2>/dev/null \
    | openssl x509 -noout -issuer -subject

# Ver los SANs (Subject Alternative Names): dominios cubiertos por el cert
echo | openssl s_client -connect httpbin.org:443 -servername httpbin.org 2>/dev/null \
    | openssl x509 -noout -text | grep -A5 "Subject Alternative Name"
```

**Preguntas:**
- ¿Cuándo vence el certificado de httpbin.org?
- ¿Qué CA lo firmó?
- ¿El certificado cubre solo `httpbin.org` o también `www.httpbin.org`?

---

## Tarea 3: Ver el handshake TLS completo

```bash
# Ver todo el handshake en detalle
curl -v --tlsv1.2 https://httpbin.org/get 2>&1 | grep -E "^[*]" | head -30

# Comparar con TLS 1.3
curl -v --tlsv1.3 https://httpbin.org/get 2>&1 | grep -E "^[*]" | head -30
```

**Pregunta:** ¿Qué cipher suite negoció cada conexión?

---

## Tarea 4: Simular un error de certificado

httpbin.org tiene un subdominio que genera error de SSL para practicar. Alternativamente podés usar un site conocido con cert expirado o auto-firmado. Para simular el error:

```bash
# Intentar conectar a un host con nombre que no coincide con el cert
# (badssl.com es un site creado exactamente para practicar errores SSL)
curl https://wrong.host.badssl.com/ 2>&1
```

Registrar el mensaje de error exacto.

Ahora con `--insecure`:

```bash
curl --insecure https://wrong.host.badssl.com/ 2>&1 | head -5
```

**Preguntas:**
- ¿Qué código de error (número entre paréntesis) devuelve curl cuando falla la verificación?
- ¿Qué diferencia hay en la respuesta con y sin `--insecure`?
- ¿Sigue siendo cifrada la conexión cuando usás `--insecure`?

---

## Tarea 5: Generar un certificado auto-firmado y conectarse

```bash
# Crear directorio de trabajo
mkdir ~/ssl-practica && cd ~/ssl-practica

# Generar cert auto-firmado para localhost
openssl req -x509 -newkey rsa:2048 -keyout server-key.pem -out server-cert.pem \
    -days 1 -nodes -subj "/CN=localhost"

echo "Certificado generado:"
openssl x509 -noout -dates -subject -in server-cert.pem
```

Intentar conectarse a un servidor hipotético usando el cert como CA (sin levantar servidor real, solo ver el comportamiento de curl con `--cacert`):

```bash
# Mostrar que curl acepta el cert si se lo pasás como CA de confianza
# (el servidor deberá estar corriendo con este cert para que funcione realmente)
echo "Con --cacert el cert sería aceptado si el servidor lo usara:"
openssl x509 -noout -fingerprint -in server-cert.pem
```

**Pregunta:** ¿Cuál es la diferencia entre usar `--cacert server-cert.pem` y usar `--insecure`?

---

## Entrega

Archivo `respuestas.md` con:
1. Versión de TLS y mensaje de verificación exitosa (Tarea 1)
2. Fechas de validez, issuer y SANs de httpbin.org (Tarea 2)
3. Cipher suites de TLS 1.2 y TLS 1.3 (Tarea 3)
4. Código de error SSL y comparación con/sin `--insecure` (Tarea 4)
5. Fingerprint del cert auto-firmado y explicación de `--cacert` vs `--insecure` (Tarea 5)
