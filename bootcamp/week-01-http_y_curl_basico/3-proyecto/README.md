# Proyecto Semana 01 — `api-explorer.sh`

> La capa 1 de `api-toolkit`. Al terminar tendrás un script que consulta una
> lista de URLs, dice qué respondió cada una y en cuánto tiempo, y **falla
> cuando algo falla**.

---

## 🎯 Objetivo

Escribir un script bash que reciba una o varias URLs, haga una petición a cada
una y para cada una imprima el código de estado HTTP y el tiempo total de
respuesta. Al final, una línea de resumen. Y lo más importante: que el script
salga con un código distinto de 0 cuando alguna URL responde mal, para que quien
lo llame —un cron, un pipeline— se entere.

No es un ejercicio de bash. Es el primer trozo de la herramienta que vas a
tener escrita dentro de diez semanas.

---

## 📦 Qué añade esta capa

| | |
|---|---|
| **Viene de** | Nada: es la primera capa |
| **Añade** | Consultar endpoints y medir: código de estado, tiempo, y un veredicto |
| **Desbloquea** | La Semana 02 convierte `consultar_url` en `get`, `post`, `put` y `delete` con cuerpo JSON. La Semana 03 le añade la credencial. La Semana 07 le pone reintentos con backoff sobre este mismo bucle |

Lo que aprendes aquí y no vas a volver a tocar: que el código de salida de curl
y el código HTTP son cosas distintas, y que un script serio mira los dos.

Antes de empezar, si aún no lo has hecho, elige tu dominio:

```bash
echo "DOMINIO=github" >> ~/.bc-curl
chmod 600 ~/.bc-curl
```

Ver [`docs/proyecto-hilo-conductor.md`](../../../docs/proyecto-hilo-conductor.md).

---

## ✅ Requisitos verificables

Estos son, palabra por palabra, los diez `checks` que ejecuta
`./scripts/verificar-semana.sh 01`. Si uno falla, aquí está lo que pide:

1. **El laboratorio responde en /get**
2. **api-explorer.sh existe, es ejecutable y arranca con set -euo pipefail**
3. **No quedan marcadores TODO sin resolver en el script**
4. **El script imprime el codigo de estado de cada URL que consulta**
5. **El script imprime el tiempo de respuesta en segundos**
6. **El script sale distinto de 0 cuando el servidor responde 503**
7. **El script no se queda colgado cuando el servidor tarda demasiado**
8. **El script no desactiva la verificacion del certificado con -k**
9. **El script pasa shellcheck sin avisos**
10. **El script termina con una linea de resumen que cuenta cuantas URLs respondieron 2xx**

Detalle de los que suelen costar más:

| # | Qué se comprueba de verdad | Dónde está la respuesta |
|:--:|---|---|
| 5 | Que el tiempo salga con decimales (`0.412`, no `0`) | Práctica 03, paso 6: `%{time_total}` |
| 6 | `bash api-explorer.sh .../status/503` sale con un código distinto de 0 | Práctica 04, paso 6 |
| 7 | Contra `/delay/10`, el script termina antes de 25 s | Práctica 03, paso 7: `--max-time` |
| 10 | La **última** línea de la salida contiene un número | El resumen va después del bucle, no dentro |

---

## 🎨 Criterios de calidad

Lo que el autograding no ve y sí mira la rúbrica:

- **Una sola petición por URL.** Llamar a curl dos veces —una para el cuerpo,
  otra para el código— duplica el tráfico y en una API con rate limit se nota
- **Los flags con su porqué.** Un comentario por encima del curl explicando qué
  resuelve cada flag, no un `# hacer petición`
- **Nombres en inglés para las funciones, español para los comentarios**, como
  el resto del bootcamp
- **El script no se rompe si una URL no resuelve.** Sigue con las demás y lo
  cuenta como fallo
- **`--max-time` en una constante**, no repetido a mano en cada llamada
- **Ninguna URL con credenciales.** Ni en el código, ni de ejemplo

---

## 💡 Adaptación a tu dominio

La lista por defecto del starter apunta al laboratorio. Cámbiala por endpoints
de la API que elegiste:

| Dominio | URLs que tienen sentido en la capa 1 | Qué vas a ver |
|---|---|---|
| GitHub | `/rate_limit`, `/users/octocat`, `/repos/curl/curl` | Rate limit real en los headers, y tiempos que varían |
| Open-Meteo | `/v1/forecast?latitude=40.4&longitude=-3.7&current=temperature_2m` | Respuestas grandes y rápidas, sin autenticación |
| TfL | `/Line/Mode/tube/Status` | Una API que a veces tarda de verdad |
| TMDB | `/3/movie/550` (sin API key, para ver el 401) | Un 401 auténtico, con su `WWW-Authenticate` |

Consejo: deja **una** URL del laboratorio en la lista. Cuando algo falle, saber
si es tu script o la API de fuera te ahorra media hora.

---

## 🚦 Cómo entregarlo

```bash
# 1. Copia el starter a TU repositorio de trabajo, fuera de este.
cp starter/api-explorer.sh ~/api-toolkit/api-explorer.sh
chmod +x ~/api-toolkit/api-explorer.sh

# 2. Rellena los seis TODO.

# 3. Compruebalo a mano antes que con el autograding.
./api-explorer.sh http://localhost:8080/get http://localhost:8080/status/503
echo "exit=$?"     # tiene que ser distinto de 0

# 4. Pasa shellcheck.
shellcheck -S warning api-explorer.sh
# Si no lo tienes instalado:
# docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:stable -S warning api-explorer.sh

# 5. Y ahora si, el autograding.
./scripts/verificar-semana.sh 01
```

Salida esperada del script terminado:

```
=== api-explorer — 3 URL(s), maximo 10s cada una ===
200     0.001s  http://localhost:8080/get
200     0.002s  http://localhost:8080/json
404     0.001s  http://localhost:8080/status/404
=== Resumen: 2/3 respondieron correctamente ===
```

---

## 🧯 Errores comunes

| Síntoma | Causa | Solución |
|---|---|---|
| El script sale con 0 aunque una URL diera 503 | La última instrucción fue un `echo`, y el código de salida del script es el del último comando | Termina en una comparación: `[ "$correctas" -eq "$total" ]` |
| `set -e` mata el script en la primera URL caída | curl salió con 6 o 7 y `-e` aborta | `|| echo "000 0"` al final de la llamada a curl |
| El tiempo sale como `0` y el check 5 falla | `printf '%d'` trunca el decimal | `printf '%.3f'`, o imprime la variable tal cual |
| `[: 000: integer expression expected` | Comparas `000` como número antes de tratarlo aparte | `[ "$codigo" = "000" ] \|\| [ "$codigo" -ge 400 ]` |
| El check 7 falla con `exit 124` | Falta `--max-time`; `timeout` mató el script | Constante `MAX_TIME` y `--max-time "$MAX_TIME"` |
| El check 10 falla aunque imprimes el resumen | El resumen no es la **última** línea | Quita cualquier `echo` posterior; el `exit` no imprime nada |
| shellcheck avisa de `SC2086` | Una variable sin comillas | Comillas siempre: `"$url"`, `"$codigo"` |
| El check 3 sigue fallando | Queda la palabra `TODO` en un comentario | `grep -n TODO api-explorer.sh` y bórralos todos |

---

## 🔗 Navegación

| Anterior | Actual | Siguiente |
|---|---|---|
| [Práctica 04 — Códigos de estado](../2-practicas/04-provocar-y-leer-status-codes.md) | **Proyecto — api-explorer.sh** | [Rúbrica de evaluación](../rubrica-evaluacion.md) |

[← Volver a la Semana 01](../README.md)
