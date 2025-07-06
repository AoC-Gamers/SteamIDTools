# Makefile para SteamID Conversion Service (Go)
.PHONY: help build test deploy stop logs clean all status restart dev-run dev-test info health

# Variables
DOCKER_IMAGE = steamid-service:latest
DOCKER_CONTAINER = steamid-service
TEST_PORT = 8081
TEST_STEAMID64 = 76561197960287930
TEST_ACCOUNTID = 22202
TEST_STEAMID2 = STEAM_1:0:11101

# Comando por defecto
help: ## Mostrar esta ayuda
	@echo "SteamID Conversion Service (Go) - Comandos disponibles:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Construir imagen Docker
	@echo "🔨 Construyendo imagen Docker (Go)..."
	docker build -t $(DOCKER_IMAGE) .
	@echo "✅ Imagen construida exitosamente"
	@echo "📊 Tamaño de imagen:"
	@docker images $(DOCKER_IMAGE) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

test: ## Ejecutar pruebas completas del contenedor
	@echo "🧪 Ejecutando pruebas completas..."
	@echo "Iniciando contenedor temporal para pruebas..."
	$(eval CONTAINER_ID := $(shell docker run -d -p $(TEST_PORT):80 $(DOCKER_IMAGE)))
	@sleep 5
	@echo "Ejecutando pruebas de endpoints..."
	@echo "  🔹 Probando SID64toAID..."
	@curl -f "http://localhost:$(TEST_PORT)/SID64toAID?steamid=$(TEST_STEAMID64)" > /dev/null || (docker logs $(CONTAINER_ID) && docker stop $(CONTAINER_ID) && docker rm $(CONTAINER_ID) && exit 1)
	@echo "  🔹 Probando AIDtoSID64..."
	@curl -f "http://localhost:$(TEST_PORT)/AIDtoSID64?steamid=$(TEST_ACCOUNTID)" > /dev/null || (docker logs $(CONTAINER_ID) && docker stop $(CONTAINER_ID) && docker rm $(CONTAINER_ID) && exit 1)
	@echo "  🔹 Probando SID2toSID64..."
	@curl -f "http://localhost:$(TEST_PORT)/SID2toSID64?steamid=$(TEST_STEAMID2)" > /dev/null || (docker logs $(CONTAINER_ID) && docker stop $(CONTAINER_ID) && docker rm $(CONTAINER_ID) && exit 1)
	@echo "  🔹 Probando health check..."
	@curl -f "http://localhost:$(TEST_PORT)/health" > /dev/null || (docker logs $(CONTAINER_ID) && docker stop $(CONTAINER_ID) && docker rm $(CONTAINER_ID) && exit 1)
	@echo "  🔹 Probando batch processing..."
	@curl -f "http://localhost:$(TEST_PORT)/SID64toAID?steamid=$(TEST_STEAMID64),76561197960287931" > /dev/null || (docker logs $(CONTAINER_ID) && docker stop $(CONTAINER_ID) && docker rm $(CONTAINER_ID) && exit 1)
	@docker stop $(CONTAINER_ID) > /dev/null
	@docker rm $(CONTAINER_ID) > /dev/null
	@echo "✅ Todas las pruebas pasaron exitosamente"

deploy: ## Desplegar servicio con docker-compose
	@echo "🚀 Desplegando servicio SteamID (Go)..."
	@if [ ! -f .env ]; then \
		echo "⚠️  Archivo .env no encontrado, creando desde .env.example"; \
		cp .env.example .env; \
	fi
	@echo "📋 Configuración actual:"
	@grep -E '^(PORT|HOST|SID2_UNIVERSE)=' .env 2>/dev/null || echo "Usando valores por defecto"
	docker-compose up -d --build
	@echo "✅ Servicio desplegado exitosamente"
	@echo ""
	@echo "📊 Estado del servicio:"
	@docker-compose ps
	@echo ""
	@echo "🌐 Endpoints disponibles:"
	@echo "  http://localhost:$$(grep '^PORT=' .env 2>/dev/null | cut -d'=' -f2 || echo '80')/SID64toAID?steamid=$(TEST_STEAMID64)"
	@echo "  http://localhost:$$(grep '^PORT=' .env 2>/dev/null | cut -d'=' -f2 || echo '80')/health"

stop: ## Detener servicio
	@echo "🛑 Deteniendo servicio..."
	docker-compose down
	@echo "✅ Servicio detenido"

logs: ## Mostrar logs del servicio
	docker-compose logs -f

status: ## Mostrar estado del servicio
	@echo "📊 Estado del servicio:"
	@docker-compose ps
	@echo ""
	@echo "📋 Últimos logs:"
	@docker-compose logs --tail=10

clean: ## Limpiar imágenes, contenedores y archivos temporales
	@echo "🧹 Limpiando recursos..."
	@echo "  🛑 Deteniendo servicios..."
	@docker-compose down 2>/dev/null || true
	@echo "  🗑️  Removiendo imagen..."
	@docker rmi $(DOCKER_IMAGE) 2>/dev/null || true
	@echo "  � Limpiando contenedores no utilizados..."
	@docker container prune -f 2>/dev/null || true
	@echo "✅ Limpieza completada"

clean-all: ## Limpieza completa (incluyendo volúmenes y redes)
	@echo "🧹 Limpieza completa del sistema..."
	@docker-compose down -v --remove-orphans 2>/dev/null || true
	@docker rmi $(DOCKER_IMAGE) 2>/dev/null || true
	@docker system prune -f 2>/dev/null || true
	@echo "✅ Limpieza completa terminada"

restart: stop deploy ## Reiniciar servicio

all: build test deploy ## Construir, probar y desplegar

# Comandos de desarrollo
dev-run: ## Ejecutar servicio en modo desarrollo (sin Docker)
	@echo "🔧 Ejecutando en modo desarrollo (Go)..."
	@cd go && go run main.go

dev-test: ## Ejecutar pruebas completas en modo desarrollo
	@echo "🧪 Ejecutando pruebas en modo desarrollo..."
	@echo "Asegúrate de que el servicio esté ejecutándose en otro terminal (make dev-run)"
	@echo ""
	@echo "🔹 Probando conversiones individuales:"
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
	@echo "🔹 Probando procesamiento por lotes:"
	@curl -s "http://localhost:80/SID64toAID?steamid=$(TEST_STEAMID64),76561197960287931"
	@echo ""

health: ## Verificar salud del servicio desplegado
	@echo "❤️  Verificando salud del servicio..."
	@docker-compose ps | grep -q "Up" || (echo "❌ Servicio no está ejecutándose. Ejecuta 'make deploy' primero." && exit 1)
	@PORT=$$(grep '^PORT=' .env 2>/dev/null | cut -d'=' -f2 || echo '80'); \
	echo "🔍 Probando endpoint de salud en puerto $$PORT..."; \
	curl -f "http://localhost:$$PORT/health" && echo " ✅ Servicio saludable" || echo " ❌ Servicio no responde"

quick-test: ## Prueba rápida de endpoints principales
	@echo "⚡ Prueba rápida de endpoints..."
	@PORT=$$(grep '^PORT=' .env 2>/dev/null | cut -d'=' -f2 || echo '80'); \
	echo "🔹 SID64toAID: $$(curl -s http://localhost:$$PORT/SID64toAID?steamid=$(TEST_STEAMID64))"; \
	echo "🔹 Health: $$(curl -s http://localhost:$$PORT/health)"

# Información del sistema
info: ## Mostrar información completa del sistema
	@echo "🔍 SteamID Conversion Service - Información del Sistema"
	@echo "======================================================="
	@echo ""
	@echo "📋 Versiones instaladas:"
	@echo "  Docker: $$(docker --version 2>/dev/null || echo 'No instalado')"
	@echo "  Docker Compose: $$(docker-compose --version 2>/dev/null || echo 'No instalado')"
	@echo "  Go: $$(go version 2>/dev/null || echo 'No instalado')"
	@echo ""
	@echo "📁 Archivos del proyecto:"
	@ls -la go/*.go *.yml *.env* Dockerfile 2>/dev/null || true
	@echo ""
	@echo "🐳 Estado de Docker:"
	@docker-compose ps 2>/dev/null || echo "  Docker Compose no está ejecutándose"
	@echo ""
	@echo "⚙️  Configuración actual (.env):"
	@if [ -f .env ]; then \
		grep -E '^(PORT|HOST|SID2_UNIVERSE)=' .env || echo "  Archivo .env existe pero sin configuración visible"; \
	else \
		echo "  Archivo .env no encontrado"; \
	fi
	@echo ""
	@echo "📊 Tamaño de imagen Docker:"
	@docker images $(DOCKER_IMAGE) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>/dev/null || echo "  Imagen no construida aún"
