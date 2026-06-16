# Ejercicio 01: Instalación y exploración

## Objetivo

Verificar que curl está instalado y explorar sus capacidades básicas de ayuda.

## Tareas

### 1. Verificar instalación

```bash
curl --version
```

Anotar: versión, protocolos soportados, features.

### 2. Explorar la ayuda

```bash
curl --help
```

Contar cuántos flags aparecen. ¿Cuáles reconocés de la teoría?

### 3. Buscar flags en el manual

```bash
# Buscar el flag para seguir redirects
man curl | grep -A2 "location"

# Buscar el flag para silenciar output
man curl | grep -A2 "\-\-silent"
```

### 4. Primer request

```bash
curl https://httpbin.org/get
```

Identificar en el output:
- ¿Qué User-Agent usa curl por defecto?
- ¿Qué IP de origen muestra?
- ¿Qué headers envió curl automáticamente?

## Entrega

Archivo `respuestas.md` con:
1. Versión de curl instalada
2. Lista de 5 flags que te parecieron interesantes del `--help`
3. Output del primer request a httpbin
4. Respuesta a las 3 preguntas del punto 4
