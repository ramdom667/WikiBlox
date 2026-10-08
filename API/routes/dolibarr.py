"""
Routes pour l'intégration Dolibarr ERP
"""
from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import JSONResponse
import time
import os
from typing import Dict, Optional

from services.dolibarr_service import DolibarrService
from services.wikipedia_service import CardService
from models.card import CardData

router = APIRouter(prefix="/api/dolibarr", tags=["dolibarr"])


def get_dolibarr_service():
    """Dépendance pour le service Dolibarr"""
    return DolibarrService()


def get_card_service():
    """Dépendance pour le service cartes"""
    return CardService()


def _build_wikicards_metadata(card_data) -> str:
    """
    Construit les métadonnées complètes au format JSON pour note_private
    
    Args:
        card_data: Données de la carte Wikipédia
        
    Returns:
        JSON string avec toutes les métadonnées
    """
    import json
    from datetime import datetime
    
    metadata = {
        "wikicards_version": "1.0",
        "generated_at": datetime.now().isoformat(),
        "wikipedia": {
            "page_id": card_data.page_id,
            "title": card_data.title,
            "short_description": card_data.short_description,
            "full_description": card_data.description,
            "page_url": card_data.page_url,
            "wikidata_id": card_data.wikidata_id,
            "image_url": card_data.image_url,
            "original_image_url": card_data.original_image_url
        },
        "statistics": {
            "monthly_views": dict(card_data.monthly_views),
            "total_views": card_data.total_views,
            "average_views": card_data.average_views,
            "reference_months": card_data.reference_months,
            "rarity": card_data.rarity,
            "rarity_text": card_data.rarity  # Pas d'emoji
        },
        "dolibarr_integration": {
            "product_ref": f"WIKI_{card_data.page_id}",
            "generated_price": card_data.total_views / 1000,  # Prix basé sur vues
            "category": os.getenv("DOLIBARR_PRODUCT_CATEGORY", "WikiCards")
        }
    }
    
    return json.dumps(metadata, indent=2, ensure_ascii=False)


@router.get("/card/{page_id}/metadata")
async def get_card_metadata(
    page_id: int,
    dolibarr_service: DolibarrService = Depends(get_dolibarr_service)
):
    """
    Récupère les métadonnées WikiCards d'une carte via son page_id Wikipédia
    
    Args:
        page_id: ID Wikipédia de la carte (ex: 6678 pour "Cat")
        
    Returns:
        Métadonnées complètes de la carte
    """
    try:
        # 1. Chercher le produit par référence
        product_ref = f"WIKI_{page_id}"
        product = dolibarr_service.get_product_by_ref(product_ref)
        
        if not product:
            # Fallback: chercher dans les champs personnalisés
            products = dolibarr_service.search_products_by_custom_field(
                "wikipedia_page_id", str(page_id)
            )
            
            if not products:
                raise HTTPException(
                    status_code=404,
                    detail=f"Aucune carte trouvée avec page_id {page_id}"
                )
            
            # Prendre le premier produit trouvé
            product = products[0]
        
        # 2. Extraire product_id
        product_id = product.get("id")
        if not product_id:
            raise HTTPException(
                status_code=404,
                detail=f"Produit trouvé mais sans ID pour page_id {page_id}"
            )
        
        # 3. Récupérer les métadonnées
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
        
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de la récupération des métadonnées: {str(e)}"
        )
    
    return json.dumps(metadata, indent=2, ensure_ascii=False)


@router.post("/register-card")
async def register_card_in_dolibarr(
    card_data: CardData,
    dolibarr_service: DolibarrService = Depends(get_dolibarr_service)
):
    """
    Enregistre une carte Wikipédia comme produit dans Dolibarr
    
    Args:
        card_data: Données complètes d'une carte (format CardData)
        
    Returns:
        Information sur le produit créé/mis à jour dans Dolibarr
        
    Notes:
        - Vérifie si le produit existe déjà (par page_id)
        - Crée un nouveau produit si non existant
        - Ne crée pas de doublon
        - Gère automatiquement les catégories et prix
    """
    start_time = time.time()
    
    try:
        # Générer la référence du produit (sans mois, UNIQUE par carte)
        product_ref = f"WIKI_{card_data.page_id}"
        
        # Vérifier si le produit existe déjà
        existing_product = dolibarr_service.get_product_by_ref(product_ref)
        
        if existing_product:
            response_time = (time.time() - start_time) * 1000
            
            return JSONResponse(content={
                "success": True,
                "action": "already_exists",
                "product_id": existing_product.get("id"),
                "product_ref": product_ref,
                "card_title": card_data.title,
                "rarity": card_data.rarity,
                "details": {
                    "message": f"Produit déjà existant dans Dolibarr",
                    "existing_ref": existing_product.get("ref"),
                    "price": existing_product.get("price"),
                    "stock": existing_product.get("stock_reel")
                },
                "performance": {
                    "response_time_ms": round(response_time, 2),
                    "api_calls": 1
                }
            })
        
        # Générer le prix basé sur la rareté
        price = dolibarr_service.calculate_price_by_rarity(card_data.rarity)
        
        # Créer le produit dans Dolibarr
        product_data = {
            "ref": product_ref,
            "label": f"{card_data.title} - Carte Wikipédia",
            "description": f"{card_data.short_description}\n\n{card_data.description[:200]}...",
            "type": 0,  # 0 = Produit, 1 = Service
            "status": 1,  # 1 = Actif
            "price": price,
            "cost_price": price * 0.3,  # Coût estimé à 30% du prix
            "vat_rate": float(os.getenv("DOLIBARR_DEFAULT_VAT_RATE", 20.0)),
            "weight": 0.01,  # Poids symbolique pour une carte
            "weight_units": -1,  # -1 = kilogramme
            "stock_warning": 100,  # Alerte si moins de 100 en stock
            "url": card_data.page_url,
            # Champs personnalisés Dolibarr (array_options)
            "array_options": {
                # Note: Les clés doivent correspondre à la config Dolibarr
                "options_wikipedia_page_id": card_data.page_id,
                "options_wikipedia_title": card_data.title[:64],  # Limité en longueur
                "options_wikicards_rarity": card_data.rarity,
                "options_wikicards_total_views": int(card_data.total_views),
                "options_wikicards_average_views": float(card_data.average_views),
                "options_wikicards_reference_months": ",".join(card_data.reference_months)
            },
            # Metadata complète dans note_private (JSON)
            "note_private": _build_wikicards_metadata(card_data)
        }
        
        # Vérifier s'il y a une image et l'ajouter
        if card_data.image_url:
            product_data["photo_url"] = card_data.image_url
        
        created_product = dolibarr_service.create_product(product_data)
        
        response_time = (time.time() - start_time) * 1000
        
        return JSONResponse(content={
            "success": True,
            "action": "created",
            "product_id": created_product.get("id"),
            "product_ref": product_ref,
            "card_title": card_data.title,
            "rarity": card_data.rarity,
            "price": price,
            "details": {
                "message": "Nouveau produit créé dans Dolibarr",
                "dolibarr_ref": created_product.get("ref"),
                "label": created_product.get("label"),
                "status": "Actif" if created_product.get("status") == 1 else "Inactif"
            },
            "performance": {
                "response_time_ms": round(response_time, 2),
                "api_calls": 2  # 1 pour vérifier + 1 pour créer
            }
        })
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de l'enregistrement dans Dolibarr: {str(e)}"
        )


@router.get("/check-card/{page_id}")
async def check_card_exists_in_dolibarr(
    page_id: int,
    dolibarr_service: DolibarrService = Depends(get_dolibarr_service)
):
    """
    Vérifie si une carte existe déjà dans Dolibarr
    
    Args:
        page_id: ID Wikipédia de la carte
        
    Returns:
        État de la carte dans Dolibarr
    """
    try:
        # Générer la référence UNIQUE (sans mois)
        product_ref = f"WIKI_{page_id}"
        
        # Chercher par référence exacte
        exact_product = dolibarr_service.get_product_by_ref(product_ref)
        
        if exact_product:
            return {
                "exists": True,
                "match_type": "exact_ref",
                "page_id": page_id,
                "product_ref": product_ref,
                "product": exact_product,
                "details": {
                    "id": exact_product.get("id"),
                    "ref": exact_product.get("ref"),
                    "label": exact_product.get("label"),
                    "price": exact_product.get("price"),
                    "stock": exact_product.get("stock_reel")
                },
                "message": f"Carte trouvée (ID: {exact_product.get('id')})"
            }
        
        # Chercher aussi dans les champs personnalisés Wikipedia (fallback)
        wikicards_products = dolibarr_service.search_products_by_custom_field(
            "wikipedia_page_id", str(page_id)
        )
        
        if wikicards_products:
            return {
                "exists": True,
                "match_type": "custom_field",
                "page_id": page_id,
                "product_ref": product_ref,
                "products_found": len(wikicards_products),
                "products": wikicards_products[:3],  # Limiter pour la réponse
                "message": f"Carte trouvée via champ personnalisé ({len(wikicards_products)} produits)"
            }
        
        return {
            "exists": False,
            "match_type": "none",
            "page_id": page_id,
            "product_ref": product_ref,
            "product": None,
            "products_found": 0,
            "message": f"Carte non trouvée dans Dolibarr (réf: {product_ref})"
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de la vérification: {str(e)}"
        )


@router.get("/auto-random")
async def generate_and_register_random_card(
    dolibarr_service: DolibarrService = Depends(get_dolibarr_service),
    card_service: CardService = Depends(get_card_service)
):
    """
    Génère une carte aléatoire ET l'enregistre dans Dolibarr
    
    Combinaison de /api/cards/random et /api/dolibarr/register-card
    
    Returns:
        Carte générée + résultat enregistrement Dolibarr
    """
    start_time = time.time()
    
    try:
        # 1. Générer une carte aléatoire
        print("🎴 Génération carte aléatoire...")
        card_result = card_service.generate_random_card()
        
        if not card_result:
            raise HTTPException(status_code=503, detail="Impossible de générer une carte")
        
        card_data_dict = card_result["card"]
        
        # Convertir dict en CardData model
        card_data = CardData(**card_data_dict)
        
        # 2. Enregistrer dans Dolibarr
        print("🏭 Enregistrement dans Dolibarr...")
        register_response = await register_card_in_dolibarr(card_data, dolibarr_service)
        
        total_time = (time.time() - start_time) * 1000
        
        response_data = register_response.body.decode() if hasattr(register_response, 'body') else {}
        
        return JSONResponse(content={
            "success": True,
            "card": card_data_dict,
            "game_ready": card_result["game_ready"],
            "dolibarr_integration": response_data,
            "performance": {
                "total_time_ms": round(total_time, 2),
                "steps": {
                    "card_generation_ms": round((total_time * 0.6), 2),  # Estimation
                    "dolibarr_integration_ms": round((total_time * 0.4), 2)
                },
                "description": "Toutes les étapes complétées avec succès"
            },
            "message": "Carte générée et enregistrée dans Dolibarr"
        })
        
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de la génération automatique: {str(e)}"
        )


@router.get("/products/stats")
async def get_dolibarr_products_stats(
    dolibarr_service: DolibarrService = Depends(get_dolibarr_service)
):
    """
    Statistiques sur les produits WikiCards dans Dolibarr
    """
    try:
        stats = dolibarr_service.get_wikicards_stats()
        
        return {
            "success": True,
            "stats": stats,
            "message": "Statistiques des produits WikiCards dans Dolibarr"
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de la récupération des statistiques: {str(e)}"
        )


@router.get("/test-connection")
async def test_dolibarr_connection(
    dolibarr_service: DolibarrService = Depends(get_dolibarr_service)
):
    """
    Test de connexion à l'API Dolibarr
    """
    try:
        success, details = dolibarr_service.test_connection()
        
        return {
            "success": success,
            "details": details,
            "message": "Test de connexion à Dolibarr" if success else "Échec de connexion à Dolibarr"
        }
        
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "message": "Exception lors du test de connexion"
        }


@router.get("/config")
async def get_dolibarr_config():
    """
    Configuration Dolibarr (sans données sensibles)
    """
    return {
        "dolibarr_url": os.getenv("DOLIBARR_URL"),
        "product_category": os.getenv("DOLIBARR_PRODUCT_CATEGORY"),
        "default_vat_rate": os.getenv("DOLIBARR_DEFAULT_VAT_RATE"),
        "api_key_configured": bool(os.getenv("DOLIBARR_API_KEY")) and 
                             os.getenv("DOLIBARR_API_KEY") not in ["", "your_dolibarr_api_key_here"],
        "notes": [
            "La clé API est masquée pour des raisons de sécurité",
            "URL par défaut: http://localhost:8080 pour Docker",
            "La catégorie 'WikiCards' sera créée automatiquement si elle n'existe pas"
        ]
    }