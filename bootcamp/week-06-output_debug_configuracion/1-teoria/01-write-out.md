# El flag --write-out

## Que es

`--write-out` (forma corta: `-w`) le dice a curl que imprima informacion extra
despues de completar la transferencia. El argumento es una cadena de formato donde
puedes mezclar texto libre con variables que curl sustituye por los valores reales
de esa transferencia.

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://httpbin.org/get
```

Resultado:
```
200
```

## Variables disponibles

Las variables se escriben como `%{nombre}`. Las mas utiles son:

| Variable | Descripcion |
|----------|-------------|
| `%{http_code}` | Codigo de estado HTTP (200, 404, 500, etc.) |
| `%{time_total}` | Tiempo total de la transferencia en segundos |
| `%{time_connect}` | Tiempo hasta establecer la conexion TCP |
| `%{time_starttransfer}` | Tiempo hasta recibir el primer byte del body (TTFB) |
| `%{size_download}` | Bytes descargados en el body |
| `%{speed_download}` | Velocidad de descarga en bytes/segundo |
| `%{url_effective}` | URL final (despues de redirecciones) |
| `%{redirect_url}` | URL a la que apuntaba el header Location |
| `%{content_type}` | Valor del header Content-Type de la respuesta |

## Formato personalizado con multiples variables

Puedes combinar variables, texto y caracteres de escape en el mismo formato:

```bash
curl -s -o /dev/null -w \
  "Status: %{http_code}\nTiempo total: %{time_total}s\nTTFB: %{time_starttransfer}s\nTamano: %{size_download} bytes\n" \
  https://httpbin.org/get
```

Resultado:
```
Status: 200
Tiempo total: 0.342156s
TTFB: 0.341823s
Tamano: 305 bytes
```

Para formatos largos es mas legible pasarlos en una variable bash:

```bash
FORMAT="Codigo: %{http_code}  Tiempo: %{time_total}s  Tamano: %{size_download}b\n"
curl -s -o /dev/null -w "$FORMAT" https://httpbin.org/get
```

## Escribir a stderr con %{stderr}

Por defecto, el output de `--write-out` va a stdout junto con el body. Para
separarlo puedes redirigirlo a stderr con el prefijo especial `%{stderr}`:

```bash
curl -o resultado.json -w "%{stderr}HTTP %{http_code} en %{time_total}s\n" \
  https://httpbin.org/get
```

Aqui el body JSON se guarda en `resultado.json` y las metricas aparecen en la
terminal via stderr. Puedes capturar stderr por separado con `2>metricas.txt`.

## Ejemplo: health check que muestra codigo y tiempo

```bash
#!/bin/bash
URL="https://httpbin.org/status/200"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
TIEMPO=$(curl -s -o /dev/null -w "%{time_total}" "$URL")

echo "URL: $URL"
echo "Status: $STATUS"
echo "Tiempo: ${TIEMPO}s"

if [ "$STATUS" = "200" ]; then
    echo "Resultado: OK"
else
    echo "Resultado: ERROR"
fi
```

Nota: en el ejemplo anterior hacemos dos requests separados. En produccion es mejor
capturar ambos valores en una sola llamada:

```bash
RESULTADO=$(curl -s -o /dev/null -w "%{http_code} %{time_total}" "$URL")
STATUS=$(echo "$RESULTADO" | cut -d' ' -f1)
TIEMPO=$(echo "$RESULTADO" | cut -d' ' -f2)
```

## Ejemplo: benchmark rapido de un endpoint

```bash
#!/bin/bash
URL="https://httpbin.org/get"
FORMAT="%{http_code} %{time_total} %{time_starttransfer} %{size_download}\n"

echo "code  total     ttfb      size"
echo "----  --------  --------  ----"

for i in $(seq 1 5); do
    curl -s -o /dev/null -w "$FORMAT" "$URL"
done
```

Resultado esperado:
```
code  total     ttfb      size
----  --------  --------  ----
200   0.341234  0.340987  305
200   0.298765  0.298432  305
200   0.315678  0.315234  305
200   0.289012  0.288765  305
200   0.302345  0.302012  305
```

## Notas importantes

- `time_total` incluye DNS, TCP, TLS y transferencia de datos.
- `time_starttransfer` es el indicador de TTFB (Time To First Byte), util para
  medir la latencia del servidor independientemente del tamano del body.
- Los valores de tiempo son decimales en segundos. Para milisegundos multiplica
  por 1000 con `awk` o `bc`.
- `--write-out` se ejecuta aunque la transferencia falle. Esto lo hace ideal para
  logging de errores.
