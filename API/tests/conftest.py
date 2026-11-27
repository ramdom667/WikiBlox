"""
Tests de l'API sans vrai Dolibarr : un faux Dolibarr en mémoire remplace DolibarrService.

Lancer depuis le dossier API/ :
    pip install -r requirements.txt -r requirements-dev.txt
    python -m pytest tests
"""
import os
import sys
from pathlib import Path

import pytest

API_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(API_DIR))

GAME_KEY = "test-game-key"
ADMIN_KEY = "test-admin-key"

# Avant d'importer l'application : clés de test, et aucun .env ne doit les écraser
os.environ["GAME_API_KEY"] = GAME_KEY
os.environ["ADMIN_API_KEY"] = ADMIN_KEY
os.environ.setdefault("DOCS_ENABLED", "false")


class FakeDolibarr:
    """Le strict nécessaire de DolibarrService, en mémoire"""

    def __init__(self, products):
        self.products = products
        self.thirdparties = {}  # roblox_user_id -> tiers
        self.warehouses = {}  # ref -> id
        self.stock = {}  # (warehouse_id, product_id) -> qté
        self.movements = []  # (product_id, warehouse_id, qty, label)
        self.fail_movements = False

    def list_wikicards(self, properties=None):
        return list(self.products)

    def find_thirdparty_by_roblox_id(self, uid):
        return self.thirdparties.get(uid)

    def create_thirdparty(self, data):
        tid = len(self.thirdparties) + 1
        self.thirdparties[data["array_options"]["options_roblox_user_id"]] = {"id": str(tid), "name": data["name"]}
        return tid

    def find_warehouse_by_ref(self, ref):
        wid = self.warehouses.get(ref)
        return {"id": str(wid)} if wid else None

    def create_warehouse(self, ref, description):
        wid = 100 + len(self.warehouses)
        self.warehouses[ref] = wid
        return wid

    def get_warehouse_stock(self, warehouse_id):
        by_id = {int(p["id"]): p for p in self.products}
        return {
            pid: {"qty": qty, "product": by_id[pid]}
            for (wid, pid), qty in self.stock.items()
            if wid == warehouse_id and qty > 0
        }

    def add_stock_movement(self, product_id, warehouse_id, qty, label):
        if self.fail_movements:
            raise Exception("Dolibarr indisponible")
        key = (int(warehouse_id), int(product_id))
        self.stock[key] = self.stock.get(key, 0) + qty
        self.movements.append((int(product_id), int(warehouse_id), qty, label))
        return len(self.movements)


def carte(pid, rarity, title):
    return {
        "id": str(pid),
        "ref": f"WIKI_{pid}",
        "label": f"{title} - Carte Wikipédia",
        "note_private": "{}",
        "array_options": {
            "options_wikicards_rarity": rarity,
            "options_wikipedia_title": title,
            "options_wikipedia_page_id": str(pid),
            "options_wikicards_total_views": "1234",
        },
    }


@pytest.fixture
def fake_dolibarr(monkeypatch, tmp_path):
    from routes import rewards
    from services import booster_service, idempotency, player_service
    from services.rate_limit import RateLimiter

    fake = FakeDolibarr([
        carte(1, "common", "Chat"),
        carte(2, "uncommon", "Tour Eiffel"),
        carte(3, "rare", "Paris"),
        carte(4, "epic", "Albert Einstein"),
        # aucune légendaire : sert à tester le catalogue vide
    ])
    monkeypatch.setattr(rewards, "_dolibarr", lambda: fake)
    monkeypatch.setattr(rewards, "_limiter", RateLimiter(15, 60))
    monkeypatch.setattr(idempotency, "DATA_DIR", tmp_path)
    monkeypatch.setattr(idempotency, "DB_PATH", tmp_path / "idempotency.sqlite3")
    booster_service.invalidate_catalog_cache()
    player_service._cache.clear()
    yield fake
    booster_service.invalidate_catalog_cache()
    player_service._cache.clear()


@pytest.fixture
def client():
    from fastapi.testclient import TestClient
    from main import app

    # main.py recharge API/.env (override=True) : on remet les clés de test par-dessus
    os.environ["GAME_API_KEY"] = GAME_KEY
    os.environ["ADMIN_API_KEY"] = ADMIN_KEY
    return TestClient(app)
