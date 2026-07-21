# Reverse Proxy — Librería Pequeño Morrison

Reverse Proxy basado en **Caddy**, punto único de entrada de la plataforma.
Soporta **HTTP/1.1, HTTP/2 y HTTP/3 (QUIC)** de forma nativa y redirige cada
solicitud del navegador hacia la **API REST** o el **servidor de WebSockets**
según la ruta solicitada.

## Contenido del repositorio

| Archivo | Descripción |
|---|---|
| `Dockerfile` | Imagen de Caddy con la configuración del proxy. |
| `Caddyfile` | Configuración de enrutamiento y protocolos. |
| `.env.example` | Variables de entorno necesarias. |
| `docker-compose.yml` | Levanta el proxy de forma aislada, para pruebas. |
| `docker-compose.snippet.yml` | Bloque listo para copiar al `docker-compose.yml` principal. |

## 1. Configuración

```bash
cp .env.example .env
```

Editar `.env` con los valores reales:

```
DOMAIN=localhost
API_REST_UPSTREAM=api-rest:3000
WEBSOCKET_UPSTREAM=websocket-server:8765
FRONTEND_UPSTREAM=frontend:8080
```

- `DOMAIN`: dominio público del proyecto. Si no hay dominio (pruebas locales
  o demo), dejar `localhost`; Caddy generará un certificado autofirmado.
- `API_REST_UPSTREAM` / `WEBSOCKET_UPSTREAM` / `FRONTEND_UPSTREAM`: nombre del
  servicio (tal como aparece en el `docker-compose.yml`) y puerto interno en
  el que escucha cada uno.

## 2. Probar el proxy de forma aislada (opcional)

Antes de integrarlo al repositorio principal se puede levantar solo, con
contenedores de prueba (`traefik/whoami`) en lugar de la API real:

```bash
docker compose up --build
```

Con `DOMAIN=localhost`, ajustar en `.env`:

```
API_REST_UPSTREAM=api-rest-test:80
WEBSOCKET_UPSTREAM=websocket-test:80
```

Luego abrir `https://localhost/api/` y `https://localhost/ws` en el
navegador (el certificado será autofirmado, aceptar la advertencia).

## 3. Integración al repositorio principal (Git Submodule)

Desde el repositorio principal:

```bash
git submodule add <URL_DE_ESTE_REPOSITORIO> reverse-proxy
git submodule update --init --recursive
```

Copiar el contenido de `docker-compose.snippet.yml` dentro del
`docker-compose.yml` principal, ajustando:

- La ruta de `build.context` (debe apuntar a la carpeta `reverse-proxy`).
- Los nombres de servicio `api-rest` y `websocket-server` a los que usen
  realmente los otros equipos.
- Agregar los volúmenes `caddy_data` y `caddy_config` a la sección
  `volumes:` global del compose principal.

Copiar también `.env.example` como `reverse-proxy/.env` con los valores
reales de producción/demo.

## 4. Verificar la versión de HTTP usada por el navegador

1. Abrir las **DevTools** del navegador → pestaña **Network**.
2. Click derecho sobre la cabecera de columnas → habilitar la columna
   **Protocol**.
3. Recargar la página: se mostrará `h3` (HTTP/3), `h2` (HTTP/2) o
   `http/1.1` según lo que el navegador haya negociado con Caddy.

## 5. Habilitar / deshabilitar HTTP/3 durante la demostración

En el `Caddyfile`, el bloque global controla los protocolos activos:

```caddyfile
{
	servers {
		protocols h1 h2 h3
	}
}
```

- **Para deshabilitar HTTP/3**: quitar `h3` de la lista (dejar `protocols h1 h2`).
- **Para volver a habilitarlo**: agregar `h3` de nuevo.

Después de editar el archivo, reiniciar el contenedor para aplicar el cambio:

```bash
docker compose restart reverse-proxy
```

Esto permite mostrar en vivo cómo el navegador cae automáticamente a
HTTP/2 (o HTTP/1.1) cuando HTTP/3 no está disponible, y cómo vuelve a
usar HTTP/3 cuando se rehabilita.

## 6. Certificados TLS

- **Demo / red local sin dominio público**: se usa `tls internal` en el
  `Caddyfile`, que genera un certificado autofirmado. El navegador mostrará
  una advertencia de seguridad la primera vez (normal, aceptar y continuar).
- **Producción con dominio real**: quitar la línea `tls internal` del
  `Caddyfile`; Caddy emitirá y renovará automáticamente un certificado
  válido vía Let's Encrypt usando el valor de `DOMAIN`.

## 7. Rutas configuradas

| Ruta | Destino | Protocolo hacia el backend |
|---|---|---|
| `/api/*` | API REST | HTTP/1.1 |
| `/ws*` | Servidor de WebSockets | HTTP/1.1 + Upgrade |
| `/*` (resto) | Frontend de la librería | HTTP/1.1 |

El navegador siempre habla con el reverse proxy usando HTTP/1.1, HTTP/2 o
HTTP/3, según lo que negocie; el proxy siempre reenvía hacia los backends
internos usando HTTP/1.1, que es lo único que estos requieren soportar.
