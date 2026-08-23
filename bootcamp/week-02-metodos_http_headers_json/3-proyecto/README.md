# Proyecto Semana 02 — La capa de los verbos

## 🎯 Objetivo

`api-toolkit.sh` deja de ser un explorador de solo lectura y aprende a escribir.
Cuatro subcomandos — `get`, `post`, `put`, `delete` — con el cuerpo JSON y los
headers correctos, más un `--dry-run` que imprime el comando en vez de
ejecutarlo.

```
api-toolkit.sh [--dry-run] <get|post|put|delete> ENDPOINT [DATOS]
```

El punto de partida está en [`starter/api-toolkit.sh`](starter/api-toolkit.sh),
con cinco `TODO` numerados. Es el punto de partida, **no la solución**.

---

## 📦 Qué añade esta capa

La Semana 01 dejó `api-explorer.sh`: consultaba URLs e imprimía código de estado
y tiempo. Sabía leer y nada más.

| | Semana 01 | Semana 02 |
|---|---|---|
| Métodos | GET implícito | GET, POST, PUT, DELETE explícitos |
| Cuerpo | Ninguno | JSON, con `Content-Type` declarado |
| Headers | Los que pone curl | `Content-Type` y `Accept` propios |
| Seguridad al probar | Ninguna: lo que ejecutas, pasa | `--dry-run` |
| Salida | Código y tiempo | El cuerpo de la respuesta, más un código de salida acorde |

**Qué desbloquea en la Semana 03**: en cuanto la API está autenticada hay que
añadir un `Authorization` a cada petición. Con `construir_args()` centralizando
la construcción de la petición, eso es una línea en un sitio. Sin esa función,
son cuatro sitios y uno se olvida.

> [!IMPORTANT]
> Tu copia de trabajo vive **fuera** de este repositorio. El material es este
> repo; la entrega es tuya:
>
> ```bash
> cp starter/api-toolkit.sh ~/api-toolkit.sh
> chmod +x ~/api-toolkit.sh
> ```

---

## ✅ Requisitos verificables

Cada línea es, palabra por palabra, la descripción de una comprobación de
[`checks.json`](../checks.json). Si una falla, esta es la lista donde mirar.

1. El laboratorio acepta POST en /post
2. api-toolkit.sh existe, es ejecutable y arranca con set -euo pipefail
3. No quedan marcadores TODO sin resolver en el script
4. El subcomando get imprime el cuerpo de la respuesta
5. El subcomando post envia el cuerpo JSON que se le pasa
6. El subcomando post declara Content-Type: application/json
7. El subcomando put usa el metodo PUT
8. El subcomando delete usa el metodo DELETE
9. --dry-run imprime el comando curl que se habria ejecutado
10. --dry-run no llega a hacer la peticion
11. El script sale distinto de 0 cuando la API responde 404
12. El script no se queda colgado cuando el servidor tarda demasiado
13. El script no desactiva la verificacion del certificado con -k
14. El script pasa shellcheck sin avisos

```bash
./scripts/verificar-semana.sh 02
```

---

## 🎨 Criterios de calidad

Lo que el autograding no ve y la rúbrica sí:

| Criterio | Qué se mira |
|---|---|
| **Los mensajes de error van a `stderr`** | Si van a stdout, un `api-toolkit.sh get /x \| jq` se traga el error como si fueran datos |
| **El cuerpo se imprime aunque la petición falle** | En un 422 el cuerpo es donde la API dice qué campo está mal. Tirarlo es tirar el diagnóstico |
| **Una sola petición para código y cuerpo** | `-w '\n%{http_code}'` y separar en bash. Dos peticiones son dos estados distintos del servidor |
| **`--data-raw`, no `-d`, para el cuerpo que llega por argumento** | Viene de fuera: si empieza por `@`, `-d` abre un archivo, y si no existe manda un cuerpo vacío **sin fallar** |
| **`--request`, no `-X`** | Se lee solo dentro de seis meses, y `-x` es otra cosa (`--proxy`) |
| **`--max-time` en todas las peticiones** | Sin él, un servidor colgado cuelga el script para siempre |
| **Los argumentos de curl en un array** | Una cadena se rompe en cuanto un valor lleva un espacio dentro |
| **El `--dry-run` es copiable y pegable** | `printf ' %q'` entrecomilla como lo haría el shell |
| **Sin secretos en el código** | Ni un token, ni un `<TOKEN>` con formato válido, ni en un comentario |

---

## 💡 Adaptación a tu dominio

`BASE_URL` es lo único que cambia. Los cuatro verbos son los mismos en cualquier
API REST:

| Dominio | `BASE_URL` | Prueba de escritura segura |
|---|---|---|
| GitHub | `https://api.github.com` | `post /gists` con un gist privado, y `delete` después |
| Open-Meteo | `https://api.open-meteo.com` | Es de solo lectura: usa `--dry-run` para los verbos de escritura |
| TfL | `https://api.tfl.gov.uk` | Solo lectura también: `get /Line/Mode/tube/Status` |
| The Movie DB | `https://api.themoviedb.org` | `post /3/list` con una lista de prueba tuya |

> [!WARNING]
> Contra tu API real, **usa `--dry-run` antes de cada `delete`**. Es literalmente
> para lo que existe. Y si tu dominio es de solo lectura, es la única forma de
> probar los verbos de escritura sin inventarte otro servidor.

```bash
# El endpoint de tu dominio, sin ejecutar nada.
BASE_URL=https://api.ejemplo.com ./api-toolkit.sh --dry-run delete /v1/usuarios/42
# curl --max-time 10 --request DELETE --silent --show-error \
#   --write-out '\n%{http_code}' https://api.ejemplo.com/v1/usuarios/42
```

---

## 🚦 Cómo entregarlo

1. Copia el starter fuera del repositorio y hazlo ejecutable
2. Resuelve los cinco `TODO`, en orden: el 1 y el 2 construyen la petición, el 3 es el `--dry-run`, el 4 el código de salida y el 5 la validación de argumentos
3. Elimina **todos** los marcadores `TODO`, incluidos los de la cabecera
4. Comprueba que pasa `shellcheck -S warning`
5. Ejecuta `./scripts/verificar-semana.sh 02` y que las catorce estén en verde
6. Entrega el script, `respuestas.md`, `crud.log` y `cabeceras.txt` sin el token real dentro

```bash
shellcheck -S warning ~/api-toolkit.sh
./scripts/verificar-semana.sh 02
```

---

## 🧯 Errores comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `unbound variable: ARGS_CURL` | El array se usa antes de inicializarlo | `ARGS_CURL=()` al principio de `construir_args` |
| El cuerpo llega vacío y no falla nada | Usaste `-d` con un valor que empieza por `@` | `--data-raw` |
| El `--dry-run` ejecuta la petición | Falta el `exit 0` después de imprimir | `imprimir_dry_run; exit 0` |
| `%{http_code}` sale pegado al cuerpo | Falta el `\n` delante en el `--write-out` | `--write-out '\n%{http_code}'` |
| El script sale con 0 ante un 404 | El `TODO 4` sigue sin resolver | Compara el código con 400 |
| `[: 000: integer expression expected` | El `000` no es un número comparable | Trátalo aparte antes de comparar |
| `post` sin datos hace la petición igual | Falta la validación del `TODO 5` | `error "post necesita un cuerpo JSON"` |
| `shellcheck` avisa de `SC2086` | Una variable sin comillas | Ponle comillas. Siempre |
| `shellcheck` avisa de `SC2034` | Declaraste algo que no usas | O lo usas, o lo borras |
| El comando del `--dry-run` no se puede pegar | Usaste `echo` en vez de `printf ' %q'` | `printf ' %q' "${ARGS_CURL[@]}"` |

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [Proyecto Semana 01](../../week-01-http_y_curl_basico/3-proyecto/README.md) | **Proyecto Semana 02 — La capa de los verbos** | [Proyecto Semana 03](../../week-03-autenticacion_basica/3-proyecto/README.md) |

[← Volver a la Semana 02](../README.md)
