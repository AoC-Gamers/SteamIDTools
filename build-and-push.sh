#!/bin/bash
set -e

# --------------------------
# CONFIGURACIÓN INICIAL
# --------------------------

function check_dependencies() {
    for dep in docker awk; do
        if ! command -v "$dep" &>/dev/null; then
            echo "❌ Dependencia faltante: $dep. Instálala antes de continuar." >&2
            exit 2
        fi
    done
}

function usage() {
    echo
    echo "Uso:"
    echo "  $0 --url <GITHUB_URL> --imagename <IMAGE_NAME> [--imageversion <VERSION>] [--token <GHCR_TOKEN>] <comando>"
    echo
    echo "Comandos disponibles:"
    echo "    build         Construye la imagen Docker"
    echo "    push-ghcr     Etiqueta y sube la imagen a GHCR"
    echo "    all           Construye y sube la imagen a GHCR"
    echo "    clean         Elimina la imagen Docker local"
    echo
    echo "Parámetros obligatorios:"
    echo "    --url         URL del repositorio GitHub (ej: https://github.com/AoC-Gamers/SteamIDTools)"
    echo "    --imagename   Nombre corto de la imagen Docker (ej: steamidtools)"
    echo
    echo "Parámetros opcionales:"
    echo "    --imageversion    (por defecto: latest)"
    echo "    --token           Token de acceso a GHCR (opcional, puede usar docker login previo)"
    echo
    echo "Ejemplo:"
    echo "$0 --url https://github.com/AoC-Gamers/SteamIDTools --imagename steamidtools --imageversion latest --token YOUR_TOKEN all"
    exit 1
}

github_url=""
image_name=""
image_version="latest"
ghcr_token=""
dockerfile="Dockerfile"
docker_build_args="${DOCKER_BUILD_ARGS:-}"

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --url)
            github_url="$2"
            shift
            shift
            ;;
        --imagename)
            image_name="$2"
            shift
            shift
            ;;
        --imageversion)
            image_version="$2"
            shift
            shift
            ;;
        --token)
            ghcr_token="$2"
            shift
            shift
            ;;
        --help)
            usage
            ;;
        -*)
            echo "❌ Opción desconocida: $1"
            usage
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL[@]}"

if [[ $# -lt 1 ]]; then
    echo "❌ Falta el comando."
    usage
fi

command="$1"

# --------------------------
# VALIDACIONES
# --------------------------

if [[ -z "$github_url" || -z "$image_name" ]]; then
    echo "❌ Debes indicar --url y --imagename."
    usage
fi

check_dependencies

# Extraer namespace desde la URL GitHub
# ej: https://github.com/AoC-Gamers/SteamIDTools
namespace=$(echo "$github_url" | awk -F/ '{print tolower($4)}')
repo_name=$(echo "$github_url" | awk -F/ '{print tolower($5)}')

# Construir nombre GHCR completo
ghcr_image="ghcr.io/$namespace/$image_name:$image_version"

echo "🔎 GHCR Image: $ghcr_image"

# --------------------------
# FUNCIONES
# --------------------------

function login_ghcr() {
    if [[ -n "$ghcr_token" ]]; then
        echo "$ghcr_token" | docker login ghcr.io -u "$namespace" --password-stdin
    else
        echo "ℹ️  No se especificó token GHCR. Usando sesión actual de docker login."
    fi
}

function spinner() {
    local pid=$1
    local msg="$2"
    local spin='|/-\\'
    local i=0
    if command -v tput >/dev/null 2>&1; then
        tput civis
    fi
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r%s %s" "${spin:$i:1}" "$msg"
        sleep 0.1
    done
    printf "\r"
    if command -v tput >/dev/null 2>&1; then
        tput cnorm
    fi
}

function build_image() {
    echo "🐳 Construyendo imagen Docker..."
    docker build $docker_build_args -t "$image_name:latest" -f "$dockerfile" .
    echo "✅ Imagen Docker construida: $image_name:latest"
}

function tag_and_push_ghcr() {
    echo "🔄 Etiquetando imagen para GHCR..."
    docker tag "$image_name:latest" "$ghcr_image"

    echo "⬆️  Subiendo imagen a GHCR: $ghcr_image"
    (docker push "$ghcr_image") &
    pid=$!
    spinner $pid "Subiendo imagen a GHCR..."
    wait $pid
    if [[ $? -eq 0 ]]; then
        echo "✅ Imagen subida a GHCR correctamente."
    else
        echo "❌ Error al subir la imagen a GHCR."
        exit 5
    fi
}

function clean() {
    echo "🧹 Eliminando imagen local: $image_name:latest"
    docker rmi "$image_name:latest" || true
    docker rmi "$ghcr_image" || true
}

# --------------------------
# EJECUCIÓN
# --------------------------

case "$command" in
    build)
        build_image
        ;;
    push-ghcr)
        login_ghcr
        tag_and_push_ghcr
        ;;
    all)
        build_image
        login_ghcr
        tag_and_push_ghcr
        ;;
    clean)
        clean
        ;;
    *)
        usage
        ;;
esac
