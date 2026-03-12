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

echo "[INFO] Validating local compose file..."
docker compose -f docker-compose.local.yml config >/dev/null

echo "[INFO] Pulling images..."
docker compose -f docker-compose.local.yml pull

echo "[INFO] Starting local stack (Gophish + Postfix, no Caddy)..."
docker compose -f docker-compose.local.yml up -d

echo "[INFO] Configuring Gophish for local mode..."
docker compose -f docker-compose.local.yml cp gophish:/opt/gophish/config.json ./tmp_config.json

python3 -c "
import json

with open('./tmp_config.json', 'r') as f:
    data = json.load(f)

data['admin_server']['use_tls'] = False
data['admin_server']['listen_url'] = '0.0.0.0:3333'
data['admin_server']['trusted_origins'] = [
    'http://localhost:3333',
    'http://127.0.0.1:3333'
]
data['phish_server']['use_tls'] = False
data['phish_server']['listen_url'] = '0.0.0.0:80'

with open('./tmp_config.json', 'w') as f:
    json.dump(data, f, indent=4)
"

docker compose -f docker-compose.local.yml cp ./tmp_config.json gophish:/opt/gophish/config.json
rm -f ./tmp_config.json

docker compose -f docker-compose.local.yml restart gophish >/dev/null

echo "[INFO] Status:"
docker compose -f docker-compose.local.yml ps

echo "[INFO] Access endpoints:"
echo "  - Gophish admin  : http://localhost:3333"
echo "  - Gophish landing: http://localhost:8080"

echo "[INFO] Initial password (if first run):"
docker compose -f docker-compose.local.yml logs --no-color --tail 200 gophish | grep -Ei 'password|admin' || true
