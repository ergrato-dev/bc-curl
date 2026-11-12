# Preparar el entorno

Diez minutos. Al final tendrás curl, jq, shellcheck y un laboratorio local con
tres servidores contra los que practicar sin depender de internet.

---

## 1. Por qué hay un laboratorio local

La forma clásica de enseñar curl es apuntar a `httpbin.org`. Funciona hasta que
no funciona: el servicio se cae, limita por IP, y a mitad de una práctica dejas
de saber si el problema es tu comando o el servidor de otro.

Peor: hay cosas que no se pueden enseñar contra un servicio público. No puedes
provocar un fallo de certificado a propósito, ni pedirle un token OAuth2, ni
apagarlo para ver qué hace tu script cuando el servidor no está.

El laboratorio son tres contenedores en tu máquina:

| Servicio | Dónde | Para qué |
|---|---|---|
| httpbin | `http://localhost:8080` | Métodos, status codes, headers, auth, cookies, redirects, compresión, multipart, rangos, ETag |
| OAuth2 | `http://localhost:8081/default` | Tokens firmados de verdad: client credentials, authorization code + PKCE, refresh, revocación e introspección (device code no) |
| TLS | `https://localhost:8443` | HTTPS con CA propia, HTTP/2 y HTTP/3. Además, `/paginas` (paginación con `Link`) y `/limitado` (429 con `Retry-After`) |
| mTLS | `https://localhost:8444` | Exige certificado de cliente |

Consumen unos 300 MB de RAM en total.

---

## 2. Requisitos

### Sistema

Linux, macOS, o Windows con WSL2. En Windows **trabaja siempre dentro de WSL**:
el curl de PowerShell es un alias de `Invoke-WebRequest` y no es el mismo
programa.

```powershell
# En PowerShell, esto NO es curl:
Get-Command curl
# CommandType: Alias    Name: curl -> Invoke-WebRequest
```

### Herramientas

```bash
# Debian / Ubuntu
sudo apt update && sudo apt install -y curl jq shellcheck

# Fedora / RHEL
sudo dnf install -y curl jq ShellCheck

# macOS
brew install curl jq shellcheck
```

Comprueba las tres:

```bash
curl --version | head -1
jq --version
shellcheck --version | head -2
```

> [!IMPORTANT]
> Mira qué versión de curl te ha salido y compárala con
> [versiones-de-curl.md](versiones-de-curl.md). Si es 7.81 o anterior, algunos
> ejemplos del bootcamp llevan una alternativa marcada al lado. No es un
> problema: es información que necesitas antes de que un comando falle.

### Docker

```bash
docker --version
docker compose version   # tiene que ser v2. `docker-compose` v1 no sirve
docker info              # el demonio tiene que responder
```

Si `docker info` falla, arranca el servicio antes de seguir.

---

## 3. Levantar el laboratorio

```bash
git clone https://github.com/ergrato-dev/bc-curl.git
cd bc-curl
cp .env.example .env      # opcional: solo si necesitas cambiar puertos
./scripts/start.sh
```

`start.sh` hace cuatro cosas: comprueba las dependencias, avisa si alguno de los
cuatro puertos está ocupado, levanta los contenedores, y **espera a que
respondan de verdad** antes de darte el control. Después exporta el certificado
raíz de la CA a `docs/lab-ca.pem`.

Salida esperada:

```
Laboratorio listo.

  httpbin        http://localhost:8080          metodos, status, auth, cookies
  OAuth2         http://localhost:8081/default  tokens de verdad, firmados
  TLS            https://localhost:8443         HTTP/2 y HTTP/3, CA propia
  mTLS           https://localhost:8444         exige certificado de cliente
```

### Comprobarlo

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/get
# 200

curl --cacert docs/lab-ca.pem -s -o /dev/null -w '%{http_version}\n' https://localhost:8443/get
# 2
```

Y ahora la comprobación más importante del bootcamp, la que **tiene que
fallar**:

```bash
curl -s -o /dev/null https://localhost:8443/get
echo $?
# 60
```

El código 60 es `SSL peer certificate or SSH remote key was not OK`: curl no
conoce la CA que emitió ese certificado y **se niega a seguir**. Eso es lo
correcto. Existe un flag para apagar esa comprobación y en la Semana 05 verás
por qué no se usa.

### Pararlo

```bash
./scripts/stop.sh              # para los contenedores, conserva la CA
./scripts/stop.sh --limpiar    # ademas borra volumenes y CA (pregunta antes)
```

---

## 4. La CA del laboratorio

`docs/lab-ca.pem` es el certificado raíz que Caddy genera **en tu máquina, la
primera vez**. Es tuyo y de nadie más: por eso está en `.gitignore` y no se
comitea.

Es lo que pasas a `--cacert` cuando hablas con `https://localhost:8443`. Si lo
borras o corres `stop.sh --limpiar`, se regenera en el siguiente arranque y el
anterior deja de valer.

Para verlo por dentro:

```bash
openssl x509 -in docs/lab-ca.pem -noout -subject -issuer -dates
```

> [!WARNING]
> No lo instales en el almacén de confianza de tu sistema. Es un certificado de
> laboratorio: si tu sistema confía en él, cualquier cosa firmada por esa CA
> pasa como legítima en todo tu equipo. Pásalo con `--cacert` y ya.

---

## 5. Configurar el autograding

Comprueba que el entorno está completo:

```bash
./scripts/verificar-semana.sh --doctor
```

Y a partir de la Semana 01, para evaluarte:

```bash
./scripts/verificar-semana.sh 01
```

Cómo funciona y qué se puede comprobar: [autograding.md](autograding.md).

---

## 6. Si algo sale mal

| Síntoma | Causa | Solución |
|---|---|---|
| `El puerto 8080 ya esta ocupado` | Otro servicio lo tiene | Libéralo, o cambia `HTTPBIN_PORT` en tu `.env` |
| `docker compose version` falla | Tienes `docker-compose` v1 | Instala el plugin Compose v2 |
| `Los servicios no respondieron en 60s` | Arranque lento o imagen a medio bajar | `docker compose logs` para ver qué pasó |
| `No se pudo exportar la CA` | Caddy aún no emitió el certificado | Espera unos segundos y repite `./scripts/start.sh` |
| Código 60 con `--cacert` puesto | La CA que tienes es de un laboratorio anterior | `./scripts/stop.sh --limpiar && ./scripts/start.sh` |
| `curl` en PowerShell devuelve un objeto raro | Es el alias de `Invoke-WebRequest` | Trabaja dentro de WSL |
| `--http3` no se acepta | Tu curl no se compiló con HTTP/3 | Ver [versiones-de-curl.md](versiones-de-curl.md) |

---

[← Volver a la documentación](README.md)
