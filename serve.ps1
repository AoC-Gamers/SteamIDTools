# SteamID Tools - Go Server (PowerShell version)
# Wrapper to start the SteamIDTools Go backend on Windows
# Usage is identical to start-server.ps1, only the filename is different for multiplatform clarity

param(
    [int]$Port = 80,
    [string]$HostAddress = "0.0.0.0",
    [switch]$Help,
    [switch]$Debug
)

function Show-Help {
    Write-Host "`nSTEAMID TOOLS - GO SERVER" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "\nDESCRIPTION:"
    Write-Host "  Starts the SteamID conversion service in Go with real-time console output"
    Write-Host "\nUSAGE:"
    Write-Host "  .\serve.ps1 [-Port <port>] [-Host <host>] [-Help] [-Debug]"
    Write-Host "\nPARAMETERS:"
    Write-Host "  -Port <port>   Server port (default: 80)"
    Write-Host "  -Host <host>   Host IP address (default: 0.0.0.0)"
    Write-Host "  -Help          Show this help"
    Write-Host "  -Debug         Enable debug mode (extra logs)" -ForegroundColor Cyan
    Write-Host "\nEXAMPLES:"
    Write-Host "  .\serve.ps1                # Port 80, all interfaces" -ForegroundColor Gray
    Write-Host "  .\serve.ps1 -Port 8080     # Port 8080" -ForegroundColor Gray
    Write-Host "  .\serve.ps1 -Port 3000 -Host localhost  # Port 3000, only localhost" -ForegroundColor Gray
    Write-Host "  .\serve.ps1 -Debug         # Enable debug mode" -ForegroundColor Gray
    Write-Host "  $env:DEBUG=1; .\serve.ps1 # (Manual alternative)" -ForegroundColor Gray
    Write-Host "\nCONTROLS:"
    Write-Host "  Ctrl+C   Stop the server" -ForegroundColor Gray
    Write-Host
}

if ($Help) {
    Show-Help
    exit 0
}

# Check dependencies
try {
    $goVersion = & go version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Go found: $($goVersion)" -ForegroundColor Green
    } else {
        throw "Go not found"
    }
} catch {
    Write-Host "❌ ERROR: Go is not installed or not in PATH" -ForegroundColor Red
    Write-Host "   Download Go from: https://golang.org/dl/" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path "go\main.go")) {
    Write-Host "❌ ERROR: go\main.go not found" -ForegroundColor Red
    Write-Host "   Make sure to run this script from the SteamIDTools project root" -ForegroundColor Yellow
    exit 1
}

# Set environment variables
$env:PORT = $Port.ToString()
$env:HOST = $HostAddress
if ($Debug) {
    $env:DEBUG = "1"
    Write-Host "🔍 Debug mode enabled (DEBUG=1)" -ForegroundColor Cyan
}

Push-Location "go"

# Define binary name by platform
$binName = if ($IsWindows) { "steamid-service.exe" } else { "steamid-service" }

# Remove previous binary if -Debug for clean rebuild
if ($Debug -and (Test-Path $binName)) {
    Write-Host "🧹 Removing previous binary for clean rebuild (debug)..." -ForegroundColor Yellow
    Remove-Item $binName -Force
}

try {
    # Build if binary does not exist or code changed
    if (-not (Test-Path $binName)) {
        Write-Host "⚙️  Building Go binary..." -ForegroundColor Yellow
        & go build -o $binName .
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Build error. Check the logs above." -ForegroundColor Red
            throw "Build failed"
        }
        Write-Host "✅ Binary built: $binName" -ForegroundColor Green
    }

    # Run the binary
    if ($Debug) {
        Write-Host "🔍 Debug mode enabled (DEBUG=1)" -ForegroundColor Cyan
        $env:DEBUG = "1"
    }
    & .\$binName
} finally {
    Pop-Location
}
