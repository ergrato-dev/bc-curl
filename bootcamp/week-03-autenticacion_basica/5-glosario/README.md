# Glosario - Semana 3

---

**Autenticación**
El proceso de verificar la identidad de quien hace un request. Responde a "¿quién sos?". Sin autenticación el request es anónimo. Los mecanismos más comunes en APIs REST son Basic Auth, API Keys y Bearer Tokens.

---

**Autorización**
El proceso de verificar si el usuario autenticado tiene permiso para realizar la operación solicitada. Responde a "¿podés hacer esto?". Ocurre después de la autenticación. Un 401 indica falta de autenticación; un 403 indica falta de autorización.

---

**API Key**
Token estático generado por un servicio que identifica a una aplicación cliente. No representa un usuario humano. Se envía en headers (generalmente `X-API-Key`) o en query string (no recomendado en producción). Puede ser revocada o rotada sin cambiar contraseñas.

---

**Base64**
Esquema de codificación que convierte datos binarios (o texto) a caracteres ASCII imprimibles. No es cifrado — cualquiera puede decodificarlo. Se usa en Basic Auth para codificar `usuario:contraseña`. Decodificar: `echo "base64string" | base64 -d`.

---

**Basic Auth**
HTTP Basic Authentication. Envía usuario y contraseña codificados en base64 en el header `Authorization: Basic XXXX`. Curl lo soporta con `-u user:pass`. Requiere HTTPS obligatoriamente porque las credenciales son trivialmente decodificables.

---

**Bearer Token**
Token de acceso temporal obtenido después de un login exitoso. Se incluye en el header `Authorization: Bearer TOKEN`. "Bearer" significa portador — quien tenga el token puede usarlo. Tiene fecha de expiración y puede ser revocado.

---

**Header Authorization**
Header HTTP estándar usado para enviar credenciales. Tiene esquemas distintos según el mecanismo: `Authorization: Basic XXXX` (Basic Auth), `Authorization: Bearer TOKEN` (Bearer/JWT), `Authorization: ApiKey KEY` (variante de API Key).

---

**JWT (JSON Web Token)**
Formato estándar para Bearer Tokens. Tiene tres partes en base64 separadas por puntos: header (algoritmo), payload (datos del usuario y expiración), signature (firma criptográfica). El payload es legible sin la clave privada, pero no puede modificarse sin invalidar la firma.

---

**.netrc**
Archivo de configuración de curl (en `~/.netrc`) que permite guardar credenciales por hostname. curl lo lee automáticamente con `--netrc`. Debe tener permisos 600 (solo lectura para el owner). Alternativa a repetir `-u user:pass` en cada comando.

---

**Variable de entorno**
Variable almacenada en el entorno del proceso shell, accesible con `$NOMBRE`. Se define con `export NOMBRE=valor`. No aparece en archivos de código fuente. Se usa para pasar credenciales a scripts sin hardcodearlas. Desaparece al cerrar la sesión o terminal.

---

**WWW-Authenticate**
Header que el servidor incluye en respuestas 401 para indicar qué tipo de autenticación espera. Ejemplo: `WWW-Authenticate: Basic realm="API"` indica que el servidor acepta Basic Auth. El cliente usa esta información para saber cómo autenticarse.
