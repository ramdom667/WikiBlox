"""
Récompenses des joueurs Roblox : donner une carte d'une rareté précise (pêche...)

Le jeu tire la rareté (avec les bonus de zone, canne, appât...), l'API pioche la carte
et l'ajoute à la collection. Même protection anti-doublon que les boosters (request_id).
"""
import math
import os
from typing import Literal, Optional

from fastapi import APIRouter, Depends, HTTPException, Path
from pydantic import BaseModel, Field

from security import require_game_key
from services import idempotency
from services.dolibarr_service import DolibarrService
from services.rate_limit import RateLimiter
from services.reward_service import SOURCES, RewardError, grant_card
from services.wikipedia_service import RARITIES

router = APIRouter(prefix="/api/players", tags=["joueurs"], dependencies=[Depends(require_game_key)])

# Nombre maximum de cartes données à un même joueur par minute (toutes sources confondues)
CARD_GRANT_MAX_PER_MINUTE = int(os.getenv("CARD_GRANT_MAX_PER_MINUTE", "15"))
_limiter = RateLimiter(CARD_GRANT_MAX_PER_MINUTE, 60)

RarityName = Literal[tuple(RARITIES)]
SourceName = Literal[tuple(SOURCES)]


def _dolibarr() -> DolibarrService:
    try:
        return DolibarrService()
    except ValueError as e:
        raise HTTPException(status_code=503, detail=str(e))


class GrantCardRequest(BaseModel):
    rarity: RarityName = Field(..., description="Rareté tirée par le jeu", examples=["common"])
    source: SourceName = Field(..., description="D'où vient la carte (libellé du mouvement de stock Dolibarr)", examples=["peche"])
    request_id: str = Field(
        ..., min_length=8, max_length=64, pattern=r"^[A-Za-z0-9_\-{}]+$",
        description="Identifiant unique de la récompense (GUID). Rejouer le même request_id renvoie la même carte sans en donner une autre.",
    )
    roblox_username: Optional[str] = Field(None, max_length=50, description="Pseudo Roblox (utilisé à la création du compte)")


@router.post("/{roblox_user_id}/cards")
def grant_card_route(request: GrantCardRequest, roblox_user_id: int = Path(..., gt=0, description="UserId Roblox du joueur")):
    """
    Donne une carte de la rareté demandée à un joueur (ex. carte pêchée)

    - Pioche une carte au hasard de cette rareté dans le catalogue, +1 exemplaire dans la collection
    - Crée automatiquement le compte client Dolibarr + la collection du joueur s'ils n'existent pas
    - request_id obligatoire : une requête rejouée renvoie la même carte (replayed = true)
    - Limite : CARD_GRANT_MAX_PER_MINUTE cartes par joueur et par minute (15 par défaut), sinon 429
    """
    scope = f"card_grant:{roblox_user_id}"
    with idempotency.request_lock(scope, request.request_id):
        previous = idempotency.get_result(scope, request.request_id)
        if previous:
            return {**previous, "replayed": True}

        allowed, retry_after = _limiter.allow(str(roblox_user_id))
        if not allowed:
            raise HTTPException(
                status_code=429,
                detail=f"Trop de cartes données à ce joueur, réessayer dans {math.ceil(retry_after)} s",
                headers={"Retry-After": str(math.ceil(retry_after))},
            )

        dolibarr = _dolibarr()
        try:
            result = grant_card(dolibarr, roblox_user_id, request.rarity, request.source, request.roblox_username)
        except RewardError as e:
            raise HTTPException(status_code=e.status_code, detail=str(e))
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"Erreur lors de l'ajout de la carte : {e}")

        response = {"success": True, "request_id": request.request_id, "replayed": False, **result}
        idempotency.save_result(scope, request.request_id, response)
        return response
