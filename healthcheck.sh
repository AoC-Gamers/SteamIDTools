#!/bin/sh
# Health check script for the SteamIDTools Go backend
curl -fsSL http://localhost:${PORT:-80}/health | grep HEALTHY > /dev/null
