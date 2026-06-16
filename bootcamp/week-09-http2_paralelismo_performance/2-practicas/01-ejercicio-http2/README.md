# Ejercicio 01: HTTP/2 en la Practica

## Objetivo

Verificar el soporte HTTP/2 en tu instalacion de curl, hacer requests con ambas versiones del protocolo, e interpretar las diferencias en la negociacion y en el rendimiento.

## Parte 1: Verificar Soporte

```bash
# Ver version y features
curl --version

# Buscar especificamente HTTP2
curl --version | grep -o 'HTTP2'

# Si no aparece, intentar instalar:
# Ubuntu/Debian:
sudo apt-get update && sudo apt-get install -y curl
# macOS:
# brew install curl
# (usar /opt/homebrew/bin/curl o agregar brew a PATH)
```

Preguntas:
- Que version de curl tenés instalada?
- Aparece `HTTP2` en Features?
- Aparece `nghttp2` en la linea de libraries?

## Parte 2: Comparar HTTP/1.1 vs HTTP/2

```bash
# Request con HTTP/1.1 (forzado)
curl -sI --http1.1 https://www.google.com | head -3

# Request con HTTP/2 (forzado)  
curl -sI --http2 https://www.google.com | head -3
```

Observar la primera linea de cada respuesta. Debe decir `HTTP/1.1 200 OK` o `HTTP/2 200` respectivamente.

## Parte 3: Ver la Negociacion ALPN

ALPN (Application-Layer Protocol Negotiation) es el mecanismo TLS por el que el cliente y servidor acuerdan usar HTTP/2 en lugar de HTTP/1.1:

```bash
# -v muestra el proceso de negociacion
curl -sv --http2 https://www.google.com -o /dev/null 2>&1 | grep -E "ALPN|HTTP/"
```

Buscar en el output:
- `ALPN: offering h2` — curl ofrece HTTP/2
- `ALPN: server accepted h2` — el servidor acepto HTTP/2
- `< HTTP/2 200` — la respuesta uso HTTP/2

## Parte 4: Servidor sin Soporte HTTP/2

```bash
# httpbin.org puede no soportar HTTP/2 segun el hosting
# Ver que pasa cuando el servidor no soporta HTTP/2
curl -sv --http2 https://httpbin.org/get -o /dev/null 2>&1 | grep -E "ALPN|HTTP/"
```

Si el servidor no soporta HTTP/2, curl hace "fallback" automatico a HTTP/1.1. Verificar que la respuesta dice `HTTP/1.1`.

## Parte 5: Medir Diferencia de Performance

```bash
# Funcion para medir tiempo de un request
measure() {
  local version_flag="$1"
  local url="$2"
  local n=5
  local total=0
  
  for i in $(seq 1 $n); do
    t=$(curl -s $version_flag -o /dev/null \
      -w '%{time_total}' "$url")
    total=$(awk "BEGIN{print $total + $t}")
  done
  
  awk "BEGIN{printf \"%.3f\n\", $total / $n}"
}

URL="https://www.cloudflare.com"
echo "HTTP/1.1 promedio (5 requests): $(measure --http1.1 $URL)s"
echo "HTTP/2 promedio (5 requests):   $(measure --http2 $URL)s"
```

Nota: la diferencia puede ser pequeña para un solo request. El beneficio real de HTTP/2 se ve con muchos recursos en paralelo.

## Parte 6: HTTP/2 Prior Knowledge (h2c)

Para servidores locales que hablan HTTP/2 sin TLS (h2c — HTTP/2 cleartext):

```bash
# Levantar un servidor HTTP/2 local (requiere Python y hypercorn)
# pip install hypercorn
# Solo para referencia, no es parte del ejercicio principal

# Para servidores locales, se puede forzar HTTP/2 sin negociacion TLS:
curl --http2-prior-knowledge http://localhost:8080/
```

## Entrega

Archivo `respuestas.md` con:
1. Version de curl y si tiene soporte HTTP/2 (output de `curl --version`)
2. Diferencia en la primera linea de respuesta entre HTTP/1.1 y HTTP/2
3. Output del grep de ALPN (con la negociacion visible)
4. Resultado del test de performance (tiempos para HTTP/1.1 vs HTTP/2)
5. Respuesta: en que situaciones elegirías forzar HTTP/2 con `--http2`? En cuales no importa?
