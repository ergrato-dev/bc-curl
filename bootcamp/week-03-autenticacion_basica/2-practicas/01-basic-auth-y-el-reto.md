# Práctica 01 — Basic Auth y el reto

> **Duración**: 50 min · **Entregables**: `reto.md`, `authorization-a-mano.txt`

Vas a provocar un `401`, leer lo que el servidor pide, construir el header
`Authorization` a mano con `base64` y comprobar que sale byte a byte lo mismo
que genera curl. Al final sabrás que Basic Auth no tiene ninguna magia dentro.

**Antes de empezar**:

```bash
./scripts/start.sh
curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 http://localhost:8080/get
# 200
```

Crea una carpeta de trabajo **fuera** del repositorio:

```bash
mkdir -p ~/bc-curl-trabajo/semana-03 && cd ~/bc-curl-trabajo/semana-03
```

---

## Paso 1: Provocar el reto y leerlo

**Por qué**: antes de mandar una credencial hay que saber cuál pide el servidor.
Esa información no está en la documentación —que se queda vieja— sino en el
header `WWW-Authenticate` de la respuesta `401`. Es la fuente de verdad de hoy.

**Comando**:

```bash
# -D - manda los headers de respuesta a stdout; -o /dev/null tira el cuerpo.
# Asi se ve el reto sin el ruido del JSON de error.
curl -s -o /dev/null -D - http://localhost:8080/basic-auth/user/password \
  | grep -iE '^(HTTP/|www-authenticate)'
# HTTP/1.1 401 Unauthorized
# Www-Authenticate: Basic realm="Fake Realm"
```

**Verifica**:

```bash
# El esquema, aislado: es la primera palabra tras los dos puntos.
curl -s -o /dev/null -D - http://localhost:8080/basic-auth/user/password \
  | grep -i '^www-authenticate' | awk '{print $2}'
# Basic
```

---

## Paso 2: Comparar con un endpoint que pide otro esquema

**Por qué**: el mismo servidor puede pedir esquemas distintos según la ruta. Si
mandas la credencial equivocada, el `401` es idéntico y no dice por qué. Esta es
la comparación que te ahorra media hora de depuración algún día.

**Comando**:

```bash
# Tres endpoints del laboratorio, tres retos distintos.
for ruta in /basic-auth/user/password /bearer /digest-auth/auth/user/password; do
  printf '%-34s ' "$ruta"
  curl -s -o /dev/null -D - "http://localhost:8080$ruta" \
    | grep -i '^www-authenticate' | cut -c1-42
done
# /basic-auth/user/password          Www-Authenticate: Basic realm="Fake Realm"
# /bearer                            Www-Authenticate: Bearer
# /digest-auth/auth/user/password    Www-Authenticate: Digest qop=auth, realm="
```

**Verifica**:

```bash
# Guarda esto: es el primer entregable.
{
  echo "# Retos de los endpoints del laboratorio"
  echo
  for ruta in /basic-auth/user/password /bearer /digest-auth/auth/user/password; do
    printf -- '- `%s`: ' "$ruta"
    curl -s -o /dev/null -D - "http://localhost:8080$ruta" \
      | grep -i '^www-authenticate' | tr -d '\r'
  done
} > reto.md
cat reto.md
```

Añade a mano, al final de `reto.md`, una frase con la diferencia entre los tres
retos: cuál trae `realm`, cuál no trae nada y cuál trae material para calcular
una respuesta.

---

## Paso 3: Autenticarse con `-u`

**Por qué**: `-u` es la forma corta y es lo que vas a usar en la terminal. En un
script no, y el paso 6 te enseñará por qué de una forma que no se olvida.

**Comando**:

```bash
# El endpoint del laboratorio lleva la credencial que espera en la propia ruta:
# /basic-auth/<usuario>/<password>.
curl -s -u user:password http://localhost:8080/basic-auth/user/password | jq
# {
#   "authenticated": true,
#   "user": "user",
#   "authorized": true
# }
```

**Verifica**:

```bash
# Con la credencial correcta, 200. Con una mala, 401. Sin el cuerpo, solo el
# codigo, que es lo que decide un script.
for cred in user:password user:incorrecta; do
  printf '%-18s -> ' "$cred"
  curl -s -o /dev/null -w '%{http_code}\n' -u "$cred" \
    http://localhost:8080/basic-auth/user/password
done
# user:password      -> 200
# user:incorrecta    -> 401
```

---

## Paso 4: Ver el header que curl construye

**Por qué**: `-u` no es magia, es una concatenación y un base64. Verlo con tus
ojos es lo que hace que la próxima vez que encuentres un `Authorization: Basic`
en un log sepas exactamente lo que estás viendo.

**Comando**:

```bash
# -v enseña la traza. El > marca lo que sale hacia el servidor.
curl -s -u user:password -o /dev/null -v \
  http://localhost:8080/basic-auth/user/password 2>&1 \
  | grep -i '^> authorization'
# > Authorization: Basic dXNlcjpwYXNzd29yZA==
```

**Verifica**:

```bash
# Quedarse solo con la parte codificada, que es lo que compararemos.
curl -s -u user:password -o /dev/null -v \
  http://localhost:8080/basic-auth/user/password 2>&1 \
  | grep -i '^> authorization' | awk '{print $NF}'
# dXNlcjpwYXNzd29yZA==
```

---

## Paso 5: Construirlo a mano y comprobar que coincide

**Por qué**: aquí es donde base64 deja de parecer seguridad. Vas a generar el
mismo valor con dos comandos de shell, y luego vas a deshacerlo. Si puedes
hacerlo tú en dos segundos, cualquiera que vea ese header puede.

**Comando**:

```bash
# printf y NO echo: echo anade un salto de linea que cambiaria el base64 y el
# servidor devolveria 401 sin decirte por que.
printf 'user:password' | base64
# dXNlcjpwYXNzd29yZA==
```

```bash
# Y la vuelta: sin ninguna clave, sin nada. Es una codificacion, no un cifrado.
echo 'dXNlcjpwYXNzd29yZA==' | base64 -d; echo
# user:password
```

**Verifica**:

```bash
# Las dos formas, una debajo de otra. Si no coinciden, revisa el printf.
{
  echo "# El header Authorization construido a mano"
  echo
  echo "A mano:   $(printf 'user:password' | base64)"
  echo "Con curl: $(curl -s -u user:password -o /dev/null -v \
    http://localhost:8080/basic-auth/user/password 2>&1 \
    | grep -i '^> authorization' | awk '{print $NF}')"
  echo
  echo "Decodificado: $(echo 'dXNlcjpwYXNzd29yZA==' | base64 -d)"
} > authorization-a-mano.txt
cat authorization-a-mano.txt
# A mano:   dXNlcjpwYXNzd29yZA==
# Con curl: dXNlcjpwYXNzd29yZA==
# Decodificado: user:password
```

```bash
# La prueba definitiva: el header construido a mano funciona igual que -u.
curl -s -H "Authorization: Basic $(printf 'user:password' | base64)" \
  http://localhost:8080/basic-auth/user/password | jq -c '.authenticated'
# true
```

---

## Paso 6: El error del `echo`

**Por qué**: este es el fallo real que vas a cometer algún día. `echo` añade un
`\n`, el base64 sale distinto, y el servidor responde `401` sin ninguna pista. Si
lo provocas ahora a propósito, lo reconocerás cuando te pase de verdad.

**Comando**:

```bash
# Los dos base64, uno al lado del otro. Fijate en que NO son iguales.
printf 'user:password' | base64
echo   'user:password' | base64
# dXNlcjpwYXNzd29yZA==
# dXNlcjpwYXNzd29yZAo=
```

Esa `o=` del final es el salto de línea codificado.

**Verifica**:

```bash
# El de echo da 401, con la credencial "correcta". Este es el sintoma.
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Basic $(echo 'user:password' | base64)" \
  http://localhost:8080/basic-auth/user/password
# 401
```

```bash
# El de printf da 200.
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Basic $(printf 'user:password' | base64)" \
  http://localhost:8080/basic-auth/user/password
# 200
```

---

## Paso 7: El endpoint que miente

**Por qué**: no todos los servidores devuelven `401` cuando falta la credencial.
Algunos devuelven `404` para no confirmar que el recurso existe. Si no sabes que
esto pasa, abrirás un ticket diciendo que el endpoint no existe.

**Comando**:

```bash
# Sin credencial: 404. Parece que la ruta no existe.
curl -s -o /dev/null -w '%{http_code}\n' \
  http://localhost:8080/hidden-basic-auth/user/password
# 404
```

**Verifica**:

```bash
# Con credencial: 200. Existia todo el rato.
curl -s -o /dev/null -w '%{http_code}\n' \
  -u user:password http://localhost:8080/hidden-basic-auth/user/password
# 200
```

```bash
# La comparacion, para que quede claro el contraste con el endpoint normal.
for ruta in /basic-auth/user/password /hidden-basic-auth/user/password; do
  printf '%-38s sin credencial: ' "$ruta"
  curl -s -o /dev/null -w '%{http_code}' "http://localhost:8080$ruta"
  printf '   con credencial: '
  curl -s -o /dev/null -w '%{http_code}\n' -u user:password "http://localhost:8080$ruta"
done
# /basic-auth/user/password              sin credencial: 401   con credencial: 200
# /hidden-basic-auth/user/password       sin credencial: 404   con credencial: 200
```

---

## Paso 8: Que curl pregunte la password

**Por qué**: es la primera forma de sacar el secreto de la línea de comandos, y
la única que sirve en una sesión interactiva sin preparar ningún archivo. La
password no queda en `ps` ni en el historial del shell.

**Comando**:

```bash
# -u con el usuario y SIN los dos puntos ni la password: curl la pide.
curl -s -o /dev/null -w '%{http_code}\n' \
  -u user http://localhost:8080/basic-auth/user/password
# Enter host password for user 'user':
# 200
```

Escribe `password` cuando lo pregunte. No se ve mientras escribes, es normal.

**Verifica**:

```bash
# Comprueba que NO quedo en el historial: este comando no deberia encontrar la
# password en ninguna linea reciente.
history 2>/dev/null | tail -5 | grep -c 'password$' || echo "0"
```

En un script esto no vale —no hay nadie para escribirla— y ahí entran `--config`
y `--netrc-file`. Es la práctica 02 entera.

---

## ✅ Resultado

- [ ] `reto.md` existe y tiene los tres retos, más tu frase con la diferencia
- [ ] `authorization-a-mano.txt` existe y las dos líneas de base64 coinciden
- [ ] Sé por qué `printf` y `echo` dan base64 distintos, y cuál de los dos vale
- [ ] He visto que `/hidden-basic-auth` devuelve `404` sin credencial
- [ ] He usado `-u user` sin password y curl me la ha preguntado
- [ ] Puedo explicar por qué base64 no protege la credencial

```bash
./scripts/verificar-semana.sh 03
```

De las 17 comprobaciones, esta práctica prepara la de `toolkit-basic-auth`: el
resto llega con el proyecto.

---

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `Connection refused` en todo | El laboratorio no está levantado | `./scripts/start.sh` y espera a que el healthcheck pase |
| `401` con la credencial correcta | Usaste `echo` en vez de `printf` al construir el base64 | `printf 'user:password' \| base64`. Paso 6 |
| `401` y el base64 parece bien | Un espacio de más dentro de las comillas | `echo "$TU_BASE64" \| base64 -d` y mira qué sale exactamente |
| `jq: command not found` | Falta `jq` | `sudo apt install jq` o `brew install jq` |
| `-u user` no pregunta nada y falla | La entrada estándar no es una terminal (lo lanzaste desde un script o con `< /dev/null`) | Ejecútalo directamente en tu terminal |
| El `for` del paso 2 no imprime nada | El endpoint contestó 200 y no hay reto que leer | Comprueba la ruta: `/bearer` sin credencial tiene que dar 401 |
| `base64: invalid input` | La cadena tiene un carácter de más al copiarla | Cópiala otra vez, sin el salto de línea final |

---

| Anterior | Siguiente |
|---|---|
| [Teoría 08 — Cuando la credencial falla](../1-teoria/08-cuando-la-credencial-falla.md) | [Práctica 02 — Sacar la credencial de la línea](02-sacar-la-credencial-de-la-linea.md) |
