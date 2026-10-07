"""
Service pour interagir avec l'API Wikipédi
"""
import requests
import urllib.parse
import time
from typing import Dict, Optional, Tuple, List
import os
from datetime import datetime, timedelta

from models.card import WikipediaArticle


class WikipediaService:
    """Service pour les appels API Wikipédia"""
    
    def __init__(self):
        self.rest_base_url = "https://en.wikipedia.org/api/rest_v1"
        self.pageviews_base_url = "https://wikimedia.org/api/rest_v1/metrics/pageviews"
        self.headers = {
            "User-Agent": os.getenv("WIKIPEDIA_USER_AGENT", "WikiCards-IAMSI (contact@example.com)")
        }
        self.last_request_time = 0
        self.rate_limit = int(os.getenv("WIKIPEDIA_RATE_LIMIT", "1"))
        
    def _rate_limit(self, delay: float = None):
        """Respect du rate limiting"""
        current_time = time.time()
        
        if delay:
            sleep_time = delay
        else:
            sleep_time = max(0, (1.0 / self.rate_limit) - (current_time - self.last_request_time))
        
        if sleep_time > 0:
            time.sleep(sleep_time)
        
        self.last_request_time = time.time()
    
    def get_article_by_title(self, title: str) -> Optional[WikipediaArticle]:
        """Récupère un article par titre"""
        try:
            self._rate_limit()
            
            encoded_title = urllib.parse.quote(title.replace(" ", "_"))
            url = f"{self.rest_base_url}/page/summary/{encoded_title}"
            
            response = requests.get(url, headers=self.headers, timeout=8)
            
            if response.status_code == 200:
                data = response.json()
                return WikipediaArticle(**data)
            elif response.status_code == 404:
                return None
            elif response.status_code == 429:
                self._rate_limit(delay=2.0)
                return None
            else:
                return None
                
        except (requests.exceptions.Timeout, requests.exceptions.RequestException):
            return None
        except Exception:
            return None
    
    def get_random_article(self) -> Optional[WikipediaArticle]:
        """Récupère un article aléatoire"""
        try:
            self._rate_limit()
            
            response = requests.get(
                f"{self.rest_base_url}/page/random/summary",
                headers=self.headers,
                timeout=8
            )
            
            if response.status_code == 200:
                data = response.json()
                return WikipediaArticle(**data)
            elif response.status_code == 429:
                self._rate_limit(delay=2.0)
                return None
            else:
                return None
                
        except (requests.exceptions.Timeout, requests.exceptions.RequestException):
            return None
        except Exception:
            return None
    
    def get_last_three_months_views(self, article_title: str) -> Tuple[Dict[str, int], int, float]:
        """
        Récupère les vues des 3 derniers mois complets
        
        Exemple: Si aujourd'hui = Oct 2026, retourne:
        - Juillet 2024
        - Août 2024  
        - Septembre 2024
        
        Returns:
            (monthly_views, total_views, average_views)
        """
        try:
            self._rate_limit()
            
            encoded_title = urllib.parse.quote(article_title.replace(" ", "_"))
            
            # 3 derniers mois complets disponibles
            months = self._get_last_three_complete_months()
            monthly_views = {}
            
            for year, month in months:
                month_str = f"{year}-{month:02d}"
                start_date = f"{year}{month:02d}01"
                end_date = f"{year}{month:02d}30"  # 30 jours pour tous les mois
                
                # Déterminer le vrai dernier jour du mois
                if month in [1, 3, 5, 7, 8, 10, 12]:
                    end_date = f"{year}{month:02d}31"
                elif month in [4, 6, 9, 11]:
                    end_date = f"{year}{month:02d}30"
                elif month == 2:
                    # Février : 28 ou 29 jours
                    end_date = f"{year}{month:02d}28"
                
                url = (
                    f"{self.pageviews_base_url}/per-article/"
                    f"en.wikipedia/all-access/user/"
                    f"{encoded_title}/monthly/{start_date}/{end_date}"
                )
                
                try:
                    response = requests.get(url, headers=self.headers, timeout=10)
                    
                    if response.status_code == 200:
                        data = response.json()
                        if "items" in data and len(data["items"]) > 0:
                            views = data["items"][0].get("views", 0)
                            monthly_views[month_str] = views
                            print(f"✅ {month_str}: {views:,} vues")
                        else:
                            monthly_views[month_str] = 0
                            print(f"⚠️  {month_str}: Pas d'items dans la réponse")
                    else:
                        monthly_views[month_str] = 0
                        print(f"❌ {month_str}: Erreur HTTP {response.status_code}")
                        
                except Exception as e:
                    monthly_views[month_str] = 0
                    print(f"💥 {month_str}: Exception {str(e)[:50]}")
                
                # Petite pause entre chaque mois
                time.sleep(0.1)
            
            # Calculs
            total_views = sum(monthly_views.values())
            average_views = total_views / len(monthly_views) if monthly_views else 0
            
            return monthly_views, total_views, round(average_views, 2)
            
        except Exception:
            # Retourner des données par défaut en cas d'erreur
            months = self._get_last_three_complete_months()
            default_views = {f"{year}-{month:02d}": 0 for year, month in months}
            return default_views, 0, 0
    
    def _get_last_three_complete_months(self) -> List[Tuple[int, int]]:
        """
        Retourne les 3 derniers mois complets disponibles
        
        Pour éviter les mois futurs, on fixe septembre 2024 comme dernier mois
        """
        # Fixé à 2024 pour avoir des données complètes
        BASE_YEAR = 2024
        BASE_MONTH = 9  # Septembre
        
        months = []
        for i in range(3):
            # Recule de i mois depuis septembre 2024
            target_month = BASE_MONTH - i
            target_year = BASE_YEAR
            
            if target_month <= 0:
                target_month += 12
                target_year -= 1
            
            months.append((target_year, target_month))
        
        # Inverser pour avoir du plus ancien au plus récent
        return list(reversed(months))
    
    def calculate_rarity(self, total_views: int, timeframe_months: int = 3) -> Tuple[str, str]:
        """
        Calcule la rareté basée sur le TOTAL des 3 derniers mois
        
        Common: < 1,000 vues/3 mois
        Uncommon: 1,000 - 10,000 vues/3 mois
        Rare: 10,000 - 100,000 vues/3 mois  
        Epic: 100,000 - 1,000,000 vues/3 mois
        Legendary: > 1,000,000 vues/3 mois
        """
        if total_views < 1000:
            return "common", "⚪"
        elif total_views < 10000:
            return "uncommon", "🟢"
        elif total_views < 100000:
            return "rare", "🔵"
        elif total_views < 1000000:
            return "epic", "🟣"
        else:
            return "legendary", "🟡"


class CardService:
    """Service pour la logique métier des cartes"""
    
    def __init__(self):
        self.wikipedia_service = WikipediaService()
    
    def generate_random_card(self) -> Optional[Dict]:
        """Génère une carte aléatoire complète"""
        # 1. Récupérer article aléatoire
        article = self.wikipedia_service.get_random_article()
        if not article:
            return None
        
        return self._build_card_from_article(article)
    
    def get_card_by_title(self, title: str) -> Optional[Dict]:
        """Récupère une carte par titre"""
        # 1. Récupérer article par titre
        article = self.wikipedia_service.get_article_by_title(title)
        if not article:
            return None
        
        return self._build_card_from_article(article)
    
    def _build_card_from_article(self, article: WikipediaArticle) -> Dict:
        """Construit une carte complète depuis un article"""
        # 2. Récupérer les vues des 3 derniers mois
        monthly_views, total_views, avg_views = self.wikipedia_service.get_last_three_months_views(
            article.title
        )
        
        # 3. Calculer la rareté (basée sur le TOTAL des 3 mois)
        rarity, rarity_emoji = self.wikipedia_service.calculate_rarity(total_views)
        
        # 4. Construire la réponse
        card_data = {
            "page_id": article.pageid,
            "title": article.title,
            "short_description": article.description or article.extract[:100],
            "description": article.extract[:300],
            "image_url": article.thumbnail.get("source") if article.thumbnail else None,
            "original_image_url": article.originalimage.get("source") if article.originalimage else None,
            "page_url": article.content_urls.get("desktop", {}).get("page") if article.content_urls else None,
            "wikidata_id": article.wikidata_item,
            "generated_at": datetime.now().isoformat(),
            
            # Données de rareté (3 mois)
            "monthly_views": monthly_views,
            "total_views": total_views,
            "average_views": avg_views,
            "reference_months": list(monthly_views.keys()),
            "rarity": rarity,
            "rarity_emoji": rarity_emoji
        }
        
        # 5. Version jeu
        game_ready = {
            "card_id": f"WIKI_{article.pageid}_{list(monthly_views.keys())[-1]}",  # Dernier mois
            "name": article.title,
            "description": article.description or article.extract[:100],
            "image": article.originalimage.get("source") if article.originalimage else article.thumbnail.get("source"),
            "rarity": rarity,
            "rarity_display": f"{rarity_emoji} {rarity.upper()}",
            "total_views": total_views,
            "monthly_breakdown": monthly_views
        }
        
        return {
            "card": card_data,
            "game_ready": game_ready
        }