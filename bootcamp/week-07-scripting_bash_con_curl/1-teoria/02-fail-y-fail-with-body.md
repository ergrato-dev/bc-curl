# `--fail` y `--fail-with-body`

> Sin `--fail`, curl entrega el cuerpo de un error como si fueran datos. Con
> `--fail`, sale con error pero tira el cuerpo, que es justo donde la API
> explica qué ha pasado. `--fail-with-body` conserva las dos cosas. Y hay una
> tercera vía, la del toolkit: leer el código y decidir tú.

![Diagrama de tres columnas que compara la misma respuesta 429 con un cuerpo JSON de error: sin --fail, curl sale con 0 y el cuerpo llega a stdout como si fueran datos; con --fail, curl sale con 22 y el cuerpo se pierde; con --fail-with-body (7.76+), curl sale con 22 y el cuerpo llega a stdout o al archivo de -o](../0-assets/02-fail-y-fail-with-body.svg)

## 🎯 Objetivos

- Saber qué hace cada una de las tres formas con el cuerpo de un error
- Elegir entre `--fail-with-body` y leer `%{http_code}` según lo que el
  script necesite distinguir
- No dejar el cuerpo de un error en el archivo donde el script espera datos
- Conocer el límite de `--fail` con 401 y 407

---

## 1. Qué problema resuelve

```bash
export CA="$PWD/docs/lab-ca.pem"
curl -sS --cacert "$CA" https://localhost:8443/limitado > usuarios.json
echo $?
# 0
cat usuarios.json
# {"error":"demasiadas peticiones"}
```

El script pidió una lista de usuarios, la API respondió 429, y ahora
`usuarios.json` contiene un mensaje de error con forma de JSON válido. El
siguiente paso del script lo procesará como si fuera la lista. Si ese paso es
un `jq '.[] | .email'`, fallará con un error que no tiene nada que ver con el
problema real. Si es un `cp usuarios.json /srv/datos/`, el error llegará a
producción.

El problema no es que la API falle: es que **el script no se ha enterado**.

---

## 2. Cómo funciona

### 2.1 `--fail` (`-f`): sale con 22, sin cuerpo

```bash
curl -sS --fail --cacert "$CA" -o usuarios.json https://localhost:8443/limitado
# curl: (22) The requested URL returned error: 429
echo $?
# 22
ls usuarios.json
# ls: cannot access 'usuarios.json': No such file or directory
```

Ante un código **400 o mayor**, curl no escribe nada y sale con 22. Si había
`-o`, ni siquiera crea el archivo. El script ya se entera del fallo, pero solo
sabe el código HTTP del mensaje de stderr. El cuerpo, que en una API suele
decir *qué* campo era inválido o *cuándo* puedes volver a intentarlo, se ha
perdido.

Los 3xx no son errores para `--fail`: un 302 sin `-L` sale con 0. Con `-L`,
cuenta la última respuesta de la cadena.

### 2.2 `--fail-with-body` (7.76+): sale con 22, con cuerpo

```bash
curl -sS --fail-with-body --cacert "$CA" https://localhost:8443/limitado
# curl: (22) The requested URL returned error: 429
# {"error":"demasiadas peticiones"}
echo $?
# 22
```

Mismo código de salida, y el cuerpo llega a donde iría normalmente: a stdout,
o al archivo de `-o`. Es la opción que pide el bootcamp para todo ejemplo de
producción, y 7.81 la tiene.

En 7.81, `--fail` y `--fail-with-body` juntos son un error de uso:

```bash
curl -sS --fail --fail-with-body http://localhost:8080/get
# curl: option --fail-with-body: is badly used here
echo $?
# 2
```

Elige una. Con un `.curlrc` que lleve `--fail` y un script que pase
`--fail-with-body` pasa exactamente esto: el motivo para que un script lo
ignore con `-q` (Semana 06).

### 2.3 Lo que `--fail` no garantiza

La documentación de curl lo dice sin rodeos: el método *no es a prueba de
fallos*, y algún código de error puede colarse, **sobre todo con
autenticación (401 y 407)**. En el laboratorio un 401 sí da 22, pero no es una
garantía para cualquier servidor y cualquier esquema de autenticación. Si un
401 tiene que ser un fallo seguro, compruébalo con `%{http_code}`.

### 2.4 La tercera vía: leer el código y decidir

```bash
codigo=$(curl -sS --cacert "$CA" -o respuesta.json -w '%{http_code}' \
  https://localhost:8443/limitado)
echo "$codigo"
# 429
```

Sin `--fail`, curl sale con 0 porque hubo respuesta, y `-w` deja el código
en una variable. El cuerpo está en `respuesta.json`, y ahora es el script quien
decide qué hacer con cada código:

| Código | Qué significa para quien llama | Qué hacer |
|---|---|---|
| 2xx | Éxito | Usar el cuerpo |
| 401, 403 | La credencial no vale | Parar y avisar: repetir no lo arregla |
| 404, 422, otros 4xx | La petición está mal | Parar: repetir da lo mismo |
| 429, 503 | La API pide que vuelvas más tarde | Esperar y repetir |
| 500 | El servidor falló | Depende: quizá repetir una vez |

`--fail` reduce todo eso a "22". Para un script que solo tiene que parar ante
cualquier error, basta. Para uno que tiene que **reaccionar distinto** según
el error, como el toolkit, no.

---

## 3. Cómo se usa

### 3.1 `--fail-with-body` sin ensuciar el archivo de datos

Con `--fail-with-body` y `-o`, el cuerpo del error **acaba en el archivo**. El
fallo se detecta, pero `usuarios.json` queda con contenido que no son datos.
La forma limpia es descargar a un temporal y moverlo solo si todo fue bien:

```bash
tmp=$(mktemp)
if curl -sS --fail-with-body --max-time 10 --retry 3 \
     --cacert "$CA" -o "$tmp" https://localhost:8443/get; then
  mv "$tmp" usuarios.json
else
  echo "la API respondio con error:" >&2
  cat "$tmp" >&2
  rm -f "$tmp"
  exit 1
fi
```

Quien lea `usuarios.json` encuentra los datos de la última petición que fue
bien, o nada. Nunca un error. Es el mismo principio que la descarga a
`DESTINO.part` de la Semana 04.

### 3.2 Leer el código: el patrón del toolkit

```bash
cuerpo=$(mktemp)
trap 'rm -f "$cuerpo"' EXIT
rc=0
codigo=$(curl -sS --max-time 10 --retry 3 --cacert "$CA" -o "$cuerpo" \
  -w '%{http_code}' https://localhost:8443/limitado) || rc=$?

[ "$rc" -eq 0 ] || { echo "sin respuesta HTTP (curl: $rc)" >&2; exit 69; }
case "$codigo" in
  2??)         cat "$cuerpo" ;;
  429|503)     cat "$cuerpo" >&2; echo "repite mas tarde" >&2; exit 75 ;;
  401|403)     cat "$cuerpo" >&2; exit 77 ;;
  *)           cat "$cuerpo" >&2; exit 1 ;;
esac
```

Tres decisiones que se repiten en todo el bootcamp:

- **El cuerpo de un error va a stderr**, nunca a stdout. stdout es para datos.
- **El código HTTP se traduce a un código de salida** con significado (teoría
  08).
- **Sin `--fail`, curl ya no avisa de un 4xx/5xx**: el `case` tiene que cubrir
  todos los casos, con un `*` al final.

El `rc` va antes que el `case`: si curl no sale con 0, no hubo respuesta
HTTP, `codigo` vale `000` y no hay nada que decidir.

### 3.3 `-w` junto a `--fail-with-body`

No son excluyentes. Con los dos, curl sale con 22 y `-w` sigue escribiendo el
código:

```bash
curl -s --fail-with-body --cacert "$CA" -o /dev/null -w '%{http_code}\n' \
  https://localhost:8443/limitado
# 429
echo $?
# 22
```

Útil en un script que quiere `set -e` como red de seguridad y además el
código para el mensaje.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `curl -o datos.json URL` sin `--fail` y sin mirar el código | El error acaba en `datos.json` y el script sigue | `--fail-with-body`, o `-w '%{http_code}'` |
| `--fail` en un script que tiene que explicar el error | El cuerpo, donde la API dice qué pasó, se pierde | `--fail-with-body` |
| `--fail-with-body -o datos.json` y seguir | El archivo de datos contiene el error | Temporal, y `mv` solo si salió con 0 |
| El cuerpo del error a stdout | El siguiente comando de la tubería lo procesa como datos | `>&2` |
| Confiar en `--fail` para el 401 | No es a prueba de fallos con autenticación | `%{http_code}` |
| `--fail` en el `.curlrc` | Cambia el comportamiento de todos tus scripts, y choca con `--fail-with-body` | Cada script decide; el `.curlrc` se ignora con `-q` |

---

## 5. Trucos

- **`-f` es `--fail`**, y `-sSf` es la combinación clásica de los one-liners:
  silencioso, con errores, y sale con 22 ante un 4xx/5xx. En scripts, mejor
  `-sS --fail-with-body`.
- **`--fail-early`** hace que curl pare en la primera URL que falle cuando le
  pasas varias. Sin él, sigue con las demás y el código final es el de la
  última.
- **Para saber si tu curl tiene `--fail-with-body`**:
  `curl --help all | grep -c fail-with-body` da 1 o 0.

---

## 📚 Recursos Adicionales

- [Manpage: `--fail`](https://curl.se/docs/manpage.html#-f)
- [Manpage: `--fail-with-body`](https://curl.se/docs/manpage.html#--fail-with-body)
- [Daniel Stenberg — `--fail-with-body`](https://daniel.haxx.se/blog/2021/02/11/curl-fail-with-body/),
  el anuncio, con el porqué

---

## ✅ Checklist de Verificación

- [ ] Ves la diferencia entre `--fail` y `--fail-with-body` contra `/limitado`
- [ ] Sabes por qué no se combinan en 7.81
- [ ] Tu patrón de `--fail-with-body` nunca deja un error en el archivo de datos
- [ ] Tu `case` sobre `%{http_code}` distingue lo temporal de lo definitivo
