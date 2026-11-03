"""
Routes du catalogue : chargement de cartes en base Dolibarr par rareté
"""
from typing import Dict, Literal

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, field_validator

from services.catalog_loader import (
    MAX_COUNT_PER_RARITY, JobAlreadyRunning, get_job, list_jobs, start_load_job,
)
from security import require_admin_key
from services.dolibarr_service import DolibarrService

router = APIRouter(prefix="/api/catalog", tags=["catalogue"], dependencies=[Depends(require_admin_key)])

Rarity = Literal["common", "uncommon", "rare", "epic", "legendary"]


class LoadRequest(BaseModel):
    """Nombre de cartes à charger par rareté"""
    targets: Dict[Rarity, int] = Field(
        ...,
        description=f"Rareté -> nombre de nouvelles cartes à créer (1 à {MAX_COUNT_PER_RARITY})",
        examples=[{"epic": 10, "rare": 20, "common": 50}],
    )

    @field_validator("targets")
    @classmethod
    def check_targets(cls, targets: Dict[str, int]) -> Dict[str, int]:
        if not targets:
            raise ValueError("Indiquez au moins une rareté")
        for rarity, count in targets.items():
            if not 1 <= count <= MAX_COUNT_PER_RARITY:
                raise ValueError(f"{rarity} : le nombre doit être entre 1 et {MAX_COUNT_PER_RARITY}")
        return targets


@router.post("/load", status_code=202)
async def load_cards(request: LoadRequest):
    """
    Lance le chargement de nouvelles cartes dans Dolibarr

    - Une carte déjà présente en base n'est jamais recréée (référence WIKI_<page_id>)
    - Le chargement tourne en arrière-plan : suivre la progression avec GET /api/catalog/jobs/{job_id}
    - Un seul chargement à la fois

    Exemple : {"targets": {"epic": 10, "rare": 20, "common": 50}}
    """
    try:
        job = start_load_job(dict(request.targets))
    except JobAlreadyRunning as e:
        return JSONResponse(status_code=409, content={
            "success": False,
            "message": str(e),
            "running_job": e.job.to_dict(include_cards=False),
        })
    except ValueError as e:
        raise HTTPException(status_code=503, detail=str(e))

    return {
        "success": True,
        "job_id": job.id,
        "status": job.status,
        "targets": job.targets,
        "follow": f"/api/catalog/jobs/{job.id}",
        "message": "Chargement lancé en arrière-plan",
    }


@router.get("/jobs")
async def get_jobs():
    """Liste des chargements (du plus récent au plus ancien)"""
    return {"jobs": [j.to_dict(include_cards=False) for j in list_jobs()]}


@router.get("/jobs/{job_id}")
async def get_job_status(job_id: str):
    """Progression détaillée d'un chargement (+ cartes créées)"""
    job = get_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail=f"Chargement introuvable : {job_id}")
    return job.to_dict()


@router.post("/jobs/{job_id}/cancel")
async def cancel_job(job_id: str):
    """Demande l'arrêt d'un chargement (les cartes déjà créées sont conservées)"""
    job = get_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail=f"Chargement introuvable : {job_id}")
    if job.status not in ("pending", "running"):
        return {"success": False, "status": job.status, "message": "Ce chargement est déjà terminé"}
    job.cancel_requested = True
    return {"success": True, "status": job.status, "message": "Arrêt demandé"}


@router.get("/stats")
async def catalog_stats():
    """Nombre de cartes en base par rareté"""
    try:
        stats = DolibarrService().get_wikicards_stats()
    except ValueError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Erreur Dolibarr : {e}")
    return {"success": True, "stats": stats}
