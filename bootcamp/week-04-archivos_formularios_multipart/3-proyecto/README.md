# Proyecto — Capa 4: las transferencias

> `api-toolkit.sh` aprende a mover archivos. Y aprende a hacerlo de forma que
> el nombre del archivo signifique algo: si existe, está entero y es el que
> pediste.

---

## 🎯 Objetivo

Añadir a `api-toolkit.sh` dos subcomandos: `download`, que descarga a
`DESTINO.part` y solo renombra cuando el archivo está completo y verificado,
con `--resume` para continuar una descarga cortada y `--sha256` para rechazar
lo que no es lo pedido; y `upload`, que sube un archivo como
`multipart/form-data` sin escribir a mano ni el boundary ni el `Content-Type`.

---

## 📦 Qué añade esta capa

La Semana 03 dejó los cuatro verbos autenticados, con la credencial fuera de
la línea de comandos. Esta capa reutiliza todo eso — el `--config` con el
secreto sirve igual para descargar que para subir — y añade lo que hace falta
para que el cuerpo sea un archivo.

| Viene de la Semana 03 | Lo añade esta capa |
|---|---|
| `get`, `post`, `put`, `delete` con JSON | `download` y `upload` con archivos |
| La credencial en un `--config` temporal | La misma, en las descargas y subidas |
| `--dry-run` con la credencial redactada | `--dry-run` también para `download` y `upload` |
| Códigos 0, 1 y 77 | El **75** (`EX_TEMPFAIL`): descarga cortada, repite con `--resume` |
| `--max-time 10` para todo | Límites de descarga: techo de 600 s y velocidad mínima |

Lo que desbloquea: la Semana 05 apunta el toolkit a `https://` con la CA del
laboratorio, y las descargas son lo primero que se nota cuando la cadena de
certificados falla. La Semana 07 añade reintentos con backoff, que sobre un
`download` reanudable salen casi gratis.

---

## ✅ Requisitos verificables

Estos son los enunciados exactos de `checks.json`. Si uno falla,
`./scripts/verificar-semana.sh 04` te dice cuál y con qué pista.

1. El laboratorio sirve rangos de bytes en /range
2. api-toolkit.sh existe, es ejecutable y arranca con set -euo pipefail
3. No quedan marcadores TODO sin resolver en el script
4. La capa 3 sigue funcionando: con AUTH_MODE=bearer el get autentica
5. download guarda el archivo entero en el destino indicado
6. Un download que recibe un 404 sale con 1
7. Un download fallido no deja ningun archivo en el destino
8. Mientras descarga, el archivo se escribe en DESTINO.part y no en DESTINO
9. Con --resume continua el DESTINO.part existente en vez de empezar de cero
10. --resume sobre una descarga ya completa sale con 0 y deja el archivo en su sitio
11. Con --sha256 y el hash correcto, download sale con 0
12. Con un --sha256 que no coincide, download falla y no deja el archivo
13. upload envia el archivo como multipart/form-data
14. El archivo viaja en el campo que dice UPLOAD_FIELD
15. upload de un archivo que no existe sale con 1 sin llegar a llamar a curl
16. El script no escribe a mano el Content-Type multipart: el boundary lo pone curl
17. El script no desactiva la verificacion del certificado con -k
18. El script pasa shellcheck sin avisos

---

## 🎨 Criterios de calidad

Lo que el autograding no ve y la rúbrica sí:

- **El `.part` vive junto al destino**, no en `/tmp`. Si no, el `mv` final deja
  de ser atómico (teoría 02 §3.3).
- **El cuerpo de una descarga no pasa por bash.** Va directo de curl al
  `.part` con `--output`. Meter un binario en una variable de bash lo corrompe:
  bash no guarda bytes nulos.
- **`--fail` en `download`, no `--fail-with-body`.** El cuerpo del error no
  puede acabar en el `.part` (teoría 01 §3.3).
- **Un corte de red conserva el `.part`; un error HTTP lo borra.** El primero
  se puede continuar; el segundo no tiene nada que continuar.
- **Los mensajes de progreso y de error van a stderr.** El `upload` imprime la
  respuesta de la API en stdout para que se pueda encadenar con `jq`.
- **`--resume` y `--sha256` se rechazan fuera de `download`**, con un mensaje
  que diga por qué, en vez de ignorarse en silencio.
- **El nombre del archivo en `-F` va entre comillas** dentro del valor, para
  que un `;` en el nombre no lo rompa (teoría 06 §3.3).

---

## 💡 Adaptación a tu dominio

El laboratorio sirve archivos sintéticos. Tu API servirá lo que sirva:

| Dominio | Qué descargar | Qué subir | Formato de subida |
|---|---|---|---|
| Código | Un *release asset* de GitHub (`/repos/{o}/{r}/releases/assets/{id}` con `Accept: application/octet-stream`) | Un asset a un release (`uploads.github.com`) | **Crudo** con `Content-Type`: el `upload` multipart no sirve; es un buen ejercicio extra |
| Clima | Un CSV histórico de Open-Meteo | — | — |
| Documentos | Un PDF de un gestor documental | Un adjunto | Multipart, lo más habitual |
| Imágenes | Una imagen original | Una imagen a un servicio de procesamiento | Multipart con metadatos en otras partes |

Antes de programar nada contra tu API, con lo de la práctica 01:

```bash
# ¿Acepta rangos? Sin esto, --resume no va a funcionar con tu API.
curl -sI "https://api.de-tu-dominio.com/ruta/al/archivo" | grep -i '^accept-ranges'
# ¿Publica hashes? Busca un SHA256SUMS o un campo "sha256"/"digest" en su JSON.
```

---

## 🚦 Cómo entregarlo

**1.** Copia el starter. Trae la capa 3 resuelta, así que puedes partir de él
aunque tu versión de la Semana 03 sea distinta:

```bash
cd bootcamp/week-04-archivos_formularios_multipart/3-proyecto/starter/
# Guarda antes tu version de la Semana 03: el cp de abajo la sobrescribe.
cp ~/api-toolkit.sh ~/api-toolkit.semana03.sh 2>/dev/null || true
cp api-toolkit.sh ~/api-toolkit.sh
chmod +x ~/api-toolkit.sh
```

**2.** Rellena los seis `TODO` numerados:

| TODO | Qué resuelve | Dónde está explicado |
|:--:|---|---|
| 1 | La parte `-F` del `upload`, con el nombre entre comillas | [Teoría 06 §3.3](../1-teoria/06-multipart-por-dentro.md), práctica 03 paso 8 |
| 2 | `--fail`, `--output` al `.part` y `--continue-at -` en el `download` | [Teoría 02 §3.1](../1-teoria/02-rangos-y-descargas-reanudables.md), práctica 01 paso 6 |
| 3 | El `416` con `--resume`: completo si el tamaño coincide con el remoto, borrar si no | [Teoría 02 §3.2](../1-teoria/02-rangos-y-descargas-reanudables.md), práctica 01 paso 7 |
| 4 | Borrar el `.part` ante un error HTTP | [Teoría 01 §3.4](../1-teoria/01-descargar-un-archivo.md), práctica 01 paso 4 |
| 5 | Comparar el SHA-256 y borrar si no coincide | [Teoría 03 §3.3](../1-teoria/03-verificar-lo-descargado.md), práctica 02 paso 6 |
| 6 | El `mv` del `.part` al destino | [Teoría 02 §3.3](../1-teoria/02-rangos-y-descargas-reanudables.md), práctica 01 paso 9 |

**3.** Prueba a mano los cuatro caminos de `download` y el de `upload`:

```bash
./api-toolkit.sh download /range/1000 datos.bin; echo "$?"
# datos.bin
# 0
./api-toolkit.sh download /status/404 nada.bin; echo "$?"; ls nada.bin*
# curl: (22) The requested URL returned error: 404
# error: la API respondio 404
# 1
# ls: cannot access 'nada.bin*': No such file or directory

# Un corte simulado: un .part con la primera mitad, y --resume la completa.
curl -s -r 0-499 -o mitad.bin.part http://localhost:8080/range/1000
./api-toolkit.sh --resume download /range/1000 mitad.bin; echo "$?"
# mitad.bin                   ← por stderr: el archivo listo
# 0
curl -s http://localhost:8080/range/1000 | cmp - mitad.bin && echo identico
# identico

# Otra vez: ya no falta nada. El 416 no es un error.
cp mitad.bin mitad.bin.part
./api-toolkit.sh --resume download /range/1000 mitad.bin; echo "$?"
# curl: (22) The requested URL returned error: 416   ← lo dice curl, con -sS
# aviso: mitad.bin.part ya estaba completo (416)
# mitad.bin
# 0

./api-toolkit.sh --sha256 2ac123dcd759eebabfa1b17c0332b88b3815ef3f95fbfcceb5fac07e233235bd \
  download /range/100 cien.bin; echo "$?"
# 0

echo hola > nota.txt
./api-toolkit.sh upload /post nota.txt | jq -c .files
# {"file":["hola\n"]}
```

**4.** Comprueba que `--dry-run` sigue sin filtrar la credencial:

```bash
AUTH_MODE=bearer API_TOKEN=zzsecretozz ./api-toolkit.sh --dry-run download /range/10 x.bin
# curl --max-time 600 --speed-limit 1024 --speed-time 30 --silent --show-error --fail --output x.bin.part --write-out %\{http_code\} --config /tmp/api-toolkit.PQZQ77 http://localhost:8080/range/10
# # AUTH_MODE=bearer, credencial: <REDACTADO>
```

**5.** Pasa el autograding y `shellcheck`:

```bash
./scripts/verificar-semana.sh 04
shellcheck -S warning ~/api-toolkit.sh
```

---

## 🧯 Errores comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `download` deja `datos.bin` de 0 bytes tras un 404 | Falta `--fail` en el TODO 2 | Añádelo: sin él curl escribe el cuerpo del error |
| El check del `.part` falla aunque el archivo acaba bien | `--output` apunta a `$destino` y no a `$parte` | El cuerpo va siempre al `.part` |
| `--resume` vuelve a bajar todo | Falta `--continue-at -`, o el `.part` no está en la ruta que mide curl | `--continue-at -` con `--output "$parte"` |
| `--resume` sobre un archivo completo sale con 1 | El 416 cae en el bloque de errores | El TODO 3 va **antes** del bloque de error |
| `--sha256` correcto falla siempre | Comparas con el hash en mayúsculas, o con el nombre del archivo pegado | `sha256_de` devuelve solo el hash en minúsculas; `main` ya pasa `--sha256` a minúsculas |
| `upload` sale con 26 con un archivo que existe | Ruta relativa y el script se ejecutó desde otro directorio | Pasa rutas absolutas, o ejecútalo desde donde está el archivo |
| El servidor responde 400 a `upload` | Añadiste `--header 'Content-Type: multipart/...'` | Quítalo: `-F` lo genera con su boundary |
| `shellcheck` avisa de `SC2086` en el `-F` | Faltan comillas alrededor de `"${UPLOAD_FIELD}=@\"${archivo}\""` | Comillas dobles fuera, escapadas dentro |

---

## 🔗 Navegación

| Anterior | Siguiente |
|---|---|
| [Práctica 04 — Subir en crudo y elegir](../2-practicas/04-subir-en-crudo-y-elegir.md) | [Rúbrica de evaluación](../rubrica-evaluacion.md) |

[← Volver a la Semana 04](../README.md)
