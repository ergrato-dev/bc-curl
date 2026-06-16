#!/bin/bash
# api-explorer.sh — Proyecto Semana 1
# Consulta 3 APIs públicas y muestra status, tiempo y preview del body.

set -euo pipefail

URLS=(
  "https://api.github.com/users/octocat"
  "https://jsonplaceholder.typicode.com/posts/1"
  "https://httpbin.org/get"
)

ok_count=0
total=${#URLS[@]}

echo "=== API Explorer ==="
echo ""

for i in "${!URLS[@]}"; do
  url="${URLS[$i]}"
  num=$((i + 1))

  echo "[$num/$total] $url"

  # TODO: usar curl para obtener status code, tiempo y body
  # Pista: usar -s -o /dev/null -w "%{http_code} %{time_total}" para métricas
  # y otra llamada con -s para el body

  status="???"
  time_total="0.000"
  body=""

  echo "  Status : $status"
  echo "  Tiempo : ${time_total}s"
  echo "  Preview: ${body:0:100}"
  echo ""

  # TODO: incrementar ok_count si status empieza con 2
done

echo "=== Resumen: $ok_count/$total endpoints respondieron con 2xx ==="
