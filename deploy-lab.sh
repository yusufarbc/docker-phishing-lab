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

# Export .env values for script output variables.
set -a
. ./.env
set +a

echo "[INFO] Validating docker compose configuration..."
docker compose config >/dev/null

echo "[INFO] Pulling latest images..."
if ! docker compose pull; then
	echo "[WARN] Some images could not be pulled."
	echo "[WARN] Continuing with default stack."
fi

echo "[INFO] Starting phishing lab stack (Caddy + Gophish + Postfix)..."
docker compose up -d

echo "[INFO] Configuring Gophish for reverse proxy mode..."
docker compose exec gophish sh -lc "sed -i -E 's/\"use_tls\": *true/\"use_tls\": false/' /opt/gophish/config.json"
docker compose exec gophish sh -lc "sed -i -E 's#\"trusted_origins\": *\[[^]]*\]#\"trusted_origins\": [\"https://${GOPHISH_ADMIN_DOMAIN}:8443\",\"https://${GOPHISH_ADMIN_DOMAIN}\"]#' /opt/gophish/config.json || true"
docker compose restart gophish caddy >/dev/null

echo "[INFO] Stack started."
echo "[INFO] Status:"
docker compose ps

echo "[INFO] Access endpoints:"
echo "  - Gophish admin  : https://${GOPHISH_ADMIN_DOMAIN}:8443"
echo "  - Gophish landing: https://${GOPHISH_LANDING_DOMAIN}:8443"

echo "[INFO] Waiting a few seconds for first-run logs..."
sleep 8

echo "[INFO] Attempting to extract initial credentials from logs..."

gophish_password=""
for i in $(seq 1 12); do
	gophish_logs="$(docker compose logs --no-color gophish 2>/dev/null || true)"
	gophish_password="$(printf '%s\n' "$gophish_logs" | sed -nE \
		-e 's/.*username admin and the password ([^\" ]+).*/\1/p' \
		-e 's/.*password for.*admin[^:]*:[[:space:]]*([^\" ]+).*/\1/p' \
		-e 's/.*admin password[[:space:]]*:[[:space:]]*([^\" ]+).*/\1/p' | head -n1)"

	if [[ -n "${gophish_password}" ]]; then
		break
	fi

	sleep 5
done

if [[ -n "${gophish_password}" ]]; then
	echo "[CRED] Gophish initial admin"
	echo "  - Username: admin"
	echo "  - Password: ${gophish_password}"
else
	echo "[WARN] Gophish initial password could not be parsed from logs."
	echo "  - If this is not first install, password line will not be printed again."
	echo "  - Manual check: docker compose logs --no-color gophish | grep -Ei 'password|admin'"
fi

