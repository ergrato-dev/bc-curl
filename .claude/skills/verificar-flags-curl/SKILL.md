---
name: verificar-flags-curl
description: Comprueba que los flags de curl, las variables de --write-out, los códigos de salida y los endpoints del laboratorio citados en el material existan de verdad, hagan lo que el texto dice y estén disponibles en la versión mínima que soporta el bootcamp. Usar SIEMPRE después de escribir teoría o prácticas con comandos, y antes de cerrar cualquier semana.
allowed-tools: Bash(curl *) Bash(jq*) Bash(grep*) Bash(docker *) Bash(shellcheck*) Read Grep Glob WebFetch
---

# Verificar flags, variables y endpoints

El fallo más probable de este repositorio no es un enlace roto: es un **flag
plausible que no existe**, o que existe pero no en la versión del alumno. Pasa
la revisión a ojo y revienta cuando alguien lo ejecuta.

Cuatro familias de error, por frecuencia:

1. **Variable de `--write-out` inventada.** `%{time_total}` existe;
   `%{total_time}` no. `%{response_code}` y `%{http_code}` son las dos válidas;
   `%{status_code}` no.
2. **Flag de versión posterior sin marcar.** `--json` es 7.82 y Ubuntu 22.04
   trae 7.81. Está a una versión de distancia.
3. **Flag que existe pero hace otra cosa.** `-f` descarta el cuerpo del error;
   `--fail-with-body` lo conserva. Confundirlos cambia el ejemplo entero.
4. **Endpoint del laboratorio que no está.** `go-httpbin` no implementa todo lo
   que implementaba el httpbin original.

## Alcance

Los archivos que se pasen como argumento; si no se indica nada, la semana en
curso: `1-teoria/`, `2-practicas/`, `3-proyecto/` y `checks.json`.

## Procedimiento

### 1. Extraer lo que hay que comprobar

```bash
# Flags largos
grep -rhoE '\-\-[a-z0-9][a-z0-9-]+' <ruta> | sort -u

# Variables de --write-out
grep -rhoE '%\{[a-z_]+\}' <ruta> | sort -u

# Endpoints del laboratorio
grep -rhoE 'localhost:(8080|8081|8443|8444)[a-zA-Z0-9/_.:{}-]*' <ruta> | sort -u

# Codigos de salida citados
grep -rhoE 'c[oó]digo (de salida )?[0-9]{1,2}|exit=[0-9]{1,2}' <ruta> | sort -u
```

### 2. ¿Existe el flag?

```bash
curl --help all | grep -- '--nombre-del-flag'
```

`curl --help` a secas solo muestra las opciones comunes: usa siempre
`--help all`.

### 3. ¿Desde qué versión?

La referencia autoritativa es el propio repositorio de curl:

```bash
curl -s https://raw.githubusercontent.com/curl/curl/master/docs/options-in-versions \
  | grep -- '--nombre-del-flag'
# --fail-with-body                     7.76.0
```

**El suelo del bootcamp es 7.81.** Todo lo posterior tiene que ir marcado en el
propio ejemplo, con su alternativa. La tabla completa está en
`docs/versiones-de-curl.md`, y si encuentras un flag que no está en ella,
añádelo.

### 4. ¿Existe la variable de `--write-out`?

No se adivina: se ejecuta.

```bash
curl -s -o /dev/null -w '%{la_variable}\n' http://localhost:8080/get
# Si no existe, curl avisa por stderr y no imprime nada:
#   curl: unknown --write-out variable: 'la_variable'
```

Para ver la lista entera de las validas, tal como la conoce **tu** binario:

```bash
curl --manual | sed -n '/^       -w, --write-out/,/^       See also/p'
```

Es la fuente que no miente: la del manual empotrado en el propio curl, no la de
la web, que describe la ultima version.

### 5. ¿Responde el endpoint del laboratorio?

```bash
curl -s -o /dev/null -w '%{http_code} %{url_effective}\n' <url>
```

Un 404 de `go-httpbin` significa que ese endpoint no está implementado, aunque
el httpbin original lo tuviera. Comprueba lo que hay:

```bash
# La portada de go-httpbin lista sus endpoints. El filtro se queda con las
# rutas de un solo segmento, que es donde estan casi todos.
curl -s http://localhost:8080/ | grep -oE 'href="/[a-z0-9:_-]+' | cut -d'"' -f2 | sort -u
```

### 6. ¿El código de salida es el que dice el texto?

```bash
curl <los-flags-del-ejemplo> <la-url-del-ejemplo> >/dev/null 2>&1; echo $?
```

Contrasta con la [tabla oficial](https://curl.se/libcurl/c/libcurl-errors.html).
Los que más aparecen en el material: `6` no resuelve el host, `7` no conecta,
`22` fallo HTTP con `--fail`, `28` timeout, `35` handshake TLS, `56` fallo al
recibir, `60` certificado no verificado.

### 7. ¿El script hace lo que dice?

```bash
shellcheck -S warning <ruta>/3-proyecto/starter/*.sh
```

## Salida

Una tabla, sin prosa alrededor:

```
archivo:línea | lo citado | veredicto | corrección
```

Veredictos: `OK`, `NO EXISTE`, `VERSIÓN` (existe pero es posterior a 7.81 y no
está marcado), `SEMÁNTICA` (existe pero no hace lo que dice el texto),
`ENDPOINT` (el laboratorio no lo sirve), `SIN VERIFICAR`.

Cierra con el recuento: `N comprobados, M problemas`.

## Reglas

- **No corrijas nada.** Este skill informa; quien escribe decide.
- **Ejecuta antes de opinar.** Un veredicto sin comando detrás no vale.
- **Si no puedes comprobarlo, dilo.** `SIN VERIFICAR` es una respuesta honesta;
  inventar un veredicto no.
- **No inventes hallazgos para parecer exhaustivo.** Cero problemas es un
  resultado válido y frecuente.
- Un flag que existe pero hace otra cosa distinta de la que dice el texto es un
  problema, y de los peores. Compruébalo también.
