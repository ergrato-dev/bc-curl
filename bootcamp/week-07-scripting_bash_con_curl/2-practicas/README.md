# Practicas - Semana 7

Las practicas de esta semana requieren bash y jq. Antes de empezar, verifica:

```bash
bash --version   # debe ser 4.x o superior
jq --version     # debe estar instalado
curl --version   # version 7.61 o superior recomendada
```

## Instalar jq si no esta disponible

```bash
# Debian/Ubuntu/WSL
sudo apt update && sudo apt install -y jq

# macOS
brew install jq

# Fedora/RHEL/CentOS
sudo dnf install jq
```

## Orden recomendado

1. **01-ejercicio-exit-codes**: comprender los exit codes antes de escribir scripts
2. **02-ejercicio-jq**: aprender jq de forma iterativa con datos reales
3. **03-ejercicio-loop**: combinar curl + jq en un loop sencillo
4. **04-ejercicio-script-completo**: script con subcomandos y estructura profesional

## API usada

Todos los ejercicios usan `https://jsonplaceholder.typicode.com`, una API REST
publica que devuelve datos de prueba: posts, usuarios, comentarios, etc. No
requiere autenticacion y es idempotente (los datos son siempre los mismos).

## Como entregar

Para cada ejercicio, guarda en el directorio del ejercicio:
- El script o comandos que ejecutaste (`.sh`)
- El output capturado (`output.txt`)
- Respuestas a preguntas (`respuestas.md`)
