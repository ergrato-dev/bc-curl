# Proyecto — Capa 3: las credenciales

> `api-toolkit.sh` aprende a autenticarse. Y aprende a hacerlo sin publicar el
> secreto, que es la parte que separa un script de juguete de uno que puede
> tocar una API de verdad.

---

## 🎯 Objetivo

Añadir a `api-toolkit.sh` cuatro modos de autenticación —`none`, `basic`,
`bearer` y `apikey`— con la credencial leída del entorno o de `~/.bc-curl`,
**nunca de la línea de comandos**, un `--dry-run` que redacta el secreto y un
código de salida propio para los fallos de credencial.

---

## 📦 Qué añade esta capa

La Semana 02 dejó los cuatro verbos funcionando contra endpoints abiertos. Esta
capa es lo que hace falta para apuntar el toolkit a la API de tu dominio, que
casi seguro pide credencial.

| Viene de la Semana 02 | Lo añade esta capa |
|---|---|
| `get`, `post`, `put`, `delete` | Los mismos verbos, ahora autenticados |
| `--dry-run` que imprime el comando | El mismo, con la credencial **redactada** |
| Salida distinta de 0 ante 4xx/5xx | Salida `77` cuando el problema es la credencial |
| `BASE_URL` desde el entorno | `AUTH_MODE` y la credencial desde el entorno o `~/.bc-curl` |

Y lo que desbloquea después:

- **Semana 05** reutiliza el archivo de `--config` para meter también `--cacert`
  y el cookie jar
- **Semana 07** se apoya en el código `77` para decidir qué reintenta y qué no
- **Semana 08** sustituye el token fijo por uno de OAuth2 que se refresca solo.
  Sin el sitio donde guardarlo que crea esta capa, no habría dónde ponerlo

---

## ✅ Requisitos verificables

Estos son los enunciados exactos de `checks.json`. Si uno falla,
`./scripts/verificar-semana.sh 03` te dice cuál y con qué pista.

1. El laboratorio responde en el endpoint protegido con Basic Auth
2. api-toolkit.sh existe, es ejecutable y arranca con set -euo pipefail
3. No quedan marcadores TODO sin resolver en el script
4. Con AUTH_MODE=basic el script autentica contra un endpoint Basic Auth
5. Una password incorrecta hace salir al script con el codigo 77
6. Con AUTH_MODE=bearer el script autentica contra un endpoint Bearer
7. El token llega al servidor tal cual, sin recortes ni comillas de mas
8. Con AUTH_MODE=apikey la clave viaja en un header, no en la query string
9. Sin credencial contra un endpoint protegido el script sale con 77
10. Un 403 sale tambien con 77: reintentar con lo mismo no va a funcionar
11. Un 500 sale con 1, no con 77: no es un problema de credencial
12. El token no aparece en la linea de comandos de ningun proceso curl
13. --dry-run imprime el comando pero no el valor de la credencial
14. El script se niega a leer un archivo de credenciales con permisos abiertos
15. No hay ninguna credencial escrita a mano dentro del script
16. El script no desactiva la verificacion del certificado con -k
17. El script pasa shellcheck sin avisos

---

## 🎨 Criterios de calidad

Lo que el autograding no puede ver y sí mira la rúbrica:

- **El archivo de credenciales se borra siempre.** Con un `trap ... EXIT`, que
  salta aunque el script muera a mitad. Un `rm` al final no vale: no se ejecuta
  si algo falla antes
- **El archivo nace con permisos 600.** `(umask 077; ...)` antes de escribir, no
  un `chmod` después. La ventana entre las dos operaciones es real
- **El entorno manda sobre el archivo.** Un pipeline de CI inyecta el token por
  variable de entorno y no debería tener que escribir ningún archivo
- **`~/.bc-curl` se lee, no se ejecuta.** Nada de `source`: eso ejecutaría
  cualquier cosa que hubiera dentro. Se filtra con `grep` y se asigna a mano
- **Los mensajes de error van a stderr.** Si fueran a stdout, un `... | jq` se
  los tragaría como si fueran datos
- **El mensaje de permisos dice el `chmod` exacto.** «Permisos incorrectos» hace
  buscar; `usa: chmod 600 /home/tu/.bc-curl` se copia y se pega
- **La redacción del secreto es total.** Un texto fijo, sin los primeros
  caracteres del valor: cuatro caracteres filtrados son cuatro que ya no hay que
  adivinar
- **La cabecera del script documenta los códigos de salida.** Quien lo llame
  necesita saber qué significa `77` sin leer el código

---

## 💡 Adaptación a tu dominio

El laboratorio usa Basic y Bearer. Tu API usará lo que use, y por eso el
`AUTH_MODE` es una variable y no una decisión escrita en el código:

| Dominio | API | `AUTH_MODE` | Cómo se obtiene la credencial |
|---|---|---|---|
| Código | GitHub REST | `bearer` | Un *personal access token* en la configuración de tu cuenta. Dale solo los scopes que necesites |
| Clima | Open-Meteo | `none` | No pide credencial. Buen caso para comprobar que `none` funciona |
| Transporte | Transport for London | `apikey` | Registro gratuito; la clave va en un header propio |
| Cultura | The Movie Database | `bearer` | El panel da un token de lectura ya en formato Bearer |

Averigua cuál es el tuyo antes de escribir nada, con lo de la práctica 01:

```bash
curl -s -o /dev/null -D - "https://api.de-tu-dominio.com/v1/algo" \
  | grep -i '^www-authenticate'
```

Si tu API no devuelve `WWW-Authenticate`, su documentación es la única fuente.
Anótalo en `~/.bc-curl` junto a la credencial.

---

## 🚦 Cómo entregarlo

**1.** Copia el starter sobre tu `api-toolkit.sh` de la Semana 02, o parte del
starter directamente si prefieres empezar limpio:

```bash
cd bootcamp/week-03-autenticacion_basica/3-proyecto/starter/
cp api-toolkit.sh ~/api-toolkit.sh
chmod +x ~/api-toolkit.sh
```

**2.** Rellena los seis `TODO` numerados. Cada uno dice qué se espera:

| TODO | Qué resuelve | Dónde está explicado |
|:--:|---|---|
| 1 | La comprobación de permisos de `~/.bc-curl` | [Teoría 03 §2.5](../1-teoria/03-donde-no-poner-la-credencial.md), práctica 02 paso 8 |
| 2a | La línea `user = "..."` del archivo de `--config` | [Teoría 02 §3.3](../1-teoria/02-basic-auth.md) |
| 2b | La línea `header = "Authorization: Bearer ..."` | [Teoría 05 §3.2](../1-teoria/05-bearer-y-el-flujo-de-login.md), práctica 02 paso 2 |
| 2c | La línea del header de API key | [Teoría 04 §3.1](../1-teoria/04-api-keys.md), práctica 02 paso 5 |
| 3 | La línea de `--dry-run` que dice el modo sin decir el valor | [Teoría 03 §4](../1-teoria/03-donde-no-poner-la-credencial.md) |
| 4 | La traducción del código HTTP al código de salida | [Teoría 08 §2.4](../1-teoria/08-cuando-la-credencial-falla.md), práctica 04 paso 5 |

**3.** Prueba los cuatro modos a mano:

```bash
# El laboratorio, con cada modo.
AUTH_MODE=basic  API_USER=user API_PASSWORD=password \
  ./api-toolkit.sh get /basic-auth/user/password
AUTH_MODE=bearer API_TOKEN=token-de-laboratorio ./api-toolkit.sh get /bearer
AUTH_MODE=apikey API_KEY=clave-de-laboratorio   ./api-toolkit.sh get /headers
AUTH_MODE=none   ./api-toolkit.sh get /get
```

**4.** Comprueba que no filtras:

```bash
AUTH_MODE=bearer API_TOKEN=zzsecretozz ./api-toolkit.sh get /delay/3 >/dev/null &
sleep 1; ps -eo args | grep '^curl ' | grep -c zzsecretozz || true
wait
# 0
```

**5.** Pasa el autograding y `shellcheck`:

```bash
./scripts/verificar-semana.sh 03
shellcheck -S warning ~/api-toolkit.sh
```

---

## 🧯 Errores comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `toolkit-token-no-en-la-linea-de-comandos` falla | El secreto entra por `ARGS_CURL` en vez de por el archivo de `--config` | TODO 2: se escribe en `$CONFIG_CURL`, no se añade a `ARGS_CURL` |
| `toolkit-sin-todos` falla y ya los rellenaste todos | Queda un comentario que empieza por `# TODO` | `grep -nE '^[[:space:]]*#[[:space:]]*TODO' api-toolkit.sh` |
| `toolkit-basic-auth` da 401 con la credencial buena | El formato del `--config` es `user = "usuario:password"`, con **un** dos puntos entre los dos | Comprueba el archivo generado antes de que se borre |
| `toolkit-otro-error-no-es-77` falla | El `case` mete el 500 en la rama del `77`, o `[123]??` va antes que `401\|403` | El orden del `case` importa: `401\|403` primero |
| `exit=77` no llega a quien llama | Pusiste `exit` fuera del `case`, o `ejecutar` devuelve y `main` no propaga | `return 77` dentro del `case`, y que `main` termine con `ejecutar` |
| `toolkit-rechaza-credenciales-legibles` falla | El script avisa de los permisos pero continúa | Tiene que llamar a `error`, que sale con 1 |
| `toolkit-dry-run-oculta-el-secreto` falla | Imprimes `$API_TOKEN` o un trozo | Usa `$REDACTADO`, un texto fijo |
| El script se queda colgado | Falta `--max-time`, o `/delay/10` con `MAX_TIME=10` justo en el límite | `MAX_TIME` está puesto: no lo quites |
| `shellcheck` avisa `SC2086` | Una variable sin comillas | `"$codigo"`, no `$codigo` |
| Los mensajes de error se cuelan en el JSON | Van a stdout | `>&2` en todos ellos. La función `error` ya lo hace |

---

## 🔗 Navegación

| Anterior | Siguiente |
|---|---|
| [Práctica 04 — Cuando la credencial falla](../2-practicas/04-cuando-la-credencial-falla.md) | [Rúbrica de evaluación](../rubrica-evaluacion.md) |

[← README de la Semana 03](../README.md)
