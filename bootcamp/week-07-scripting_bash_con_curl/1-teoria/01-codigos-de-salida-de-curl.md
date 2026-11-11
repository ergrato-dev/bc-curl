# Códigos de salida de curl

> Un script no lee mensajes de error: lee un número. curl sale con un código
> distinto para cada forma de fallar, y con 0 cuando el servidor contesta un
> 500. Saber cuál es cuál es la diferencia entre un script que se entera de
> que ha fallado y uno que sigue como si nada.

![Diagrama de los códigos de salida de curl ordenados por la fase en la que se produce cada fallo: uso y URL (2, 3, 1), DNS (6), conexión TCP (7, 28), TLS (35, 56, 60), HTTP (22 solo con --fail, 47 por redirects) y escritura local (23); debajo, la respuesta 500 sin --fail, que sale con 0](../0-assets/01-codigos-de-salida-de-curl.svg)

## 🎯 Objetivos

- Leer `$?` después de curl y saber en qué fase falló la petición
- Saber por qué un 404 o un 500 salen con 0, y qué cambia `--fail`
- Recuperar el código de curl cuando va dentro de una tubería
- Tratar cada código en un `case`, sin un `if` por cada uno

---

## 1. Qué problema resuelve

```bash
curl -sS http://localhost:8080/status/500
echo $?
# 0
```

El servidor ha dicho que algo se rompió, y curl sale con 0. No es un error de
curl: para curl, la transferencia **ha ido bien**. Pidió algo, el servidor
contestó, y curl le ha entregado la respuesta entera. Que la respuesta sea una
mala noticia es asunto tuyo.

Un script que solo mira `$?` no ve ese 500, y un cron que lanza ese script
cada noche tampoco. Esta semana va de que el script **falle cuando debe
fallar**, y empieza por saber qué significa cada número.

---

## 2. Cómo funciona

### 2.1 `$?`, el código del último comando

Todo proceso termina con un número entre 0 y 255. 0 es éxito y cualquier
otro número es un fallo. El shell guarda en `$?` el del último comando, y lo
**sobrescribe** con el siguiente:

```bash
curl -sS http://127.0.0.1:9/
echo $?      # 7: el de curl
echo $?      # 0: el del echo anterior
```

Si vas a usar el código más de una vez, guárdalo antes de hacer nada:
`rc=$?`.

### 2.2 Un código por fase

curl tiene casi cien códigos de salida. En la práctica, con HTTP aparecen una
docena, y cada uno dice **dónde** se paró la petición:

| Código | Fase | Qué pasó | Cómo provocarlo en el laboratorio |
|:--:|---|---|---|
| 0 | — | La transferencia terminó, **sea cual sea el código HTTP** | `/status/500` |
| 1 | Uso | Protocolo no soportado | `curl htp://x` |
| 2 | Uso | Opción desconocida o mal usada | `curl --nope` |
| 3 | Uso | URL mal formada | `curl "http://"` |
| 6 | DNS | El nombre no resuelve | `https://no-existe.invalid/` |
| 7 | TCP | Conexión rechazada | `http://127.0.0.1:9/` |
| 22 | HTTP | Respuesta 4xx o 5xx, **solo con `--fail`** | `--fail /status/404` |
| 23 | Local | No se pudo escribir la salida | `-o /no/existe/x` |
| 28 | Cualquiera | Timeout: `--max-time` o `--connect-timeout` | `--max-time 1 /delay/3` |
| 35 | TLS | El handshake falló | — |
| 47 | HTTP | Demasiados redirects | `-L --max-redirs 2 /redirect/5` |
| 56 | TLS / red | Fallo al recibir datos | mTLS sin certificado (`:8444`) |
| 60 | TLS | El certificado del servidor no valida | `https://localhost:8443` sin `--cacert` |

La lista completa está en `man curl`, sección *EXIT CODES*. No hace falta
memorizarla: hace falta saber que los códigos **no son intercambiables**. Un
6 en un script de CI apunta a la configuración (un host mal escrito). Un 7
apunta a un servicio caído. Un 60 apunta a un certificado. Un script que los
trata todos como "falló" tira esa información.

### 2.3 El 28 no dice cuál de los timeouts saltó

```bash
curl -sS --max-time 2 'http://localhost:8080/drip?duration=4&numbytes=4' -o /dev/null
# curl: (28) Operation timed out after 2001 milliseconds with 0 bytes received
curl -sS --connect-timeout 1 http://10.255.255.1/ -o /dev/null
# curl: (28) Connection timeout after 1000 ms
```

Los dos son 28. El código no distingue un servidor lento de un host que no
contesta; el mensaje sí. Si te importa la diferencia, `%{errormsg}` (7.75+)
te da el mensaje dentro de `-w`, o `%{time_connect}` vale 0 cuando ni siquiera
hubo conexión.

### 2.4 Por qué un 500 es 0

HTTP tiene dos capas de éxito: la transferencia y la respuesta. curl informa
de la primera con su código de salida y de la segunda con `%{http_code}`:

```bash
curl -sS -o /dev/null -w '%{http_code} %{exitcode}\n' http://localhost:8080/status/500
# 500 0
curl -sS --fail -o /dev/null -w '%{http_code} %{exitcode}\n' http://localhost:8080/status/500
# curl: (22) The requested URL returned error: 500
# 500 22
```

`--fail` mueve la frontera: con él, curl trata un 4xx o un 5xx como un fallo
de la transferencia y sale con 22. Lo que cuesta, y la alternativa que no
pierde el cuerpo, son la teoría 02. `%{exitcode}` es 7.75+; en 7.81 existe.

---

## 3. Cómo se usa

### 3.1 Un `case`, no una escalera de `if`

```bash
rc=0
curl -sS --fail-with-body --max-time 10 -o respuesta.json \
  http://localhost:8080/get || rc=$?

case "$rc" in
  0)        echo "ok" ;;
  6)        echo "el host no existe: revisa la URL" >&2 ;;
  7|28)     echo "el servicio no responde: reintenta mas tarde" >&2 ;;
  22)       echo "la API respondio con error" >&2 ;;
  35|56|60) echo "problema de TLS" >&2 ;;
  *)        echo "curl salio con $rc" >&2 ;;
esac
```

`|| rc=$?` es la forma de recoger el código **con `set -e` activo**: el
comando forma parte de un `||`, así que el shell no aborta y `rc` recibe el
número. La teoría 03 explica por qué `curl ...; rc=$?` no funciona ahí.

### 3.2 Dentro de una tubería

```bash
curl -sS http://127.0.0.1:9/ | jq .
echo $?
# 0: el de jq, que no recibió nada y no se quejó
```

Sin más, el código de una tubería es el del **último** comando. Hay dos formas
de llegar al de curl:

```bash
# PIPESTATUS: un array con el código de cada comando de la tubería
curl -sS http://localhost:8080/get | jq -e '.nada' > /dev/null
echo "${PIPESTATUS[@]}"
# 0 1

# pipefail: la tubería sale con el último código distinto de 0
set -o pipefail
curl -sS http://127.0.0.1:9/ 2>/dev/null | jq .
echo $?
# 7
```

`PIPESTATUS` hay que leerlo **justo después** de la tubería, igual que `$?`.
`pipefail` es lo que activa `set -euo pipefail`, y es la razón de su `-o
pipefail`.

### 3.3 El código en el propio `-w`

Si el script ya parsea la línea del `-w`, el código puede viajar en ella:

```bash
curl -s -o /dev/null -w '%{http_code} %{exitcode}\n' http://127.0.0.1:9/
# 000 7
```

Es lo que permite registrar en un archivo de métricas también las peticiones
que no llegaron al servidor (Semana 06, práctica 04).

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `if curl ...; then` sin `--fail` | Un 500 entra por la rama del éxito | `--fail-with-body`, o leer `%{http_code}` |
| `curl ... ; echo "ok"` | El `echo` se ejecuta pase lo que pase, y su 0 tapa el de curl | `set -e`, o `\|\| exit` |
| `curl ... \| jq` sin `pipefail` | El código es el de `jq`: un servidor caído pasa por éxito | `set -o pipefail` |
| Tratar cualquier código distinto de 0 igual | Un host mal escrito y un servicio caído piden acciones distintas | Un `case` por familias |
| Leer `$?` dos veces | El segundo es el del primer `echo` | `rc=$?` y usar `rc` |
| Comparar el texto del error | Cambia entre versiones de curl y backends TLS | Compara el número |

---

## 5. Trucos

- **`man curl`, y `/EXIT CODES`** dentro, salta a la tabla completa. Sin
  `man`: `curl --manual | grep -A3 '^ *28 '`.
- **`%{exitcode}` y `%{errormsg}`** (7.75+) en el `-w` dejan el código y el
  mensaje en la misma línea que el resto de las medidas.
- **Los códigos de salida van de 0 a 255.** Un `exit 300` sale como 44. Si
  diseñas los de tu script, quédate por debajo de 126: del 126 en adelante los
  usa el propio shell (126 no ejecutable, 127 no encontrado, 128+N señal N).

---

## 📚 Recursos Adicionales

- [Manpage de curl — Exit codes](https://curl.se/docs/manpage.html#EXIT)
- [libcurl — Error codes](https://curl.se/libcurl/c/libcurl-errors.html), con
  la descripción larga de cada uno
- [Bash Reference Manual — Pipelines](https://www.gnu.org/software/bash/manual/html_node/Pipelines.html)

---

## ✅ Checklist de Verificación

- [ ] Provocas en el laboratorio un 6, un 7, un 22, un 28 y un 60
- [ ] Sabes explicar por qué `/status/500` sale con 0
- [ ] Recuperas el código de curl en `curl | jq` de las dos formas
- [ ] Tu `case` separa los fallos de configuración de los temporales
