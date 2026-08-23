# Práctica 03 — Bearer y el JWT por dentro

> **Duración**: 50 min · **Entregable**: `jwt.md`

Vas a pedir un token de verdad al servidor del laboratorio, usarlo, abrirlo con
`base64` y `jq`, y decidir si está vigente. Todo sin instalar nada y sin mandarle
tu token a ninguna página web.

**Antes de empezar**:

```bash
./scripts/start.sh
cd ~/bc-curl-trabajo/semana-03
# El servidor de tokens del laboratorio vive en el 8081.
curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 \
  http://localhost:8081/default/.well-known/openid-configuration
# 200
```

---

## Paso 1: Mandar un token y comprobar que llega entero

**Por qué**: el fallo más común con Bearer es silencioso. El token viaja **casi**
entero —con una comilla de más, con un salto de línea— y el servidor devuelve
`401` sin decir por qué. El endpoint `/bearer` del laboratorio te devuelve lo que
recibió, así que sirve de espejo.

**Comando**:

```bash
# El laboratorio acepta cualquier token no vacio: lo que comprueba es el
# formato del header, no el valor.
curl -s -H 'Authorization: Bearer token-de-laboratorio' \
  http://localhost:8080/bearer | jq -c .
# {"authenticated":true,"token":"token-de-laboratorio"}
```

**Verifica**:

```bash
# Lo que el servidor recibio tiene que ser EXACTAMENTE lo que mandaste.
curl -s -H 'Authorization: Bearer token-de-laboratorio' \
  http://localhost:8080/bearer | jq -r '.token'
# token-de-laboratorio
```

---

## Paso 2: Provocar el fallo de las comillas

**Por qué**: pasa cuando sacas el token de un JSON con `jq` **sin** `-r`. Las
comillas del JSON se van dentro del header y el token deja de ser el token. Verlo
ahora te ahorra buscarlo a ciegas dentro de un mes.

**Comando**:

```bash
# Con -r, jq devuelve el valor pelado.
jq -rn '"token-de-laboratorio"'
# token-de-laboratorio
```

```bash
# Sin -r, se lleva las comillas. Y esas comillas acaban en el header.
jq -n '"token-de-laboratorio"'
# "token-de-laboratorio"
```

**Verifica**:

```bash
# El espejo del laboratorio delata el problema: el token que recibio lleva
# comillas dentro.
curl -s -H 'Authorization: Bearer "token-de-laboratorio"' \
  http://localhost:8080/bearer | jq -r '.token'
# "token-de-laboratorio"
```

Contra una API real esto no da un mensaje claro: da `401`. La regla, entonces:
**`jq -r` siempre que el valor vaya a un header.**

---

## Paso 3: Pedir un token de verdad

**Por qué**: hasta ahora el token era una cadena inventada. El servidor del
puerto 8081 emite tokens firmados con caducidad real, que es lo que vas a
diseccionar en los pasos siguientes. Los flujos OAuth2 completos son la Semana
08; aquí solo lo usamos como fuente de token.

**Comando**:

```bash
# La respuesta trae el token, su tipo y los segundos que le quedan de vida.
curl -s --max-time 10 -X POST http://localhost:8081/default/token \
  -d 'grant_type=client_credentials' \
  -d 'client_id=bc-curl' \
  -d 'client_secret=lab' \
  -d 'scope=api' | jq -c '{token_type, expires_in}'
# {"token_type":"Bearer","expires_in":3599}
```

> [!NOTE]
> Ese `client_secret=lab` está en la línea de comandos, que es justo lo que la
> práctica 02 dice que no se hace. Aquí es a propósito, para que el flujo se lea
> de un vistazo, y el secreto es de laboratorio. En el paso 8 lo montarás bien.

**Verifica**:

```bash
# Guardar solo el token, con -r para que no se lleve las comillas.
TOKEN=$(curl -s --max-time 10 -X POST http://localhost:8081/default/token \
  -d 'grant_type=client_credentials' -d 'client_id=bc-curl' \
  -d 'client_secret=lab' -d 'scope=api' | jq -r '.access_token')

# Los primeros caracteres de un JWT son casi siempre eyJ: es {" en base64url.
echo "${TOKEN:0:3}"
# eyJ
```

---

## Paso 4: Usarlo y comprobar que sirve

**Por qué**: antes de abrirlo, confirma que el token funciona. Si no funciona, el
problema está en cómo lo pides o en cómo lo mandas, no en lo que lleva dentro.

**Comando**:

```bash
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8080/bearer \
  | jq -c '.authenticated'
# true
```

**Verifica**:

```bash
# Y que lo que llego coincide con lo que mandaste, byte a byte.
recibido=$(curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/bearer | jq -r '.token')
[ "$recibido" = "$TOKEN" ] && echo "identico" || echo "DIFERENTE: revisa el header"
# identico
```

---

## Paso 5: Partirlo en tres

**Por qué**: un JWT son tres cadenas separadas por puntos. Contar los puntos es
la forma de distinguir un JWT de un token opaco **antes** de intentar
decodificarlo y llevarte un error confuso.

**Comando**:

```bash
# Tres partes: header, payload y firma.
tr '.' '\n' <<<"$TOKEN" | wc -l
# 3
```

```bash
# Cada una, con su longitud. La tercera es la firma.
tr '.' '\n' <<<"$TOKEN" | awk '{print NR": "length($0)" caracteres"}'
# 1: 58 caracteres
# 2: 239 caracteres
# 3: 342 caracteres
```

Las longitudes exactas variarán en tu ejecución: dependen del contenido.

**Verifica**:

```bash
# La comprobacion que hace un script antes de decodificar nada.
[ "$(tr -cd '.' <<<"$TOKEN" | wc -c)" -eq 2 ] && echo "JWT" || echo "opaco"
# JWT
```

---

## Paso 6: Decodificar el payload, con el relleno

**Por qué**: aquí es donde falla todo el mundo. base64url no lleva relleno y
`base64 -d` lo necesita. Sin él, el comando **imprime el resultado y además da
error**, así que en un script con `set -o pipefail` tumba la ejecución aunque
parezca que ha funcionado.

**Comando**:

```bash
# Primero, sin relleno, para ver el problema. Fijate en el final de la salida.
p=$(cut -d. -f2 <<<"$TOKEN")
printf '%s' "$p" | tr '_-' '/+' | base64 -d
# {"sub":"bc-curl",...}base64: invalid input
```

```bash
# La longitud, y lo que le falta para ser multiplo de 4.
echo "longitud: ${#p}, resto: $(( ${#p} % 4 ))"
# longitud: 239, resto: 3
```

**Verifica**:

```bash
# Con el relleno calculado: sin aviso, y con codigo de salida 0.
relleno=$(( (4 - ${#p} % 4) % 4 ))
printf '%s%s' "$p" "$(printf '=%.0s' $(seq 1 "$relleno"))" \
  | tr '_-' '/+' | base64 -d | jq
echo "salida: $?"
# {
#   "sub": "bc-curl",
#   "aud": "api",
#   "nbf": 1787502409,
#   "iss": "http://localhost:8081/default",
#   "exp": 1787506009,
#   "iat": 1787502409,
#   "jti": "6b66f762-311b-4405-ad56-0da5606749e4",
#   "tid": "default"
# }
# salida: 0
```

Los valores de tu token serán otros: se emite en el momento.

---

## Paso 7: Leer la caducidad y decidir

**Por qué**: esto es lo único del payload que te sirve como cliente. Saber cuándo
caduca es lo que permite renovar el token **antes** de que falle, en vez de
reaccionar a un `401`.

**Comando**:

```bash
# Una funcion reutilizable, con la comprobacion de las tres partes incluida.
jwt_payload() {
  local token="$1" p relleno
  [ "$(tr -cd '.' <<<"$token" | wc -c)" -eq 2 ] \
    || { echo "no parece un JWT" >&2; return 1; }
  p=$(cut -d. -f2 <<<"$token")
  relleno=$(( (4 - ${#p} % 4) % 4 ))
  printf '%s%s' "$p" "$(printf '=%.0s' $(seq 1 "$relleno"))" \
    | tr '_-' '/+' | base64 -d
}

exp=$(jwt_payload "$TOKEN" | jq -r '.exp')
date -d "@$exp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$exp" '+%Y-%m-%d %H:%M:%S'
# 2026-08-23 17:29:43
```

**Verifica**:

```bash
# El veredicto, con 60 segundos de margen para que no caduque entre la
# comprobacion y la peticion.
if [ "$(date +%s)" -lt $(( exp - 60 )) ]; then
  echo "vigente, quedan $(( (exp - $(date +%s)) / 60 )) minutos"
else
  echo "caducado o a punto: hay que renovarlo"
fi
# vigente, quedan 59 minutos
```

```bash
# El entregable.
{
  echo "# El JWT por dentro"
  echo
  echo '## Payload'
  echo
  echo '```json'
  jwt_payload "$TOKEN" | jq
  echo '```'
  echo
  echo "## Caducidad"
  echo
  echo "- \`exp\`: $exp"
  echo "- En fecha: $(date -d "@$exp" '+%F %T' 2>/dev/null || date -r "$exp" '+%F %T')"
  echo "- Veredicto: $([ "$(date +%s)" -lt "$exp" ] && echo vigente || echo caducado)"
} > jwt.md
head -6 jwt.md
```

Añade a mano, al final de `jwt.md`, una frase explicando por qué **no** has
validado la firma y qué implicaría intentarlo desde el cliente.

---

## Paso 8: El flujo entero, sin secretos en el argv

**Por qué**: junta la práctica 02 con esta. Es el patrón que usarás en el
proyecto: el secreto de cliente entra por un archivo, el token sale a una
variable, y el token tampoco toca la línea de comandos de la segunda petición.

**Comando**:

```bash
# El cuerpo del login en un archivo, con -d @archivo. Asi el client_secret no
# esta en el argv de curl.
(umask 077; cat > login.txt <<'EOF'
grant_type=client_credentials&client_id=bc-curl&client_secret=lab&scope=api
EOF
)

TOKEN=$(curl -sS --max-time 10 --fail-with-body \
  -X POST -d @login.txt http://localhost:8081/default/token | jq -r '.access_token')
```

```bash
# Y el token, al archivo de --config de la practica 02.
(umask 077; printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" > auth.conf)

curl -s --config auth.conf http://localhost:8080/bearer | jq -c '.authenticated'
# true
```

**Verifica**:

```bash
# Ni el client_secret ni el token aparecen en ningun argv de curl.
curl -s --config auth.conf http://localhost:8080/delay/3 >/dev/null &
sleep 1; ps -eo args | grep '^curl ' | grep -cE "lab|$TOKEN" || true
wait
# 0
```

```bash
# Limpieza: login.txt lleva el secreto de cliente.
rm -f login.txt
```

---

## ✅ Resultado

- [ ] He comprobado con `/bearer` que el token llega idéntico a como lo mando
- [ ] He provocado el fallo de las comillas y sé qué lo causa
- [ ] He pedido un token real al servidor del puerto 8081
- [ ] He contado las tres partes del JWT antes de decodificar nada
- [ ] He visto el error de `base64` sin relleno, y lo he resuelto calculándolo
- [ ] `jwt.md` tiene el payload, el `exp` en fecha legible y el veredicto
- [ ] He añadido a mano la frase sobre por qué no valido la firma
- [ ] En el flujo del paso 8, ni el `client_secret` ni el token salen en `ps`

```bash
./scripts/verificar-semana.sh 03
```

Esta práctica prepara `toolkit-bearer` y `toolkit-bearer-token-intacto`.

---

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `000` al pedir el token | El servidor del 8081 no está levantado | `./scripts/start.sh`. El contenedor es `bc-curl-oauth` |
| `.access_token` sale `null` | El `grant_type` o el `scope` no son los del ejemplo | Copia el comando del paso 3 tal cual |
| `base64: invalid input` | Falta el relleno | Paso 6: `(4 - len % 4) % 4` |
| El payload sale como basura binaria | Falta el `tr '_-' '/+'` | El `tr` va siempre, aunque este token no lleve `-` ni `_` |
| `jq: error ... Invalid numeric literal` | Estás pasando a `jq` el token entero, no el payload decodificado | `cut -d. -f2` primero |
| `date: invalid date '@…'` | Estás en macOS | `date -r "$exp"`. Los comandos de aquí ya prueban las dos |
| El veredicto dice caducado nada más pedirlo | Interpretaste `exp` como milisegundos, o tu reloj va mal | `exp` son segundos. Comprueba con `date` |
| `no parece un JWT` | El token es opaco, sin partes | Correcto: no todos los Bearer son JWT |
| El `grep -cE` del paso 8 da `1` | `$TOKEN` está vacío y el patrón casa con cualquier cosa | Comprueba que `echo "${TOKEN:0:3}"` da `eyJ` |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 02 — Sacar la credencial de la línea](02-sacar-la-credencial-de-la-linea.md) | [Práctica 04 — Cuando la credencial falla](04-cuando-la-credencial-falla.md) |
