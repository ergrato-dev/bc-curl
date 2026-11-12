# Rúbrica de evaluación — Semana 09

> HTTP/2, paralelismo y rendimiento. Se evalúa que sepas en qué se va el
> tiempo antes de intentar ahorrarlo, que midas con cifras que no escondan la
> cola, que pidas en paralelo sin convertir un benchmark en una ráfaga contra
> la API, y que lo que el toolkit guarda en disco (la caché, la sesión) siga
> siendo correcto y privado cuando varios procesos lo tocan a la vez.

---

## 📊 Distribución de Evidencias

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales |
| 💪 Desempeño | 40% | Las 4 prácticas, con sus entregables y salida real de tu máquina |
| 📦 Producto | 30% | `api-toolkit.sh`: 60 pts de autograding + 40 pts de calidad |

**Mínimo 70% en cada evidencia**, no en el promedio. Un `bench` que pasa los
checks no compensa no saber por qué la media de veinte muestras puede
describir una petición que no existió.

---

## 🧠 Conocimiento (30%)

| # | Pregunta |
|:--:|---|
| 1 | Un script recorre 200 ids con un `while read` que lanza un `curl` por vuelta contra una API HTTPS a 90 ms de RTT. ¿Cuánto tiempo se va, como mínimo, en abrir conexiones, y por qué? ¿Cómo lo reescribes con un solo curl? Un compañero propone `--no-keepalive` "para no dejar conexiones abiertas": ¿qué hace ese flag en realidad? |
| 2 | Contra el laboratorio, `--http2` sobre `http://localhost:8080` responde en 1.1, `--http2-prior-knowledge` sale con 52, y sobre `https://localhost:8443` sale HTTP/2 sin poner ningún flag. Explica las tres cosas. |
| 3 | `curl -Z` con tres URLs a `http://localhost:8080/delay/1` tarda dos segundos en curl 7.81. ¿Por qué no uno? ¿Qué flag lo arregla, y por qué el toolkit lo pone en `http://` y no en `https://`? |
| 4 | Un lote con `-Z` de 20 URLs sale con 0, pero tres respondieron 500. ¿Por qué? ¿Y si añades `--fail`? ¿Cómo sabes cuáles fallaron y cuántas? |
| 5 | Diecinueve peticiones tardan 10 ms y una tarda 1000 ms. Calcula la media, la mediana, el p95 por rango y el max. ¿Cuál de esas cifras no describe ninguna petición real? ¿Qué cifras darías en un informe y por qué varias? |
| 6 | `bench /ruta 10` da un p95 igual al max. ¿Es casualidad? ¿Cuántas muestras pedirías para hablar del p95? Y si `bench` usara `--retry 3` y `--location` como `get`, ¿qué estaría midiendo un 503 o un 302? |
| 7 | En Ubuntu 22.04, `curl --http3` sale con 2, y una API anuncia `alt-svc: h3=":443"`. ¿Qué te dice cada cosa? Otra API tiene un endpoint WebSocket que "no conecta": ¿qué comprobación puedes hacer con curl 7.81, qué respuesta esperas si todo está bien, y desde qué versión curl habla `ws://`? |
| 8 | Usas `--etag-compare e.txt --etag-save e.txt -o datos.json` y la primera petición contra un servidor ya recibe un 304. ¿Cómo es posible? Si alguien borra `datos.json` y deja `e.txt`, ¿qué pasa en la siguiente? ¿Qué hace el toolkit distinto? |
| 9 | La caché del toolkit guarda respuestas de una API autenticada. Di tres reglas que sigue al guardarlas y qué ataque o fallo evita cada una. ¿Por qué guarda el cuerpo antes que el ETag y no al revés? |
| 10 | Ocho procesos del toolkit encuentran a la vez la sesión OAuth2 caducada. ¿Por qué el `mv` atómico de `guardar_sesion` no evita ocho renovaciones? ¿Qué pasaría con un refresh token que rota? ¿Por qué no basta con el cerrojo, y para qué sirve `VISTO`? ¿Por qué no se borra el `.lock`? |

<details>
<summary><strong>Respuestas</strong></summary>

**1.** Cada proceso curl abre su conexión y la pierde al morir: 200 veces DNS
(cacheado tras la primera, en el mejor caso), saludo TCP (1 RTT) y TLS 1.3 (1
RTT). Son al menos 2 RTT × 200 = 36 s solo en abrir conexiones, antes de la
propia petición. Con un solo curl: una lista de pares `url`/`output` en un
`--config` y `curl -K lista.txt`; la conexión se abre una vez y se reutiliza.
`--no-keepalive` apaga las sondas de keepalive de TCP; no cierra la conexión
persistente de HTTP, y curl sigue reutilizando. Para forzar conexiones nuevas
se usa `Connection: close`.

**2.** Sin TLS no hay ALPN: `--http2` sobre `http://` manda HTTP/1.1 con
`Upgrade: h2c`, y go-httpbin lo ignora y responde en 1.1. Con
`--http2-prior-knowledge` curl habla HTTP/2 desde el primer byte; el servidor
no lo entiende, cierra sin responder, y curl sale con 52 (*empty reply*). Sobre
HTTPS, desde la 7.62.0 curl ofrece `h2` por ALPN dentro del handshake TLS, y
Caddy lo acepta: no hace falta ningún flag.

**3.** Antes de abrir más conexiones, curl 7.x espera a que la primera esté
lista para saber si podrá multiplexar. Sobre `http://` no habrá HTTP/2, así
que la primera petición sale sola y las otras dos arrancan cuando termina: dos
segundos. `--parallel-immediate` (7.68.0) abre las conexiones sin esperar. En
`https://` la espera es útil: si el servidor acepta h2, todas van como streams
en una sola conexión, y con el flag curl abriría una por petición.

**4.** Sin `--fail`, un 500 es una respuesta HTTP válida para curl: la
transferencia salió bien, y el lote sale con 0. Con `--fail`, sale con 22
porque alguna falló, pero no dice cuál ni cuántas. El resultado de cada una
está en su línea de `-w`: `-w '%{http_code} %{url_effective}\n'` y contar las
que no empiezan por 2 o 3, como hace `estadisticas`.

**5.** Media: (19 × 10 + 1000) / 20 = 59,5 ms. Mediana: 10 ms. p95 por rango:
la posición ⌈20 × 0,95⌉ = 19, 10 ms. Max: 1000 ms. La media no describe
ninguna petición: ninguna tardó 59,5 ms. En un informe van varias, porque cada
una responde a una pregunta: la mediana o el p95 "cómo va normalmente", el max
"qué es lo peor que vimos", y la media solo si hay que estimar un total.

**6.** No es casualidad: con N = 10, ⌈10 × 0,95⌉ = 10, la última posición. El
p95 por rango de 10 muestras **es** el max. Para que signifique algo, al menos
20, y mejor 100. Con `--retry`, un 503 se convertiría en una petición "lenta"
de varios segundos que mezcla espera de reintento con latencia; con
`--location`, un 302 mediría dos peticiones como una. Por eso `construir_red
BENCH` no los pone.

**7.** Que tu curl no se compiló con HTTP/3 (no hay `HTTP3` en `Features:`) y
el flag ni se acepta. El `alt-svc` dice que el servidor también sirve HTTP/3
en el puerto 443 por UDP: un cliente con HTTP/3 lo probaría la próxima vez. Con
7.81 se puede hacer el handshake de WebSocket: un GET con `Connection:
Upgrade`, `Upgrade: websocket`, `Sec-WebSocket-Version: 13` y una
`Sec-WebSocket-Key`; si todo el camino lo deja pasar, responde 101 Switching
Protocols. Un 400, 426 o 200 dice que algo en medio no lo acepta. curl habla
`ws://` desde la 7.86.0 como experimental, y por defecto desde la 8.11.0.

**8.** Con los dos flags sobre un archivo que no existe, curl lo crea vacío y
manda `If-None-Match: ""`; un servidor que responda 304 a cualquier
`If-None-Match` (como `/cache` del laboratorio) da un 304 sin que tengas nada.
Si borras `datos.json`, el siguiente 304 no lo recrea: te quedas sin datos y
sin error, porque el ETag y el cuerpo no están atados. El toolkit guarda el
ETag y el cuerpo él mismo, y solo manda `If-None-Match` si existen los dos y no
están vacíos.

**9.** Directorio con permisos 700 (o error si ya existe con otros): otro
usuario de la máquina no puede leer respuestas autenticadas. Nombre de cada
entrada = SHA-256 de la URL: no se ve qué se consultó (ni una clave en la
query) y una URL con `/` o `?` no rompe la ruta. Cada archivo con `mktemp` en
el mismo directorio y `mv`: nadie lee un archivo a medias. Primero el cuerpo y
después el ETag: si el proceso muere entre los dos, queda el ETag viejo, que el
servidor ya no reconoce, y la siguiente petición trae el cuerpo entero. Al
revés quedaría un ETag nuevo con un cuerpo viejo, y el 304 serviría datos que
ya no son.

**10.** El `mv` garantiza que nadie lee un JSON a medias, pero los ocho leen la
sesión, ven que caducó y deciden renovar antes de que ninguno escriba: el
problema es la secuencia leer-decidir-escribir, no la escritura. Con un
refresh token que rota, el primero lo invalida y los otros siete reciben
`invalid_grant` y salen con 77. El cerrojo solo los pone en fila: cada uno
renovaría al entrar. `VISTO` es el token que el proceso vio caducado; con el
cerrojo en la mano, si la sesión ya tiene otro y no ha caducado, otro proceso
renovó y se usa ese. El `.lock` no se borra porque, entre que uno lo borra y
otro lo crea, dos procesos pueden tener cada uno "su" archivo y su cerrojo.

</details>

---

## 💪 Desempeño (40%)

| Práctica | Criterio | Puntos |
|---|---|:--:|
| 01 — Una conexión para muchas peticiones | `conexiones.md` con la duración del TLS y del servidor restadas del `-w`, el bucle contra la lista con sus dos tiempos y el cálculo para 90 ms de RTT, la tabla de lo que impide reutilizar con `--no-keepalive` explicado, el `--next` con GET y POST, y las líneas en bruto de `bench` en HTTP/1.1 y HTTP/2 | 10 |
| 02 — HTTP/2 y peticiones en paralelo | `paralelo.md` con la negociación ALPN y los `MAX_CONCURRENT_STREAMS`, el h2c fallido y su conclusión, la espera de curl 7.x medida con y sin `--parallel-immediate`, las conexiones de `-Z` en HTTP/1.1 frente a HTTP/2, los tiempos con distintos `--parallel-max` y por qué `bench` no usa `--fail` | 10 |
| 03 — Medir sin engañarse | `medidas.md` con veinte muestras y la más lenta identificada, la media frente a mediana, p95 y max de la mezcla, la posición del p95 para 10, 20 y 100, los dos resúmenes de `bench`, el efecto de calentar y qué harías antes de medir una API con rate limit | 10 |
| 04 — Caché con ETag y un token compartido | `cache-y-cerrojo.md` con la petición condicional a mano, la rareza de `--etag-save` explicada, Last-Modified frente a `max-age`, la caché funcionando con sus permisos, las ocho renovaciones antes del cerrojo y una después, y por qué el `.lock` no se borra | 10 |

---

## 📦 Producto (30%)

### Verificable por el autograding — 60 puntos

| Comprobación | Puntos |
|---|:--:|
| `toolkit-ejecutable` | 2 |
| `toolkit-sin-todos` | 2 |
| `toolkit-version` | 2 |
| `toolkit-get-sigue` | 2 |
| `bench-un-solo-curl` | 4 |
| `bench-resumen` | 3 |
| `bench-estadisticas` | 4 |
| `bench-en-paralelo` | 5 |
| `bench-reutiliza-http2` | 5 |
| `bench-errores` | 4 |
| `bench-sin-reintentos` | 3 |
| `cache-304` | 4 |
| `cache-mismo-cuerpo` | 4 |
| `cache-700` | 3 |
| `cache-sin-etag` | 3 |
| `renovar-una-vez` | 6 |
| `toolkit-shellcheck` | 4 |
| **Total** | **60** |

### Calidad — 40 puntos

| Criterio | Qué se mira | Puntos |
|---|---|:--:|
| Un solo curl | `bench` lanza una sola invocación; la lista va en `LISTA` (temporal 600) con cada URL pasada por `escapar_config`; ninguna URL en la línea del proceso | 7 |
| Paralelo con criterio | `--parallel-max` siempre; `--parallel-immediate` solo en `http://`, con un comentario que diga por qué; sin `--retry` ni `--location` en `bench`; `BENCH_PARALELO` y N validados | 6 |
| Estadísticas honestas | p95 por rango con el redondeo hacia arriba; el `000` cuenta como error; sin división entre cero; código de salida 1 con algún error; formato exacto | 7 |
| Caché segura | Directorio 700 o error; clave SHA-256 de la URL; `If-None-Match` solo con ETag y cuerpo; cuerpo antes que ETag, cada uno con `mktemp` y `mv`; solo un 200 con ETag y sin `no-store` se guarda | 8 |
| Cerrojo correcto | `flock -w`; el `.lock` abierto con `umask 077`; segunda comprobación con `VISTO`; el cerrojo se suelta en los dos caminos; sin `flock` el toolkit sigue funcionando y un `ponytail:` lo dice | 7 |
| Documentación | El `--help` sigue siendo verdad; los comentarios dicen por qué un solo curl, por qué el `immediate` depende del esquema, por qué cuerpo antes que ETag y por qué la segunda comprobación | 5 |
| **Total** | | **40** |

### Penalizaciones

| Situación | Deducción |
|---|---|
| Una credencial en la línea de un proceso, en una traza o en una caché sin 700 | **−30** y hay que rotarla ya |
| Un `-k` o `--insecure` en la entrega | **−20** |
| `bench` lanza un curl por petición | **−15** |
| `bench` sin `--parallel-max`, o sin el techo de `MAX_BENCH` | −10 |
| `bench` con `--retry` o `--location` | −8 |
| `flock` sin `-w` | −8 |
| La caché sirve un cuerpo que no corresponde a su ETag en algún camino (ETag escrito antes que el cuerpo, o sin `mv`) | −8 |
| Un entregable con un benchmark contra una API ajena de más de 100 peticiones o con más de 8 en paralelo | −10 |
| `shellcheck -S warning` con avisos | −5 |

Las tres primeras no son puntos: son la diferencia entre una herramienta que
mide una API y una que la ataca, o que deja en `/tmp` lo que el token
protegía. Esta semana enseña que ir rápido es hacer menos trabajo, no hacer el
mismo trabajo más fuerte.

---

[← README de la Semana 09](README.md)
