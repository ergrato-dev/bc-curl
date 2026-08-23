---
name: "Nueva teoría"
description: "Genera un archivo de teoría del Bootcamp curl con la estructura fija: qué problema resuelve, cómo funciona, cómo se usa, antipatrones, trucos. 200-300 líneas, con comandos ejecutables contra el laboratorio."
argument-hint: "Semana (ej: 07), nombre del archivo (ej: 03-manejo-de-errores.md) y el concepto a explicar"
mode: "agent"
---

# Nuevo archivo de teoría — Bootcamp curl

Antes de escribir, lee [`.github/copilot-instructions.md`](../copilot-instructions.md).

## Estructura obligatoria

````markdown
# Título del concepto

> Una línea: qué resuelve esto y por qué te importa.

![Descripción del diagrama](../0-assets/NN-nombre.svg)

## 🎯 Objetivos

- Objetivo verificable 1
- Objetivo verificable 2

## 1. Qué problema resuelve

El problema antes que la solución, con un caso concreto y con **lo que pasa si
no lo resuelves**.

## 2. Cómo funciona

### 2.1 Subtema

Tablas para comparar opciones. Bloques ✅/❌ para contrastar.

## 3. Cómo se usa

Comandos contra el laboratorio, cada uno con su salida esperada comentada.

## 4. Antipatrones

| Antipatrón | Por qué duele | Qué hacer en su lugar |
|---|---|---|

## 5. Trucos

## 📚 Recursos Adicionales

## ✅ Checklist de Verificación

- [ ] Casillas ejecutables contra el laboratorio
````

## Reglas duras

- **200-300 líneas.** Si te pasas, el archivo mezcla dos conceptos: divídelo.
- **Un archivo, un concepto.** Si el título necesita una "y", sospecha.
- **Todo comando se ejecuta contra el laboratorio** (`http://localhost:8080`,
  `https://localhost:8443`, `http://localhost:8081/default`), no contra
  `httpbin.org`.
- **Toda salida esperada va comentada debajo del comando.** El lector tiene que
  poder comparar sin ejecutar.
- **No inventes flags ni variables de `--write-out`.** Compruébalos con
  `curl --help all` y con el skill `verificar-flags-curl`.
- **Marca la versión mínima** de todo flag posterior a 7.81, y da la
  alternativa. Ver [`docs/versiones-de-curl.md`](../../docs/versiones-de-curl.md).
- **`-k` solo en la tabla de antipatrones.** Nunca para que un ejemplo funcione.
- **Ningún secreto en la línea de comandos**, ni de ejemplo.
- Diagramas en SVG, nunca arte ASCII. Si añades uno, enlázalo.

$input
