# Versiones de curl

curl casi nunca rompe hacia atrás: un comando de 2010 sigue funcionando hoy. El
riesgo en este bootcamp es el contrario — **escribir un flag que tu versión
todavía no tiene**. Este documento existe para que eso no te pare.

Lo primero, siempre:

```bash
curl --version
# curl 8.5.0 (x86_64-pc-linux-gnu) libcurl/8.5.0 OpenSSL/3.0.13 ...
# Release-Date: 2023-12-06
# Protocols: dict file ftp ftps gopher gophers http https imap imaps ...
# Features: alt-svc AsynchDNS brotli GSS-API HSTS HTTP2 HTTPS-proxy IDN IPv6 ...
```

Tres líneas, tres cosas distintas:

- **La primera** es la versión y con qué librería TLS se compiló.
- **`Protocols:`** es lo que ese binario sabe hablar. Si `http3` no aparece, no
  hay `--http3` que valga: el flag existirá y fallará.
- **`Features:`** es lo que se activó al compilar. `HTTP2`, `brotli` y `HSTS`
  salen aquí, no en `Protocols`.

> [!IMPORTANT]
> Un flag puede existir en tu versión y aun así fallar, porque la *feature* no
> se compiló. Es la confusión más frecuente con `--http3` y con `--compressed`
> para brotli. Mira siempre las dos líneas.

---

## Qué trae cada distribución

Datos comprobados en agosto de 2026 contra los repositorios oficiales.

| Distribución | Versión de curl | Nota |
|---|---|---|
| Ubuntu 20.04 (focal) | 7.68.0 | Sin `--fail-with-body`, sin `--json`, sin `--retry-all-errors` |
| **Ubuntu 22.04 (jammy)** | **7.81.0** | La más común entre alumnos. **Sin `--json`** |
| Ubuntu 24.04 (noble) | 8.5.0 | Todo lo que usa el bootcamp |
| Ubuntu 25.04 (plucky) | 8.12.1 | |
| Debian 11 (bullseye) | 7.74.0 | Sin `--fail-with-body` |
| Debian 12 (bookworm) | 7.88.1 | Tiene `--json`; sin `--variable` |
| Debian 13 (trixie) | 8.14.1 | |

Para cualquier otra: `curl --version`. Es la única respuesta que no envejece.

Si tu versión se queda corta, tienes tres salidas, en este orden:

1. **Usar la alternativa larga.** Casi todos los flags nuevos son azúcar sobre
   algo que ya existía. La tabla de abajo la da.
2. **Instalar un curl más nuevo** desde los backports de tu distribución.
3. **Usar el contenedor del laboratorio**, que trae una versión reciente:

   ```bash
   docker run --rm --network bc-curl-lab_default \
     curlimages/curl:8.21.0 -s http://httpbin:8080/get
   ```

---

## Cuándo entró cada flag

Fuente: [`docs/options-in-versions`](https://github.com/curl/curl/blob/master/docs/options-in-versions)
del repositorio oficial. **Antes de escribir un flag nuevo en el material,
compruébalo ahí.**

### Flags que el bootcamp da por supuestos

Todos anteriores a 7.68, así que están en cualquier distribución con soporte.

| Flag | Desde | Semana |
|---|:--:|:--:|
| `-v` / `--verbose` | 4.0 | 01 |
| `-s` / `--silent` | 4.0 | 01 |
| `-I` / `--head` | 4.0 | 01 |
| `-f` / `--fail` | 4.0 | 01 |
| `-m` / `--max-time` | 4.0 | 01 |
| `-O` / `--remote-name` | 4.0 | 04 |
| `-r` / `--range` | 4.0 | 04 |
| `-x` / `--proxy` | 4.0 | 06 |
| `-C` / `--continue-at` | 4.8 | 04 |
| `-K` / `--config` | 4.10 | 06 |
| `-H` / `--header` | 5.0 | 02 |
| `-F` / `--form` | 5.0 | 04 |
| `-E` / `--cert` | 5.0 | 05 |
| `--cacert` | 7.5 | 05 |
| `-w` / `--write-out` | 6.5 | 06 |
| `--connect-timeout` | 7.7 | 05 |
| `-c` / `--cookie-jar` | 7.9 | 05 |
| `--trace` / `--trace-ascii` | 7.9.7 | 06 |
| `--compressed` | 7.10 | 02 |
| `--limit-rate` | 7.10 | 04 |
| `-k` / `--insecure` | 7.10 | 05 (solo como antipatrón) |
| `--location-trusted` | 7.10.4 | 05 |
| `--max-filesize` | 7.10.8 | 04 |
| `--retry` | 7.12.3 | 05 |
| `--form-string` | 7.13.2 | 04 |
| `--trace-time` | 7.14.0 | 06 |
| `--libcurl` | 7.16.1 | 06 |
| `--data-urlencode` | 7.18.0 | 02 |
| `-J` / `--remote-header-name` | 7.20.0 | 04 |
| `--resolve` | 7.21.3 | 05 |
| `--netrc-file` | 7.21.5 | 03 |
| `--http2` | 7.33.0 | 09 |
| `--oauth2-bearer` | 7.33.0 | 08 |
| `-:` / `--next` | 7.36.0 | 09 |
| `--unix-socket` | 7.40.0 | 06 |
| `--tlsv1.3` | 7.52.0 | 05 |
| `--retry-connrefused` | 7.52.0 | 05 |
| `--fail-early` | 7.52.0 | 07 |
| `--doh-url` | 7.62.0 | 05 |
| `--alt-svc` | 7.64.1 | 09 |
| `Retry-After` respetado por `--retry` | 7.66.0 | 07 |
| `-Z` / `--parallel` | 7.66.0 | 09 |
| `--parallel-max` | 7.66.0 | 09 |
| `--http3` | 7.66.0 | 09 |
| `--no-progress-meter` | 7.67.0 | 06 |
| `--etag-save` / `--etag-compare` | 7.68.0 | 09 |

### Flags que hay que marcar en el material

Posteriores a 7.68. **Cada vez que uses uno, dilo en el propio ejemplo y da la
alternativa.**

| Flag | Desde | Semana | Alternativa si no lo tienes |
|---|:--:|:--:|---|
| `--retry-all-errors` | 7.71.0 | 07 | Bucle `for` con `sleep` y comprobación del código de salida |
| `--output-dir` | 7.73.0 | 04 | `mkdir -p dir && cd dir && curl -O ...` |
| `--hsts` | 7.74.0 | 05 | Ninguna directa; es opcional en el bootcamp |
| `--aws-sigv4` | 7.75.0 | 08 | Firmar a mano con `openssl dgst -sha256 -hmac` |
| **`--fail-with-body`** | **7.76.0** | **07** | `-f` a secas, perdiendo el cuerpo del error; o `-w '%{http_code}'` y comparar en bash |
| **`--json`** | **7.82.0** | **02** | `-H 'Content-Type: application/json' -H 'Accept: application/json' -d '...'` — exactamente lo que hace el flag |
| `--remove-on-error` | 7.83.0 | 04 | `curl -o f ... \|\| rm -f f` |
| `--url-query` | 7.87.0 | 02 | `--data-urlencode` con `-G` |
| `--trace-ids` | 8.2.0 | 06 | Lanzar las transferencias por separado, una traza cada una |
| `--variable` | 8.3.0 | 06 | Variables de bash normales |
| `--trace-config` | 8.3.0 | 06 | `-v` o `--trace-ascii`, sin el detalle por componente |

> [!WARNING]
> `--json` es el caso que más muerde. Es de 7.82 y **Ubuntu 22.04 trae 7.81**.
> Está a una versión de distancia. En el material siempre va con su equivalente
> largo al lado.

### Variables de `--write-out` que hay que marcar

Una variable de `-w` que tu curl no conoce **no da error**: avisa en stderr y
sale con 0. `%header{}` en 7.81 ni siquiera avisa: imprime el texto literal.
Por eso estas se marcan igual que los flags.

| Variable | Desde | Semana | Alternativa en 7.81 |
|---|:--:|:--:|---|
| `%{json}` | 7.70.0 | 06 | — (7.81 la tiene) |
| `%{exitcode}`, `%{errormsg}`, `%{onerror}`, `%{url}` | 7.75.0 | 06 | — (7.81 las tiene) |
| `%{header_json}` | 7.83.0 | 06 | `-D -` y `awk` |
| `%header{nombre}` | 7.84.0 | 06 | `-D - -o /dev/null \| tr -d '\r' \| awk ...` |
| `%{certs}` | 7.88.0 | 05 | `openssl s_client -showcerts` |
| `%{num_retries}` | 8.9.0 | 05 | Contar las líneas `Will retry` de stderr |
| `%{time_posttransfer}` | 8.10.0 | 09 | — |
| `%{time_queue}` | 8.12.0 | 09 | — |

---

## Comportamientos que cambiaron entre 7.81 y 8.x

No son flags nuevos: es el mismo comando, que hace otra cosa según la versión.
Comprobados con 7.81.0 (Ubuntu 22.04) y la imagen `curlimages/curl:8.17.0`.

| Comando | En 7.81 | En 8.x | Semana |
|---|---|---|:--:|
| `--fail --fail-with-body` | Error de uso: `is badly used here`, sale con 2 | Se acepta | 07 |
| `--retry N -o /dev/null` con un cuerpo no vacío | El reintento sale con `(23) Failed to truncate file` | Funciona | 07 |
| `-w '%header{nombre}'` | Imprime el texto literal, sin error | El valor del header (7.84+) | 06 |
| Configuración en `$XDG_CONFIG_HOME` | Lee `.curlrc` | Lee `curlrc`, sin punto | 06 |

## `--http3` merece un párrafo aparte

`--http3` existe desde 7.66, pero **el soporte de HTTP/3 casi nunca se compila**.
No lo trae ninguna distribución mayor, y tampoco la imagen oficial
`curlimages/curl`. Si tu binario no lo tiene, el flag ni siquiera se acepta:

```bash
curl --http3 https://localhost:8443/get
# curl: option --http3: the installed libcurl version does not support this
# curl: try 'curl --help' or 'curl --manual' for more information
echo $?
# 2
```

Cómo saberlo antes de intentarlo — `HTTP3` sale en `Features:`, no en
`Protocols:`:

```bash
curl --version | grep -o HTTP3
# HTTP3     ← si no imprime nada, tu curl no lo soporta
```

En la Semana 09, si tu binario no lo trae, se usa un contenedor que sí:

```bash
# ymuski/curl-http3 se compila con BoringSSL + quiche, que es lo que HTTP/3
# necesita. `curlimages/curl` NO sirve para esto: no trae HTTP3 en Features.
docker run --rm --network bc-curl-lab_default \
  -v "$PWD/docs/lab-ca.pem:/ca.pem:ro" ymuski/curl-http3:8.2.1 \
  curl --http3 --cacert /ca.pem -s -o /dev/null -w '%{http_version}\n' \
  https://tls:8443/get
# 3
```

El laboratorio sirve HTTP/3 desde el primer día: el que falta es tu cliente,
no el servidor. Dentro de la red del laboratorio el endpoint TLS responde al
nombre `tls`, no a `localhost`; el certificado cubre los dos.

---

## Política del repositorio

- El material se escribe contra **7.81 como suelo**. Todo lo posterior se marca.
- La versión de referencia del laboratorio es la de la imagen
  `curlimages/curl` fijada en los ejemplos que la usan. **Nunca `latest`.**
- Antes de subir la versión de referencia: comprobar que el tag existe, mirar
  las [vulnerabilidades publicadas](https://curl.se/docs/vulnerabilities.html)
  y actualizar este archivo.

---

## Referencias

- [Cuándo entró cada opción](https://github.com/curl/curl/blob/master/docs/options-in-versions)
- [Changelog de curl](https://curl.se/changes.html)
- [Vulnerabilidades](https://curl.se/docs/vulnerabilities.html)
- [Manpage](https://curl.se/docs/manpage.html)

---

[← Volver a la documentación](README.md)
