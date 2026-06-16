# Transferencia avanzada: velocidad, timeouts y reintentos

![Transferencia avanzada](../0-assets/05-transferencia-avanzada.svg)

## Limitar el ancho de banda con --limit-rate

`--limit-rate` limita la velocidad de transferencia (upload y download). Útil para simular conexiones lentas o para no saturar la red:

```bash
# Limitar a 100 KB/s
curl --limit-rate 100k -o archivo.bin https://httpbin.org/stream-bytes/1000000

# Limitar a 1 MB/s
curl --limit-rate 1M -o archivo.bin https://httpbin.org/stream-bytes/5000000

# Limitar a 500 bytes/s (muy lento, para pruebas)
curl --limit-rate 500 -o archivo.txt https://httpbin.org/get
```

Las unidades son: `k` o `K` para kilobytes, `m` o `M` para megabytes, `g` o `G` para gigabytes. Sin sufijo se interpreta como bytes.

---

## Timeouts: dos tipos diferentes

curl distingue entre dos tipos de timeout que es importante no confundir:

### --connect-timeout: tiempo para establecer la conexión

Tiempo máximo que curl espera para que se establezca la conexión TCP (y TLS si es HTTPS). No incluye la transferencia de datos.

```bash
# Fallar si la conexión no se establece en 5 segundos
curl --connect-timeout 5 https://httpbin.org/get

# Útil para detectar hosts caídos rápidamente
curl --connect-timeout 3 https://servidor-inexistente.ejemplo.com
```

### --max-time: tiempo total incluyendo transferencia

Tiempo máximo total del request: conexión + tiempo de espera del servidor + transferencia completa.

```bash
# El request completo no puede durar más de 30 segundos
curl --max-time 30 -o archivo.bin https://httpbin.org/stream-bytes/1000000

# Forzar timeout en un endpoint lento (httpbin /delay/N demora N segundos)
curl --max-time 3 https://httpbin.org/delay/10
# curl: (28) Operation timed out after 3001 milliseconds
```

Regla práctica: `--connect-timeout` entre 3-10 segundos, `--max-time` según lo que tarde la operación completa.

---

## Reintentos con --retry

`--retry N` le dice a curl que reintente el request hasta N veces si falla por errores transitorios (timeout, error de red):

```bash
# Reintentar hasta 3 veces
curl --retry 3 https://httpbin.org/get

# Combinado con --max-time
curl --retry 3 --max-time 10 https://httpbin.org/get
```

Por defecto curl espera poco entre reintentos. Para agregar pausa:

```bash
# Esperar 5 segundos entre cada reintento
curl --retry 3 --retry-delay 5 https://httpbin.org/get
```

Para limitar el tiempo total dedicado a reintentos:

```bash
# No más de 60 segundos en total para todos los reintentos
curl --retry 5 --retry-max-time 60 https://httpbin.org/get
```

Nota importante: `--retry` solo reintenta en errores de red o timeout. No reintenta si el servidor responde con 5xx. Para reintentar en errores del servidor usá `--retry-all-errors` (curl 7.71+).

---

## Descargar solo un rango de bytes con --range

El header HTTP `Range` permite pedir solo una porción de un archivo. Útil para:
- Retomar descargas
- Descargar partes de archivos grandes en paralelo
- Inspeccionar los primeros bytes de un binario

```bash
# Descargar solo los primeros 999 bytes (bytes 0 a 999)
curl --range 0-999 -o primeros-1k.bin https://httpbin.org/stream-bytes/10000

# Descargar del byte 1000 al 1999
curl --range 1000-1999 -o segundo-bloque.bin https://httpbin.org/stream-bytes/10000

# Descargar los últimos 500 bytes (sin número inicial)
curl --range -500 -o ultimos-500.bin https://httpbin.org/stream-bytes/10000
```

Para que `--range` funcione el servidor debe soportar el header `Accept-Ranges: bytes`. Podés verificarlo con `-I`:

```bash
curl -I https://httpbin.org/stream-bytes/10000 | grep -i range
```

---

## Ejemplo: script con reintentos y backoff exponencial

curl no tiene backoff exponencial nativo, pero podés implementarlo en bash:

```bash
#!/bin/bash
URL="https://httpbin.org/get"
MAX_INTENTOS=5
ESPERA=1

for i in $(seq 1 $MAX_INTENTOS); do
    if curl --max-time 10 --connect-timeout 5 -s -o /dev/null -w "%{http_code}" "$URL" | grep -q "^2"; then
        echo "Exito en el intento $i"
        break
    else
        echo "Intento $i fallido. Esperando ${ESPERA}s..."
        sleep "$ESPERA"
        ESPERA=$((ESPERA * 2))
    fi
done
```

---

## Resumen de flags de transferencia

| Flag | Función |
|------|---------|
| `--limit-rate 100k` | Velocidad máxima de transferencia |
| `--connect-timeout N` | Tiempo máximo para establecer la conexión |
| `--max-time N` | Tiempo máximo total del request |
| `--retry N` | Número de reintentos en caso de fallo |
| `--retry-delay N` | Segundos entre reintentos |
| `--retry-max-time N` | Tiempo total máximo para todos los reintentos |
| `--range 0-999` | Descargar solo bytes 0 a 999 |
| `-C -` | Continuar descarga interrumpida |
