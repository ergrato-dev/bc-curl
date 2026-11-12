# Práctica 03 — Medir sin engañarse

> **Duración**: 50 min · **Entregables**: `medidas.md`

Vas a convertir una columna de tiempos en un resumen que no mienta. Primero a
mano: veinte muestras, una lenta escondida entre ellas, y cómo la media se
la traga mientras el p95 y el max la delatan. Después escribes `estadisticas`
en el toolkit (TODO 3): min, media, p95 y max, cuántas peticiones reutilizaron
la conexión, y cuántas fallaron.

**Antes de empezar**, desde la raíz del repositorio, con los TODOs 1 y 2
resueltos (prácticas 01 y 02):

```bash
./scripts/start.sh
export TK="$PWD/bootcamp/week-09-http2_paralelismo_performance/3-proyecto/starter/api-toolkit.sh"
export CA="$PWD/docs/lab-ca.pem"
mkdir -p ~/bc-curl-trabajo/semana-09/p3 && cd ~/bc-curl-trabajo/semana-09/p3
bash    # los pasos estan escritos para bash; si tu terminal es zsh, abre un bash
lista() { for ((i = 0; i < $2; i++)); do printf 'url = "%s"\noutput = "/dev/null"\n' "$1"; done; }
```

---

## Paso 1: Veinte muestras

**Por qué**: una medida es una anécdota. Veinte ya dibujan una distribución:
lo normal, lo mejor y lo peor (teoría 05, apartado 1).

**Comando**:

```bash
lista https://localhost:8443/get 20 > veinte.txt
curl --cacert "$CA" -s -K veinte.txt -w '%{time_total} %{num_connects}\n' > tiempos.txt
sort -n tiempos.txt | head -3
sort -n tiempos.txt | tail -3
```

**Verifica**:

```bash
# 0.000712 0
# 0.000731 0
# 0.000745 0
# 0.001015 0
# 0.001102 0
# 0.004556 1
```

El más lento es el que abrió la conexión (el `1`): su tiempo es casi todo
handshake. Apunta en `medidas.md` cuántas veces más lento es que la mediana.

---

## Paso 2: La media se traga la cola

**Por qué**: diecinueve peticiones rápidas y una lenta. La media describe una
petición que no existe; la mediana no se entera de la lenta; el p95 y el max
dicen la verdad, cada uno a su manera (teoría 05, apartado 2.2).

**Comando**:

```bash
{ lista http://localhost:8080/get 19; lista http://localhost:8080/delay/1 1; } > mezcla.txt
curl -s -K mezcla.txt -w '%{time_total}\n' > mezcla-tiempos.txt
sort -n mezcla-tiempos.txt | awk '
  { t[NR] = $1; s += $1 }
  END {
    m = int(NR * 0.5);  if (m < NR * 0.5)  m++
    p = int(NR * 0.95); if (p < NR * 0.95) p++
    printf "media=%.4f mediana=%.4f p95=%.4f max=%.4f\n", s / NR, t[m], t[p], t[NR]
  }'
```

**Verifica**:

```bash
# media=0.0505 mediana=0.0004 p95=0.0015 max=1.0017
```

La media es 100 veces la mediana, y ninguna petición tardó 50 ms. Con 20
muestras, el p95 es la posición 19: justo deja fuera la lenta. Apunta en
`medidas.md` qué cifra usarías para decir "casi siempre tarda X" y cuál para
"el peor caso visto".

---

## Paso 3: El p95 de diez muestras

**Por qué**: con pocas muestras, el p95 por rango cae en la última posición y
es el max con otro nombre. Hace falta saber cuántas muestras pide cada cifra
(teoría 05, apartado 2.3).

**Comando**:

```bash
for n in 10 20 100; do
  awk -v n="$n" 'BEGIN { i = int(n * 0.95); if (i < n * 0.95) i++; print n, "->", i }'
done
```

**Verifica**:

```bash
# 10 -> 10
# 20 -> 19
# 100 -> 95
```

Con 10 muestras el p95 **es** el max. Por eso `bench` usa 10 por defecto para
una ojeada, pero para hablar del p95 pide `bench /ruta 20` o más. Apúntalo.

---

## Paso 4: El TODO 3, las cuatro cifras

**Por qué**: lo que has hecho a mano en el paso 2, dentro del toolkit.
`estadisticas` recibe por stdin una línea por petición:
`código tiempo conexiones_nuevas versión`. Ordena por la segunda columna y
calcula sobre ella.

**Comando**: resuelve la primera parte del TODO 3. El esqueleto:

```bash
sort -k2,2n | awk -v paralelo="$1" '
  { t[NR] = $2; suma += $2 }
  END {
    p95 = int(NR * 0.95); if (p95 < NR * 0.95) p95++
    printf "  min    %.3fs\n", t[1]
    # ... media, p95 y max con el mismo formato
  }'
```

Después:

```bash
"$TK" bench /get 10
```

**Verifica**:

```bash
#   min    0.000s
#   media  0.001s
#   p95    0.002s
#   max    0.002s
```

Dos espacios delante, la etiqueta a seis columnas, tres decimales y una `s`.
El check `bench-estadisticas` busca exactamente ese formato.

---

## Paso 5: Los errores cuentan

**Por qué**: un 503 rápido no es una petición rápida, es un fallo. `bench` no
reintenta (teoría 05, apartado 2.5), así que cada fallo aparece una vez, y
tiene que salir con 1 para que un script que lo use se entere.

**Comando**: añade al `awk` la cuenta de errores (el código no empieza por 2
ni por 3, incluido el `000` de una petición sin respuesta), la línea
`errores: N`, y `exit (errores > 0)` al final del `END`. Después:

```bash
"$TK" bench /status/503 3; echo "exit $?"
"$TK" bench /status/302 3 | tail -1; echo "exit $?"
```

**Verifica**:

```bash
#   min    0.001s
#   media  0.001s
#   p95    0.001s
#   max    0.001s
#   errores: 3
# error: alguna peticion de bench fallo
# exit 1
#   errores: 0
# exit 0
```

El 302 cuenta como respuesta: `bench` no sigue redirects, y un 3xx no es un
fallo. El mensaje de `error:` lo pone la función `bench`, que ya estaba
escrita: lee el código de salida de `estadisticas`.

---

## Paso 6: El resumen completo

**Por qué**: las cifras sin contexto no se pueden comparar. La primera línea
dice cuántas peticiones, cuántas a la vez y con qué versión de HTTP; la de
reutilización dice cuánto handshake hay dentro de la medida.

**Comando**: completa el TODO 3. La versión es la cuarta columna (la última
distinta de `0`; una petición sin respuesta da `0`), y una petición reutilizó
si su tercera columna es `0`. Después:

```bash
"$TK" bench /get 8
BASE_URL=https://localhost:8443 API_CACERT="$CA" "$TK" bench /get 8
```

**Verifica**:

```bash
# 8 peticiones, 4 en paralelo, HTTP/1.1
#   min    0.000s
#   media  0.006s
#   p95    0.013s
#   max    0.013s
#   reutilizacion de conexion: 4/8
#   errores: 0
# 8 peticiones, 4 en paralelo, HTTP/2
#   ...
#   reutilizacion de conexion: 7/8
#   errores: 0
```

4/8 en HTTP/1.1 (cuatro conexiones en paralelo) y 7/8 en HTTP/2 (una sola).
Copia los dos resúmenes en `medidas.md`.

---

## Paso 7: Calentar

**Por qué**: la primera petición paga DNS, TCP y TLS. Si la medida tiene pocas
muestras, la primera pesa mucho (teoría 05, apartado 2.4).

**Comando**:

```bash
export BASE_URL=https://localhost:8443 API_CACERT="$CA"
"$TK" bench /get 1 | grep -E 'max|reutil'
"$TK" bench /get 100 | grep -E 'media|p95|max|reutil'
unset BASE_URL API_CACERT
```

**Verifica**:

```bash
#   max    0.005s
#   reutilizacion de conexion: 0/1
#   media  0.001s
#   p95    0.002s
#   max    0.005s
#   reutilizacion de conexion: 99/100
```

El max de 100 sigue siendo el handshake, pero el p95 y la media ya no lo
notan. Apunta en `medidas.md` qué N usarías para comparar dos versiones de
una API, y por qué.

---

## Paso 8: El rate limit es una medida

**Por qué**: si al apretar aparecen 429, has encontrado el límite del
servidor. `/limitado` del laboratorio responde siempre 429 (teoría 05,
apartado 2.7).

**Comando**:

```bash
BASE_URL=https://localhost:8443 API_CACERT="$CA" "$TK" bench /limitado 5; echo "exit $?"
```

**Verifica**:

```bash
# 5 peticiones, 4 en paralelo, HTTP/2
#   min    0.000s
#   media  0.002s
#   p95    0.004s
#   max    0.004s
#   reutilizacion de conexion: 4/5
#   errores: 5
# error: alguna peticion de bench fallo
# exit 1
```

Cinco 429 rapidísimos: unas cifras de latencia preciosas de algo que no ha
funcionado. Por eso la línea de errores va en el resumen. Apunta en
`medidas.md` qué harías antes de medir una API con rate limit.

---

## ✅ Resultado

- [ ] He visto la media arrastrada por un solo valor, y la mediana y el p95 sin arrastrar
- [ ] Sé que con 10 muestras el p95 por rango es el max
- [ ] Mi `estadisticas` (TODO 3) imprime el resumen con el formato exacto
- [ ] `bench` cuenta los errores y sale con 1 si hay alguno
- [ ] Sé cuánto pesa la primera conexión según el número de muestras

```bash
./scripts/verificar-semana.sh 09
```

Esta práctica cierra el TODO 3. Todos los checks de `bench` deberían pasar.

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| El min es mayor que el max | `sort` ordena como texto, o por la primera columna | `sort -k2,2n`: la segunda columna, numérica |
| `awk: division by zero` | No llegó ninguna línea: el TODO 1 o 2 tiene un fallo | `"$TK" --dry-run bench /get 3` y prueba esa línea a mano |
| El p95 sale vacío | Índice 0 por redondear hacia abajo | `int()` y después `if (p95 < NR * 0.95) p95++` |
| `bench-resumen` falla con `HTTP/0` | La versión se toma de la última línea, y fue una petición sin respuesta | Guarda la versión solo si la columna no es `0` |
| `bench /status/503` sale con 0 | Falta `exit (errores > 0)` en el `END` | El `exit` del `awk` es el código de salida de `estadisticas` |
| Los decimales salen con coma (`0,001s`) | Tu locale usa coma decimal, y algún `awk` lo respeta | `LC_ALL=C` delante del `awk`, o compruébalo con `locale` |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 02 — HTTP/2 y peticiones en paralelo](02-http2-y-peticiones-en-paralelo.md) | [Práctica 04 — Caché con ETag y un token compartido](04-cache-con-etag-y-un-token-compartido.md) |
