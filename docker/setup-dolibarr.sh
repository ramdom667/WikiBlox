#!/bin/bash
# Configure Dolibarr pour WikiCards puis écrit la clé API dans API/.env
# Usage : ./docker/setup-dolibarr.sh   (Dolibarr doit tourner : docker compose ... up -d)
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
CONTAINER="${CONTAINER:-dolibarr_app}"
ENV_FILE="$DIR/../API/.env"

# WIKICARDS_RESET_API_KEY=1 ./docker/setup-dolibarr.sh  -> régénère la clé API (après une restauration)
# WIKICARDS_ADMIN_PASSWORD=xxx ./docker/setup-dolibarr.sh  -> (ré)applique le mot de passe admin
OUT="$(docker exec -i \
  -e WIKICARDS_RESET_API_KEY="${WIKICARDS_RESET_API_KEY:-}" \
  -e WIKICARDS_ADMIN_PASSWORD="${WIKICARDS_ADMIN_PASSWORD:-}" \
  "$CONTAINER" php < "$DIR/setup-dolibarr.php")"
echo "$OUT" | grep -v '^APIKEY='

KEY="$(echo "$OUT" | sed -n 's/^APIKEY=//p' | tr -d '\r')"
if [ -z "$KEY" ]; then
  echo "Clé API non récupérée" >&2
  exit 1
fi

[ -f "$ENV_FILE" ] || cp "$DIR/../API/.env.example" "$ENV_FILE"
sed -i.bak "s|^DOLIBARR_API_KEY=.*|DOLIBARR_API_KEY=$KEY|" "$ENV_FILE" && rm -f "$ENV_FILE.bak"
echo "[OK] Clé API écrite dans API/.env"
