# Timeouts

> Sin timeouts, curl espera. Cinco minutos a que conecte un host caído, y
> después para siempre a que responda uno colgado. Un script que espera para
> siempre es un script roto que no lo dice.

![Diagrama de la línea de tiempo de una petición: resolución DNS, conexión TCP, handshake TLS, espera del primer byte y transferencia; --connect-timeout cubre los tres primeros tramos, --max-time la petición entera, y --speed-limit con --speed-time vigila la transferencia; cada uno termina en el código 28 con un mensaje distinto](../0-assets/07-timeouts.svg)

## 🎯 Objetivos

- Saber qué esperan curl y el sistema por defecto, y por qué no sirve
- Separar la fase de conexión de la petición entera
- Elegir `--connect-timeout` y `--max-time` para cada tipo de petición
- Distinguir los dos timeouts por el mensaje del código 28
- Medir dónde se va el tiempo con las variables `time_*` de `--write-out`

---

## 1. Qué problema resuelve

Dos maneras de colgarse:

- **El host no contesta.** Un firewall que descarta los paquetes en vez de
  rechazarlos, una IP que ya no existe. curl manda el `SYN` y espera. El
  timeout de conexión por defecto de curl es de **300 segundos**.
- **El servidor acepta y no responde.** Un backend bloqueado, una consulta
  lenta, un proxy que no cierra. Una vez conectado, curl **no tiene límite**
  por defecto: espera la respuesta indefinidamente.

En un cron, un CI o un monitor, ese "espera" es el fallo más caro: el
siguiente cron se acumula encima, el CI consume su hora entera, el monitor no
avisa porque sigue "comprobando".

---

## 2. Cómo funciona

### 2.1 Las fases de una petición

```bash
curl -s --cacert docs/lab-ca.pem -o /dev/null \
  -w 'dns=%{time_namelookup} tcp=%{time_connect} tls=%{time_appconnect} primer_byte=%{time_starttransfer} total=%{time_total}\n' \
  https://localhost:8443/delay/1
# dns=0.000017 tcp=0.000135 tls=0.006519 primer_byte=1.014961 total=1.015063
```

Cada valor es **acumulado** desde el principio, en segundos:

| Variable | Hasta cuándo |
|---|---|
| `time_namelookup` | DNS resuelto |
| `time_connect` | Conexión TCP establecida |
| `time_appconnect` | Handshake TLS terminado (0 en HTTP) |
| `time_starttransfer` | Primer byte de la respuesta |
| `time_total` | Todo terminado |

Aquí casi todo el tiempo está entre el TLS y el primer byte: es el segundo que
`/delay/1` tarda en responder. La Semana 06 entra a fondo en estas
variables; aquí sirven para elegir timeouts con datos.

### 2.2 `--connect-timeout`: la fase de conexión

Limita todo lo que pasa **antes** de que la conexión esté lista: DNS, TCP y,
en HTTPS, el handshake TLS.

```bash
# 10.255.255.1 no responde: los paquetes se pierden sin rechazo.
curl -sS --connect-timeout 2 http://10.255.255.1/ -o /dev/null; echo "codigo: $?"
# curl: (28) Connection timeout after 2001 ms
# codigo: 28
```

Una conexión sana dentro de la misma red tarda milisegundos; a través de
Internet, decenas o un par de cientos. **5 segundos** es un valor amplio para
casi cualquier API, y saca un host caído en 5 s en vez de 300.

### 2.3 `--max-time`: la petición entera

Limita el total, de principio a fin, conexión incluida.

```bash
curl -sS --max-time 2 http://localhost:8080/delay/5 -o /dev/null; echo "codigo: $?"
# curl: (28) Operation timed out after 2001 milliseconds with 0 bytes received
# codigo: 28
```

El mismo código 28 para los dos, pero el mensaje dice cuál fue:

| Mensaje | Qué timeout |
|---|---|
| `Connection timeout after N ms` | `--connect-timeout` |
| `Operation timed out after N milliseconds with M bytes received` | `--max-time` |

`M bytes received` cuenta además lo que llegó: `0` es "conectó y nunca
respondió"; un número mayor es "la transferencia fue demasiado lenta".

### 2.4 Por qué los dos

`--max-time` solo ya pone un techo, pero mezcla dos problemas distintos. Con
`--max-time 60` para una API que tarda 40 s en un informe, un host caído
también tarda 60 s en fallar. Con `--connect-timeout 5 --max-time 60`, el host
caído falla en 5 y el informe sigue teniendo sus 60.

Los dos aceptan decimales: `--connect-timeout 0.5` es medio segundo.

---

## 3. Cómo se usa

### 3.1 Valores por tipo de petición

| Petición | `--connect-timeout` | `--max-time` | Por qué |
|---|---|---|---|
| Health check de un monitor | 2 | 5 | Si tarda más, ya es una alerta |
| Llamada a una API normal | 5 | 10–30 | Una respuesta de API rara vez pasa de unos segundos |
| Informe o exportación lenta | 5 | 120–300 | El servidor necesita tiempo; la conexión no |
| Descarga grande | 5 | 3600, o ninguno con `--speed-limit` | El tamaño manda; mejor vigilar la velocidad (Semana 04) |

```bash
curl --fail-with-body --connect-timeout 5 --max-time 10 --retry 3 -sS \
  http://localhost:8080/get
```

### 3.2 Medir antes de elegir

Un timeout elegido "a ojo" corta peticiones sanas o no corta nada. Mide el
`time_total` de varias peticiones normales y pon el `--max-time` en varias
veces el peor caso observado, no en el promedio:

```bash
for i in 1 2 3 4 5; do
  curl -s -o /dev/null -w '%{time_total}\n' http://localhost:8080/get
done | sort -n | tail -1
```

### 3.3 Las descargas, ya resueltas en la Semana 04

Para una descarga, `--max-time` es un mal límite: un archivo de 2 GB en una
red lenta tarda lo que tarda. La Semana 04 usó `--speed-limit` y `--speed-time`
(abortar si la velocidad cae por debajo de N bytes/s durante T segundos): eso
detecta la transferencia **atascada**, no la **lenta**. Combinado con
`--connect-timeout`, cubre las dos formas de colgarse.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Ningún timeout en un script | Un servidor colgado cuelga el script, el cron y lo que dependa | `--connect-timeout` y `--max-time` siempre |
| Solo `--connect-timeout` | Conecta, y luego espera la respuesta para siempre | Añadir `--max-time` |
| `--max-time` igual para todo | O corta los informes lentos, o tarda una eternidad en detectar un host caído | Valores por tipo de petición |
| Leer el 28 sin el mensaje | No distingue "no conecta" de "no responde", que se arreglan distinto | Mirar `Connection timeout` frente a `Operation timed out` |
| `timeout 10 curl ...` del sistema en vez de `--max-time` | Mata curl con una señal: sin mensaje, código 124, y una descarga a medias sin avisar | `--max-time`, que curl entiende y reporta |

---

## 5. Trucos

```bash
# Simular un servidor lento: el laboratorio responde tras N segundos.
curl -sS --max-time 2 http://localhost:8080/delay/3 -o /dev/null
```

```bash
# Simular un host que no responde (los paquetes se pierden).
curl -sS --connect-timeout 2 http://10.255.255.1/ -o /dev/null
```

```bash
# Donde se va el tiempo de una peticion, en una linea.
curl -s -o /dev/null -w 'conexion=%{time_connect} primer_byte=%{time_starttransfer} total=%{time_total}\n' \
  http://localhost:8080/delay/1
```

---

## 📚 Recursos Adicionales

- [everything.curl.dev — Timeouts](https://everything.curl.dev/usingcurl/timeouts.html) — los límites y qué cubre cada uno
- [manpage de curl — `--connect-timeout`](https://curl.se/docs/manpage.html#--connect-timeout) — la fase de conexión
- [manpage de curl — `-m`](https://curl.se/docs/manpage.html#-m) — el límite total
- [libcurl — `CURLOPT_CONNECTTIMEOUT`](https://curl.se/libcurl/c/CURLOPT_CONNECTTIMEOUT.html) — el valor por defecto de 300 s

---

## ✅ Checklist de Verificación

- [ ] Sé cuánto espera curl por defecto a conectar, y cuánto a que le respondan
- [ ] He provocado los dos timeouts y sé distinguirlos por el mensaje
- [ ] Sé qué fases cubre `--connect-timeout` y cuáles `--max-time`
- [ ] He medido las fases de una petición con las variables `time_*`
- [ ] Sé elegir valores para un health check, una API y un informe lento
- [ ] Sé por qué una descarga grande se vigila con `--speed-limit` y no con `--max-time`

---

| Anterior | Siguiente |
|---|---|
| [06 — Redirects](06-redirects.md) | [08 — Reintentos](08-reintentos.md) |
