# Caché y peticiones condicionales

> La petición más rápida es la que no se hace, y la segunda más rápida es la
> que se responde con "lo que ya tienes sigue valiendo". Un ETag convierte una
> respuesta de 200 KB en un 304 vacío. curl sabe guardarlo y mandarlo; lo que
> no hace es emparejarlo con el cuerpo, y eso le toca a tu script.

![Dos peticiones al mismo recurso: la primera responde 200 con el cuerpo y un ETag, que el cliente guarda junto al cuerpo; la segunda manda If-None-Match con ese ETag y el servidor responde 304 Not Modified sin cuerpo, y el cliente sirve el cuerpo que tenía. A un lado, Last-Modified e If-Modified-Since como alternativa por fecha; al otro, Cache-Control max-age, que evita incluso preguntar](../0-assets/06-cache-y-peticiones-condicionales.svg)

## 🎯 Objetivos

- Explicar qué es un ETag y cómo lo usa una petición condicional
- Revalidar con `If-None-Match` y con `If-Modified-Since`, y leer el 304
- Usar `--etag-save`, `--etag-compare` y `-z` conociendo sus rarezas en 7.81
- Distinguir revalidar (siempre una petición) de cachear con `max-age` (a
  veces ninguna)
- Guardar una caché en disco sin abrir un agujero

---

## 1. Qué problema resuelve

Un script consulta cada minuto la configuración de un servicio: 200 KB de
JSON que cambian una vez al día. Son 288 MB diarios para recibir 1439 veces
lo mismo.

HTTP tiene una respuesta para eso desde 1999: el cliente dice **qué versión
tiene**, y el servidor contesta "sigue siendo esa" sin mandar el cuerpo.

---

## 2. Cómo funciona

### 2.1 El ETag

Un **ETag** es una etiqueta que el servidor pone a cada versión de un
recurso, en la cabecera `ETag`. Puede ser un hash del contenido, un número de
versión, o cualquier cosa que cambie cuando cambia el recurso:

```
ETag: "v1"
ETag: W/"5468-17a"
```

Las comillas forman parte del valor. Un `W/` delante es un **ETag débil**:
"semánticamente igual", aunque los bytes difieran (otra compresión, otro
orden de campos). Para revalidar sirven los dos.

### 2.2 La petición condicional

La segunda vez, el cliente manda el ETag que tiene:

```
GET /config HTTP/1.1
If-None-Match: "v1"
```

- Si el recurso **sigue** en `"v1"`: `304 Not Modified`, sin cuerpo.
- Si **cambió**: `200` con el cuerpo nuevo y el ETag nuevo.

El 304 **no ahorra el viaje**, ahorra el cuerpo. Para un JSON de 2 KB la
diferencia es mínima; para 200 KB, o para una API que cobra por bytes, es
enorme. Y muchas APIs (GitHub, por ejemplo) **no descuentan** de tu rate limit
las respuestas 304.

### 2.3 Por fecha: Last-Modified

La alternativa antigua: el servidor manda `Last-Modified` con una fecha, y el
cliente pregunta con `If-Modified-Since`. Funciona igual, pero con resolución
de un segundo: dos cambios en el mismo segundo no se distinguen. Si el
servidor da los dos, el ETag manda.

curl la manda con `-z` / `--time-cond`:

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  -z 'Wed, 01 Jan 2020 00:00:00 GMT' http://localhost:8080/cache
# 304
```

`-z` acepta también un archivo: usa su fecha de modificación. `-z datos.json`
pide el recurso solo si cambió después de que bajaras `datos.json`.

### 2.4 `--etag-save` y `--etag-compare` (7.68.0+)

curl puede guardar y mandar el ETag por ti:

- `--etag-save ARCHIVO` escribe el ETag de la respuesta en ARCHIVO.
- `--etag-compare ARCHIVO` lee un ETag de ARCHIVO y lo manda como
  `If-None-Match`.

Juntos, sobre el mismo archivo:

```bash
curl -s -o datos.json --etag-compare e.txt --etag-save e.txt \
  -w '%{http_code}\n' http://localhost:8080/etag/v1
# 200          ← la primera vez
curl -s -o datos.json --etag-compare e.txt --etag-save e.txt \
  -w '%{http_code}\n' http://localhost:8080/etag/v1
# 304          ← la segunda
```

Con el 304, curl no toca `datos.json`: no llega cuerpo, y el archivo de
salida solo se abre cuando llegan datos. Los 292 bytes de la primera vez
siguen ahí. Pero hay tres rarezas que conviene saber en 7.81:

1. **El ETag y el cuerpo no están atados.** Si `datos.json` se borra o se
   corrompe, `e.txt` sigue diciendo "tengo la versión v1", el servidor
   responde 304, y te quedas sin datos y sin error.
2. **Si el archivo de `--etag-compare` no existe, no manda nada.** Pero si
   está **vacío**, manda `If-None-Match: ""`, y con los dos flags sobre un
   archivo que aún no existe, curl lo crea vacío antes de comparar. Un
   servidor que responda 304 a cualquier `If-None-Match` (el `/cache` del
   laboratorio lo hace) te da un 304 en la primera petición.
3. **Una respuesta sin ETag deja el archivo vacío**, y vuelves al caso 2.

Por eso el toolkit **no** usa estos flags: guarda el ETag y el cuerpo él
mismo, y manda `If-None-Match` solo si tiene los dos (práctica 04).

### 2.5 Cache-Control: no preguntar

Revalidar siempre cuesta un viaje. `Cache-Control: max-age=N` dice algo más
fuerte: "esta respuesta vale N segundos; no vuelvas a preguntar hasta
entonces".

```bash
curl -s -D- -o /dev/null http://localhost:8080/cache/60 | grep -i cache-control
# Cache-Control: public, max-age=60
```

Un cliente que lo respete ahorra la petición entera. Pero exige decidir cuándo
caduca cada entrada, qué hacer con `no-store`, `no-cache`, `private`… Es lo
que hace un navegador, y es mucho para un script. El toolkit **solo
revalida**: siempre pregunta, y un 304 le ahorra el cuerpo.

### 2.6 Una caché en disco es un secreto

Si la API pide autenticación, el cuerpo que guardas es tan sensible como la
respuesta. Una caché en `/tmp` legible por todos filtra lo que el token
protegía. Las reglas del toolkit:

- El directorio se crea con **permisos 700**, y si ya existe con otros, error.
- El nombre de cada entrada es el **SHA-256 de la URL**: no se ve qué se
  consultó listando el directorio, y la query string no rompe nada.
- Se guarda **primero el cuerpo y después el ETag**, cada uno con `mv`. Un
  corte entre los dos deja un ETag viejo que el servidor no reconoce, y la
  siguiente petición trae el cuerpo entero. Nunca un ETag nuevo con un cuerpo
  viejo.
- Una respuesta con **`Cache-Control: no-store`** no se guarda, aunque traiga
  ETag. No es un detalle de rendimiento: la API dice que esa respuesta no debe
  quedar en ningún disco, y es lo único de `Cache-Control` que el toolkit sí
  respeta.

---

## 3. Cómo se usa

A mano, contra el endpoint `/etag/{etag}` del laboratorio, que responde con
ese ETag y honra `If-None-Match`:

```bash
curl -s -D- -o /dev/null http://localhost:8080/etag/v1 | grep -i etag
# Etag: "v1"

curl -s -o /dev/null -w '%{http_code} %{size_download}\n' \
  -H 'If-None-Match: "v1"' http://localhost:8080/etag/v1
# 304 0

curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'If-None-Match: "v0"' http://localhost:8080/etag/v1
# 200
```

Y con el toolkit, la segunda llamada imprime lo mismo que la primera, pero el
cuerpo sale del disco:

```bash
export API_CACHE_DIR=~/.cache/api-toolkit
./api-toolkit.sh get /etag/v1 | jq -r .url
# http://localhost:8080/etag/v1
./api-toolkit.sh --verbose get /etag/v1 2>&1 >/dev/null | grep -E '^[<>] (HTTP|If-None)'
# > If-None-Match: "v1"
# < HTTP/1.1 304 Not Modified
```

---

## 4. Antipatrones

- **Fiarse de `--etag-compare` sin comprobar que el archivo de datos existe.**
  Un 304 no lo recrea.
- **Guardar el ETag sin el cuerpo**, o el cuerpo sin el ETag. Uno sin el otro
  no sirve, y mandar `If-None-Match` sin cuerpo guardado acaba en un 304 que
  no puedes servir.
- **Una caché con permisos 755** para respuestas autenticadas.
- **Usar la URL tal cual como nombre de archivo.** Barras, `?`, `&` y la
  longitud máxima de un nombre te lo rompen.
- **Tratar el 304 como error.** Es un 3xx de éxito: el toolkit lo trata como
  2xx desde la Semana 07.
- **Cachear un POST.** Solo se revalidan lecturas.

---

## 5. Trucos

- **Ver si una API da ETag**: `curl -sI URL | grep -iE '^(etag|last-modified|cache-control):'`.
- **El 304 se ve en `%{http_code}` y en `%{size_download}` 0**: es la forma de
  comprobarlo en un lote.
- **`-z archivo`** es la revalidación más corta para descargas: `curl -z
  datos.json -o datos.json URL` no descarga si no cambió, y con el 304 deja
  `datos.json` como estaba. Para que un corte no lo deje a medias, `-o
  datos.json.new` y `mv` si el código es 200.
- **GitHub y los 304**: con `If-None-Match`, una respuesta 304 no gasta rate
  limit. En un script que sondea, es la diferencia entre 60 y miles de
  consultas por hora.
- **`/etag/{etag}` del laboratorio** acepta cualquier valor: `/etag/v2` simula
  que el recurso cambió.

---

## 📚 Recursos Adicionales

- [RFC 9110, apartado 13 — Conditional Requests](https://datatracker.ietf.org/doc/html/rfc9110#section-13)
- [RFC 9111 — HTTP Caching](https://datatracker.ietf.org/doc/html/rfc9111)
- [MDN — ETag](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag)

---

## ✅ Checklist de Verificación

- [ ] Explicas qué es un ETag, uno débil, y qué ahorra un 304
- [ ] Revalidas con `If-None-Match` y con `-z`
- [ ] Explicas por qué `--etag-save` no basta: el ETag y el cuerpo van separados
- [ ] Distingues revalidar de cachear con `max-age`
- [ ] Nombras las tres reglas de una caché en disco que guarda respuestas autenticadas
