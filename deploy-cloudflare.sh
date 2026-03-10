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

# Ensure default Cloudflare cert paths exist in .env for a smoother first run.
if ! grep -q '^CLOUDFLARE_ORIGIN_CERT_PATH=' .env; then
  echo 'CLOUDFLARE_ORIGIN_CERT_PATH=./certs/cloudflare-origin.crt' >> .env
fi

if ! grep -q '^CLOUDFLARE_ORIGIN_KEY_PATH=' .env; then
  echo 'CLOUDFLARE_ORIGIN_KEY_PATH=./certs/cloudflare-origin.key' >> .env
fi

set -a
. ./.env
set +a

CLOUDFLARE_ORIGIN_CERT_PATH="${CLOUDFLARE_ORIGIN_CERT_PATH:-./certs/cloudflare-origin.crt}"
CLOUDFLARE_ORIGIN_KEY_PATH="${CLOUDFLARE_ORIGIN_KEY_PATH:-./certs/cloudflare-origin.key}"

mkdir -p "$(dirname "${CLOUDFLARE_ORIGIN_CERT_PATH}")"
mkdir -p "$(dirname "${CLOUDFLARE_ORIGIN_KEY_PATH}")"

if [[ -d "${CLOUDFLARE_ORIGIN_CERT_PATH}" ]]; then
  echo "[ERROR] Expected certificate file but found directory: ${CLOUDFLARE_ORIGIN_CERT_PATH}"
  echo "        Remove directory and create PEM file at this path."
  exit 1
fi

if [[ -d "${CLOUDFLARE_ORIGIN_KEY_PATH}" ]]; then
  echo "[ERROR] Expected private key file but found directory: ${CLOUDFLARE_ORIGIN_KEY_PATH}"
  echo "        Remove directory and create PEM file at this path."
  exit 1
fi

if [[ ! -f "${CLOUDFLARE_ORIGIN_CERT_PATH}" ]]; then
  echo "[ERROR] Origin certificate file not found: ${CLOUDFLARE_ORIGIN_CERT_PATH}"
  echo "        Create file and paste Cloudflare Origin Certificate PEM content."
  exit 1
fi

if [[ ! -f "${CLOUDFLARE_ORIGIN_KEY_PATH}" ]]; then
  echo "[ERROR] Origin private key file not found: ${CLOUDFLARE_ORIGIN_KEY_PATH}"
  echo "        Create file and paste Cloudflare Origin Private Key PEM content."
  exit 1
fi

echo "[INFO] Validating Cloudflare compose file..."
docker compose -f docker-compose.cloudflare.yml config >/dev/null

echo "[INFO] Pulling images..."
docker compose -f docker-compose.cloudflare.yml pull

echo "[INFO] Starting stack (Gophish + Postfix, no Caddy)..."
docker compose -f docker-compose.cloudflare.yml up -d

echo "[INFO] Configuring Gophish for Cloudflare Full mode..."
docker compose -f docker-compose.cloudflare.yml cp gophish:/opt/gophish/config.json ./tmp_config.json

python3 -c "
import json

with open('./tmp_config.json', 'r') as f:
    data = json.load(f)

admin = '${GOPHISH_ADMIN_DOMAIN}'
landing = '${GOPHISH_LANDING_DOMAIN}'

trusted_origins = [
    f'https://{admin}',
    f'http://{admin}',
    f'https://{landing}',
    f'http://{landing}'
]

data['admin_server']['use_tls'] = True
data['admin_server']['listen_url'] = '0.0.0.0:443'
data['admin_server']['cert_path'] = '/opt/gophish/cloudflare-origin.crt'
data['admin_server']['key_path'] = '/opt/gophish/cloudflare-origin.key'
data['admin_server']['trusted_origins'] = trusted_origins

data['phish_server']['use_tls'] = True
data['phish_server']['listen_url'] = '0.0.0.0:80'
data['phish_server']['cert_path'] = '/opt/gophish/cloudflare-origin.crt'
data['phish_server']['key_path'] = '/opt/gophish/cloudflare-origin.key'

with open('./tmp_config.json', 'w') as f:
    json.dump(data, f, indent=4)
"

docker compose -f docker-compose.cloudflare.yml cp ./tmp_config.json gophish:/opt/gophish/config.json
rm -f ./tmp_config.json

docker compose -f docker-compose.cloudflare.yml restart gophish >/dev/null

echo "[INFO] Status:"
docker compose -f docker-compose.cloudflare.yml ps

echo "[INFO] Access endpoints:"
echo "  - Admin   : https://${GOPHISH_ADMIN_DOMAIN}"
echo "  - Landing : https://${GOPHISH_LANDING_DOMAIN}"

echo "[INFO] Initial password (if first run):"
docker compose -f docker-compose.cloudflare.yml logs --no-color --tail 200 gophish | grep -Ei 'password|admin' || true
