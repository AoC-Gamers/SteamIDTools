GO ?= go
GOLANGCI_LINT ?= golangci-lint
GOSEC ?= gosec
NANCY ?= nancy
SWAG ?= swag
GOLANGCI_LINT_VERSION ?= 2.4.0
GOSEC_VERSION ?= 2.23
NANCY_VERSION ?= v1.2.0
SWAG_VERSION ?= v1.16.6
GO_DIR := go

.PHONY: help deps fmt swagger test lint gosec build clean

help:
	@echo "Available targets:"
	@echo "  make deps   - download, tidy and verify Go dependencies"
	@echo "  make fmt    - format Go code"
	@echo "  make swagger - generate Swagger docs"
	@echo "  make test   - run Go tests"
	@echo "  make lint   - run golangci-lint $(GOLANGCI_LINT_VERSION)"
	@echo "  make gosec  - run gosec $(GOSEC_VERSION) security checks"
	@echo "  make build  - build the backend binary"
	@echo "  make clean  - clean Go caches and build artifacts"
	@echo ""
	@echo "Pinned tool versions:"
	@echo "  golangci-lint $(GOLANGCI_LINT_VERSION)"
	@echo "  gosec        $(GOSEC_VERSION)"
	@echo "  nancy        $(NANCY_VERSION)"
	@echo "  swag         $(SWAG_VERSION)"

deps:
	@echo "Updating dependencies..."
	cd $(GO_DIR) && $(GO) mod download
	cd $(GO_DIR) && $(GO) mod tidy
	cd $(GO_DIR) && $(GO) mod verify

fmt:
	@echo "Formatting code..."
	cd $(GO_DIR) && $(GO) fmt ./...

swagger:
	@echo "Generating Swagger docs..."
	cd $(GO_DIR) && $(GO) run github.com/swaggo/swag/cmd/swag@$(SWAG_VERSION) init -g main.go -d ./cmd/steamid-service,./internal/app -o ./internal/app/docs --parseInternal

test:
	cd $(GO_DIR) && $(GO) test ./...

lint:
	cd $(GO_DIR) && $(GOLANGCI_LINT) run ./...

gosec:
	cd $(GO_DIR) && $(GOSEC) ./cmd/steamid-service/... ./internal/app/...

build:
	cd $(GO_DIR) && $(GO) build ./cmd/steamid-service

clean:
	@echo "Cleaning..."
	cd $(GO_DIR) && $(GO) clean -cache -testcache -modcache
	@if [ -d "$(GO_DIR)/bin" ]; then rm -rf "$(GO_DIR)/bin"; fi
	@if [ -f "$(GO_DIR)/steamid-service" ]; then rm -f "$(GO_DIR)/steamid-service"; fi
	@if [ -f "$(GO_DIR)/steamid-service.exe" ]; then rm -f "$(GO_DIR)/steamid-service.exe"; fi
