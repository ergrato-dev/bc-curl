#!/usr/bin/env bash
# Verifica la integridad estructural del bootcamp:
#   1. Nombres de carpeta week-NN-slug bien formados.
#   2. Enlaces relativos en markdown que resuelven a una ruta real.
#   3. Seccion "Navegacion" en el README de cada semana publicada.
#   4. SVG de 0-assets/ enlazados desde algun .md.
#   5. checks.json valido como JSON.
#   6. Todo .sh con shebang `env bash` y `set -euo pipefail`.
#   7. Archivos de teoria dentro del rango 200-300 lineas.
#
# Las comprobaciones 3, 6 y 7 solo se aplican a las semanas marcadas con ✅ en
# bootcamp/README.md: son el estandar del refactor de profundizacion y una
# semana todavia sin refactorizar fallaria todas por diseno.
#
# Uso: scripts/verificar-enlaces.sh
# Salida: lista de problemas encontrados; exit code 1 si hay al menos uno.

set -u
cd "$(dirname "$0")/.." || exit 1

fail=0

# Semanas ya refactorizadas, segun el indice de bootcamp/README.md.
publicadas=$(grep -oE '^\| \[[0-9]{2}\]\(([a-z0-9_-]+)/README\.md\).*\| ✅ \|$' bootcamp/README.md \
             | sed -E 's/^\| \[[0-9]{2}\]\(([a-z0-9_-]+)\/README\.md\).*/\1/')

esta_publicada() {
  # $1 = ruta que contiene el slug de la semana
  local ruta="$1" slug
  for slug in $publicadas; do
    case "$ruta" in *"$slug"*) return 0 ;; esac
  done
  return 1
}

if [ -z "$publicadas" ]; then
  echo "AVISO: ninguna semana marcada como ✅ en bootcamp/README.md."
  echo "       Se omiten las comprobaciones 3, 6 y 7 del contenido de las semanas."
fi

echo "== 1. Nombres de carpeta =="
while IFS= read -r d; do
  name=$(basename "$d")
  if ! [[ "$name" =~ ^week-[0-9]{2}-[a-z0-9_]+$ ]]; then
    echo "NOMBRE INVALIDO (week): $d"
    fail=1
  fi
done < <(find bootcamp -mindepth 1 -maxdepth 1 -type d -iname "week-*")

echo "== 2. Enlaces relativos en markdown =="
# No parsea markdown de verdad: quita los bloques ``` y busca "](...)".
# Falso positivo conocido: URLs con parentesis anidados. Si el script reporta
# algo distinto a eso, es un enlace roto real.
while IFS= read -r f; do
  content=$(awk '/^```/{c=!c; next} !c' "$f")
  while IFS= read -r link; do
    [ -z "$link" ] && continue
    clean="${link%%#*}"
    [ -z "$clean" ] && continue
    case "$clean" in http*|\<http*|ws*|mailto:*|\#*|/*) continue ;; esac
    dir=$(dirname "$f")
    resolved=$(realpath -m "$dir/$clean")
    if [ ! -e "$resolved" ]; then
      echo "ENLACE ROTO: $f -> $link"
      fail=1
    fi
  done < <(printf '%s\n' "$content" | grep -oE '\]\([^)]+\)' | sed -E 's/^\]\(//;s/\)$//')
# .claude/ y .github/ contienen plantillas con rutas de ejemplo
# (`../0-assets/NN-nombre.svg`) que no resuelven por diseno.
done < <(find . -iname "*.md" -not -path "./.git/*" -not -path "*/node_modules/*" \
           -not -path "./.claude/*" -not -path "./.github/*")

echo "== 3. Navegacion anterior/siguiente en README de cada semana publicada =="
while IFS= read -r rm; do
  esta_publicada "$rm" || continue
  if ! grep -q "Navegación" "$rm"; then
    echo "SIN NAVEGACION: $rm"
    fail=1
  fi
done < <(find bootcamp -mindepth 2 -maxdepth 2 -iname "README.md")

echo "== 4. SVG huerfanos en 0-assets/ =="
while IFS= read -r svg; do
  base=$(basename "$svg")
  if ! grep -rqF "$base" --include="*.md" .; then
    echo "SVG HUERFANO (no enlazado desde ningun .md): $svg"
    fail=1
  fi
done < <(find bootcamp assets -iname "*.svg" 2>/dev/null)

echo "== 5. checks.json valido =="
if command -v jq >/dev/null 2>&1; then
  while IFS= read -r cj; do
    if ! jq -e . "$cj" > /dev/null 2>&1; then
      echo "JSON INVALIDO: $cj"
      fail=1
    fi
  done < <(find bootcamp -name "checks.json")
else
  echo "AVISO: jq no esta instalado, no se validan los checks.json"
fi

echo "== 6. Cabecera de los scripts bash =="
# Un starter sin `set -euo pipefail` ensena el antipatron que el bootcamp
# combate: el script que sigue adelante despues de que algo falle.
while IFS= read -r sh; do
  case "$sh" in bootcamp/*) esta_publicada "$sh" || continue ;; esac
  if [ "$(head -1 "$sh")" != "#!/usr/bin/env bash" ]; then
    echo "SHEBANG INCORRECTO (debe ser '#!/usr/bin/env bash'): $sh"
    fail=1
  fi
  if ! grep -q 'set -euo pipefail' "$sh"; then
    echo "SIN 'set -euo pipefail': $sh"
    fail=1
  fi
  if [ ! -x "$sh" ]; then
    echo "SIN BIT DE EJECUCION (chmod +x): $sh"
    fail=1
  fi
done < <(find bootcamp scripts -name "*.sh" 2>/dev/null)

echo "== 7. Extension de los archivos de teoria (200-300 lineas) =="
# La regla del refactor de profundizacion: un archivo, un concepto, ~250
# lineas. Si se pasa, casi siempre es que mezcla dos temas.
while IFS= read -r t; do
  esta_publicada "$t" || continue
  n=$(wc -l < "$t")
  if [ "$n" -lt 200 ] || [ "$n" -gt 300 ]; then
    echo "TEORIA FUERA DE RANGO ($n lineas, se esperan 200-300): $t"
    fail=1
  fi
done < <(find bootcamp -path "*/1-teoria/*" -name "*.md" 2>/dev/null)

if [ "$fail" -eq 0 ]; then
  echo "OK: sin problemas detectados."
fi
exit "$fail"
