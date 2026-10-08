"""
Service pour l'intégration avec Dolibarr ERP - VERSION FIXÉE
"""
import requests
import os
import json
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
    
    def get_product_by_ref(self, product_ref: str) -> Optional[Dict]:
        """
        Récupère un produit par sa référence
        
        Args:
            product_ref: Référence du produit (ex: WIKI_6678)
            
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
    
    def create_product(self, product_data: Dict) -> Dict:
        """
        Crée un nouveau produit dans Dolibarr
        
        Args:
            product_data: Données du produit à créer
            
        Returns:
            Produit créé
        """
        try:
            # Dolibarr peut retourner juste l'ID (pas du JSON)
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