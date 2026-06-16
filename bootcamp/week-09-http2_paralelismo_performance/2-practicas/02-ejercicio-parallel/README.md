# Ejercicio 02: Requests Paralelos

## Objetivo

Comparar la performance de requests secuenciales vs paralelos, entender los parametros de control de concurrencia, y medir el speedup real en distintos escenarios.

## Preparacion

Se usa `jsonplaceholder.typicode.com` que tiene 100 posts. Cada request es liviano (~1KB) — ideal para ver el efecto del paralelismo.

```bash
# Verificar que el servidor responde
curl -s "https://jsonplaceholder.typicode.com/posts/1" | jq '{id, title}'
```

## Parte 1: Secuencial vs Paralelo (20 URLs)

```bash
mkdir -p /tmp/parallel-test
cd /tmp/parallel-test

# Generar lista de URLs
URLS=()
for i in $(seq 1 20); do
  URLS+=("-o post_${i}.json" "https://jsonplaceholder.typicode.com/posts/$i")
done

# Secuencial
echo "=== SECUENCIAL ==="
time curl -s "${URLS[@]}"

# Limpiar archivos
rm -f *.json

# Paralelo
echo "=== PARALELO ==="
time curl -s --parallel "${URLS[@]}"

# Verificar que los archivos se descargaron
ls -la *.json | wc -l
```

Anotar los tiempos de ambos. Calcular el speedup: `tiempo_secuencial / tiempo_paralelo`.

## Parte 2: Ajustar --parallel-max

```bash
cd /tmp/parallel-test

# Generar URLs para 50 posts
URLS=()
for i in $(seq 1 50); do
  URLS+=("-o post_${i}.json" "https://jsonplaceholder.typicode.com/posts/$i")
done

for max in 1 5 10 25 50; do
  rm -f *.json
  echo -n "parallel-max=$max: "
  { time curl -s --parallel --parallel-max "$max" "${URLS[@]}" ; } 2>&1 | grep real
done
```

Crear una tabla con los resultados:

| parallel-max | Tiempo | vs max=1 |
|-------------|--------|----------|
| 1 | | |
| 5 | | |
| 10 | | |
| 25 | | |
| 50 | | |

Donde se estabiliza la mejora? Por que no sigue mejorando indefinidamente?

## Parte 3: Observar Conexiones con --trace

```bash
rm -f /tmp/parallel-test/*.json

# Ver cuantas conexiones se abren
curl -s --parallel --parallel-max 5 \
  -o /tmp/parallel-test/p1.json "https://jsonplaceholder.typicode.com/posts/1" \
  -o /tmp/parallel-test/p2.json "https://jsonplaceholder.typicode.com/posts/2" \
  -o /tmp/parallel-test/p3.json "https://jsonplaceholder.typicode.com/posts/3" \
  -o /tmp/parallel-test/p4.json "https://jsonplaceholder.typicode.com/posts/4" \
  -o /tmp/parallel-test/p5.json "https://jsonplaceholder.typicode.com/posts/5" \
  -w "Conexiones abiertas: %{num_connects}\n" 2>&1
```

Cuantas conexiones nuevas se abrieron? Si el servidor soporta HTTP/2, deberia ser 1 (multiplexing). Si es HTTP/1.1, deberia ser hasta 5 (una por request).

## Parte 4: Comparar con bash &

```bash
cd /tmp/parallel-test
rm -f *.json

# Metodo 1: curl --parallel
echo "=== curl --parallel ==="
time curl -s --parallel \
  $(for i in $(seq 1 20); do echo "-o bash_p${i}.json https://jsonplaceholder.typicode.com/posts/$i"; done)

rm -f *.json

# Metodo 2: bash background jobs
echo "=== bash & ==="
time {
  for i in $(seq 1 20); do
    curl -s -o "bash_b${i}.json" "https://jsonplaceholder.typicode.com/posts/$i" &
  done
  wait
}
```

Que metodo fue mas rapido? Que metodo genero mas procesos? (usar `ps aux | grep curl` durante la ejecucion para verlo)

## Parte 5: Paralelismo con URLs en Archivo

Para casos donde tienes muchas URLs o URLs generadas dinamicamente:

```bash
# Generar archivo de configuracion curl
for i in $(seq 1 30); do
  echo "url = https://jsonplaceholder.typicode.com/posts/$i"
  echo "output = /tmp/parallel-test/config_${i}.json"
done > /tmp/curl-urls.txt

# Ejecutar
time curl -s --parallel --parallel-max 10 --config /tmp/curl-urls.txt

# Contar archivos descargados
ls /tmp/parallel-test/config_*.json | wc -l
```

## Entrega

Archivo `respuestas.md` con:
1. Tabla comparativa secuencial vs paralelo (tiempo y speedup)
2. Tabla de `--parallel-max` con tiempos
3. Numero de conexiones observadas en la parte 3 y explicacion
4. Comparacion `--parallel` vs `bash &` (tiempo y observaciones)
5. Reflexion: cuando usarias `--parallel-max` bajo (5 o menos)?
