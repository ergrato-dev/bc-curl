# Rúbrica de evaluación — Semana 04

> Archivos, formularios y multipart. Se evalúa que sepas mover bytes, sí, pero
> sobre todo que un archivo con el nombre bueno sea siempre el archivo bueno.

---

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales |
| 💪 Desempeño | 40% | Las 4 prácticas, con sus entregables .md y salida real de tu máquina |
| 📦 Producto | 30% | `api-toolkit.sh`: 60 pts de autograding + 40 pts de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio. Un `download` que pasa
todas las comprobaciones no compensa no saber por qué un 404 sin `--fail` sale
con 0.

---

## 🧠 Conocimiento (30%)

| # | Pregunta |
|:--:|---|
| 1 | `curl -s -o informe.pdf URL` sale con 0 y el archivo existe. ¿Qué tres cosas pueden estar mal en ese archivo a pesar de todo, y qué comprobación atrapa cada una? |
| 2 | En todo el bootcamp se recomienda `--fail-with-body`. ¿Por qué en una descarga a archivo se usa `--fail` a secas, y qué se pierde con ello? |
| 3 | Explica qué hace curl cuando le pasas `-C -`: qué mide, qué header envía, y qué hace con cada una de las tres respuestas posibles (`206`, `200`, `416`). |
| 4 | El patrón `.part` + `mv` se recomienda con el `.part` en el mismo directorio que el destino. ¿Por qué no en `/tmp`? ¿Qué propiedad se perdería? |
| 5 | Una descarga se cortó ayer al 60 % y hoy la reanudas con `-C -`. Termina con 0 y el tamaño es el correcto. ¿Qué puede haber salido mal, por qué el tamaño no lo detecta, y qué sí? |
| 6 | `--max-time 10` es la regla para llamadas de API. ¿Por qué no sirve para una descarga de 2 GB, por qué quitarlo tampoco sirve, y qué combinación de límites resuelve las dos cosas? |
| 7 | `-d 'nota=50% & más'` produce un 400 en el servidor, y no solo pierde ese campo: pierde todos. ¿Qué carácter lo provoca, por qué arrastra al resto, y qué hace `--data-urlencode` distinto? |
| 8 | Describe un cuerpo `multipart/form-data`: qué es el boundary, por qué el delimitador lleva dos guiones más que el del header, y por qué copiar a mano un `Content-Type` con boundary hace que el servidor responda 400. |
| 9 | `-F 'x=@f'`, `-F 'x=<f'` y `--data-binary @f` leen el mismo archivo. ¿Qué recibe el servidor en cada caso, y por qué `--data-binary` sin `-H` llega como un formulario con un campo raro? |
| 10 | Una API acepta el mismo archivo en crudo, en multipart y como base64 dentro de un JSON. ¿Qué cuesta cada uno en bytes y en memoria, y cuál elegirías para un vídeo de 2 GB y por qué? |

<details>
<summary><strong>Respuestas</strong></summary>

**1.** Que sea una **página de error**: un 404 o un 500 sin `--fail` se guarda
con el nombre del archivo y curl sale con 0, porque para curl la transferencia
fue un éxito; lo atrapa `--fail`, y después `%{content_type}` si el servidor
devolvió HTML con un 200. Que esté **incompleto**: si no había
`Content-Length` y la conexión se cerró antes, curl no tiene con qué comparar;
lo atrapa el hash, y en parte el código de salida cuando sí había tamaño (18,
56). Que sea **otro archivo**: una réplica vieja, un proxy, un atacante sin TLS
verificado; solo lo atrapa el SHA-256 contra un hash de fuente fiable. Las
comprobaciones son capas: cada una atrapa algo que la anterior deja pasar.

**2.** `--fail-with-body` falla ante un 4xx/5xx **pero escribe el cuerpo**,
que en una API es donde viene el motivo del error. En una descarga con `-o`,
ese cuerpo se escribiría en el archivo de destino: exactamente la página de
error con el nombre bueno que se quiere evitar. `--fail` falla y no escribe
nada. Lo que se pierde es el mensaje del servidor; si se necesita, se obtiene
con `-w '%{http_code}'` y una segunda petición sin `-o`, o pidiéndolo a un
archivo de diagnóstico distinto del destino.

**3.** curl mide el tamaño actual del archivo de `-o` y envía
`Range: bytes=N-`, con `N` ese tamaño. Con `206` y un `Content-Range` que
empieza en `N`, añade los bytes al final. Con `200`, el servidor ignoró el
rango y manda el archivo entero; añadirlo duplicaría contenido, así que curl
7.81 se niega con el código 33 y deja el archivo intacto. Con `416`, el rango
no existe porque el archivo ya está completo (o es más largo que el remoto);
sin `--fail` sale con 0, con `--fail` sale con 22, y un script que reanuda
tiene que distinguir ese 22 del de un 404 mirando `%{http_code}`.

**4.** Porque `mv` dentro del mismo sistema de archivos es un `rename`, que es
**atómico**: no existe un instante en que el destino esté a medio escribir; o
está el viejo, o está el nuevo entero. `/tmp` suele ser otro sistema de
archivos (un `tmpfs`), y entre sistemas `mv` es copiar y borrar: durante la
copia, el destino existe incompleto, y si el proceso muere ahí, se queda así.
Además, el `.part` junto al destino es el estado de la reanudación, y en `/tmp`
puede desaparecer con un reinicio.

**5.** Que el archivo **cambiara en el servidor** entre los dos intentos. El
resultado tiene los primeros 60 % de la versión de ayer y el 40 % final de la
de hoy: tamaño correcto, contenido corrupto. El tamaño no lo detecta porque
ambas versiones pueden medir lo mismo, y curl no envía `If-Range` por su
cuenta. Lo detecta el **hash** final contra el publicado; preventivamente,
comparar el `ETag` antes de reanudar y empezar de cero si cambió.

**6.** Porque `--max-time` es un techo para la operación entera: una descarga
sana a 10 MB/s tarda 200 s, y un límite de 10 la mata siempre. Quitarlo deja
el problema contrario: una conexión colgada, sin cerrar, no da error nunca, y
el cron se queda esperando para siempre. Lo que distingue **lento pero vivo**
de **muerto** es `--speed-limit` con `--speed-time` (abortar si la velocidad
cae por debajo de un mínimo durante un periodo), con `--connect-timeout` para
el establecimiento y un `--max-time` generoso como red de seguridad final.

**7.** El `%`. En urlencoded, `%` empieza un escape `%XX`, y `% ` no es un
escape válido. El servidor no puede decodificar el cuerpo y lo rechaza entero,
no campo a campo: el formulario es una sola cadena y se parsea de una vez. El
`&` y el espacio también se malinterpretan (un campo de más, un `+` que
desaparece), pero no tumban el resto. `--data-urlencode` codifica el valor:
`%` → `%25`, `&` → `%26`, espacio → `+`, y la `á` en sus bytes UTF-8; el
servidor recibe exactamente lo escrito.

**8.** El boundary es una cadena aleatoria que curl declara en el
`Content-Type` y que separa las partes del cuerpo. Cada parte va precedida de
`--` + boundary en su propia línea, y el cuerpo termina con `--` + boundary +
`--`: por eso en el cuerpo hay dos guiones más que en el header. Cada parte
lleva su `Content-Disposition` con `name` (y `filename` si es archivo), su
`Content-Type` opcional, una línea en blanco y el contenido sin codificar. Si
copias un `Content-Type` con su boundary, curl añade el suyo detrás; el
servidor usa el primero, que no aparece en el cuerpo, no encuentra ninguna
parte y responde 400.

**9.** Con `-F 'x=@f'`, una parte de **archivo**: `name="x"; filename="f"`,
con `Content-Type` deducido; el servidor lo pone en `files`. Con
`-F 'x=<f'`, una parte de **texto** con el contenido de `f`, sin `filename`; el
servidor lo pone en `form`. Con `--data-binary @f`, el cuerpo entero **es** el
archivo, sin envoltorio. Pero curl le pone por defecto
`Content-Type: application/x-www-form-urlencoded`, así que el servidor lo
parsea como formulario: el contenido entero se convierte en un nombre de campo
con valor vacío. Con `--data-binary`, el `-H 'Content-Type: ...'` es
obligatorio.

**10.** En crudo, el cuerpo mide lo que el archivo y curl lo envía en
streaming con `-T`. En multipart, unos 200 bytes más por las cabeceras de
parte y los delimitadores, también en streaming. En JSON con base64, un **33 %
más** (3 bytes se convierten en 4 caracteres), y los dos extremos necesitan el
archivo entero en memoria para codificarlo y decodificarlo, porque un string
JSON no se puede procesar a trozos. Para un vídeo de 2 GB: crudo con `-T`, sin
sobrecoste ni memoria extra; multipart si hay que mandar metadatos en la misma
petición. JSON queda descartado: 2,7 GB de cuerpo y otros tantos en memoria.

</details>

---

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Descargar y reanudar | `descargas.md` con los cuatro nombres explicados; `pagina-de-error.md` con el `xxd` y el comando que lo evita; `reanudar.md` con `Range`, `Content-Range` e `identico` | 10 |
| 02 — Verificar y limitar | `SHA256SUMS` y sus dos salidas; `limites.md` con los cuatro límites, su código, su mensaje y lo que no cubren | 10 |
| 03 — Formularios y multipart | La codificación a mano coincidiendo con la de curl; `multipart.txt` anotado pieza a pieza | 10 |
| 04 — Subir en crudo y elegir | `tres-formatos.md` con las tres cifras, su explicación y la elección razonada para tres casos | 10 |

---

## 📦 Producto (30%)

### Verificable por el autograding — 60 puntos

| Comprobación | Puntos |
|---|:--:|
| `toolkit-ejecutable` | 3 |
| `toolkit-sin-todos` | 3 |
| `toolkit-sigue-autenticando` | 3 |
| `toolkit-download-guarda` | 4 |
| `toolkit-download-404-sale-1` | 4 |
| `toolkit-download-sin-pagina-de-error` | 5 |
| `toolkit-download-usa-parte` | 5 |
| `toolkit-download-reanuda` | 5 |
| `toolkit-download-ya-completo` | 4 |
| `toolkit-download-sha256-correcto` | 3 |
| `toolkit-download-sha256-incorrecto` | 5 |
| `toolkit-upload-multipart` | 4 |
| `toolkit-upload-campo` | 3 |
| `toolkit-upload-inexistente` | 3 |
| `toolkit-no-fija-content-type-multipart` | 3 |
| `toolkit-shellcheck` | 3 |
| **Total** | **60** |

### Calidad — 40 puntos

| Criterio | Qué se mira | Puntos |
|---|---|:--:|
| Atomicidad | El `.part` vive junto al destino y el `mv` es lo último que pasa | 6 |
| El binario no pasa por bash | El cuerpo de `download` va de curl al `.part` con `--output`, nunca por una variable | 6 |
| Corte frente a error | Un corte de red conserva el `.part` y sale con 75; un error HTTP lo borra y sale con 1 o 77 | 6 |
| Flags con sentido | `--resume` y `--sha256` se rechazan fuera de `download`, con mensaje | 4 |
| Comillas en `-F` | El nombre del archivo va entre comillas dentro del valor | 4 |
| Límites de descarga | `--speed-limit`/`--speed-time` y un `--max-time` propio de descargas, no el de la API | 5 |
| Mensajes accionables | El fallo de hash dice esperado y recibido; el corte dice "repite con `--resume`"; todo a stderr | 5 |
| Documentación de salida | La cabecera explica `download`, `upload`, los flags nuevos y el código 75 | 4 |
| **Total** | | **40** |

---

### Penalizaciones

| Situación | Deducción |
|---|---|
| Un `-k` o `--insecure` en la entrega | **−20** |
| Una credencial real comiteada, aunque sea en el histórico | **−30** y hay que rotarla ya |
| `download` deja una página de error con el nombre del destino | −15 |
| El cuerpo de `download` pasa por una variable de bash | −10 |
| `--fail-with-body` en `download` | −8 |
| Verificar el hash **después** del `mv` | −8 |
| `Content-Type: multipart/...` escrito a mano | −8 |
| `-d @archivo` para subir un archivo | −6 |
| Sin `--max-time` en alguna petición | −6 |
| El `.part` en `/tmp` | −5 |
| Mensajes de error en stdout | −4 |
| `shellcheck -S warning` con avisos | −5 |

Las dos primeras no son puntos: son la diferencia entre un script que se puede
poner en producción y uno que no. Un `-k` en un script que descarga binarios es
dejar que cualquiera en medio elija qué ejecutas.

---

[← README de la Semana 04](README.md)
