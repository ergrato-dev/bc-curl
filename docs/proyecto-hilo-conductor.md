# El proyecto hilo conductor: `api-toolkit`

No hay un script desechable por semana. Hay **uno solo que crece diez semanas** y
que al final es una herramienta que instalarías en tu `PATH`.

Se llama `api-toolkit`. Cada semana le añade una capa, y cada capa se apoya en la
anterior.

---

## 1. Elige tu dominio

El bootcamp no te da la API contra la que trabajar: la eliges tú, la primera
semana, y no la cambias.

Requisitos: que sea una **API REST pública con documentación**, que tenga al
menos un endpoint autenticado, y que te interese lo suficiente para aguantarla
diez semanas.

| Dominio | API | Por qué funciona bien |
|---|---|---|
| Código | [GitHub REST](https://docs.github.com/rest) | Paginación por header `Link`, rate limit real, tokens con scopes |
| Clima | [Open-Meteo](https://open-meteo.com/en/docs) | Sin autenticación, respuestas grandes, ideal para `jq` |
| Transporte | [Transport for London](https://api.tfl.gov.uk/) | API key sencilla, datos que cambian |
| Cultura | [The Movie Database](https://developer.themoviedb.org/docs) | API key, paginación clásica, imágenes para practicar descargas |

Si tienes una API de tu trabajo o de un proyecto propio, mejor todavía. Las
únicas condiciones: que puedas hablar con ella desde tu máquina, y que no
lamentes un `DELETE` mal escrito.

> [!IMPORTANT]
> Elige un dominio **distinto** al de tus compañeros si estás haciendo el
> bootcamp en grupo. Copiar el script de otro deja de ser una opción y eso te
> hace un favor.

Lo escribes en la Semana 01 y no se vuelve a discutir:

```bash
echo "DOMINIO=github" >> ~/.bc-curl
chmod 600 ~/.bc-curl
```

`~/.bc-curl` vive en tu `$HOME`, **nunca dentro del repositorio**, y con permisos
600 porque acabará teniendo credenciales.

---

## 2. Qué es `api-toolkit` al final

Un CLI en bash, un solo archivo ejecutable, sin dependencias más allá de curl y
jq:

```
api-toolkit <subcomando> [argumentos]

  init                         Configuracion interactiva
  auth login|logout|status     Gestion de sesion OAuth2
  get ENDPOINT [--output F]    GET
  post ENDPOINT DATA           POST
  put ENDPOINT DATA            PUT
  delete ENDPOINT              DELETE
  fetch-all ENDPOINT           Recorre todas las paginas
  download URL [--resume]      Descarga reanudable
  monitor URLS_FILE            Monitoriza endpoints
  bench URL [N]                Benchmark de N peticiones

Flags globales:
  --dry-run                    Imprime lo que haria, sin hacerlo
  --verbose                    Traza la peticion
  --help
```

---

## 3. Qué capa añade cada semana

| Semana | Capa | Qué sabe hacer al terminar |
|:--:|---|---|
| 01 | **Explorador** | Consulta endpoints, muestra código de estado y tiempo de respuesta |
| 02 | **Verbos** | `get`, `post`, `put`, `delete` con cuerpo JSON y headers correctos |
| 03 | **Credenciales** | Lee el token del entorno o de `~/.bc-curl`. Nunca en la línea de comandos |
| 04 | **Transferencias** | `download` con reanudación, subida de archivos y multipart |
| 05 | **Red hostil** | CA propia, mTLS, cookies persistentes, redirects, timeouts y reintentos |
| 06 | **Observable** | `--verbose` con credenciales tachadas, `--timing` y métricas JSON con `--write-out`, ignora el `~/.curlrc`, User-Agent propio |
| 07 | **Robusto** | Falla cuando debe fallar: errores por stderr, 429/502/503/504 salen con 75 y `Retry-After`, un solo cuerpo tras reintentar, `fetch-all` con paginación por `Link` |
| 08 | **OAuth2** | `auth login/logout/status`, refresco automático del token caducado |
| 09 | **Rápido** | `bench` con un solo curl en paralelo (min, media, p95, max, reutilización y errores), caché por ETag con `API_CACHE_DIR`, renovación OAuth2 con cerrojo entre procesos |
| 10 | **Entregable** | Configuración en `~/.bc-curl` con el entorno por encima, `init` con 600 y sin pisar, `--version`, `install.sh`, tests con `bats` y CI con curl 7.81 y 8.5 |

Cada capa se apoya en la anterior. La Semana 08 no puede refrescar un token si
la 03 no dejó dónde guardarlo; la 09 no puede medir si la 06 no instrumentó.

---

## 4. Reglas del proyecto

1. **Un solo archivo.** `api-toolkit.sh`. Pasa de las 1400 líneas y sigue
   siendo uno: se instala copiando un archivo. La Semana 10 (teoría 01) explica
   cuándo compensaría partirlo.
2. **Sin dependencias más allá de curl, jq y bash.** Si algo necesita Python,
   es que estás resolviendo el problema equivocado para este bootcamp.
3. **`set -euo pipefail` desde la primera línea de la primera semana.**
4. **Ningún secreto en el repositorio.** Ni en el código, ni en un `.env`
   comiteado, ni en un comentario.
5. **`shellcheck -S warning` limpio** antes de cada entrega.
6. **`--dry-run` funciona desde la Semana 02.** Es lo que te deja probar un
   `delete` sin borrar nada.

---

## 5. Cómo empezarlo (Semana 01)

El `starter/` de cada semana trae el esqueleto con `TODO`s. La Semana 01 arranca
así:

```bash
cd bootcamp/week-01-http_y_curl_basico/3-proyecto/starter/
cp api-explorer.sh ~/api-toolkit.sh   # tu copia, fuera del repositorio
chmod +x ~/api-toolkit.sh
```

Tu copia vive **fuera** de este repositorio, en tu propio repo de trabajo. Este
repositorio es el material; tu entrega es tuya.

---

## 6. Cómo se ve al final

Semana 10, con el dominio GitHub:

```bash
$ ./install.sh
instalado: /home/ana/.local/bin/api-toolkit (api-toolkit 1.0.0)

$ BASE_URL=https://api.github.com AUTH_MODE=bearer api-toolkit init
configuracion creada en /home/ana/.bc-curl (permisos 600)
$ "$EDITOR" ~/.bc-curl          # descomenta API_TOKEN= y pega el token

$ api-toolkit fetch-all '/user/repos?per_page=100' | jq length
337

$ api-toolkit bench /rate_limit 20
20 peticiones, 4 en paralelo, HTTP/2
  min    0.089s
  media  0.134s
  p95    0.221s
  max    0.298s
  reutilizacion de conexion: 19/20
  errores: 0

$ bats tests/ | tail -1
ok 14 un archivo de configuracion legible por otros se rechaza
```

Eso no es un ejercicio. Es una herramienta.

---

[← Volver a la documentación](README.md)
