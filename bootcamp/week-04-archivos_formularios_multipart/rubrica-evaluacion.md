# Rubrica de Evaluacion - Semana 4

## Competencias evaluadas

### C1: Descarga de archivos (25 puntos)

| Indicador | Logrado | Parcial | No logrado |
|-----------|---------|---------|------------|
| Usa `-o` con nombre explícito y el archivo se guarda correctamente | 7 | 4 | 0 |
| Usa `-O` y entiende de dónde proviene el nombre del archivo | 6 | 3 | 0 |
| Usa `--progress-bar` y explica la diferencia con el modo detallado | 6 | 3 | 0 |
| Reanuda una descarga interrumpida con `-C -` correctamente | 6 | 3 | 0 |

### C2: Form URL-encoded (25 puntos)

| Indicador | Logrado | Parcial | No logrado |
|-----------|---------|---------|------------|
| Envía formulario con `-d` y los datos aparecen en `.form` de httpbin | 7 | 4 | 0 |
| Usa `--data-urlencode` con valores que contienen `&`, `=` y espacios | 8 | 4 | 0 |
| Explica la diferencia entre `-d` y `--data-urlencode` | 5 | 2 | 0 |
| Identifica cuándo usar URL-encoded vs JSON | 5 | 2 | 0 |

### C3: Multipart upload (30 puntos)

| Indicador | Logrado | Parcial | No logrado |
|-----------|---------|---------|------------|
| Sube un archivo con `-F "campo=@archivo"` y verifica la respuesta | 8 | 4 | 0 |
| Combina campos de texto y archivo en un mismo request multipart | 8 | 4 | 0 |
| Especifica MIME type explícito con `;type=` | 7 | 3 | 0 |
| Identifica el boundary en el Content-Type del request | 7 | 3 | 0 |

### C4: Opciones de transferencia (20 puntos)

| Indicador | Logrado | Parcial | No logrado |
|-----------|---------|---------|------------|
| Usa `--limit-rate` y observa el efecto en la velocidad | 5 | 2 | 0 |
| Distingue `--connect-timeout` de `--max-time` y usa ambos | 7 | 3 | 0 |
| Configura `--retry` y entiende cuándo reintenta curl | 5 | 2 | 0 |
| Usa `--range` para descargar un fragmento de un archivo | 3 | 1 | 0 |

---

## Proyecto (evaluacion separada)

| Criterio | Puntos |
|----------|--------|
| Subcomando `download` funciona con y sin nombre de salida | 20 |
| `download` muestra el tamaño del archivo descargado | 10 |
| Subcomando `upload` valida existencia del archivo antes de subir | 15 |
| `upload` muestra el campo `files` de la respuesta de httpbin | 15 |
| Subcomando `form-post` usa `--data-urlencode` por cada campo | 20 |
| `form-post` muestra el campo `form` de la respuesta | 10 |
| Manejo de errores y uso correcto del mensaje de `usage` | 10 |

---

## Criterios de aprobacion

- Nota minima para aprobar: 60/100 en competencias + 60/100 en proyecto
- Todos los ejercicios prácticos deben entregarse con `respuestas.md`
- Los comandos en `respuestas.md` deben ser ejecutables tal como se escribieron

## Notas del evaluador

_Espacio para comentarios personalizados_
