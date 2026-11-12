# Medir sin engañarse

> Una medida es una anécdota. "Tarda 120 ms" no dice si tarda 120 ms
> siempre, casi siempre, o una vez de cada diez tarda tres segundos. Medir
> rendimiento es tomar muchas muestras, resumirlas con las cifras que no
> esconden la cola, y no medir sin querer otra cosa: el handshake, los
> reintentos o tu propio portátil.

![Histograma de veinte tiempos de respuesta: diecinueve agrupados entre 5 y 15 ms y uno solo a 1000 ms. Marcas para el mínimo, la mediana, la media (arrastrada hacia la derecha por el valor lento) y el p95. Debajo, cómo se calcula el p95 por rango: ordenar, multiplicar N por 0,95, redondear hacia arriba y tomar esa posición](../0-assets/05-medir-sin-enganarse.svg)

## 🎯 Objetivos

- Explicar por qué la media sola engaña, y qué cuentan la mediana y el p95
- Calcular un percentil por rango con `sort` y `awk`
- Decidir cuántas muestras hacen falta para que el p95 signifique algo
- Evitar lo que contamina una medida: la primera conexión, los reintentos,
  los redirects y la máquina que mide
- Distinguir medir la latencia de una API de hacerle una prueba de carga

---

## 1. Qué problema resuelve

Lanzas una petición, tarda 8 ms, y concluyes que la API es rápida. La lanzas
veinte veces y diecinueve tardan 8 ms, pero una tarda un segundo. Si tu script
hace cien llamadas, se va a encontrar esa lenta cinco veces.

Lo que el usuario sufre no es la media: es **la cola**. Y la cola solo aparece
con muchas muestras.

---

## 2. Cómo funciona

### 2.1 Cuatro cifras

Con N tiempos ordenados de menor a mayor:

| Cifra | Qué es | Qué cuenta |
|---|---|---|
| **min** | El primero | Lo mejor que puede ir: casi siempre, una conexión reutilizada sin espera |
| **media** | La suma entre N | Útil para estimar un total. Un solo valor extremo la arrastra |
| **p95** | El que deja por debajo al 95 % | La experiencia "mala pero normal": 1 de cada 20 va peor |
| **max** | El último | El peor caso visto. Con pocas muestras, puro azar |

La **mediana** (p50) es el valor del medio: la mitad va más rápido, la mitad
más lento. No la mueve un valor extremo.

### 2.2 Por qué la media engaña

Diecinueve peticiones de 10 ms y una de 1000 ms:

- media: (19 × 10 + 1000) / 20 = **59,5 ms**
- mediana: **10 ms**
- p95: **10 ms** (posición 19 de 20)
- max: **1000 ms**

Ninguna petición tardó 59,5 ms. La media describe un caso que no existe. Por
eso un resumen honesto da **varias cifras**, nunca una.

### 2.3 El percentil por rango

Hay varias formas de calcular un percentil. La más simple, y la que usa el
toolkit, es **por rango** (*nearest-rank*): el valor en la posición
`⌈N × p⌉` de la lista ordenada, sin interpolar.

| N | N × 0,95 | Posición del p95 |
|:--:|:--:|:--:|
| 10 | 9,5 | 10 (el máximo) |
| 20 | 19 | 19 |
| 100 | 95 | 95 |

Con 10 muestras, el p95 **es** el máximo: no hay datos para separar la cola
del peor caso. A partir de 20 empieza a significar algo, y con 100 ya es
estable. Regla práctica: **para hablar del p95, al menos 20 muestras**.

En `awk`, el redondeo hacia arriba se hace a mano, porque `awk` no tiene
`ceil`:

```bash
sort -n tiempos.txt | awk '{ t[NR] = $1 }
  END { i = int(NR * 0.95); if (i < NR * 0.95) i++; print t[i] }'
```

### 2.4 Lo que contamina la medida

- **La primera petición.** Paga DNS, TCP y TLS. Si mides 5 y una es la
  primera, el max y la media son del handshake. O la descartas (calentar), o
  mides suficientes para que pese poco, o la reportas aparte. `bench` la
  incluye y lo dice: la línea de reutilización cuenta cuántas abrieron.
- **Los reintentos.** Un `--retry` que repite un 503 tras un segundo convierte
  una petición fallida en una "lenta" de un segundo. La medida mezcla dos
  cosas.
- **Los redirects.** Un `-L` que sigue un 302 mide dos peticiones como una.
- **El cliente.** Arrancar un proceso curl, leer certificados y resolver
  nombres también cuesta. Por eso un bucle de curl mide más el bucle que la
  API.
- **La máquina.** Un portátil con el navegador abierto, una Wi-Fi compartida,
  una VPN: todo suma a la cola.

### 2.5 Sin reintentos ni redirects

Por lo anterior, `bench` en el toolkit construye su red con `construir_red
BENCH`, que **no** añade `--retry` ni `--location`. Una petición que falla
cuenta como error, con su tiempo; un 3xx cuenta como respuesta, sin seguirlo.
El resto de subcomandos siguen reintentando: un `get` quiere el dato, un
`bench` quiere la verdad.

### 2.6 Latencia frente a carga

Medir la **latencia** de una API es ver cuánto tarda en responder cuando
nadie la aprieta: pocas peticiones, poco paralelo. Hacerle una **prueba de
carga** es ver cuándo se rompe: miles de peticiones, cientos a la vez.

Son cosas distintas, con herramientas distintas. `bench` mide latencia: 4 en
paralelo por defecto, nunca más de 8, y un techo de 1000 peticiones. Una prueba de carga necesita
herramientas hechas para eso (`wrk`, `hey`, `k6`), un entorno propio, y
**permiso**.

> [!WARNING]
> Lanzar cientos de peticiones contra una API que no es tuya es, en la
> práctica, un ataque de denegación de servicio a pequeña escala. Además de
> los 429 y del bloqueo de tu IP, puede violar sus condiciones de uso. Mide
> contra el laboratorio, o contra tu propia API.

### 2.7 El rate limit también es una medida

Si a partir de cierta concurrencia empiezan los 429, has encontrado el límite
del servidor. No lo esquives: anótalo. El endpoint `/limitado` del
laboratorio responde siempre 429 con `Retry-After: 1`, para que veas cómo se
cuentan los errores.

---

## 3. Cómo se usa

Veinte muestras a mano, con el handshake dentro de la primera:

```bash
for i in $(seq 20); do
  printf 'url = "https://localhost:8443/get"\noutput = "/dev/null"\n'
done > lista.txt

curl --cacert docs/lab-ca.pem -s -K lista.txt -w '%{time_total}\n' > tiempos.txt
sort -n tiempos.txt | awk '
  { t[NR] = $1; s += $1 }
  END { i = int(NR * 0.95); if (i < NR * 0.95) i++
        printf "min %.4f  media %.4f  p95 %.4f  max %.4f\n", t[1], s / NR, t[i], t[NR] }'
# min 0.0007  media 0.0024  p95 0.0054  max 0.0233
```

El max es la primera petición, con su handshake. El p95 no se entera: 1 de 20
es exactamente el 5 % que el p95 deja fuera.

Y con el toolkit, todo eso en una línea:

```bash
BASE_URL=https://localhost:8443 API_CACERT=docs/lab-ca.pem ./api-toolkit.sh bench /get 20
# 20 peticiones, 4 en paralelo, HTTP/2
#   min    0.001s
#   media  0.002s
#   p95    0.004s
#   max    0.005s
#   reutilizacion de conexion: 19/20
#   errores: 0
```

---

## 4. Antipatrones

- **Dar solo la media.** Da al menos mediana o p95, y el max.
- **El p95 de 10 muestras.** Es el max con otro nombre.
- **Comparar dos medidas tomadas en momentos distintos** sin repetirlas. El
  ruido de una red real puede ser mayor que la diferencia que buscas.
- **Medir con `--retry`.** Mides la política de reintentos, no la API.
- **Medir desde un bucle de curl** y atribuir el tiempo a la API.
- **Hacer una prueba de carga contra producción ajena.** Para eso, laboratorio
  o API propia. Medir la latencia de una API ajena con 20 peticiones y 4 en
  paralelo es otra cosa, y aun así se leen antes sus condiciones de uso.

---

## 5. Trucos

- **Calentar sin código**: lanza `bench` con N=1 y descarta el resultado, o
  mide con N grande para que la primera pese poco.
- **La mediana con el mismo awk**: cambia 0.95 por 0.5.
- **`sort -n` y `sort -g`**: `-n` basta para tiempos como `0.004556`; `-g`
  entiende también notación científica.
- **`%{time_total}` tiene microsegundos** (6 decimales). Para el resumen, 3
  bastan: por debajo del milisegundo, el ruido del sistema manda.
- **Separa los errores** antes de calcular percentiles si quieres la latencia
  de las que salieron bien: un 503 rápido baja la media.

---

## 📚 Recursos Adicionales

- [Gil Tene — How NOT to Measure Latency](https://www.infoq.com/presentations/latency-response-time/)
- [Wikipedia — Percentile, método nearest-rank](https://en.wikipedia.org/wiki/Percentile#The_nearest-rank_method)
- [Google SRE Book — Service Level Objectives](https://sre.google/sre-book/service-level-objectives/)

---

## ✅ Checklist de Verificación

- [ ] Explicas con un ejemplo por qué la media sola engaña
- [ ] Calculas un p95 por rango con `sort` y `awk`
- [ ] Sabes cuántas muestras hacen falta para que el p95 no sea el max
- [ ] Nombras cuatro cosas que contaminan una medida
- [ ] Distingues medir latencia de hacer una prueba de carga, y cuándo hace falta permiso
