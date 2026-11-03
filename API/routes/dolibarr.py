"""
Routes pour l'intégration Dolibarr ERP
"""
from fastapi import APIRouter, HTTPException, Depends
import time
import os

from security import require_admin_key
from services.dolibarr_service import DolibarrService
from services.wikipedia_service import CardService
from services.card_registry import register_card, product_ref_for
from models.card import CardData

router = APIRouter(prefix="/api/dolibarr", tags=["dolibarr"], dependencies=[Depends(require_admin_key)])


def get_dolibarr_service():
    """Dépendance pour le service Dolibarr"""
    try:
        return DolibarrService()
    except ValueError as e:
        raise HTTPException(status_code=503, detail=str(e))


def get_card_service():
    """Dépendance pour le service cartes"""
    return CardService()


@router.get("/card/{page_id}/metadata")
async def get_card_metadata(
    page_id: int,
    dolibarr_service: DolibarrService = Depends(get_dolibarr_service)
):
    """
    Récupère les métadonnées WikiCards d'une carte via son page_id Wikipédia

    Args:
        page_id: ID Wikipédia de la carte (ex: 6678 pour "Cat")
    """
    try:
        product_ref = product_ref_for(page_id)
        product = dolibarr_service.get_product_by_ref(product_ref)

        if not product:
            # Fallback : champ personnalisé wikipedia_page_id
            products = dolibarr_service.search_products_by_custom_field("wikipedia_page_id", str(page_id))
            if not products:
                raise HTTPException(status_code=404, detail=f"Aucune carte trouvée avec page_id {page_id}")
            product = products[0]

        product_id = product.get("id")
        metadata = dolibarr_service.get_wikicards_metadata(product_id)
        if not metadata:
            raise HTTPException(
                status_code=404,
                detail=f"Carte trouvée mais métadonnées manquantes pour page_id {page_id}"
            )

        return {
            "success": True,
            "page_id": page_id,
            "product_id": product_id,
            "product_ref": product.get("ref"),
            "metadata": metadata,
            "message": f"Métadonnées récupérées avec succès (produit ID: {product_id})"
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur lors de la récupération des métadonnées: {str(e)}")


@router.post("/register-card")
async def register_card_in_dolibarr(
    card_data: CardData,
    dolibarr_service: DolibarrService = Depends(get_dolibarr_service)
):
    """
    Enregistre une carte Wikipédia comme produit dans Dolibarr

    - Ne crée jamais de doublon (référence WIKI_<page_id>)
    - Prix selon la rareté, champs personnalisés, catégorie WikiCards
    """
    start_time = time.time()
    try:
        result = register_card(card_data, dolibarr_service)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur lors de l'enregistrement dans Dolibarr: {str(e)}")

    created = result["action"] == "created"
    return {
        "success": True,
        **result,
        "message": "Nouveau produit créé dans Dolibarr" if created else "Produit déjà existant dans Dolibarr",
        "performance": {"response_time_ms": round((time.time() - start_time) * 1000, 2)}
    }


@router.get("/check-card/{page_id}")
async def check_card_exists_in_dolibarr(
    page_id: int,
    dolibarr_service: DolibarrService = Depends(get_dolibarr_service)
):
    """Vérifie si une carte existe déjà dans Dolibarr"""
    try:
        product_ref = product_ref_for(page_id)
        exact_product = dolibarr_service.get_product_by_ref(product_ref)

        if exact_product:
            return {
                "exists": True,
                "match_type": "exact_ref",
                "page_id": page_id,
                "product_ref": product_ref,
                "details": {
                    "id": exact_product.get("id"),
                    "ref": exact_product.get("ref"),
                    "label": exact_product.get("label"),
                    "price": exact_product.get("price"),
                    "stock": exact_product.get("stock_reel"),
                    "rarity": (exact_product.get("array_options") or {}).get("options_wikicards_rarity"),
                },
                "message": f"Carte trouvée (ID: {exact_product.get('id')})"
            }

        products = dolibarr_service.search_products_by_custom_field("wikipedia_page_id", str(page_id))
        if products:
            return {
                "exists": True,
                "match_type": "custom_field",
                "page_id": page_id,
                "product_ref": product_ref,
                "products_found": len(products),
                "products": [{"id": p.get("id"), "ref": p.get("ref"), "label": p.get("label")} for p in products[:3]],
                "message": f"Carte trouvée via champ personnalisé ({len(products)} produits)"
            }

        return {
            "exists": False,
            "match_type": "none",
            "page_id": page_id,
            "product_ref": product_ref,
            "message": f"Carte non trouvée dans Dolibarr (réf: {product_ref})"
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur lors de la vérification: {str(e)}")


@router.get("/auto-random")
async def generate_and_register_random_card(
    dolibarr_service: DolibarrService = Depends(get_dolibarr_service),
    card_service: CardService = Depends(get_card_service)
):
    """Génère une carte aléatoire ET l'enregistre dans Dolibarr"""
    start_time = time.time()

    card_result = card_service.generate_random_card()
    if not card_result:
        raise HTTPException(status_code=503, detail="Impossible de générer une carte")

    try:
        result = register_card(CardData(**card_result["card"]), dolibarr_service)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur lors de la génération automatique: {str(e)}")

    return {
        "success": True,
        "card": card_result["card"],
        "game_ready": card_result["game_ready"],
        "dolibarr_integration": result,
        "performance": {"total_time_ms": round((time.time() - start_time) * 1000, 2)},
        "message": "Carte générée et enregistrée dans Dolibarr"
    }


@router.get("/products/stats")
async def get_dolibarr_products_stats(
    dolibarr_service: DolibarrService = Depends(get_dolibarr_service)
):
    """Statistiques sur les produits WikiCards dans Dolibarr"""
    try:
        return {
            "success": True,
            "stats": dolibarr_service.get_wikicards_stats(),
            "message": "Statistiques des produits WikiCards dans Dolibarr"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur lors de la récupération des statistiques: {str(e)}")


@router.get("/test-connection")
async def test_dolibarr_connection(
    dolibarr_service: DolibarrService = Depends(get_dolibarr_service)
):
    """Test de connexion à l'API Dolibarr"""
    success, details = dolibarr_service.test_connection()
    return {
        "success": success,
        "details": details,
        "message": "Test de connexion à Dolibarr" if success else "Échec de connexion à Dolibarr"
    }


@router.get("/config")
async def get_dolibarr_config():
    """Configuration Dolibarr (sans données sensibles)"""
    return {
        "dolibarr_url": os.getenv("DOLIBARR_URL"),
        "product_category": os.getenv("DOLIBARR_PRODUCT_CATEGORY"),
        "default_vat_rate": os.getenv("DOLIBARR_DEFAULT_VAT_RATE"),
        "api_key_configured": bool(os.getenv("DOLIBARR_API_KEY")) and
                              os.getenv("DOLIBARR_API_KEY") not in ["", "your_dolibarr_api_key_here"],
        "notes": [
            "La clé API est masquée pour des raisons de sécurité",
            "Configuration initiale (modules, clé API, catégorie, champs perso) : docker/setup-dolibarr.sh"
        ]
    }
