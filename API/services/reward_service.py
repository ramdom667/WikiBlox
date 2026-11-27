"""
Récompenses : donner UNE carte d'une rareté précise à un joueur (pêche, plus tard quêtes, événements...)

Contrairement aux boosters, c'est le jeu qui tire la rareté : il connaît les bonus du joueur
(zone de pêche, canne, appât...). L'API pioche une carte de cette rareté dans le catalogue
et l'ajoute à la collection du joueur (+1 exemplaire dans son entrepôt Dolibarr).
"""
import random
import uuid
from typing import Dict, Optional

from services.booster_service import card_view, get_catalog
from services.dolibarr_service import DolibarrService
from services.player_service import Player, get_or_create_player
from services.wikipedia_service import RARITIES

# Sources autorisées : identifiant envoyé par le jeu -> début du libellé du mouvement de stock Dolibarr
# (pour ajouter une source, par exemple "quete", il suffit d'ajouter une ligne ici)
SOURCES: Dict[str, str] = {
    "peche": "Peche",
}


class RewardError(Exception):
    """Erreur fonctionnelle (rareté ou source inconnue, catalogue vide...)"""

    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.status_code = status_code


def grant_card(dolibarr: DolibarrService, roblox_user_id: int, rarity: str, source: str,
               username: Optional[str] = None) -> Dict:
    """Pioche une carte de la rareté demandée et l'ajoute à la collection du joueur"""
    if rarity not in RARITIES:
        raise RewardError(f"Rareté inconnue : '{rarity}'. Possibles : {RARITIES}", 422)
    if source not in SOURCES:
        raise RewardError(f"Source inconnue : '{source}'. Possibles : {list(SOURCES)}", 422)

    # Tirage avant toute écriture : si le catalogue est vide, rien n'est créé ni enregistré
    pool = get_catalog(dolibarr).get(rarity) or []
    if not pool:
        raise RewardError(
            f"Aucune carte '{rarity}' dans le catalogue. Chargez des cartes via /api/catalog/load.", 503
        )
    product = random.choice(pool)
    product_id = int(product["id"])

    player: Player = get_or_create_player(dolibarr, roblox_user_id, username)
    owned = dolibarr.get_warehouse_stock(player.warehouse_id)
    before = owned[product_id]["qty"] if product_id in owned else 0

    grant_id = uuid.uuid4().hex[:10]
    label = f"{SOURCES[source]} #{grant_id} - Roblox {player.roblox_user_id}"
    dolibarr.add_stock_movement(product_id, player.warehouse_id, 1, label)

    card = card_view(product)
    card.update({"is_new": before == 0, "copies_owned": before + 1})
    return {
        "grant_id": grant_id,
        "source": source,
        "player": player.to_dict(),
        "card": card,
    }
