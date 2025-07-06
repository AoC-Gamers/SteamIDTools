#!/bin/sh
# Health check script for SteamIDTools container
curl -fsSL http://localhost:${PORT:-80}/health | grep HEALTHY > /dev/null
