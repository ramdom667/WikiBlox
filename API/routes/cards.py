"""
Routes pour les cartes Wikipédi
"""
from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
import time

from services.wikipedia_service import CardService
from models.card import APIResponse

router = APIRouter(prefix="/api/cards", tags=["cartes"])
card_service = CardService()


@router.get("/random", response_model=APIResponse)
async def get_random_card():
    """
    Tirage d'une carte aléatoire
    
    - Article aléatoire Wikipédia
    - Vues des 3 derniers mois complets
    - Calcul de rareté basé sur la moyenne
    
    Returns:
        Carte complète avec statistiques
    """
    start_time = time.time()
    
    try:
        result = card_service.generate_random_card()
        
        if not result:
            raise HTTPException(status_code=503, detail="Service Wikipédia indisponible")
        
        response_time = (time.time() - start_time) * 1000
        
        response = {
            "success": True,
            "card": result["card"],
            "game_ready": result["game_ready"],
            "message": "Carte aléatoire générée avec succès",
            "metadata": {
                "response_time_ms": round(response_time, 2),
                "data_source": "Wikipedia REST API + Pageviews API",
                "rarity_basis": "Moyenne sur 3 derniers mois complets",
                "reference_months": result["card"]["reference_months"]
            }
        }
        
        return JSONResponse(content=response)
        
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur interne: {str(e)}")


@router.get("/title/{title}", response_model=APIResponse)
async def get_card_by_title(title: str):
    """
    Recherche une carte par titre Wikipédia
    
    Args:
        title: Titre exact de l'article (espaces → underscores _)
        
    Exemples:
        - /api/cards/title/Cat
        - /api/cards/title/Albert_Einstein
        - /api/cards/title/Quantum_mechanics
        
    Returns:
        Carte complète avec statistiques
    """
    start_time = time.time()
    
    try:
        result = card_service.get_card_by_title(title)
        
        if not result:
            raise HTTPException(
                status_code=404,
                detail=f"Article Wikipédia non trouvé: '{title}'. Vérifiez le titre."
            )
        
        response_time = (time.time() - start_time) * 1000
        
        response = {
            "success": True,
            "card": result["card"],
            "game_ready": result["game_ready"],
            "message": f"Carte trouvée: {result['card']['title']}",
            "metadata": {
                "response_time_ms": round(response_time, 2),
                "search_query": title,
                "data_source": "Wikipedia REST API + Pageviews API",
                "rarity_basis": "Moyenne sur 3 derniers mois complets",
                "reference_months": result["card"]["reference_months"]
            }
        }
        
        return JSONResponse(content=response)
        
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur interne: {str(e)}")


@router.get("/health")
async def cards_health():
    """Vérification santé du service cartes"""
    return {
        "status": "healthy",
        "service": "cards-api",
        "endpoints": {
            "random": "/api/cards/random",
            "search": "/api/cards/title/{title}"
        },
        "features": [
            "Wikipedia article fetching",
            "3-month pageviews statistics",
            "Rarity calculation",
            "Game-ready card formatting"
        ]
    }


@router.get("/examples")
async def examples():
    """Exemples de titres pour tester"""
    return {
        "popular_articles": [
            "Cat",
            "Dog", 
            "Paris",
            "Albert_Einstein",
            "Quantum_mechanics",
            "Python_(programming_language)",
            "French_Revolution",
            "Leonardo_da_Vinci",
            "Moon",
            "Internet"
        ],
        "how_to_use": [
            "GET /api/cards/random → Carte aléatoire",
            "GET /api/cards/title/Cat → Article sur les chats",
            "GET /api/cards/title/Paris → Article sur Paris"
        ],
        "notes": [
            "Utilisez des underscores (_) pour les espaces",
            "Les titres sont sensibles à la casse",
            "Les caractères spéciaux doivent être correctement encodés"
        ]
    }