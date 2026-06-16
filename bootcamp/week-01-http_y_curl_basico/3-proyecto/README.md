# Proyecto Semana 1: Explorador de APIs Públicas

## Descripcion

Script bash `api-explorer.sh` que consulta 3 APIs públicas diferentes, muestra para cada una: status code, tiempo de respuesta y un preview del body.

## Requisitos

### Funcionalidad

El script debe:

1. Consultar estas 3 URLs:
   - `https://api.github.com/users/octocat`
   - `https://jsonplaceholder.typicode.com/posts/1`
   - `https://httpbin.org/get`

2. Para cada URL mostrar:
   - La URL consultada
   - El status code HTTP
   - El tiempo total de respuesta (en segundos)
   - Los primeros 100 caracteres del body

3. Al final: un resumen indicando cuántas respondieron con 2xx.

### Output esperado

```
=== API Explorer ===

[1/3] https://api.github.com/users/octocat
  Status : 200
  Tiempo : 0.412s
  Preview: {"login":"octocat","id":583231,"node_id":"MDQ6VXNlcjU4MzIzMQ==","avata

[2/3] https://jsonplaceholder.typicode.com/posts/1
  Status : 200
  Tiempo : 0.238s
  Preview: {  "userId": 1,  "id": 1,  "title": "sunt aut facere repellat provide

[3/3] https://httpbin.org/get
  Status : 200
  Tiempo : 0.891s
  Preview: {  "args": {},  "headers": {    "Accept": "*/*",    "Host": "httpbin.or

=== Resumen: 3/3 endpoints respondieron con 2xx ===
```

## Restricciones

- Solo bash + curl (sin Python, jq ni otras herramientas)
- Usar `-w` para extraer status code y tiempo
- Usar `-s` para no mostrar barra de progreso
- Los primeros 100 chars del body: capturar con `-o` a variable y usar `${var:0:100}`

## Estructura de entrega

```
3-proyecto/
├── README.md          (este archivo)
└── starter/
    └── api-explorer.sh   (tu implementación)
```

## Pista de implementacion

```bash
#!/bin/bash

URL="https://api.github.com/users/octocat"

# Capturar body y métricas por separado
BODY=$(curl -s "$URL")
METRICS=$(curl -s -o /dev/null -w "%{http_code} %{time_total}" "$URL")

STATUS=$(echo "$METRICS" | cut -d' ' -f1)
TIME=$(echo "$METRICS" | cut -d' ' -f2)
PREVIEW="${BODY:0:100}"

echo "Status : $STATUS"
echo "Tiempo : ${TIME}s"
echo "Preview: $PREVIEW"
```

Nota: la pista hace 2 requests por URL. Como mejora opcional, hacer solo 1 usando `-w` + `-o`.

## Criterios de evaluacion

Ver [rubrica-evaluacion.md](../rubrica-evaluacion.md)

- Script funciona y produce output correcto: 40%
- Status code capturado correctamente: 20%
- Tiempo de respuesta mostrado: 20%
- Preview del body: 10%
- Resumen final con conteo: 10%
