---
name: "Nuevo proyecto de semana"
description: "Genera el 3-proyecto/README.md de una semana del Bootcamp curl: la capa que esa semana añade a api-toolkit, con los requisitos copiados literalmente del checks.json."
argument-hint: "Semana (ej: 08) y qué capa añade a api-toolkit"
mode: "agent"
---

# Nuevo proyecto de semana — Bootcamp curl

El proyecto **no es un script nuevo**: es la capa que esta semana añade a
`api-toolkit`, el CLI hilo conductor. Lee
[`docs/proyecto-hilo-conductor.md`](../../docs/proyecto-hilo-conductor.md) antes
de escribir, y comprueba qué capa te toca en su tabla.

## Antes de escribir

El `checks.json` de la semana **ya tiene que existir**. Léelo:

```bash
jq -r '.checks[].descripcion' bootcamp/week-NN-*/checks.json
```

Esas líneas se copian **palabra por palabra** a `## ✅ Requisitos verificables`.
Si no coinciden, el alumno ve un ❌ y no sabe a qué requisito corresponde.

## Estructura obligatoria: ocho secciones

````markdown
# Proyecto Semana NN — <Nombre de la capa>

> Una línea: qué sabrá hacer `api-toolkit` al terminar y no sabía antes.

## 🎯 Objetivo

## 📦 Qué añade esta capa

Cómo encaja con la capa de la semana anterior y qué desbloquea en la siguiente.

## ✅ Requisitos verificables

Copia literal de las descripciones del `checks.json`, como lista de casillas.

## 🎨 Criterios de calidad

Lo que el autograding no ve: legibilidad, nombres, ausencia de código muerto,
mensajes de error que sirven para algo.

## 💡 Adaptación a tu dominio

| Dominio | Cómo se concreta esta capa |
|---|---|

Tres o cuatro dominios de los de `docs/proyecto-hilo-conductor.md`.

## 🚦 Cómo entregarlo

## 🧯 Errores comunes

| Síntoma | Causa | Solución |
|---|---|---|

## 🔗 Navegación
````

## El `starter/`

Va en `3-proyecto/starter/`, es el **único** sitio del repositorio con código de
partida, y **nunca es la solución**:

- `#!/usr/bin/env bash` y `set -euo pipefail`
- Bit de ejecución (`chmod +x`)
- Cabecera de comentario con el uso y los subcomandos
- **Un `# TODO:` numerado por cada hueco**, con una frase de qué se espera
- `shellcheck -S warning` limpio sobre el esqueleto tal como se entrega

Ejemplo del formato de hueco:

```bash
# TODO 3: capturar el codigo de estado sin descartar el cuerpo.
#         Pista: --write-out con %{http_code} y un separador que puedas cortar.
codigo=""
```

## Reglas duras

- **Los requisitos verificables son copia literal del `checks.json`.**
- **El proyecto se apoya en la capa anterior.** Si la capa N necesita algo que
  ninguna semana anterior enseñó, el problema es la capa, no el alumno.
- **No pidas nada que no esté en la teoría o las prácticas de esta semana** o
  de una anterior.
- El proyecto ocupa unas **2 h** de las 8 de la semana. Si pide más, recorta el
  alcance.

$input
