# Ejercicio 04: Timeouts y reintentos

## Objetivo

Experimentar con los dos tipos de timeout de curl, forzar errores de timeout para leer los mensajes, y configurar reintentos automáticos.

---

## Tarea 1: Timeout en la transferencia con --max-time

httpbin `/delay/N` espera N segundos antes de responder. Usalo para forzar timeouts:

```bash
# Request que tarda 2 segundos: funciona con max-time 5
curl --max-time 5 https://httpbin.org/delay/2
echo "Exit code: $?"

# Request que tarda 10 segundos: falla con max-time 3
curl --max-time 3 https://httpbin.org/delay/10
echo "Exit code: $?"
```

**Preguntas:**
- ¿Cuál es el mensaje de error cuando se supera `--max-time`?
- ¿Cuál es el exit code de curl en caso de timeout?
- ¿Cuántos milisegundos esperó curl antes de abortar?

---

## Tarea 2: Medir el tiempo real con -w

Usar `-w` para medir cuánto tiempo tomó cada fase de la conexión:

```bash
# Request normal: ver tiempos de cada fase
curl -s -o /dev/null -w "\
tiempo_dns:        %{time_namelookup}s\n\
tiempo_conexion:   %{time_connect}s\n\
tiempo_ssl:        %{time_appconnect}s\n\
tiempo_espera:     %{time_starttransfer}s\n\
tiempo_total:      %{time_total}s\n\
status:            %{http_code}\n" \
     https://httpbin.org/get

# Request lenta (delay 3s): ver cómo se refleja en tiempo_espera
curl -s -o /dev/null -w "tiempo_total: %{time_total}s | status: %{http_code}\n" \
     https://httpbin.org/delay/3
```

**Pregunta:** ¿Cuál es la diferencia entre `time_connect` y `time_starttransfer`?

---

## Tarea 3: --connect-timeout vs --max-time

Ver la diferencia entre los dos timeouts:

```bash
# --connect-timeout: tiempo para establecer la conexión
# Si la conexión se establece rápido pero la respuesta tarda, no falla
curl --connect-timeout 5 --max-time 30 https://httpbin.org/delay/3

# Verificar que connect-timeout no afecta la respuesta lenta
time curl --connect-timeout 5 --max-time 10 https://httpbin.org/delay/3
```

Para ver la diferencia real de `--connect-timeout`, necesitarías un host que no responda al TCP SYN. Podés simular con un host inaccesible:

```bash
# Un host que no existe o no responde
curl --connect-timeout 3 https://192.0.2.1/  # 192.0.2.1 es una IP reservada (no routeable)
echo "Exit code: $?"
```

**Preguntas:**
- ¿Qué mensaje muestra curl cuando falla `--connect-timeout`?
- ¿Es el mismo mensaje que cuando falla `--max-time`?

---

## Tarea 4: Reintentos con --retry

```bash
# Reintentar 3 veces con pausa de 2 segundos
# (httpbin /get siempre responde OK, así que no reintentará, pero veamos la config)
curl --retry 3 --retry-delay 2 -v https://httpbin.org/get 2>&1 | grep -E "retry|Retry"
```

Para ver reintentos en acción, usar un endpoint que falle a veces. Con httpbin podés forzar un status 500:

```bash
# Intentar con status 500 (curl no reintenta 5xx por defecto)
curl --retry 3 https://httpbin.org/status/500
echo "Exit code: $?"

# Con --retry-all-errors, curl reintenta también los 5xx
curl --retry 3 --retry-delay 1 --retry-all-errors https://httpbin.org/status/500
echo "Exit code: $?"
```

**Preguntas:**
- Sin `--retry-all-errors`, ¿reintenta curl cuando recibe un 500?
- ¿Cuánto tiempo total esperó con `--retry 3 --retry-delay 1 --retry-all-errors`?

---

## Tarea 5: Configuración completa para producción

Combinar todos los flags de timeout y retry:

```bash
# Configuración para una API externa: robusta pero con límites claros
curl --connect-timeout 5 \
     --max-time 30 \
     --retry 3 \
     --retry-delay 5 \
     --retry-max-time 120 \
     -s -o respuesta.json -w "Status: %{http_code} | Tiempo: %{time_total}s\n" \
     https://httpbin.org/get

cat respuesta.json | python3 -m json.tool | head -5
```

**Pregunta:** ¿Cuál es el tiempo total máximo que este comando podría tomar en el peor caso (3 reintentos, todos con timeout de 30s)?

---

## Tarea 6: Script con backoff exponencial

Implementar backoff exponencial manual:

```bash
cat > backoff-retry.sh << 'SCRIPT'
#!/bin/bash

URL="${1:-https://httpbin.org/get}"
MAX_INTENTOS=4
ESPERA=1
EXITO=0

echo "Iniciando requests a $URL..."

for intento in $(seq 1 $MAX_INTENTOS); do
    echo -n "Intento ${intento}/${MAX_INTENTOS}... "
    
    HTTP_CODE=$(curl -s -o /dev/null \
        --connect-timeout 5 \
        --max-time 15 \
        -w "%{http_code}" \
        "$URL")
    
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
        echo "Exito! (HTTP $HTTP_CODE)"
        EXITO=1
        break
    else
        echo "Fallo (HTTP $HTTP_CODE). Esperando ${ESPERA}s..."
        sleep "$ESPERA"
        ESPERA=$((ESPERA * 2))
    fi
done

if [ "$EXITO" -eq 0 ]; then
    echo "Error: todos los intentos fallaron"
    exit 1
fi
SCRIPT

chmod +x backoff-retry.sh

# Probar con un endpoint exitoso
./backoff-retry.sh https://httpbin.org/get

# Probar con un endpoint que siempre falla (ver el backoff)
./backoff-retry.sh https://httpbin.org/status/503
```

**Pregunta:** ¿Cuáles fueron los tiempos de espera entre reintentos? ¿Por qué el backoff exponencial es mejor que esperar siempre lo mismo?

---

## Entrega

Archivo `respuestas.md` con:
1. Mensaje de error y exit code del timeout (Tarea 1)
2. Output de los tiempos de `time_connect` vs `time_starttransfer` (Tarea 2)
3. Diferencia entre mensaje de `--connect-timeout` vs `--max-time` (Tarea 3)
4. Comportamiento de `--retry` con 500 con y sin `--retry-all-errors` (Tarea 4)
5. Tiempo máximo teórico del peor caso de la Tarea 5
6. Tiempos de espera del backoff y justificación (Tarea 6)
