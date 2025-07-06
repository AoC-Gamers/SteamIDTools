FROM golang:1.23-alpine AS builder

LABEL maintainer="lechuga"
LABEL description="SteamID Conversion Service for Game Servers (Go)"
LABEL version="2.0.0"

RUN apk update && apk upgrade && \
    apk add --no-cache git ca-certificates tzdata && \
    rm -rf /var/cache/apk/*

WORKDIR /app

COPY go/go.mod go/go.sum* ./
RUN go mod download

COPY go/ .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o steamid-service .

FROM alpine:3

RUN apk add --no-cache curl && \
    rm -rf /var/cache/apk/*

RUN adduser -D -s /bin/sh steamid

COPY --from=builder /app/steamid-service /steamid-service
COPY go/lang/*.json /lang/
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /steamid-service /healthcheck.sh

USER steamid

EXPOSE 80

HEALTHCHECK --interval=60s --timeout=5s --start-period=10s --retries=3 \
    CMD /healthcheck.sh || exit 1

ENTRYPOINT ["/steamid-service"]
