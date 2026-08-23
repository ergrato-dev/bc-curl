# Tanda en curso — Semana 01

> Archivo temporal de traspaso. Se borra al cerrar la tanda.

## Estado

- Rama: `refactor/profundizacion`
- Último commit cerrado: `8ec9a8c chore: infraestructura de autoria, laboratorio y autograding` (Fase 0 completa)
- Plan aprobado: `~/.claude/plans/hicimos-refactor-de-profundizaci-n-delegated-pearl.md`

## Hecho en esta tanda (sin commitear)

- `checks.json` — 10 comprobaciones, todas ejecutadas a mano contra el laboratorio
- `README.md` de la semana — 10 secciones, tabla de tiempos cuadrada a 8 h
- `1-teoria/01-que-es-http.md` (240)
- `1-teoria/02-anatomia-de-la-url.md` (240)
- `1-teoria/03-instalacion-y-versiones.md` (242)
- `1-teoria/04-el-primer-get.md` (244)
- `1-teoria/05-los-flags-esenciales.md` (296)
- `1-teoria/06-codigos-de-estado.md` (260)

Todos los comandos de esos seis archivos se ejecutaron contra el laboratorio y
la salida comentada es la real.

## Pendiente para cerrar la Semana 01

1. `1-teoria/07-headers-http.md` (200-300 líneas)
2. `1-teoria/08-leer-la-traza-y-el-manual.md` (200-300 líneas)
3. **Borrar los archivos de teoría viejos**, ya absorbidos:
   - `01-que-es-http.md` es el nuevo, pero quedan `02-anatomia-url.md`,
     `03-instalacion-curl.md`, `04-primer-request-get.md`,
     `05-status-codes-y-headers.md`
4. `2-practicas/` — convertir a 4 archivos planos y borrar las carpetas
   `NN-ejercicio-*/`:
   - `01-conocer-tu-curl.md`
   - `02-el-primer-get.md`
   - `03-los-flags-esenciales.md`
   - `04-provocar-y-leer-status-codes.md`
5. `3-proyecto/README.md` (8 secciones) y `starter/api-explorer.sh` con TODOs,
   `shellcheck -S warning` limpio
6. `rubrica-evaluacion.md` al formato nuevo (10 preguntas en `<details>`,
   Producto 60 automático / 40 manual)
7. `4-recursos/` y `5-glosario/` actualizados
8. SVG nuevos en `0-assets/` para los archivos 05, 07 y 08; el resto ya están
   enlazados
9. Replicar los trucos en `docs/trucos-curl.md` y los términos en
   `docs/glosario-global.md`
10. Marcar la Semana 01 como ✅ en `bootcamp/README.md`
11. `bash scripts/verificar-enlaces.sh` en verde y
    `./scripts/verificar-semana.sh 01` con las 10 comprobaciones
12. Commit: `feat(week-01): contenido completo de la Semana 01 — HTTP y curl basico`

## Cómo retomar

```bash
cd /home/ergratodev/bc-channel/bc-curl
./scripts/start.sh                       # el laboratorio
./scripts/verificar-semana.sh --doctor
```

Convenciones: [`.github/copilot-instructions.md`](.github/copilot-instructions.md).
Checklist de cierre: al final de ese mismo archivo.

## Notas de la tanda

- `shellcheck` no está instalado en esta máquina. Se usó
  `docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:stable`.
- La comprobación `explorer-sin-todos` falla por diseño mientras el starter
  tenga TODOs. Es correcto: pasa cuando el alumno los resuelve.
