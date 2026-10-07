# 📚 WikiCards API - Documentation

**Middleware pour le jeu de cartes Wikipédia | Phase 2 - Partie 1**

---

## 🎯 **Présentation**

API Python FastAPI connectant Wikipédia à un jeu de cartes type "cartes à collectionner".  
Génération de cartes aléatoires avec système de **rareté** basé sur les **statistiques réelles de visites**.

**URL :** `http://localhost:8000`  
**Swagger :** `http://localhost:8000/docs`

---

## 📊 **Système de Rareté**

La rareté est calculée sur le **TOTAL des vues des 3 derniers mois complets** (Juillet-Août-Septembre 2024).

| Rareté | Emoji | Total vues / 3 mois | Exemple |
|--------|-------|---------------------|---------|
| **Common** | ⚪ | < 1,000 | Articles obscurs |
| **Uncommon** | 🟢 | 1,000 - 10,000 | Articles de niche |
| **Rare** | 🔵 | 10,000 - 100,000 | Articles populaires |
| **Epic** | 🟣 | 100,000 - 1,000,000 | Articles très populaires |
| **Legendary** | 🟡 | > 1,000,000 | Articles viraux |

**Exemple :** "Cat" = 1,131,535 vues/3 mois → **Legendary** 🟡

---

## 🚀 **Endpoints Principaux**

### **1. Carte Aléatoire avec Rareté**
```
GET /api/cards/random
```

**Réponse :** Carte complète avec données mensuelles et rareté  
**Performance :** ~2-3 secondes (3 appels API)

```json
{
  "success": true,
  "card": {
    "monthly_views": {
      "2024-07": 355184,
      "2024-08": 339923, 
      "2024-09": 436428
    },
    "total_views": 1131535,
    "rarity": "legendary",
    "rarity_emoji": "🟡"
  },
  "game_ready": {
    "id": "WIKI_6678_2024-09",
    "name": "Cat",
    "rarity_display": "🟡 LEGENDARY",
    "total_views": 1131535
  }
}
```

---

### **2. Recherche par Titre**
```
GET /api/cards/title/{title}
```

**Arguments :** Titre Wikipédia exact (espaces → underscores `_`)  
**Exemples :**
- `/api/cards/title/Cat`
- `/api/cards/title/Albert_Einstein`  
- `/api/cards/title/Quantum_mechanics`

**Performance :** ~2-3 secondes

---

### **3. Version Simple (Rapide)**
```
GET /api/wikipedia/random
```
```
GET /api/wikipedia/title/{title}
```

**Pour :** Développement et tests rapides (< 500ms)  
**Exclut :** Pageviews API et rareté

---

## ⚙️ **Configuration**

### **Fichier `.env`** (OBLIGATOIRE)
```env
# Format STRICT : "Projet (email@domaine.com)"
WIKIPEDIA_USER_AGENT="WikiCards-IAMSI (swoooxd2500@gmail.com)"

# Rate limiting (1 = 1 requête/seconde)
WIKIPEDIA_RATE_LIMIT=1

# Configuration API
API_PORT=8000
API_HOST=0.0.0.0
RELOAD=true
```

**IMPORTANT :** Sans email valide → **blocage par Wikipédia**

---

## 🛠️ **Installation & Démmarage**

### **1. Installation**
```bash
cd API
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### **2. Configuration**
```bash
echo 'WIKIPEDIA_USER_AGENT="WikiCards-IAMSI (votre.email@ici.com)"' > .env
```

### **3. Démmarage**
```bash
./start.sh
# ou
python main.py
```

### **4. Tests**
```bash
# Vérifier Swagger
open http://localhost:8000/docs

# Tester Cat (devrait être Legendary)
curl http://localhost:8000/api/cards/title/Cat | jq '.card.rarity, .card.total_views'
```

---

## 🏗️ **Architecture**

```
API/
├── main.py                # Point d'entrée
├── requirements.txt       # Dépendances
├── .env                  # Configuration
│
├── models/               # Modèles de données
│   └── card.py          # Pydantic models
│
├── services/            # Logique métier  
│   └── wikipedia_service.py  # Appels API
│
└── routes/              # Endpoints
    ├── cards.py        # Cartes avec rareté
    └── simple.py       # Version simple
```

---

## 🔗 **APIs Externes Utilisées**

### **1. Wikipedia REST API**
- **URL :** `https://en.wikipedia.org/api/rest_v1/page/random/summary`
- **Données :** Titre, description, image, page_id
- **Rate limit :** ~100 req/min

### **2. Pageviews API**  
- **URL :** `https://wikimedia.org/api/rest_v1/metrics/pageviews/`
- **Données :** Statistiques mensuelles de vues
- **Période :** 3 derniers mois complets
- **Rate limit :** Strict (1-2 req/sec)

---

## 📈 **Performance & Statistiques**

### **Temps de réponse :**
- **Cartes avec rareté :** 2-3 secondes
  - 1 appel → Article Wikipédia
  - 3 appels → Pageviews (1 par mois)
- **Cartes simples :** < 500ms
  - 1 appel seulement

### **Cache :**
- **Aucun cache persistant** pour l'instant
- **Optimisations :** Pauses automatiques entre appels
- **Rate limiting :** Configurable dans `.env`

---

## 🐛 **Dépannage**

### **Erreur 429 (Rate Limit)**
```
{"detail": "Rate limit Wikipédia"}
```
**Solution :**
1. Vérifier `.env` → email valide
2. Augmenter `WIKIPEDIA_RATE_LIMIT=2`
3. Attendre 1-2 minutes

### **Erreur 404 (Article non trouvé)**
```
{"detail": "Article non trouvé: 'Titre'"}
```
**Solution :** Vérifier le titre exact, remplacer espaces par `_`

### **Données manquantes dans pageviews**
```
"monthly_views": {"2024-07": 0, "2024-08": 0, "2024-09": 0}
```
**Solution :** Email invalide dans `.env` → modifier avec email réel

---

## 📋 **Checklist de Démo**

- [x] API démarrée sur `http://localhost:8000`
- [x] Swagger accessible sur `/docs`
- [x] `.env` configuré avec email valide
- [x] `/api/cards/title/Cat` retourne données
- [x] Rareté calculée correctement
- [x] `/api/cards/random` fonctionne
- [x] `/api/wikipedia/random` (version simple) fonctionne

---

## 🔮 **Prochaines Étapes (Phase 2 - Partie 2)**

1. **Intégration Dolibarr**
   - Enregistrement cartes comme produits
   - Gestion stocks → inventaire joueurs

2. **Cache persistant**
   - Base de données pour pageviews
   - Réduction temps réponse

3. **Système d'acquisition**
   - Jauges de progression
   - Boosters par rareté

---

## 📞 **Support**

**Projet :** WikiCards IAMSI  
**Contact :** [swoooxd2500@gmail.com](mailto:swoooxd2500@gmail.com)  
**Date :** Octobre 2026  
**Version :** 1.0.0

---

*Documentation générée automatiquement le 07/10/2026*  
*Dernière mise à jour : 16:15*