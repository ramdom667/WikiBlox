"""
Routes simples (sans rareté)
"""
from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
import time

from services.wikipedia_service import WikipediaService

router = APIRouter(prefix="/api/wikipedia", tags=["simple"])
wikipedia_service = WikipediaService()


@router.get("/random")
async def simple_random():
    """
    Tirage très simple sans rareté
    
    Rapide (< 500ms en moyenne)
    Parfait pour les tests
    """
    start_time = time.time()
    
    try:
        article = wikipedia_service.get_random_article()
        
        if not article:
            raise HTTPException(status_code=503, detail="Service Wikipédia indisponible")
        
        response_time = (time.time() - start_time) * 1000
        
        return {
            "success": True,
            "card": {
                "page_id": article.pageid,
                "title": article.title,
                "description": article.extract[:150] if article.extract else "",
                "image": article.thumbnail.get("source") if article.thumbnail else None,
                "url": article.content_urls.get("desktop", {}).get("page") if article.content_urls else None
            },
            "performance": {
                "response_time_ms": round(response_time, 2),
                "status": "very_fast" if response_time < 500 else "fast"
            },
            "message": "Carte simple générée"
        }
        
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur interne: {str(e)}")


@router.get("/title/{title}")
async def simple_by_title(title: str):
    """Recherche simple par titre sans rareté"""
    start_time = time.time()
    
    try:
        article = wikipedia_service.get_article_by_title(title)
        
        if not article:
            raise HTTPException(status_code=404, detail=f"Article non trouvé: '{title}'")
        
        response_time = (time.time() - start_time) * 1000
        
        return {
            "success": True,
            "card": {
                "page_id": article.pageid,
                "title": article.title,
                "description": article.extract[:200] if article.extract else "",
                "image": article.thumbnail.get("source") if article.thumbnail else None,
                "url": article.content_urls.get("desktop", {}).get("page") if article.content_urls else None
            },
            "performance": {
                "response_time_ms": round(response_time, 2)
            },
            "message": f"Article trouvé: {article.title}"
        }
        
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur interne: {str(e)}")