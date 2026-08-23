# Guía de autoría — Bootcamp curl

Este archivo es la **fuente única de verdad** de cómo se escribe el contenido de
este repositorio. `CLAUDE.md` no duplica nada de aquí: lo enlaza.

---

## 📋 Contexto del Bootcamp

`bc-curl` enseña **curl como la herramienta con la que se opera y se depura
HTTP**, no como el atajo para bajar un archivo. El alumno termina hablando con
cualquier API REST desde la terminal, depurando TLS sin abrir una GUI, y
escribiendo scripts bash que se pueden poner en un cron sin miedo.

### 📊 Datos del bootcamp

| Dato | Valor |
|---|---|
| Duración | 10 semanas |
| Dedicación | 8 h/semana |
| Total | 80 horas |
| Modalidad | Autoestudio asincrónico |
| Nivel de entrada | Terminal básica (`ls`, `cd`, `cat`, pipes). Cero programación |
| Nivel de salida | Integra, depura y automatiza APIs HTTP desde bash |
| Herramienta central | curl 7.x / 8.x |
| Entorno de prácticas | Laboratorio Docker local, versiones fijadas |
| Proyecto hilo conductor | `api-toolkit`, un CLI que crece las diez semanas |
| Idioma de la prosa | Español |
| Idioma del código | Inglés |

---

## 🎯 Objetivos de Aprendizaje

Al terminar el bootcamp el alumno es capaz de:

- Leer una traza `-v` completa y decir en qué punto falló la petición
- Construir cualquier método HTTP con el cuerpo y los headers correctos
- Elegir el mecanismo de autenticación adecuado y **no filtrar la credencial**
- Subir y descargar archivos, incluidos multipart y transferencias reanudables
- Diagnosticar un fallo de TLS distinguiendo cadena, nombre, versión y cifrado
- Medir una petición con `--write-out` y explicar dónde se va el tiempo
- Escribir un script bash que falla cuando debe fallar y reintenta cuando debe reintentar
- Implementar los flujos OAuth2 de client credentials, authorization code + PKCE y device code
- Usar HTTP/2, HTTP/3 y peticiones en paralelo, y saber cuándo no aportan nada
- Integrar curl en un pipeline de CI/CD sin dejar secretos en los logs

---

## 📚 Estructura del Bootcamp

### Distribución por fases

#### Fase 1 — Fundamentos (S01-03, 24 h)
HTTP, la URL, métodos, headers, JSON y autenticación básica. Al terminar el
alumno consume una API REST autenticada.

#### Fase 2 — Intermedio (S04-06, 24 h)
Archivos, multipart, TLS, cookies, redirects, salida y depuración. Al terminar
el alumno diagnostica una petición que falla.

#### Fase 3 — Avanzado (S07-09, 24 h)
Scripting bash, OAuth2, HTTP/2, HTTP/3 y rendimiento. Al terminar el alumno
automatiza una integración completa.

#### Fase 4 — Producción (S10, 8 h)
Empaquetado, testing, CI/CD y seguridad del script. Al terminar el alumno
entrega `api-toolkit` como una herramienta instalable.

### Contenido semana a semana

| Semana | Slug | Tema |
|:--:|---|---|
| 01 | `week-01-http_y_curl_basico` | HTTP y curl básico |
| 02 | `week-02-metodos_http_headers_json` | Métodos HTTP, headers y JSON |
| 03 | `week-03-autenticacion_basica` | Autenticación básica |
| 04 | `week-04-archivos_formularios_multipart` | Archivos, formularios y multipart |
| 05 | `week-05-ssl_tls_cookies_redirects` | SSL/TLS, cookies y redirects |
| 06 | `week-06-output_debug_configuracion` | Output, debug y configuración |
| 07 | `week-07-scripting_bash_con_curl` | Scripting bash con curl |
| 08 | `week-08-oauth2_y_autenticacion_avanzada` | OAuth2 y autenticación avanzada |
| 09 | `week-09-http2_paralelismo_performance` | HTTP/2, paralelismo y rendimiento |
| 10 | `week-10-proyecto_final` | Proyecto final |

> **Esta tabla vive en tres archivos**: aquí, en `README.md` y en `README_EN.md`.
> Si cambia una, cambian las tres. El agente `curriculo-coherencia-reviewer`
> existe para comprobarlo.

---

## 🗂️ Estructura de Carpetas

```
bc-curl/
├── README.md                  # Contrato con el alumno
├── README_EN.md               # Único espejo en inglés
├── CLAUDE.md                  # Índice para el agente; delega en este archivo
├── CONTRIBUTING.md · CODE_OF_CONDUCT.md · SECURITY.md · LICENSE
├── docker-compose.yml · .env.example   # El laboratorio
├── assets/bootcamp-header.svg          # Solo recursos visuales globales
├── docs/                      # Documentación transversal a las diez semanas
├── scripts/                   # start/stop del laboratorio y verificación
├── .github/                   # Esta guía, los prompts y el workflow
├── .claude/                   # Agentes de revisión y skills
└── bootcamp/week-NN-tema/     # El contenido
```

Regla de reparto: si algo aplica a **todas** las semanas va en `docs/`; si aplica
a una, va dentro de su semana. Los SVG globales van en `assets/`; los de una
semana, en el `0-assets/` de esa semana. Nunca al revés.

---

## 🎓 Componentes de Cada Semana

```
week-XX-tema_principal/
├── README.md
├── rubrica-evaluacion.md
├── checks.json
├── 0-assets/
├── 1-teoria/
├── 2-practicas/
├── 3-proyecto/
│   ├── README.md
│   └── starter/            ← el único sitio donde vive código de partida
├── 4-recursos/{ebooks-free,videografia,webgrafia}/README.md
└── 5-glosario/README.md
```

### 1-teoria/

**El número de archivos es libre: los que pida el temario, no un cupo fijo.**
Siete u ocho es lo normal. Antes eran cinco y eso comprimía el contenido.
**Nunca se sacrifica profundidad para que quepa.**

- **Extensión por archivo**: ~250 líneas, rango sano 200-300. Si un archivo se
  sale, casi siempre es porque mezcla dos temas: divídelo en dos, no recortes.
- **Un archivo, un concepto.** Si el título necesita una "y", sospecha.
- **Orden fijo dentro del archivo**: qué problema resuelve → cómo funciona →
  cómo se usa → antipatrones → trucos.
- **Todo ejemplo se puede ejecutar contra el laboratorio local.** Si un ejemplo
  necesita internet, dilo.
- **Marca la versión mínima** de todo flag que no sea universal. Ver
  [`docs/versiones-de-curl.md`](../docs/versiones-de-curl.md).
- Diagramas en SVG, nunca arte ASCII.

Nomenclatura: `NN-tema-en-kebab-case.md`, numerados desde `01`.

### 2-practicas/

Cuatro archivos planos, **200-380 líneas** cada uno. Nada de carpeta por
ejercicio: `NN-titulo-en-kebab-case.md` y punto. El `starter/` vive en
`3-proyecto/`, que es donde el entregable es código.

> El rango es más ancho que el de la teoría a propósito: cada paso lleva tres
> bloques (Por qué, Comando, Verifica) y ocho o nueve pasos suman rápido. Si una
> práctica se pasa de 380, no la recortes: mira si son dos prácticas.

Formato canónico de un paso:

````markdown
## Paso 3: Distinguir un fallo de red de un fallo HTTP

**Por qué**: curl sale con código 0 cuando el servidor responde 500. Para curl
la transferencia fue un éxito: pidió, le contestaron. Si el script no distingue
"no pude hablar con el servidor" de "el servidor me dijo que no", tratará un
despliegue fallido como un despliegue correcto.

**Comando**:

```bash
# --fail-with-body sale con 22 ante 4xx/5xx y ademas conserva el cuerpo del
# error, que es donde la API explica que fue mal. --fail a secas lo descarta.
curl --fail-with-body --max-time 10 -s http://localhost:8080/status/503
echo "codigo de salida: $?"
```

**Verifica**:

```bash
curl --fail-with-body -s http://localhost:8080/status/503 >/dev/null; echo $?
# 22
curl -s http://localhost:8080/status/503 >/dev/null; echo $?
# 0   ← el mismo 503, sin --fail, pasa por bueno
```
````

Reglas:

- **Todo paso termina en una verificación ejecutable.** Sin excepción.
- **Toda salida esperada va comentada debajo del comando.** El alumno tiene que
  poder comparar sin ejecutar.
- **Advertencia antes de lo destructivo**, con el comando de respaldo delante.
- Cierra con `## ✅ Resultado` (casillas + el comando de `verificar-semana.sh`) y
  `## 🧯 Si algo sale mal` (tabla Síntoma | Causa | Solución).
- ❌ **No uses `# TODO:` en prácticas.** El `TODO` es formato de proyecto.

### 3-proyecto/README.md

La capa que esta semana añade a `api-toolkit`. Ocho secciones:

1. `## 🎯 Objetivo`
2. `## 📦 Qué añade esta capa` — cómo encaja con la semana anterior y qué desbloquea en la siguiente
3. `## ✅ Requisitos verificables` — **copia literal de las descripciones de `checks.json`**. Si no coinciden palabra por palabra, el alumno no sabe qué le falta cuando una comprobación falla
4. `## 🎨 Criterios de calidad` — lo que el autograding no ve
5. `## 💡 Adaptación a tu dominio` — tabla con 3-4 dominios
6. `## 🚦 Cómo entregarlo`
7. `## 🧯 Errores comunes`
8. `## 🔗 Navegación`

### 3-proyecto/starter/

El punto de partida, **nunca la solución**. Obligatorio en todos:

- `#!/usr/bin/env bash` y `set -euo pipefail`
- Bit de ejecución (`chmod +x`)
- Cabecera de comentario con el uso y los subcomandos
- **`# TODO:` en cada hueco que el alumno tiene que rellenar**, numerados y con
  una frase de qué se espera
- `shellcheck` limpio sobre el esqueleto tal como se entrega

### 4-recursos/

Tres subcarpetas: `ebooks-free/`, `videografia/`, `webgrafia/`. **Cada recurso
lleva una línea de por qué vale la pena**, no solo el enlace. Los enlaces se
comprueban y se fecha la comprobación.

### 5-glosario/

A-Z en español, con el término real en inglés entre paréntesis cuando lo haya, y
**la versión de curl** si es un flag que no es universal. Enlaza al glosario
global.

### checks.json

Contrato completo en [`docs/autograding.md`](../docs/autograding.md). Lo esencial:

- Se escribe **antes** que el contenido: define qué es entregable y por tanto
  qué tienen que enseñar las prácticas.
- Entre 6 y 18 comprobaciones, creciendo con la complejidad de la semana.
- Cada `descripcion` se copia literal al proyecto; cada `pista` apunta a
  archivo + paso.
- Una comprobación, un hecho.
- **Cero lógica bash por semana en `verificar-semana.sh`.** Si una comprobación
  necesita código imperativo, el entregable no es verificable y va a rúbrica
  manual.

---

## 🎩 Sección de Trucos

**Obligatoria en el README de cada semana.** Es lo que no viene en el manpage, o
viene enterrado en la línea 4.000.

Criterio de admisión:

- ✅ Un flag poco conocido que ahorra tiempo de verdad (`--write-out '%{json}'`)
- ✅ Una forma de ver algo que la salida normal no enseña
- ❌ Repetir lo que ya dice la teoría de esa semana
- ❌ Trivialidades ("puedes usar `-o` para guardar en un archivo")

Todo truco se replica en `docs/trucos-curl.md`, en la sección de su semana. El
skill `sincronizar-trucos` mantiene los dos lados de acuerdo; si difieren, gana
el README de la semana.

---

## 📝 Convenciones

### Comandos

✅ **BIEN** — el porqué, el comando, y qué esperar:

```bash
# %{http_code} es la variable de --write-out con el codigo de estado. El \n
# final hace falta: curl no lo anade.
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/status/418
# 418
```

❌ **MAL** — comando desnudo, sin motivo ni salida esperada:

```bash
curl -w "%{http_code}" http://localhost:8080/get
```

### Scripts bash

✅ **BIEN**:

```bash
#!/usr/bin/env bash
set -euo pipefail

# --fail-with-body: sale distinto de 0 ante 4xx/5xx y conserva el cuerpo.
# --max-time: sin el, un servidor colgado cuelga el cron.
# --retry: solo reintenta errores transitorios, no un 404.
respuesta=$(curl --fail-with-body --max-time 30 --retry 3 --retry-delay 2 \
  -sS -H "Authorization: Bearer ${API_TOKEN}" \
  "${BASE_URL}/v1/deploy")
```

❌ **MAL** — sin `--fail` el 500 pasa por bueno, sin `--max-time` el script no
termina nunca, y el token es visible en `ps`:

```bash
curl -s -H "Authorization: Bearer sk_live_abc123" $BASE_URL/v1/deploy
```

### Nomenclatura

| Elemento | Formato | Ejemplo |
|---|---|---|
| Carpeta de semana | `week-XX-tema_en_snake_case` | `week-07-scripting_bash_con_curl` |
| Archivo de teoría | `NN-tema-en-kebab-case.md` | `03-manejo-de-errores.md` |
| Archivo de práctica | `NN-titulo-en-kebab-case.md` | `02-paginar-con-el-header-link.md` |
| SVG | `NN-nombre-descriptivo.svg` | `01-anatomia-de-una-peticion.svg` |
| Script de starter | `nombre-en-kebab-case.sh` | `api-explorer.sh` |
| Función bash | inglés, `snake_case` | `fetch_page` |
| Variable de entorno | `UPPER_SNAKE_CASE` | `API_TOKEN` |

**Inglés para código, identificadores, funciones, variables y mensajes de
commit. Español para documentación y comentarios educativos.**

Los slugs de carpeta y de archivo van **sin tildes y sin ñ**. Los títulos dentro
del markdown **sí llevan tildes**: es prosa en español.

### Placeholders

| Placeholder | Uso |
|---|---|
| `<tu-dominio>` | El dominio que eligió el alumno |
| `http://localhost:8080` | El httpbin del laboratorio, siempre este puerto |
| `https://localhost:8443` | El endpoint TLS del laboratorio |
| `http://localhost:8081` | El servidor OAuth2 del laboratorio |
| `https://api.ejemplo.com` | API genérica ficticia en los ejemplos de prosa |
| `<TOKEN>` / `$API_TOKEN` | Cualquier credencial |

Nunca uses la API real de un tercero como destino de un ejemplo destructivo.

---

## 🔐 Reglas de Seguridad del Contenido

Este bootcamp enseña a manejar credenciales. El material tiene que predicar con
el ejemplo.

1. **Nunca un token con formato válido**, ni real ni inventado. `ghp_` o
   `sk_live_` seguidos de caracteres disparan los detectores de secretos. Usa
   `<TOKEN>` o `$API_TOKEN`.
2. **Ningún secreto en la línea de comandos.** Es visible en `ps`, en
   `~/.bash_history` y en los logs de CI. Variable de entorno, `--netrc`, o un
   archivo de headers con `-H @archivo`.
3. **`-k` / `--insecure` solo en la sección de antipatrones.** Si el certificado
   no valida, la respuesta es `--cacert`, no apagar la verificación. Un ejemplo
   que usa `-k` "para que funcione" enseña exactamente lo contrario del bootcamp.
4. **Nada de `curl | bash`** sin advertirlo explícitamente y sin enseñar la
   alternativa de descargar, leer y ejecutar.
5. **Todo ejemplo de producción lleva `--fail-with-body`, `--max-time` y
   `--retry`.** El ejemplo sin ellos solo existe como contraste marcado.
6. **Los comandos destructivos van precedidos de su respaldo.** `docker compose
   down -v`, `rm -rf`, un `DELETE` contra una API real: los tres necesitan aviso.
7. **`~/.bc-curl` nunca dentro del repositorio**, y siempre con `chmod 600`.
8. **Los certificados del laboratorio no se comitean.** Se generan y se exportan.

---

## 🎨 Recursos Visuales

- **SVG siempre. Arte ASCII prohibido.** Un diagrama de cajas dibujado con
  guiones se rompe en cuanto cambia la fuente.
- Tema oscuro, sin degradados, tipografía sans-serif.
- Paleta (la que ya usan los SVG existentes, base GitHub dark con acento naranja):

  | Color | Hex | Uso |
  |---|---|---|
  | Lienzo | `#0d1117` | Fondo |
  | Superficie | `#161b22` | Cajas y paneles |
  | Borde | `#30363d` | Líneas y separadores |
  | Texto principal | `#f0f6fc` | Etiquetas |
  | Texto secundario | `#8b949e` | Anotaciones |
  | Naranja curl | `#f0883e` | Elemento principal, la petición |
  | Azul | `#58a6ff` / `#79c0ff` | Enlaces, la respuesta |
  | Verde | `#3fb950` | Éxito, 2xx |
  | Amarillo | `#e3b341` | Aviso, 3xx |
  | Rojo | `#f85149` | Error, 4xx/5xx |
  | Morado | `#d2a8ff` | Secundario, metadatos |

- `viewBox` obligatorio, más `role="img"` y un `<title>` descriptivo.
- Nombrados en orden de lectura: `01-`, `02-`…
- **Todo SVG tiene que estar enlazado desde algún `.md`.**
  `verificar-enlaces.sh` falla si hay huérfanos.
- Se enlaza con `![Descripción](../0-assets/NN-nombre.svg)` y el texto
  alternativo describe el diagrama, no repite el título.

---

## 📖 Documentación

### Las 10 secciones del README de semana, en orden

1. `# Semana NN — Tema`
2. Blockquote de gancho, 2 líneas
3. `## 🎯 Objetivos de la Semana` — bullets "serás capaz de"
4. `## 📋 Prerrequisitos` — encadenados a semanas anteriores, concretos:
   "Semana 06 completada: `.curlrc` con `--fail-with-body` y `--max-time 30`"
5. `## 🗂️ Estructura de la Semana` — árbol comentado
6. `## 📝 Contenidos` — tabla de teoría (Archivo | Tema | Duración) y tabla de
   prácticas (Práctica | Qué haces | Duración), más un párrafo de proyecto
7. `## ⏱️ Distribución del Tiempo (8 horas)` — **la tabla suma 8 h exactas**
8. `## 🎩 Trucos y atajos`
9. `## 📌 Entregables` — numerados
10. `## ✅ Verificación` — el comando de `verificar-semana.sh`
11. `## 🔗 Navegación` — tabla Anterior | Actual | Siguiente + volver al inicio

Entre la 7 y la 8 cabe **una** sección temática propia de la semana si el tema
lo pide.

### Plantilla de archivo de teoría

````markdown
# Título del concepto

> Una línea que sitúa el concepto y por qué importa.

![Descripción del diagrama](../0-assets/NN-nombre.svg)

## 🎯 Objetivos

- Lo que sabrás hacer al terminar este archivo

## 1. Qué problema resuelve

Antes de la solución, el problema. Con un caso concreto y con lo que pasa si no
lo resuelves.

## 2. Cómo funciona

### 2.1 Subtema

Tablas para comparar opciones. Bloques ✅/❌ para contrastar.

## 3. Cómo se usa

Comandos ejecutables contra el laboratorio, con la salida esperada comentada.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|

## 5. Trucos

## 📚 Recursos Adicionales

## ✅ Checklist de Verificación

- [ ] Casillas ejecutables contra el laboratorio
````

---

## 📊 Evaluación

| Evidencia | Peso | Instrumento |
|---|:--:|---|
| 🧠 Conocimiento | 30% | 10 preguntas conceptuales, respuestas en `<details>` |
| 💪 Desempeño | 40% | Las 4 prácticas, verificadas por `checks.json` |
| 📦 Producto | 30% | 60 pts verificables por el autograding + 40 pts de rúbrica manual |

**Mínimo 70% en cada evidencia**, no en el promedio.

### Estructura de `rubrica-evaluacion.md`

1. `## 📊 Distribución de Evidencias` — tabla + nota mínima
2. `## 🧠 Conocimiento (30%)` — tabla `# | Pregunta` con 10 preguntas
   **conceptuales, no de memoria**, seguida de
   `<details><summary><strong>Respuestas</strong></summary>` con 10 respuestas
   de párrafo argumentado
3. `## 💪 Desempeño (40%)` — tabla Práctica | Criterio | Puntos (10 c/u)
4. `## 📦 Producto (30%)` — **dos tablas**: "Verificable por el autograding — 60
   puntos" y "Calidad — 40 puntos"
5. `### Penalizaciones` — tabla Situación | Deducción, graduada y con señal moral
   clara. `-k` en la entrega y un token comiteado son penalizaciones graves
6. Cierre con enlace de vuelta

Una buena pregunta contrasta dos cosas y pide el porqué: *"¿Por qué `curl -s`
sale con código 0 ante un 500, y qué diferencia hay entre `--fail` y
`--fail-with-body` cuando la API devuelve el motivo del error en el cuerpo?"*.
Una mala pregunta pide recordar un flag.

---

## 🤖 Instrucciones para el agente

### Límites de respuesta

- **Una semana por tanda**, usando la última semana publicada como plantilla de
  calidad.
- Dentro de la semana, divide por carpetas: primero `checks.json`, luego README,
  luego teoría, luego prácticas, luego proyecto, luego rúbrica, luego recursos y
  glosario.

### Reglas de generación

1. **Profundidad sobre cobertura.** Es preferible explicar bien cinco variables
   de `--write-out` que listar las cuarenta. El bootcamp existe porque los
   tutoriales superficiales sobran.
2. **Siempre el porqué.** Un comando sin motivo es una receta.
3. **Verificable.** Si un entregable no se puede comprobar, no es obligatorio:
   va a rúbrica manual.
4. **No inventar.** Flags, opciones largas, variables de `--write-out`, códigos
   de salida: si dudas, ejecútalo o comprueba el
   [manpage](https://curl.se/docs/manpage.html). **Es el fallo más probable en
   este repositorio**: una opción plausible pero inexistente pasa la revisión y
   revienta cuando el alumno la ejecuta. Usa el skill `verificar-flags-curl`.
5. **Marca la versión.** Todo flag posterior a 7.81 lleva su versión mínima y su
   alternativa. Ubuntu 22.04 trae 7.81 y es lo que muchos alumnos tendrán.
6. **Fechar lo volátil.** Las APIs públicas que se citen llevan fecha de
   comprobación.

### Estado de la herramienta

curl publica una versión cada ocho semanas y casi nunca rompe compatibilidad
hacia atrás, pero **añade** constantemente. El riesgo aquí no es que un flag
desaparezca: es escribir un flag que todavía no existía en la versión del
alumno. Antes de usar algo reciente, comprueba en
[`docs/versiones-de-curl.md`](../docs/versiones-de-curl.md) y en el
[changelog](https://curl.se/changes.html).

---

## 📚 Referencias Oficiales

- [curl — manpage](https://curl.se/docs/manpage.html)
- [everything.curl.dev](https://everything.curl.dev/) — el libro oficial
- [Changelog de curl](https://curl.se/changes.html)
- [Códigos de salida de curl](https://curl.se/libcurl/c/libcurl-errors.html)
- [Variables de `--write-out`](https://curl.se/docs/manpage.html#-w)
- [Vulnerabilidades de curl](https://curl.se/docs/vulnerabilities.html)
- [RFC 9110 — HTTP Semantics](https://datatracker.ietf.org/doc/html/rfc9110)
- [RFC 9112 — HTTP/1.1](https://datatracker.ietf.org/doc/html/rfc9112)
- [RFC 9113 — HTTP/2](https://datatracker.ietf.org/doc/html/rfc9113)
- [RFC 9114 — HTTP/3](https://datatracker.ietf.org/doc/html/rfc9114)
- [RFC 6749 — OAuth 2.0](https://datatracker.ietf.org/doc/html/rfc6749)
- [RFC 7636 — PKCE](https://datatracker.ietf.org/doc/html/rfc7636)
- [Manual de jq](https://jqlang.github.io/jq/manual/)
- [ShellCheck](https://www.shellcheck.net/)

---

## ✅ Checklist para Nuevas Semanas

- [ ] `checks.json` escrito **primero**, con 6-18 comprobaciones y sus pistas
- [ ] Cada comprobación del `checks.json` ejecutada a mano contra el laboratorio
- [ ] `README.md` con las 10 secciones en orden
- [ ] La tabla de tiempos suma **8 h exactas**
- [ ] 7-8 archivos de teoría, 200-300 líneas cada uno, un concepto por archivo
- [ ] 4 prácticas planas (200-380 líneas), cada paso con Por qué / Comando / Verifica
- [ ] Cada práctica cierra con `## ✅ Resultado` y `## 🧯 Si algo sale mal`
- [ ] Toda salida esperada aparece comentada bajo su comando
- [ ] `3-proyecto/README.md` con los requisitos copiados literalmente del `checks.json`
- [ ] `starter/*.sh` con shebang `env bash`, `set -euo pipefail`, bit de ejecución, `TODO`s y `shellcheck` limpio
- [ ] `rubrica-evaluacion.md` con 10 preguntas, respuestas argumentadas y penalizaciones
- [ ] Sección de trucos en el README, replicada en `docs/trucos-curl.md`
- [ ] Glosario A-Z con la versión mínima de cada flag no universal
- [ ] Recursos con la línea de "por qué vale la pena" y la fecha de comprobación
- [ ] SVG en `0-assets/`, todos enlazados, ninguno con arte ASCII
- [ ] Ningún `-k` fuera de la sección de antipatrones
- [ ] Ningún secreto en la línea de comandos de ningún ejemplo
- [ ] Prerrequisitos encadenados a semanas anteriores, concretos
- [ ] Navegación anterior/siguiente correcta
- [ ] Las tres tablas maestras siguen coincidiendo
- [ ] `bash scripts/verificar-enlaces.sh` en verde
- [ ] Los dos agentes de revisión pasados

---

## 💡 Notas Finales

- **Profundidad sobre cobertura.** Siempre.
- **Nunca comprimir para que quepa.** Si no cabe, se divide.
- **Lo que no se puede verificar no es obligatorio.**
- **Si dudas de un flag, ejecútalo. No lo escribas "porque suena bien".**

_Última actualización: agosto de 2026 · Versión 2.0 (refactor de profundización)_
