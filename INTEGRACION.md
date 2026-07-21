# Integración completa — Módulo HTTP/3 + QUIC (Grupo 2)

Este entorno levanta **todo el sistema real**: ya no hay gateways ni datos
simulados. Los tres equipos entregaron su versión final (o corregida) y
este repositorio los integra tal cual, con el frontend adaptado al
contrato real de la API.

## Cambios de esta actualización

Los tres paquetes recibidos resultaron ser **reescrituras completas**, no
simples correcciones:

| Componente | Antes | Ahora |
|---|---|---|
| gRPC (Grupo 6) | Java + Maven + JDBC crudo | **Kotlin + Spring Boot + JPA/Hibernate**, con su propia imagen de PostgreSQL (`grpc/db/`) que ya trae el esquema y una siembra oficial (75 libros, 16 categorías) |
| API REST (Grupo 3) | Python simple, puerto 3000, `/compras`, sesión por query param | **TypeScript + Hono**, puerto 3124 (HTTP) + 3113 (TCP, reabastecimiento), rutas `/auth/register`, `/auth/login`, `/auth/logout`, `/books`, `/books/buy`, `/clients/me`; sesión en **cookie httpOnly** |
| Frontend (Equipo 1) | Hablaba con la API vieja | **Adaptado** a las rutas, nombres de campo y flujo de sesión reales |

**Ya no existe la sesión de invitado.** Registrarse (o iniciar sesión) es
obligatorio antes de ver el catálogo o comprar.

## Servicios

| Servicio           | Rol                                                | Puerto interno |
|---------------------|-----------------------------------------------------|----------------|
| `reverse-proxy`     | Único punto de entrada (HTTP/1.1, HTTP/2, HTTP/3)   | 80 / 443       |
| `frontend`          | Sitio de LittleMorrison (Equipo 1)                  | 80             |
| `api-rest`          | API REST real (Grupo 3, TypeScript + Hono)          | 3124 (HTTP), 3113 (TCP) |
| `morrison-smtp`     | MailHog — recibe los correos de factura de prueba   | 1025 (SMTP), 8025 (UI web) |
| `morrison-sftp`     | Servidor SFTP donde se suben los PDF de factura     | 22             |
| `grpc`              | Servicio gRPC real del Grupo 6 (Kotlin/Spring Boot) | 50051          |
| `postgres`          | Base de datos oficial del Grupo 6 (esquema + siembra propios) | 5432 |
| `websocket-server`  | Servidor de WebSockets real del Grupo 5             | 8765 / 8766    |

```
Browser → reverse-proxy → /api/* → api-rest (Hono) → gRPC → grpc → postgres
                                              └─ SFTP (factura PDF) + SMTP (correo)
                                              └─ POST /eventos → websocket-server
                        → /ws   → websocket-server
                        → /*    → frontend
```

El navegador **nunca** habla con `grpc`, `postgres`, `morrison-smtp` ni
`morrison-sftp` directamente — todo pasa por el reverse proxy.

## Endpoints reales de la API REST

| Ruta                | Método | Requiere sesión | Descripción                                   |
|----------------------|--------|:---:|------------------------------------------------|
| `/api/auth/register` | POST   |    | `{ fullName, email, password }` → crea la cuenta |
| `/api/auth/login`    | POST   |    | `{ email, password }` → setea la cookie de sesión y devuelve `{ message, sessionId, fullName }` |
| `/api/auth/logout`   | POST   | ✓  | Cierra la sesión                               |
| `/api/clients/me`    | GET    | ✓  | `{ fullName, email, balance }`                 |
| `/api/books`         | GET    | ✓  | Catálogo (filtros opcionales `category`, `minPrice`, `maxPrice`) |
| `/api/books/buy`     | POST   | ✓  | `{ bookId, quantity }`                         |

Toda respuesta exitosa llega envuelta como `{ content: ... }` y los
errores como `{ errors: ... }` (string o `{formErrors, fieldErrors}` de
Zod); `assets/js/api.js` ya desempaqueta esto.

## Fix aplicado sobre el código del Grupo 3

`routes/auth.ts` (`/auth/login`) solo devolvía un string de bienvenida.
Como la cookie de sesión es `httpOnly`, el frontend no puede leerla para
identificar la conexión de WebSocket (`/ws?sessionId=...`). Se modificó
la respuesta para incluir también `sessionId` y `fullName` en el cuerpo
JSON (el dato ya existía en `LoginResponse`, solo faltaba exponerlo).

## Contrato de eventos WebSocket (verificado, sin cambios)

Se comparó `api-rest/src/services/WebSocketService.ts` contra el
`websocket-server/server.py` real del Grupo 5: **ambos usan `sessionId`**
como clave de sesión (query param de conexión y campo en los eventos
`purchase_approved` / `purchase_denied`), así que no hubo que tocar nada
en el servidor de WebSockets.

- **`purchase_approved`**: `sessionId`, `bookId`, `bookTitle`, `quantity`,
  `booksLeft`.
- **`purchase_denied`**: `sessionId`, `bookTitle`, `reason` (código de
  dominio en bruto, p. ej. `INSUFFICIENT_STOCK`; el frontend lo traduce
  con `LMApi.denialReasonLabel`).
- **`stock_change`** (broadcast): `books: [{ id, stockRemaining }]`.

⚠️ **Limitación real y ya contemplada:** ni `BuyBookResponse` (proto del
Grupo 6) ni el evento `purchase_approved` incluyen el saldo restante del
cliente — solo el stock restante del libro. El frontend ya no espera ese
campo: llama a `GET /clients/me` justo después de una compra (y al
recibir el evento) para refrescar el saldo mostrado.

## Envío de factura (SFTP/SMTP) best-effort

Si el servidor SFTP o SMTP no están disponibles, la compra **igual se
completa** — esos pasos fallan en silencio (se registran en el log del
contenedor `api-rest`, no interrumpen la respuesta al cliente).

## Cómo probar

```bash
docker compose up --build
```

La primera vez tarda más porque compila el servicio Kotlin (Gradle/Maven)
y construye la imagen de PostgreSQL con el esquema y la siembra oficiales.
Con todo arriba:

1. Abre `https://localhost` (acepta el certificado autofirmado).
2. Como ya no hay sesión de invitado, crea una cuenta o inicia sesión
   antes de ver el catálogo (la página redirige sola si no hay sesión).
3. El catálogo viene de PostgreSQL vía gRPC (75 libros reales).
4. Compra un libro: el stock se actualiza en tiempo real por WebSocket y
   el saldo se refresca automáticamente contra `/clients/me`.
5. Revisa `http://localhost:8025` (MailHog) para ver el correo de factura
   simulado.
6. Verifica la negociación HTTP/3 en DevTools → Network → columna
   *Protocol*, como en las pruebas anteriores.

## Pendiente / a confirmar con otros grupos

- Confirmar con el Grupo 1 (frontend) los cambios pendientes de catálogo
  que mencionaron querer agregar, para no perder ese trabajo en la
  próxima entrega.
- El servicio gRPC expone también `RestockBook` (reabastecimiento) vía el
  puerto TCP 3113 de la API REST; no hay UI para esto todavía.
