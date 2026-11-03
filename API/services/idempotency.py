"""
Anti double-ouverture : un même request_id renvoie toujours le même résultat.

Le jeu envoie un identifiant unique par ouverture (ex: GUID généré par le serveur Roblox,
ou PurchaseId d'un achat Robux). Si la requête est rejouée (timeout réseau, retry),
l'API renvoie le booster déjà ouvert au lieu d'en ouvrir un second.

Stockage : SQLite (API/data/idempotency.sqlite3), persistant entre les redémarrages.
"""
import json
import os
import sqlite3
import threading
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path
from typing import Dict, Iterator, Optional

DATA_DIR = Path(os.getenv("DATA_DIR", Path(__file__).resolve().parent.parent / "data"))
DB_PATH = DATA_DIR / "idempotency.sqlite3"

_db_lock = threading.Lock()
_key_locks: Dict[str, threading.Lock] = {}
_key_locks_guard = threading.Lock()


def _connect() -> sqlite3.Connection:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        "CREATE TABLE IF NOT EXISTS results ("
        " scope TEXT NOT NULL, request_id TEXT NOT NULL, response TEXT NOT NULL, created_at TEXT NOT NULL,"
        " PRIMARY KEY (scope, request_id))"
    )
    return conn


def get_result(scope: str, request_id: str) -> Optional[Dict]:
    with _db_lock:
        conn = _connect()
        try:
            row = conn.execute(
                "SELECT response FROM results WHERE scope = ? AND request_id = ?", (scope, request_id)
            ).fetchone()
        finally:
            conn.close()
    return json.loads(row[0]) if row else None


def save_result(scope: str, request_id: str, response: Dict):
    with _db_lock:
        conn = _connect()
        try:
            conn.execute(
                "INSERT OR REPLACE INTO results (scope, request_id, response, created_at) VALUES (?, ?, ?, ?)",
                (scope, request_id, json.dumps(response, ensure_ascii=False), datetime.now().isoformat()),
            )
            conn.commit()
        finally:
            conn.close()


@contextmanager
def request_lock(scope: str, request_id: str) -> Iterator[None]:
    """Sérialise les requêtes concurrentes portant le même request_id"""
    key = f"{scope}:{request_id}"
    with _key_locks_guard:
        lock = _key_locks.setdefault(key, threading.Lock())
    with lock:
        yield
