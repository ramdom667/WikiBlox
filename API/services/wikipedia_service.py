"""
Service pour interagir avec les APIs Wikipédia / Wikimedia
"""
import requests
import urllib.parse
import time
from typing import Dict, Optional, Tuple, List
import os
from datetime import datetime
from calendar import monthrange

from models.card import WikipediaArticle


# Seuils de rareté sur le TOTAL des vues de la période de référence (3 mois).
# (rareté, minimum inclus, maximum exclu, emoji)
RARITY_TIERS: List[Tuple[str, int, float, str]] = [
    ("common", 0, 1_000, "⚪"),
    ("uncommon", 1_000, 10_000, "🟢"),
    ("rare", 10_000, 100_000, "🔵"),
    ("epic", 100_000, 1_000_000, "🟣"),
    ("legendary", 1_000_000, float("inf"), "🟡"),
]
RARITIES: List[str] = [t[0] for t in RARITY_TIERS]


def rarity_bounds(rarity: str) -> Tuple[int, float]:
    """Bornes [min, max[ de vues (sur 3 mois) d'une rareté"""
    for name, lo, hi, _ in RARITY_TIERS:
        if name == rarity:
            return lo, hi
    raise ValueError(f"Rareté inconnue: {rarity}")


class WikipediaService:
    """Service pour les appels API Wikipédia"""

    def __init__(self):
        self.rest_base_url = "https://en.wikipedia.org/api/rest_v1"
        self.action_api_url = "https://en.wikipedia.org/w/api.php"
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

    @staticmethod
    def _encode_title(title: str) -> str:
        # safe="" : encode aussi les "/" (ex: "AC/DC")
        return urllib.parse.quote(title.replace(" ", "_"), safe="")

    # ------------------------------------------------------------------
    # Articles (REST API)
    # ------------------------------------------------------------------

    def get_article_by_title(self, title: str) -> Optional[WikipediaArticle]:
        """Récupère un article par titre"""
        try:
            self._rate_limit()

            url = f"{self.rest_base_url}/page/summary/{self._encode_title(title)}"
            response = requests.get(url, headers=self.headers, timeout=8)

            if response.status_code == 200:
                return WikipediaArticle(**response.json())
            elif response.status_code == 429:
                self._rate_limit(delay=2.0)
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
                return WikipediaArticle(**response.json())
            elif response.status_code == 429:
                self._rate_limit(delay=2.0)
            return None

        except Exception:
            return None

    # ------------------------------------------------------------------
    # Vues sur la période de référence (Pageviews API)
    # ------------------------------------------------------------------

    def get_last_three_months_views(self, article_title: str) -> Tuple[Dict[str, int], int, float]:
        """
        Récupère les vues des 3 mois de référence (0 partout en cas d'erreur)

        Returns:
            (monthly_views, total_views, average_views)
        """
        try:
            return self.fetch_reference_views(article_title)
        except Exception:
            months = self._get_last_three_complete_months()
            return {f"{y}-{m:02d}": 0 for y, m in months}, 0, 0

    def fetch_reference_views(self, article_title: str) -> Tuple[Dict[str, int], int, float]:
        """
        Vues des 3 mois de référence en UN seul appel (granularité mensuelle sur la plage)

        Raises:
            Exception si l'API ne répond pas correctement (≠ 200 / 404)
        """
        months = self._get_last_three_complete_months()
        monthly_views = {f"{y}-{m:02d}": 0 for y, m in months}

        (y0, m0), (y1, m1) = months[0], months[-1]
        start = f"{y0}{m0:02d}0100"
        end = f"{y1}{m1:02d}{monthrange(y1, m1)[1]:02d}00"

        url = (
            f"{self.pageviews_base_url}/per-article/en.wikipedia/all-access/user/"
            f"{self._encode_title(article_title)}/monthly/{start}/{end}"
        )

        for attempt in range(2):
            self._rate_limit()
            response = requests.get(url, headers=self.headers, timeout=10)
            if response.status_code == 429 and attempt == 0:
                self._rate_limit(delay=2.0)
                continue
            break

        if response.status_code == 200:
            for item in response.json().get("items", []):
                ts = item.get("timestamp", "")  # ex: 2024070100
                key = f"{ts[:4]}-{ts[4:6]}"
                if key in monthly_views:
                    monthly_views[key] = int(item.get("views", 0))
        elif response.status_code != 404:  # 404 = aucune vue enregistrée -> 0 partout
            raise Exception(f"Pageviews HTTP {response.status_code}")

        total_views = sum(monthly_views.values())
        average_views = total_views / len(monthly_views) if monthly_views else 0
        return monthly_views, total_views, round(average_views, 2)

    def _get_last_three_complete_months(self) -> List[Tuple[int, int]]:
        """
        Retourne les 3 mois de référence (du plus ancien au plus récent).

        Fixé à juillet-septembre 2024 : la rareté d'un article ne change donc jamais.
        """
        BASE_YEAR = 2024
        BASE_MONTH = 9  # Septembre

        months = []
        for i in range(3):
            target_month = BASE_MONTH - i
            target_year = BASE_YEAR
            if target_month <= 0:
                target_month += 12
                target_year -= 1
            months.append((target_year, target_month))

        return list(reversed(months))

    def calculate_rarity(self, total_views: int, timeframe_months: int = 3) -> Tuple[str, str]:
        """
        Calcule la rareté basée sur le TOTAL des 3 mois de référence

        Common: < 1,000 | Uncommon: 1,000 - 10,000 | Rare: 10,000 - 100,000
        Epic: 100,000 - 1,000,000 | Legendary: > 1,000,000
        """
        for name, lo, hi, emoji in RARITY_TIERS:
            if lo <= total_views < hi:
                return name, emoji
        return "common", "⚪"

    # ------------------------------------------------------------------
    # Sources de candidats (catalogue)
    # ------------------------------------------------------------------

    def get_top_articles(self, year: int, month: int) -> List[Tuple[str, int]]:
        """Top 1000 des pages les plus vues d'un mois (titres non filtrés : Main_Page, Special:...)"""
        url = f"{self.pageviews_base_url}/top/en.wikipedia/all-access/{year}/{month:02d}/all-days"
        try:
            self._rate_limit()
            response = requests.get(url, headers=self.headers, timeout=15)
            if response.status_code != 200:
                return []
            items = response.json().get("items", [])
            if not items:
                return []
            return [(a["article"], int(a.get("views", 0))) for a in items[0].get("articles", [])]
        except Exception:
            return []

    def _query_pages(self, params: Dict) -> List[Dict]:
        """
        Appel api.php avec prop=pageviews|pageprops, en suivant la continuation
        jusqu'à ce que le lot soit complet (batchcomplete).

        Returns:
            [{"page_id", "title", "recent_views" (60 jours), "disambiguation"}] (namespace 0 uniquement)
        """
        p = {
            "action": "query",
            "format": "json",
            "formatversion": 2,
            "redirects": 1,
            "prop": "pageviews|pageprops",
            "pvipdays": 60,
            "ppprop": "disambiguation",
            **params,
        }
        pages: Dict[int, Dict] = {}

        for _ in range(30):  # garde-fou
            self._rate_limit()
            try:
                response = requests.get(self.action_api_url, params=p, headers=self.headers, timeout=20)
            except Exception:
                break
            if response.status_code == 429:
                self._rate_limit(delay=2.0)
                continue
            if response.status_code != 200:
                break
            data = response.json()

            for pg in data.get("query", {}).get("pages", []):
                if pg.get("missing") or "pageid" not in pg or pg.get("ns") != 0:
                    continue
                entry = pages.setdefault(pg["pageid"], {
                    "page_id": pg["pageid"],
                    "title": pg["title"],
                    "recent_views": 0,
                    "disambiguation": False,
                })
                views = pg.get("pageviews") or {}
                entry["recent_views"] += sum(v for v in views.values() if v)
                if "disambiguation" in (pg.get("pageprops") or {}):
                    entry["disambiguation"] = True

            if "batchcomplete" in data or "continue" not in data:
                break
            p.update(data["continue"])

        return list(pages.values())

    def screen_titles(self, titles: List[str]) -> List[Dict]:
        """Tri en masse d'une liste de titres (50 par appel) : page_id + vues 60 jours"""
        results = []
        for i in range(0, len(titles), 50):
            results.extend(self._query_pages({"titles": "|".join(titles[i:i + 50])}))
        return results

    def screen_random(self, limit: int = 50) -> List[Dict]:
        """Lot d'articles aléatoires avec leurs vues 60 jours (1 lot = ~1-2 appels)"""
        return self._query_pages({"generator": "random", "grnnamespace": 0, "grnlimit": min(limit, 50)})

    def screen_links(self, title: str) -> List[Dict]:
        """Articles liés depuis une page (jusqu'à 500) avec leurs vues 60 jours"""
        return self._query_pages({
            "generator": "links",
            "titles": title,
            "gplnamespace": 0,
            "gpllimit": "max",
        })


class CardService:
    """Service pour la logique métier des cartes"""

    def __init__(self, wikipedia_service: Optional[WikipediaService] = None):
        self.wikipedia_service = wikipedia_service or WikipediaService()

    def generate_random_card(self) -> Optional[Dict]:
        """Génère une carte aléatoire complète"""
        article = self.wikipedia_service.get_random_article()
        if not article:
            return None
        return self._build_card_from_article(article)

    def get_card_by_title(self, title: str) -> Optional[Dict]:
        """Récupère une carte par titre"""
        article = self.wikipedia_service.get_article_by_title(title)
        if not article:
            return None
        return self._build_card_from_article(article)

    def _build_card_from_article(
        self,
        article: WikipediaArticle,
        views: Optional[Tuple[Dict[str, int], int, float]] = None
    ) -> Dict:
        """
        Construit une carte complète depuis un article

        Args:
            views: (monthly_views, total_views, average_views) déjà calculés (évite un appel)
        """
        if views is None:
            views = self.wikipedia_service.get_last_three_months_views(article.title)
        monthly_views, total_views, avg_views = views

        rarity, rarity_emoji = self.wikipedia_service.calculate_rarity(total_views)

        extract = article.extract or ""
        thumbnail = article.thumbnail.get("source") if article.thumbnail else None
        original = article.originalimage.get("source") if article.originalimage else None

        card_data = {
            "page_id": article.pageid,
            "title": article.title,
            "short_description": article.description or extract[:100],
            "description": extract[:300],
            "image_url": thumbnail,
            "original_image_url": original,
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

        game_ready = {
            "card_id": f"WIKI_{article.pageid}",
            "name": article.title,
            "description": article.description or extract[:100],
            "image": original or thumbnail,
            "rarity": rarity,
            "rarity_display": f"{rarity_emoji} {rarity.upper()}",
            "total_views": total_views,
            "monthly_breakdown": monthly_views
        }

        return {
            "card": card_data,
            "game_ready": game_ready
        }
