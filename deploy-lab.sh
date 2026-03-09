#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

if ! command -v docker >/dev/null 2>&1; then
	echo "[ERROR] Docker is not installed."
	exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
	echo "[ERROR] Docker Compose plugin is not available."
	exit 1
fi

if [[ ! -f ".env" ]]; then
	echo "[ERROR] .env not found. Copy .env.example to .env and set valid domain/email values."
	exit 1
fi

echo "[INFO] Validating docker compose configuration..."
docker compose config >/dev/null

echo "[INFO] Pulling latest images..."
docker compose pull

echo "[INFO] Starting cyber lab stack (Gophish + OpenVAS + Caddy)..."
docker compose up -d

echo "[INFO] Stack started."
echo "[INFO] Status:"
docker compose ps

echo "[INFO] Access endpoints:"
echo "  - Gophish admin  : https://${GOPHISH_ADMIN_DOMAIN}:8443"
echo "  - Gophish landing: https://${GOPHISH_LANDING_DOMAIN}:8443"
echo "  - OpenVAS GSA    : https://${OPENVAS_DOMAIN}:8443"
echo "  - WebMap         : https://${WEBMAP_DOMAIN}:8443"
echo "  - Sn1per CE      : https://${SN1PER_DOMAIN}:8443"
echo "[INFO] Note: OpenVAS feed sync and first startup can take a long time."
