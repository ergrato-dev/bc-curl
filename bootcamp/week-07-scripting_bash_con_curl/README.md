# Semana 7: Scripting bash con curl

## Descripcion

Esta semana combinamos curl con bash para construir scripts reales: automatizacion
de APIs, procesamiento de respuestas JSON, manejo de errores y estructura de codigo
profesional. El objetivo no es solo que los scripts funcionen, sino que sean
robustos, legibles y mantenibles.

La herramienta central de esta semana es `jq`, el procesador JSON de la linea de
comandos. Si curl es la herramienta para hablar con APIs, jq es la que permite
procesar lo que las APIs devuelven.

## Objetivos de la semana

Al terminar esta semana seras capaz de:

- Entender y manejar correctamente los exit codes de curl
- Diferenciar errores de red, errores HTTP y timeouts en tus scripts
- Usar jq para filtrar, transformar y crear JSON desde la terminal
- Escribir loops que iteren sobre listas de recursos con manejo de errores
- Implementar retry logic con backoff exponencial para errores 429 y 503
- Estructurar scripts bash de forma profesional

## Estructura

```
week-07-scripting_bash_con_curl/
├── README.md                       <- este archivo
├── rubrica-evaluacion.md           <- criterios de evaluacion
├── 1-teoria/
│   ├── 01-exit-codes-curl.md       <- exit codes y el flag -f
│   ├── 02-manejo-errores.md        <- patrones de error handling
│   ├── 03-jq-basico.md             <- procesamiento JSON con jq
│   ├── 04-loops-y-paginacion.md    <- loops e iteracion sobre APIs
│   └── 05-scripts-produccion.md    <- estructura profesional
├── 2-practicas/
│   ├── README.md
│   ├── 01-ejercicio-exit-codes/
│   ├── 02-ejercicio-jq/
│   ├── 03-ejercicio-loop/
│   └── 04-ejercicio-script-completo/
├── 3-proyecto/
│   └── README.md                   <- API Sync
└── 5-glosario/
    └── README.md
```

## Prerequisitos

- Semanas 1 a 6 completadas
- jq instalado: `sudo apt install jq` (Debian/Ubuntu) o `brew install jq` (macOS)
- Bash 4.x o superior: `bash --version`

## Tiempo estimado

- Teoria: 3-4 horas
- Practicas: 4-5 horas
- Proyecto: 3-4 horas
