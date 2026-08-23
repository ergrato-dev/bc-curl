---
name: "Nueva práctica"
description: "Genera un archivo de práctica del Bootcamp curl: pasos con Por qué / Comando / Verifica, contra el laboratorio local, cerrando con Resultado y Si algo sale mal."
argument-hint: "Semana (ej: 05), nombre del archivo (ej: 02-cookies-y-sesion.md) y qué debe conseguir el alumno"
mode: "agent"
---

# Nueva práctica — Bootcamp curl

Antes de escribir, lee [`.github/copilot-instructions.md`](../copilot-instructions.md).

## Estructura obligatoria

````markdown
# Práctica NN — Título

> Una línea: qué vas a conseguir.

**Duración estimada**: XX min
**Prerrequisitos**: el laboratorio levantado (`./scripts/start.sh`) y ...

## Contexto

Dos párrafos: en qué situación real aparece esto.

## Paso 1: Título del paso

**Por qué**: el motivo. Sin esto, el paso es una receta.

**Comando**:

```bash
# El comentario explica lo que no se ve en el comando.
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/get
```

**Verifica**:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/get
# 200
```

## Paso 2: ...

## ✅ Resultado

- [ ] Lo que tiene que ser cierto al terminar
- [ ] ...

```bash
./scripts/verificar-semana.sh NN
```

## 🧯 Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|

## 🔗 Navegación
````

## Reglas duras

- **200-380 líneas.** Si te pasas, probablemente son dos prácticas.
- **Todo paso termina en una verificación ejecutable.** Sin excepción.
- **Toda salida esperada va comentada** debajo del comando.
- **Los pasos van contra el laboratorio local**, no contra servicios externos.
- **Ocho o nueve pasos como mucho.** Más es una práctica que no cabe en su hora.
- **Advertencia antes de lo destructivo**, con el respaldo delante.
- ❌ **Nada de `# TODO:`.** El `TODO` es formato de `3-proyecto/starter/`.
- ❌ **Nada de `-k`** salvo para enseñar por qué no se usa.
- Los pasos se numeran desde `## Paso 1`; el `Paso 0` se reserva para
  preparación del entorno cuando haga falta.

$input
