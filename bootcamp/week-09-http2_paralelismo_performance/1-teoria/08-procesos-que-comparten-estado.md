# Procesos que comparten estado

> En cuanto un script se ejecuta dos veces a la vez, todo lo que guarda en
> disco se convierte en un sitio donde dos procesos se pisan. El toolkit
> guarda una sesión OAuth2: ocho procesos con el token caducado lo renuevan
> ocho veces, y con un servidor que rota el refresh token, siete de ellos
> fallan. Un cerrojo de una línea, `flock`, lo deja en una renovación.

![Ocho procesos encuentran a la vez la sesión caducada. Sin cerrojo, los ocho piden un token nuevo al servidor y escriben la sesión uno encima de otro; con un refresh token que rota, el segundo y siguientes reciben invalid_grant. Con flock, el primero renueva mientras los demás esperan; al entrar, cada uno relee la sesión, ve que el token ya cambió y no ha caducado, y la usa sin renovar](../0-assets/08-procesos-que-comparten-estado.svg)

## 🎯 Objetivos

- Reconocer una condición de carrera en un script que guarda estado en disco
- Usar `flock` para que solo un proceso a la vez entre en una sección
- Aplicar el patrón "comprobar, cerrar, volver a comprobar"
- Saber qué protege ya la escritura atómica con `mv` y qué no
- Lanzar procesos en paralelo con `&` y `wait`, y recoger su resultado

---

## 1. Qué problema resuelve

Un cron lanza cada minuto ocho instancias del toolkit, una por cliente. Todas
usan la misma sesión OAuth2. A la hora en punto el token caduca, y las ocho
lo ven caducado **en el mismo segundo**:

1. Las ocho leen la sesión: caducada.
2. Las ocho piden un token nuevo al servidor.
3. Las ocho escriben la sesión, cada una con su token.

Con client credentials, el resultado es desperdicio: ocho tokens donde
bastaba uno, y ocho peticiones al servidor OAuth2, que también tiene rate
limit. Con un **refresh token que rota** (teoría 06 de la Semana 08), es un
fallo: la primera que renueva invalida el refresh token, y las otras siete
reciben `invalid_grant` y salen con 77.

Medido en el laboratorio con la capa 8:

```bash
# 8 procesos, sesión caducada a mano
grep -c renovado errores.log
# 8
```

---

## 2. Cómo funciona

### 2.1 La escritura atómica no basta

Desde la Semana 08, `guardar_sesion` escribe en un temporal y hace `mv`. Eso
garantiza que nadie lee **un JSON a medias**. No garantiza que dos procesos no
**decidan a la vez** renovar: el problema no es escribir, es la secuencia
"leer, decidir, actuar, escribir", que tiene que ir entera sin que otro se
cuele en medio.

### 2.2 `flock`

`flock` (de util-linux) pide al kernel un **cerrojo** sobre un archivo. Si
otro proceso lo tiene, espera. El cerrojo se suelta al cerrar el archivo, o
cuando el proceso muere, aunque sea con `kill -9`: no se queda colgado.

La forma más usada en bash abre el archivo en un descriptor y bloquea ese
descriptor:

```bash
exec 9>>/ruta/archivo.lock     # abre (y crea si no existe) en el descriptor 9
flock -w 30 9 || exit 1        # espera hasta 30 s a tener el cerrojo
# ... sección crítica: solo un proceso a la vez ...
exec 9>&-                      # cierra el descriptor: suelta el cerrojo
```

- `>>` y no `>`: el archivo del cerrojo no se trunca, y no importa su
  contenido.
- El `.lock` nace con la umask de quien ejecuta, casi siempre 644. Está vacío
  y no filtra nada, pero otro usuario que lo pueda abrir puede coger el
  cerrojo y bloquearte. El toolkit lo abre con `umask 077` y después
  restaura la que había.
- `-w 30`: sin límite, un proceso colgado dentro bloquea a todos para siempre.
- `-n`: no espera; si está cogido, falla al momento. Útil para "si ya hay uno
  corriendo, no arranco otro".

### 2.3 Comprobar, cerrar, volver a comprobar

Con el cerrojo solo, los ocho procesos seguirían renovando ocho veces: uno
detrás de otro, en vez de a la vez. El paso que falta es **volver a mirar con
el cerrojo en la mano**:

1. Fuera del cerrojo: ¿la sesión está caducada? Si no, usarla. (Rápido: la
   mayoría de las veces no hay que renovar y nadie espera.)
2. Coger el cerrojo.
3. Dentro: ¿el token **sigue siendo el que vi caducado**? Si otro proceso
   acaba de renovar, el token es otro y no ha caducado: soltar y usarlo.
4. Si no, renovar, guardar y soltar.

El toolkit pasa a `renovar` el token que vio (`VISTO`). Sirve para los dos
casos que renuevan: el token caducado antes de la petición y el 401 después.

### 2.4 Dónde va el cerrojo

Al lado de lo que protege: `~/.bc-curl-session.lock` para
`~/.bc-curl-session`. Dos sesiones distintas (dos `OAUTH_SESSION_FILE`) no se
bloquean entre sí. Un cerrojo global en `/tmp` bloquearía también a otro
usuario con su propia sesión.

El archivo `.lock` se queda en disco después: está vacío, y borrarlo abre una
carrera nueva (un proceso abre el viejo y otro crea uno nuevo, y cada uno
tiene "su" cerrojo).

### 2.5 Sin `flock`

`flock` viene con util-linux: está en cualquier Linux, pero **no en macOS**
(se instala con `brew install flock`). El toolkit no lo exige: si no está,
renueva sin cerrojo, como la capa 8, y lo dice en un comentario `ponytail:`.
Una alternativa portable es `mkdir` (atómico en todos los sistemas), pero
exige limpiar el directorio si el proceso muere: más código para un caso que
casi nadie tiene.

### 2.6 Lanzar en paralelo desde bash

Para probarlo hace falta lanzar varios procesos a la vez:

```bash
for i in 1 2 3 4 5 6 7 8; do
  ./api-toolkit.sh get /userinfo > "salida.$i" 2>> errores.log &
done
wait
```

- `&` lanza cada uno en segundo plano; `wait` espera a todos.
- Cada uno escribe su stdout en **su** archivo: ocho procesos escribiendo en
  el mismo archivo con `>` se pisan; con `>>` las líneas cortas no se
  mezclan, pero el orden es cualquiera.
- `wait` sin argumentos devuelve 0 aunque alguno fallara. Para saberlo, guarda
  los PID (`$!`) y haz `wait "$pid"` de cada uno.

---

## 3. Cómo se usa

La sección crítica del toolkit, resumida:

```bash
renovar() {
  local visto="${1:-}" mascara
  mascara="$(umask)"; umask 077
  exec 9>>"${OAUTH_SESSION_FILE}.lock"    # nace 600 aunque tu umask sea 022
  umask "$mascara"
  flock -w "$ESPERA_CERROJO" 9 || error "otro proceso lleva demasiado renovando"
  if [ -n "$visto" ] && [ "$(jq -r .access_token "$OAUTH_SESSION_FILE")" != "$visto" ] \
      && ! sesion_caducada; then
    exec 9>&-          # otro proceso ya renovó
    return 0
  fi
  # ... pedir el token y guardar_sesion ...
  exec 9>&-
}
```

Con la capa 9, los mismos ocho procesos:

```bash
grep -c renovado errores.log
# 1
```

Y para ver el cerrojo cogido desde fuera, en otra terminal mientras un
proceso lo tiene:

```bash
flock -n ~/.bc-curl-session.lock true || echo "cogido"
# cogido
```

---

## 4. Antipatrones

- **Un `sleep` aleatorio para "repartir" los procesos.** Reduce la carrera, no
  la elimina, y hace el script más lento siempre.
- **Comprobar si existe un archivo `.lock` y crearlo** (`[ -e x ] || touch x`).
  Entre la comprobación y el `touch` cabe otro proceso: es la misma carrera.
- **`flock` sin `-w`**: un proceso colgado en la sección bloquea al resto para
  siempre.
- **Coger el cerrojo para leer.** Leer la sesión vigente no necesita cerrojo:
  el `mv` atómico ya garantiza que se lee entera. El cerrojo es solo para
  renovar.
- **Olvidar la segunda comprobación.** Sin ella, el cerrojo solo pone en fila
  las ocho renovaciones.
- **Un cerrojo en `/tmp/toolkit.lock` para todos.** Bloquea sesiones que no
  tienen nada que ver.

---

## 5. Trucos

- **`flock` con un comando**: `flock -w 10 archivo.lock comando args` coge el
  cerrojo, ejecuta y lo suelta. Para cron: `flock -n /ruta/job.lock
  ./job.sh` evita que dos ejecuciones se solapen.
- **Descriptor 9** es una convención: los bajos (0, 1, 2) son stdin, stdout y
  stderr, y los de 3 a 9 están libres para el script.
- **`$!`** es el PID del último proceso lanzado con `&`.
- **`xargs -P 8`** lanza procesos en paralelo con un máximo, sin bucle ni
  `wait`: `seq 8 | xargs -P 8 -I{} ./api-toolkit.sh get /userinfo`.
- **Para provocar la carrera** sin esperar una hora, pon `expires_at` a 0 en la
  sesión con `jq` (como en la práctica 03 de la Semana 08).

---

## 📚 Recursos Adicionales

- [Manual de flock(1)](https://man7.org/linux/man-pages/man1/flock.1.html)
- [Bash Reference Manual — Redirections](https://www.gnu.org/software/bash/manual/html_node/Redirections.html)
- [BashFAQ/045 — How can I ensure that only one instance of a script is running?](https://mywiki.wooledge.org/BashFAQ/045)

---

## ✅ Checklist de Verificación

- [ ] Explicas por qué el `mv` atómico no evita ocho renovaciones a la vez
- [ ] Coges y sueltas un cerrojo con `exec 9>>` y `flock -w`
- [ ] Explicas el patrón de comprobar, cerrar y volver a comprobar
- [ ] Sabes por qué el archivo `.lock` no se borra
- [ ] Lanzas procesos con `&`, esperas con `wait` y sabes qué devuelve `wait`
