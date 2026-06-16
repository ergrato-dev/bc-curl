# Instalación y verificación de curl

## Verificar si ya está instalado

```bash
curl --version
```

Salida esperada:
```
curl 8.5.0 (x86_64-pc-linux-gnu) libcurl/8.5.0 OpenSSL/3.2.1
Release-Date: 2023-12-06
Protocols: dict file ftp ftps http https imap imaps ...
Features: alt-svc AsynchDNS brotli GSS-API HSTS HTTP2 HTTPS-proxy ...
```

Lo importante: versión >= 7.x y protocolo `https` en la lista.

---

## Instalación por sistema

### Ubuntu / Debian

```bash
sudo apt update && sudo apt install -y curl
```

### Fedora / RHEL / Rocky

```bash
sudo dnf install -y curl
```

### macOS

curl viene preinstalado. Para versión más reciente:

```bash
brew install curl
# Agregar al PATH si querés usar la versión de brew en lugar de la del sistema
echo 'export PATH="$(brew --prefix)/opt/curl/bin:$PATH"' >> ~/.zshrc
```

### Windows (WSL)

Dentro de WSL (Ubuntu):
```bash
sudo apt update && sudo apt install -y curl
```

### Windows (nativo, sin WSL)

Descargar desde https://curl.se/windows/ o usar winget:
```
winget install curl.curl
```

---

## Primer comando

```bash
curl https://httpbin.org/get
```

Si ves un JSON con tu IP y headers, curl funciona correctamente.

---

## Explorar la ayuda

```bash
# Ayuda rápida (flags más usados)
curl --help

# Manual completo
man curl

# Buscar un flag específico en el manual
man curl | grep -A3 "\-\-verbose"
```

La man page de curl tiene más de 4000 líneas. No la memorices — úsala como referencia cuando necesites un flag específico.

---

## Flags que vamos a usar esta semana

| Flag | Forma corta | Descripción |
|------|-------------|-------------|
| `--verbose` | `-v` | Muestra todo: handshake, headers enviados y recibidos |
| `--include` | `-i` | Muestra headers de respuesta + body |
| `--head` | `-I` | Solo descarga los headers (usa HEAD) |
| `--output` | `-o file` | Guarda el output en un archivo |
| `--silent` | `-s` | Sin barra de progreso ni mensajes de error |
| `--location` | `-L` | Sigue redirects automáticamente |
| `--request` | `-X METHOD` | Especifica el método HTTP |

---

## Verificacion final

Ejecutá estos tres comandos. Si todos responden, estás listo:

```bash
# 1. GET básico
curl https://httpbin.org/get

# 2. Ver headers
curl -I https://httpbin.org

# 3. Verbose
curl -v https://httpbin.org/get 2>&1 | head -30
```
