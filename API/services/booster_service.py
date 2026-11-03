"""
Boosters : tirage de cartes selon des probabilités définies dans config/boosters.json

Ouverture d'un booster :
  1. pour chaque emplacement, tirage d'une rareté selon les poids de l'emplacement
  2. pioche d'une carte de cette rareté dans le catalogue Dolibarr (pas de doublon dans un même booster)
  3. tri de la moins rare à la plus rare (la dernière carte est la plus rare)
  4. ajout à la collection du joueur : +1 en stock dans son entrepôt Dolibarr par carte
"""
import json
import random
import threading
import time
import uuid
from collections import Counter
from pathlib import Path
from typing import Dict, List, Optional

from services.dolibarr_service import DolibarrService
from services.player_service import Player, get_or_create_player
from services.wikipedia_service import RARITIES, RARITY_TIERS

CONFIG_PATH = Path(__file__).resolve().parent.parent / "config" / "boosters.json"
CATALOG_CACHE_TTL = 300  # secondes

RARITY_RANK = {r: i for i, r in enumerate(RARITIES)}
RARITY_EMOJI = {name: emoji for name, _, _, emoji in RARITY_TIERS}


class BoosterError(Exception):
    """Erreur fonctionnelle (booster inconnu, catalogue insuffisant...)"""

    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.status_code = status_code


# ----------------------------------------------------------------------
# Configuration des boosters
# ----------------------------------------------------------------------

def load_boosters() -> Dict[str, Dict]:
    """Lit et valide config/boosters.json (relu à chaque appel : modifiable à chaud)"""
    with open(CONFIG_PATH, encoding="utf-8") as f:
        boosters = json.load(f)

    for booster_id, booster in boosters.items():
        if not booster.get("slots"):
            raise ValueError(f"Booster '{booster_id}' : aucun emplacement")
        for slot in booster["slots"]:
            weights = slot.get("weights") or {}
            unknown = set(weights) - set(RARITIES)
            if unknown:
                raise ValueError(f"Booster '{booster_id}' : rareté inconnue {unknown}")
            if sum(weights.values()) <= 0 or any(w < 0 for w in weights.values()):
                raise ValueError(f"Booster '{booster_id}' : poids invalides {weights}")
            if int(slot.get("count", 1)) < 1:
                raise ValueError(f"Booster '{booster_id}' : count doit être >= 1")
    return boosters


def get_booster(booster_type: str) -> Dict:
    boosters = load_boosters()
    if booster_type not in boosters:
        raise BoosterError(f"Booster inconnu : '{booster_type}'. Disponibles : {list(boosters)}", 404)
    return boosters[booster_type]


def booster_odds(booster: Dict) -> Dict:
    """Description publique d'un booster avec les probabilités en % (affichage en jeu)"""
    slots = []
    for slot in booster["slots"]:
        total = sum(slot["weights"].values())
        slots.append({
            "label": slot.get("label"),
            "count": int(slot.get("count", 1)),
            "odds_percent": {
                r: round(100 * slot["weights"][r] / total, 2)
                for r in RARITIES if slot["weights"].get(r)
            },
        })
    return {
        "name": booster.get("name"),
        "description": booster.get("description"),
        "cards_per_booster": sum(s["count"] for s in slots),
        "slots": slots,
    }


# ----------------------------------------------------------------------
# Catalogue (cartes disponibles par rareté, en cache)
# ----------------------------------------------------------------------

_catalog: Optional[Dict[str, List[Dict]]] = None
_catalog_loaded_at = 0.0
_catalog_lock = threading.Lock()


def invalidate_catalog_cache():
    """À appeler quand de nouvelles cartes sont ajoutées au catalogue"""
    global _catalog
    with _catalog_lock:
        _catalog = None


def get_catalog(dolibarr: DolibarrService) -> Dict[str, List[Dict]]:
    """{rareté: [produits]} des cartes WikiCards en base"""
    global _catalog, _catalog_loaded_at
    with _catalog_lock:
        if _catalog is None or time.time() - _catalog_loaded_at > CATALOG_CACHE_TTL:
            catalog: Dict[str, List[Dict]] = {r: [] for r in RARITIES}
            for product in dolibarr.list_wikicards():
                rarity = (product.get("array_options") or {}).get("options_wikicards_rarity")
                if rarity in catalog:
                    catalog[rarity].append(product)
            _catalog = catalog
            _catalog_loaded_at = time.time()
        return _catalog


def card_view(product: Dict) -> Dict:
    """Carte au format jeu à partir d'un produit Dolibarr"""
    options = product.get("array_options") or {}
    meta = {}
    try:
        meta = json.loads(product.get("note_private") or "{}")
    except (TypeError, ValueError):
        pass
    wiki = meta.get("wikipedia", {}) if isinstance(meta, dict) else {}

    rarity = options.get("options_wikicards_rarity") or "common"
    title = options.get("options_wikipedia_title") or str(product.get("label", "")).replace(" - Carte Wikipédia", "")
    page_id = options.get("options_wikipedia_page_id")

    return {
        "product_id": int(product["id"]),
        "product_ref": product.get("ref"),
        "page_id": int(page_id) if page_id else None,
        "title": title,
        "description": wiki.get("short_description") or "",
        "image": wiki.get("original_image_url") or wiki.get("image_url"),
        "page_url": wiki.get("page_url") or product.get("url"),
        "rarity": rarity,
        "rarity_display": f"{RARITY_EMOJI.get(rarity, '')} {rarity.upper()}",
        "total_views": int(float(options.get("options_wikicards_total_views") or 0)),
    }


# ----------------------------------------------------------------------
# Tirage
# ----------------------------------------------------------------------

def draw_rarities(booster: Dict, available: Optional[Dict[str, int]] = None) -> List[str]:
    """
    Tire la rareté de chaque carte du booster.

    available : nombre de cartes disponibles par rareté. Une rareté épuisée est retirée
    du tirage de l'emplacement (les poids restants sont renormalisés).
    """
    remaining = dict(available) if available is not None else None
    rarities: List[str] = []
    for slot in booster["slots"]:
        for _ in range(int(slot.get("count", 1))):
            weights = {r: w for r, w in slot["weights"].items() if w > 0}
            if remaining is not None:
                weights = {r: w for r, w in weights.items() if remaining.get(r, 0) > 0}
                if not weights:
                    raise BoosterError(
                        f"Catalogue insuffisant pour l'emplacement '{slot.get('label')}' "
                        f"(raretés possibles : {list(slot['weights'])}). Chargez des cartes via /api/catalog/load.",
                        503,
                    )
            rarity = random.choices(list(weights), weights=list(weights.values()))[0]
            rarities.append(rarity)
            if remaining is not None:
                remaining[rarity] -= 1
    return rarities


def simulate(booster_type: str, count: int) -> Dict:
    """Ouvre `count` boosters fictifs (raretés seulement, rien en base) pour vérifier les taux"""
    booster = get_booster(booster_type)
    per_card = Counter()
    best = Counter()
    for _ in range(count):
        rarities = sorted(draw_rarities(booster), key=RARITY_RANK.get)
        per_card.update(rarities)
        best[rarities[-1]] += 1
    total_cards = sum(per_card.values())
    return {
        "booster_type": booster_type,
        "boosters_simulated": count,
        "cards_drawn": total_cards,
        "cards_by_rarity_percent": {r: round(100 * per_card[r] / total_cards, 2) for r in RARITIES},
        "best_card_percent": {r: round(100 * best[r] / count, 2) for r in RARITIES},
        "odds": booster_odds(booster),
    }


def open_booster(dolibarr: DolibarrService, roblox_user_id: int, booster_type: str = "standard",
                 username: Optional[str] = None) -> Dict:
    """Ouvre un booster pour un joueur et ajoute les cartes à sa collection"""
    booster = get_booster(booster_type)
    catalog = get_catalog(dolibarr)

    # 1-2. Tirage (avant toute écriture : en cas d'échec, rien n'est enregistré)
    rarities = draw_rarities(booster, {r: len(cards) for r, cards in catalog.items()})
    picked_ids = set()
    drawn: List[Dict] = []
    for rarity in rarities:
        pool = [p for p in catalog[rarity] if int(p["id"]) not in picked_ids]
        product = random.choice(pool)
        picked_ids.add(int(product["id"]))
        drawn.append(product)

    # 3. Tri : de la moins rare à la plus rare
    random.shuffle(drawn)
    drawn.sort(key=lambda p: RARITY_RANK.get((p.get("array_options") or {}).get("options_wikicards_rarity"), 0))

    # 4. Ajout à la collection du joueur
    player: Player = get_or_create_player(dolibarr, roblox_user_id, username)
    owned = {pid: entry["qty"] for pid, entry in dolibarr.get_warehouse_stock(player.warehouse_id).items()}

    opening_id = uuid.uuid4().hex[:10]
    label = f"Booster {booster_type} #{opening_id} - Roblox {player.roblox_user_id}"
    cards = []
    for position, product in enumerate(drawn, start=1):
        product_id = int(product["id"])
        dolibarr.add_stock_movement(product_id, player.warehouse_id, 1, label)
        before = owned.get(product_id, 0)
        view = card_view(product)
        view.update({"position": position, "is_new": before == 0, "copies_owned": before + 1})
        cards.append(view)

    return {
        "opening_id": opening_id,
        "booster_type": booster_type,
        "booster_name": booster.get("name"),
        "player": player.to_dict(),
        "best_rarity": cards[-1]["rarity"],
        "new_cards": sum(1 for c in cards if c["is_new"]),
        "cards": cards,
    }
