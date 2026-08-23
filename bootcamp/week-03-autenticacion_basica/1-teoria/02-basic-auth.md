# Basic Auth

> El esquema más viejo y el más malinterpretado. `base64` no cifra nada: lo que
> hace `-u` es codificar, y codificar no es proteger.

![Diagrama de Basic Auth: usuario y password unidos por dos puntos, codificados en base64 y enviados en el header Authorization, con la nota de que la operación es reversible](../0-assets/02-basic-auth.svg)

## 🎯 Objetivos

- Construir el header `Authorization: Basic` a mano y comprobar que coincide con el de `-u`
- Explicar por qué base64 no aporta seguridad y qué es lo que sí la aporta
- Manejar los casos que rompen `-u`: password con dos puntos, usuario vacío, caracteres no ASCII
- Saber cuándo Basic Auth sigue siendo una respuesta razonable

---

## 1. Qué problema resuelve

Basic Auth es la respuesta mínima a «necesito identificar al cliente y no quiero
montar nada». Está en el
[RFC 7617](https://datatracker.ietf.org/doc/html/rfc7617) y cabe en una frase:
pega el usuario y la password con dos puntos, codifica el resultado en base64 y
mándalo en un header.

Sigue vivo en 2026 en sitios donde no lo esperas: registries de contenedores,
`/metrics` de Prometheus, paneles de routers, APIs internas, y el `Basic` que
usan muchos endpoints de token de OAuth2 para identificar al cliente.

Su virtud es que no necesita nada: ni estado en el servidor, ni un endpoint de
login, ni una librería. Su defecto es que **manda la password en cada
petición**, y solo un TLS bien verificado impide que la lea quien esté en medio.

---

## 2. Cómo funciona

### 2.1 Los tres pasos de la codificación

```
usuario:password        →  se unen con UN dos puntos
dXNlcjpwYXNzd29yZA==    →  base64 del resultado
Authorization: Basic dXNlcjpwYXNzd29yZA==
```

Se puede hacer entero a mano y comprobar que sale lo mismo:

```bash
# printf y no echo: echo anade un \n que cambiaria el base64.
printf 'user:password' | base64
# dXNlcjpwYXNzd29yZA==
```

```bash
# Y lo que curl genera de verdad, con -v. El > marca lo que sale hacia fuera.
curl -s -u user:password -o /dev/null -v \
  http://localhost:8080/basic-auth/user/password 2>&1 | grep -i '^> authorization'
# > Authorization: Basic dXNlcjpwYXNzd29yZA==
```

Idéntico. Y como es idéntico, cualquiera puede hacer el camino inverso:

```bash
# base64 -d deshace la operacion. No hace falta ninguna clave: es una
# codificacion, no un cifrado.
echo 'dXNlcjpwYXNzd29yZA==' | base64 -d
# user:password
```

> [!WARNING]
> Ese último bloque **es** el argumento de seguridad de Basic Auth. Un header
> `Authorization: Basic` en un log, en una captura de pantalla o en un ticket de
> Jira es la password en claro con dos segundos de trabajo por medio.

### 2.2 Lo que aporta seguridad es TLS, no base64

| Lo que hace base64 | Lo que hace TLS |
|---|---|
| Convierte bytes cualesquiera en ASCII imprimible | Cifra el canal entero, headers incluidos |
| Es reversible sin ninguna clave | No es reversible sin la clave de sesión |
| Existe para que un header no se rompa | Existe para que nadie lea el header |

Por eso Basic Auth **sobre HTTP en claro no es autenticación**: es publicar la
password en la red. Y por eso `-k` es especialmente grave aquí: desactiva la
verificación del certificado, así que cualquiera que se ponga en medio con su
propio certificado recibe tu password y la reenvía sin que te enteres.

```bash
# ❌ NUNCA. Con -k no sabes con quien estas hablando, y le estas mandando la
#    password. El -k convierte el unico control que tenias en decoracion.
curl -k -u usuario:password https://api.ejemplo.com/v1/datos
```

```bash
# ✅ Si el certificado no valida, se arregla dandole la CA correcta, no
#    apagando la comprobacion. La del laboratorio se exporta con start.sh.
curl --cacert docs/lab-ca.pem -u user:password https://localhost:8443/basic-auth/user/password
```

### 2.3 Los cuatro flags que hacen lo mismo, casi

| Forma | Qué hace | Cuándo |
|---|---|---|
| `-u usuario:password` | La credencial completa en el argv | Nunca en un script. Visible en `ps` |
| `-u usuario` | curl **pregunta** la password por terminal | Uso interactivo. No queda en el historial |
| `--basic -u ...` | Fuerza el esquema Basic sin esperar el reto | Cuando ya sabes que es Basic. Ahorra una petición |
| `--netrc-file f` | Saca usuario y password de un archivo | Scripts. Es el tema de la teoría 03 |

`-u` sin `--basic` también manda Basic de entrada: Basic es el esquema por
defecto de curl. `--basic` es explícito y sirve para desactivar un `--digest`
puesto antes en un `.curlrc`.

```bash
# curl pregunta la password. Ni en ps, ni en ~/.bash_history.
curl -u user http://localhost:8080/basic-auth/user/password
# Enter host password for user 'user':
```

### 2.4 Los casos raros de `-u`

**La password lleva dos puntos.** curl parte por el **primer** `:`, así que el
usuario nunca puede llevarlos, pero la password sí:

```bash
# Usuario "user", password "pass:con:dos:puntos". Lo que hay tras el primer
# dos puntos es la password entera, dos puntos incluidos.
printf 'user:pass:con:dos:puntos' | base64
# dXNlcjpwYXNzOmNvbjpkb3M6cHVudG9z
```

**Usuario sin password.** `-u 'user:'` manda la password vacía, que es distinto
de no mandar credencial:

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  -u 'user:' http://localhost:8080/basic-auth/user/password
# 401
```

**Caracteres no ASCII.** El RFC 7617 dice que el juego de caracteres por defecto
es indefinido, y en la práctica cada servidor decide. Una `ñ` o un acento en la
password es la causa de un `401` que no se explica de otra forma. Si controlas
la credencial, evítalos; si no, prueba a comparar el base64 que genera curl con
el que espera el servidor.

### 2.5 El `realm`

El servidor manda un `realm` en su reto. Es una etiqueta del espacio protegido,
no un secreto:

```bash
curl -s -o /dev/null -D - http://localhost:8080/basic-auth/user/password \
  | grep -i '^www-authenticate'
# Www-Authenticate: Basic realm="Fake Realm"
```

Sirve para dos cosas: el navegador lo enseña en su ventana de login, y curl lo
usa para **no reenviar la credencial a un realm distinto** cuando sigue una
redirección. Ese detalle vuelve en la Semana 05.

---

## 3. Cómo se usa

### 3.1 El caso básico, contra el laboratorio

```bash
# El endpoint del laboratorio lleva el usuario y la password en la propia ruta,
# para que sepas que credencial espera: /basic-auth/<usuario>/<password>.
curl -s -u user:password http://localhost:8080/basic-auth/user/password | jq
# {
#   "authenticated": true,
#   "user": "user",
#   "authorized": true
# }
```

### 3.2 Comprobar si la credencial vale, sin bajarte el cuerpo

```bash
# -o /dev/null tira el cuerpo, -w imprime solo lo que te interesa.
curl -s -o /dev/null -w '%{http_code}\n' \
  -u user:incorrecta http://localhost:8080/basic-auth/user/password
# 401
```

### 3.3 En un script: la credencial fuera del argv

Este es el patrón que vas a usar el resto del bootcamp. La password no aparece
en la línea de comandos de curl:

```bash
#!/usr/bin/env bash
set -euo pipefail

# umask 077 hace que el archivo nazca con permisos 600. Un chmod despues deja
# una ventana, corta pero real, en la que el archivo es legible por todos.
config=$(mktemp)
trap 'rm -f "$config"' EXIT
(umask 077; printf 'user = "%s:%s"\n' "$API_USER" "$API_PASSWORD" > "$config")

# --fail-with-body: sale distinto de 0 ante 4xx/5xx y conserva el cuerpo, que
# es donde la API explica el motivo. --max-time: sin el, un servidor colgado
# cuelga el cron. --retry: solo reintenta lo transitorio.
curl --config "$config" \
  --fail-with-body --max-time 30 --retry 3 --retry-delay 2 \
  -sS "${BASE_URL}/v1/datos"
```

El formato del archivo de `--config` es una opción larga por línea, sin los dos
guiones. La teoría 03 lo desarrolla.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `-u usuario:password` en un script | Visible en `ps` para cualquier usuario de la máquina, y en el historial | `--config` o `--netrc-file`. Teoría 03 |
| Basic Auth sobre `http://` | La password viaja legible. base64 no es cifrado | `https://` con certificado verificado |
| `-k` para «que funcione» con HTTPS | Le entregas la password a quien se ponga en medio | `--cacert` con la CA correcta |
| Guardar el base64 «ya calculado» en el código | Es la password, con un paso más. Un `base64 -d` la saca | La credencial en un archivo con permisos 600, fuera del repositorio |
| Reutilizar la misma password de Basic en varios servicios | Cada servicio que la loguee la compromete en todos | Una credencial por servicio, rotable |
| Poner la credencial en la URL: `https://user:pass@host/` | Acaba en el log del proxy, en el `Referer` y en el historial | `-u` interactivo, o un archivo |

---

## 5. Trucos

```bash
# Comprobar que tu base64 a mano coincide con el que manda curl. Si no
# coinciden, el problema esta en la credencial, no en el servidor.
printf 'user:password' | base64
curl -s -u user:password -o /dev/null -v \
  http://localhost:8080/basic-auth/user/password 2>&1 \
  | grep -i '^> authorization' | awk '{print $NF}'
# dXNlcjpwYXNzd29yZA==
# dXNlcjpwYXNzd29yZA==
```

```bash
# Ver que credencial esperaba de verdad un endpoint que te devuelve 401:
# decodifica lo que TU mandaste y leelo. Casi siempre es un espacio de mas.
echo 'dXNlcjpwYXNzd29yZA==' | base64 -d; echo
# user:password
```

```bash
# Que curl pregunte la password: no queda en ps ni en el historial.
curl -u user http://localhost:8080/basic-auth/user/password
```

```bash
# Probar una lista de credenciales contra un endpoint sin repetir el comando.
# Esto es diagnostico sobre TU propio servicio, no fuerza bruta contra nadie.
for cred in user:password user:incorrecta; do
  printf '%s -> ' "$cred"
  curl -s -o /dev/null -w '%{http_code}\n' -u "$cred" \
    http://localhost:8080/basic-auth/user/password
done
# user:password -> 200
# user:incorrecta -> 401
```

---

## 📚 Recursos Adicionales

- [RFC 7617 — The 'Basic' HTTP Authentication Scheme](https://datatracker.ietf.org/doc/html/rfc7617) — corto y se lee entero en quince minutos
- [everything.curl.dev — Basic](https://everything.curl.dev/http/auth.html) — el capítulo de autenticación del libro oficial
- [manpage de curl — `-u`](https://curl.se/docs/manpage.html#-u) — incluida la nota sobre el primer dos puntos
- [RFC 4648 §4 — Base64](https://datatracker.ietf.org/doc/html/rfc4648#section-4) — la codificación, para ver que no hay ninguna clave por ningún lado

---

## ✅ Checklist de Verificación

- [ ] `printf 'user:password' | base64` me da lo mismo que el header que enseña `-v`
- [ ] He decodificado ese base64 con `base64 -d` y he recuperado la credencial
- [ ] Sé explicar en una frase por qué base64 no es una medida de seguridad
- [ ] `curl -u user http://localhost:8080/basic-auth/user/password` me pregunta la password
- [ ] Sé qué pasa si la password lleva dos puntos, y por qué el usuario no puede llevarlos
- [ ] He leído el `realm` del laboratorio con `-D -`
- [ ] Sé por qué `-k` es peor con Basic Auth que sin autenticación ninguna

---

| Anterior | Siguiente |
|---|---|
| [01 — Autenticación y autorización](01-autenticacion-y-autorizacion.md) | [03 — Dónde no poner la credencial](03-donde-no-poner-la-credencial.md) |
