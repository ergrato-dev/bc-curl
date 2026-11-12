# Videografía — Semana 09

_Comprobado el 11 de noviembre de 2026: los seis enlaces resuelven y el
título coincide con el que aparece aquí._

Pocos y elegidos. Un vídeo solo entra aquí si enseña algo que en texto se
entiende peor.

| Recurso | Por qué vale la pena |
|---|---|
| ["How NOT to Measure Latency" by Gil Tene](https://www.youtube.com/watch?v=lJ8ydIuPFeU) — Strange Loop Conference | La charla clásica sobre por qué la media miente, qué son los percentiles y cómo un medidor que espera la respuesta se esconde la cola (*coordinated omission*). Es la teoría 05 contada por quien la popularizó |
| [How HTTP/2 Works, Performance, Pros & Cons and More](https://www.youtube.com/watch?v=fVKPrDrEwTI) — Hussein Nasser | HTTP/2 desde el lado del backend: streams, multiplexación y lo que cuesta al servidor. Buen complemento visual de la teoría 03 |
| [Where http2 hits its limit](https://www.youtube.com/watch?v=beDiiWE8ESM) — Hussein Nasser | Lo que HTTP/2 no arregla: el head-of-line blocking de TCP y los límites de streams. Por qué existe HTTP/3 |
| [Davey Shafik - HTTP/2 and Asynchronous APIs - PyCon 2016](https://www.youtube.com/watch?v=Mou17XxYRZk) — PyCon 2016 | Qué cambia HTTP/2 para quien consume APIs: reutilización, multiplexación y por qué muchas peticiones pequeñas dejan de ser un problema |
| [Daniel Stenberg - HTTP/3: why and where are we? \| Øredev 2023](https://www.youtube.com/watch?v=da_qW_xXabY) — Øredev Conference | El autor de curl explica QUIC y HTTP/3: qué arregla, cuánto tráfico lo usa ya y por qué desplegarlo es difícil |
| [HTTP/3 with curl at curl up 2022 with Daniel Stenberg](https://www.youtube.com/watch?v=TTCKl9-AydU) — Daniel Stenberg | Cómo se compila curl con HTTP/3 y por qué tu distribución no lo trae. El porqué del `--http3` que sale con 2 |

> [!TIP]
> Si tienes poco tiempo, el primero. Cambia para siempre cómo lees un
> "tarda 120 ms de media".

Para lo demás, el laboratorio rinde más que un vídeo: medir ocho `/delay/1`
con y sin `--parallel-immediate` enseña más que verlo contado.

---

| Anterior | Siguiente |
|---|---|
| [Libros gratuitos](../ebooks-free/README.md) | [Webgrafía](../webgrafia/README.md) |
