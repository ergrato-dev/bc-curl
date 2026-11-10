# Práctica 04 — Timeouts y reintentos

> **Duración**: 50 min · **Entregables**: `resiliencia.md`

Vas a medir dónde se va el tiempo de una petición, ver cuánto espera curl sin
límites, provocar los dos timeouts y distinguirlos, y después hacer que curl
reintente: qué errores repite, cuánto espera entre intentos, cuánto puede
tardar en total y por qué el método importa más que el flag.

**Antes de empezar**, desde la raíz del repositorio:

```bash
./scripts/start.sh
export CA="$PWD/docs/lab-ca.pem"
mkdir -p ~/bc-curl-trabajo/semana-05/p4 && cd ~/bc-curl-trabajo/semana-05/p4
```

---

## Paso 1: Dónde se va el tiempo

**Por qué**: un timeout elegido sin medir corta peticiones sanas o no corta
nada.

**Comando**:

```bash
F='dns=%{time_namelookup} tcp=%{time_connect} tls=%{time_appconnect} primer_byte=%{time_starttransfer} total=%{time_total}\n'
curl -s -o /dev/null -w "$F" http://localhost:8080/get
curl -s -o /dev/null -w "$F" --cacert "$CA" https://localhost:8443/get
curl -s -o /dev/null -w "$F" --cacert "$CA" https://localhost:8443/delay/1
```

**Verifica**: tres líneas con tiempos en segundos. En la primera, `tls=0`
(no hay TLS). En la tercera, el `primer_byte` pasa de 1 segundo.

Apunta en `resiliencia.md` cuánto tarda el handshake TLS en tu equipo
(`tls - tcp`) y cuánto el servidor en responder (`primer_byte - tls`) en la
tercera petición.

---

## Paso 2: Sin límites

**Por qué**: hay que ver con tus ojos que curl espera lo que haga falta.

**Comando**:

```bash
time curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/delay/10
```

**Verifica**:

```
200
real    0m10,0...
```

Diez segundos esperando, sin quejarse. El laboratorio limita `/delay` a 10;
un servidor de verdad colgado no tiene límite. Apunta en `resiliencia.md`
cuánto esperaría curl por defecto a **conectar** con un host que no responde,
y cuánto a que le **respondan** una vez conectado.

---

## Paso 3: Los dos timeouts

**Por qué**: el mismo código 28 cubre dos problemas que se arreglan distinto.
El mensaje es lo que los separa.

**Comando**:

```bash
# Un host que no responde: los paquetes se pierden.
curl -sS --connect-timeout 2 http://10.255.255.1/ -o /dev/null; echo "codigo: $?"

# Un servidor que acepta y tarda en responder.
curl -sS --max-time 2 http://localhost:8080/delay/5 -o /dev/null; echo "codigo: $?"

# El mismo servidor, con --connect-timeout: no sirve de nada.
time curl -sS --connect-timeout 2 http://localhost:8080/delay/5 -o /dev/null
```

**Verifica**:

```
curl: (28) Connection timeout after 2001 ms
codigo: 28
curl: (28) Operation timed out after 2001 milliseconds with 0 bytes received
codigo: 28
real    0m5,0...
```

Apunta en `resiliencia.md`, para cada mensaje, qué falló y qué flag lo
detectó. Y por qué el tercero tardó 5 segundos pese al `--connect-timeout 2`.

---

## Paso 4: Elegir valores

**Por qué**: con los tiempos del paso 1 ya puedes elegir límites que no
corten lo sano.

**Comando**:

```bash
# El peor de cinco: la base para --max-time.
for i in 1 2 3 4 5; do
  curl -s -o /dev/null -w '%{time_total}\n' http://localhost:8080/get
done | sort -n | tail -1

# Medio segundo para conectar es de sobra en local; 1,5 s para un endpoint
# que tarda 1.
curl -sS --connect-timeout 0.5 --max-time 1.5 -o /dev/null -w '%{http_code}\n' \
  http://localhost:8080/delay/1
```

**Verifica**:

```
0.00...
200
```

Apunta en `resiliencia.md` los dos valores que pondrías al health check de
un monitor y los dos de una llamada a una API normal, con el porqué.

---

## Paso 5: Ver los reintentos

**Por qué**: sin `-s`, curl cuenta cada reintento y cuánto va a esperar. Es
la forma de ver la espera creciente.

**Comando**:

```bash
time curl --retry 3 -o /dev/null -w '%{http_code}\n' http://localhost:8080/status/503 2>&1 \
  | grep -E 'Will retry|^[0-9]{3}$'
```

**Verifica**:

```
Warning: Problem : HTTP error. Will retry in 1 seconds. 3 retries left.
Warning: Problem : HTTP error. Will retry in 2 seconds. 2 retries left.
Warning: Problem : HTTP error. Will retry in 4 seconds. 1 retries left.
503
real    0m7,0...
```

Cuatro peticiones, siete segundos de espera, y al final... un 503 y código
de salida 0. Apunta en `resiliencia.md` qué le falta a este comando para que
el script se entere de que falló.

---

## Paso 6: Lo que no se reintenta

**Por qué**: `--retry` no es "repite si falla". Solo repite lo que considera
transitorio.

**Comando**:

```bash
for c in 404 408 429 500 502 503 504; do
  printf '%s: ' "$c"
  curl --retry 1 --retry-delay 1 -o /dev/null http://localhost:8080/status/$c 2>&1 | grep -c 'Will retry'
done

# Conexion rechazada: nada escucha en el puerto 9.
curl -sS --retry 2 http://localhost:9/ -o /dev/null; echo "sin --retry-connrefused: $?"
time curl -sS --retry 2 --retry-connrefused http://localhost:9/ -o /dev/null
```

**Verifica**:

```
404: 0
408: 1
429: 1
500: 1
502: 1
503: 1
504: 1
curl: (7) Failed to connect to localhost port 9 after 0 ms: Connection refused
sin --retry-connrefused: 7
curl: (7) Failed to connect to localhost port 9 after 0 ms: Connection refused
real    0m3,0...
```

El primer `(7)` sale al instante; el segundo, tras dos reintentos (1 + 2 s).
Apunta en `resiliencia.md` qué códigos reintenta curl y por qué un 404 no.

---

## Paso 7: El presupuesto de tiempo

**Por qué**: reintentos y timeouts se multiplican. Hay que saber calcular el
peor caso antes de que lo calcule el cron.

**Comando**:

```bash
time curl -s --retry 3 --max-time 2 http://localhost:8080/delay/5 -o /dev/null
time curl -s --retry 3 --max-time 2 --retry-max-time 4 http://localhost:8080/delay/5 -o /dev/null
```

**Verifica**:

```
real    0m15,0...
real    0m5,0...
```

Apunta en `resiliencia.md` el cálculo del primero (intentos × `--max-time`
+ esperas) y por qué el segundo se para en 5.

---

## Paso 8: `--fail` y el último intento

**Por qué**: el reintento no cambia lo que pasa al final. Si el último
intento falla, hace falta `--fail` para que el script lo sepa.

**Comando**:

```bash
curl -s --retry 1 -o /dev/null http://localhost:8080/status/503; echo "sin --fail: $?"
curl -s --fail --retry 1 -o /dev/null http://localhost:8080/status/503; echo "con --fail: $?"
```

**Verifica**:

```
sin --fail: 0
con --fail: 22
```

---

## Paso 9: curl no sabe qué es un POST

**Por qué**: la decisión de reintentar un POST no la puede tomar curl. Hay
que verlo reintentar un POST tan tranquilo para entender que es tu
responsabilidad.

**Comando**:

```bash
curl -X POST -d 'importe=100' --retry 2 -o /dev/null \
  http://localhost:8080/status/503 2>&1 | grep -c 'Will retry'
```

**Verifica**:

```
2
```

Tres POST al servidor. Si fuera un `POST /pagos` que el servidor procesó
antes de devolver el 503, serían tres pagos. Apunta en `resiliencia.md`:

- Qué métodos reintentarías automáticamente y cuáles no.
- Qué ofrecen algunas APIs para poder reintentar un POST sin duplicar
  (pista: un header que empieza por `Idempotency`).

---

## Paso 10: La llamada completa

**Por qué**: todo lo de la semana junto, en el comando que acaba dentro del
toolkit.

**Comando**:

```bash
curl --fail-with-body -sS \
  --connect-timeout 5 --max-time 10 \
  --retry 3 --retry-connrefused --retry-max-time 30 \
  -L --max-redirs 5 --proto-redir '=https' \
  --cacert "$CA" \
  https://localhost:8443/redirect/2 | jq -r .url
```

**Verifica**:

```
https://localhost:8443/get
```

Apunta en `resiliencia.md` qué hace cada línea del comando, en una frase por
línea.

---

## ✅ Resultado

- [ ] `resiliencia.md` tiene las fases de una petición medidas en tu equipo
- [ ] `resiliencia.md` distingue los dos 28 por su mensaje
- [ ] He visto la espera de 1, 2 y 4 segundos y sé qué códigos se reintentan
- [ ] He calculado el peor caso de una petición con reintentos y lo he acotado
- [ ] Sé por qué el toolkit no reintenta un POST

```bash
./scripts/verificar-semana.sh 05
```

Esta práctica prepara el `--connect-timeout` y los reintentos del proyecto:
solo para GET, PUT y DELETE.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| El paso 3 da `(7)` o `(101)` en vez de 28 | Tu red devuelve "inalcanzable" para `10.255.255.1` en vez de perder los paquetes | Prueba `10.0.0.123` u otra IP privada que no exista en tu red |
| `/delay/10` responde antes | El laboratorio tiene otro `HTTPBIN_MAX_DURATION` en `.env` | Es correcto: el límite lo pone el laboratorio |
| El paso 5 no muestra los avisos | Añadiste `-s`, o tu shell no redirige `2>&1` | Copia el comando tal cual |
| Los tiempos del paso 7 no cuadran al segundo | El reloj de `time` incluye el arranque de curl | Basta con que estén cerca de 15 y 5 |
| `time` muestra otro formato | Es el `time` de zsh | Mira el valor `total` |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 03 — Sesiones y redirects](03-sesiones-y-redirects.md) | [Proyecto](../3-proyecto/README.md) |
