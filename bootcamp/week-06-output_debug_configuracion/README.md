# Semana 6: Output, Debug y Configuracion

## Descripcion

En las semanas anteriores aprendiste a construir requests HTTP con curl. Esta semana
el foco cambia: aprenderemos a controlar lo que curl muestra, extraer metricas del
proceso de transferencia, depurar problemas a nivel de protocolo y persistir
configuraciones para no repetir flags en cada comando.

Estas habilidades son fundamentales para usar curl en entornos de produccion, donde
necesitas saber exactamente que paso y cuanto tardo, sin ruido visual de por medio.

## Objetivos de la semana

Al terminar esta semana seras capaz de:

- Controlar el output de curl con precision usando `-s`, `-o` y `-D`
- Usar `--write-out` para extraer metricas de cada transferencia
- Configurar `~/.curlrc` para establecer defaults persistentes
- Depurar requests a nivel de protocolo con `-v`, `--trace` y `--trace-ascii`
- Combinar variables bash con curl para construir scripts reutilizables

## Estructura

```
week-06-output_debug_configuracion/
├── README.md                  <- este archivo
├── rubrica-evaluacion.md      <- criterios de evaluacion
├── 1-teoria/
│   ├── 01-write-out.md        <- el flag --write-out y sus variables
│   ├── 02-silent-y-output-control.md  <- control de verbosidad
│   ├── 03-verbose-y-trace.md  <- depuracion profunda
│   ├── 04-curlrc.md           <- archivo de configuracion
│   └── 05-variables-y-templates.md   <- variables bash con curl
├── 2-practicas/
│   ├── README.md
│   ├── 01-ejercicio-write-out/
│   ├── 02-ejercicio-debug/
│   ├── 03-ejercicio-curlrc/
│   └── 04-ejercicio-metricas/
├── 3-proyecto/
│   └── README.md              <- API Monitor
└── 5-glosario/
    └── README.md
```

## Prerequisitos

- Semanas 1 a 5 completadas
- Bash funcional (Linux, macOS o WSL)
- curl instalado (version 7.61 o superior recomendada)

## Tiempo estimado

- Teoria: 2-3 horas
- Practicas: 3-4 horas
- Proyecto: 2-3 horas
