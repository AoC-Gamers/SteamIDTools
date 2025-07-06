# Multi-stage build para Go - imagen ultra-optimizada y segura
FROM golang:1.23-alpine AS builder

# Metadata
LABEL maintainer="lechuga"
LABEL description="SteamID Conversion Service for Game Servers (Go)"
LABEL version="2.0.0"

# Actualizar packages y instalar dependencias de build
RUN apk update && apk upgrade && \
    apk add --no-cache git ca-certificates tzdata && \
    rm -rf /var/cache/apk/*

# Configurar directorio de trabajo
WORKDIR /app

# Copiar archivos Go
COPY go/go.mod go/go.sum* ./
RUN go mod download

COPY go/ .

# Compilar binario estático optimizado
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o steamid-service .

# Imagen final ultra-segura pero con herramientas mínimas para health check
FROM alpine:3

# Instalar solo curl para health check
RUN apk add --no-cache curl && \
    rm -rf /var/cache/apk/*

# Crear usuario no-root
RUN adduser -D -s /bin/sh steamid

# Copiar binario
COPY --from=builder /app/steamid-service /steamid-service

# Copiar todos los archivos de idioma presentes y futuros
COPY go/lang/*.json /lang/

# Copiar script de healthcheck
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /steamid-service /healthcheck.sh

# Cambiar a usuario no-root
USER steamid

# Exponer puerto (configurable via ENV)
EXPOSE 80

# Health check usando script externo
HEALTHCHECK --interval=60s --timeout=5s --start-period=10s --retries=3 \
    CMD /healthcheck.sh || exit 1

# Comando de inicio
ENTRYPOINT ["/steamid-service"]
