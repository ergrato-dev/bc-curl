# Anatomía de la URL

> La mitad de los fallos de una integración son una URL mal construida. La otra
> mitad son una credencial. Esta semana atacamos la primera mitad.

![Las partes de una URL: esquema, credenciales, host, puerto, path, query y fragmento](../0-assets/02-anatomia-url.svg)

## 🎯 Objetivos

- Descomponer cualquier URL en sus siete partes
- Decir qué partes viajan al servidor y cuáles se quedan en el cliente
- Saber cuándo hace falta codificar un carácter y qué pasa si no lo haces
- Entender por qué las comillas alrededor de la URL no son opcionales en bash

---

## 1. Qué problema resuelve

Una URL tiene que decir, en una sola cadena de texto: con qué protocolo hablar,
con qué máquina, en qué puerto, qué recurso pedir y con qué parámetros. Y tiene
que hacerlo con un juego de caracteres tan limitado que ni siquiera admite
espacios.

Casi todo lo que sale mal con una URL es una de estas tres cosas:

- Un carácter que había que codificar y no se codificó
- Una parte que creías que llegaba al servidor y no llega
- El shell interpretando un carácter antes de que curl lo vea

---

## 2. Cómo funciona

### 2.1 Las siete partes

```
https://ana:secreto@api.ejemplo.com:8443/v1/users?rol=admin&activo=true#seccion
└─┬─┘   └────┬────┘ └──────┬───────┘└─┬─┘└───┬──┘ └────────┬──────────┘ └──┬──┘
esquema  credenciales     host      puerto  path         query         fragmento
```

| Parte | Ejemplo | Obligatoria | ¿Viaja al servidor? |
|---|---|:--:|:--:|
| **Esquema** | `https` | Sí | Determina el protocolo, no viaja como tal |
| **Credenciales** | `ana:secreto` | No | Sí, pero convertidas en un header `Authorization` |
| **Host** | `api.ejemplo.com` | Sí | Sí, en el header `Host` |
| **Puerto** | `8443` | No | No: determina a dónde se conecta el socket |
| **Path** | `/v1/users` | No (`/` por defecto) | Sí, en la línea inicial |
| **Query** | `?rol=admin&activo=true` | No | Sí, pegada al path en la línea inicial |
| **Fragmento** | `#seccion` | No | **No. Nunca.** |

### 2.2 El fragmento no viaja

Es la parte que más sorprende. Todo lo que va después de `#` es **para el
cliente**: un navegador lo usa para hacer scroll hasta un ancla. El servidor
nunca lo ve, y curl ni siquiera lo manda.

```bash
curl -s http://localhost:8080/anything#esto-no-viaja | jq -r '.url'
# http://localhost:8080/anything
```

Si tu API espera recibir algo en un `#`, esa API está rota, o lo que quieres es
un parámetro de query.

### 2.3 El puerto por defecto

Si no lo escribes, lo pone el esquema:

| Esquema | Puerto por defecto |
|---|:--:|
| `http` | 80 |
| `https` | 443 |
| `ftp` | 21 |

Por eso `curl http://localhost:8080/get` necesita el `:8080` explícito: el
laboratorio no escucha en el 80.

### 2.4 El esquema no es opcional (pero curl te lo perdona)

```bash
curl -s -o /dev/null -w '%{url_effective}\n' localhost:8080/get
# http://localhost:8080/get
```

curl asume `http://` cuando falta. Es cómodo escribiendo a mano y **peligroso en
un script**: si tu variable de configuración se queda vacía en la parte del
esquema, acabas mandando por HTTP en claro algo que creías cifrado. En un script
el esquema se escribe siempre.

---

## 3. Codificación de caracteres

### 3.1 Cuándo hace falta

Una URL solo admite letras, dígitos y unos pocos símbolos. Todo lo demás se
escribe como `%` seguido del valor hexadecimal del byte.

| Carácter | Codificado | Por qué |
|---|---|---|
| espacio | `%20` | Corta la línea inicial de la petición |
| `&` | `%26` | Separa parámetros: sin codificar, parte el valor en dos |
| `=` | `%3D` | Separa clave de valor |
| `?` | `%3F` | Empieza la query |
| `#` | `%23` | Empieza el fragmento, y el resto se pierde |
| `+` | `%2B` | En una query, `+` significa espacio |
| `/` | `%2F` | Separa segmentos del path |

Los acentos y la ñ también: `ñ` en UTF-8 son dos bytes, y se escribe `%C3%B1`.

### 3.2 Qué pasa si no codificas

Míralo:

```bash
# El & sin codificar parte el valor: el servidor ve dos parametros.
curl -s 'http://localhost:8080/get?empresa=Ana&Juan' | jq -c '.args'
# {"Juan":[""],"empresa":["Ana"]}
```

El servidor recibió un parámetro `empresa` con valor `Ana` y otro llamado `Juan`
sin valor. No hay error, no hay aviso: simplemente los datos llegaron mal.

Este es el fallo más silencioso de la semana, y el que más tiempo cuesta
encontrar cuando aparece en producción.

### 3.3 Cómo se hace bien

`--data-urlencode` codifica el valor por ti. Con `-G` lo pone en la query en vez
de en el cuerpo:

```bash
curl -s -G 'http://localhost:8080/get' \
  --data-urlencode 'empresa=Ana&Juan' | jq -c '.args'
# {"empresa":["Ana&Juan"]}
```

Ahora sí: un parámetro, con su valor entero.

> [!NOTE]
> `--data-urlencode` existe desde 7.18, así que está en cualquier curl que te
> encuentres. Su uso completo llega en la Semana 02; aquí basta con saber que la
> alternativa a codificar a mano existe.

---

## 4. El shell antes que curl

Hay un paso previo que no tiene nada que ver con HTTP: **bash lee la línea antes
que curl**. Y bash tiene sus propios caracteres especiales.

```bash
# MAL: bash interpreta el & como "ejecuta en segundo plano" y parte el comando.
curl http://localhost:8080/get?a=1&b=2

# MAL: bash expande el ? y el * como comodines de nombres de archivo.
curl http://localhost:8080/anything?buscar=*.txt
```

La regla es simple y no tiene excepciones útiles:

```bash
# BIEN: comillas simples. Bash no toca nada de lo que hay dentro.
curl -s 'http://localhost:8080/get?a=1&b=2' | jq -c '.args'
# {"a":["1"],"b":["2"]}
```

**Comillas simples siempre.** Comillas dobles solo cuando necesitas que bash
expanda una variable dentro:

```bash
BASE='http://localhost:8080'
curl -s "${BASE}/get?a=1&b=2" | jq -c '.args'
```

---

## 5. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|
| URL sin comillas en el shell | `&`, `?`, `*` y `;` los interpreta bash antes de que curl los vea | Comillas simples siempre; dobles si hay variables |
| Meter la contraseña en la URL (`https://ana:secreto@host/`) | Queda en el historial, en `ps` y en los logs de cualquier proxy | `-u` con variable de entorno, o `--netrc`. Semana 03 |
| Concatenar parámetros a mano en un script | El primer valor con un espacio o un `&` rompe la petición sin avisar | `--data-urlencode` con `-G` |
| Omitir el esquema en un script | curl asume `http://` y mandas en claro lo que creías cifrado | Escribe `https://` siempre |
| Confiar en que el `#` llega al servidor | No llega. Nunca | Parámetro de query |

---

## 6. Trucos

- **`%{url_effective}` te dice a qué URL fue curl de verdad**, después de
  aplicar defaults y redirects. Es lo primero que hay que mirar cuando "la URL
  parecía bien":

  ```bash
  curl -s -o /dev/null -L -w '%{url_effective}\n' http://localhost:8080/redirect/2
  # http://localhost:8080/get
  ```

- **`/anything` te devuelve la URL como la vio el servidor**, que es lo único que
  cuenta:

  ```bash
  curl -s 'http://localhost:8080/anything/de/varios/niveles?x=1' | jq -r '.url'
  ```

- **Para ver cómo queda codificado un valor**, combina `-G --data-urlencode`
  con `%{url_effective}`. curl te enseña la URL exacta que construyó:

  ```bash
  curl -s -o /dev/null -G 'http://localhost:8080/get' \
    --data-urlencode 'q=Ana & Juan #1' -w '%{url_effective}\n'
  # http://localhost:8080/get?q=Ana+%26+Juan+%231
  ```

  El espacio se convirtió en `+`, el `&` en `%26` y el `#` en `%231`.

- **curl expande rangos y listas en la URL** por su cuenta: `[1-5]` y `{a,b,c}`.
  Es una función suya, no del shell — por eso hay que poner comillas para que
  bash no la estropee. Se ve a fondo en la Semana 06.

---

## 📚 Recursos Adicionales

- [RFC 3986 — URI Generic Syntax](https://datatracker.ietf.org/doc/html/rfc3986) — la definición formal. La sección 3 es la de las partes
- [MDN — Qué es una URL](https://developer.mozilla.org/es/docs/Learn/Common_questions/Web_mechanics/What_is_a_URL) — en español, para fijar el vocabulario
- [everything.curl.dev — URL](https://everything.curl.dev/cmdline/urls) — incluye la expansión de rangos y listas

---

## ✅ Checklist de Verificación

- [ ] Nombras las siete partes de una URL sin mirar
- [ ] Compruebas con `/anything` que el fragmento no llega al servidor
- [ ] Reproduces el fallo del `&` sin codificar y lo arreglas con `--data-urlencode`
- [ ] Explicas por qué `curl url?a=1&b=2` sin comillas no hace lo que parece
- [ ] Usas `%{url_effective}` para ver a dónde fue la petición de verdad
