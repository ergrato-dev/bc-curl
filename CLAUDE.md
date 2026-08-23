# CLAUDE.md — bc-curl

Bootcamp curl Zero to Hero (10 semanas, 80 h, ergrato-dev). Trata **curl como la
herramienta con la que se opera y se depura HTTP**, no como el atajo para bajar
un archivo. Nivel de salida: capaz de hablar con cualquier API REST, depurar TLS
sin GUI y escribir scripts bash de producción. Modalidad: **autoestudio
asincrónico**, 8 h/semana.

Las convenciones de contenido pedagógico (estructura de semana, tono, plantillas,
checklist de nueva semana, paleta de los SVG) viven en
[`.github/copilot-instructions.md`](.github/copilot-instructions.md) — léelo
antes de crear o editar contenido de cualquier semana. No se duplican aquí.

## Prompts reutilizables

`.github/prompts/` tiene plantillas para tareas recurrentes — úsalas en vez de
generar contenido libre: `nueva-semana`, `nueva-teoria`, `nueva-practica`,
`nuevo-proyecto`, `checks-json`, `svg-diagrama`, `commit-message`.

## Skills y agentes

`.claude/skills/`: `verificar-estructura` (enlaces, navegación y lo que el script
no ve), `verificar-flags-curl` (que cada flag y cada variable de `-w` existan de
verdad y desde qué versión), `sincronizar-trucos` (README de semana ↔
`docs/trucos-curl.md`).

`.claude/agents/`: `curriculo-coherencia-reviewer` (malla ↔ semanas ↔ 8 h),
`seguridad-contenido-reviewer` (tokens, `-k`, secretos en la línea de comandos,
scripts sin `set -euo pipefail`).

## Estructura por semana

```
week-XX-tema/
├── README.md · rubrica-evaluacion.md (30% conocimiento / 40% desempeño / 30% producto)
├── checks.json (autograding declarativo contra el laboratorio local)
├── 0-assets/ · 1-teoria/ · 2-practicas/ · 3-proyecto/ · 4-recursos/ · 5-glosario/
```

## Reglas que rompen fácil

- **No inventes flags, opciones largas ni variables de `--write-out`.** Es el
  fallo más probable en este repo: una opción plausible que no existe, o una
  variable de `-w` con nombre parecido al real (`%{time_total}` existe,
  `%{total_time}` no). Compruébalo con `curl --help all`, con
  `curl --manual`, o contra el [manpage](https://curl.se/docs/manpage.html).
  Usa el skill `verificar-flags-curl`.
- **Marca la versión mínima de todo flag que no sea universal.** curl lleva
  veinticinco años acumulando opciones y la distribución del alumno va por
  detrás: Ubuntu 22.04 trae **7.81**, que no tiene `--json`. La tabla completa
  está en [`docs/versiones-de-curl.md`](docs/versiones-de-curl.md). Si un
  ejemplo necesita algo posterior a 7.81, dilo en el propio ejemplo y da la
  alternativa larga.
- **`-k` / `--insecure` solo aparece en la sección de antipatrones.** Nunca como
  el camino fácil para que el ejemplo funcione. Si el certificado no valida, la
  respuesta es `--cacert`, no apagar la verificación.
- **Nunca un token con formato válido**, ni falso. `ghp_` o `sk_live_` más
  caracteres dispara los detectores de secretos. Usa `<TOKEN>` o `$API_TOKEN`.
- **Ningún secreto en la línea de comandos de un ejemplo.** Es visible en `ps`,
  en el historial y en los logs. Variable de entorno, `--netrc`, o
  `--header @archivo`.
- **Todo ejemplo de producción lleva `--fail-with-body`, `--max-time` y
  `--retry`.** curl sale con 0 ante un 500: un script sin `--fail` se traga los
  errores del servidor. El ejemplo sin esos flags solo existe como contraste
  explícito.
- **Las prácticas apuntan al laboratorio local**, no a `httpbin.org`. El
  servicio externo se cae, limita por IP y cambia. Las APIs públicas
  (`api.github.com`, `jsonplaceholder`) se usan solo cuando el punto pedagógico
  *es* hablar con una API real, y siempre con el laboratorio como alternativa.
- **`docker compose` es el único método de instalación del laboratorio.** Y
  **nunca `:latest`**: versión completa siempre (`2.25.0`, `2.11.4-alpine`),
  aunque hoy apunte a la misma imagen. `latest` convierte cada `pull` en un
  cambio de versión que nadie decidió.
- **Un solo CLI hilo conductor.** `api-toolkit` crece las diez semanas; no hay
  un script desechable por semana. Ver
  [`docs/proyecto-hilo-conductor.md`](docs/proyecto-hilo-conductor.md).
- **Todo `starter/*.sh` lleva `#!/usr/bin/env bash`, `set -euo pipefail`, bit de
  ejecución y `TODO`s.** El `starter/` es el punto de partida, nunca la
  solución. `shellcheck` limpio antes de comitear.
- **Si un entregable no se puede verificar, no es entregable obligatorio** — va
  a la rúbrica manual. Nunca metas lógica bash específica de una semana en
  `verificar-semana.sh`; declara la comprobación en `checks.json`.
- **La tabla de tiempos del README de cada semana suma 8 h exactas.** Si suma
  más, la semana está sobrecargada: se recorta el alcance, no se maquilla la
  tabla.
- **Diagramas en SVG, nunca arte ASCII.** Paleta y reglas en la guía de autoría.
- Antes de cerrar cualquier cambio: `bash scripts/verificar-enlaces.sh` sin
  errores. Los enlaces desde `bootcamp/week-NN/README.md` a la raíz son
  `../../README.md` (2 niveles).

## Ritmo de trabajo

Una semana por tanda, de la 01 a la 10. La tanda termina con
`bash scripts/verificar-enlaces.sh` en verde y un commit:

```
feat(week-NN): contenido completo de la Semana NN — <tema>
```

## Enlaces

- [docs/](docs/README.md) — setup, hilo conductor, autograding, versiones, trucos, glosario
- [Checklist de nueva semana](.github/copilot-instructions.md) (sección final)
