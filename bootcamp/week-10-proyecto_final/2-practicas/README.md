# Practicas — Semana 10

Las 4 practicas de esta semana son las etapas de construccion del proyecto final. No son ejercicios independientes: cada una extiende el trabajo de la anterior. Al completar la etapa 4, el proyecto final esta listo para entregar.

**Completa las etapas en orden.**

---

## Mapa de etapas

| # | Etapa | Tiempo estimado | Que construyes |
|---|-------|-----------------|----------------|
| 01 | [Estructura base](01-ejercicio-estructura/README.md) | 45 min | Scaffolding, `--help`, dispatcher, `load_config` |
| 02 | [Modulo auth](02-ejercicio-auth-module/README.md) | 60 min | `auth login/logout/status`, token lifecycle |
| 03 | [Modulo requests](03-ejercicio-request-module/README.md) | 75 min | `get/post/put/delete`, retry, logging |
| 04 | [Features avanzadas](04-ejercicio-features-avanzadas/README.md) | 60 min | `monitor`, `bench`, `--output`, mejoras de UX |

**Total:** ~4 horas de implementacion

---

## Punto de partida

Copia el starter a tu directorio de trabajo:

```bash
cp /ruta/a/bootcamp/week-10-proyecto_final/3-proyecto/starter/api-toolkit.sh ~/api-toolkit.sh
chmod +x ~/api-toolkit.sh
```

O trabajar directamente en `3-proyecto/starter/api-toolkit.sh` si prefieres tener todo en un lugar.

## API de practica

Puedes usar cualquiera de estas APIs publicas (sin necesidad de cuenta):

- **JSONPlaceholder** `https://jsonplaceholder.typicode.com` — CRUD fake, sin auth
- **httpbin** `https://httpbin.org` — refleja requests, util para debugging
- **reqres.in** `https://reqres.in` — simula auth con tokens

Si ya tienes una cuenta en GitHub, puedes usar la GitHub API con tu token personal (AUTH_TYPE=bearer, sin token_url ya que pasas el token directamente).

---

## Verificacion antes de empezar

```bash
# Verifica que tienes las dependencias
bash --version     # debe ser >= 4.0
curl --version
jq --version

# Verifica que el starter carga sin errores
bash -n api-toolkit.sh && echo "Sintaxis OK"

# El --help debe funcionar
bash api-toolkit.sh --help
```

---

## Flujo de trabajo recomendado

1. Lee el README de la etapa
2. Abre `api-toolkit.sh` y busca los `TODO` relevantes para esa etapa
3. Implementa, prueba manualmente, refina
4. Verifica cada punto del checklist antes de pasar a la siguiente etapa

No necesitas terminar una etapa en una sesion. El script funciona en cualquier estado: las funciones no implementadas muestran un mensaje de "TODO" en lugar de fallar silenciosamente.
