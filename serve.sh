#!/bin/bash
# Wrapper to start the SteamIDTools Go backend on (Linux/macOS)

set -e

PORT=80
HOST="0.0.0.0"
SHOW_HELP=0
DEBUG=0
BIN_NAME="steamid-service"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

show_help() {
    echo -e "${CYAN}\n🚀 SteamID Tools - Go Server\n===============================================${NC}"
    echo -e "\nDESCRIPTION:"
    echo -e "  Starts the SteamID conversion service in Go with real-time console"
    echo -e "\nUSAGE:"
    echo -e "  ./serve.sh [-p <port>] [-h <host>] [--help] [--debug]"
    echo -e "\nPARAMETERS:"
    echo -e "  -p, --port        Server port (default: 80)"
    echo -e "  -h, --host        Host IP address (default: 0.0.0.0)"
    echo -e "  --help            Show this help"
    echo -e "  --debug           Enable debug mode (extra logs)"
    echo -e "\nEXAMPLES:"
    echo -e "  ./serve.sh                # Port 80, all interfaces"
    echo -e "  ./serve.sh -p 8080        # Port 8080"
    echo -e "  ./serve.sh -p 3000 -h localhost  # Port 3000, only localhost"
    echo -e "  ./serve.sh --debug        # Enable debug mode"
    echo -e "  DEBUG=1 ./serve.sh        # (Alternativa manual)"
    echo -e "\nCONTROLS:"
    echo -e "  Ctrl+C   Stop the server"
    echo
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -h|--host)
            HOST="$2"
            shift 2
            ;;
        --help)
            SHOW_HELP=1
            shift
            ;;
        --debug)
            DEBUG=1
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

if [[ $SHOW_HELP -eq 1 ]]; then
    show_help
    exit 0
fi

if ! command -v go &> /dev/null; then
    echo -e "${RED}❌ ERROR: Go is not installed or not in PATH${NC}"
    echo -e "   Download Go from: https://golang.org/dl/"
    exit 1
fi

if [[ ! -f go/main.go ]]; then
    echo -e "${RED}❌ ERROR: go/main.go not found${NC}"
    echo -e "   Make sure to run this script from the SteamIDTools project root"
    exit 1
fi

if ss -tuln 2>/dev/null | grep -q ":$PORT "; then
    echo -e "${YELLOW}⚠️  WARNING: Port $PORT is already in use${NC}"
    echo -e "   Use 'sudo lsof -i :$PORT' to see the process."
    read -p "Do you want to continue anyway? (y/N): " response
    if [[ "$response" != "y" && "$response" != "Y" ]]; then
        echo -e "${RED}❌ Operation cancelled by user${NC}"
        exit 1
    fi
fi

DISPLAY_HOST="$HOST"
if [[ "$HOST" == "0.0.0.0" ]]; then
    DISPLAY_HOST="localhost"
fi

echo -e "${CYAN}\n🌐 SERVER STARTUP\n===============================================${NC}"
echo -e "${GREEN}📡 Address: http://$DISPLAY_HOST:$PORT${NC}"
echo -e "🔌 Host: $HOST"
echo -e "🚪 Port: $PORT"
echo -e "\n${YELLOW}For available endpoints and features, see the server output below.${NC}"
echo

export PORT="$PORT"
export HOST="$HOST"
if [[ $DEBUG -eq 1 ]]; then
    export DEBUG=1
fi

trap 'echo -e "\n${YELLOW}🛑 Stopping server...${NC}"; exit 0' SIGINT

if [[ $DEBUG -eq 1 ]]; then
    if [[ -f go/$BIN_NAME ]]; then
        echo -e "${YELLOW}🧹 Eliminando binario previo para recompilación limpia (debug)...${NC}"
        rm -f go/$BIN_NAME
    fi
fi

if [[ ! -f go/$BIN_NAME ]]; then
    echo -e "${YELLOW}⚙️  Compilando binario Go...${NC}"
    (cd go && go build -o $BIN_NAME .)
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Error de compilación. Revisa los logs anteriores.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Binario compilado: go/$BIN_NAME${NC}"
fi

cd go
if [[ $DEBUG -eq 1 ]]; then
    echo -e "${CYAN}🔍 Debug mode enabled (DEBUG=1)${NC}"
    DEBUG=1 ./$BIN_NAME
else
    ./$BIN_NAME
fi
