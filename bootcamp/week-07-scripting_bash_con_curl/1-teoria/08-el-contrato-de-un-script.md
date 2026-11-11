# El contrato de un script

> Un script que llama a una API acaba llamado por otro programa: un cron, un
> pipeline de CI, otro script. Ese programa no lee tus mensajes. Lee tu
> código de salida y tu stdout. Lo que pongas en cada uno es un contrato, y
> romperlo es la forma más silenciosa de hacer daño.

![Diagrama del contrato de api-toolkit: por stdout solo salen datos de una respuesta 2xx o 3xx; por stderr, los mensajes, la traza y el cuerpo de cualquier error; y el código de salida, con cinco valores: 0 éxito, 1 fallo definitivo, 69 sin respuesta HTTP, 75 fallo temporal que merece repetirse más tarde y 77 credencial rechazada; cada código conectado con lo que haría un cron que lo recibe](../0-assets/08-el-contrato-de-un-script.svg)

## 🎯 Objetivos

- Separar lo que va por stdout de lo que va por stderr, sin excepciones
- Traducir cada código HTTP a un código de salida que diga qué hacer
- Usar los códigos de `sysexits.h` en vez de inventar los tuyos
- Garantizar que la salida está completa o no existe

---

## 1. Qué problema resuelve

```bash
./sincronizar.sh > clientes.json && ./publicar.sh clientes.json
```

Una línea en un cron. Funciona si `sincronizar.sh` cumple tres cosas que nadie
ha escrito en ningún sitio:

- **Si falla, sale con algo distinto de 0**, y el `&&` no publica.
- **Si falla, no escribe en stdout**, porque el `>` ya ha creado
  `clientes.json` y lo que caiga ahí se trata como datos.
- **Si sale con 0, `clientes.json` está completo**, no con la mitad de las
  páginas.

Y una cuarta que el cron agradecería: si el fallo es **temporal**, decirlo, para
reintentar dentro de cinco minutos en vez de despertar a alguien a las tres de
la mañana.

---

## 2. Cómo funciona

### 2.1 Los códigos que ya están cogidos

| Código | Quién lo usa | Significado |
|:--:|---|---|
| 0 | Todos | Éxito |
| 1 | Todos | Fallo genérico |
| 2 | bash y muchas herramientas | Error de uso: argumentos mal |
| 64–78 | `sysexits.h` | Fallos con nombre (abajo) |
| 124 | `timeout` | El comando superó el tiempo |
| 126 | El shell | El archivo no es ejecutable |
| 127 | El shell | Comando no encontrado |
| 128 + N | El shell | Terminado por la señal N: 130 es Ctrl+C, 143 es `kill` |

Del 3 al 63 y del 79 al 125 están libres, pero un número que te inventes solo
lo entiende quien lea tu documentación. `sysexits.h` es una convención de los
BSD que lleva décadas en `/usr/include/` de cualquier Linux, y algunos
programas la entienden sin que nadie les explique nada:

| Código | Nombre | Para |
|:--:|---|---|
| 64 | `EX_USAGE` | Uso incorrecto |
| 65 | `EX_DATAERR` | Los datos de entrada están mal |
| 69 | `EX_UNAVAILABLE` | Un servicio necesario no está disponible |
| 75 | `EX_TEMPFAIL` | Fallo temporal: **repetir más tarde puede funcionar** |
| 77 | `EX_NOPERM` | Sin permiso |
| 78 | `EX_CONFIG` | Error de configuración |

El 75 es el más útil para un cliente de API. Los servidores de correo lo
usan desde los años ochenta para decir "no he podido entregarlo ahora, déjalo
en la cola".

### 2.2 stdout es para datos

La regla, sin excepciones: **por stdout sale el resultado, y nada más**.
Mensajes, avisos, progreso, la traza de `-v` y el **cuerpo de una respuesta de
error** van a stderr.

```bash
# Mal: el cuerpo del 429 sale por stdout
cat "$cuerpo"
echo "error: la API respondio $codigo" >&2

# Bien: stdout queda vacio, y quien lo lea por terminal ve las dos cosas
cat "$cuerpo" >&2
echo "error: la API respondio $codigo" >&2
```

El cuerpo de un error es información para una **persona**: dice qué falló.
Por stdout llegaría a un **programa**, que lo procesaría como si fuera la
respuesta que pidió. Con `2>&1` en la terminal se ven las dos cosas juntas;
en un `| jq` o un `> archivo`, solo los datos buenos.

### 2.3 Temporal o definitivo

Lo que quien llama necesita saber de un fallo es **si merece la pena repetir**.
Para un cliente HTTP, eso se lee en el código de la respuesta:

| Respuesta | Repetir... | Código de salida |
|---|---|:--:|
| 2xx, 3xx | — | 0 |
| 401, 403 | No: la credencial no vale | 77 |
| 404, 400, 422 y el resto de 4xx | No: la petición está mal | 1 |
| 429 | Sí, cuando diga `Retry-After` | 75 |
| 502, 503, 504 | Sí: el servidor o su proxy están de paso | 75 |
| 500 | Quizá: puede ser un bug que fallará siempre | 1 |
| Sin respuesta: DNS, conexión, TLS | Depende: un 6 no se arregla solo; un 7, quizá | 69 |

El 500 es la decisión discutible. El toolkit lo trata como definitivo: si
fuera temporal, el `--retry` del `GET` ya lo habría superado.

### 2.4 Completo o nada

Un script que escribe su salida según la va obteniendo deja, si falla a mitad,
**una salida a medias que parece buena**: un JSON de dos páginas en vez de
tres, perfectamente válido. Dos formas de evitarlo:

- **Acumular y escribir al final.** `fetch-all` guarda cada página en un
  temporal y no imprime nada hasta tener la última. Si una falla, stdout queda
  vacío.
- **Escribir en un temporal y mover.** `mv` dentro del mismo sistema de
  archivos es atómico: quien mira el destino ve el archivo viejo o el nuevo
  entero, nunca uno a medio escribir. Es la descarga a `DESTINO.part` de la
  Semana 04.

---

## 3. Cómo se usa

### 3.1 El contrato del toolkit

```bash
./api-toolkit.sh --help | sed -n '/^Codigos de salida/,/^$/p'
```

| Código | Cuándo | Qué hace un cron con él |
|:--:|---|---|
| 0 | 2xx o 3xx; en `fetch-all`, todas las páginas | Sigue |
| 1 | Uso incorrecto, 4xx/5xx definitivo, página que no es lista, `Link` fuera de la API | Avisa: alguien tiene que mirarlo |
| 69 | Sin respuesta HTTP | Avisa si se repite |
| 75 | 429, 502, 503, 504 tras los reintentos; descarga cortada | Reintenta en el siguiente ciclo |
| 77 | 401 o 403 | Avisa: la credencial caducó o no tiene permiso |

El 1 mezcla el error de uso con el fallo de la API porque el toolkit ya era
así en la Semana 01. Separarlos (64 para el uso) sería más limpio, y romper
el contrato de quien ya lo usa: un código de salida, una vez publicado, se
cambia con tanto cuidado como una API.

### 3.2 Del otro lado: quien llama

```bash
rc=0
./api-toolkit.sh fetch-all /paginas > clientes.json.tmp || rc=$?

case "$rc" in
  0)  mv clientes.json.tmp clientes.json ;;
  75) echo "temporal; se reintentara en el siguiente ciclo" >&2
      rm -f clientes.json.tmp ;;
  77) echo "credencial rechazada: renuevala" >&2
      rm -f clientes.json.tmp; exit 1 ;;
  *)  echo "fallo ($rc)" >&2
      rm -f clientes.json.tmp; exit 1 ;;
esac
```

Con un `case` sobre un contrato claro, el script de fuera hace lo correcto sin
leer un solo mensaje.

### 3.3 Documentarlo donde se ve

El contrato vive en el `--help`, no en un README aparte: es lo primero que
mira quien va a llamar al script, y lo único que se actualiza junto con el
código. El toolkit lo imprime desde los comentarios de cabecera (`uso`), así
que documentar un código nuevo es editar un comentario.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| `exit 1` para todo | Quien llama no distingue "repite" de "avisa" | 75 para lo temporal, 77 para la credencial |
| Mensajes por stdout | Se mezclan con los datos en un `>` o un `\|` | `>&2` |
| El cuerpo de un error por stdout | Un programa lo procesa como si fueran datos | `>&2` |
| Imprimir cada página según llega | Un fallo a mitad deja una salida válida e incompleta | Acumular y escribir al final |
| `exit 300` | Sale como 44 (300 mod 256) | Códigos entre 0 y 125 |
| Usar 126, 127 o 128+N | Quien llama cree que el problema es del shell o de una señal | `sysexits.h` |
| Cambiar un código de salida sin avisar | Rompe los `case` de todos los que te llaman | Tratarlo como un cambio de API |

---

## 5. Trucos

- **`sed -n '/^Codigos/,/^$/p'`** sobre el `--help` saca solo el contrato:
  útil para pegarlo en la documentación de quien te llama.
- **`set -o pipefail` en quien llama** también: `./api-toolkit.sh ... | jq`
  sin él pierde tu código de salida.
- **systemd entiende los códigos**: `RestartPreventExitStatus=77` en una
  unidad evita reiniciar un servicio cuyo problema es la credencial.

---

## 📚 Recursos Adicionales

- [`sysexits.h` — FreeBSD manual](https://man.freebsd.org/cgi/man.cgi?query=sysexits)
- [Bash Reference Manual — Exit Status](https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html)
- [The Linux Documentation Project — Exit Codes With Special Meanings](https://tldp.org/LDP/abs/html/exitcodes.html)

---

## ✅ Checklist de Verificación

- [ ] Tu script no escribe nada en stdout cuando falla
- [ ] El cuerpo de un error sale por stderr
- [ ] Un 429 y un 503 salen con 75; un 404, con 1; un 401, con 77
- [ ] `fetch-all` imprime todas las páginas o ninguna
- [ ] El contrato está en el `--help`
