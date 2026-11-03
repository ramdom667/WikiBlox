#!/usr/bin/env bash
# =====================================================================
#  WikiBlox - installation / mise à jour en une commande (Linux)
#
#   ./install.sh                                  installation (ou mise à jour)
#   ./install.sh --tunnel-token <TOKEN>           + mise en ligne via Cloudflare Tunnel
#   ./install.sh --restore backups/xxx.tar.gz     + restaure les données d'une sauvegarde
#   ./install.sh --load 20                        + charge 20 cartes de chaque rareté
#
#  Relançable sans risque : rien n'est écrasé (clés, mots de passe, données).
# =====================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

COMPOSE=(docker compose -f docker/docker-compose.yml)
API_ENV="API/.env"
DOCKER_ENV="docker/.env"
TUNNEL_TOKEN_ARG=""
RESTORE_FILE=""
LOAD_COUNT=""

c_info()  { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
c_ok()    { printf '\033[1;32m  ✔ %s\033[0m\n' "$*"; }
c_warn()  { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
c_fail()  { printf '\033[1;31m  ✘ %s\033[0m\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --tunnel-token) TUNNEL_TOKEN_ARG="${2:-}"; shift 2 ;;
    --restore)      RESTORE_FILE="${2:-}"; shift 2 ;;
    --load)         LOAD_COUNT="${2:-}"; shift 2 ;;
    -h|--help)      sed -n '2,12p' "$0"; exit 0 ;;
    *)              c_fail "Option inconnue : $1 (voir --help)" ;;
  esac
done

random_secret() { head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c "${1:-40}"; }

# Lit / écrit une variable KEY=valeur dans un fichier .env
env_get() { grep -E "^$2=" "$1" 2>/dev/null | head -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' || true; }
env_set() {
  local file="$1" key="$2" value="$3"
  if grep -qE "^$key=" "$file"; then
    local tmp; tmp="$(mktemp)"
    awk -v k="$key" -v v="$value" 'BEGIN{FS=OFS="="} $1==k {print k "=" v; next} {print}' "$file" > "$tmp" && cat "$tmp" > "$file" && rm -f "$tmp"
  else
    printf '%s=%s\n' "$key" "$value" >> "$file"
  fi
}

wait_http() {  # wait_http <url> <timeout_s> <label>
  local url="$1" timeout="$2" label="$3" i=0
  printf '  … attente %s' "$label"
  until curl -fsS -o /dev/null "$url" 2>/dev/null; do
    i=$((i + 3)); [ "$i" -ge "$timeout" ] && { echo; return 1; }
    printf '.'; sleep 3
  done
  echo; c_ok "$label prêt"
}

# ---------------------------------------------------------------------
c_info "1/7 Vérifications"
command -v docker >/dev/null || c_fail "Docker n'est pas installé : https://docs.docker.com/engine/install/ (ou : curl -fsSL https://get.docker.com | sh)"
docker compose version >/dev/null 2>&1 || c_fail "Le plugin 'docker compose' (v2) est requis"
docker info >/dev/null 2>&1 || c_fail "Docker ne répond pas. Démarrez-le (sudo systemctl enable --now docker) et ajoutez-vous au groupe docker (sudo usermod -aG docker \$USER puis reconnectez-vous), ou lancez ce script avec sudo"
command -v curl >/dev/null || c_fail "curl est requis (sudo apt install curl)"
if [ -n "$RESTORE_FILE" ] && [ ! -f "$RESTORE_FILE" ]; then c_fail "Sauvegarde introuvable : $RESTORE_FILE"; fi
if command -v systemctl >/dev/null && ! systemctl is-enabled docker >/dev/null 2>&1; then
  c_warn "Docker ne démarre pas automatiquement au boot : sudo systemctl enable docker"
fi
c_ok "Docker $(docker version --format '{{.Server.Version}}' 2>/dev/null)"

# ---------------------------------------------------------------------
c_info "2/7 Configuration (.env)"
DB_VOLUME_EXISTS=false
docker volume inspect wikiblox_mariadb_data >/dev/null 2>&1 && DB_VOLUME_EXISTS=true

if [ ! -f "$DOCKER_ENV" ]; then
  cp docker/.env.example "$DOCKER_ENV"
  if [ "$DB_VOLUME_EXISTS" = false ]; then
    # Nouvelle installation : mots de passe forts (MariaDB ne les lit qu'à la création du volume)
    env_set "$DOCKER_ENV" DB_ROOT_PASSWORD "$(random_secret 32)"
    env_set "$DOCKER_ENV" DB_PASSWORD "$(random_secret 32)"
    env_set "$DOCKER_ENV" DOLI_ADMIN_PASSWORD "$(random_secret 16)"
    c_ok "docker/.env créé avec des mots de passe générés"
  else
    c_warn "docker/.env créé avec les mots de passe par défaut (base existante conservée)"
  fi
else
  c_ok "docker/.env existant conservé"
fi

if [ -n "$TUNNEL_TOKEN_ARG" ]; then
  env_set "$DOCKER_ENV" CLOUDFLARE_TUNNEL_TOKEN "$TUNNEL_TOKEN_ARG"
fi
TUNNEL_TOKEN="$(env_get "$DOCKER_ENV" CLOUDFLARE_TUNNEL_TOKEN)"
if [ -z "$TUNNEL_TOKEN" ] && [ -t 0 ]; then
  read -rp "  Token Cloudflare Tunnel (Entrée pour ignorer, l'API restera locale) : " TUNNEL_TOKEN
  [ -n "$TUNNEL_TOKEN" ] && env_set "$DOCKER_ENV" CLOUDFLARE_TUNNEL_TOKEN "$TUNNEL_TOKEN"
fi
chmod 600 "$DOCKER_ENV"

if [ ! -f "$API_ENV" ]; then
  cp API/.env.example "$API_ENV"
  env_set "$API_ENV" WIKIPEDIA_USER_AGENT '"WikiCards-IAMSI (https://github.com/ramdom667/WikiBlox)"'
  c_ok "API/.env créé"
else
  c_ok "API/.env existant conservé"
fi
for key in ADMIN_API_KEY GAME_API_KEY; do
  current="$(env_get "$API_ENV" "$key")"
  if [ -z "$current" ] || [[ "$current" == change_me* ]]; then
    env_set "$API_ENV" "$key" "$(random_secret 43)"
    c_ok "$key générée"
  fi
done
env_set "$API_ENV" RELOAD false
chmod 600 "$API_ENV"

# ---------------------------------------------------------------------
c_info "3/7 Démarrage de MariaDB + Dolibarr"
"${COMPOSE[@]}" up -d mariadb dolibarr
wait_http "http://127.0.0.1:8080/" 600 "Dolibarr (installation auto, 1-3 min au premier lancement)" \
  || c_fail "Dolibarr ne répond pas : docker logs dolibarr_app"

# ---------------------------------------------------------------------
RESET_KEY=""
if [ -n "$RESTORE_FILE" ]; then
  c_info "4/7 Restauration de $RESTORE_FILE"
  WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
  tar -xzf "$RESTORE_FILE" -C "$WORK"
  [ -f "$WORK/dolibarr.sql" ] || c_fail "dolibarr.sql absent de la sauvegarde"
  docker exec -i dolibarr_mariadb sh -c \
    'exec mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 dolibarr' < "$WORK/dolibarr.sql"
  c_ok "Base Dolibarr restaurée"
  docker restart dolibarr_app >/dev/null
  wait_http "http://127.0.0.1:8080/" 300 "Dolibarr (redémarrage)" || c_fail "Dolibarr ne répond pas après restauration"
  RESET_KEY=1  # la clé API est chiffrée avec l'identifiant de l'ancienne installation
else
  c_info "4/7 Restauration : ignorée (pas de --restore)"
fi

# ---------------------------------------------------------------------
c_info "5/7 Configuration de Dolibarr (modules, clé API, catégorie, champs perso)"
ADMIN_PASSWORD_TO_APPLY=""
[ -n "$RESTORE_FILE" ] && ADMIN_PASSWORD_TO_APPLY="$(env_get "$DOCKER_ENV" DOLI_ADMIN_PASSWORD)"
WIKICARDS_RESET_API_KEY="$RESET_KEY" WIKICARDS_ADMIN_PASSWORD="$ADMIN_PASSWORD_TO_APPLY" bash docker/setup-dolibarr.sh

# ---------------------------------------------------------------------
c_info "6/7 Démarrage de l'API$( [ -n "$TUNNEL_TOKEN" ] && echo ' + tunnel Cloudflare')"
PROFILE=()
[ -n "$TUNNEL_TOKEN" ] && PROFILE=(--profile tunnel)
"${COMPOSE[@]}" "${PROFILE[@]}" up -d --build --force-recreate api
[ -n "$TUNNEL_TOKEN" ] && "${COMPOSE[@]}" "${PROFILE[@]}" up -d tunnel
wait_http "http://127.0.0.1:8000/health" 120 "API" || c_fail "L'API ne répond pas : docker logs wikicards_api"

if [ -n "$RESTORE_FILE" ] && [ -d "$WORK/api_data" ] && [ -n "$(ls -A "$WORK/api_data" 2>/dev/null)" ]; then
  docker cp "$WORK/api_data/." wikicards_api:/app/data/
  c_ok "Données de l'API restaurées"
fi

ADMIN_KEY="$(env_get "$API_ENV" ADMIN_API_KEY)"
STATS="$(curl -fsS -H "X-API-Key: $ADMIN_KEY" http://127.0.0.1:8000/api/catalog/stats || true)"
c_ok "Catalogue : ${STATS:-indisponible}"

# ---------------------------------------------------------------------
if [ -n "$LOAD_COUNT" ]; then
  c_info "7/7 Chargement du catalogue ($LOAD_COUNT cartes par rareté)"
  BODY="{\"targets\": {\"legendary\": $LOAD_COUNT, \"epic\": $LOAD_COUNT, \"rare\": $LOAD_COUNT, \"uncommon\": $LOAD_COUNT, \"common\": $LOAD_COUNT}}"
  curl -fsS -X POST -H "X-API-Key: $ADMIN_KEY" -H "Content-Type: application/json" -d "$BODY" \
    http://127.0.0.1:8000/api/catalog/load && echo
  c_ok "Chargement lancé en arrière-plan (suivi : GET /api/catalog/jobs)"
else
  c_info "7/7 Chargement du catalogue : ignoré (pas de --load)"
fi

# ---------------------------------------------------------------------
PUBLIC_URL="https://wikiblox.omertilki.fr"
cat <<EOF

=====================================================================
 WikiBlox est en place
=====================================================================
 API locale      : http://127.0.0.1:8000        (Swagger : /docs)
 API publique    : $( [ -n "$TUNNEL_TOKEN" ] && echo "$PUBLIC_URL  (via tunnel)" || echo "non exposée (pas de token tunnel)")
 Dolibarr        : http://127.0.0.1:8080        (admin / mot de passe : DOLI_ADMIN_PASSWORD dans docker/.env)

 Clés d'API (API/.env) :
   ADMIN_API_KEY  -> administration, bouton "Authorize" de Swagger
   GAME_API_KEY   -> serveur de jeu Roblox (Secrets Store), jamais dans un script du jeu

 Commandes utiles :
   Logs API       : docker logs -f wikicards_api
   État           : docker compose -f docker/docker-compose.yml --profile tunnel ps
   Arrêter        : docker compose -f docker/docker-compose.yml --profile tunnel down
   Sauvegarder    : ./scripts/backup.sh
   Mettre à jour  : git pull && ./install.sh
=====================================================================
EOF
