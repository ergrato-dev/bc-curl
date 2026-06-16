# Ejercicio 03: Redirects

## Objetivo

Practicar el control de redirects: ver la respuesta sin seguirlos, seguirlos con `-L`, limitar la cadena con `--max-redirs`, e inspeccionar cada salto de la cadena con `-v`.

---

## Tarea 1: Ver redirect sin seguirlo

```bash
# Un solo redirect: httpbin responde 302 y apunta a /get
curl https://httpbin.org/redirect/1
```

**Preguntas:**
- ¿Cuál es el status code de la respuesta?
- ¿Qué header indica la URL de destino?
- ¿Obtenés los datos finales de /get sin `-L`?

```bash
# Ver el header Location con -I (solo headers)
curl -I https://httpbin.org/redirect/1
```

---

## Tarea 2: Seguir el redirect con -L

```bash
# Seguir 1 redirect
curl -L https://httpbin.org/redirect/1

# Seguir cadena de 3 redirects
curl -L https://httpbin.org/redirect/3
```

**Preguntas:**
- ¿Qué datos aparecen en la respuesta final con `-L`?
- ¿Cuántos requests hizo curl en total para `/redirect/3`?

---

## Tarea 3: Ver la cadena completa con -v

```bash
# Ver cada redirect individualmente
curl -v -L https://httpbin.org/redirect/3 2>&1 | grep -E "^> GET|^< HTTP|^< [Ll]ocation"
```

**Pregunta:** ¿Cuántas líneas `GET` aparecen? ¿Cuántos status codes distintos ves?

También podés usar `-w` para ver información de la última respuesta:

```bash
curl -s -L -o /dev/null -w "Status final: %{http_code}\nURLs seguidas: %{num_redirects}\nURL final: %{url_effective}\n" \
     https://httpbin.org/redirect/3
```

---

## Tarea 4: Limitar redirects con --max-redirs

```bash
# Intentar seguir 5 redirects pero limitar a 2
curl -L --max-redirs 2 https://httpbin.org/redirect/5
```

**Preguntas:**
- ¿Qué mensaje de error muestra curl?
- ¿Qué código de error devuelve? (tip: `echo $?` después del comando)
- ¿Cuántos redirects siguió antes de fallar?

---

## Tarea 5: Redirect absoluto vs relativo

httpbin tiene dos tipos de redirect:

```bash
# Redirect relativo: Location: /get
curl -v https://httpbin.org/redirect/1 2>&1 | grep -i "location"

# Redirect absoluto: Location: https://httpbin.org/get
curl -v https://httpbin.org/absolute-redirect/1 2>&1 | grep -i "location"
```

**Pregunta:** ¿Cuál es la diferencia en el header `Location` entre los dos tipos?

---

## Tarea 6: Redirect HTTP → HTTPS

Este es el redirect más común en producción: todo el tráfico HTTP se redirige a HTTPS.

```bash
# Sin -L: ver el redirect
curl -I http://httpbin.org

# Con -L: seguir automáticamente
curl -L -s -o /dev/null -w "Status final: %{http_code}\nURL final: %{url_effective}\n" \
     http://httpbin.org/get
```

**Preguntas:**
- ¿Cuál es el status code del redirect HTTP → HTTPS?
- ¿Es un 301 (permanente) o un 302 (temporal)?
- ¿Por qué es importante que sea 301 para SEO y bookmarks?

---

## Tarea 7: Redirect y cookies

Cuando hay un redirect, ¿se reenvían las cookies?

```bash
# Setear cookie y seguir redirect
curl -c cookies-redirect.txt -b cookies-redirect.txt -L -v \
     "https://httpbin.org/cookies/set?test=valor" 2>&1 | \
     grep -E "^> Cookie|^< Set-Cookie|^< Location|^> GET"
```

**Pregunta:** ¿La cookie se envía en el request al URL de destino del redirect?

---

## Entrega

Archivo `respuestas.md` con:
1. Status code y header Location de la Tarea 1
2. Número de requests para `/redirect/3` con y sin `-L` (Tarea 2)
3. Output de `-w` con num_redirects y url_effective (Tarea 3)
4. Mensaje de error de `--max-redirs` y código de salida (Tarea 4)
5. Diferencia entre redirect relativo y absoluto (Tarea 5)
6. Status code del redirect HTTP→HTTPS y si es 301 o 302 (Tarea 6)
7. Respuesta sobre el comportamiento de cookies en redirects (Tarea 7)
