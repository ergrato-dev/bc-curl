# `--write-out`

> Cuando la transferencia termina, curl sabe mucho más de lo que te ha
> contado: el código, los bytes, la URL a la que acabó llegando, cuánto tardó,
> por qué falló. `-w` es la forma de preguntárselo, en una línea que un script
> puede leer.

![Diagrama de cómo se construye la salida de --write-out: una plantilla con texto, variables %{nombre} y secuencias como \n se rellena al terminar la transferencia con los datos que curl guardó; la plantilla puede venir del argumento, de @archivo o de @- (stdin), y %{stderr} y %{stdout} cambian el flujo a mitad de la línea](../0-assets/03-write-out.svg)

## 🎯 Objetivos

- Escribir un formato de `-w` con texto, variables y saltos de línea
- Conocer las diez variables que resuelven casi todo, y en qué versión entró cada una
- Guardar el formato en un archivo sin caer en la trampa de los saltos de línea
- Separar el cuerpo de la línea de `-w` cuando los dos van a stdout
- Obtener un resultado legible también cuando la petición falla

---

## 1. Qué problema resuelve

Sin `-w`, saber el código de estado de una petición desde un script exige
`-i`, partir la salida y parsear la primera línea. Saber la URL final tras los
redirects, o el número de bytes, o por qué falló, exige más parseo todavía.

curl ya tiene todos esos datos al terminar. `-w` los imprime:

```bash
curl -s -o /dev/null -w '%{http_code} %{size_download} %{url_effective}\n' \
  -L http://localhost:8080/redirect/2
# 200 245 http://localhost:8080/get
```

Una línea, separada por espacios, lista para un `read` o un `awk`.

---

## 2. Cómo funciona

### 2.1 La plantilla

El argumento de `-w` es una plantilla. Al terminar, curl la recorre y sustituye:

| Elemento | Qué es | Ejemplo |
|---|---|---|
| `%{nombre}` | Una variable | `%{http_code}` |
| `%header{nombre}` | Un header de la respuesta (7.84+) | `%header{etag}` |
| `\n`, `\r`, `\t` | Salto de línea, retorno, tabulador | `'%{http_code}\n'` |
| `%%` | Un `%` literal | `'100%%'` |
| Cualquier otra cosa | Texto literal | `'codigo='` |

curl **no añade un salto de línea al final**: si no pones `\n`, el prompt se
pega a la salida. Y la plantilla va entre comillas simples para que el shell no
toque las llaves ni las barras.

### 2.2 Las diez variables que importan

| Variable | Qué da | Desde |
|---|---|:--:|
| `http_code` | Código de estado de la última respuesta. `000` si no hubo | siempre |
| `exitcode` | El código de salida de curl | 7.75 |
| `errormsg` | El mensaje de error, vacío si no hubo | 7.75 |
| `url_effective` | La URL final, tras los redirects | siempre |
| `num_redirects` | Cuántos redirects siguió | siempre |
| `redirect_url` | A dónde llevaba el redirect que **no** siguió | siempre |
| `size_download` | Bytes del cuerpo recibido | siempre |
| `content_type` | El `Content-Type` de la respuesta | siempre |
| `remote_ip` | La IP a la que se conectó de verdad | 7.29 |
| `time_total` | Segundos que duró todo | siempre |

`response_code` es un sinónimo de `http_code`. Los `time_*` tienen su archivo
propio, el 04. Y hay más (`method`, `num_headers`, `scheme`, `http_version`...):
el truco del final enseña cómo verlas todas.

> [!CAUTION]
> Las variables inventadas no dan error: curl avisa en stderr y **sale con 0**.
> `%{status_code}` o `%{total_time}` no existen. Un script con una de ellas
> recibe una cadena vacía y sigue como si nada.
>
> ```bash
> curl -s -o /dev/null -w '%{status_code}\n' http://localhost:8080/get; echo "salida: $?"
> # curl: unknown --write-out variable: 'status_code'
> #
> # salida: 0
> ```

### 2.3 Solo vale el último `-w`

```bash
curl -s -o /dev/null -w '%{http_code}\n' -w '%{size_download}\n' http://localhost:8080/get
# 245
```

`-w` no se acumula: el segundo sustituye al primero. Si un `.curlrc` (teoría
07) trae su propio `-w`, el de tu comando lo pisa, y viceversa según el orden.

### 2.4 El formato en un archivo

`-w @archivo` lee la plantilla de un archivo; `-w @-`, de stdin. Útil para
compartir el mismo formato entre scripts, pero con una trampa:

```bash
printf 'codigo=%%{http_code}\nbytes=%%{size_download}\n' > formato.txt
curl -s -o /dev/null -w @formato.txt http://localhost:8080/get
# codigo=200bytes=245          ← los saltos de linea del archivo desaparecen
```

**curl descarta los saltos de línea reales del archivo.** Cada línea tiene que
llevar su `\n` escrito, como texto:

```bash
cat > formato.txt <<'EOF'
codigo=%{http_code}\n
bytes=%{size_download}\n
EOF
curl -s -o /dev/null -w @formato.txt http://localhost:8080/get
# codigo=200
# bytes=245
```

El `<<'EOF'` con comillas impide que el shell interprete nada del interior.

---

## 3. Cómo se usa

### 3.1 Cuerpo y `-w` en la misma salida

En un script normalmente quieres las dos cosas: el cuerpo para procesarlo y el
código para decidir. La técnica del toolkit desde la Semana 02: `-w` añade una
última línea, y bash la separa.

```bash
salida=$(curl -sS -w '\n%{http_code}' http://localhost:8080/status/404)
codigo="${salida##*$'\n'}"     # lo que hay tras el ultimo salto de linea
cuerpo="${salida%$'\n'*}"      # todo lo anterior
echo "codigo=$codigo"
# codigo=404
```

El `\n` al **principio** del formato es imprescindible: un cuerpo que no
termina en salto de línea dejaría el código pegado a su última línea.

La capa 6 del proyecto amplía esa última línea con siete campos separados por
espacios, y la lee con un solo `read`.

### 3.2 `-w` por stderr

`%{stderr}` cambia el flujo: lo que viene detrás va a stderr. `%{stdout}` lo
devuelve. Así el cuerpo sale limpio por el pipe y la medida, por la terminal:

```bash
curl -sS -w '%{stderr}codigo=%{http_code}\n' http://localhost:8080/get | jq -r .url
# codigo=200                       ← stderr
# http://localhost:8080/get        ← stdout, por jq
```

### 3.3 Cuando la petición falla

`-w` se imprime **también cuando curl falla**. El código HTTP es `000` porque no
hubo respuesta, y `exitcode` y `errormsg` cuentan el motivo:

```bash
curl -s -o /dev/null -w '%{http_code} %{exitcode} %{errormsg}\n' http://127.0.0.1:9/
# 000 7 Failed to connect to 127.0.0.1 port 9 after 0 ms: Connection refused
```

`%{onerror}` (7.75+) imprime lo que le sigue **solo si** la transferencia
falló. Una línea de log que solo aparece cuando hay algo que contar:

```bash
formato='%{onerror}error %{exitcode}: %{errormsg}\n'
curl -s -o /dev/null -w "$formato" http://localhost:8080/get
#                                   ← nada: salio bien
curl -s -o /dev/null -w "$formato" http://127.0.0.1:9/
# error 7: Failed to connect to 127.0.0.1 port 9 after 0 ms: Connection refused
```

Un 500 **no** es un fallo para curl, salvo con `--fail`: entonces es el 22.

```bash
curl -s -f -o /dev/null -w "$formato" http://localhost:8080/status/500
# error 22: The requested URL returned error: 500
```

### 3.4 Todo de una vez: `%{json}`

`%{json}` (7.70+) imprime **todas** las variables como un objeto JSON. Es la
forma más segura de leer varias a la vez: nada de partir por espacios, y `jq`
da error si una no existe en vez de devolver vacío.

```bash
curl -s -o /dev/null -w '%{json}' http://127.0.0.1:9/ \
  | jq -c '{http_code, exitcode, errormsg}'
# {"http_code":0,"exitcode":7,"errormsg":"Failed to connect to 127.0.0.1 port 9 after 0 ms: Connection refused"}
```

En JSON, `http_code` es un número: `0`, no `000`.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `-w '%{http_code}'` sin `\n` | La salida se pega al prompt o a la línea siguiente | `'%{http_code}\n'` |
| `-w "\n%{http_code}"` con comillas dobles en zsh o en un `printf` | Según el shell, el `\n` se convierte antes de llegar a curl | Comillas simples |
| Fiarse de una variable sin probarla | Si no existe, sale vacía y con código 0 | Ejecútala una vez; o usa `%{json}` y `jq -e` |
| Un archivo de formato con saltos de línea reales | Desaparecen: todo sale en una línea | `\n` escrito al final de cada línea |
| `-w` con el código pegado al cuerpo | Un cuerpo sin `\n` final se come el código | `'\n%{http_code}'`, con el salto delante |
| Tratar `000` como un código HTTP | No hubo respuesta: es un fallo de red | Mira `exitcode` |

---

## 5. Trucos

- **Ver todo lo que `-w` sabe, con su valor real**:
  `curl -s -o /dev/null -w '%{json}' URL | jq .`. Más rápido que el manual.
- **`-w '%{redirect_url}'` sin `-L`** dice a dónde lleva un redirect sin
  seguirlo.
- **`-w '%{remote_ip}'`** delata un `/etc/hosts`, un `--resolve` o un DNS que
  te llevó a otra máquina.
- **`-w '%{onerror}%{stderr}...'`** combina las dos: una línea en stderr solo
  si algo falló.

---

## 📚 Recursos Adicionales

- [Manpage: `--write-out`](https://curl.se/docs/manpage.html#-w) — la lista completa, con la versión de cada variable
- [everything.curl.dev — `--write-out`](https://everything.curl.dev/usingcurl/verbose/writeout.html)
- [Daniel Stenberg — `--write-out` en JSON](https://daniel.haxx.se/blog/2020/03/17/curl-write-out-json/)

---

## ✅ Checklist de Verificación

- [ ] `curl -s -o /dev/null -w '%{http_code} %{num_redirects}\n' -L URL/redirect/2` da `200 2`
- [ ] Tu `formato.txt` saca dos líneas, y sabes por qué la primera versión sacaba una
- [ ] Separas cuerpo y código con `${salida##*$'\n'}` y `${salida%$'\n'*}`
- [ ] Una petición a `127.0.0.1:9` te da `000`, `7` y el mensaje
- [ ] `%{onerror}` no imprime nada en una petición que sale bien
- [ ] `%{json}` funciona en tu curl, o sabes que es anterior a 7.70
