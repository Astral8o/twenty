#!/bin/bash
# Pulls the image for the TAG in .env and restarts. Takes a backup first,
# because the server runs database upgrades on startup.
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/backup.sh
docker compose pull server worker
docker compose up -d --build
docker image prune -f

echo "Updated. Follow startup with: docker compose logs -f server"
