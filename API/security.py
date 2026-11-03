"""
Authentification par clé d'API (en-tête X-API-Key)

  GAME_API_KEY  : clé du serveur de jeu Roblox -> boosters, collections
  ADMIN_API_KEY : clé d'administration        -> tout (catalogue, Dolibarr, cartes...)

Dans Swagger (/docs) : bouton "Authorize" puis coller la clé.
"""
import os
import secrets
from typing import Optional

from fastapi import HTTPException, Security
from fastapi.security import APIKeyHeader

api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False, description="Clé de jeu ou clé d'administration")


def _matches(provided: Optional[str], env_name: str) -> bool:
    expected = os.getenv(env_name, "")
    return bool(expected) and bool(provided) and secrets.compare_digest(provided, expected)


def _check(provided: Optional[str], allow_game: bool):
    if not os.getenv("ADMIN_API_KEY") and not os.getenv("GAME_API_KEY"):
        raise HTTPException(status_code=503, detail="Clés d'API non configurées sur le serveur (ADMIN_API_KEY / GAME_API_KEY)")
    if not provided:
        raise HTTPException(status_code=401, detail="Clé d'API manquante (en-tête X-API-Key)")
    if _matches(provided, "ADMIN_API_KEY") or (allow_game and _matches(provided, "GAME_API_KEY")):
        return
    raise HTTPException(status_code=403, detail="Clé d'API invalide pour cette route")


def require_game_key(api_key: Optional[str] = Security(api_key_header)):
    """Routes appelées par le jeu : clé de jeu OU clé d'admin"""
    _check(api_key, allow_game=True)


def require_admin_key(api_key: Optional[str] = Security(api_key_header)):
    """Routes d'administration : clé d'admin uniquement"""
    _check(api_key, allow_game=False)
