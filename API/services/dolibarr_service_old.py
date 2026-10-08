"""
Service pour l'intégration avec Dolibarr ERP
"""
import requests
import os
from typing import Dict, Optional, List, Tuple
from dotenv import load_dotenv

load_dotenv()


class DolibarrService:
    """Service pour interagir avec l'API Dolibarr"""
    
    def __init__(self):
        self.base_url = os.getenv("DOLIBARR_URL", "http://localhost:8080")
        self.api_key = os.getenv("DOLIBARR_API_KEY")
        self.product_category = os.getenv("DOLIBARR_PRODUCT_CATEGORY", "WikiCards")
        self.default_vat_rate = float(os.getenv("DOLIBARR_DEFAULT_VAT_RATE", 20.0))
        
        if not self.api_key or self.api_key == "your_dolibarr_api_key_here":
            raise ValueError("Clé API Dolibarr non configurée. Vérifiez le fichier .env")
        
        self.headers = {
            "DOLAPIKEY": self.api_key,
            "Content-Type": "application/json",
            "Accept": "application/json"
        }
        
        # Note: Catégorie doit être créée manuellement dans Dolibarr
        # L'utilisateur API n'a souvent pas les droits pour créer des catégories
        print(f"ℹ️  Catégorie configurée: '{self.product_category}'")
        print("⚠️  Créez cette catégorie manuellement dans Dolibarr si elle n'existe pas")
    
    def _ensure_category_exists(self):
        """Vérifie si la catégorie WikiCards existe, sinon la crée"""
        try:
            # Chercher la catégorie
            categories = self._get_categories()
            category_exists = any(
                cat.get("label") == self.product_category 
                for cat in categories
            )
            
            if not category_exists:
                print(f"📂 Création de la catégorie '{self.product_category}' dans Dolibarr...")
                self._create_category()
                
        except Exception as e:
            print(f"⚠️  Impossible de vérifier/créer la catégorie: {e}")
    
    def _get_categories(self) -> List[Dict]:
        """Récupère toutes les catégories de produits"""
        try:
            response = requests.get(
                f"{self.base_url}/api/index.php/categories",
                headers=self.headers,
                params={"type": "product"},
                timeout=10
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                return []
                
        except Exception:
            return []
    
    def _create_category(self) -> Optional[Dict]:
        """Crée la catégorie WikiCards"""
        try:
            category_data = {
                "label": self.product_category,
                "type": 0,  # 0 = catégorie produit
                "description": "Cartes Wikipédia pour le jeu WikiCards",
                "visible": 1,
                "color": "4CAF50"  # Vert
            }
            
            response = requests.post(
                f"{self.base_url}/api/index.php/categories",
                headers=self.headers,
                json=category_data,
                timeout=10
            )
            
            if response.status_code == 201:
                return response.json()
            else:
                print(f"❌ Erreur création catégorie: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            print(f"❌ Exception création catégorie: {e}")
            return None
    
    def get_product_by_ref(self, product_ref: str) -> Optional[Dict]:
        """
        Récupère un produit par sa référence
        
        Args:
            product_ref: Référence du produit (ex: WIKI_6678_2024-09)
            
        Returns:
            Données du produit ou None si non trouvé
        """
        try:
            response = requests.get(
                f"{self.base_url}/api/index.php/products/ref/{product_ref}",
                headers=self.headers,
                timeout=10
            )
            
            if response.status_code == 200:
                return response.json()
            elif response.status_code == 404:
                return None
            else:
                print(f"⚠️  Erreur recherche produit {product_ref}: {response.status_code}")
                return None
                
        except requests.exceptions.Timeout:
            print(f"⏱️  Timeout recherche produit {product_ref}")
            return None
        except Exception as e:
            print(f"❌ Exception recherche produit {product_ref}: {e}")
            return None
    
    def search_products_by_custom_field(self, field_name: str, field_value: str) -> List[Dict]:
        """
        Recherche des produits par champ personnalisé
        
        Utilise l'API avec filtre sur les propriétés personnalisées
        """
        try:
            # Récupérer tous les produits et filtrer localement
            # (Dolibarr API ne supporte pas directement la recherche par champ perso)
            response = requests.get(
                f"{self.base_url}/api/index.php/products",
                headers=self.headers,
                params={"limit": 100},
                timeout=15
            )
            
            if response.status_code == 200:
                all_products = response.json()
                matching_products = []
                
                for product in all_products:
                    # Vérifier les propriétés personnalisées
                    if isinstance(product, dict):
                        # Chercher dans les champs personnalisés
                        if "array_options" in product:
                            options = product["array_options"]
                            if isinstance(options, dict):
                                for key, value in options.items():
                                    if field_name in key and str(value) == str(field_value):
                                        matching_products.append(product)
                                        break
                        
                        # Chercher dans les autres champs
                        if product.get(field_name) == field_value:
                            matching_products.append(product)
                
                return matching_products
            else:
                return []
                
        except Exception:
            return []
    
    def create_product(self, product_data: Dict) -> Dict:
        """
        Crée un nouveau produit dans Dolibarr
        
        Args:
            product_data: Données du produit à créer
            
        Returns:
            Produit créé
        """
        try:
            # S'assurer que la catégorie est définie
            if "categories" not in product_data:
                product_data["categories"] = [self.product_category]
            
            # Ajouter le taux de TVA par défaut si non spécifié
            if "vat_rate" not in product_data:
                product_data["vat_rate"] = self.default_vat_rate
            
            response = requests.post(
                f"{self.base_url}/api/index.php/products",
                headers=self.headers,
                json=product_data,
                timeout=15
            )
            
            if response.status_code == 201 or response.status_code == 200:
                response_text = response.text.strip()
                
                # Dolibarr peut répondre juste avec l'ID numérique
                if response_text.isdigit():
                    product_id = int(response_text)
                    print(f"✅ Produit créé avec ID: {product_id}")
                    return {"id": product_id, "status": "created"}
                
                # Sinon essayer de parser comme JSON
                try:
                    created_product = response.json()
                    print(f"✅ Produit créé: {created_product.get('ref', 'N/A')} (ID: {created_product.get('id')})")
                    return created_product
                except Exception:
                    # Si ni numérique ni JSON valide
                    print(f"ℹ️  Produit créé - réponse: {response_text}")
                    return {"raw_response": response_text, "status": "created"}
            else:
                error_msg = f"Erreur création produit: {response.status_code} - {response.text}"
                print(f"❌ {error_msg}")
                raise Exception(error_msg)
                
        except requests.exceptions.Timeout:
            raise Exception("Timeout lors de la création du produit")
        except Exception as e:
            raise Exception(f"Erreur création produit: {str(e)}")
    
    def calculate_price_by_rarity(self, rarity: str) -> float:
        """
        Calcule le prix d'une carte basé sur sa rareté
        
        Common: 1-5€
        Uncommon: 5-15€  
        Rare: 15-50€
        Epic: 50-200€
        Legendary: 200-1000€
        """
        import random
        
        price_ranges = {
            "common": (1.0, 5.0),
            "uncommon": (5.0, 15.0),
            "rare": (15.0, 50.0),
            "epic": (50.0, 200.0),
            "legendary": (200.0, 1000.0)
        }
        
        if rarity not in price_ranges:
            rarity = "common"  # Valeur par défaut
        
        min_price, max_price = price_ranges[rarity]
        return round(random.uniform(min_price, max_price), 2)
    
    def test_connection(self) -> Tuple[bool, Dict]:
        """Teste la connexion à l'API Dolibarr"""
        try:
            response = requests.get(
                f"{self.base_url}/api/index.php/status",
                headers=self.headers,
                timeout=5
            )
            
            if response.status_code == 200:
                return True, {
                    "status_code": response.status_code,
                    "response": response.json(),
                    "message": "Connexion API Dolibarr réussie"
                }
            else:
                return False, {
                    "status_code": response.status_code,
                    "response": response.text,
                    "message": f"Erreur API: {response.status_code}"
                }
                
        except requests.exceptions.ConnectionError:
            return False, {
                "message": "Impossible de se connecter à Dolibarr. Vérifiez l'URL et que le service tourne."
            }
        except requests.exceptions.Timeout:
            return False, {
                "message": "Timeout lors de la connexion à Dolibarr"
            }
        except Exception as e:
            return False, {
                "message": f"Erreur inconnue: {str(e)}"
            }
    
    def get_wikicards_stats(self) -> Dict:
        """
        Récupère les statistiques des produits WikiCards
        """
        try:
            # Récupérer tous les produits
            response = requests.get(
                f"{self.base_url}/api/index.php/products",
                headers=self.headers,
                params={"limit": 500},
                timeout=15
            )
            
            if response.status_code != 200:
                return {"error": "Impossible de récupérer les produits"}
            
            all_products = response.json()
            
            # Filtrer les produits WikiCards (par référence qui commence par WIKI_)
            wikicards_products = []
            for product in all_products:
                if isinstance(product, dict) and product.get("ref", "").startswith("WIKI_"):
                    wikicards_products.append(product)
            
            # Statistiques par rareté
            rarity_stats = {}
            for product in wikicards_products:
                # Extraire la rareté des propriétés personnalisées
                rarity = "unknown"
                if "array_options" in product:
                    options = product["array_options"]
                    if isinstance(options, dict):
                        for key, value in options.items():
                            if "options_" in key and "rarity" in key.lower():
                                rarity = str(value)
                                break
                
                if rarity not in rarity_stats:
                    rarity_stats[rarity] = 0
                rarity_stats[rarity] += 1
            
            # Calculer les totaux
            total_wikicards = len(wikicards_products)
            total_value = sum(p.get("price", 0) for p in wikicards_products if isinstance(p.get("price"), (int, float)))
            
            return {
                "total_products": len(all_products),
                "total_wikicards": total_wikicards,
                "percentage_wikicards": round((total_wikicards / len(all_products) * 100), 2) if all_products else 0,
                "total_value": round(total_value, 2),
                "average_price": round(total_value / total_wikicards, 2) if total_wikicards > 0 else 0,
                "rarity_distribution": rarity_stats,
                "most_recent": wikicards_products[-1] if wikicards_products else None,
                "by_rarity": rarity_stats
            }
            
        except Exception as e:
            return {"error": f"Erreur calcul statistiques: {str(e)}"}
    
    def update_stock(self, product_id: int, warehouse_id: int, quantity: float) -> Optional[Dict]:
        """
        Met à jour le stock d'un produit
        
        Args:
            product_id: ID du produit
            warehouse_id: ID de l'entrepôt
            quantity: Quantité à ajouter (positif)/retirer (négatif)
            
        Returns:
            Résultat de la mise à jour ou None en cas d'erreur
        """
        try:
            stock_data = {
                "product_id": product_id,
                "warehouse_id": warehouse_id,
                "qty": quantity
            }
            
            response = requests.post(
                f"{self.base_url}/api/index.php/warehouses/{warehouse_id}/stock",
                headers=self.headers,
                json=stock_data,
                timeout=10
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                print(f"❌ Erreur mise à jour stock: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            print(f"❌ Exception mise à jour stock: {e}")
            return None
    
    def create_thirdparty(self, thirdparty_data: Dict) -> Optional[Dict]:
        """
        Crée un tiers (client/fournisseur) dans Dolibarr
        
        Pour représenter un joueur dans le jeu
        """
        try:
            response = requests.post(
                f"{self.base_url}/api/index.php/thirdparties",
                headers=self.headers,
                json=thirdparty_data,
                timeout=10
            )
            
            if response.status_code == 201:
                return response.json()
            else:
                print(f"❌ Erreur création tiers: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            print(f"❌ Exception création tiers: {e}")
            return None


def get_wikicards_metadata(self, product_id: int) -> Optional[Dict]:
        """
        Récupère les métadonnées WikiCards d'un produit
        
        Args:
            product_id: ID du produit Dolibarr
            
        Returns:
            Métadonnées WikiCards ou None si non trouvé
        """
        try:
            # Récupérer le produit
            response = requests.get(
                f"{self.base_url}/api/index.php/products/{product_id}",
                headers=self.headers,
                timeout=10
            )
            
            if response.status_code != 200:
                return None
            
            product = response.json()
            
            # Extraire les métadonnées depuis note_private
            note_private = product.get("note_private")
            if note_private:
                try:
                    import json
                    metadata = json.loads(note_private)
                    if metadata.get("wikicards_version"):
                        return metadata
                except json.JSONDecodeError:
                    pass
            
            # Fallback: construire depuis array_options
            metadata = {
                "wikicards_version": "0.9",
                "reconstructed_from": "array_options",
                "wikipedia": {
                    "page_id": None,
                    "title": self._extract_title_from_label(product.get("label", ""))
                },
                "statistics": {
                    "rarity": None,
                    "total_views": None
                }
            }
            
            # Chercher dans array_options
            array_options = product.get("array_options")
            if isinstance(array_options, dict):
                if "options_wikipedia_page_id" in array_options:
                    metadata["wikipedia"]["page_id"] = array_options["options_wikipedia_page_id"]
                
                if "options_wikicards_rarity" in array_options:
                    metadata["statistics"]["rarity"] = array_options["options_wikicards_rarity"]
                
                if "options_wikipedia_title" in array_options:
                    metadata["wikipedia"]["title"] = array_options["options_wikipedia_title"]
            
            return metadata
            
        except Exception as e:
            print(f"❌ Erreur récupération métadonnées: {e}")
            return None
    
    def _extract_title_from_label(self, label: str) -> str:
        """Extrait le titre Wikipédia du label (format: 'Titre - Carte Wikipédia')"""
        if " - Carte Wikipédia" in label:
            return label.replace(" - Carte Wikipédia", "")
        return label


# Service singleton pour faciliter l'utilisation
dolibarr_service = DolibarrService()