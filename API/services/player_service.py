"""
Joueurs Roblox <-> Dolibarr

  joueur Roblox  = tiers (client) avec le champ personnalisé roblox_user_id
  sa collection  = un entrepôt ROBLOX_<user_id> : stock d'une carte = nombre d'exemplaires
"""
import threading
from dataclasses import dataclass
from typing import Dict, List, Optional

from services.dolibarr_service import DolibarrService
from services.wikipedia_service import RARITIES

_cache: Dict[str, "Player"] = {}
_lock = threading.Lock()


@dataclass
class Player:
    roblox_user_id: str
    thirdparty_id: int
    warehouse_id: int
    name: str
    created: bool = False  # créé lors de cet appel

    def to_dict(self) -> Dict:
        return {
            "roblox_user_id": self.roblox_user_id,
            "name": self.name,
            "dolibarr_thirdparty_id": self.thirdparty_id,
            "dolibarr_warehouse_id": self.warehouse_id,
            "new_player": self.created,
        }


def warehouse_ref(roblox_user_id: str) -> str:
    return f"ROBLOX_{roblox_user_id}"


def get_or_create_player(dolibarr: DolibarrService, roblox_user_id: int,
                         username: Optional[str] = None) -> Player:
    """Retrouve le joueur dans Dolibarr ou crée son compte client + son entrepôt"""
    uid = str(roblox_user_id)
    with _lock:
        if uid in _cache:
            cached = _cache[uid]
            return Player(cached.roblox_user_id, cached.thirdparty_id, cached.warehouse_id, cached.name)

        created = False
        thirdparty = dolibarr.find_thirdparty_by_roblox_id(uid)
        if thirdparty:
            thirdparty_id = int(thirdparty["id"])
            name = thirdparty.get("name") or f"Roblox {uid}"
        else:
            name = f"{username} (Roblox {uid})" if username else f"Roblox {uid}"
            try:
                thirdparty_id = dolibarr.create_thirdparty({
                    "name": name,
                    "client": 1,
                    "code_client": "auto",
                    "note_private": f"Joueur Roblox {uid}",
                    "array_options": {"options_roblox_user_id": uid},
                })
                created = True
            except Exception:
                # Création concurrente (roblox_user_id est unique en base) : on relit
                thirdparty = dolibarr.find_thirdparty_by_roblox_id(uid)
                if not thirdparty:
                    raise
                thirdparty_id = int(thirdparty["id"])

        ref = warehouse_ref(uid)
        warehouse = dolibarr.find_warehouse_by_ref(ref)
        if warehouse:
            warehouse_id = int(warehouse["id"])
        else:
            warehouse_id = dolibarr.create_warehouse(ref, f"Collection WikiCards de {name}")
            created = True

        player = Player(uid, thirdparty_id, warehouse_id, name, created)
        _cache[uid] = Player(uid, thirdparty_id, warehouse_id, name)
        return player


def find_player(dolibarr: DolibarrService, roblox_user_id: int) -> Optional[Player]:
    """Joueur existant (sans création), ou None"""
    uid = str(roblox_user_id)
    if uid in _cache:
        return _cache[uid]
    thirdparty = dolibarr.find_thirdparty_by_roblox_id(uid)
    warehouse = dolibarr.find_warehouse_by_ref(warehouse_ref(uid))
    if not thirdparty or not warehouse:
        return None
    player = Player(uid, int(thirdparty["id"]), int(warehouse["id"]), thirdparty.get("name") or f"Roblox {uid}")
    _cache[uid] = player
    return player


def get_collection(dolibarr: DolibarrService, player: Player) -> Dict:
    """Collection d'un joueur : cartes possédées + nombre d'exemplaires"""
    from services.booster_service import card_view  # import local (évite un import circulaire)

    contents = dolibarr.get_warehouse_stock(player.warehouse_id)
    cards: List[Dict] = []
    for product_id, entry in contents.items():
        view = card_view(entry["product"])
        view["copies"] = entry["qty"]
        cards.append(view)

    rank = {r: i for i, r in enumerate(RARITIES)}
    cards.sort(key=lambda c: (-rank.get(c["rarity"], -1), c["title"]))

    by_rarity = {r: {"unique": 0, "copies": 0} for r in RARITIES}
    for c in cards:
        if c["rarity"] in by_rarity:
            by_rarity[c["rarity"]]["unique"] += 1
            by_rarity[c["rarity"]]["copies"] += c["copies"]

    return {
        "player": player.to_dict(),
        "summary": {
            "unique_cards": len(cards),
            "total_copies": sum(c["copies"] for c in cards),
            "by_rarity": by_rarity,
        },
        "cards": cards,
    }
