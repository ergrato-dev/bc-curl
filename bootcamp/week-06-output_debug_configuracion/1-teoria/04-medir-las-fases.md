# Medir las fases

> "La API va lenta" no es un diagnóstico. Lenta resolviendo el nombre, lenta
> conectando, lenta negociando TLS, lenta pensando o lenta mandando son cinco
> problemas distintos, con cinco responsables distintos. curl mide cada uno.

![Diagrama de la línea de tiempo de una petición HTTPS con los cinco instantes que mide curl, todos acumulados desde el principio: time_namelookup, time_connect, time_appconnect, time_starttransfer y time_total; debajo, las cinco duraciones que se obtienen restando instantes consecutivos: dns, tcp, tls, servidor y transferencia, cada una con el problema que delata](../0-assets/04-medir-las-fases.svg)

## 🎯 Objetivos

- Saber qué instante marca cada variable `time_*`
- Convertir esos instantes acumulados en la duración de cada fase
- Leer qué problema delata una fase larga, y a quién hay que llamar
- Entender por qué `time_appconnect` vale 0 en HTTP y cómo no restar mal
- Medir varias veces antes de concluir nada

---

## 1. Qué problema resuelve

Alguien abre un ticket: "el endpoint `/informes` tarda 3 segundos". Con
`time_total` sabes que es verdad. No sabes nada más. Si el tiempo está en el
DNS, el problema es de red o de configuración del resolver. Si está en el TLS,
puede ser un certificado con una cadena larga o un servidor sin reanudación de
sesión. Si está esperando el primer byte, es el backend. Si está en la
transferencia, es el tamaño o el ancho de banda.

Cada respuesta manda el ticket a un equipo distinto. Sin las fases, se manda
al equivocado.

---

## 2. Cómo funciona

### 2.1 Los instantes

Cada variable `time_*` es un **instante**, en segundos desde que empezó la
petición, no una duración:

| Variable | Marca el instante en que... |
|---|---|
| `time_namelookup` | ... se resolvió el nombre |
| `time_connect` | ... se estableció la conexión TCP |
| `time_appconnect` | ... terminó el handshake TLS. **0 si no hubo TLS** |
| `time_pretransfer` | ... curl estaba listo para enviar la petición |
| `time_starttransfer` | ... llegó el primer byte de la respuesta |
| `time_total` | ... terminó todo |
| `time_redirect` | Tiempo gastado en los redirects previos, con `-L` |

```bash
F='dns=%{time_namelookup} tcp=%{time_connect} tls=%{time_appconnect} ttfb=%{time_starttransfer} total=%{time_total}\n'
curl -s -o /dev/null --cacert docs/lab-ca.pem -w "$F" https://localhost:8443/get
# dns=0.000019 tcp=0.000156 tls=0.003845 ttfb=0.006919 total=0.006986
```

Leído como instantes: a los 0,156 ms había conexión, a los 3,8 ms había TLS, a
los 6,9 ms llegó el primer byte, a los 7,0 ms todo había terminado.

### 2.2 De instantes a duraciones

La duración de una fase es su instante final menos el de la fase anterior:

| Fase | Cálculo | Qué delata si es larga |
|---|---|---|
| dns | `time_namelookup` | Resolver lento, DNS caído, falta caché |
| tcp | `time_connect - time_namelookup` | Distancia (latencia de red), servidor saturado aceptando |
| tls | `time_appconnect - time_connect` | Cadena larga, OCSP, sin reanudación, CPU del servidor |
| servidor | `time_starttransfer - time_appconnect` | El backend: base de datos, colas, cálculo |
| transferencia | `time_total - time_starttransfer` | Tamaño de la respuesta, ancho de banda, streaming |

En el ejemplo anterior: dns 0,02 ms, tcp 0,14 ms, tls 3,7 ms, servidor 3,1 ms,
transferencia 0,07 ms. En el laboratorio todo es local y el TLS pesa tanto
como el servidor. En una red real, tcp y tls crecen con la distancia: cada uno
cuesta al menos un viaje de ida y vuelta.

### 2.3 La trampa del cero

Sobre HTTP no hay TLS, y `time_appconnect` vale **0**, no "lo mismo que
`time_connect`":

```bash
curl -s -o /dev/null -w "$F" http://localhost:8080/get
# dns=0.000014 tcp=0.000113 tls=0.000000 ttfb=0.000727 total=0.000774
```

Restar a ciegas da una fase tls **negativa** (0 - 0,113) y una fase servidor
que incluye la conexión entera (0,727 - 0). La regla correcta: **si no hubo
TLS, la fase tls termina donde terminó la conexión.**

```bash
fin_tls = (appconnect > 0) ? appconnect : connect
```

Lo mismo cuando la petición falla: en un `Connection refused`, `time_connect`
vale 0 y `time_starttransfer` también. Toda resta tiene que acotarse a 0, o el
informe dirá que una fase duró menos que nada.

### 2.4 Bash no sabe restar decimales

`$(( ))` solo hace aritmética entera. `$(( 0.003 - 0.001 ))` es un error de
sintaxis. Las restas van en awk:

```bash
read -r dns con tls ttfb total < <(curl -s -o /dev/null --cacert docs/lab-ca.pem \
  -w '%{time_namelookup} %{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total}' \
  https://localhost:8443/get)

awk -v d="$dns" -v c="$con" -v t="$tls" -v s="$ttfb" -v z="$total" 'BEGIN {
  ft = (t > 0) ? t : c
  printf "dns=%.6f tcp=%.6f tls=%.6f servidor=%.6f transferencia=%.6f\n",
         d, c - d, ft - c, s - ft, z - s
}'
# dns=0.000019 tcp=0.000137 tls=0.003689 servidor=0.003074 transferencia=0.000067
```

---

## 3. Cómo se usa

### 3.1 Cada fase, provocada

El laboratorio permite alargar dos fases a voluntad:

```bash
# /delay/1: el servidor espera un segundo antes de responder. Fase servidor.
curl -s -o /dev/null -w "$F" http://localhost:8080/delay/1
# dns=0.000019 tcp=0.000146 tls=0.000000 ttfb=1.001815 total=1.001887

# /drip: el servidor manda el cuerpo gota a gota durante un segundo.
# Primer byte enseguida, fase de transferencia larga.
curl -s -o /dev/null -w "$F" 'http://localhost:8080/drip?duration=1&numbytes=5&delay=0'
# dns=0.000016 tcp=0.000120 tls=0.000000 ttfb=0.000765 total=1.001520
```

El `time_total` es casi igual en los dos. El problema, no: en el primero hay
que hablar con el backend; en el segundo, con quien decidió mandar la
respuesta en streaming lento.

### 3.2 La conexión reutilizada

Si un solo comando pide dos URLs al mismo host, la segunda reutiliza la
conexión:

```bash
curl -s -o /dev/null -o /dev/null -w '%{num_connects} ' \
  http://localhost:8080/get http://localhost:8080/get; echo
# 1 0
```

En la segunda, `num_connects` es 0: no hubo conexión nueva, y sus fases tcp y
tls valen prácticamente 0. Al comparar medidas, separa las que abrieron
conexión de las que no. La Semana 09 vive de esta diferencia.

### 3.3 Una medida no es una medida

La red tiene ruido: una medida aislada puede salir el doble que la siguiente.
Antes de concluir nada, repite y mira la distribución:

```bash
for i in $(seq 20); do
  curl -s -o /dev/null -w '%{time_total}\n' http://localhost:8080/get
done | sort -n | awk '{ v[NR] = $1 } END { print "mediana=" v[int(NR/2)+1], "max=" v[NR] }'
# mediana=0.000801 max=0.002914
```

El máximo suele ser la primera petición: cachés frías, DNS sin resolver. La
práctica 04 hace esto con cien peticiones, mediana, p95 y fases.

---

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| Leer `time_starttransfer` como "lo que tarda el servidor" | Incluye DNS, TCP y TLS | Réstale `time_appconnect` (o `time_connect` sin TLS) |
| Restar `time_appconnect - time_connect` en HTTP | Sale negativo | Si `appconnect` es 0, la fase tls vale 0 |
| `$(( b - a ))` con los tiempos | Bash no hace decimales: error de sintaxis | `awk` |
| Concluir con una sola medida | El ruido es del mismo orden que la señal | Mediana de 20 o más |
| Comparar medidas con y sin conexión reutilizada | La segunda se ahorra tcp y tls | Mira `num_connects` |
| Medir contra producción en hora punta para "ver si va lento" | Mides la carga, no el endpoint | Repite en horas distintas, o contra un entorno de pruebas |

---

## 5. Trucos

- **`time_pretransfer - time_appconnect`** es lo que tarda curl en preparar la
  petición tras el TLS. Casi siempre 0; si no, sospecha de un proxy.
- **`%{speed_download}`** da bytes por segundo de la transferencia. En
  descargas grandes dice más que `time_total`.
- **`%{time_redirect}`** con `-L` separa lo que costaron los saltos de lo que
  costó el destino.
- **`curl -w '%{json}' | jq '{time_namelookup, time_connect, time_appconnect, time_starttransfer, time_total}'`**
  te da los cinco instantes sin escribir el formato.

---

## 📚 Recursos Adicionales

- [everything.curl.dev — Timing](https://everything.curl.dev/usingcurl/verbose/writeout.html#timing)
- [Manpage: variables `time_*`](https://curl.se/docs/manpage.html#-w)
- [libcurl — `CURLINFO_*_TIME` y su diagrama](https://curl.se/libcurl/c/curl_easy_getinfo.html#TIMES)

---

## ✅ Checklist de Verificación

- [ ] Calculas las cinco fases de una petición HTTPS al laboratorio y suman `time_total`
- [ ] Sobre HTTP, tu cálculo da `tls=0.000000`, no un negativo
- [ ] `/delay/1` alarga la fase servidor y `/drip` la de transferencia, y sabes distinguirlas
- [ ] Ves `num_connects` a 0 en una conexión reutilizada
- [ ] Tienes la mediana de 20 peticiones, no una sola medida
