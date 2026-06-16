# Primer request GET con curl

## Sintaxis básica

```bash
curl [opciones] URL
```

El orden importa: las opciones van antes de la URL (aunque curl es flexible al respecto, es buena práctica).

---

## GET sin flags

```bash
curl https://httpbin.org/get
```

curl asume GET por defecto cuando no especificás método. La respuesta va a `stdout`.

Salida:
```json
{
  "args": {},
  "headers": {
    "Accept": "*/*",
    "Host": "httpbin.org",
    "User-Agent": "curl/8.5.0"
  },
  "origin": "203.0.113.1",
  "url": "https://httpbin.org/get"
}
```

---

## Flag -v (verbose)

Muestra todo el proceso: DNS, conexión TCP, handshake TLS, headers enviados (`>`), headers recibidos (`<`), body.

```bash
curl -v https://httpbin.org/get
```

Salida anotada:
```
* Trying 54.175.219.8:443...          ← conexión TCP
* Connected to httpbin.org port 443    ← TCP establecida
* TLS handshake...                     ← negociación TLS
> GET /get HTTP/2                      ← request enviado
> Host: httpbin.org
> User-Agent: curl/8.5.0
> Accept: */*
>
< HTTP/2 200                           ← respuesta
< content-type: application/json
< ...
<
{ body JSON }
```

Las líneas con `>` son lo que curl envía.
Las líneas con `<` son lo que el servidor devuelve.
Las líneas con `*` son información de curl (no parte del protocolo).

---

## Flag -i (include headers)

Muestra headers de respuesta + body. Más limpio que `-v` para inspeccionar respuestas.

```bash
curl -i https://httpbin.org/get
```

Salida:
```
HTTP/2 200
content-type: application/json
content-length: 252
...

{ body JSON }
```

---

## Flag -I (HEAD request)

Solo descarga los headers, sin body. Útil para verificar si un recurso existe o ver sus metadatos.

```bash
curl -I https://httpbin.org/get
```

---

## Flag -o (output a archivo)

Guarda el body de la respuesta en un archivo en lugar de mostrarlo en terminal.

```bash
curl -o respuesta.json https://httpbin.org/get
curl -o imagen.png https://httpbin.org/image/png
```

Con `-o /dev/null` descartas el body (útil para medir tiempos o solo ver headers):

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://httpbin.org/get
```

---

## Flag -s (silent)

Suprime la barra de progreso y mensajes de error de curl. El body de la respuesta sigue mostrándose.

```bash
curl -s https://httpbin.org/get
```

Casi siempre se usa con `-o` o en scripts para no contaminar el output.

---

## Flag -L (location / seguir redirects)

Por defecto curl NO sigue redirects. Con `-L` los sigue automáticamente.

```bash
# Sin -L: curl devuelve 301 y para
curl http://httpbin.org/get

# Con -L: curl sigue el redirect a HTTPS
curl -L http://httpbin.org/get
```

---

## Combinando flags

Los flags se pueden combinar:

```bash
# Forma larga
curl --silent --include --location https://httpbin.org/get

# Forma corta combinada
curl -siL https://httpbin.org/get

# Guardar silenciosamente
curl -sL -o resultado.json https://httpbin.org/get
```

---

## Especificar método explícitamente

Aunque GET es el default, podés especificarlo explícitamente:

```bash
curl -X GET https://httpbin.org/get
```

Esto es útil cuando querés ser explícito en scripts.
