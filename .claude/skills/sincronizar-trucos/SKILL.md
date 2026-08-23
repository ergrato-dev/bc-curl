---
name: sincronizar-trucos
description: Mantiene de acuerdo la sección `## 🎩 Trucos y atajos` del README de cada semana con su sección correspondiente en docs/trucos-curl.md. Usar al cerrar una semana y cada vez que se añada o edite un truco.
allowed-tools: Bash(grep*) Bash(diff*) Bash(sed*) Read Edit Grep Glob
---

# Sincronizar los trucos

Los trucos viven en dos sitios a propósito: en el README de la semana, donde el
alumno los encuentra cuando los necesita, y en `docs/trucos-curl.md`, que es el
cheatsheet acumulativo al que se vuelve después.

**La fuente de verdad es el README de la semana.** Si los dos difieren, gana el
README y se actualiza el cheatsheet, nunca al revés.

## Procedimiento

### 1. Extraer los trucos de la semana

```bash
sed -n '/^## 🎩 Trucos y atajos/,/^## /p' bootcamp/week-NN-*/README.md
```

Es una tabla `| Truco | Cómo |`.

### 2. Extraer la sección correspondiente del cheatsheet

```bash
sed -n '/^## Semana NN —/,/^## Semana /p' docs/trucos-curl.md
```

### 3. Comparar fila a fila

Tres resultados posibles por fila:

| Situación | Qué hacer |
|---|---|
| Está en el README y no en el cheatsheet | Añadirla al cheatsheet |
| Está en el cheatsheet y no en el README | Preguntar antes de borrar: puede ser un truco bueno que se cayó del README por error |
| Está en los dos con texto distinto | Copiar el del README al cheatsheet |

### 4. Comprobar el criterio de admisión

Antes de propagar un truco, que cumpla lo que pide la guía de autoría:

- ✅ Un flag poco conocido que ahorra tiempo de verdad
- ✅ Una forma de ver algo que la salida normal no enseña
- ❌ Repetir lo que ya explica la teoría de esa semana
- ❌ Trivialidades (`-o` guarda en un archivo)

Un truco que no cumple no se propaga: se reporta para que salga del README.

### 5. Comprobar que el truco funciona

Es un cheatsheet: si un comando de aquí falla, el daño es doble porque se copia
sin leer.

```bash
# Ejecutar el comando del truco contra el laboratorio
```

Si un truco depende de una versión de curl posterior a 7.81, la fila lo dice.

### 6. Mantener el orden

En `docs/trucos-curl.md` las secciones van en orden de semana, 01 a 10, después
de la sección "Antes de empezar". Una semana sin cerrar deja su marcador
`_Pendiente._`; no se borra la cabecera.

## Salida

Qué se cambió, en una línea por cambio:

```
docs/trucos-curl.md § Semana NN | AÑADIDO   | <truco>
docs/trucos-curl.md § Semana NN | ACTUALIZADO | <truco>
bootcamp/week-NN/README.md      | REPORTADO | <truco que no cumple el criterio>
```

Si no había nada que hacer: `OK: los trucos ya estaban sincronizados.`

## Reglas

- **Nunca edites el README de la semana desde aquí.** Es la fuente de verdad: si
  algo está mal ahí, se reporta.
- **No borres del cheatsheet sin preguntar.**
- **No inventes trucos** para rellenar una sección vacía. `_Pendiente._` es un
  estado válido.
