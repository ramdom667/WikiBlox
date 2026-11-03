"""
Service pour l'intégration avec Dolibarr ERP (API REST)
"""
import re
import requests
import os
import json
import random
from typing import Dict, Optional, List, Tuple, Set
from dotenv import load_dotenv

load_dotenv(override=True)

WIKI_REF_PATTERN = re.compile(r"^WIKI_(\d+)$")

PRICE_RANGES = {
    "common": (1.0, 5.0),
    "uncommon": (5.0, 15.0),
    "rare": (15.0, 50.0),
    "epic": (50.0, 200.0),
    "legendary": (200.0, 1000.0),
}


class DolibarrService:
    """Service pour interagir avec l'API Dolibarr"""

    def __init__(self):
        self.base_url = os.getenv("DOLIBARR_URL", "http://localhost:8080")
        self.api_url = f"{self.base_url}/api/index.php"
        self.api_key = os.getenv("DOLIBARR_API_KEY")
        self.product_category = os.getenv("DOLIBARR_PRODUCT_CATEGORY", "WikiCards")
        self.default_vat_rate = float(os.getenv("DOLIBARR_DEFAULT_VAT_RATE", 20.0))
        self._category_id: Optional[int] = None

        if not self.api_key or self.api_key == "your_dolibarr_api_key_here":
            raise ValueError("Clé API Dolibarr non configurée. Lancez docker/setup-dolibarr.sh ou vérifiez le fichier .env")

        self.headers = {
            "DOLAPIKEY": self.api_key,
            "Content-Type": "application/json",
            "Accept": "application/json"
        }

    # ------------------------------------------------------------------
    # Produits
    # ------------------------------------------------------------------

    def get_product_by_ref(self, product_ref: str) -> Optional[Dict]:
        """
        Récupère un produit par sa référence (ex: WIKI_6678)

        Returns:
            Données du produit ou None si non trouvé

        Raises:
            Exception si Dolibarr ne répond pas correctement (pour ne jamais
            conclure à tort qu'une carte n'existe pas)
        """
        response = requests.get(
            f"{self.api_url}/products/ref/{product_ref}",
            headers=self.headers,
            timeout=10
        )
        if response.status_code == 200:
            return response.json()
        if response.status_code == 404:
            return None
        raise Exception(f"Erreur recherche produit {product_ref}: {response.status_code} - {response.text[:200]}")

    def create_product(self, product_data: Dict) -> Dict:
        """
        Crée un nouveau produit dans Dolibarr

        Returns:
            {"id": <id>, "status": "created"}
        """
        product_data.setdefault("tva_tx", self.default_vat_rate)

        try:
            response = requests.post(
                f"{self.api_url}/products",
                headers=self.headers,
                json=product_data,
                timeout=15
            )
        except requests.exceptions.Timeout:
            raise Exception("Timeout lors de la création du produit")

        if response.status_code not in (200, 201):
            raise Exception(f"Erreur création produit: {response.status_code} - {response.text[:300]}")

        # Dolibarr répond avec l'ID numérique du produit créé
        response_text = response.text.strip().strip('"')
        if response_text.isdigit():
            return {"id": int(response_text), "status": "created"}
        try:
            return response.json()
        except Exception:
            return {"raw_response": response_text, "status": "created"}

    def search_products_by_custom_field(self, field_name: str, field_value: str) -> List[Dict]:
        """
        Recherche des produits par champ personnalisé (extrafield)

        Args:
            field_name: nom de l'extrafield sans préfixe (ex: "wikipedia_page_id")
        """
        if not re.fullmatch(r"[a-z0-9_]+", field_name):
            raise ValueError(f"Nom de champ invalide: {field_name}")
        value = str(field_value).replace("'", "")
        return self._list_products(f"(ef.{field_name}:=:'{value}')", limit=100)

    def _list_products(self, sqlfilters: str, limit: int = 500, properties: Optional[str] = None,
                       max_pages: int = 1) -> List[Dict]:
        """Liste paginée de produits filtrée (404 Dolibarr = liste vide)"""
        products: List[Dict] = []
        for page in range(max_pages):
            params = {"sqlfilters": sqlfilters, "limit": limit, "page": page, "sortfield": "t.rowid"}
            if properties:
                params["properties"] = properties
            response = requests.get(f"{self.api_url}/products", headers=self.headers, params=params, timeout=20)
            if response.status_code == 404:
                break
            if response.status_code != 200:
                raise Exception(f"Erreur liste produits: {response.status_code} - {response.text[:200]}")
            batch = response.json()
            if not isinstance(batch, list) or not batch:
                break
            products.extend(batch)
            if len(batch) < limit:
                break
        return products

    def list_wikicards(self, properties: Optional[str] = None) -> List[Dict]:
        """Tous les produits WikiCards (référence WIKI_<page_id>)"""
        products = self._list_products("(t.ref:like:'WIKI_%')", limit=500, properties=properties, max_pages=200)
        return [p for p in products if WIKI_REF_PATTERN.match(str(p.get("ref", "")))]

    def list_wikicard_page_ids(self) -> Set[int]:
        """page_id Wikipédia de toutes les cartes déjà en base (pour l'anti-doublon)"""
        return {
            int(WIKI_REF_PATTERN.match(p["ref"]).group(1))
            for p in self.list_wikicards(properties="id,ref")
        }

    def get_wikicards_stats(self) -> Dict:
        """Statistiques des cartes WikiCards par rareté"""
        wikicards = self.list_wikicards()
        by_rarity = {r: 0 for r in PRICE_RANGES}
        total_value = 0.0
        for product in wikicards:
            options = product.get("array_options") or {}
            rarity = options.get("options_wikicards_rarity") or "unknown"
            by_rarity[rarity] = by_rarity.get(rarity, 0) + 1
            try:
                total_value += float(product.get("price") or 0)
            except (TypeError, ValueError):
                pass

        total = len(wikicards)
        return {
            "total_wikicards": total,
            "by_rarity": by_rarity,
            "total_value": round(total_value, 2),
            "average_price": round(total_value / total, 2) if total else 0,
        }

    # ------------------------------------------------------------------
    # Catégorie
    # ------------------------------------------------------------------

    def get_category_id(self) -> Optional[int]:
        """ID de la catégorie produit WikiCards (mis en cache)"""
        if self._category_id is None:
            response = requests.get(
                f"{self.api_url}/categories",
                headers=self.headers,
                params={"type": "product", "limit": 500},
                timeout=10
            )
            if response.status_code == 200:
                for cat in response.json():
                    if cat.get("label") == self.product_category:
                        self._category_id = int(cat["id"])
                        break
        return self._category_id

    def add_product_to_category(self, product_id: int) -> bool:
        """Range un produit dans la catégorie WikiCards"""
        category_id = self.get_category_id()
        if not category_id:
            return False
        response = requests.post(
            f"{self.api_url}/categories/{category_id}/objects/product/{product_id}",
            headers=self.headers,
            timeout=10
        )
        return response.status_code == 200

    # ------------------------------------------------------------------
    # Joueurs (tiers) et collections (entrepôts / stock)
    # ------------------------------------------------------------------

    def find_thirdparty_by_roblox_id(self, roblox_user_id: str) -> Optional[Dict]:
        """Tiers (joueur) lié à un identifiant Roblox, ou None"""
        uid = str(roblox_user_id).replace("'", "")
        response = requests.get(
            f"{self.api_url}/thirdparties",
            headers=self.headers,
            params={"sqlfilters": f"(ef.roblox_user_id:=:'{uid}')", "limit": 1},
            timeout=10
        )
        if response.status_code == 404:
            return None
        if response.status_code != 200:
            raise Exception(f"Erreur recherche joueur: {response.status_code} - {response.text[:200]}")
        results = response.json()
        return results[0] if results else None

    def create_thirdparty(self, thirdparty_data: Dict) -> int:
        """Crée un tiers (client) et renvoie son ID"""
        response = requests.post(f"{self.api_url}/thirdparties", headers=self.headers, json=thirdparty_data, timeout=10)
        if response.status_code not in (200, 201):
            raise Exception(f"Erreur création tiers: {response.status_code} - {response.text[:300]}")
        return int(response.text.strip().strip('"'))

    def find_warehouse_by_ref(self, ref: str) -> Optional[Dict]:
        """Entrepôt par référence, ou None"""
        safe_ref = ref.replace("'", "")
        response = requests.get(
            f"{self.api_url}/warehouses",
            headers=self.headers,
            params={"sqlfilters": f"(t.ref:=:'{safe_ref}')", "limit": 1},
            timeout=10
        )
        if response.status_code == 404:
            return None
        if response.status_code != 200:
            raise Exception(f"Erreur recherche entrepôt: {response.status_code} - {response.text[:200]}")
        results = response.json()
        return results[0] if results else None

    def create_warehouse(self, ref: str, description: str) -> int:
        """Crée un entrepôt et renvoie son ID"""
        response = requests.post(
            f"{self.api_url}/warehouses",
            headers=self.headers,
            json={"label": ref, "description": description, "statut": 1},
            timeout=10
        )
        if response.status_code not in (200, 201):
            raise Exception(f"Erreur création entrepôt: {response.status_code} - {response.text[:300]}")
        return int(response.text.strip().strip('"'))

    def add_stock_movement(self, product_id: int, warehouse_id: int, qty: int, label: str) -> int:
        """Mouvement de stock (+qty / -qty) d'un produit dans un entrepôt"""
        response = requests.post(
            f"{self.api_url}/stockmovements",
            headers=self.headers,
            json={"product_id": int(product_id), "warehouse_id": int(warehouse_id), "qty": qty, "movementlabel": label},
            timeout=10
        )
        if response.status_code not in (200, 201):
            raise Exception(f"Erreur mouvement de stock: {response.status_code} - {response.text[:300]}")
        return int(response.text.strip().strip('"'))

    def get_warehouse_stock(self, warehouse_id: int) -> Dict[int, Dict]:
        """
        Contenu d'un entrepôt : {product_id: {"qty": quantité DANS cet entrepôt, "product": produit}}
        (seules les quantités > 0 sont renvoyées)
        """
        contents: Dict[int, Dict] = {}
        limit = 500
        for page in range(100):
            response = requests.get(
                f"{self.api_url}/warehouses/{warehouse_id}/products",
                headers=self.headers,
                params={"includestockdata": 1, "limit": limit, "page": page},
                timeout=30
            )
            if response.status_code == 404:
                break
            if response.status_code != 200:
                raise Exception(f"Erreur lecture entrepôt: {response.status_code} - {response.text[:200]}")
            batch = response.json()
            if not isinstance(batch, list) or not batch:
                break
            for product in batch:
                # stock_reel = stock global du produit ; stock_warehouse = détail par entrepôt
                per_warehouse = product.get("stock_warehouse") or {}
                entry = per_warehouse.get(str(warehouse_id)) if isinstance(per_warehouse, dict) else None
                qty = int(float(entry.get("real") or 0)) if entry else 0
                if qty > 0:
                    contents[int(product["id"])] = {"qty": qty, "product": product}
            if len(batch) < limit:
                break
        return contents

    # ------------------------------------------------------------------
    # Divers
    # ------------------------------------------------------------------

    def calculate_price_by_rarity(self, rarity: str) -> float:
        """
        Prix d'une carte selon sa rareté

        Common: 1-5€ | Uncommon: 5-15€ | Rare: 15-50€ | Epic: 50-200€ | Legendary: 200-1000€
        """
        min_price, max_price = PRICE_RANGES.get(rarity, PRICE_RANGES["common"])
        return round(random.uniform(min_price, max_price), 2)

    def test_connection(self) -> Tuple[bool, Dict]:
        """Teste la connexion à l'API Dolibarr"""
        try:
            response = requests.get(f"{self.api_url}/status", headers=self.headers, timeout=5)

            if response.status_code == 200:
                return True, {
                    "status_code": response.status_code,
                    "response": response.json(),
                    "message": "Connexion API Dolibarr réussie"
                }
            return False, {
                "status_code": response.status_code,
                "response": response.text,
                "message": f"Erreur API: {response.status_code}"
            }

        except requests.exceptions.ConnectionError:
            return False, {"message": "Impossible de se connecter à Dolibarr. Vérifiez l'URL et que le service tourne."}
        except requests.exceptions.Timeout:
            return False, {"message": "Timeout lors de la connexion à Dolibarr"}
        except Exception as e:
            return False, {"message": f"Erreur inconnue: {str(e)}"}

    def get_wikicards_metadata(self, product_id: int) -> Optional[Dict]:
        """
        Récupère les métadonnées WikiCards d'un produit

        Ordre : JSON de note_private, sinon reconstruction depuis array_options
        """
        try:
            response = requests.get(f"{self.api_url}/products/{product_id}", headers=self.headers, timeout=10)
            if response.status_code != 200:
                return None

            product = response.json()

            note_private = product.get("note_private")
            if note_private:
                try:
                    metadata = json.loads(note_private)
                    if metadata.get("wikicards_version"):
                        return metadata
                except json.JSONDecodeError:
                    pass

            metadata = {
                "wikicards_version": "0.9",
                "reconstructed_from": "array_options",
                "wikipedia": {
                    "page_id": None,
                    "title": self._extract_title_from_label(product.get("label", ""))
                },
                "statistics": {"rarity": None, "total_views": None}
            }

            array_options = product.get("array_options")
            if isinstance(array_options, dict):
                if array_options.get("options_wikipedia_page_id"):
                    metadata["wikipedia"]["page_id"] = array_options["options_wikipedia_page_id"]
                if array_options.get("options_wikicards_rarity"):
                    metadata["statistics"]["rarity"] = array_options["options_wikicards_rarity"]
                if array_options.get("options_wikicards_total_views"):
                    metadata["statistics"]["total_views"] = array_options["options_wikicards_total_views"]
                if array_options.get("options_wikipedia_title"):
                    metadata["wikipedia"]["title"] = array_options["options_wikipedia_title"]

            return metadata

        except Exception:
            return None

    def _extract_title_from_label(self, label: str) -> str:
        """Extrait le titre Wikipédia du label (format: 'Titre - Carte Wikipédia')"""
        return label.replace(" - Carte Wikipédia", "")
