# Ejercicio 3: Configuracion con .curlrc

## Objetivo

Crear un archivo de configuracion global `~/.curlrc` con opciones utiles y un
archivo local para simular la configuracion de un proyecto especifico.

## Parte 1: verificar estado actual

Antes de crear el curlrc, verifica si ya existe uno:

```bash
cat ~/.curlrc 2>/dev/null && echo "Existe" || echo "No existe"
```

Si existe, haz un backup:
```bash
cp ~/.curlrc ~/.curlrc.backup
```

## Parte 2: crear el curlrc global

Crea (o edita) `~/.curlrc` con el siguiente contenido:

```
# ~/.curlrc - Configuracion global de curl
# Creado como parte del bootcamp bc-curl, semana 6

# Seguir redirecciones HTTP automaticamente
location

# Timeouts para evitar esperas indefinidas
connect-timeout = 10
max-time = 30

# Silencioso pero muestra errores de curl
silent
show-error
```

Verifica que el archivo se creo:
```bash
cat ~/.curlrc
```

## Parte 3: verificar que las opciones se aplican

Prueba que `location` funciona (httpbin redirige de HTTP a HTTPS):

```bash
# Sin curlrc: seguiria sin redireccion y mostraria 301
# Con curlrc (location activo): deberia llegar al destino final
curl http://httpbin.org/redirect/2
```

Deberia ver el JSON de respuesta sin necesidad de pasar `-L`.

Prueba que `max-time` funciona:

```bash
# Este endpoint tarda mas de 30 segundos, deberia fallar
curl https://httpbin.org/delay/35
# Deberia mostrar: curl: (28) Operation timed out after 30000 milliseconds
```

Prueba que `show-error` funciona (muestra error aunque este silencioso):

```bash
# Con un host invalido, deberia mostrar el error aunque curl este silencioso
curl https://este-host-no-existe-12345.ejemplo.com/
# Deberia mostrar: curl: (6) Could not resolve host: ...
```

## Parte 4: override desde CLI

Demuestra que puedes sobreescribir el curlrc desde la linea de comandos:

```bash
# El curlrc tiene "silent", pero aqui queremos ver el progreso
curl --no-silent --no-show-error https://httpbin.org/get -o /dev/null

# El curlrc tiene "location", pero aqui queremos ver el 301 sin seguirlo
curl --no-location -I https://httpbin.org/redirect/1

# El curlrc tiene max-time = 30, pero aqui damos mas tiempo
curl --max-time 5 https://httpbin.org/delay/3
```

Guarda el output de cada comando en `overrides.txt`.

## Parte 5: curlrc de proyecto

Crea un directorio para el ejercicio y un curlrc local:

```bash
mkdir -p /tmp/proyecto-api
cd /tmp/proyecto-api

cat > .curlrc <<'EOF'
# .curlrc del proyecto
# Configura la autenticacion y headers base para la API

# Estos headers se enviaran en cada request dentro del proyecto
header = "Accept: application/json"
header = "X-Client: bc-curl-bootcamp"

# Timeout mas agresivo para la API interna
connect-timeout = 3
max-time = 10
EOF
```

Ahora ejecuta curl desde ese directorio y verifica que los headers se agregan:

```bash
# Desde /tmp/proyecto-api
curl -s https://httpbin.org/headers | python3 -m json.tool
```

Deberia aparecer `X-Client: bc-curl-bootcamp` y `Accept: application/json` en
la seccion de headers.

Compara con ejecutar el mismo comando desde tu directorio home (donde no hay
.curlrc local):

```bash
cd ~
curl -s https://httpbin.org/headers | python3 -m json.tool
```

Los headers del proyecto no deberan aparecer.

## Parte 6: ignorar el curlrc completamente

Para depuracion, a veces necesitas ejecutar curl sin ningun curlrc:

```bash
curl --config /dev/null -v https://httpbin.org/get 2>&1 | head -20
```

Esto carga la configuracion de `/dev/null` (vacio) en lugar del curlrc habitual.

## Entregables

- Contenido de `~/.curlrc` creado
- `overrides.txt`: output de los comandos de override
- Respuesta en `respuestas.md`:
  1. Que pasa si pones `max-time = 5` en el curlrc y pasas `--max-time 60` en
     CLI? Cual gana?
  2. Si tienes `~/.curlrc` con `silent` y `.curlrc` local con `no-silent`, cual
     prevalece?
  3. Que riesgo hay en poner `insecure` en el curlrc global?
