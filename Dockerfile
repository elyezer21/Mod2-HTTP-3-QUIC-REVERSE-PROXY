# Imagen oficial de Caddy. Incluye soporte para HTTP/1.1, HTTP/2 y HTTP/3
# (QUIC) de forma nativa desde la version 2.6, sin necesidad de plugins
# adicionales ni compilar con xcaddy.
FROM caddy:2-alpine

# Copiamos la configuracion del reverse proxy
COPY Caddyfile /etc/caddy/Caddyfile

# Puertos expuestos:
#   80/tcp   -> HTTP (redireccion automatica a HTTPS)
#   443/tcp  -> HTTPS (HTTP/1.1 y HTTP/2)
#   443/udp  -> HTTPS sobre QUIC (HTTP/3)
EXPOSE 80/tcp 443/tcp 443/udp
