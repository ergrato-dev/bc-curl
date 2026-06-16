# Form URL-encoded: formularios clásicos

## Qué es application/x-www-form-urlencoded

Cuando un formulario HTML clásico hace submit con método POST, el browser empaqueta los campos en un formato específico:

```
nombre=Ana&apellido=Lopez&edad=30
```

Este es el formato `application/x-www-form-urlencoded`. Las claves y valores van separados por `=`, los pares por `&`, y cualquier carácter especial (espacios, tildes, ñ) se codifica en formato percent-encoding (`%20` para espacio, `%C3%B1` para ñ).

---

## Enviar form data con -d

El flag `-d` (data) envía datos en el body del request. Cuando lo usás sin especificar Content-Type, curl detecta que es un formulario y setea `application/x-www-form-urlencoded` automáticamente si usás el formato clave=valor.

Importante: `-d` implica método POST. No necesitás agregar `-X POST`.

```bash
# Formulario básico
curl -d "nombre=Ana&apellido=Lopez&edad=30" https://httpbin.org/post

# Verificar qué Content-Type envió curl
curl -v -d "nombre=Ana" https://httpbin.org/post 2>&1 | grep "Content-Type"
# > Content-Type: application/x-www-form-urlencoded
```

La respuesta de httpbin muestra el campo `form` con los valores decodificados:

```json
{
  "form": {
    "apellido": "Lopez",
    "edad": "30",
    "nombre": "Ana"
  }
}
```

---

## El problema con los caracteres especiales

Si el valor contiene `&`, `=`, `+`, espacios o caracteres no ASCII, hay que codificarlos. El flag `-d` NO codifica automáticamente:

```bash
# Esto está mal: el & rompe el parsing
curl -d "mensaje=Hola & bienvenido" https://httpbin.org/post

# httpbin recibirá: mensaje=Hola   bienvenido (el & se interpretó como separador)
```

---

## --data-urlencode: encoding automático

`--data-urlencode` codifica el valor automáticamente. Podés usarlo de varias formas:

```bash
# Codifica solo el valor (la clave va antes del =)
curl --data-urlencode "mensaje=Hola & bienvenido" https://httpbin.org/post

# Múltiples campos
curl --data-urlencode "nombre=María José" \
     --data-urlencode "ciudad=São Paulo" \
     https://httpbin.org/post

# Leer el valor desde un archivo
curl --data-urlencode "contenido@./texto.txt" https://httpbin.org/post
```

httpbin mostrará los valores correctamente decodificados:

```json
{
  "form": {
    "mensaje": "Hola & bienvenido",
    "nombre": "María José"
  }
}
```

---

## Combinar -d con --data-urlencode

Podés mezclar ambos flags en el mismo request:

```bash
curl -d "tipo=usuario" \
     --data-urlencode "nombre=María José García" \
     --data-urlencode "bio=Desarrolladora & consultora" \
     https://httpbin.org/post
```

---

## Cuándo se usa URL-encoded

- Formularios HTML legacy (login, búsqueda, registro)
- APIs antiguas que siguen la convención de formularios web
- Endpoints que esperan `application/x-www-form-urlencoded` explícitamente
- Cuando los datos son simples pares clave=valor sin estructura jerárquica

No se usa cuando:
- Los datos tienen estructura anidada (usar JSON)
- Hay archivos en el request (usar multipart)
- La API especifica `application/json` en su documentación

---

## Diferencia clave con JSON

```bash
# URL-encoded: sin comillas, sin llaves, separado por &
curl -d "nombre=Ana&rol=admin" https://httpbin.org/post

# JSON: estructura, comillas, llaves
curl -H "Content-Type: application/json" \
     -d '{"nombre": "Ana", "rol": "admin"}' \
     https://httpbin.org/post
```

En la respuesta de httpbin, URL-encoded aparece en `.form`, JSON aparece en `.json`.

---

## Resumen

| Flag | Uso |
|------|-----|
| `-d "clave=valor&clave2=valor2"` | Form data directa, sin encoding automático |
| `--data-urlencode "clave=valor con espacios"` | Codifica el valor automáticamente |
| `--data-urlencode "clave@archivo.txt"` | Lee el valor desde un archivo y lo codifica |
