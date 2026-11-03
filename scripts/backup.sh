#!/usr/bin/env bash
# Sauvegarde des données WikiBlox (base Dolibarr + données de l'API)
#
# Usage : ./scripts/backup.sh            -> backups/wikiblox-AAAAMMJJ-HHMMSS.tar.gz
# Restauration sur une autre machine : ./install.sh --restore backups/<fichier>.tar.gz
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DB_CONTAINER="${DB_CONTAINER:-dolibarr_mariadb}"
API_CONTAINER="${API_CONTAINER:-wikicards_api}"
STAMP="$(date +%Y%m%d-%H%M%S)"
WORK="$(mktemp -d)"
OUT="backups/wikiblox-$STAMP.tar.gz"
trap 'rm -rf "$WORK"' EXIT

mkdir -p backups

echo "==> Export de la base Dolibarr..."
docker exec "$DB_CONTAINER" sh -c \
  'exec mariadb-dump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers --default-character-set=utf8mb4 dolibarr' \
  > "$WORK/dolibarr.sql"
echo "    $(wc -c < "$WORK/dolibarr.sql") octets"

echo "==> Données de l'API (anti double-ouverture)..."
mkdir -p "$WORK/api_data"
if docker ps --format '{{.Names}}' | grep -qx "$API_CONTAINER"; then
  docker cp "$API_CONTAINER:/app/data/." "$WORK/api_data/" || true
fi

cat > "$WORK/INFO.txt" <<EOF
Sauvegarde WikiBlox du $(date)
Machine : $(hostname)
Contenu : dolibarr.sql (base complète), api_data/ (idempotency.sqlite3)
Restauration : ./install.sh --restore <ce fichier>
EOF

tar -czf "$OUT" -C "$WORK" .
echo "==> Sauvegarde créée : $OUT ($(du -h "$OUT" | cut -f1))"
