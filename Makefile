# Makefile for SteamID Conversion Service (Go)
.PHONY: help build test deploy stop logs clean all status restart dev-run dev-test info health

# Variables
DOCKER_IMAGE = steamid-service:latest
DOCKER_CONTAINER = steamid-service
TEST_PORT = 8081
TEST_STEAMID64 = 76561197960287930
TEST_ACCOUNTID = 22202
TEST_STEAMID2 = STEAM_1:0:11101

# Default command
help: ## Show this help
	@echo "SteamID Conversion Service (Go) - Available commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build Docker image
	@echo "🔨 Building Docker image (Go)..."
	docker build -t $(DOCKER_IMAGE) .
	@echo "✅ Image built successfully"
	@echo "📊 Image size:"
	@docker images $(DOCKER_IMAGE) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

test: ## Run full container tests
	@echo "🧪 Running full tests..."
	@echo "Starting temporary container for tests..."
	$(eval CONTAINER_ID := $(shell docker run -d -p $(TEST_PORT):80 $(DOCKER_IMAGE)))
	@sleep 5
	@echo "Testing endpoints..."
	@echo "  🔹 Testing SID64toAID..."
	@curl -f "http://localhost:$(TEST_PORT)/SID64toAID?steamid=$(TEST_STEAMID64)" > /dev/null || (docker logs $(CONTAINER_ID) && docker stop $(CONTAINER_ID) && docker rm $(CONTAINER_ID) && exit 1)
	@echo "  🔹 Testing AIDtoSID64..."
	@curl -f "http://localhost:$(TEST_PORT)/AIDtoSID64?steamid=$(TEST_ACCOUNTID)" > /dev/null || (docker logs $(CONTAINER_ID) && docker stop $(CONTAINER_ID) && docker rm $(CONTAINER_ID) && exit 1)
	@echo "  🔹 Testing SID2toSID64..."
	@curl -f "http://localhost:$(TEST_PORT)/SID2toSID64?steamid=$(TEST_STEAMID2)" > /dev/null || (docker logs $(CONTAINER_ID) && docker stop $(CONTAINER_ID) && docker rm $(CONTAINER_ID) && exit 1)
	@echo "  🔹 Testing health check..."
	@curl -f "http://localhost:$(TEST_PORT)/health" > /dev/null || (docker logs $(CONTAINER_ID) && docker stop $(CONTAINER_ID) && docker rm $(CONTAINER_ID) && exit 1)
	@echo "  🔹 Testing batch processing..."
	@curl -f "http://localhost:$(TEST_PORT)/SID64toAID?steamid=$(TEST_STEAMID64),76561197960287931" > /dev/null || (docker logs $(CONTAINER_ID) && docker stop $(CONTAINER_ID) && docker rm $(CONTAINER_ID) && exit 1)
	@docker stop $(CONTAINER_ID) > /dev/null
	@docker rm $(CONTAINER_ID) > /dev/null
	@echo "✅ All tests passed successfully"

deploy: ## Deploy service with docker-compose
	@echo "🚀 Deploying SteamID service (Go)..."
	@if [ ! -f .env ]; then \
		echo "⚠️  .env file not found, creating from .env.example"; \
		cp .env.example .env; \
	fi
	@echo "📋 Current configuration:"
	@grep -E '^(PORT|HOST|SID2_UNIVERSE)=' .env 2>/dev/null || echo "Using default values"
	docker-compose up -d --build
	@echo "✅ Service deployed successfully"
	@echo ""
	@echo "📊 Service status:"
	@docker-compose ps
	@echo ""
	@echo "🌐 Available endpoints:"
	@echo "  http://localhost:$$(grep '^PORT=' .env 2>/dev/null | cut -d'=' -f2 || echo '80')/SID64toAID?steamid=$(TEST_STEAMID64)"
	@echo "  http://localhost:$$(grep '^PORT=' .env 2>/dev/null | cut -d'=' -f2 || echo '80')/health"

stop: ## Stop service
	@echo "🛑 Stopping service..."
	docker-compose down
	@echo "✅ Service stopped"

logs: ## Show service logs
	docker-compose logs -f

status: ## Show service status
	@echo "📊 Service status:"
	@docker-compose ps
	@echo ""
	@echo "📋 Last logs:"
	@docker-compose logs --tail=10

clean: ## Clean images, containers and temp files
	@echo "🧹 Cleaning resources..."
	@echo "  🛑 Stopping services..."
	@docker-compose down 2>/dev/null || true
	@echo "  🗑️  Removing image..."
	@docker rmi $(DOCKER_IMAGE) 2>/dev/null || true
	@echo "  🗑️  Cleaning unused containers..."
	@docker container prune -f 2>/dev/null || true
	@echo "✅ Cleanup completed"

clean-all: ## Full cleanup (including volumes and networks)
	@echo "🧹 Full system cleanup..."
	@docker-compose down -v --remove-orphans 2>/dev/null || true
	@docker rmi $(DOCKER_IMAGE) 2>/dev/null || true
	@docker system prune -f 2>/dev/null || true
	@echo "✅ Full cleanup finished"

restart: stop deploy ## Restart service

all: build test deploy ## Build, test and deploy

# Development commands
dev-run: ## Run service in development mode (without Docker)
	@echo "🔧 Running in development mode (Go)..."
	@cd go && go run main.go

dev-test: ## Run full tests in development mode
	@echo "🧪 Running tests in development mode..."
	@echo "Make sure the service is running in another terminal (make dev-run)"
	@echo ""
	@echo "🔹 Testing individual conversions:"
	@echo -n "  SID64toAID: "
	@curl -s "http://localhost:80/SID64toAID?steamid=$(TEST_STEAMID64)"
	@echo ""
	@echo -n "  AIDtoSID64: "
	@curl -s "http://localhost:80/AIDtoSID64?steamid=$(TEST_ACCOUNTID)"
	@echo ""
	@echo -n "  SID2toSID64: "
	@curl -s "http://localhost:80/SID2toSID64?steamid=$(TEST_STEAMID2)"
	@echo ""
	@echo -n "  Health: "
	@curl -s "http://localhost:80/health"
	@echo ""
	@echo ""
	@echo "🔹 Testing batch processing:"
	@curl -s "http://localhost:80/SID64toAID?steamid=$(TEST_STEAMID64),76561197960287931"
	@echo ""

health: ## Check health of deployed service
	@echo "❤️  Checking service health..."
	@docker-compose ps | grep -q "Up" || (echo "❌ Service is not running. Run 'make deploy' first." && exit 1)
	@PORT=$$(grep '^PORT=' .env 2>/dev/null | cut -d'=' -f2 || echo '80'); \
	echo "🔍 Testing health endpoint on port $$PORT..."; \
	curl -f "http://localhost:$$PORT/health" && echo " ✅ Service healthy" || echo " ❌ Service not responding"

quick-test: ## Quick test of main endpoints
	@echo "⚡ Quick test of endpoints..."
	@PORT=$$(grep '^PORT=' .env 2>/dev/null | cut -d'=' -f2 || echo '80'); \
	echo "🔹 SID64toAID: $$(curl -s http://localhost:$$PORT/SID64toAID?steamid=$(TEST_STEAMID64))"; \
	echo "🔹 Health: $$(curl -s http://localhost:$$PORT/health)"

# System information
info: ## Show full system information
	@echo "🔍 SteamID Conversion Service - System Information"
	@echo "======================================================="
	@echo ""
	@echo "📋 Installed versions:"
	@echo "  Docker: $$(docker --version 2>/dev/null || echo 'Not installed')"
	@echo "  Docker Compose: $$(docker-compose --version 2>/dev/null || echo 'Not installed')"
	@echo "  Go: $$(go version 2>/dev/null || echo 'Not installed')"
	@echo ""
	@echo "📁 Project files:"
	@ls -la go/*.go *.yml *.env* Dockerfile 2>/dev/null || true
	@echo ""
	@echo "🐳 Docker status:"
	@docker-compose ps 2>/dev/null || echo "  Docker Compose is not running"
	@echo ""
	@echo "⚙️  Current configuration (.env):"
	@if [ -f .env ]; then \
		grep -E '^(PORT|HOST|SID2_UNIVERSE)=' .env || echo "  .env file exists but no visible configuration"; \
	else \
		echo "  .env file not found"; \
	fi
	@echo ""
	@echo "📊 Docker image size:"
	@docker images $(DOCKER_IMAGE) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>/dev/null || echo "  Image not built yet"
