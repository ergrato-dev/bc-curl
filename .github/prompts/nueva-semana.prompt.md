---
name: "Nueva semana"
description: "Genera o refactoriza una semana completa del Bootcamp curl: checks.json, README con las 10 secciones, 7-8 archivos de teoría, 4 prácticas planas, proyecto con starter, rúbrica, recursos y glosario."
argument-hint: "Número de semana (ej: 05) y su tema"
mode: "agent"
---

# Nueva semana — Bootcamp curl

Antes de empezar, lee [`.github/copilot-instructions.md`](../copilot-instructions.md)
entero. Aquí está el procedimiento; ahí están las convenciones.

## Estructura a producir

```
bootcamp/week-NN-tema_en_snake_case/
├── README.md                  # 10 secciones, en orden
├── rubrica-evaluacion.md      # 30 / 40 / 30
├── checks.json                # 6-18 comprobaciones
├── 0-assets/                  # NN-nombre.svg, todos enlazados
├── 1-teoria/                  # 7-8 archivos, 200-300 lineas cada uno
├── 2-practicas/               # 4 archivos planos, 200-380 lineas
├── 3-proyecto/
│   ├── README.md              # 8 secciones
│   └── starter/               # esqueleto con TODOs, nunca la solucion
├── 4-recursos/{ebooks-free,videografia,webgrafia}/README.md
└── 5-glosario/README.md
```

## Orden de generación

No es negociable: cada paso depende del anterior.

1. **`checks.json`.** Define qué es entregable. Usa el prompt `checks-json`.
2. **`README.md`** de la semana, con las 10 secciones y la tabla de tiempos
   cuadrada a 8 h.
3. **`1-teoria/`**, archivo a archivo. Usa el prompt `nueva-teoria`.
4. **`2-practicas/`**, las cuatro. Usa el prompt `nueva-practica`.
5. **`3-proyecto/`** más su `starter/`. Usa el prompt `nuevo-proyecto`.
6. **`rubrica-evaluacion.md`.**
7. **`4-recursos/`** y **`5-glosario/`**.
8. **`0-assets/`**: los SVG que hagan falta. Usa el prompt `svg-diagrama`.
9. **`docs/trucos-curl.md`**: replica la sección de trucos del README.
10. **`docs/glosario-global.md`**: añade los términos nuevos.

## Las 10 secciones del README

1. `# Semana NN — Tema`
2. Blockquote de gancho, 2 líneas
3. `## 🎯 Objetivos de la Semana`
4. `## 📋 Prerrequisitos` — encadenados y concretos
5. `## 🗂️ Estructura de la Semana` — árbol comentado
6. `## 📝 Contenidos` — tabla de teoría y tabla de prácticas, con duración
7. `## ⏱️ Distribución del Tiempo (8 horas)` — **suma 8 h exactas**
8. `## 🎩 Trucos y atajos`
9. `## 📌 Entregables`
10. `## ✅ Verificación`
11. `## 🔗 Navegación` — tabla Anterior | Actual | Siguiente + volver al inicio

Entre la 7 y la 8 cabe **una** sección temática propia de la semana.

## Las doce instrucciones

1. **Profundidad sobre cobertura.** Es preferible explicar bien cinco variables
   de `--write-out` que listar las cuarenta.
2. **Un archivo, un concepto.** Si el título necesita una "y", divídelo.
3. **200-300 líneas por archivo de teoría.** Si se pasa, mezcla dos temas.
4. **Siempre el porqué antes del comando.**
5. **Todo paso de práctica termina en una verificación ejecutable.**
6. **Toda salida esperada va comentada** bajo su comando.
7. **Todo va contra el laboratorio local.** `httpbin.org` solo como alternativa.
8. **No inventes flags ni variables de `--write-out`.** Ejecútalos. Skill
   `verificar-flags-curl`.
9. **Marca la versión mínima** de todo flag posterior a 7.81, con su alternativa.
10. **`-k` solo como antipatrón. Ningún secreto en la línea de comandos.**
11. **La tabla de tiempos suma 8 h exactas.** Si suma más, recorta el alcance,
    no maquilles la tabla.
12. **Diagramas en SVG.** Arte ASCII prohibido.

## Cierre de la tanda

```bash
bash scripts/verificar-enlaces.sh    # en verde
./scripts/verificar-semana.sh NN     # todas las comprobaciones en verde
```

Más el checklist completo del final de `.github/copilot-instructions.md`, y los
dos agentes de `.claude/agents/`. Después:

```
feat(week-NN): contenido completo de la Semana NN — <tema>
```

$input
