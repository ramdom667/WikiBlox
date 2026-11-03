"""
Enregistrement d'une carte Wikipédia comme produit Dolibarr (logique partagée)

Utilisé par /api/dolibarr/register-card, /api/dolibarr/auto-random et le chargement du catalogue.
"""
import json
import os
from datetime import datetime
from typing import Dict

from models.card import CardData
from services.dolibarr_service import DolibarrService


def product_ref_for(page_id: int) -> str:
    """Référence unique d'une carte : une page Wikipédia = un produit"""
    return f"WIKI_{page_id}"


def build_wikicards_metadata(card: CardData, price: float) -> str:
    """Métadonnées complètes (JSON) stockées dans note_private"""
    metadata = {
        "wikicards_version": "1.0",
        "generated_at": datetime.now().isoformat(),
        "wikipedia": {
            "page_id": card.page_id,
            "title": card.title,
            "short_description": card.short_description,
            "full_description": card.description,
            "page_url": card.page_url,
            "wikidata_id": card.wikidata_id,
            "image_url": card.image_url,
            "original_image_url": card.original_image_url
        },
        "statistics": {
            "monthly_views": dict(card.monthly_views),
            "total_views": card.total_views,
            "average_views": card.average_views,
            "reference_months": card.reference_months,
            "rarity": card.rarity,
        },
        "dolibarr_integration": {
            "product_ref": product_ref_for(card.page_id),
            "price": price,
            "category": os.getenv("DOLIBARR_PRODUCT_CATEGORY", "WikiCards")
        }
    }
    return json.dumps(metadata, indent=2, ensure_ascii=False)


def build_product_data(card: CardData, price: float) -> Dict:
    """Payload de création du produit Dolibarr"""
    description = card.short_description or ""
    if card.description:
        description += f"\n\n{card.description[:200]}..."

    return {
        "ref": product_ref_for(card.page_id),
        "label": f"{card.title} - Carte Wikipédia",
        "description": description,
        "type": 0,        # 0 = Produit
        "status": 1,      # En vente
        "status_buy": 0,  # Pas en achat
        "price": price,
        "cost_price": round(price * 0.3, 2),
        "weight": 0.01,
        "weight_units": 0,  # kg
        "url": card.page_url,
        # Champs personnalisés (extrafields créés par docker/setup-dolibarr.php)
        "array_options": {
            "options_wikipedia_page_id": card.page_id,
            "options_wikipedia_title": card.title[:255],
            "options_wikicards_rarity": card.rarity,
            "options_wikicards_total_views": int(card.total_views),
            "options_wikicards_average_views": float(card.average_views),
            "options_wikicards_reference_months": ",".join(card.reference_months)
        },
        "note_private": build_wikicards_metadata(card, price)
    }


def register_card(card: CardData, dolibarr: DolibarrService) -> Dict:
    """
    Enregistre une carte dans Dolibarr si elle n'existe pas déjà

    Returns:
        {"action": "created" | "already_exists", "product_id", "product_ref", "price", ...}
    """
    product_ref = product_ref_for(card.page_id)

    # Anti-doublon : vérification juste avant la création
    existing = dolibarr.get_product_by_ref(product_ref)
    if existing:
        return {
            "action": "already_exists",
            "product_id": int(existing.get("id")),
            "product_ref": product_ref,
            "card_title": card.title,
            "rarity": card.rarity,
            "price": float(existing.get("price") or 0),
            "stock": existing.get("stock_reel"),
        }

    price = dolibarr.calculate_price_by_rarity(card.rarity)
    created = dolibarr.create_product(build_product_data(card, price))
    product_id = created.get("id")

    in_category = dolibarr.add_product_to_category(int(product_id)) if product_id else False

    return {
        "action": "created",
        "product_id": product_id,
        "product_ref": product_ref,
        "card_title": card.title,
        "rarity": card.rarity,
        "price": price,
        "in_category": in_category,
    }
