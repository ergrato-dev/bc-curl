---
name: verificar-estructura
description: Revisa la integridad estructural de una semana o de todo el repositorio — enlaces, navegación, secciones obligatorias del README, SVG huérfanos, rango de líneas de la teoría y lo que el script no puede ver. Usar después de crear o editar contenido y antes de cerrar cualquier tanda.
allowed-tools: Bash(bash scripts/*) Bash(find*) Bash(grep*) Bash(wc*) Bash(jq*) Read Grep Glob
---

# Verificar la estructura

`scripts/verificar-enlaces.sh` cubre lo mecánico. Este skill hace lo que un
script no puede: leer y decidir si una sección **está** o solo **parece que
está**.

## 1. Lo mecánico primero

```bash
bash scripts/verificar-enlaces.sh
```

Siete comprobaciones: nombres de carpeta, enlaces relativos, sección de
navegación, SVG huérfanos, `checks.json` válido, cabecera de los `.sh`, y rango
de 200-300 líneas de la teoría.

Si sale en rojo, arregla eso antes de seguir. Lo de abajo asume que está verde.

## 2. Lo que el script no ve

### Las 10 secciones del README de semana

Comprueba que estén **y en orden**:

1. `# Semana NN — Tema`
2. Blockquote de gancho
3. `## 🎯 Objetivos de la Semana`
4. `## 📋 Prerrequisitos`
5. `## 🗂️ Estructura de la Semana`
6. `## 📝 Contenidos`
7. `## ⏱️ Distribución del Tiempo (8 horas)`
8. `## 🎩 Trucos y atajos`
9. `## 📌 Entregables`
10. `## ✅ Verificación`
11. `## 🔗 Navegación`

Entre la 7 y la 8 cabe **una** sección temática propia de la semana.

```bash
grep -nE '^#{1,2} ' bootcamp/week-NN-*/README.md
```

### La tabla de tiempos suma 8 h

Súmala a mano. Es el error más frecuente y el que más daño hace: una semana que
suma 11 h no es una semana, es dos.

### El árbol de `## 🗂️ Estructura de la Semana` refleja la realidad

```bash
find bootcamp/week-NN-* -maxdepth 2 | sort
```

Compáralo con el bloque del README. Un árbol que promete `07-loops.md` cuando el
archivo se llama `07-loops-y-paginacion.md` es un enlace roto en potencia.

### Las prácticas cierran bien

Cada `2-practicas/NN-*.md` termina con `## ✅ Resultado` y
`## 🧯 Si algo sale mal`. Y cada `## Paso N` lleva sus tres bloques: **Por qué**,
**Comando**, **Verifica**.

```bash
grep -c '^## Paso' bootcamp/week-NN-*/2-practicas/*.md
grep -c '\*\*Verifica\*\*' bootcamp/week-NN-*/2-practicas/*.md
# los dos numeros tienen que coincidir en cada archivo
```

### Los requisitos del proyecto son copia literal del `checks.json`

```bash
jq -r '.checks[].descripcion' bootcamp/week-NN-*/checks.json
```

Cada línea tiene que aparecer **palabra por palabra** en
`3-proyecto/README.md § ✅ Requisitos verificables`. Si no, el alumno ve un ❌ y
no sabe a qué requisito corresponde.

### Toda salida esperada está comentada

Un bloque `bash` con un comando y sin la salida debajo obliga al alumno a
ejecutar para saber si acertó. En la teoría y en las prácticas, cada comando que
produce salida la lleva comentada.

### Los recursos dicen por qué

Cada entrada de `4-recursos/*/README.md` lleva su línea de "por qué vale la
pena" y el archivo lleva la fecha de comprobación de los enlaces.

## Salida

```
archivo:línea | qué falta o qué no cuadra | qué debería haber
```

Cierra con `N hallazgos.` o `OK: la estructura cuadra.`

## Reglas

- **Solo lectura.** Informas; quien escribe corrige.
- Una semana sin refactorizar todavía va a fallar casi todo. No es un hallazgo:
  compruébalo contra la lista de semanas ya cerradas antes de reportar.
- **No inventes hallazgos.** Cero es un resultado válido.
