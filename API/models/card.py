"""
Modèles de données pour les cartes Wikipédi
"""
from typing import Dict, Optional
from pydantic import BaseModel
from datetime import datetime


class WikipediaArticle(BaseModel):
    """Données brutes d'un article Wikipédia"""
    pageid: int
    title: str
    extract: Optional[str] = ""
    description: Optional[str] = ""
    thumbnail: Optional[Dict] = None
    originalimage: Optional[Dict] = None
    content_urls: Optional[Dict] = None
    wikidata_item: Optional[str] = None
    timestamp: Optional[str] = None


class CardData(BaseModel):
    """Carte complète avec données de rareté"""
    # Données Wikipédia
    page_id: int
    title: str
    short_description: str
    description: str
    image_url: Optional[str]
    original_image_url: Optional[str]
    page_url: Optional[str]
    
    # Métadonnées
    wikidata_id: Optional[str]
    generated_at: datetime
    
    # Données de rareté (3 mois)
    monthly_views: Dict[str, int]  # Ex: {"2024-07": 10000, "2024-08": 12000, "2024-09": 15000}
    total_views: int
    average_views: float
    reference_months: list[str]  # ["2024-07", "2024-08", "2024-09"]
    rarity: str
    rarity_emoji: str


class GameReadyCard(BaseModel):
    """Version simplifiée pour le jeu"""
    card_id: str
    name: str
    description: str
    image: Optional[str]
    rarity: str
    rarity_display: str
    total_views: int
    monthly_breakdown: Dict[str, int]


class APIResponse(BaseModel):
    """Réponse standard de l'API"""
    success: bool
    card: CardData
    game_ready: GameReadyCard
    message: str
    metadata: Optional[Dict] = {}