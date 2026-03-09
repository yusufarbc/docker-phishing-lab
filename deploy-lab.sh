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
if ! docker compose pull; then
	echo "[WARN] Some images could not be pulled."
	echo "[WARN] Continuing with default stack. Optional services may be skipped."
fi

echo "[INFO] Starting cyber lab stack (Caddy + Gophish + Postfix + OpenVAS)..."
docker compose up -d

echo "[INFO] Stack started."
echo "[INFO] Status:"
docker compose ps

echo "[INFO] Access endpoints:"
echo "  - Gophish admin  : https://${GOPHISH_ADMIN_DOMAIN}:8443"
echo "  - Gophish landing: https://${GOPHISH_LANDING_DOMAIN}:8443"
echo "  - OpenVAS GSA    : https://${OPENVAS_DOMAIN}:8443"
echo "[INFO] Note: OpenVAS feed sync and first startup can take a long time."

echo "[INFO] Waiting a few seconds for first-run logs..."
sleep 8

echo "[INFO] Attempting to extract initial credentials from logs..."

gophish_logs="$(docker compose logs --no-color gophish 2>/dev/null || true)"
gophish_password="$(printf '%s\n' "$gophish_logs" | sed -nE 's/.*username admin and the password ([^ ]+).*/\1/p' | head -n1)"

if [[ -n "${gophish_password}" ]]; then
	echo "[CRED] Gophish initial admin"
	echo "  - Username: admin"
	echo "  - Password: ${gophish_password}"
else
	echo "[WARN] Gophish initial password could not be parsed from logs."
	echo "  - Manual check: docker compose logs --no-color gophish | grep -i 'password'"
fi

openvas_hint="$(docker compose logs --no-color gvmd 2>/dev/null | grep -Ei 'password|admin' | head -n1 || true)"
if [[ -n "${openvas_hint}" ]]; then
	echo "[INFO] OpenVAS related credential hint from gvmd logs"
	echo "  - ${openvas_hint}"
else
	echo "[INFO] OpenVAS admin password was not found in logs (this is common)."
	echo "  - Check users manually after startup:"
	echo "    docker compose exec gvmd gvmd --get-users"
fi
