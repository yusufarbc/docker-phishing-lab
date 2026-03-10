#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f ".env" ]]; then
  echo "[ERROR] .env not found."
  exit 1
fi

set -a
. ./.env
set +a

echo "Fixing Gophish referer issue..."

# Daha güçlü sed pattern'i (birden fazla satır arası ihtimaline karşı)
docker compose exec gophish sh -lc "sed -i -E 's/\"use_tls\": *true/\"use_tls\": false/' /opt/gophish/config.json"
docker compose exec gophish sh -lc "sed -i -E 's#\"trusted_origins\": *\[.*?\]#\"trusted_origins\": [\"https://${GOPHISH_ADMIN_DOMAIN}\", \"http://${GOPHISH_ADMIN_DOMAIN}\", \"https://${GOPHISH_LANDING_DOMAIN}\"]#' /opt/gophish/config.json"

# Alternatif olarak python json modülü ile parse et (sed başarısız olursa diye fallback)
docker compose exec gophish sh -lc "cat << 'EOF' > fix_config.py
import json
with open('/opt/gophish/config.json', 'r') as f:
    data = json.load(f)

data['admin_server']['use_tls'] = False
data['admin_server']['trusted_origins'] = ['https://${GOPHISH_ADMIN_DOMAIN}', 'http://${GOPHISH_ADMIN_DOMAIN}', 'https://${GOPHISH_LANDING_DOMAIN}']

with open('/opt/gophish/config.json', 'w') as f:
    json.dump(data, f, indent=4)
EOF
python3 fix_config.py 2>/dev/null || true
rm fix_config.py 2>/dev/null || true
"

docker compose restart gophish
echo "Done. Please refresh your browser."
