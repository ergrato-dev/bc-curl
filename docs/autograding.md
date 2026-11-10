# Autograding

`scripts/verificar-semana.sh` te dice qué te falta antes de entregar. No sabe
nada de ninguna semana en concreto: lee `bootcamp/week-NN-*/checks.json` y
ejecuta lo que ahí ponga.

---

## Uso

```bash
./scripts/verificar-semana.sh --doctor   # comprueba tu entorno
./scripts/verificar-semana.sh 03         # comprueba la Semana 03
```

Salida:

```
Semana 03 — Autenticación básica

  ✅ api-toolkit.sh existe, es ejecutable y arranca con set -euo pipefail
  ✅ Una password incorrecta hace salir al script con el codigo 77
  ❌ El token no aparece en la linea de comandos de ningun proceso curl
     pista: 2-practicas/02-sacar-la-credencial-de-la-linea.md, paso 6

  16/17 comprobaciones superadas.
```

Sale con 0 si pasan todas, con 1 si falla alguna. **Cada pista dice en qué
práctica y en qué paso se arregla**: si una pista no lleva ahí, es un fallo del
material y merece un issue.

---

## Formato de `checks.json`

Un archivo por semana, en la raíz de la carpeta de la semana.

```json
{
  "semana": "03",
  "titulo": "Autenticacion basica",
  "checks": [
    {
      "id": "toolkit-ejecutable",
      "descripcion": "api-toolkit.sh existe, es ejecutable y arranca con set -euo pipefail",
      "cmd": "test -x {semana}/3-proyecto/starter/api-toolkit.sh",
      "assert": "exit0",
      "pista": "3-proyecto/README.md, paso 1"
    },
    {
      "id": "toolkit-basic-auth-credencial-mala",
      "descripcion": "Una password incorrecta hace salir al script con el codigo 77",
      "cmd": "AUTH_MODE=basic API_USER=user API_PASSWORD=incorrecta bash {semana}/3-proyecto/starter/api-toolkit.sh get /basic-auth/user/password",
      "assert": "exit=77",
      "pista": "2-practicas/04-cuando-la-credencial-falla.md, paso 5"
    }
  ]
}
```

### Campos

| Campo | Obligatorio | Qué es |
|---|:--:|---|
| `id` | sí | Identificador estable en kebab-case. **Nunca se renombra**: se usa para seguir una comprobación entre versiones |
| `descripcion` | sí | Qué se comprueba, en una línea. **Se copia literal** a `3-proyecto/README.md` |
| `cmd` | sí | Comando bash que se ejecuta desde la raíz del repositorio |
| `assert` | sí | Qué tiene que cumplirse. Ver la tabla siguiente |
| `pista` | sí | Archivo y paso donde se arregla |

### Aserciones

| `assert` | Se cumple si |
|---|---|
| `exit0` | el comando sale con código 0 |
| `exit!=0` | el comando sale distinto de 0 |
| `exit=N` | el comando sale exactamente con el código `N` |
| `stdout~RE` | la salida casa con la expresión regular extendida `RE` |
| `stdout!~RE` | la salida **no** casa con `RE` |

Cualquier otra cosa se reporta como aserción desconocida y la comprobación
cuenta como fallida. No falla en silencio.

> [!IMPORTANT]
> **Las expresiones regulares no pueden llevar `\`.** El verificador lee los
> campos con `jq @tsv`, que escapa la barra invertida, así que `\b200\b` llega
> a `grep -E` como `\\b200\\b` y no casa nunca. En su lugar: `.` para un
> carácter cualquiera y `(^|[^0-9])200([^0-9]|$)` para lo que sería `\b`.

### Marcadores

Se sustituyen antes de ejecutar el comando, para que el `checks.json` no dependa
de rutas ni de puertos:

| Marcador | Se sustituye por |
|---|---|
| `{raiz}` | Ruta absoluta del repositorio |
| `{semana}` | Ruta de la carpeta de la semana, p. ej. `bootcamp/week-03-autenticacion_basica` |
| `{lab}` | `http://localhost:8080` (o `$LAB_URL`) |
| `{lab_tls}` | `https://localhost:8443` (o `$LAB_TLS_URL`) |
| `{lab_mtls}` | `https://localhost:8444`, el frontal que exige certificado de cliente (o `$LAB_MTLS_URL`) |
| `{lab_oauth}` | `http://localhost:8081/default` (o `$LAB_OAUTH_URL`) |
| `{ca}` | Ruta a `docs/lab-ca.pem` (o `$LAB_CA`) |

---

## Reglas de diseño

1. **El `checks.json` se escribe antes que el contenido.** Define qué es
   entregable, y por tanto qué tienen que enseñar las prácticas. Escrito
   después, se convierte en un resumen de lo que ya se escribió.
2. **Entre 6 y 18 comprobaciones**, creciendo con la complejidad de la semana.
3. **Una comprobación, un hecho.** Si la descripción necesita una "y", son dos
   comprobaciones. Cuando fallan tres cosas a la vez, el alumno tiene que ver
   tres cruces, no una.
4. **`descripcion` se copia palabra por palabra** a
   `3-proyecto/README.md § ✅ Requisitos verificables`. Si no coinciden, el
   alumno no sabe qué le falta cuando algo sale en rojo.
5. **Cero lógica bash de la semana en `verificar-semana.sh`.** Si una
   comprobación necesita código imperativo, el entregable no es verificable:
   va a la rúbrica manual.
6. **La comprobación no puede pasar por accidente.** `test -f script.sh` se
   cumple con un archivo vacío. Comprueba comportamiento, no existencia, siempre
   que puedas.

---

## Lo que sí se puede comprobar

curl no deja estado en un servidor, así que aquí no hay una API a la que
preguntar "¿lo hizo?". Lo que hay es el script del alumno y el laboratorio, y
con eso se llega bastante lejos:

```json
{ "id": "usa-fail-with-body",
  "descripcion": "El script detecta los errores HTTP en vez de tragarselos",
  "cmd": "bash {semana}/3-proyecto/starter/api-explorer.sh {lab}/status/503",
  "assert": "exit!=0",
  "pista": "2-practicas/04-provocar-status-codes.md, paso 5" }
```

```json
{ "id": "sin-token-en-linea-de-comandos",
  "descripcion": "Ningun curl del script lleva el token escrito en la linea de comandos",
  "cmd": "grep -nE 'Authorization: *(Bearer|Basic) +[A-Za-z0-9]' {semana}/3-proyecto/starter/*.sh",
  "assert": "exit!=0",
  "pista": "1-teoria/07-variables-de-entorno.md" }
```

```json
{ "id": "shellcheck-limpio",
  "descripcion": "El script pasa shellcheck sin avisos",
  "cmd": "shellcheck -S warning {semana}/3-proyecto/starter/*.sh",
  "assert": "exit0",
  "pista": "3-proyecto/README.md, criterios de calidad" }
```

```json
{ "id": "respeta-el-timeout",
  "descripcion": "El script no se cuelga cuando el servidor tarda demasiado",
  "cmd": "timeout 20 bash {semana}/3-proyecto/starter/api-explorer.sh {lab}/delay/10",
  "assert": "exit!=124",
  "pista": "1-teoria/05-timeouts.md" }
```

## Lo que no se puede comprobar

- Que el código sea **legible**. Eso es rúbrica manual.
- Que el alumno **entienda** lo que escribió. Eso son las preguntas de la
  rúbrica.
- Que la elección de diseño sea **la buena**. Un script feo que pasa todas las
  comprobaciones sigue siendo un script feo, y la rúbrica lo refleja.

Por eso el Producto vale 30% y solo 60 de sus 100 puntos son automáticos.

---

## Escribir una comprobación nueva

1. Ejecuta el comando **a mano** contra el laboratorio, con un caso que pasa y
   con un caso que falla. Si no distingue los dos, la comprobación no vale.
2. Comprueba el código de salida con `echo $?`.
3. Añádela al `checks.json` con su `pista`.
4. Copia la `descripcion` al `3-proyecto/README.md`.
5. Corre `./scripts/verificar-semana.sh NN` y verifica que **falla** antes de
   hacer el trabajo y **pasa** después. Una comprobación que nunca ha estado en
   rojo no se ha probado.

---

## Trampa

Puedes leer el `checks.json` y escribir el mínimo que lo satisface. Adelante: no
hay nota que defender aquí, esto es autoestudio.

Lo que estás cambiando es a quién engañas. El día que un despliegue se caiga
porque tu script se tragó un 503, la comprobación que te saltaste era
exactamente esa.

---

[← Volver a la documentación](README.md)
