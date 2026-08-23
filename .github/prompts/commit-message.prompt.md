---
name: "Mensaje de commit"
description: "Genera un mensaje de commit en Conventional Commits, en español, con los tipos y ámbitos propios del Bootcamp curl."
argument-hint: "Qué se cambió (o deja que se deduzca del diff en el área de staging)"
mode: "agent"
---

# Mensaje de commit — Bootcamp curl

Genera **un solo** mensaje de commit. Sin alternativas, sin explicación alrededor.

## Formato

```
<tipo>(<ámbito>): <resumen en imperativo, minúscula, sin punto final>

<cuerpo opcional: qué cambió y por qué, no cómo>
```

El resumen no pasa de 72 caracteres.

## Tipos

| Tipo | Cuándo |
|---|---|
| `feat` | Contenido nuevo: una semana, un archivo de teoría, una práctica |
| `fix` | Corregir algo que estaba mal: un flag inexistente, un enlace roto, una versión mal atribuida |
| `docs` | Documentación transversal de `docs/`, README raíz, CONTRIBUTING |
| `chore` | Infraestructura del repo: compose, scripts, `.env.example`, imágenes |
| `refactor` | Reorganizar contenido sin cambiar lo que enseña |
| `style` | Formato, tipografía, tablas. Nunca cambia el significado |

## Ámbitos

- `week-01` … `week-10` para contenido de una semana concreta
- `bootcamp` para cambios que cruzan varias semanas
- `docs`, `scripts`, `lab`, `ci` para lo transversal
- Sin ámbito si el cambio es global

## Ejemplos

```
feat(week-07): contenido completo de la Semana 07 — scripting bash con curl
```

```
fix(week-06): corregir la variable de --write-out en la practica 02

El material usaba %{total_time}, que no existe: curl avisa por stderr y no
imprime nada. La variable correcta es %{time_total}.
```

```
chore(lab): fijar go-httpbin en 2.25.0 y caddy en 2.11.4-alpine
```

## Reglas

- **En español**, salvo el tipo, que es la palabra clave inglesa.
- **Imperativo**: "añade", "corrige", "separa". No "añadido" ni "añadiendo".
- El cuerpo explica **por qué**, no repite el diff.
- Una línea en blanco entre resumen y cuerpo, siempre.
- Si el cambio arregla algo que estaba mal en el material, el cuerpo dice **qué
  fallaba**: es la información que le sirve a quien lo lea dentro de un año.

$input
