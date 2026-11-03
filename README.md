# WikiBlox

Jeu Roblox de cartes à collectionner basé sur Wikipédia. La rareté d'une carte dépend du nombre de vues de l'article (juillet à septembre 2024).

| Dossier | Contenu |
|---|---|
| `API/` | API FastAPI : catalogue de cartes, boosters, collections des joueurs |
| `docker/` | Stack Docker (MariaDB, Dolibarr, API, tunnel Cloudflare) et configuration de Dolibarr |
| `scripts/` | Sauvegarde |
| `roblox/` | Projet Rojo du jeu |

Dolibarr (ERP) sert de base de données : une carte est un produit `WIKI_<page_id>`, un joueur est un client (`roblox_user_id`), sa collection est un entrepôt `ROBLOX_<id>` (stock = exemplaires).

## Installation (Linux)

Prérequis : Docker (avec `docker compose`), git et curl.

```bash
git clone git@github.com:ramdom667/WikiBlox.git && cd WikiBlox
bash install.sh --tunnel-token <TOKEN_CLOUDFLARE>
```

`install.sh` effectue ces étapes :

1. génère `docker/.env` et `API/.env` (mots de passe et clés d'API aléatoires) ;
2. démarre MariaDB et Dolibarr (installation automatique) ;
3. configure Dolibarr : modules, clé API, catégorie WikiCards, champs personnalisés ;
4. démarre l'API et le tunnel, ce qui met l'API en ligne sur https://wikiblox.omertilki.fr.

Le script est relançable sans risque : il ne remplace aucune clé ni donnée existante. Ses options :

| Option | Effet |
|---|---|
| `--tunnel-token <TOKEN>` | Met l'API en ligne via Cloudflare Tunnel |
| `--restore backups/xxx.tar.gz` | Restaure une sauvegarde (catalogue, joueurs, collections) |
| `--load 20` | Charge 20 nouvelles cartes de chaque rareté |

## Exploitation

| Action | Commande |
|---|---|
| Sauvegarder | `bash scripts/backup.sh` (crée `backups/wikiblox-<date>.tar.gz`) |
| Mettre à jour | `git pull && bash install.sh` |
| Logs de l'API | `docker logs -f wikicards_api` |
| Arrêter | `docker compose -f docker/docker-compose.yml --profile tunnel down` |

Accès locaux :

- API : http://127.0.0.1:8000 (Swagger sur `/docs`, bouton **Authorize** avec `ADMIN_API_KEY`)
- Dolibarr : http://127.0.0.1:8080 (utilisateur `admin`, mot de passe `DOLI_ADMIN_PASSWORD` dans `docker/.env`)

Clés d'API (dans `API/.env`, en-tête `X-API-Key`) :

- `ADMIN_API_KEY` : toutes les routes ;
- `GAME_API_KEY` : boosters et collections uniquement. C'est la clé du serveur Roblox, à stocker dans le Secrets Store de Roblox.

## Cloudflare Tunnel

1. Dans https://one.dash.cloudflare.com, ouvrir **Networks** puis **Tunnels** et créer le tunnel `wikiblox` (type Cloudflared).
2. Copier le token, c'est-à-dire la chaîne affichée après `--token`.
3. Dans **Public Hostname**, ajouter `wikiblox.omertilki.fr` avec le service `HTTP`, URL `api:8000`.

Le tunnel ne doit tourner que sur **une seule machine** à la fois. Sinon, Cloudflare répartit les requêtes entre deux bases différentes.
