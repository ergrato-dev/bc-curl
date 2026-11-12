# Guardar la sesión

> Un token que solo vive en una variable muere con el script, y el siguiente
> cron vuelve a pedirlo. Guardarlo en disco es lo razonable, y es también
> dejar una credencial en un archivo. Este archivo trata de cómo hacerlo sin
> que ese archivo se convierta en el punto débil: dónde, con qué permisos, cómo
> escribirlo sin romperlo y cómo deshacerse de él de verdad.

![El archivo de sesión y lo que lo protege: arriba, su contenido JSON (access_token, token_type, expires_in, expires_at y refresh_token si lo hay) en ~/.bc-curl-session con permisos 600, fuera del repositorio. En el centro, la escritura atómica: jq escribe en un temporal del mismo directorio creado por mktemp con 600, y mv lo renombra sobre la sesión; un corte a medias deja la sesión anterior intacta. Abajo, el logout en dos pasos: revocar el refresh_token en el servidor y solo entonces borrar el archivo](../0-assets/08-guardar-la-sesion.svg)

## 🎯 Objetivos

- Elegir dónde vive la sesión y con qué permisos
- Escribirla de forma atómica, sin dejar nunca un JSON a medias
- Saber qué se puede enseñar de una sesión y qué no se imprime nunca
- Cerrar la sesión revocando antes de borrar

---

## 1. Qué problema resuelve

Cuatro formas en que un archivo de sesión sale mal, todas vistas en scripts
reales:

| Lo que pasa | Consecuencia |
|---|---|
| `echo "$respuesta" > ~/.token` con la umask por defecto | El archivo queda con 644: cualquier usuario de la máquina lee el token |
| La sesión vive en el directorio del proyecto | Un `git add .` la sube al repositorio |
| El script muere a mitad de `jq ... > sesion.json` | La sesión queda vacía o cortada, y el siguiente uso falla con un error de JSON en vez de pedir login |
| `logout` hace `rm ~/.token` | El refresh token sigue vivo en el servidor durante semanas, en todas las copias de seguridad del disco |

El toolkit tiene que hacerlo bien porque, a diferencia de una persona, lo va
a hacer miles de veces sin que nadie mire.

---

## 2. Cómo funciona

### 2.1 Dónde

| Opción | Problema |
|---|---|
| El directorio del proyecto | Acaba en git |
| `/tmp` | Se borra al reiniciar, y en algunos sistemas es compartido |
| **`~/.bc-curl-session`** | El del toolkit: en tu `HOME`, fuera de cualquier repositorio, junto a `~/.bc-curl` |
| `~/.local/state/api-toolkit/session.json` | Lo que pide la especificación XDG. Igual de válido; un archivo más que crear |
| El llavero del sistema (`secret-tool`, `security`) | Lo más seguro en un escritorio; no existe en un servidor sin sesión gráfica |

El toolkit usa `OAUTH_SESSION_FILE`, con `~/.bc-curl-session` por defecto, y
la misma regla que `~/.bc-curl` desde la Semana 03: **nunca dentro del
repositorio**.

### 2.2 Con qué permisos

`600`: lectura y escritura solo para el dueño. Dos momentos:

- **Al crearla.** `mktemp` crea los archivos con 600 sin depender de la
  umask. Una redirección `>` a un archivo nuevo usa la umask (normalmente
  022, es decir, 644).
- **Al leerla.** Si alguien la copió o la editó y quedó con 644, el toolkit se
  niega a usarla: `exigir_600`, la misma función que protege la clave privada
  del mTLS y el tarro de cookies.

```bash
ls -l ~/.bc-curl-session | cut -c1-10
# -rw-------
```

### 2.3 Qué guarda

La respuesta del endpoint de token tal cual, más un campo:

```json
{
  "access_token": "eyJ...",
  "token_type": "Bearer",
  "expires_in": 3599,
  "expires_at": 1794449607,
  "refresh_token": "82dca34e-..."
}
```

`expires_at` es el instante de caducidad (teoría 06). `refresh_token` solo
está si el flujo lo dio. Guardar la respuesta entera y no solo el token tiene
una ventaja: si mañana hace falta el `scope` o el `id_token`, ya está.

Al renovar, si la respuesta no trae `refresh_token`, se conserva el anterior.
Al hacer `auth login`, no: una sesión nueva no hereda el refresh token de la
vieja, que podría ser de otra identidad.

### 2.4 Escritura atómica

`jq ... > sesion` trunca el archivo **antes** de escribir. Si el proceso
muere en medio (un `kill`, un disco lleno, un corte de luz), queda un archivo
vacío o cortado. La solución clásica:

1. Escribir en un temporal **del mismo directorio**
2. Si la escritura fue bien, `mv` del temporal sobre el definitivo

`mv` dentro de un mismo sistema de archivos es un `rename()`, que es atómico:
quien lea la sesión ve la vieja o la nueva, nunca una mezcla. Si el temporal
estuviera en `/tmp` y la sesión en `HOME`, podrían ser sistemas de archivos
distintos, y `mv` se convertiría en copiar y borrar: ya no es atómico.

```bash
nueva="$(mktemp "${OAUTH_SESSION_FILE}.XXXXXX")"
if ! jq ... "$CUERPO" > "$nueva"; then
  rm -f "$nueva"
  error "no se pudo escribir la sesion"
fi
mv -f "$nueva" "$OAUTH_SESSION_FILE"
```

Es la misma idea que el `.part` de `download` en la Semana 04: el nombre
definitivo solo aparece cuando el contenido está completo.

### 2.5 Qué se imprime y qué no

| Dato | ¿Se puede enseñar? | Por qué |
|---|:--:|---|
| `access_token` | No | Es un *bearer*: quien lo ve, lo usa hasta que caduque |
| `refresh_token` | **Nunca** | Vale semanas y fabrica access tokens |
| `client_secret` | **Nunca** | Fabrica tokens sin límite |
| `sub`, `exp`, `scope`, `jti` | Sí | Dicen de quién es y hasta cuándo, sin dar acceso |
| La ruta de la sesión | Sí | Saber dónde está ayuda a depurar |

`auth status` enseña lo segundo:

```bash
./api-toolkit.sh auth status
# activa: expira en 3540 s, sub=api-toolkit, refresh_token: no
```

Y se cuidan los caminos por los que un token se escapa sin un `echo`:

| Camino | Cómo se cierra |
|---|---|
| `set -x` | El toolkit no lo activa. Si depuras con él, el token aparecerá en la traza |
| Argumentos de un proceso (`jq --arg token "$TOKEN"`, `curl -H "Authorization: ..."`) | El token entra por archivo o por stdin; el header va en el `--config` |
| La traza de `--verbose` | `redactar_traza` tacha `Authorization` desde la Semana 06 |
| Mensajes de error que vuelcan la respuesta | La respuesta del endpoint de token va a `CUERPO`, y de ahí a la sesión: nunca a stderr |

### 2.6 Cerrar la sesión de verdad

Borrar el archivo solo borra **tu copia**. El refresh token sigue vivo en el
servidor, y en cualquier copia de seguridad que se hiciera mientras existía.
`auth logout` hace dos pasos, en este orden:

1. **Revocar** en el servidor (RFC 7009): el refresh token si lo hay; si no,
   el access token.
2. **Borrar** el archivo.

Si la revocación falla (red caída, 503), la sesión **no** se borra: el
`logout` sale con el código del fallo y se puede repetir. Si se borrara igual,
el token quedaría vivo y ya no habría forma local de revocarlo.

La excepción es `unsupported_token_type`: el servidor dice que no revoca ese
tipo de token. Reintentar no lo va a cambiar, así que se avisa y se borra:

```bash
./api-toolkit.sh auth logout
# aviso: el servidor no revoca el access_token: sigue valido hasta que caduque
# sesion cerrada
```

---

## 3. Cómo se usa

El ciclo completo con el toolkit, con las credenciales del cliente en
`~/.bc-curl` (Semana 03):

```bash
(umask 077 && touch ~/.bc-curl)    # si es nuevo, nace con 600
cat >> ~/.bc-curl <<'EOF'
OAUTH_CLIENT_ID=api-toolkit
OAUTH_CLIENT_SECRET=secreto-de-laboratorio
EOF
chmod 600 ~/.bc-curl

./api-toolkit.sh auth login
# sesion guardada en /home/tu-usuario/.bc-curl-session
AUTH_MODE=oauth BASE_URL=http://localhost:8081/default ./api-toolkit.sh get /userinfo | jq -r .sub
# api-toolkit
./api-toolkit.sh auth logout
# aviso: el servidor no revoca el access_token: sigue valido hasta que caduque
# sesion cerrada
```

Una sesión con permisos de más:

```bash
./api-toolkit.sh auth login 2>/dev/null
chmod 644 ~/.bc-curl-session
./api-toolkit.sh auth status; echo "salida: $?"
# error: /home/tu-usuario/.bc-curl-session es legible por otros usuarios. Arreglalo con: chmod 600 "/home/tu-usuario/.bc-curl-session"
# salida: 1
chmod 600 ~/.bc-curl-session
```

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `echo "$token" > ~/.token` | 644 por la umask, y el token pasa por un `echo` que alguien acabará copiando a un log | `mktemp` (600) y `mv` |
| La sesión en el directorio del proyecto | Acaba en git, y un token en el historial de git es para siempre | `HOME`, fuera de cualquier repositorio |
| `jq ... > sesion` directamente | Un corte deja la sesión vacía | Temporal del mismo directorio y `mv` |
| Temporal en `/tmp` y `mv` a `HOME` | Puede cruzar sistemas de archivos: deja de ser atómico | `mktemp "${OAUTH_SESSION_FILE}.XXXXXX"` |
| `logout` como `rm` | El refresh token sigue vivo | Revocar y luego borrar |
| Borrar aunque la revocación falle | Ya no hay forma local de revocar | Conservar la sesión y salir con el código del fallo |
| Un `status` que imprime el token "para comprobar que existe" | El token acaba en la terminal, en el historial del terminal y en una captura | `sub` y tiempo restante |

---

## 5. Trucos

- **`git check-ignore -v ~/.bc-curl-session`** no sirve: está fuera del
  repositorio, que es justo la idea. Lo que sí sirve es un
  `git status --porcelain | grep -i session` antes de cada commit.
- **En un escritorio Linux, el llavero**: `secret-tool store --label=api-toolkit
  servicio api-toolkit < sesion.json` guarda la sesión cifrada con tu login;
  `secret-tool lookup servicio api-toolkit` la recupera. El toolkit se queda
  con el archivo porque tiene que funcionar también en un servidor.
- **`shred -u` no protege en un SSD** ni en sistemas de archivos con copia en
  escritura: el bloque viejo sigue en algún sitio. Por eso lo que protege de
  verdad es revocar, no borrar bien.

---

## 📚 Recursos Adicionales

- [RFC 7009 — OAuth 2.0 Token Revocation](https://datatracker.ietf.org/doc/html/rfc7009)
- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/latest/)
- [`rename(2)` — atomicidad del renombrado](https://man7.org/linux/man-pages/man2/rename.2.html)

---

## ✅ Checklist de Verificación

- [ ] Tu sesión vive fuera del repositorio y tiene permisos 600
- [ ] Explicas por qué el temporal tiene que estar en el mismo directorio que la sesión
- [ ] Sabes qué datos de la sesión se pueden enseñar y cuáles no
- [ ] Ves al toolkit negarse a usar una sesión con 644
- [ ] Explicas por qué `logout` revoca antes de borrar, y qué hace si la revocación falla
