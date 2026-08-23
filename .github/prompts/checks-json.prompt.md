---
name: "checks.json"
description: "Genera el checks.json de una semana del Bootcamp curl: comprobaciones declarativas que ejecuta scripts/verificar-semana.sh contra el laboratorio local y el script del alumno."
argument-hint: "Semana (ej: 04) y qué tiene que saber hacer api-toolkit al terminarla"
mode: "agent"
---

# checks.json — Bootcamp curl

**Se escribe antes que el contenido.** Define qué es entregable, y por tanto qué
tienen que enseñar las prácticas. Escrito después, se convierte en un resumen de
lo que ya se escribió.

Contrato completo: [`docs/autograding.md`](../../docs/autograding.md).

## Formato

```json
{
  "semana": "NN",
  "titulo": "Titulo de la semana, sin tildes",
  "checks": [
    {
      "id": "kebab-case-estable",
      "descripcion": "Que se comprueba, en una linea",
      "cmd": "comando bash desde la raiz del repositorio",
      "assert": "exit0",
      "pista": "2-practicas/NN-archivo.md, paso N"
    }
  ]
}
```

### Campos

| Campo | Regla |
|---|---|
| `id` | kebab-case, estable. **Nunca se renombra** |
| `descripcion` | Una línea, sin tildes. **Se copia literal** al `3-proyecto/README.md` |
| `cmd` | Bash. Se ejecuta desde la raíz del repositorio |
| `assert` | `exit0`, `exit!=0`, `exit=N`, `stdout~RE`, `stdout!~RE` |
| `pista` | Archivo **y** paso donde se arregla |

### Marcadores

`{raiz}` `{semana}` `{lab}` `{lab_tls}` `{lab_oauth}` `{ca}` — se sustituyen
antes de ejecutar, para que el archivo no dependa de rutas ni de puertos.

## Reglas duras

- **6 a 18 comprobaciones**, creciendo con la complejidad de la semana.
- **Una comprobación, un hecho.** Si la descripción necesita una "y", son dos.
- **La comprobación no puede pasar por accidente.** `test -f script.sh` se
  cumple con un archivo vacío: comprueba comportamiento, no existencia.
- **Cada comprobación se ejecuta a mano antes de escribirla**, con un caso que
  pasa y otro que falla. Si no distingue los dos, no vale.
- **Verifica que falla antes del trabajo y pasa después.** Una comprobación que
  nunca ha estado en rojo no se ha probado.
- **Cero lógica de la semana en `verificar-semana.sh`.** Si necesita código
  imperativo, el entregable no es verificable: va a rúbrica manual.

## Patrones que funcionan bien en este bootcamp

```json
{ "id": "detecta-error-http",
  "descripcion": "El script sale distinto de 0 cuando la API responde 503",
  "cmd": "bash {semana}/3-proyecto/starter/api-toolkit.sh get {lab}/status/503",
  "assert": "exit!=0",
  "pista": "1-teoria/02-fail-y-fail-with-body.md" }
```

```json
{ "id": "sin-secreto-en-linea-de-comandos",
  "descripcion": "Ningun curl del script lleva la credencial escrita en la linea de comandos",
  "cmd": "grep -nE '(Authorization: *(Bearer|Basic)|-u +[^$]) +[A-Za-z0-9]' {semana}/3-proyecto/starter/*.sh",
  "assert": "exit!=0",
  "pista": "1-teoria/07-no-filtrar-la-credencial.md" }
```

```json
{ "id": "no-se-cuelga",
  "descripcion": "El script no se queda colgado cuando el servidor tarda demasiado",
  "cmd": "timeout 20 bash {semana}/3-proyecto/starter/api-toolkit.sh get {lab}/delay/10",
  "assert": "exit!=124",
  "pista": "1-teoria/05-timeouts-y-reintentos.md" }
```

```json
{ "id": "shellcheck-limpio",
  "descripcion": "El script pasa shellcheck sin avisos",
  "cmd": "shellcheck -S warning {semana}/3-proyecto/starter/*.sh",
  "assert": "exit0",
  "pista": "3-proyecto/README.md, criterios de calidad" }
```

$input
