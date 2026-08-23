---
name: "Diagrama SVG"
description: "Genera un diagrama SVG para el Bootcamp curl con la paleta y las reglas del repositorio: tema oscuro, sin degradados, sans-serif, accesible."
argument-hint: "Semana, nombre del archivo (ej: 03-handshake-tls.svg) y qué tiene que mostrar el diagrama"
mode: "agent"
---

# Diagrama SVG — Bootcamp curl

## Antes de dibujar: ¿hace falta?

Un diagrama vale la pena cuando muestra **algo que el texto no puede**: una
secuencia temporal, una jerarquía, un flujo con ramas.

No lo hagas si:

- ❌ Es una lista con cajas alrededor. Eso es una lista.
- ❌ Es una tabla dibujada. Eso es una tabla.
- ❌ Repite lo que el bloque de código de al lado ya enseña.

Sí lo hace bien:

- ✅ El handshake TLS: quién manda qué y en qué orden
- ✅ El flujo de authorization code + PKCE, con los dos viajes
- ✅ El desglose de `%{time_*}`: qué trozo del tiempo mide cada variable
- ✅ Peticiones en serie contra peticiones en paralelo, en la misma escala

## Paleta obligatoria

| Rol | Hex |
|---|---|
| Lienzo | `#0d1117` |
| Superficie (cajas) | `#161b22` |
| Borde | `#30363d` |
| Texto principal | `#f0f6fc` |
| Texto secundario | `#8b949e` |
| Naranja curl (la petición) | `#f0883e` |
| Azul (la respuesta) | `#58a6ff` / `#79c0ff` |
| Verde (éxito, 2xx) | `#3fb950` |
| Amarillo (aviso, 3xx) | `#e3b341` |
| Rojo (error, 4xx/5xx) | `#f85149` |
| Morado (metadatos) | `#d2a8ff` |

## Reglas duras

- **Sin degradados.** Colores sólidos.
- **Sans-serif siempre**: `font-family="Inter, system-ui, -apple-system, sans-serif"`.
- **`viewBox` obligatorio**, sin `width`/`height` fijos en el elemento raíz, para
  que escale.
- **`role="img"` y un `<title>` descriptivo** como primer hijo, para lectores de
  pantalla.
- **Fondo explícito**: un `<rect>` de `#0d1117` que cubra el `viewBox`. Sin él,
  el diagrama se ve roto en el tema claro de GitHub.
- **Nada de texto de menos de 12 px** en el sistema de coordenadas del `viewBox`.
- **Arte ASCII prohibido.** Ni aquí ni en ningún `.md`.
- Nombre: `NN-nombre-descriptivo.svg`, numerado en orden de lectura.
- **Todo SVG tiene que quedar enlazado** desde algún `.md`:
  `![Descripción del diagrama](../0-assets/NN-nombre.svg)`.
  `scripts/verificar-enlaces.sh` falla si queda huérfano.
- El texto alternativo **describe el diagrama**, no repite el título del archivo.

## Esqueleto

```svg
<svg viewBox="0 0 800 400" role="img" xmlns="http://www.w3.org/2000/svg">
  <title>El handshake TLS entre curl y el servidor, mensaje a mensaje</title>
  <rect width="800" height="400" fill="#0d1117"/>

  <g font-family="Inter, system-ui, -apple-system, sans-serif" font-size="14">
    <rect x="40" y="40" width="180" height="60" rx="6"
          fill="#161b22" stroke="#30363d"/>
    <text x="130" y="76" fill="#f0f6fc" text-anchor="middle">curl</text>
  </g>
</svg>
```

$input
