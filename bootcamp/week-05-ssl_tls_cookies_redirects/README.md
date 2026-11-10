# Semana 05 — SSL/TLS, cookies y redirects

> El laboratorio de las semanas anteriores siempre respondía, siempre en
> `http://`, siempre a la primera. La red de verdad tiene CAs que tu curl no
> conoce, servidores que te piden certificado, sesiones, redirects que llevan
> a otro sitio y servicios que tardan o fallan un segundo. Esta semana curl
> aprende a desconfiar con criterio.

---

## 🎯 Objetivos de la Semana

Al terminar serás capaz de:

- Leer un handshake TLS en `-v` y explicar qué comprueba curl del certificado: cadena, nombre y fechas
- Resolver un error **60** presentando la CA correcta con `--cacert`, `CURL_CA_BUNDLE` o `--capath`, **nunca** con `-k`
- Distinguir un 60 (el certificado no cuadra) de un 35 (no hubo handshake), y saber qué hace `--cacert` con las CAs públicas en el curl de Ubuntu
- Abrir el certificado que presenta un servidor con `openssl s_client` y `x509`, y probar un nodo concreto con `--resolve` y `--connect-to`
- Autenticarte con un certificado de cliente (mTLS) con `--cert` y `--key`, con la clave protegida y su frase fuera del argv
- Mantener una sesión con un tarro de cookies, entender su formato y protegerlo con permisos 600
- Seguir redirects con `-L` sabiendo cuándo cambia el método, qué credenciales se quitan al cambiar de host y cómo impedir que se baje de HTTPS a HTTP
- Poner `--connect-timeout` y `--max-time` con valores medidos, y distinguir los dos timeouts por su mensaje
- Reintentar con `--retry` lo que se puede reintentar, acotando el tiempo total, y explicar por qué un POST no se reintenta

---

## 📋 Prerrequisitos

- **Semana 04 completada**: `api-toolkit.sh` con `download` y `upload`, y `./scripts/verificar-semana.sh 04` en verde
- **El laboratorio levantado con el script**: `./scripts/start.sh` arranca el frontal HTTPS (8443), el mTLS (8444) y **exporta la CA** a `docs/lab-ca.pem` — ver [setup-entorno](../../docs/setup-entorno.md)
- **`openssl` instalado**: `openssl version`. Viene con cualquier distribución
- **`jq` instalado**: `jq --version`
- **Saber leer la salida de `-v`**: líneas `*` son información de curl, `>` lo que envías, `<` lo que recibes
- **Tu versión de curl a mano**: `curl --version | head -1`. Esta semana aparecen `%{certs}` (7.88+) y `%{num_retries}` (8.9+); en 7.81 no existen y se da la alternativa

---

## 🗂️ Estructura de la Semana

```
week-05-ssl_tls_cookies_redirects/
├── README.md                  # Este archivo
├── rubrica-evaluacion.md      # Cómo se evalúa
├── checks.json                # Las 21 comprobaciones automáticas
├── 0-assets/                  # Diagramas
├── 1-teoria/                  # 8 archivos, un concepto cada uno
├── 2-practicas/               # 4 prácticas sobre el laboratorio
├── 3-proyecto/                # La capa 5 de api-toolkit: red hostil
├── 4-recursos/                # Libros, vídeos y enlaces
└── 5-glosario/                # Términos de esta semana
```

---

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01 — Qué hace TLS por ti](1-teoria/01-que-hace-tls-por-ti.md) | Las tres garantías, el handshake en `-v`, las comprobaciones del certificado, los códigos 35 y 60, `--tlsv1.2` | 15 min |
| [02 — Confiar en una CA propia](1-teoria/02-confiar-en-una-ca-propia.md) | La cadena de confianza, CAfile y CApath, `--cacert`, `CURL_CA_BUNDLE`, `--capath` y `openssl rehash` | 15 min |
| [03 — Inspeccionar un certificado](1-teoria/03-inspeccionar-un-certificado.md) | `openssl s_client` y `x509`, el SNI, `-checkend`, `--resolve`, `--connect-to`, `--pinnedpubkey` | 15 min |
| [04 — Certificado de cliente: mTLS](1-teoria/04-certificado-de-cliente-mtls.md) | El `Certificate Request`, `--cert` y `--key`, los códigos 56 y 58, claves cifradas y formatos | 15 min |
| [05 — Cookies y sesiones](1-teoria/05-cookies-y-sesiones.md) | `Set-Cookie`, `-b`, `-c`, el formato del tarro, el motor de cookies con `-L`, permisos y `-j` | 15 min |
| [06 — Redirects](1-teoria/06-redirects.md) | `-L`, `--max-redirs`, el método tras 301/302/303/307/308, credenciales entre hosts, `--proto-redir` | 15 min |
| [07 — Timeouts](1-teoria/07-timeouts.md) | Las fases de una petición, `--connect-timeout`, `--max-time`, los dos mensajes del 28 | 15 min |
| [08 — Reintentos](1-teoria/08-reintentos.md) | `--retry` y qué es transitorio, la espera creciente, `--retry-max-time`, idempotencia | 15 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01 — Confiar y verificar](2-practicas/01-confiar-y-verificar.md) | Provocar el 60 y el 35, presentar la CA de tres formas, abrir el certificado, `--resolve` y un pin roto | 50 min |
| [02 — Certificado de cliente](2-practicas/02-certificado-de-cliente.md) | Generar un par con la clave en 600, entrar al frontal mTLS, los tres 58 y una clave cifrada | 50 min |
| [03 — Sesiones y redirects](2-practicas/03-sesiones-y-redirects.md) | Una sesión en tres comandos, el tarro por dentro, el método tras cada redirect y las credenciales entre hosts | 50 min |
| [04 — Timeouts y reintentos](2-practicas/04-timeouts-y-reintentos.md) | Medir fases, los dos 28, ver la espera creciente, calcular el peor caso y reintentar un POST a propósito | 50 min |

### Proyecto

La **capa 5** de tu plataforma: `api-toolkit.sh` sale a la red hostil. Una
función, `construir_red`, decide para todas las peticiones con qué CA validar
(`API_CACERT`), con qué certificado presentarse (`API_CLIENT_CERT` y
`API_CLIENT_KEY`), dónde guardar la sesión (`COOKIE_JAR`), cuándo seguir un
redirect y cuándo reintentar. Los fallos sin respuesta HTTP salen con 69 y
una causa en palabras. Detalles en [3-proyecto](3-proyecto/README.md).

---

## ⏱️ Distribución del Tiempo (8 horas)

| Bloque | Tiempo |
|---|:--:|
| Teoría (8 archivos) | 2 h 00 |
| Prácticas (4 × 50 min) | 3 h 20 |
| Proyecto | 2 h 00 |
| Revisión y verificación | 40 min |
| **Total** | **8 h 00** |

> [!TIP]
> Haz las prácticas 01 y 02 antes de tocar los TODOs 1 y 2 del proyecto. Un
> 60, un 35, un 56 y un 58 se parecen mucho hasta que has provocado cada uno a
> propósito; después se leen solos.

---

## 🌐 Cada flag de red responde a un fallo

Un comando de curl "de producción" parece una lista de flags que alguien copió
de Stack Overflow. No lo es: cada uno cierra un fallo concreto, y quitarlo es
volver a dejar ese fallo abierto.

| Fallo | Qué pasa sin defensa | Flag | Código si salta |
|---|---|---|---|
| El servidor usa una CA interna | 60, y la tentación del `-k` | `--cacert` | — |
| El servidor exige certificado de cliente | 56 con `alert certificate required` | `--cert` y `--key` | — |
| Un host que no responde | 300 s esperando a conectar | `--connect-timeout 5` | 28 |
| Un servidor colgado | Espera indefinida | `--max-time 10` | 28 |
| Un 503 de un segundo | El script falla por nada | `--retry 3` | — |
| Un servicio reiniciando | Conexión rechazada, sin reintento | `--retry-connrefused` | — |
| Reintentos que se acumulan | Minutos de espera | `--retry-max-time 30` | — |
| Un bucle de redirects | 50 peticiones antes de fallar | `--max-redirs 5` | 47 |
| Un salto de HTTPS a HTTP | La siguiente petición en claro | `--proto-redir '=https'` | 1 |

```bash
# Todas juntas. Es el comando que acaba dentro de api-toolkit get.
curl --fail-with-body -sS \
  --connect-timeout 5 --max-time 10 \
  --retry 3 --retry-connrefused --retry-max-time 30 \
  -L --max-redirs 5 --proto-redir '=https' \
  --cacert docs/lab-ca.pem \
  https://localhost:8443/redirect/2
```

Y dos que **no** van en ese comando aunque lo parezca: `--retry` en un POST
(duplica lo que crea) y `-L` con una API key en un header propio (la manda al
host nuevo).

---

## 🎩 Trucos y atajos

| Truco | Cómo |
|---|---|
| Ver qué CAs usa tu curl por defecto | `curl -sv https://host/ -o /dev/null 2>&1 \| grep -E 'CAfile\|CApath'`. En Ubuntu, `--cacert` cambia el CAfile pero el CApath sigue |
| Confiar **solo** en tu CA, sea cual sea el curl | `curl --cacert ca.pem --capath /dev/null URL`. Sin el `--capath`, el curl de Ubuntu sigue aceptando las CAs públicas |
| Ver el certificado que presenta un servidor | `openssl s_client -connect host:443 -servername host </dev/null 2>/dev/null \| openssl x509 -noout -subject -issuer -enddate -ext subjectAltName` |
| Avisar antes de que caduque un certificado | `... \| openssl x509 -noout -checkend 1209600`. Sale con 1 si caduca en menos de 14 días |
| Probar un nodo concreto de un balanceador | `curl --resolve host:443:10.0.0.5 https://host/`. La URL no cambia: el SNI y la verificación siguen siendo los de `host` |
| Comprobar que un certificado y una clave casan | `openssl x509 -in c.crt -noout -pubkey \| openssl dgst -sha256` y `openssl pkey -in c.key -pubout \| openssl dgst -sha256`: las dos huellas iguales |
| La frase de una clave cifrada sin que salga en `ps` | `pass = "..."` en un archivo con permisos 600, y `--config archivo`. Nunca `--pass` ni `--cert c.pem:frase` |
| Encender el motor de cookies sin mandar ninguna | `curl -L -b '' URL`. Sin él, la cookie que fija un login con redirect se pierde en el salto |
| Leer el tarro sin perder las cookies `HttpOnly` | `awk -F'\t' 'NF == 7 { print $6 "=" $7 }' tarro.txt`. Un `grep -v '^#'` se lleva las líneas `#HttpOnly_` |
| Ver a dónde lleva un redirect sin seguirlo | `curl -s -o /dev/null -w '%{redirect_url}\n' URL` |
| `--proto-redir` en zsh | `--proto-redir '=https'`, con comillas. Sin ellas, zsh lo expande y falla con `zsh: https not found` |
| Distinguir los dos timeouts | El mensaje del 28: `Connection timeout after` es `--connect-timeout`; `Operation timed out after` es `--max-time` |

---

## 📌 Entregables

1. `tls.md` con el 60 y el 35 provocados, las tres formas de presentar la CA y lo que hace el CApath del sistema con `--cacert`
2. `certificado.md` con la huella de la CA del laboratorio, los campos del certificado del servidor, su duración y el pin roto
3. `mtls.md` con el 56 sin certificado, los tres 58 del lado del cliente y la clave cifrada usada sin la frase en el argv
4. Una clave privada de cliente con permisos 600 desde su creación
5. `sesion.md` con una sesión de tres comandos, el tarro explicado columna a columna y el efecto de `-j`
6. `redirects.md` con la tabla del método tras 301/302/303/307/308 y qué credenciales viajan a otro host
7. `resiliencia.md` con las fases medidas, los dos 28 distinguidos, el cálculo del peor caso con reintentos y por qué un POST no se reintenta
8. `api-toolkit.sh` con `construir_red` completa y ningún `TODO` pendiente
9. El toolkit valida contra el frontal HTTPS con `API_CACERT` y falla con 69 sin ella
10. El toolkit entra al frontal mTLS con `API_CLIENT_CERT` y `API_CLIENT_KEY`, y rechaza una clave con 644
11. `COOKIE_JAR` mantiene la sesión entre llamadas en un tarro con permisos 600
12. `get` sigue redirects sin bajar a HTTP ni filtrar una API key; `post` ni sigue redirects ni reintenta; ningún `-k`

---

## ✅ Verificación

```bash
./scripts/start.sh
./scripts/verificar-semana.sh 05
```

Las 21 comprobaciones tienen que pasar. Si alguna falla, la pista te dice en qué
TODO del proyecto se arregla.

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [Semana 04 — Archivos, formularios y multipart](../week-04-archivos_formularios_multipart/README.md) | **Semana 05 — SSL/TLS, cookies y redirects** | [Semana 06 — Output, debug y configuración](../week-06-output_debug_configuracion/README.md) |

[← Volver al inicio del bootcamp](../README.md)
