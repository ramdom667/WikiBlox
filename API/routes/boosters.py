"""
Routes boosters et collections des joueurs Roblox

Les routes sont synchrones (def) : FastAPI les exécute dans un pool de threads,
les appels Dolibarr ne bloquent donc pas le serveur.
"""
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from security import require_game_key
from services import idempotency
from services.booster_service import (
    BoosterError, booster_odds, get_booster, load_boosters, open_booster, simulate,
)
from services.dolibarr_service import DolibarrService
from services.player_service import find_player, get_collection

router = APIRouter(prefix="/api/boosters", tags=["boosters"], dependencies=[Depends(require_game_key)])
players_router = APIRouter(prefix="/api/players", tags=["joueurs"], dependencies=[Depends(require_game_key)])


def _dolibarr() -> DolibarrService:
    try:
        return DolibarrService()
    except ValueError as e:
        raise HTTPException(status_code=503, detail=str(e))


class OpenBoosterRequest(BaseModel):
    roblox_user_id: int = Field(..., gt=0, description="UserId Roblox du joueur", examples=[123456789])
    booster_type: str = Field("standard", description="Type de booster (voir GET /api/boosters)")
    roblox_username: Optional[str] = Field(None, max_length=50, description="Pseudo Roblox (utilisé à la création du compte)")
    request_id: Optional[str] = Field(
        None, min_length=8, max_length=64, pattern=r"^[A-Za-z0-9_\-{}]+$",
        description="Identifiant unique de l'ouverture (GUID / PurchaseId). Rejouer le même request_id renvoie le même booster sans en ouvrir un autre.",
    )


@router.get("")
def list_boosters():
    """Types de boosters disponibles avec leurs probabilités (à afficher en jeu)"""
    try:
        return {"boosters": {bid: booster_odds(b) for bid, b in load_boosters().items()}}
    except ValueError as e:
        raise HTTPException(status_code=500, detail=f"Configuration des boosters invalide : {e}")


@router.post("/open")
def open_booster_route(request: OpenBoosterRequest):
    """
    Ouvre un booster pour un joueur Roblox

    - Crée automatiquement le compte client Dolibarr + l'entrepôt (collection) du joueur au premier tirage
    - Cartes triées de la moins rare à la plus rare (la dernière est la plus rare)
    - Booster standard : 5 cartes, la 5e est au minimum rare
    - Chaque carte est ajoutée à la collection du joueur (+1 exemplaire)
    - Avec request_id : une requête rejouée renvoie le même booster (replayed = true)
    """
    if not request.request_id:
        return _open(request)

    # La même ouverture ne peut pas être exécutée deux fois (scope = joueur)
    scope = f"booster_open:{request.roblox_user_id}"
    with idempotency.request_lock(scope, request.request_id):
        previous = idempotency.get_result(scope, request.request_id)
        if previous:
            return {**previous, "replayed": True}
        response = _open(request)
        idempotency.save_result(scope, request.request_id, response)
        return response


def _open(request: OpenBoosterRequest) -> dict:
    dolibarr = _dolibarr()
    try:
        result = open_booster(dolibarr, request.roblox_user_id, request.booster_type, request.roblox_username)
    except BoosterError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Erreur lors de l'ouverture du booster : {e}")
    return {"success": True, "request_id": request.request_id, "replayed": False, **result}


@router.get("/{booster_type}/simulate")
def simulate_booster(booster_type: str, count: int = Query(1000, ge=1, le=100_000)):
    """
    Simule l'ouverture de N boosters (raretés seulement, RIEN n'est écrit en base)

    Permet de vérifier les taux réels : % de chaque rareté et rareté de la meilleure carte
    """
    try:
        get_booster(booster_type)
        return simulate(booster_type, count)
    except BoosterError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))


@players_router.get("/{roblox_user_id}/collection")
def player_collection(roblox_user_id: int):
    """Collection d'un joueur : cartes possédées et nombre d'exemplaires (de la plus rare à la moins rare)"""
    dolibarr = _dolibarr()
    try:
        player = find_player(dolibarr, roblox_user_id)
        if not player:
            raise HTTPException(status_code=404, detail=f"Aucun joueur Roblox {roblox_user_id} (il n'a encore ouvert aucun booster)")
        return {"success": True, **get_collection(dolibarr, player)}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Erreur lors de la lecture de la collection : {e}")
