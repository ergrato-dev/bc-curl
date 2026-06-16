# Demo — api-toolkit.sh

## 1. Setup inicial

```bash
./api-toolkit.sh init
# Base URL: https://jsonplaceholder.typicode.com
# Token URL: https://httpbin.org/post
# Client ID: mi-cliente
# Client Secret: ***
# Timeout: 30
```

## 2. Verificación sin sesión

```bash
$ ./api-toolkit.sh get /posts/1
{
  "userId": 1,
  "id": 1,
  "title": "sunt aut facere repellat...",
  "body": "quia et suscipit..."
}
```

## 3. GET con --dry-run

```bash
$ ./api-toolkit.sh --dry-run get /posts/1
[INFO]  [DRY RUN] GET https://jsonplaceholder.typicode.com/posts/1
{}
```

## 4. POST

```bash
$ ./api-toolkit.sh post /posts '{"title":"Mi Post","body":"Contenido","userId":1}'
{
  "title": "Mi Post",
  "body": "Contenido",
  "userId": 1,
  "id": 101
}
```

## 5. Monitor

```bash
$ ./api-toolkit.sh monitor endpoints.txt
Monitor — 06:45:00
==============================
[OK   ] 200  0.312s  https://jsonplaceholder.typicode.com/posts/1
[OK   ] 200  0.287s  https://httpbin.org/get
[ERROR] 404  0.198s  https://httpbin.org/status/404
==============================
Resumen: OK=2 WARN=0 ERROR=1
```

## 6. Benchmark

```bash
$ ./api-toolkit.sh bench https://jsonplaceholder.typicode.com/posts/1 5
Benchmark: https://jsonplaceholder.typicode.com/posts/1 (5 requests)
==============================
  [ 1] 200  0.312s
  [ 2] 200  0.298s
  [ 3] 200  0.315s
  [ 4] 200  0.289s
  [ 5] 200  0.302s

  Min: 0.2890s  Avg: 0.3032s  Max: 0.3150s
  p50: 0.3020s  p90: 0.3150s  p99: 0.3150s
  Errores: 0 / 5
```

## 7. Logs

```bash
$ cat ~/.api-toolkit/requests.log
[2026-06-16T10:30:00+01:00] GET /posts/1 → 200
[2026-06-16T10:30:05+01:00] GET /posts/1 → 200
[2026-06-16T10:30:10+01:00] GET /posts/1 → 200
[2026-06-16T10:30:15+01:00] GET /posts/1 → 200
[2026-06-16T10:30:20+01:00] GET /posts/1 → 200
```
