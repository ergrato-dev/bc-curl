# Semana 03 — Autenticación básica

> Hasta ahora la API te dejaba entrar. Esta semana aprendes a identificarte, y
> sobre todo a que la credencial no acabe en `ps`, en el historial ni en un log.

---

## 🎯 Objetivos de la Semana

Al terminar serás capaz de:

- Distinguir autenticación de autorización, y leer un `401` y un `403` como lo que son: dos problemas distintos
- Usar Basic Auth con `-u`, decir exactamente qué header genera y por qué base64 no protege nada
- Leer el reto `WWW-Authenticate` del servidor y saber qué esquema te está pidiendo
- Sacar la credencial de la línea de comandos con `--config`, `--netrc-file` y `-H @archivo`, y **demostrar con `ps` que ya no está**
- Enviar una API key por header, y explicar por qué en la query string se filtra aunque vaya por HTTPS
- Montar el flujo `login → token → petición autenticada` y guardar el token sin escribirlo en el disco a lo bruto
- Decodificar el payload de un JWT con `base64`, leer su `exp` y decir si ya caducó — sin librerías
- Elegir entre `--basic`, `--digest`, `--oauth2-bearer` y `--anyauth`, y saber cuál manda la credencial antes de que se la pidan
- Escribir un script que salga con un código distinto ante un `401` que ante un `500`, porque uno se reintenta y el otro no

---

## 📋 Prerrequisitos

- **Semana 02 completada**: `api-toolkit.sh` con los cuatro verbos, `--dry-run` funcionando y `./scripts/verificar-semana.sh 02` en verde
- **El laboratorio levantado**: `./scripts/start.sh` — ver [setup-entorno](../../docs/setup-entorno.md)
- **`jq` instalado**: `jq --version`
- **`base64` disponible** (viene en coreutils en Linux y en macOS): `echo aG9sYQ== | base64 -d`
- **Tu archivo `~/.bc-curl` creado y con permisos 600**, de la Semana 01. Esta semana empieza a guardar credenciales de verdad: `ls -l ~/.bc-curl` tiene que enseñar `-rw-------`
- **Tu dominio elegido** para `api-toolkit`: ver [proyecto-hilo-conductor](../../docs/proyecto-hilo-conductor.md)

---

## 🗂️ Estructura de la Semana

```
week-03-autenticacion_basica/
├── README.md                  # Este archivo
├── rubrica-evaluacion.md      # Cómo se evalúa
├── checks.json                # Las 17 comprobaciones automáticas
├── 0-assets/                  # Diagramas
├── 1-teoria/                  # 8 archivos, un concepto cada uno
├── 2-practicas/               # 4 prácticas sobre el laboratorio
├── 3-proyecto/                # La capa 3 de api-toolkit: las credenciales
├── 4-recursos/                # Libros, vídeos y enlaces
└── 5-glosario/                # Términos de esta semana
```

---

## 📝 Contenidos

### Teoría

| Archivo | Tema | Duración |
|---|---|:--:|
| [01 — Autenticación y autorización](1-teoria/01-autenticacion-y-autorizacion.md) | Quién eres frente a qué puedes hacer. El reto `WWW-Authenticate`, 401 y 403 | 15 min |
| [02 — Basic Auth](1-teoria/02-basic-auth.md) | `-u`, el header que genera, base64 no es cifrado, el `realm` | 15 min |
| [03 — Dónde no poner la credencial](1-teoria/03-donde-no-poner-la-credencial.md) | `ps`, historial, logs. `--config`, `--netrc-file`, `-H @archivo` y los permisos | 15 min |
| [04 — API keys](1-teoria/04-api-keys.md) | Header frente a query string. Por qué la query se filtra incluso con TLS | 15 min |
| [05 — Bearer y el flujo de login](1-teoria/05-bearer-y-el-flujo-de-login.md) | `Authorization: Bearer`, `--oauth2-bearer` (7.61+), login → token → petición | 15 min |
| [06 — El JWT por dentro](1-teoria/06-jwt-por-dentro.md) | Las tres partes, base64url y su relleno, `exp`, y por qué el cliente no valida la firma | 15 min |
| [07 — Digest y la negociación del esquema](1-teoria/07-digest-y-la-negociacion-del-esquema.md) | `--digest`, `--anyauth`, la petición extra que cuesta, cuándo aparecen todavía | 15 min |
| [08 — Cuando la credencial falla](1-teoria/08-cuando-la-credencial-falla.md) | 401 frente a 403, expiración, qué se reintenta y qué no, códigos de salida | 15 min |

### Prácticas

| Práctica | Qué haces | Duración |
|---|---|:--:|
| [01 — Basic Auth y el reto](2-practicas/01-basic-auth-y-el-reto.md) | `-u` contra el laboratorio, leer el `WWW-Authenticate`, reconstruir el header a mano | 50 min |
| [02 — Sacar la credencial de la línea](2-practicas/02-sacar-la-credencial-de-la-linea.md) | `--config`, `--netrc-file`, `-H @archivo`, permisos, y la prueba con `ps` | 50 min |
| [03 — Bearer y el JWT por dentro](2-practicas/03-bearer-y-el-jwt-por-dentro.md) | Flujo de login, guardar el token, decodificar el payload y leer el `exp` | 50 min |
| [04 — Cuando la credencial falla](2-practicas/04-cuando-la-credencial-falla.md) | Distinguir 401 de 403 de 500 en un script, y decidir qué se reintenta | 50 min |

### Proyecto

La **capa 3** de tu plataforma: `api-toolkit.sh` aprende a autenticarse. Cuatro
modos (`none`, `basic`, `bearer`, `apikey`), la credencial leída del entorno o
de `~/.bc-curl`, **nunca en la línea de comandos**, un `--dry-run` que redacta el
secreto y un código de salida propio para el `401`. Detalles en
[3-proyecto](3-proyecto/README.md).

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
> Haz la práctica 02 **antes** de tocar el proyecto. El proyecto entero gira
> alrededor de una idea — la credencial entra por referencia a un archivo, no
> por valor — y esa idea se entiende viéndola con `ps`, no leyéndola.

---

## 🔑 La regla que no se negocia

Todo lo demás de esta semana son detalles de esquema. Esto no:

> **Un secreto en la línea de comandos es un secreto publicado.**

No es una exageración. `ps -eo args` lo lee **cualquier usuario de la máquina**,
sin privilegios. Y no es el único sitio:

| Dónde acaba | Quién lo ve | Cuánto dura |
|---|---|---|
| `ps` / `/proc/<pid>/cmdline` | Cualquier usuario de la máquina | Mientras dure la petición |
| `~/.bash_history`, `~/.zsh_history` | Quien lea tu `$HOME`, y tu backup | Meses |
| El log del runner de CI | Todo el que tenga acceso al repositorio | Para siempre |
| El log de un proxy corporativo | El equipo de red | Según retención |
| Una captura de pantalla en un ticket | Internet, si el ticket es público | Para siempre |

Las tres salidas, y las tres se practican esta semana:

```bash
# Los tres llevan --fail-with-body y --max-time porque van contra una API de
# verdad: sin --fail un 401 sale con codigo 0, y sin --max-time un servidor
# colgado cuelga el script.

# 1. --config: un archivo con las opciones de curl, incluida la del secreto.
#    Vale para cualquier esquema.
curl --config ~/.api-auth --fail-with-body --max-time 30 \
  -sS https://api.ejemplo.com/v1/datos

# 2. --netrc-file: el clasico para Basic Auth, con formato propio.
curl --netrc-file ~/.netrc-api --fail-with-body --max-time 30 \
  -sS https://api.ejemplo.com/v1/datos

# 3. -H @archivo (7.55+): un header por linea, leido de un archivo.
curl -H @cabeceras.txt --fail-with-body --max-time 30 \
  -sS https://api.ejemplo.com/v1/datos
```

Los tres archivos, siempre `chmod 600`. Un archivo de credenciales legible por
todo el mundo no es un archivo de credenciales: es el mismo problema con un
paso más.

---

## 🎩 Trucos y atajos

| Truco | Cómo |
|---|---|
| Que curl **pregunte** la password en vez de escribirla | `curl -u usuario URL`. Sin los `:pass`, curl la pide por terminal y no queda en `ps` ni en el historial |
| Ver el header `Authorization` que curl genera de verdad | `curl -u user:password -o /dev/null -v URL 2>&1 \| grep -i '^> authorization'` |
| Saber qué esquema pide un servidor antes de intentar nada | `curl -s -o /dev/null -D - URL \| grep -i '^www-authenticate'` |
| Meter la credencial en un archivo de opciones de curl | `printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" > f; chmod 600 f; curl --config f URL` |
| Mandar un Bearer sin construir el header a mano | `curl --oauth2-bearer "$TOKEN" URL` (**7.61+**). Sigue yendo en el argv: en un script, `--config` |
| Que curl elija el esquema que pida el servidor | `curl --anyauth -u user:password URL`. Cuesta una petición extra: la primera se manda sin credencial, solo para leer el reto |
| Evitar esa petición extra cuando ya sabes el esquema | `curl --basic -u user:password URL`. Manda la credencial de entrada, sin esperar el 401 |
| Decodificar el payload de un JWT sin instalar nada | `cut -d. -f2 <<<"$JWT" \| tr '_-' '/+' \| base64 -d 2>/dev/null \| jq` — y si se queja, es el relleno: mira la teoría 06 |
| Saber si un JWT ya caducó, en una línea | `[ "$(date +%s)" -lt "$exp" ] && echo vigente \|\| echo caducado` |
| Comprobar que un secreto **no** está en la línea de comandos | Lanza la petición contra `/delay/3` en segundo plano y mira: `ps -eo args \| grep '^curl '` |
| Que un archivo de credenciales nazca ya con permisos 600 | `(umask 077; printf '...' > cred.txt)`. `chmod` después deja una ventana en la que es legible |
| Diferenciar "no me conozco" de "no me dejas" en un script | Código de salida propio para el 401/403. `77` es `EX_NOPERM` en `sysexits.h`, y no colisiona con los de curl |

---

## 📌 Entregables

1. `reto.md` con el `WWW-Authenticate` de los dos endpoints de la práctica 01 y la diferencia entre ellos
2. `authorization-a-mano.txt` con el header Basic reconstruido con `base64` y la comprobación de que coincide con el de `-u`
3. `prueba-ps.md` con la salida de `ps` en los dos casos de la práctica 02: credencial en el argv y credencial en `--config`
4. `cabeceras.txt` y el archivo de `--config`, ambos con permisos `600` y **sin credencial real dentro** del repositorio
5. `jwt.md` con el payload decodificado, el `exp` en fecha legible y el veredicto de si caducó
6. `clasificar-error.sh` de la práctica 04, limpio de `shellcheck`
7. `api-toolkit.sh` con los cuatro modos de autenticación y ningún `TODO` pendiente
8. La credencial **no** aparece en la línea de comandos de ningún proceso `curl`
9. `--dry-run` imprime el comando y **redacta** el secreto
10. El script sale con `77` ante un 401 o un 403, y con `1` ante otro error
11. El script se niega a leer un archivo de credenciales con permisos abiertos
12. Ningún secreto escrito dentro del script, ni ningún `-k`

---

## ✅ Verificación

```bash
./scripts/start.sh
./scripts/verificar-semana.sh 03
```

Las 17 comprobaciones tienen que pasar. Si alguna falla, la pista te dice en qué
práctica y en qué paso se arregla.

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [Semana 02 — Métodos HTTP, headers y JSON](../week-02-metodos_http_headers_json/README.md) | **Semana 03 — Autenticación básica** | [Semana 04 — Archivos, formularios y multipart](../week-04-archivos_formularios_multipart/README.md) |

[← Volver al inicio del bootcamp](../README.md)
