# Ejercicio 02: API Key

## Objetivo

Practicar el envío de API Keys en header y en query string. Usar httpbin para verificar que la key llegó correctamente. Entender por qué el header es preferible a la query string.

---

## Tareas

### 1. Enviar API Key en header (forma correcta)

```bash
# Definir la key en variable de entorno
export MI_API_KEY="key-de-prueba-bootcamp-2026"

# Enviar en header
curl -s \
     -H "X-API-Key: $MI_API_KEY" \
     https://httpbin.org/headers | python3 -m json.tool
```

Verificar que `X-Api-Key` aparece en el campo `headers` de la respuesta.

### 2. Enviar API Key en query string (para comparar)

```bash
curl -s "https://httpbin.org/get?api_key=$MI_API_KEY" | python3 -m json.tool
```

Observar que la key aparece en el campo `args`, no en `headers`. También aparece en el campo `url` — exactamente como quedaría en logs.

### 3. Comparar visibilidad en los logs

httpbin muestra la URL completa del request. Comparar:

```bash
# Con header: la key NO aparece en la URL
curl -s -H "X-API-Key: $MI_API_KEY" https://httpbin.org/get | python3 -m json.tool | grep url

# Con query string: la key SÍ aparece en la URL
curl -s "https://httpbin.org/get?api_key=$MI_API_KEY" | python3 -m json.tool | grep url
```

### 4. Usar distintos nombres de header (según la API)

Diferentes APIs usan diferentes nombres para el header de API Key:

```bash
# X-API-Key (convención OpenAPI)
curl -s -H "X-API-Key: $MI_API_KEY" https://httpbin.org/headers | python3 -m json.tool

# Authorization con esquema custom
curl -s -H "Authorization: ApiKey $MI_API_KEY" https://httpbin.org/headers | python3 -m json.tool

# X-Auth-Token (alternativa común)
curl -s -H "X-Auth-Token: $MI_API_KEY" https://httpbin.org/headers | python3 -m json.tool
```

Para saber qué header usar, hay que leer la documentación de la API específica.

### 5. Probar con wttr.in (API real sin key)

wttr.in no requiere API Key pero sirve para practicar el formato de requests a APIs reales:

```bash
# Clima en formato JSON
curl -s "https://wttr.in/Buenos+Aires?format=j1" | python3 -m json.tool | head -30

# Formato compacto: temperatura y condición
curl -s "https://wttr.in/Buenos+Aires?format=%t+%C"

# Formato de 3 líneas
curl -s "https://wttr.in/Buenos+Aires?format=3"
```

### 6. Script que verifica que la variable está definida

```bash
#!/bin/bash
# verificar-key.sh

if [ -z "$MI_API_KEY" ]; then
    echo "Error: MI_API_KEY no está definida"
    echo "Ejecuta: export MI_API_KEY=tu-key"
    exit 1
fi

echo "Enviando request con API Key..."
curl -s \
     -H "X-API-Key: $MI_API_KEY" \
     -H "Accept: application/json" \
     https://httpbin.org/headers | python3 -m json.tool
```

Probar el script con y sin la variable definida:

```bash
# Sin la variable (debería fallar con mensaje claro)
unset MI_API_KEY
bash verificar-key.sh

# Con la variable definida
export MI_API_KEY="key-de-prueba-bootcamp-2026"
bash verificar-key.sh
```

---

## Preguntas para responder

1. ¿En qué campo de la respuesta de httpbin aparece la API Key cuando se envía en header? ¿Y cuando se envía en query string?
2. ¿Por qué la query string es menos segura para enviar credenciales?
3. ¿Cómo sabés qué nombre de header usa una API específica para su API Key?
4. ¿Qué ventaja tiene `unset` frente a definir la variable con valor vacío?

---

## Entrega

Archivo `respuestas.md` con:
1. Output del paso 1 (API Key en header)
2. Output del paso 2 (API Key en query string) — resaltar dónde aparece la key
3. El script `verificar-key.sh` completo
4. Output de probar el script sin y con la variable definida
5. Respuestas a las 4 preguntas
