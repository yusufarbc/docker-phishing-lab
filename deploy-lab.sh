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
  echo "[ERROR] .env not found. Copy .env.example to .env and set valid values."
  exit 1
fi

# Export .env values for script output variables.
set -a
. ./.env
set +a

echo "[INFO] Validating docker compose configuration..."
docker compose config >/dev/null

echo "[INFO] Pulling latest images..."
docker compose pull

echo "[INFO] Starting phishing lab stack (Caddy + Gophish + Postfix)..."
docker compose up -d

echo "[INFO] Configuring Gophish for reverse proxy mode (via offline Python patch for accurate JSON parsing)..."
docker compose cp gophish:/opt/gophish/config.json ./tmp_config.json

python3 -c "
import json, os

with open('./tmp_config.json', 'r') as f:
    data = json.load(f)

data['admin_server']['use_tls'] = False
domain = '${GOPHISH_ADMIN_DOMAIN}'
landing = '${GOPHISH_LANDING_DOMAIN}'

data['admin_server']['trusted_origins'] = [
    f'https://{domain}',
    f'http://{domain}',
    f'{domain}',
    f'https://{landing}'
]

with open('./tmp_config.json', 'w') as f:
    json.dump(data, f, indent=4)
"

docker compose cp ./tmp_config.json gophish:/opt/gophish/config.json
rm -f ./tmp_config.json

docker compose restart gophish caddy >/dev/null

echo "[INFO] Status:"
docker compose ps

echo "[INFO] Access endpoints:"
echo "  - Gophish admin  : https://${GOPHISH_ADMIN_DOMAIN}"
echo "  - Gophish landing: https://${GOPHISH_LANDING_DOMAIN}"

echo "[INFO] Attempting to extract Gophish initial password from logs..."

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
