# Glosario - Semana 6

## write-out

Flag de curl (`--write-out` o `-w`) que imprime una cadena de texto despues de
completar la transferencia. La cadena puede contener variables como `%{http_code}`
que curl reemplaza con valores reales de esa transferencia. Ejemplo:
`curl -w "%{http_code}\n" -o /dev/null -s URL`.

## stderr

File descriptor 2 en sistemas Unix. Por convencion se usa para mensajes de error,
logs y diagnostico, a diferencia de stdout (file descriptor 1) que se usa para
datos. En bash, se redirige con `2>archivo` o `2>&1` (para mezclarlo con stdout).
curl escribe su barra de progreso y mensajes de error en stderr.

## stdout

File descriptor 1 en sistemas Unix. Es la salida estandar donde los programas
escriben sus datos principales. curl escribe el body de la respuesta HTTP en
stdout por defecto. Se puede redirigir con `>archivo` o capturar con `$(...)`.

## trace

Mecanismo de depuracion de curl que captura todos los bytes que se transfieren,
incluyendo el trafico TLS, en un archivo. Hay dos variantes:
`--trace archivo` (formato binario) y `--trace-ascii archivo` (hex + ASCII
imprimible, mas facil de leer). Se usa para diagnosticar problemas de protocolo
que `-v` no muestra con suficiente detalle.

## .curlrc

Archivo de configuracion de curl donde se especifican flags que se aplicaran
automaticamente en cada ejecucion. El archivo global es `~/.curlrc` (un flag
por linea, sin los guiones). Permite establecer defaults como timeouts, seguir
redirecciones o headers personalizados. Se puede sobreescribir desde CLI con
`--no-<opcion>`.

## silent

Flag `-s` o `--silent` de curl. Suprime la barra de progreso y los mensajes de
error de curl. Se usa en scripts para evitar output no deseado. Se recomienda
combinarlo con `-S` (`--show-error`) para que los errores de curl sigan siendo
visibles: `-sS`.

## verbose

Flag `-v` o `--verbose` de curl. Muestra informacion detallada del proceso de
transferencia en stderr: resolucion DNS, conexion TCP, handshake TLS, headers
enviados y recibidos. Es el primer nivel de depuracion. Los headers enviados se
muestran con prefijo `>` y los recibidos con `<`.

## time_total

Variable de `--write-out` que contiene el tiempo total de la transferencia en
segundos, desde el inicio hasta el ultimo byte recibido. Incluye DNS, TCP, TLS,
envio del request y recepcion de la respuesta completa.

## time_starttransfer

Variable de `--write-out` que mide el tiempo hasta recibir el primer byte del
body de la respuesta. Es la metrica TTFB desde la perspectiva del cliente e
indica principalmente la latencia del servidor (tiempo de procesamiento), ya que
no incluye el tiempo de descarga del body completo.

## TTFB

Time To First Byte. Tiempo que transcurre desde que el cliente envia el request
hasta que recibe el primer byte del body de la respuesta. En curl se mide con
`%{time_starttransfer}`. Un TTFB alto indica latencia del servidor o red. Un
`time_total` mucho mayor que el TTFB indica que el body es grande y la descarga
toma tiempo.

## benchmark

Proceso de medir el rendimiento de un sistema ejecutando una carga de prueba
repetida y calculando estadisticas (minimo, maximo, promedio, percentiles). En
el contexto de APIs, un benchmark simple hace N requests al mismo endpoint y
reporta los tiempos de respuesta. No es lo mismo que un test de carga (que hace
muchos requests en paralelo para medir concurrencia).
