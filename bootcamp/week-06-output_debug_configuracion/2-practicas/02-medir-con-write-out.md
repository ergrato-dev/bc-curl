# Práctica 02 — Medir con `--write-out`

> **Duración**: 50 min · **Entregables**: `fases.md`

Vas a construir un formato de `-w` en un archivo y caer en su trampa, leer el
cuerpo y el código de una misma salida, medir las fases de una petición HTTP y
de una HTTPS y convertirlas en duraciones con awk, alargar a propósito la fase
del servidor y la de transferencia, y medir una petición que falla. Todo lo que
haces aquí lo hará `--timing` en el proyecto.

**Antes de empezar**, desde la raíz del repositorio:

```bash
./scripts/start.sh
export CA="$PWD/docs/lab-ca.pem"
mkdir -p ~/bc-curl-trabajo/semana-06/p2 && cd ~/bc-curl-trabajo/semana-06/p2
```

---

## Paso 1: Un formato en un archivo

**Por qué**: un formato que usan varios scripts tiene que vivir en un solo
sitio. Y el archivo tiene una trampa que conviene pisar una vez.

**Comando**:

```bash
# Primer intento: saltos de linea reales
printf 'codigo=%%{http_code}\nbytes=%%{size_download}\nfinal=%%{url_effective}\n' > ingenuo.txt
curl -s -o /dev/null -L -w @ingenuo.txt http://localhost:8080/redirect/1; echo

# Segundo intento: \n escrito como texto
cat > formato.txt <<'EOF'
codigo=%{http_code}\n
bytes=%{size_download}\n
final=%{url_effective}\n
EOF
curl -s -o /dev/null -L -w @formato.txt http://localhost:8080/redirect/1
```

**Verifica**:

```bash
curl -s -o /dev/null -L -w @ingenuo.txt http://localhost:8080/redirect/1; echo
# codigo=200bytes=245final=http://localhost:8080/get
curl -s -o /dev/null -L -w @formato.txt http://localhost:8080/redirect/1
# codigo=200
# bytes=245
# final=http://localhost:8080/get
```

curl descarta los saltos de línea reales del archivo. Apunta en `fases.md` por
qué el `<<'EOF'` lleva comillas.

---

## Paso 2: Una variable que no existe

**Por qué**: el error más probable con `-w` no es de sintaxis: es una variable
con un nombre plausible que no existe. curl no falla.

**Comando**:

```bash
curl -s -o /dev/null -w 'codigo=%{status_code}\n' http://localhost:8080/get 2> aviso.txt
echo "salida: $?"
```

**Verifica**:

```bash
curl -s -o /dev/null -w 'codigo=%{status_code}\n' http://localhost:8080/get 2> aviso.txt; echo "salida: $?"
# codigo=
# salida: 0
cat aviso.txt
# curl: unknown --write-out variable: 'status_code'
```

Salida 0 y una cadena vacía. Un script que compare `codigo` con `200` dirá que
la API falla, cuando es el script el que falla. Repite con `%{http_code}` y con
`%{response_code}`: las dos existen.

---

## Paso 3: Cuerpo y código en la misma salida

**Por qué**: el script necesita el cuerpo para procesarlo y el código para
decidir, y no quiere hacer dos peticiones.

**Comando**:

```bash
salida=$(curl -sS -w '\n%{http_code}' http://localhost:8080/status/418)
codigo="${salida##*$'\n'}"
cuerpo="${salida%$'\n'*}"
printf 'codigo=[%s]\n' "$codigo"
printf '%s\n' "$cuerpo" | head -3
```

**Verifica**:

```bash
printf 'codigo=[%s]\n' "$codigo"
# codigo=[418]
printf '%s' "$cuerpo" | grep -c teapot
# 1            ← el cuerpo del 418, sin el codigo pegado
```

Ahora quita el `\n` del principio del formato (`-w '%{http_code}'`) y repite.
El cuerpo de `/status/418` no termina en salto de línea: el código queda pegado
a su última línea y `${salida##*$'\n'}` devuelve otra cosa. Apúntalo en
`fases.md`.

---

## Paso 4: Las fases de HTTP y de HTTPS

**Por qué**: los `time_*` son instantes acumulados. Para saber cuánto duró
cada fase hay que restar, y una resta mal hecha da negativos.

**Comando**:

```bash
I='%{time_namelookup} %{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total}\n'
curl -s -o /dev/null -w "$I" http://localhost:8080/get        > http.txt
curl -s -o /dev/null -w "$I" --cacert "$CA" https://localhost:8443/get > https.txt
cat http.txt https.txt
```

**Verifica**:

```bash
cat http.txt https.txt
# 0.000014 0.000113 0.000000 0.000727 0.000774      ← tercer campo a cero: sin TLS
# 0.000019 0.000156 0.003845 0.006919 0.006986
```

Resta a ciegas el tercero menos el segundo en la línea de HTTP:
`0.000000 - 0.000113` es negativo. Ese es el error que la función del paso
siguiente tiene que evitar.

---

## Paso 5: De instantes a duraciones

**Por qué**: bash no sabe restar decimales. awk sí, y la regla del cero se
escribe una vez.

**Comando**:

```bash
fases() {
  awk '{
    fin_tls = ($3 > 0) ? $3 : $2
    printf "dns=%.6f tcp=%.6f tls=%.6f servidor=%.6f transferencia=%.6f total=%.6f\n",
           $1, $2 - $1, fin_tls - $2, $4 - fin_tls, $5 - $4, $5
  }'
}
fases < http.txt
fases < https.txt
```

**Verifica**:

```bash
fases < http.txt
# dns=0.000014 tcp=0.000099 tls=0.000000 servidor=0.000614 transferencia=0.000047 total=0.000774
fases < https.txt
# dns=0.000019 tcp=0.000137 tls=0.003689 servidor=0.003074 transferencia=0.000067 total=0.006986
fases < https.txt | awk '{ for (i = 1; i <= 5; i++) { split($i, kv, "="); s += kv[2] }
  split($6, t, "="); printf "suma=%.6f total=%s\n", s, t[2] }'
# suma=0.006986 total=0.006986
```

Las cinco fases suman el total: ninguna se solapa, ninguna falta. Copia en
`fases.md` las dos líneas y explica por qué `tls=0.000000` en HTTP.

---

## Paso 6: Provocar cada fase

**Por qué**: hasta que no ves una fase crecer a propósito, no sabes
reconocerla cuando crece sola.

**Comando**:

```bash
curl -s -o /dev/null -w "$I" http://localhost:8080/delay/1 | fases
curl -s -o /dev/null -w "$I" 'http://localhost:8080/drip?duration=1&numbytes=5&delay=0' | fases
```

**Verifica**:

```bash
curl -s -o /dev/null -w "$I" http://localhost:8080/delay/1 | fases
# dns=0.000019 tcp=0.000127 tls=0.000000 servidor=1.001669 transferencia=0.000072 total=1.001887
curl -s -o /dev/null -w "$I" 'http://localhost:8080/drip?duration=1&numbytes=5&delay=0' | fases
# dns=0.000016 tcp=0.000104 tls=0.000000 servidor=0.000645 transferencia=1.000755 total=1.001520
```

El total es el mismo segundo. En el primero lo gasta el servidor pensando; en
el segundo, mandando. Apunta en `fases.md` a quién llamarías en cada caso.

---

## Paso 7: Medir un fallo

**Por qué**: un fallo es justo lo que más interesa registrar, y `-w` también
se imprime cuando curl falla. Hay que saber qué sale.

**Comando**:

```bash
curl -s -o /dev/null -w '%{http_code} %{exitcode} %{errormsg}\n' http://127.0.0.1:9/
curl -s -o /dev/null -w "$I" http://127.0.0.1:9/ | fases
```

**Verifica**:

```bash
curl -s -o /dev/null -w '%{http_code} %{exitcode} %{errormsg}\n' http://127.0.0.1:9/
# 000 7 Failed to connect to 127.0.0.1 port 9 after 0 ms: Connection refused
curl -s -o /dev/null -w "$I" http://127.0.0.1:9/ | fases
# dns=0.000021 tcp=-0.000021 tls=0.000000 servidor=0.000000 transferencia=0.000155 total=0.000155
```

Un `tcp` negativo y una `transferencia` que no existió: sin conexión,
`time_connect` y `time_starttransfer` valen 0. La función del paso 5 no está
lista para un fallo. Arréglala con dos reglas, y anótalas en `fases.md`:

1. Ninguna duración baja de 0.
2. Si `time_starttransfer` es 0, no hubo respuesta: servidor y transferencia
   valen 0.

```bash
fases() {
  awk 'function dur(a, b) { return (b > a) ? b - a : 0 }
  {
    fin_tls  = ($3 > 0) ? $3 : $2
    fin_ttfb = ($4 > 0) ? $4 : $5
    printf "dns=%.6f tcp=%.6f tls=%.6f servidor=%.6f transferencia=%.6f total=%.6f\n",
           $1, dur($1, $2), dur($2, fin_tls), dur(fin_tls, $4), dur(fin_ttfb, $5), $5
  }'
}
curl -s -o /dev/null -w "$I" http://127.0.0.1:9/ | fases
# dns=0.000021 tcp=0.000000 tls=0.000000 servidor=0.000000 transferencia=0.000000 total=0.000155
```

Es exactamente la función `fases` del TODO 4 del proyecto, con la forma de
sus argumentos cambiada.

---

## Paso 8: Todo en JSON

**Por qué**: con siete campos separados por espacios, un `errormsg` con
espacios rompe el `read`. `%{json}` no se rompe.

**Comando**:

```bash
curl -s -o /dev/null -w '%{json}' http://127.0.0.1:9/ \
  | jq -c '{http_code, exitcode, errormsg, time_total}'
curl -s -o /dev/null -w '%{json}' http://localhost:8080/get | jq 'keys | length'
```

**Verifica**:

```bash
curl -s -o /dev/null -w '%{json}' http://127.0.0.1:9/ | jq -c '{http_code, exitcode}'
# {"http_code":0,"exitcode":7}
curl -s -o /dev/null -w '%{json}' http://localhost:8080/get | jq 'keys | length'
# 39           ← cuantas variables sabe tu curl; mas en versiones nuevas
```

En JSON el código del fallo es `0`, no `000`: `000` no es un número JSON
válido. El proyecto escribe sus métricas con `jq --argjson`, y por eso
convierte el `000` a `0` antes.

---

## Paso 9: La medida por stderr

**Por qué**: en un pipe, la medida no puede ir por stdout o el siguiente
comando la recibe como si fuera cuerpo.

**Comando**:

```bash
curl -sS -w '%{stderr}codigo=%{http_code} total=%{time_total}\n' \
  http://localhost:8080/get 2> medida.txt | jq -r .url
```

**Verifica**:

```bash
curl -sS -w '%{stderr}codigo=%{http_code} total=%{time_total}\n' \
  http://localhost:8080/get 2> medida.txt | jq -r .url
# http://localhost:8080/get                ← jq recibio solo el JSON
cat medida.txt
# codigo=200 total=0.000912
```

`--timing` en el proyecto hace lo mismo con otra técnica: lee la línea de `-w`
por stdout, la separa del cuerpo, y la imprime por stderr ya convertida en
fases.

---

## ✅ Resultado

- [ ] `formato.txt` saca tres líneas y sé por qué `ingenuo.txt` saca una
- [ ] He visto una variable inexistente salir vacía con código 0
- [ ] Separo cuerpo y código de una misma salida, y sé por qué el `\n` va delante
- [ ] `fases.md` tiene las fases de HTTP y HTTPS, su suma, y por qué `tls` es 0 en HTTP
- [ ] He alargado la fase servidor con `/delay` y la de transferencia con `/drip`
- [ ] Mi `fases` no da negativos ni ante un fallo de conexión

```bash
./scripts/verificar-semana.sh 06
```

Esta práctica prepara `FORMATO_W` (TODO 3), `fases` (TODO 4) y la parte de
`--timing` de `medir` (TODO 5).

---

## 🧯 Si algo sale mal

| Síntoma | Causa probable | Solución |
|---|---|---|
| El paso 1 saca tres líneas también con `ingenuo.txt` | Tu curl trata el archivo de otra forma | Es posible en versiones futuras; el `\n` escrito funciona en todas |
| `awk: syntax error` en `fases` | Copiaste el bloque partido y falta una llave | Copia la función entera de una vez |
| En el paso 6, `/drip` no tarda | Se perdieron los parámetros: sin comillas, el `&` manda el comando al fondo y corta la URL | Copia la URL con las comillas simples |
| El paso 7 da `000 7` pero sin mensaje | Tu curl es anterior a 7.75 y no tiene `%{errormsg}` | Actualiza; o usa `-sS` y lee stderr |
| `jq: error: Cannot iterate over null` en el paso 8 | Tu curl es anterior a 7.70: `%{json}` sale literal | Actualiza curl; el resto de la práctica funciona igual |
| La suma del paso 5 no cuadra en el último decimal | Redondeo de `%.6f` | Basta con que difiera en un microsegundo |

---

| Anterior | Siguiente |
|---|---|
| [Práctica 01 — Leer una traza](01-leer-una-traza.md) | [Práctica 03 — `.curlrc` sin romper scripts](03-curlrc-sin-romper-scripts.md) |
