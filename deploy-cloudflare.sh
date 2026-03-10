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
  echo "[WARN] Expected certificate file but found directory: ${CLOUDFLARE_ORIGIN_CERT_PATH}"
  echo "       Auto-removing empty directory to fix Docker mount issue."
  rm -rf "${CLOUDFLARE_ORIGIN_CERT_PATH}"
fi

if [[ -d "${CLOUDFLARE_ORIGIN_KEY_PATH}" ]]; then
  echo "[WARN] Expected private key file but found directory: ${CLOUDFLARE_ORIGIN_KEY_PATH}"
  echo "       Auto-removing empty directory to fix Docker mount issue."
  rm -rf "${CLOUDFLARE_ORIGIN_KEY_PATH}"
fi

missing_files=0

# Check if file doesn't exist OR if it's completely empty (0 bytes) OR contains the placeholder text.
if [[ ! -s "${CLOUDFLARE_ORIGIN_CERT_PATH}" ]] || grep -q 'PASTE_CLOUDFLARE_' "${CLOUDFLARE_ORIGIN_CERT_PATH}"; then
  cat > "${CLOUDFLARE_ORIGIN_CERT_PATH}" <<'EOF'
-----BEGIN CERTIFICATE-----
PASTE_CLOUDFLARE_ORIGIN_CERTIFICATE_HERE
-----END CERTIFICATE-----
EOF
  echo "[WARN] Origin certificate was missing or empty. Placeholder created: ${CLOUDFLARE_ORIGIN_CERT_PATH}"
  missing_files=1
fi

if [[ ! -s "${CLOUDFLARE_ORIGIN_KEY_PATH}" ]] || grep -q 'PASTE_CLOUDFLARE_' "${CLOUDFLARE_ORIGIN_KEY_PATH}"; then
  cat > "${CLOUDFLARE_ORIGIN_KEY_PATH}" <<'EOF'
-----BEGIN PRIVATE KEY-----
PASTE_CLOUDFLARE_ORIGIN_PRIVATE_KEY_HERE
-----END PRIVATE KEY-----
EOF
  chmod 600 "${CLOUDFLARE_ORIGIN_KEY_PATH}" || true
  echo "[WARN] Origin private key was missing or empty. Placeholder created: ${CLOUDFLARE_ORIGIN_KEY_PATH}"
  missing_files=1
fi

if [[ "${missing_files}" -eq 1 ]]; then
  echo "[ERROR] Cloudflare Origin cert/key are missing, empty, or contain placeholders."
  echo "        Replace the placeholder content in the files below with real PEM values, then run script again:"
  echo "        - ${CLOUDFLARE_ORIGIN_CERT_PATH}"
  echo "        - ${CLOUDFLARE_ORIGIN_KEY_PATH}"
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
    f'http://{landing}',
    f'https://{admin}:443',
    f'http://{admin}:443',
    f'{admin}',
    f'{admin}:443'
]

data['admin_server']['use_tls'] = True
data['admin_server']['listen_url'] = '0.0.0.0:8443'
data['admin_server']['cert_path'] = '/opt/gophish/cloudflare-origin.crt'
data['admin_server']['key_path'] = '/opt/gophish/cloudflare-origin.key'
data['admin_server']['trusted_origins'] = trusted_origins

data['phish_server']['use_tls'] = True
data['phish_server']['listen_url'] = '0.0.0.0:443'
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
echo "  - Admin   : https://${GOPHISH_ADMIN_DOMAIN}:8443"
echo "  - Landing : https://${GOPHISH_LANDING_DOMAIN}"

echo "[INFO] Initial password (if first run):"
docker compose -f docker-compose.cloudflare.yml logs --no-color --tail 200 gophish | grep -Ei 'password|admin' || true
