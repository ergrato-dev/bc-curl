# Requests Paralelos con curl

![Requests Paralelos](../0-assets/02-parallel-requests.svg)

## El Problema del Loop Secuencial

El patron tipico de scripting para muchas URLs es un loop:

```bash
for url in "${urls[@]}"; do
  curl -s "$url" -o "$(basename $url).json"
done
```

Esto es **secuencial**: cada request espera al anterior. Si cada request tarda 200ms y hay 20 URLs, el script tarda 4 segundos. Con paralelismo, los 20 requests podrian completar en ~200ms (mas overhead).

---

## curl Paralelo Nativo (curl 7.66+)

curl incorporo soporte nativo de paralelismo en la version 7.66 (2019). El flag `--parallel` (o `-Z`) activa el modo paralelo para multiples URLs en un mismo comando:

```bash
# Secuencial (default): 3 requests, uno por vez
curl -s "https://jsonplaceholder.typicode.com/posts/1" \
     "https://jsonplaceholder.typicode.com/posts/2" \
     "https://jsonplaceholder.typicode.com/posts/3"

# Paralelo: los 3 requests van al mismo tiempo
curl -s --parallel \
  "https://jsonplaceholder.typicode.com/posts/1" \
  "https://jsonplaceholder.typicode.com/posts/2" \
  "https://jsonplaceholder.typicode.com/posts/3"
```

### Guardar Cada Respuesta

Para guardar las respuestas de forma individual, cada URL necesita su propio `-o`:

```bash
curl -s --parallel \
  -o "post1.json" "https://jsonplaceholder.typicode.com/posts/1" \
  -o "post2.json" "https://jsonplaceholder.typicode.com/posts/2" \
  -o "post3.json" "https://jsonplaceholder.typicode.com/posts/3"
```

El orden de los archivos corresponde al orden de las URLs, independientemente del orden en que llegaron las respuestas.

---

## Controlar la Concurrencia

### --parallel-max N

Por defecto, curl usa un maximo de 50 conexiones paralelas. Se puede ajustar:

```bash
# Maximo 5 conexiones paralelas (para no saturar el servidor)
curl -s --parallel --parallel-max 5 \
  $(for i in $(seq 1 20); do echo "-o post$i.json https://jsonplaceholder.typicode.com/posts/$i"; done)
```

Ajustar `--parallel-max` segun:
- El numero de conexiones que el servidor acepta
- Los limites de tu red o firewall
- La politica de rate limiting del servidor

### --parallel-immediate

Sin este flag, curl por defecto espera a tener todas las URLs antes de empezar. Con `--parallel-immediate`, empieza a hacer requests tan pronto como puede:

```bash
curl -s --parallel --parallel-immediate \
  -o post1.json "https://jsonplaceholder.typicode.com/posts/1" \
  -o post2.json "https://jsonplaceholder.typicode.com/posts/2"
```

---

## Usar con URLs Dinamicas

Para listas de URLs generadas dinamicamente, usar un archivo de config curl o xargs:

### Opcion 1: Archivo de Config curl

```bash
# Generar el archivo de config
for i in $(seq 1 20); do
  echo "url = https://jsonplaceholder.typicode.com/posts/$i"
  echo "output = post_$i.json"
done > urls.txt

# Ejecutar con paralelismo
curl -s --parallel --config urls.txt
```

### Opcion 2: xargs con Concurrencia

xargs puede ejecutar multiples instancias de curl en paralelo:

```bash
# -P 10: maximo 10 procesos paralelos
seq 1 20 | xargs -P 10 -I{} \
  curl -s -o "post_{}.json" "https://jsonplaceholder.typicode.com/posts/{}"
```

La diferencia: con `--parallel` hay un solo proceso curl gestionando todo. Con xargs hay multiples procesos curl, lo que es mas costoso en recursos pero mas flexible.

---

## Comparacion: curl --parallel vs bash &

### bash & (background jobs)

```bash
# Lanzar todos en paralelo con bash
for i in $(seq 1 10); do
  curl -s -o "post_$i.json" "https://jsonplaceholder.typicode.com/posts/$i" &
done
wait  # Esperar a que todos terminen
```

Desventajas:
- Un proceso curl por URL
- No hay control de concurrencia (todos van al mismo tiempo)
- Mas overhead de procesos del sistema operativo
- Dificil capturar exit codes individuales

### curl --parallel

```bash
curl -s --parallel --parallel-max 10 \
  $(for i in $(seq 1 10); do echo "-o post_$i.json https://jsonplaceholder.typicode.com/posts/$i"; done)
```

Ventajas:
- Un solo proceso curl
- Control de concurrencia con `--parallel-max`
- Mejor aprovechamiento de HTTP/2 (multiplexing en una conexion)
- Mas eficiente en recursos del sistema

---

## Medir el Beneficio

```bash
# Secuencial
time curl -s \
  -o /dev/null "https://jsonplaceholder.typicode.com/posts/1" \
  -o /dev/null "https://jsonplaceholder.typicode.com/posts/2" \
  -o /dev/null "https://jsonplaceholder.typicode.com/posts/3" \
  -o /dev/null "https://jsonplaceholder.typicode.com/posts/4" \
  -o /dev/null "https://jsonplaceholder.typicode.com/posts/5"

# Paralelo
time curl -s --parallel \
  -o /dev/null "https://jsonplaceholder.typicode.com/posts/1" \
  -o /dev/null "https://jsonplaceholder.typicode.com/posts/2" \
  -o /dev/null "https://jsonplaceholder.typicode.com/posts/3" \
  -o /dev/null "https://jsonplaceholder.typicode.com/posts/4" \
  -o /dev/null "https://jsonplaceholder.typicode.com/posts/5"
```

El speedup teorico es linear (5 requests en paralelo → 5x mas rapido), pero en practica es menor por:
- El servidor tiene sus propios limites
- El ancho de banda puede ser el cuello de botella
- Hay overhead de abrir mas conexiones simultaneas
