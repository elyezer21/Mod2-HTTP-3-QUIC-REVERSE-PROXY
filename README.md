# Reverse Proxy — Librería Pequeño Morrison

Reverse Proxy basado en **Caddy**, utilizado como punto único de entrada de la plataforma **Librería Pequeño Morrison**. Este componente recibe todas las solicitudes del navegador y las redirige automáticamente hacia la **API REST**, el **servidor de WebSockets** o el **Frontend**, según la ruta solicitada. Caddy soporta de forma nativa **HTTP/1.1**, **HTTP/2** y **HTTP/3 (QUIC)**, permitiendo demostrar el funcionamiento de los distintos protocolos sin necesidad de configuraciones adicionales.

---

# Contenido del repositorio

| Archivo | Descripción |
|---------|-------------|
| `Dockerfile` | Construye la imagen personalizada de Caddy. |
| `Caddyfile` | Configuración del Reverse Proxy y de los protocolos HTTP. |
| `.env.example` | Variables de entorno necesarias para el proxy. |
| `docker-compose.yml` | Orquesta el servicio del Reverse Proxy dentro de la integración del proyecto. |

---

# 1. Configuración

Antes de iniciar el sistema, copiar el archivo de variables de entorno:

```bash
cp .env.example .env
```

Editar el archivo `.env` con los valores correspondientes:

```env
DOMAIN=localhost
API_REST_UPSTREAM=api-rest-gateway:3000
WEBSOCKET_UPSTREAM=websocket-server:8765
FRONTEND_UPSTREAM=frontend:8080
```

## Variables de entorno

| Variable | Descripción |
|----------|-------------|
| `DOMAIN` | Dominio del proyecto. Para pruebas locales utilizar `localhost`; Caddy generará automáticamente un certificado autofirmado. |
| `API_REST_UPSTREAM` | Nombre del servicio y puerto donde escucha la API REST Gateway. |
| `WEBSOCKET_UPSTREAM` | Nombre del servicio y puerto del servidor WebSocket. |
| `FRONTEND_UPSTREAM` | Nombre del servicio y puerto del Frontend. |

---

# 2. Ejecución de la integración

Una vez descargado y descomprimido el archivo **integracion-morrison-Mod2-V5.zip**, ubicar la terminal en la carpeta raíz del proyecto y ejecutar:

```bash
docker compose up --build
```

Este comando construirá y levantará automáticamente todos los servicios definidos en la integración, incluyendo:

- Reverse Proxy (Caddy)
- API REST Gateway
- Servidor gRPC
- Servidor WebSocket
- Base de datos
- Frontend

Cuando todos los contenedores estén ejecutándose, la aplicación podrá accederse desde:

```
https://localhost
```

En modo local el navegador mostrará una advertencia de seguridad debido al certificado autofirmado generado por Caddy; basta con aceptarla para continuar.

---

# 3. Arquitectura de la integración

La integración está compuesta por varios servicios que trabajan de manera conjunta.

| Servicio | Función |
|----------|---------|
| Reverse Proxy | Punto único de entrada utilizando Caddy. |
| API REST Gateway | Expone los endpoints REST del sistema. |
| Servidor gRPC | Comunicación interna entre servicios. |
| Servidor WebSocket | Comunicación en tiempo real con los clientes. |
| Frontend | Interfaz web de la plataforma. |
| Base de Datos | Persistencia de la información del sistema. |

---

# 4. Verificar la versión de HTTP utilizada

Para comprobar el protocolo utilizado por el navegador:

1. Abrir las herramientas de desarrollador.
2. Ir a la pestaña **Network**.
3. Hacer clic derecho sobre las columnas.
4. Habilitar la columna **Protocol**.
5. Recargar la página.

La columna mostrará alguno de los siguientes valores:

| Valor | Protocolo |
|-------|-----------|
| `h3` | HTTP/3 |
| `h2` | HTTP/2 |
| `http/1.1` | HTTP/1.1 |

---

# 5. Habilitar o deshabilitar HTTP/3

El archivo `Caddyfile` define los protocolos soportados mediante el siguiente bloque:

```caddy
{
    servers {
        protocols h1 h2 h3
    }
}
```

## Deshabilitar HTTP/3

Eliminar `h3` de la lista:

```caddy
protocols h1 h2
```

## Volver a habilitar HTTP/3

Agregar nuevamente:

```caddy
protocols h1 h2 h3
```

Aplicar los cambios reiniciando el contenedor:

```bash
docker compose restart reverse-proxy
```

Esto permite demostrar cómo el navegador negocia automáticamente el mejor protocolo disponible, utilizando HTTP/2 cuando HTTP/3 no está habilitado y regresando a HTTP/3 cuando vuelve a estar disponible.

---

# 6. Certificados TLS

## Desarrollo y demostración

El proyecto utiliza:

```caddy
tls internal
```

Con esta configuración, Caddy genera automáticamente un certificado autofirmado. La advertencia mostrada por el navegador durante el primer acceso es completamente normal.

## Producción

Para utilizar certificados válidos emitidos por Let's Encrypt, eliminar la línea:

```caddy
tls internal
```

Caddy emitirá y renovará automáticamente el certificado utilizando el dominio definido en la variable `DOMAIN`.

---

# 7. Rutas configuradas

| Ruta | Destino | Protocolo hacia el backend |
|------|---------|----------------------------|
| `/api/*` | API REST Gateway | HTTP/1.1 |
| `/ws*` | Servidor WebSocket | HTTP/1.1 + Upgrade |
| `/*` | Frontend | HTTP/1.1 |

El navegador negocia automáticamente **HTTP/1.1**, **HTTP/2** o **HTTP/3** con el Reverse Proxy, mientras que este reenvía todas las solicitudes a los servicios internos utilizando **HTTP/1.1**, protocolo suficiente para la comunicación entre los componentes de la plataforma.

---

# Arquitectura de comunicación

```text
                        Cliente
                           │
                           │ HTTP/1.1 / HTTP/2 / HTTP/3
                           ▼
                 +----------------------+
                 |    Reverse Proxy     |
                 |        Caddy         |
                 +----------------------+
                    │        │        │
                    │        │        │
                    ▼        ▼        ▼
          API REST Gateway  WebSocket  Frontend
                 │
                 ▼
           Servidor gRPC
                 │
                 ▼
            Base de Datos
```

El Reverse Proxy centraliza el acceso a todos los servicios de la plataforma, permitiendo que el cliente interactúe mediante HTTP/1.1, HTTP/2 o HTTP/3, mientras que la comunicación hacia los servicios internos se mantiene mediante HTTP/1.1, garantizando compatibilidad y simplicidad en la arquitectura.
