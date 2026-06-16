# Glosario - Semana 1

| Término | Definición |
|---------|-----------|
| **HTTP** | HyperText Transfer Protocol. Protocolo de comunicación cliente-servidor que usa la web. |
| **HTTPS** | HTTP con capa TLS para cifrar la comunicación. Puerto 443 por defecto. |
| **Cliente** | Quien inicia la comunicación HTTP. En este bootcamp: curl. |
| **Servidor** | Quien responde la petición HTTP. Puede ser una API, un web server, etc. |
| **Request** | Petición que el cliente envía al servidor. Tiene método, URL, headers y opcionalmente body. |
| **Response** | Respuesta del servidor. Tiene status code, headers y opcionalmente body. |
| **Método HTTP** | Verbo que indica la intención del request: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS. |
| **GET** | Método para leer/obtener un recurso. Sin body. Idempotente. |
| **URL** | Uniform Resource Locator. Dirección que identifica un recurso en la red. |
| **Esquema** | Primera parte de la URL que indica el protocolo: `http://` o `https://`. |
| **Host** | Dominio o IP del servidor en la URL. |
| **Path** | Ruta al recurso dentro del servidor. Empieza con `/`. |
| **Query string** | Parámetros opcionales en la URL después del `?`. Formato `clave=valor&clave2=valor2`. |
| **Status code** | Código de 3 dígitos en la respuesta HTTP que indica el resultado. Ej: 200, 404, 500. |
| **Header** | Par clave-valor de metadatos en request o response. Ej: `Content-Type: application/json`. |
| **Body** | Cuerpo de datos en un request o response. Puede ser JSON, HTML, binario, etc. |
| **Content-Type** | Header que indica el formato del body. Ej: `application/json`, `text/html`. |
| **curl** | Command-line tool para transferir datos usando URLs. Soporta HTTP, HTTPS, FTP y más. |
| **-v / --verbose** | Flag de curl que muestra el proceso completo: conexión, headers enviados y recibidos. |
| **-i / --include** | Flag de curl que incluye los headers de respuesta en el output. |
| **-I / --head** | Flag de curl que hace una petición HEAD (solo headers, sin body). |
| **-o / --output** | Flag de curl para guardar el body de la respuesta en un archivo. |
| **-s / --silent** | Flag de curl que suprime la barra de progreso y mensajes de error. |
| **-L / --location** | Flag de curl para seguir redirects automáticamente. |
| **-w / --write-out** | Flag de curl para formatear información post-transferencia como status code y tiempo. |
| **Redirect** | Respuesta 3xx que indica que el recurso está en otra URL. |
| **idempotente** | Operación que produce el mismo resultado sin importar cuántas veces se ejecute. GET y DELETE son idempotentes. |
