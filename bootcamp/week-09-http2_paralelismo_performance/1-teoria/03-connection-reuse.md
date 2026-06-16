# Reutilizacion de Conexiones

## Por Que Importa

Establecer una conexion HTTP tiene un costo:
1. **TCP handshake**: 1 round-trip (SYN, SYN-ACK, ACK)
2. **TLS handshake**: 1-2 round-trips adicionales (negociacion de cifrado, certificados)
3. **Primer request**: solo recien aqui se transfieren datos

En una red con 50ms de latencia (muy tipico en internet), estos handshakes suman 150-250ms antes de que llegue el primer byte de datos. Si cada request abre una conexion nueva, se paga este costo en cada request.

---

## Persistent Connections (HTTP Keep-Alive)

HTTP/1.1 introdujo las persistent connections: la conexion TCP se mantiene abierta despues de un request para reutilizarla en el siguiente.

curl mantiene las conexiones abiertas por defecto cuando hace multiples requests al mismo host en el mismo proceso:

```bash
# Un solo proceso curl — reutiliza la conexion TCP
curl -s "https://httpbin.org/get" "https://httpbin.org/headers" "https://httpbin.org/ip"
```

La variable `%{num_connects}` en `--write-out` muestra cuantas conexiones nuevas se abrieron:

```bash
curl -s -w "Conexiones nuevas: %{num_connects}\n" \
  "https://httpbin.org/get" \
  "https://httpbin.org/headers" \
  "https://httpbin.org/ip"
# Conexiones nuevas: 1  (solo la primera, las otras reutilizaron)
```

---

## El Problema con Scripts en Loop

Cuando se ejecuta un script con un loop, **cada iteracion es un nuevo proceso curl**:

```bash
# PROBLEMA: cada iteracion abre una conexion nueva
for i in $(seq 1 10); do
  curl -s "https://httpbin.org/get?n=$i"
  # Este curl termina, cierra la conexion
done
# 10 procesos curl = 10 conexiones TCP + 10 TLS handshakes
```

Alternativas que reutilizan conexiones:

```bash
# Opcion 1: Pasar todas las URLs a un mismo curl
curl -s \
  "https://httpbin.org/get?n=1" \
  "https://httpbin.org/get?n=2" \
  ...

# Opcion 2: Archivo de config con multiples URLs
printf 'url = "https://httpbin.org/get?n=%d"\n' $(seq 1 10) | \
  curl -s -K -
```

---

## Controlar el Keep-Alive

```bash
# Desactivar keep-alive (siempre abre conexion nueva)
curl -s --no-keepalive "https://httpbin.org/get"

# Configurar tiempo de keep-alive (segundos)
curl -s --keepalive-time 30 "https://httpbin.org/get"
```

---

## HTTP/2 Multiplexing vs Persistent Connections

Son dos cosas distintas aunque relacionadas:

| Caracteristica | Persistent Connections (HTTP/1.1) | HTTP/2 Multiplexing |
|----------------|-----------------------------------|---------------------|
| Que reutiliza | La conexion TCP (un request a la vez) | La conexion TCP (multiples requests simultaneos) |
| Paralelismo | No — requests secuenciales | Si — multiples streams en paralelo |
| Conexiones TCP | Una por "sesion" con el servidor | Una por servidor (idealmente) |
| Beneficio | Elimina overhead de TCP+TLS handshake | + elimina esperas entre requests |

Con HTTP/2, curl puede hacer 50 requests al mismo servidor con UNA sola conexion TCP, todos en paralelo:

```bash
# HTTP/2 + paralelo: maxima eficiencia
time curl -s --http2 --parallel --parallel-max 50 \
  $(for i in $(seq 1 50); do echo "-o /dev/null https://www.cloudflare.com"; done)
```

---

## El Cache de Conexiones de curl

curl mantiene un pool de conexiones para reutilizar entre requests del mismo proceso. Por defecto, guarda hasta 5 conexiones inactivas.

Ver cuantas conexiones nuevas se abren:

```bash
WRITE_FORMAT='\n--- Conexion ---\nNuevas conexiones: %{num_connects}\nIP: %{remote_ip}:%{remote_port}\n'

curl -s -w "$WRITE_FORMAT" "https://httpbin.org/get" "https://httpbin.org/ip"
# Nuevas conexiones: 1 (primer request)
# Nuevas conexiones: 0 (reutilizo)
```

---

## Recomendaciones Practicas

Para scripts que hacen muchos requests al mismo servidor:

1. **Pasar todas las URLs a un mismo curl** en lugar de un loop — reutiliza conexiones
2. **Usar `--parallel`** para requests al mismo servidor — mejor que bash `&`
3. **Con HTTP/2**, el beneficio de reutilizar conexiones es mayor porque un solo socket maneja muchos streams
4. **Evitar `--no-keepalive`** a menos que el servidor lo requiera
5. **Medir con `%{num_connects}`** si no estas seguro de cuantas conexiones estas abriendo
