# Dónde se va el tiempo

> "La API va lenta" no es un diagnóstico. Una petición pasa por cinco fases, y
> casi nunca es el servidor el que se come el tiempo: es el DNS, el saludo TCP,
> el apretón de manos TLS, o la cantidad de veces que tu script los repite.
> Antes de acelerar nada hay que saber en qué fase se va cada milisegundo.

![Línea de tiempo de una petición HTTPS: DNS, conexión TCP, handshake TLS, espera del servidor y transferencia, con las variables de --write-out que marcan el final de cada fase. Debajo, la misma petición repetida sobre una conexión reutilizada, donde DNS, TCP y TLS desaparecen y solo quedan servidor y transferencia](../0-assets/01-donde-se-va-el-tiempo.svg)

## 🎯 Objetivos

- Partir el tiempo de una petición en sus cinco fases con `--write-out`
- Distinguir latencia de ancho de banda, y saber cuál limita cada caso
- Entender por qué el coste fijo de abrir una conexión domina en las APIs
- Saber qué fases se pueden ahorrar y cuáles no
- Medir antes de optimizar, y no al revés

---

## 1. Qué problema resuelve

Un script recorre 200 recursos de una API, uno por uno, y tarda un minuto.
Alguien propone "pedirle al proveedor un servidor más rápido". Pero el
servidor responde en 20 ms; el resto del tiempo se va en **abrir 200
conexiones**, cada una con su DNS, su saludo TCP y su handshake TLS.

En la Semana 06 aprendiste a sacar los tiempos con `--write-out`. Esta semana
los usas para decidir: **qué fase domina, y si se puede evitar**.

---

## 2. Cómo funciona

### 2.1 Las cinco fases

Las variables `time_*` de `--write-out` son **instantes acumulados** desde que
empezó la petición, no duraciones. Cada fase es la resta de dos de ellas:

| Fase | Termina en | Duración |
|---|---|---|
| DNS | `%{time_namelookup}` | `time_namelookup` |
| Conexión TCP | `%{time_connect}` | `time_connect - time_namelookup` |
| Handshake TLS | `%{time_appconnect}` | `time_appconnect - time_connect` |
| Servidor (TTFB) | `%{time_starttransfer}` | `time_starttransfer - time_appconnect` |
| Transferencia | `%{time_total}` | `time_total - time_starttransfer` |

Sin TLS, `time_appconnect` vale 0 y la fase del servidor empieza en
`time_connect`. El toolkit ya hace estas cuentas desde la Semana 06: es lo que
imprime `--timing`.

### 2.2 Latencia y ancho de banda

Hay dos límites distintos, y se confunden:

- **Latencia** (RTT, *round-trip time*): lo que tarda un paquete en ir y
  volver. Entre Madrid y un servidor en Virginia, unos 80-100 ms. No depende
  de tu conexión: depende de la distancia y de la velocidad de la luz en la
  fibra.
- **Ancho de banda**: cuántos bytes por segundo caben. Es lo que vende tu
  proveedor de internet.

Una respuesta de API típica pesa unos pocos KB. Con 100 Mbit/s, transferir
5 KB lleva menos de un milisegundo. Lo que pesa son los **viajes de ida y
vuelta**: cada uno cuesta un RTT, lo pagues con 10 Mbit/s o con 1 Gbit/s.

> [!IMPORTANT]
> En una API, el tiempo lo pone la latencia, no el ancho de banda. Por eso
> optimizar es **ahorrar viajes**, no comprimir bytes.

### 2.3 Cuántos viajes cuesta una petición nueva

Sobre una conexión nueva con HTTPS:

| Paso | Viajes (RTT) |
|---|:--:|
| DNS (si no está en caché) | 1 |
| Saludo TCP (SYN, SYN-ACK, ACK) | 1 |
| Handshake TLS 1.3 | 1 (TLS 1.2: 2) |
| La petición y la respuesta | 1 |
| **Total** | **3-5** |

Con 90 ms de RTT, una petición nueva no baja de 300 ms aunque el servidor
responda al instante. Una petición sobre una conexión **ya abierta** cuesta
un solo RTT: 90 ms.

Eso es lo que esta semana ataca:

- **Reutilizar la conexión** (teoría 02) quita DNS, TCP y TLS de todas las
  peticiones menos la primera.
- **HTTP/2** (teoría 03) mete muchas peticiones en una sola conexión a la vez.
- **El paralelo** (teoría 04) solapa los viajes: diez peticiones de 90 ms a la
  vez tardan 90 ms, no 900.
- **La caché condicional** (teoría 06) convierte una respuesta grande en un 304
  vacío.

### 2.4 Lo que no se puede ahorrar

- **La fase del servidor.** Si la API tarda 2 s en calcular la respuesta, no
  hay flag de curl que lo arregle. Lo que sí puedes es no esperarla en serie
  (paralelo) o no pedirla (caché).
- **El primer viaje.** La primera petición siempre paga la conexión entera. Un
  benchmark que solo mide la primera mide el handshake, no la API.
- **La física.** 90 ms de RTT son 90 ms.

### 2.5 En el laboratorio todo es rápido

El laboratorio corre en tu máquina: el RTT es de microsegundos y el handshake
TLS dura 2-4 ms. Los números absolutos no se parecen a los de una API en otro
continente, pero **las proporciones sí**: una conexión nueva cuesta varias
veces más que una reutilizada, aquí y allí. Para simular un servidor lento,
`/delay/N` tarda N segundos en responder.

---

## 3. Cómo se usa

Las fases de una petición HTTPS al laboratorio, con el formato de la
Semana 06:

```bash
curl --cacert docs/lab-ca.pem -s -o /dev/null \
  -w 'dns=%{time_namelookup} tcp=%{time_connect} tls=%{time_appconnect} ttfb=%{time_starttransfer} total=%{time_total}\n' \
  https://localhost:8443/get
# dns=0.000043 tcp=0.000172 tls=0.003271 ttfb=0.004402 total=0.004556
```

Recuerda que son acumulados: el TLS empieza en 0.000172 y acaba en 0.003271,
así que duró unos 3 ms. Es la fase más larga: más que el servidor y la
transferencia juntos.

Dos peticiones en la misma invocación:

```bash
curl --cacert docs/lab-ca.pem -s -o /dev/null -o /dev/null \
  -w '%{num_connects} tls=%{time_appconnect} total=%{time_total}\n' \
  https://localhost:8443/get https://localhost:8443/get
# 1 tls=0.003271 total=0.004556
# 0 tls=0.000016 total=0.000938
```

La segunda no abrió conexión (`num_connects` 0) y tardó **cinco veces menos**.
Cada `-o` va con su URL, en orden: con una sola, la segunda respuesta saldría
por la pantalla.

Y el toolkit, con `--timing`, ya te da las fases restadas:

```bash
BASE_URL=https://localhost:8443 API_CACERT=docs/lab-ca.pem \
  ./api-toolkit.sh --timing get /get > /dev/null
# tiempos: dns=0.000041s tcp=0.000128s tls=0.003104s servidor=0.001095s transferencia=0.000139s total=0.004507s
```

---

## 4. Antipatrones

- **Optimizar sin medir.** "Seguro que es el JSON, que es muy grande": mide
  `size_download` y la fase de transferencia antes de cambiar nada.
- **Medir una sola petición.** La primera paga el handshake y la caché fría
  del DNS. Una medida es una anécdota; la teoría 05 explica cuántas hacen
  falta.
- **Echarle la culpa al servidor por un TTFB alto en la primera petición.** El
  TTFB de `time_starttransfer` es acumulado: incluye DNS, TCP y TLS. Resta.
- **Comprimir para ir más rápido.** `--compressed` ahorra bytes, y en una
  descarga de 50 MB se nota. En una respuesta de 3 KB la diferencia no se
  puede medir, y el servidor gasta CPU en comprimir.
- **Cambiar de proveedor de DNS por 2 ms.** El DNS se cachea: lo pagas una vez
  por proceso, y en la segunda petición ya vale 0.

---

## 5. Trucos

- **Formato de fases reutilizable.** Guarda el `-w` en un archivo y úsalo con
  `-w @fases.txt`: no tienes que escribirlo cada vez.
- **`%{time_appconnect}` es 0 sin TLS.** Si sale 0 en una URL `https://`, la
  petición falló antes del handshake: mira el código de salida.
- **`%{num_connects}` dice si hubo conexión nueva**: 1 si la abrió, 0 si
  reutilizó. Es la variable más útil de la semana.
- **`%{size_download}` frente a `%{time_total}`**: si la transferencia ocupa
  la mayor parte del tiempo, el problema es el tamaño; si no, son los viajes.
- **Para simular un RTT alto**, `/delay/1` en el laboratorio. No es lo mismo
  que latencia de red (solo retrasa la respuesta, no cada viaje), pero basta
  para ver el efecto del paralelo.

---

## 📚 Recursos Adicionales

- [Everything curl — Timing](https://everything.curl.dev/usingcurl/verbose/writeout.html)
- [High Performance Browser Networking, capítulo 1 — Latency and Bandwidth](https://hpbn.co/primer-on-latency-and-bandwidth/)
- [High Performance Browser Networking, capítulo 2 — Building Blocks of TCP](https://hpbn.co/building-blocks-of-tcp/)

---

## ✅ Checklist de Verificación

- [ ] Partes el tiempo de una petición en sus cinco fases restando los `time_*`
- [ ] Explicas por qué en una API manda la latencia y no el ancho de banda
- [ ] Cuentas los viajes de ida y vuelta de una petición HTTPS nueva
- [ ] Usas `%{num_connects}` para saber si una petición abrió conexión
- [ ] Nombras qué se puede ahorrar (conexión, espera en serie, bytes) y qué no
