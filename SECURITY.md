# Politica de Seguridad

## Versiones Soportadas

| Version | Soportada |
| ------- | --------- |
| main    | Si        |

## Reportar una Vulnerabilidad

Si descubres una vulnerabilidad de seguridad en este material o en los scripts del laboratorio, te pedimos que la reportes de manera responsable.

### NO hacer publico el reporte

Por favor, **NO** abras un issue publico para reportar vulnerabilidades de seguridad.

### Como Reportar

1. **Abre un Security Advisory privado** en GitHub:
   - Ve a la pestana "Security" del repositorio
   - Haz clic en "Report a vulnerability"
   - Completa el formulario con los detalles

2. **Incluye en tu reporte**:
   - Descripcion detallada de la vulnerabilidad
   - Pasos para reproducir el problema
   - Impacto potencial
   - Sugerencias de solucion (si las tienes)

### Tiempo de Respuesta

- **Confirmacion inicial**: 48 horas
- **Evaluacion**: 7 dias
- **Resolucion**: Dependiendo de la severidad

### Reconocimiento

Agradecemos a todos los investigadores de seguridad que reportan vulnerabilidades de manera responsable. Tu nombre sera incluido en nuestros agradecimientos (si lo deseas).

---

## Que se considera vulnerabilidad en este repositorio

Este es material educativo, no un servicio en produccion. Cuentan como vulnerabilidad:

- **Un secreto real comiteado** en cualquier archivo del repositorio.
- **Un ejemplo que ensena un antipatron sin marcarlo como tal** y que un alumno copiaria a produccion: `-k` presentado como solucion, un token en la linea de comandos, `curl | bash` sin advertencia.
- **Un script del laboratorio o de `scripts/` con inyeccion de comandos**, escalada de privilegios o escritura fuera de su directorio.
- **Una imagen del `docker-compose.yml` sin version fijada** o con una CVE conocida sin mitigar.

## Practicas de seguridad que ensena este bootcamp

### Los secretos nunca van en la linea de comandos

```bash
# ANTIPATRON: el token es visible en `ps`, en el historial y en los logs del shell
curl -H "Authorization: Bearer sk_live_abc123" https://api.ejemplo.com/v1/cuentas

# CORRECTO: la variable no aparece en `ps`
curl -H "Authorization: Bearer ${API_TOKEN}" https://api.ejemplo.com/v1/cuentas

# MEJOR: ni siquiera pasa por el entorno del proceso
curl --netrc-file ~/.netrc https://api.ejemplo.com/v1/cuentas
```

### La verificacion TLS no se desactiva

```bash
# ANTIPATRON: acepta cualquier certificado, incluido el del atacante
curl -k https://api.interna.ejemplo.com/

# CORRECTO: se confia en la CA concreta que emitio el certificado
curl --cacert /etc/ssl/certs/ca-interna.pem https://api.interna.ejemplo.com/
```

### Un error HTTP tiene que hacer fallar el script

```bash
# ANTIPATRON: curl sale con 0 ante un 500 y el script sigue como si nada
curl -s https://api.ejemplo.com/v1/deploy

# CORRECTO: --fail-with-body sale distinto de 0 y conserva el cuerpo del error
curl --fail-with-body --max-time 30 --retry 3 -s https://api.ejemplo.com/v1/deploy
```

### Nunca `curl | bash`

Descargar y ejecutar en el mismo comando no deja inspeccionar lo que se ejecuta, y un servidor puede servir contenido distinto a `curl` que a un navegador. Se descarga, se lee, y despues se ejecuta.

### Los scripts se auditan

Todo `starter/*.sh` de este repositorio pasa `shellcheck` y arranca con `set -euo pipefail`.

## Dependencias

Este bootcamp referencia:

- curl 7.x / 8.x (ver [`docs/versiones-de-curl.md`](docs/versiones-de-curl.md))
- jq
- shellcheck
- Las imagenes del laboratorio, todas con version fijada en `docker-compose.yml`

---

Gracias por ayudar a mantener este proyecto seguro.
