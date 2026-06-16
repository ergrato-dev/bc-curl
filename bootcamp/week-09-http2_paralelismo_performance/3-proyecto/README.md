# Proyecto Semana 9: perf-test.sh

## Descripcion

Construir `perf-test.sh`, un script de testing de performance que toma una lista de endpoints, hace N requests a cada uno, y reporta percentiles de tiempo de respuesta con estadisticas de errores.

## Uso

```bash
# Uso basico (5 requests por endpoint, max 3 paralelos)
bash perf-test.sh endpoints.txt

# Configurar numero de requests y paralelismo
bash perf-test.sh --times 10 --max-parallel 5 endpoints.txt

# Exportar resultados a CSV
bash perf-test.sh --times 10 --csv results.csv endpoints.txt
```

## Output esperado

```
=== Performance Test: 10 requests por endpoint ===

URL                                                p50(s)   p90(s)   p99(s)   errors
------------------------------------------------------------------------------------------
https://api.github.com/users/octocat              0.312    0.445    0.512    0/10
https://jsonplaceholder.typicode.com/posts/1      0.098    0.145    0.201    0/10
https://httpbin.org/get                           0.234    0.389    0.412    0/10
https://httpbin.org/delay/1                       1.089    1.112    1.198    0/10
https://jsonplaceholder.typicode.com/users        0.102    0.167    0.189    0/10

=== Ranking (mas rapido a mas lento por p50) ===
1. jsonplaceholder.typicode.com/posts/1   0.098s
2. jsonplaceholder.typicode.com/users     0.102s
3. httpbin.org/get                        0.234s
4. api.github.com/users/octocat           0.312s
5. httpbin.org/delay/1                    1.089s
```

## Requisitos

### Funcionales

- Leer endpoints desde archivo (una URL por linea, ignorar lineas vacias y comentarios `#`)
- Hacer exactamente N requests por endpoint (configurable con `--times`, default 5)
- Calcular p50, p90, p99 del tiempo de respuesta (usando los datos reales de `time_total`)
- Contar errores: requests con status >= 400 o que fallaron (conexion rechazada)
- Mostrar ranking al final ordenado por p50 ascendente
- Opcion `--csv FILE`: exportar resultados en formato CSV

### Tecnicos

- Usar `--write-out` para capturar `time_total` y `http_code` sin parsear headers
- Los requests de cada endpoint deben poder hacerse con `--parallel` para reducir el tiempo total del benchmark
- El script debe manejar endpoints no disponibles sin abortar todo el benchmark
- Compatibilidad: bash 4+, curl 7.66+, awk (para calcular percentiles)

### Calculo de percentiles

Para calcular p50/p90/p99 con awk dado un array de tiempos:

```bash
# Ejemplo: calcular percentiles de una lista de tiempos
printf '%s\n' "${times[@]}" | sort -n | awk '
BEGIN { n = 0 }
{ values[n++] = $1 }
END {
  p50 = values[int(n * 0.50)]
  p90 = values[int(n * 0.90)]
  p99 = values[int(n * 0.99 + 0.5)]
  printf "p50=%.3f p90=%.3f p99=%.3f\n", p50, p90, p99
}'
```

## Estructura del proyecto

```
3-proyecto/
├── README.md
└── starter/
    ├── endpoints.txt      (5 URLs de ejemplo)
    └── perf-test.sh       (estructura base con TODO markers)
```

## Criterios de evaluacion

| Criterio | Peso | Descripcion |
|---------|------|-------------|
| Lectura de endpoints | 10% | Lee archivo, ignora comentarios y lineas vacias |
| Medicion correcta | 25% | Usa `--write-out` para capturar tiempos reales |
| Calculo de percentiles | 25% | p50/p90/p99 calculados correctamente |
| Conteo de errores | 15% | Detecta status >= 400 y fallos de conexion |
| Ranking final | 10% | Ordenado por p50 ascendente |
| CSV export | 10% | Formato correcto con cabecera |
| Manejo de errores | 5% | No aborta si un endpoint falla |

## Entrega

- `perf-test.sh` en la carpeta `3-proyecto/` (no en starter/)
- `resultados.md` con la salida del script ejecutado contra el archivo `starter/endpoints.txt` con `--times 10`
- Opcional: `results.csv` generado con `--csv`
