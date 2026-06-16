# El archivo de configuracion .curlrc

## Que es .curlrc

`.curlrc` es un archivo de texto donde puedes especificar opciones de curl que se
aplicaran automaticamente en cada invocacion, sin tener que escribirlas en cada
comando. Es equivalente a tener un "perfil" de defaults para curl.

curl busca este archivo en dos ubicaciones:
- **Global del usuario**: `~/.curlrc` (o `%APPDATA%\curl\_curlrc` en Windows)
- **Local al directorio**: `.curlrc` en el directorio de trabajo actual

## Sintaxis

Un flag por linea. Se escribe el nombre largo del flag sin los dos guiones. Para
flags con valor, se usa `=` o un espacio.

```
# Esto es un comentario
silent
location
connect-timeout = 10
max-time = 30
user-agent = "mi-script/1.0"
```

Equivale a ejecutar siempre:
```bash
curl --silent --location --connect-timeout 10 --max-time 30 \
     --user-agent "mi-script/1.0" ...
```

## Opciones utiles para el curlrc global

```
# ~/.curlrc

# Seguir redirecciones automaticamente
location

# Timeouts razonables para no quedarse colgado
connect-timeout = 10
max-time = 30

# Mostrar errores aunque este en modo silencioso
# (equivale a siempre usar -sS en lugar de solo -s)
silent
show-error
```

Con este curlrc, cada vez que ejecutas `curl` ya tienes esos comportamientos sin
escribirlos. Puedes seguir usando curl interactivamente con `-v` u otras opciones
sin problema — el curlrc es solo la base.

## Override desde CLI

Cualquier opcion del curlrc puede sobreescribirse desde la linea de comandos.
Para cancelar una opcion booleana se usa el prefijo `--no-`:

```bash
# El curlrc tiene "location", pero para este request no quiero seguir redirecciones
curl --no-location https://httpbin.org/redirect/3

# El curlrc tiene "silent", pero quiero ver el output completo
curl --no-silent --no-show-error -v https://httpbin.org/get

# El curlrc tiene max-time = 30, pero este endpoint puede tardar mas
curl --max-time 120 https://httpbin.org/delay/60
```

El flag que se especifique en CLI siempre tiene prioridad sobre el curlrc.

## Curlrc por proyecto

Para proyectos con configuracion especifica, puedes tener un curlrc dedicado y
cargarlo con `--config`:

```bash
# Usar la configuracion del proyecto en lugar de la global
curl --config proyecto.curlrc https://api.miempresa.com/v1/users
```

Ejemplo de `proyecto.curlrc`:
```
# proyecto.curlrc - API interna
silent
show-error
location
connect-timeout = 5
max-time = 15
header = "X-API-Version: 2024-01"
header = "Accept: application/json"
```

Tambien puedes desactivar completamente el curlrc global para un comando:

```bash
# Ignora completamente el ~/.curlrc
curl --config /dev/null https://httpbin.org/get
```

## Curlrc local al directorio

Si existe un `.curlrc` en el directorio desde donde ejecutas curl, se cargara
adicionalmente al global. Esto permite tener configuracion especifica por proyecto
sin necesitar `--config`:

```bash
# Dentro del directorio del proyecto, con su propio .curlrc
ls .curlrc
curl https://api.miproyecto.com/endpoint  # aplica .curlrc local automaticamente
```

## Precedencia completa

De mayor a menor prioridad:

1. Flags pasados en la linea de comandos
2. Opciones en el curlrc especificado con `--config`
3. Opciones en `.curlrc` del directorio actual
4. Opciones en `~/.curlrc` (global del usuario)

## Que NO poner en .curlrc

Evita poner credenciales o tokens en curlrc, especialmente si el archivo puede
quedar en un repositorio. Para credenciales usa variables de entorno o un archivo
de credenciales separado con permisos restringidos:

```bash
chmod 600 ~/.curlrc
chmod 600 ~/.curl-credentials
```

Para tokens de API, la forma correcta es pasarlos via variable de entorno en el
script y usar `-H "Authorization: Bearer $TOKEN"`.
