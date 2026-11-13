# Webgrafía — Semana 10

_Comprobado el 11 de noviembre de 2026: todos los enlaces resuelven._

Documentación de referencia. Se consulta, no se lee entera.

## Configuración e `init`

| Recurso | Por qué vale la pena |
|---|---|
| [Bash Reference Manual — Shell Parameter Expansion](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html) | `${!nombre}`, `${var:-defecto}` y el resto de expansiones de la teoría 02, con su definición exacta |
| [BashFAQ/006 — variables con nombre variable](https://mywiki.wooledge.org/BashFAQ/006) | Por qué `printf -v` y `${!clave}` en lugar de `eval`, con los casos en que `eval` ejecuta lo que no debe |
| [Bash Reference Manual — The Set Builtin](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html) | `-C` (`noclobber`) y `-e`, las dos opciones que más pesan esta semana |
| [open(2)](https://man7.org/linux/man-pages/man2/open.2.html) | `O_EXCL`: la garantía del kernel que hace a `noclobber` seguro con dos procesos |
| [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/latest/) | Dónde deberían vivir la configuración (`~/.config`) y los ejecutables del usuario (`~/.local/bin`) |

## Tests

| Recurso | Por qué vale la pena |
|---|---|
| [bats-core — Gotchas](https://bats-core.readthedocs.io/en/stable/gotchas.html) | Las trampas conocidas de bats, la del `!` incluida. Léelo antes de que una te cueste una tarde |
| [bats-core — CHANGELOG](https://github.com/bats-core/bats-core/blob/master/docs/CHANGELOG.md) | Desde qué versión existe cada función. La tabla de la teoría 04 sale de aquí |
| [Test Anything Protocol](https://testanything.org/) | El formato de la salida de bats, que entienden muchas otras herramientas |
| [Martin Fowler — Test Double](https://martinfowler.com/bliki/TestDouble.html) | Stubs, fakes y mocks: el vocabulario para cuando `/bin/true` en lugar del toolkit se quede corto |
| [ShellCheck — wiki](https://www.shellcheck.net/wiki/) | Cada aviso de shellcheck explicado, con el ejemplo que lo dispara y su arreglo |

## Documentar e instalar

| Recurso | Por qué vale la pena |
|---|---|
| [Semantic Versioning 2.0.0](https://semver.org/lang/es/) | Qué significa cada número de `1.0.0`, y qué cambio obliga a subir cuál |
| [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) | El formato del `CHANGELOG` de la teoría 06, con sus grupos y por qué se escribe para personas |
| [GNU Coding Standards — Command-Line Interfaces](https://www.gnu.org/prep/standards/html_node/Command_002dLine-Interfaces.html) | Las convenciones de `--help` y `--version` que siguen casi todas las herramientas de Unix |
| [install — GNU coreutils](https://www.gnu.org/software/coreutils/manual/html_node/install-invocation.html) | Todas las opciones de `install`; recuerda que `-D` no existe en macOS |
| [Pro Git — Etiquetado](https://git-scm.com/book/es/v2/Fundamentos-de-Git-Etiquetado) | Etiquetas anotadas frente a ligeras, y cómo se empujan |

## Integración continua

| Recurso | Por qué vale la pena |
|---|---|
| [GitHub Actions — Workflow syntax](https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions) | La referencia de cada clave del YAML: `on`, `permissions`, `strategy`, `container`, `timeout-minutes` |
| [GitHub Actions — Running jobs in a container](https://docs.github.com/en/actions/using-jobs/running-jobs-in-a-container) | Cómo funciona `container:` y qué cambia dentro (eres root, la imagen viene casi vacía) |
| [GitHub Actions — Security hardening](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions) | Por qué fijar las acciones por SHA, cómo tratar los secretos y qué puede hacer una acción comprometida |
| [GitHub Actions — Automatic token authentication](https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication) | Qué puede hacer el `GITHUB_TOKEN` y cómo lo limita el bloque `permissions` |
| [actions/runner-images](https://github.com/actions/runner-images) | Qué runners existen, qué traen y cuándo se retiran. Ahí se anunció la retirada de Ubuntu 22 |
| [actionlint](https://github.com/rhysd/actionlint) | Revisa un workflow antes de empujarlo: sintaxis, expresiones y errores frecuentes |
| [gh run watch](https://cli.github.com/manual/gh_run_watch) | Seguir un run de la CI desde la terminal, y salir con su código |

## El laboratorio y el bootcamp

| Recurso | Por qué vale la pena |
|---|---|
| [bats-core](https://github.com/bats-core/bats-core) | El repositorio de bats: instalación desde el código si tu sistema no lo trae |
| [Command Line Interface Guidelines — Distribution](https://clig.dev/#distribution) | Cómo distribuir una CLI: un archivo, sin dependencias, y fácil de quitar |

---

| Anterior | Siguiente |
|---|---|
| [Videografía](../videografia/README.md) | [Glosario](../../5-glosario/README.md) |
