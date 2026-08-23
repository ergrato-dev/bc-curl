# Proyecto Semana 10 — `api-toolkit` entregable

> Nueve semanas de capas sueltas se convierten en una herramienta que instalas
> en tu `PATH` y usas mañana sin acordarte de cómo está hecha por dentro.

---

## 🎯 Objetivo

Cerrar `api-toolkit`: configuración persistente, tests que corren solos,
documentación que alguien más pueda seguir, y un pipeline de CI que lo
verifique en cada cambio.

No hay conceptos nuevos. Todo lo que se usa aquí se aprendió entre la Semana 01
y la 09. Lo que se aprende esta semana es **cómo se entrega**.

---

## 📦 Qué añade esta capa

La capa 9 dejó un script que hace muchas cosas y que solo sabe usar quien lo
escribió. Esta capa lo convierte en un producto:

| Antes (capa 9) | Después (capa 10) |
|---|---|
| Variables al principio del archivo | `api-toolkit init` escribe `~/.api-toolkit/config` |
| Se prueba ejecutándolo a mano | `bats` cubre los caminos críticos |
| Sabes usarlo porque lo escribiste | `--help` y un `README` que se lee en cinco minutos |
| Corre en tu máquina | Corre en CI en cada push |
| Los errores se ven en pantalla | Log estructurado en `~/.api-toolkit/requests.log` |

Es la última capa: no desbloquea nada porque ya no hay semana siguiente. Lo que
desbloquea es que puedas enseñárselo a alguien.

---

## ✅ Requisitos verificables

> Estos requisitos son copia literal de las descripciones de `checks.json`. Si
> una comprobación sale en ❌, la frase que ves aquí es la misma que verás allí.

- [ ] `api-toolkit.sh` existe, es ejecutable y arranca con `set -euo pipefail`
- [ ] `--help` lista todos los subcomandos implementados y sale con codigo 0
- [ ] `init` crea `~/.api-toolkit/config` con permisos 600
- [ ] El script lee la configuracion del archivo, no de constantes en el codigo
- [ ] `--dry-run` imprime la peticion que haria y no la ejecuta
- [ ] `get` sale distinto de 0 cuando la API responde 503
- [ ] `get` no se queda colgado cuando el servidor tarda mas que el timeout
- [ ] Ningun curl del script lleva la credencial escrita en la linea de comandos
- [ ] El script pasa shellcheck -S warning sin avisos
- [ ] Existe un archivo de tests bats y todos sus casos pasan
- [ ] El README del proyecto documenta instalacion, configuracion y cada subcomando
- [ ] El workflow de CI ejecuta shellcheck y los tests bats

---

## 🎨 Criterios de calidad

Lo que el autograding no ve y la rúbrica sí:

- **Los mensajes de error sirven para algo.** `Error: falta el token` es inútil;
  `Error: no hay token guardado. Ejecuta 'api-toolkit auth login'` es una
  instrucción.
- **Las funciones tienen un nombre que dice lo que hacen** y hacen solo eso.
- **No hay código muerto.** Ni funciones que nadie llama, ni flags que no se
  procesan, ni ramas `else` vacías.
- **El `--help` no miente.** Todo lo que lista existe; todo lo que existe está
  listado.
- **La configuración tiene precedencia clara y documentada**: flag de línea de
  comandos > variable de entorno > archivo de configuración > valor por defecto.
- **Los secretos no aparecen nunca en la salida**, ni con `--verbose`.

---

## 💡 Adaptación a tu dominio

| Dominio | Cómo se concreta esta capa |
|---|---|
| **GitHub** | `init` pide el token con scopes; `monitor` vigila el `rate_limit`; los tests usan el laboratorio, no la API real |
| **Clima (Open-Meteo)** | Sin autenticación: `init` solo pide la URL base y las coordenadas por defecto; el CI puede correr contra la API real porque no hay credencial |
| **Transporte (TfL)** | `init` guarda la API key; el log estructurado registra qué línea se consultó, útil para depurar por qué una consulta salió vacía |
| **Cine (TMDB)** | `download` guarda pósters; los tests comprueban que el nombre de archivo se deriva del `Content-Disposition` |

---

## 🚦 Cómo entregarlo

1. Tu copia de `api-toolkit.sh` vive en **tu** repositorio, no en este.
2. Estructura mínima de la entrega:

   ```
   api-toolkit/
   ├── api-toolkit.sh
   ├── README.md
   ├── tests/
   │   └── api-toolkit.bats
   └── .github/workflows/ci.yml
   ```

3. Levanta el laboratorio y pasa el autograding:

   ```bash
   ./scripts/start.sh
   ./scripts/verificar-semana.sh 10
   ```

4. Commit final:

   ```
   feat(week-10): api-toolkit completo con tests, docs y CI
   ```

---

## 🧯 Errores comunes

| Síntoma | Causa | Solución |
|---|---|---|
| Los tests pasan en tu máquina y fallan en CI | El runner no tiene el laboratorio levantado | Levanta los servicios como `services:` del job, o marca esos tests como de integración |
| `init` deja el config con permisos 644 | `touch` antes de `chmod` deja la ventana abierta | `umask 077` antes de crear el archivo, o `install -m 600 /dev/null "$config"` |
| `--dry-run` ejecuta la petición igualmente | La comprobación está después del `curl`, no antes | El `if $DRY_RUN` va antes de construir la llamada, no dentro de ella |
| El script funciona con `bash` y falla con `sh` | Estás usando bashismos con shebang genérico | El shebang es `#!/usr/bin/env bash`. No lo cambies |
| `shellcheck` se queja de `$VAR` sin comillas | Es un aviso real: una ruta con espacios rompe el script | Comillas siempre: `"$VAR"` |
| El token aparece en el log | Se registra el comando completo | Registra método, ruta y código, nunca los headers |

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [Semana 09 — HTTP/2, paralelismo y rendimiento](../../week-09-http2_paralelismo_performance/README.md) | **Semana 10 — Proyecto final** | — |

[← Volver a la Semana 10](../README.md) · [↑ Inicio del bootcamp](../../../README.md)
