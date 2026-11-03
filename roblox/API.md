# Utiliser l'API WikiCards depuis Roblox

Ce guide explique comment le jeu ouvre des boosters et lit la collection d'un joueur via l'API `https://wikiblox.omertilki.fr`.

Le code est prêt dans `src/server/` :

| Fichier | Rôle |
|---|---|
| `src/server/WikiCardsApi.luau` | Module serveur qui appelle l'API (clé, JSON, nouvelles tentatives) |
| `src/server/WikiBloxBoosters.server.luau` | Expose aux clients les RemoteFunction `OuvrirBooster`, `MaCollection` et `ProbaBoosters` |

## 1. Comment ça marche

```
Client (bouton "Ouvrir")
   │  RemoteFunction OuvrirBooster
   ▼
Serveur Roblox (WikiBloxBoosters.server.luau)
   │  vérifie (anti-spam, type de booster, monnaie…)
   │  HttpService:RequestAsync + clé du Secrets Store
   ▼
https://wikiblox.omertilki.fr  (tunnel Cloudflare)
   ▼
API FastAPI ──► Dolibarr (cartes, joueurs, collections)
```

**Règle d'or : le client ne parle jamais à l'API.**

- Roblox interdit les requêtes HTTP depuis un client : `HttpService` ne fonctionne que côté serveur.
- La clé d'API donnerait à n'importe quel tricheur le droit d'ouvrir des boosters gratuits.

Le client demande donc au serveur, et c'est le serveur qui décide.

## 2. Configuration (une seule fois par expérience)

### 2.1 Autoriser les requêtes HTTP

Dans Studio, ouvrir **File → Experience Settings → Security** et activer **Allow HTTP Requests**.

### 2.2 Créer le secret contenant la clé d'API

La clé à utiliser est `GAME_API_KEY`. Elle se trouve dans `API/.env` sur la machine qui héberge l'API :

```bash
grep GAME_API_KEY ~/WikiBlox/API/.env
```

> N'utilisez jamais `ADMIN_API_KEY` dans le jeu. `GAME_API_KEY` n'autorise que les boosters et les collections.

**Pour les serveurs en ligne :**

1. Ouvrir le [Creator Dashboard](https://create.roblox.com/dashboard/creations) et choisir l'expérience.
2. Aller dans **Secrets**, puis **Create Secret**.
3. Remplir les champs :

   | Champ | Valeur |
   |---|---|
   | **Name** | `wikiblox_game_key` (doit correspondre à `SECRET_NAME` dans `WikiCardsApi.luau`) |
   | **Secret** | la valeur de `GAME_API_KEY` |
   | **Domain** | `wikiblox.omertilki.fr` (la clé ne pourra être envoyée qu'à ce domaine) |

Seul le propriétaire de l'expérience, ou du groupe, peut créer les secrets.

**Pour tester dans Studio :**

Les secrets du dashboard ne sont **pas** disponibles en test local. Il faut les ajouter dans **File → Experience Settings → Security → Local Secrets**, avec le même nom, la même valeur et le même domaine.

> ⚠️ Ne jamais écrire la clé dans un script, un commit, un message Discord ou une capture d'écran. Si elle fuit, il faut la régénérer : changer `GAME_API_KEY` dans `API/.env`, relancer `bash install.sh`, puis mettre à jour le secret Roblox.

Le module lit la clé avec `HttpService:GetSecret()`. Roblox renvoie un objet `Secret` et non une chaîne : un `print` affiche `Secret(wikiblox_game_key)` et jamais la valeur. Le secret peut être placé dans un en-tête HTTP, ce que fait le module, mais pas dans le corps de la requête.

## 3. Les routes de l'API utilisées par le jeu

Toutes les routes exigent l'en-tête `X-API-Key`. Swagger est disponible sur https://wikiblox.omertilki.fr/docs : bouton **Authorize**, puis coller la clé.

| Route | Rôle |
|---|---|
| `GET /api/boosters` | Types de boosters et probabilités de chaque emplacement |
| `POST /api/boosters/open` | Ouvre un booster, ajoute les cartes à la collection du joueur et les renvoie |
| `GET /api/players/{userId}/collection` | Cartes possédées et nombre d'exemplaires |

### Ouvrir un booster

Requête :

```json
{
  "roblox_user_id": 123456789,
  "roblox_username": "Pseudo",
  "booster_type": "standard",
  "request_id": "6f1c2a0e-5b8d-4c1e-9a77-0d3e2b1f4a55"
}
```

Réponse (extrait) :

```json
{
  "success": true,
  "replayed": false,
  "opening_id": "…",
  "best_rarity": "rare",
  "new_cards": 3,
  "player": { "roblox_user_id": 123456789, "new_player": false },
  "cards": [
    {
      "position": 1,
      "title": "Tour Eiffel",
      "description": "…",
      "image": "https://upload.wikimedia.org/…",
      "page_url": "https://en.wikipedia.org/wiki/…",
      "rarity": "common",
      "rarity_display": "⚪ COMMON",
      "total_views": 842,
      "is_new": true,
      "copies_owned": 1
    }
  ]
}
```

- Un booster `standard` contient **5 cartes, triées de la moins rare à la plus rare**. La 5e est **au minimum rare**, ce qui en fait la carte à révéler en dernier.
- Raretés, de la plus faible à la plus forte : `common`, `uncommon`, `rare`, `epic`, `legendary`.
- `is_new` indique si le joueur découvre la carte. `copies_owned` est son nombre d'exemplaires après l'ouverture.
- Le joueur, c'est-à-dire son compte client et sa collection dans Dolibarr, est **créé automatiquement** à son premier booster.

### `request_id`, ou comment ne pas ouvrir deux boosters par erreur

Chaque ouverture porte un identifiant unique (`HttpService:GenerateGUID(false)`).

Si la requête échoue en route, par exemple sur un timeout alors que l'API a bien ouvert le booster, il faut la renvoyer **avec le même `request_id`**. L'API répond alors avec **le même booster** (`"replayed": true`) au lieu d'en ouvrir un second.

Le module le fait automatiquement : il fait jusqu'à 3 tentatives avec le même identifiant.

## 4. Utilisation dans le jeu

### Côté serveur

`WikiBloxBoosters.server.luau` est déjà en place. Il crée `ReplicatedStorage.WikiBloxRemotes` et gère deux protections :

- l'anti-spam : un appel à la fois et 3 s minimum entre deux appels ;
- la vérification du type de booster.

**Le point à compléter** est marqué `À FAIRE` : vérifier et débiter la monnaie du jeu avant l'ouverture. Pour l'instant, l'ouverture est gratuite.

Pour appeler l'API depuis un autre script serveur :

```lua
local WikiCardsApi = require(game.ServerScriptService.Server.WikiCardsApi)

local ok, data = WikiCardsApi.openBooster(player, "standard")
if ok then
	for _, card in data.cards do
		print(card.position, card.title, card.rarity)
	end
else
	warn(data.status, data.message)
end
```

### Côté client (exemple de bouton)

```lua
-- LocalScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("WikiBloxRemotes")

local result = remotes.OuvrirBooster:InvokeServer("standard")
if result.success then
	for _, card in result.booster.cards do
		-- Animation de révélation carte par carte : la dernière est la plus rare
		print(card.rarity_display, card.title, card.is_new and "NOUVELLE !" or ("x" .. card.copies_owned))
	end
else
	print(result.error)
end

local col = remotes.MaCollection:InvokeServer()
if col.success and col.collection then
	print("Cartes uniques :", col.collection.summary.unique_cards)
end
```

`InvokeServer` attend la réponse. Une ouverture prend environ 1 à 3 secondes, d'où l'intérêt d'afficher une animation pendant l'attente.

## 5. Boosters payants en Robux

Pour vendre un booster contre des Robux, utiliser un **Developer Product** et `MarketplaceService.ProcessReceipt`. Le `PurchaseId` sert alors de `request_id` : si Roblox rappelle `ProcessReceipt` pour le même achat, l'API renvoie le même booster sans en ouvrir un second.

```lua
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local WikiCardsApi = require(game.ServerScriptService.Server.WikiCardsApi)

local BOOSTER_PRODUCTS = { [123456] = "standard" } -- ID du Developer Product -> type de booster

MarketplaceService.ProcessReceipt = function(receipt)
	local boosterType = BOOSTER_PRODUCTS[receipt.ProductId]
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not boosterType or not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox réessaiera plus tard
	end
	local ok, data = WikiCardsApi.openBooster(player, boosterType, receipt.PurchaseId)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Envoyer data.cards au client (RemoteEvent) pour l'animation
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
```

> **Obligatoire chez Roblox :** les probabilités des objets aléatoires payants doivent être affichées **avant l'achat**. Les taux exacts sont fournis par `ProbaBoosters:InvokeServer()`, qui appelle `GET /api/boosters`.

## 6. Limites et pièges à connaître

| Sujet | À savoir |
|---|---|
| **Quota HTTP** | 500 requêtes par minute **par serveur Roblox**. Il ne faut pas appeler l'API en boucle : mettre la collection en cache côté serveur et la rafraîchir après chaque ouverture. |
| **Images des cartes** | Roblox **ne peut pas afficher une image depuis une URL externe** : `ImageLabel.Image` n'accepte que des `rbxassetid://`. Le champ `image` (Wikimedia) ne peut donc pas être affiché tel quel. Il faut des visuels génériques par rareté, ou un futur import des images comme assets Roblox (soumis à modération). |
| **Tests multi-joueurs dans Studio** | En mode *Local Server*, les joueurs de test ont des `UserId` **négatifs** (-1, -2…), que l'API refuse (erreur 422). Il faut tester en *Play* simple, ou dans un serveur en ligne. |
| **Probabilités** | Elles sont définies dans `API/config/boosters.json`, côté API. Une modification s'applique tout de suite, sans republier le jeu. |
| **Cloudflare** | *Bot Fight Mode* et *Under Attack Mode* doivent rester **désactivés**, sinon Cloudflare bloque les requêtes des serveurs Roblox. |
| **Un seul hébergeur** | L'API et sa base tournent sur une seule machine. Si elle est éteinte, les ouvertures échouent : le jeu doit afficher un message propre, ce que fait le module. |

## 7. Dépannage

| Message dans la console serveur | Cause et solution |
|---|---|
| `Http requests are not enabled` | Activer **Allow HTTP Requests** (§ 2.1) |
| `Secret 'wikiblox_game_key' introuvable` | Secret absent : ajouter un **Local Secret** en test Studio, ou un secret dans le dashboard pour les serveurs en ligne (§ 2.2) |
| status `401` | En-tête `X-API-Key` absent |
| status `403` | Mauvaise clé, ou domaine du secret différent de `wikiblox.omertilki.fr` |
| status `422` | Données invalides, par exemple un `UserId` négatif en test *Local Server* |
| status `503` | Catalogue insuffisant pour une rareté, à recharger côté API (`POST /api/catalog/load`, clé admin), ou Dolibarr arrêté |
| status `502` / `0` | API ou tunnel arrêté. Vérifier `https://wikiblox.omertilki.fr/health`, puis `docker logs wikicards_api` sur la machine hôte |
