# Formularios urlencoded

> El formato más viejo de la web para mandar datos sigue siendo el que esperan
> la mitad de los endpoints de login y de token. Parece texto plano, pero tiene
> tres caracteres que lo rompen: `&`, `+` y `%`.

![Diagrama de la codificación de un formulario: los pares nombre=valor unidos por &, con el espacio convertido en + y los caracteres reservados en %XX; a la izquierda lo que escribe la persona, en el centro -d que lo manda tal cual y --data-urlencode que lo codifica, a la derecha lo que el servidor reconstruye en cada caso](../0-assets/05-formularios-urlencoded.svg)

## 🎯 Objetivos

- Leer y escribir un cuerpo `application/x-www-form-urlencoded` a mano
- Saber qué hace `-d` con lo que le das, y qué **no** hace
- Usar las cinco formas de `--data-urlencode` y elegir la adecuada
- Distinguir `-d @archivo`, `--data-binary @archivo` y `--data-raw`
- Mandar los mismos datos en la query string con `-G`

---

## 1. Qué problema resuelve

Un formulario HTML con dos campos, `usuario` y `comentario`, se envía como una
sola línea:

```
usuario=ana&comentario=hola+mundo
```

Es el tipo `application/x-www-form-urlencoded`, y es lo que manda curl con `-d`.
Lo vas a encontrar mucho más allá de los formularios web: el endpoint de token
de OAuth2 lo exige (Semana 08), muchos webhooks lo usan, y casi cualquier
`/login` de una aplicación clásica.

El problema es que el formato reserva caracteres. Si el comentario es
`50% de descuento & envío gratis`, mandado tal cual rompe el cuerpo entero.

---

## 2. Cómo funciona

### 2.1 Las reglas del formato

| Carácter | Significado en el cuerpo | Cómo se escribe si es dato |
|---|---|---|
| `&` | Separa un par del siguiente | `%26` |
| `=` | Separa nombre y valor | `%3D` |
| `+` | **Un espacio** | `%2B` |
| `%` | Empieza un escape `%XX` | `%25` |
| espacio | — | `+` (o `%20`) |
| `é`, `ñ`, emoji | — | Sus bytes UTF-8 en `%XX`: `é` = `%C3%A9` |

Las letras, los dígitos y `-._~` van tal cual.

### 2.2 `-d` no codifica nada

`-d` (`--data`) manda exactamente lo que le das, une varios `-d` con `&`, y pone
el `Content-Type: application/x-www-form-urlencoded` y el método `POST`:

```bash
curl -s -d 'a=1' -d 'b=2' -o /dev/null -v http://localhost:8080/post 2>&1 \
  | grep -iE '^> (POST|content-type)'
# > POST /post HTTP/1.1
# > Content-Type: application/x-www-form-urlencoded
```

Que no codifique es lo que hace daño. Tres casos, tres fallos distintos:

```bash
# El + es un espacio: "a+b" llega como "a b".
curl -s -d 'c=a+b' http://localhost:8080/post | jq -c .form
# {"c":["a b"]}

# El & parte el valor: llega un campo de mas.
curl -s -d 'e=x&y=z' http://localhost:8080/post | jq -c .form
# {"e":["x"],"y":["z"]}

# Un % suelto no es un escape valido: el servidor rechaza el cuerpo ENTERO.
curl -s -o /dev/null -w '%{http_code}\n' -d 'c=ok' -d 'p=50%' http://localhost:8080/post
# 400
```

El tercero es el peor: un solo carácter en un campo tira todos los demás.

### 2.3 `--data-urlencode` codifica el valor

`--data-urlencode` codifica según las reglas de la tabla. Lo que codifica
depende de la forma en que lo escribas:

| Forma | Qué manda | Ejemplo | Resultado |
|---|---|---|---|
| `nombre=contenido` | `nombre` tal cual, `contenido` codificado | `'q=café & té'` | `q=caf%C3%A9+%26+t%C3%A9` |
| `=contenido` | Solo `contenido` codificado, sin nombre | `'=a b&c'` | `a+b%26c` |
| `contenido` | Igual que la anterior: todo codificado | `'a b'` | `a+b` |
| `nombre@archivo` | `nombre=` y el contenido del archivo codificado | `'msg@m.txt'` | `msg=linea1%0Alinea2%0A` |
| `@archivo` | El contenido del archivo codificado, sin nombre | `'@m.txt'` | `linea1%0Alinea2%0A` |

El nombre **nunca** se codifica: si lleva caracteres raros, codifícalo tú.
Y curl 7.81 codifica el espacio como `+`, igual que 8.21: es lo que esperan los
formularios.

```bash
curl -s --data-urlencode 'q=50% de descuento & envío gratis' \
  http://localhost:8080/post | jq -c .form
# {"q":["50% de descuento & envío gratis"]}
```

Llega exactamente lo que escribiste. `-d` y `--data-urlencode` se pueden
mezclar: `-d 'tipo=fijo' --data-urlencode 'texto=lo que sea'`.

### 2.4 Leer de un archivo: tres flags, tres comportamientos

```bash
printf 'linea1\nlinea2\n' > m.txt
```

| Flag | Qué hace con el archivo | Lo que llega |
|---|---|---|
| `-d @m.txt` | Lo lee **y quita los saltos de línea** (`\r` y `\n`) | `linea1linea2` |
| `--data-binary @m.txt` | Lo lee tal cual, byte a byte | `linea1\nlinea2\n` |
| `--data-urlencode 'campo@m.txt'` | Lo lee y lo codifica | `campo=linea1%0Alinea2%0A` |
| `--data-raw '@m.txt'` | **No lee nada**: la `@` es un carácter más | `@m.txt` |

`-d @archivo` quitando los saltos de línea es una herencia de los tiempos en
que los formularios se escribían en un archivo, uno por línea. Hoy sorprende:
un JSON multilínea funciona, pero un archivo binario o un texto con párrafos
llega estropeado. Para mandar un archivo como cuerpo, **`--data-binary`**. Lo
verás en el [archivo 07](07-subir-el-cuerpo-en-crudo.md).

`--data-raw` (7.43+) existe para lo contrario: cuando el valor empieza por `@`
y **no** quieres que curl lo lea como archivo.

### 2.5 `-G`: los mismos datos, en la URL

```bash
curl -s -G -d 'a=1' --data-urlencode 'q=a b' http://localhost:8080/get \
  | jq -c '.args, .url'
# {"a":["1"],"q":["a b"]}
# "http://localhost:8080/get?a=1&q=a+b"
```

`-G` (`--get`) coge todo lo de `-d` y `--data-urlencode`, lo pega a la URL tras
un `?` y manda un `GET`. Es la forma limpia de construir query strings con
valores que hay que codificar. En 7.87+ existe `--url-query`, que hace lo mismo
sin convertir la petición en `GET`; en 7.81 no está, y `-G` es la alternativa.

---

## 3. Cómo se usa

### 3.1 Un login clásico

```bash
# La password vive en un archivo con permisos 600, creado con printf y no
# con echo: --data-urlencode codifica tambien el \n final, y el login fallaria.
# Si lleva un & o un %, no rompe el cuerpo.
(umask 077; printf '%s' "$APP_PASSWORD" > ~/.app-password)
curl --fail-with-body --max-time 10 -sS \
  --data-urlencode "usuario=${APP_USER}" \
  --data-urlencode "password@${HOME}/.app-password" \
  https://app.ejemplo.com/login
```

La forma `password@archivo` resuelve dos problemas a la vez: la codificación y
la regla de la Semana 03. La password no aparece en `ps`, porque en el argv
solo está la ruta del archivo.

### 3.2 Un valor con saltos de línea

```bash
# Un mensaje multilinea para un webhook que acepta formularios.
printf 'Despliegue OK\nVersion: 1.4.2\n' > mensaje.txt
curl -s --data-urlencode 'text@mensaje.txt' http://localhost:8080/post \
  | jq -r '.form.text[0]'
# Despliegue OK
# Version: 1.4.2
```

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `-d "comentario=$TEXTO"` con texto del usuario | Un `&`, un `+` o un `%` en el texto rompen o alteran el cuerpo | `--data-urlencode "comentario=$TEXTO"` |
| `-d @archivo` para mandar un archivo | Quita los saltos de línea: el archivo llega distinto | `--data-binary @archivo` |
| `-d "password=$PASS"` | La password en el argv, visible en `ps` | `--data-urlencode 'password@archivo'` |
| Codificar el nombre del campo con `--data-urlencode` y esperar que funcione | El nombre no se codifica nunca | Nombres sin caracteres especiales, o codificados a mano |
| `-X GET -d ...` | Manda un `GET` **con cuerpo**, que muchos servidores ignoran | `-G` |
| Construir la query string a mano con `?q=$VAR` | El valor sin codificar rompe la URL | `-G --data-urlencode "q=$VAR"` |

---

## 5. Trucos

```bash
# Ver el cuerpo exacto que manda curl, antes de que el servidor lo
# interprete: forzar text/plain hace que /post lo devuelva en crudo.
curl -s --data-urlencode 'q=café & té' -H 'Content-Type: text/plain' \
  http://localhost:8080/post | jq -r .data
# q=caf%C3%A9+%26+t%C3%A9
```

```bash
# Codificar una cadena para una URL sin mandar nada a ningun sitio util:
# -G y una URL de /get, y quedarse con lo que va tras el ?.
curl -s -G --data-urlencode "=$TEXTO" -o /dev/null -w '%{url_effective}\n' \
  http://localhost:8080/get | cut -d'?' -f2
```

```bash
# Comprobar si un archivo tiene \r (fin de linea de Windows) antes de
# mandarlo: -d los quitaria, --data-binary los mandaria.
grep -c $'\r' archivo.txt
```

---

## 📚 Recursos Adicionales

- [WHATWG URL — application/x-www-form-urlencoded](https://url.spec.whatwg.org/#application/x-www-form-urlencoded) — la especificación vigente del formato
- [manpage de curl — `--data-urlencode`](https://curl.se/docs/manpage.html#--data-urlencode) — las cinco formas, con ejemplos
- [manpage de curl — `-d`](https://curl.se/docs/manpage.html#-d) — incluida la nota sobre los saltos de línea con `@`
- [everything.curl.dev — POST](https://everything.curl.dev/http/post/) — `-d`, `--data-binary` y `--data-urlencode` comparados

---

## ✅ Checklist de Verificación

- [ ] He escrito a mano el cuerpo urlencoded de `nota=50% & más` y coincide con el de curl
- [ ] He visto los tres fallos de `-d`: el `+`, el `&` y el `%` suelto con su 400
- [ ] Sé qué manda cada una de las cinco formas de `--data-urlencode`
- [ ] Sé qué diferencia hay entre `-d @f`, `--data-binary @f` y `--data-raw @f`
- [ ] He construido una query string con `-G` y `--data-urlencode`
- [ ] Sé mandar una password por formulario sin que aparezca en `ps`

---

| Anterior | Siguiente |
|---|---|
| [04 — Controlar la transferencia](04-controlar-la-transferencia.md) | [06 — Multipart por dentro](06-multipart-por-dentro.md) |
