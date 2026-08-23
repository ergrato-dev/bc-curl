# Contribuir

Gracias por el interés. Este repositorio es material educativo, así que lo que más ayuda no es siempre código.

---

## Qué aporta más

| Tipo | Por qué importa |
|---|---|
| **Un flag que no existe o cambió de versión** | curl lleva veinticinco años acumulando opciones. Un ejemplo que revienta al ejecutarlo es el peor fallo posible aquí |
| **Un paso que no se entiende** | Si tuviste que releerlo tres veces, el problema es del texto |
| **Un error real con su solución** | Alimenta la tabla "Si algo sale mal" de la práctica correspondiente |
| **Una diferencia de versión** | "Esto necesita curl 7.82" ahorra una hora a quien venga detrás |
| **Un truco** | Si te ahorró tiempo, ahorrará el de otro |

Para todo eso, un [issue](https://github.com/ergrato-dev/bc-curl/issues) es suficiente. No hace falta que abras un pull request.

---

## Pull requests

Se aceptan, pero ten en cuenta que este repositorio **cierra automáticamente los PR externos** y continúa la conversación en el issue. No es desconfianza: el material se escribe en tandas de una semana completa y un cambio suelto suele descolocar la coherencia entre teoría, prácticas, rúbrica y `checks.json`.

Abre primero un issue. Si el cambio encaja, se te dirá por dónde entrarlo.

---

## Si escribes contenido

Las convenciones completas están en [`.github/copilot-instructions.md`](.github/copilot-instructions.md). El resumen:

- **Un archivo, un concepto.** Si el título necesita una "y", probablemente son dos archivos.
- **Extensión de un archivo de teoría: 200-300 líneas.** Si se pasa, es que mezcla dos temas: divídelo, no recortes.
- **Siempre el porqué antes del comando.** Un comando sin motivo es una receta, no formación.
- **Todo paso termina en una verificación** que el lector pueda ejecutar.
- **No inventes flags ni variables de `--write-out`.** Compruébalo contra `curl --help all` o el [manpage oficial](https://curl.se/docs/manpage.html) antes de escribirlo.
- **Marca la versión mínima** de todo flag que no sea universal: `--json` es 7.82+, `--fail-with-body` 7.76+, `--http3` requiere un build con HTTP/3.
- **Nunca un token con formato válido**, ni real ni inventado. Usa `<TOKEN>` o `$API_TOKEN`.
- **`-k` / `--insecure` solo aparece en la sección de antipatrones.** Nunca como el camino fácil.
- **Los ejemplos de producción llevan `--fail-with-body`, `--max-time` y `--retry`.** El ejemplo sin ellos solo existe como contraste.
- **Los diagramas son SVG.** Nada de arte ASCII.
- **Código y nombres de identificadores en inglés; documentación y comentarios educativos en español.**

Antes de proponer nada:

```bash
bash scripts/verificar-enlaces.sh
```

Tiene que salir en verde.

---

## Mensajes de commit

Conventional Commits, en español, con el ámbito de la semana:

```
feat(week-07): contenido completo de la Semana 07 — scripting bash con curl
fix(week-04): corregir el ejemplo de multipart en la practica 03
docs: actualizar la matriz de versiones de curl
```

---

## Código de conducta

Participar implica aceptar el [Código de Conducta](CODE_OF_CONDUCT.md).

---

[← Volver al README principal](README.md)
