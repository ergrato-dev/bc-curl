# Glosario - Semana 5

---

**TLS (Transport Layer Security)**
Protocolo criptográfico que protege las comunicaciones en red. Sucesor de SSL. Cuando una URL comienza con `https://`, la conexión usa TLS para cifrar el tráfico y verificar la identidad del servidor. La versión actual recomendada es TLS 1.3.

---

**SSL (Secure Sockets Layer)**
El predecesor de TLS, ahora obsoleto. El término "SSL" se sigue usando coloquialmente para referirse a lo que técnicamente es TLS. curl admite las versiones modernas de TLS y rechaza SSL 3.0 y versiones anteriores por vulnerabilidades conocidas.

---

**Certificado X.509**
Formato estándar de certificado digital. Contiene: la clave pública del servidor, el nombre del dominio (CN o SAN), la CA que lo firmó, y las fechas de validez. curl verifica el certificado del servidor en cada conexión HTTPS.

---

**CA (Certificate Authority)**
Entidad de confianza que firma certificados digitales. Los sistemas operativos y curl incluyen un bundle con cientos de CAs conocidas (Mozilla, Let's Encrypt, DigiCert, etc.). Si el cert del servidor está firmado por una CA del bundle, curl lo acepta sin configuración adicional.

---

**mTLS (Mutual TLS)**
Variante de TLS en la que tanto el servidor como el cliente presentan certificados para autenticarse mutuamente. curl soporta mTLS con `--cert cliente.pem --key cliente-key.pem`. Se usa en APIs de alta seguridad y en comunicación entre microservicios.

---

**--cacert**
Flag de curl para especificar el archivo de certificado de la CA que firmó el servidor. Necesario cuando el servidor usa un certificado auto-firmado o emitido por una CA privada que no está en el bundle del sistema. Ejemplo: `curl --cacert mi-ca.pem https://servidor.interno/`.

---

**--cert**
Flag de curl para especificar el certificado del cliente en conexiones mTLS. El cliente presenta este certificado para que el servidor lo verifique. Siempre acompaña a `--key`. Diferente de `--cacert`: `--cert` identifica al cliente, `--cacert` identifica quién firmó al servidor.

---

**--insecure / -k**
Desactiva la verificación del certificado del servidor. curl acepta cualquier certificado, incluyendo los auto-firmados, caducados o con nombre de dominio incorrecto. Útil solo en entornos de desarrollo local controlados. Nunca usar en producción ni contra APIs externas.

---

**Cookie**
Par nombre-valor que el servidor envía al cliente con `Set-Cookie` y el cliente devuelve en requests posteriores con el header `Cookie`. Mecanismo principal para mantener sesión en HTTP, que es stateless por diseño.

---

**HttpOnly**
Atributo de una cookie que impide que JavaScript del navegador la lea. curl no tiene JavaScript, por lo que este atributo no afecta su comportamiento, pero es relevante cuando se prueban APIs que también sirven aplicaciones web.

---

**Secure**
Atributo de una cookie que indica que el navegador solo debe enviarla en conexiones HTTPS. curl respeta este atributo: no envía cookies marcadas como Secure a URLs `http://`.

---

**SameSite**
Atributo de una cookie que controla si se envía en requests cross-site (desde otro dominio). Valores: `Strict`, `Lax`, `None`. Relevante para prevenir CSRF. curl envía las cookies sin importar este atributo porque los requests de curl no tienen contexto de "sitio origen".

---

**Set-Cookie**
Header HTTP de respuesta mediante el cual el servidor crea una cookie en el cliente. Formato: `Set-Cookie: nombre=valor; HttpOnly; Secure; Path=/; SameSite=Strict`. curl lo procesa y guarda la cookie cuando se usa `-c`.

---

**Cookie jar**
Archivo donde curl almacena las cookies recibidas del servidor. Se especifica con `-c archivo`. El formato es el formato Netscape cookie file, con columnas separadas por tabs: hostname, flag, path, secure, expiry, name, value.

---

**--connect-timeout**
Tiempo máximo en segundos que curl espera para establecer la conexión TCP (y TLS si aplica). Si el servidor no acepta la conexión en ese tiempo, curl aborta con exit code 28. No limita el tiempo de transferencia de datos.

---

**--max-time**
Tiempo máximo total en segundos para todo el request, incluyendo conexión y transferencia de datos. Si el servidor responde lentamente o la descarga es muy grande, este flag garantiza que curl no bloquee indefinidamente.

---

**--retry**
Número de reintentos automáticos que curl realiza si el request falla. Por defecto, solo reintenta en errores de red. Con `--retry-all-errors` también reintenta en respuestas 5xx.

---

**exit code 28**
Código de salida que curl devuelve cuando se supera el tiempo de espera (`--connect-timeout` o `--max-time`). Verificable con `echo $?` inmediatamente después del comando. Útil para detectar y manejar timeouts en scripts.

---

**Redirect**
Respuesta HTTP con status 3xx que indica al cliente que el recurso está en otra URL. El header `Location` contiene la URL de destino. curl no sigue redirects por defecto; se activan con `-L`.

---

**301 (Moved Permanently)**
El recurso se movió definitivamente a la URL del header `Location`. Los clientes (y motores de búsqueda) deben actualizar sus referencias. curl puede cambiar POST a GET al seguir este redirect, a menos que se use `--post301`.

---

**302 (Found)**
Redirect temporal. El recurso existe en la URL original pero ahora se accede en la URL del `Location`. Similar al 301 en comportamiento de curl respecto al método.

---

**307 (Temporary Redirect)**
Redirect temporal que garantiza que el método HTTP se mantiene igual. Un POST a una URL que responde 307 se convierte en POST a la URL de destino, no en GET.

---

**308 (Permanent Redirect)**
Equivalente permanente del 307. Garantiza que el método se mantiene igual. curl lo maneja correctamente sin flags adicionales.

---

**--max-redirs**
Límite de cuántos redirects seguirá curl en una cadena. El valor por defecto es 30. Con `--max-redirs 5` curl falla con error si hay más de 5 redirects. Útil para detectar bucles de redirects o cadenas inesperadamente largas.

---

**-L (--location)**
Flag que activa el seguimiento automático de redirects en curl. Sin `-L`, curl devuelve la respuesta 3xx tal cual. Con `-L`, curl sigue el redirect hasta la respuesta final o hasta alcanzar el límite de `--max-redirs`.
