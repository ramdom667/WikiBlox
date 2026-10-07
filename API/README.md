# 🎴 API WikiCards - Middleware Python

Middleware pour le jeu de cartes Wikipédia intégrant Dolibarr et l'API Wikipédia.

## 🚀 Démarrage rapide

### 1. Installation
```bash
# Dans le dossier API/
./start.sh
```

### 2. Test de l'API
```bash
# Après démarrage, ouvrez dans votre navigateur :
# Swagger UI: http://localhost:8000/docs
# Documentation: http://localhost:8000/redoc
```

## 📡 Endpoints disponibles

### Test & Santé
- `GET /` - Page d'accueil
- `GET /health` - Vérification santé API
- `GET /api/test` - Test simple

### Wikipédia
- `GET /api/wikipedia/random` - **Tirage carte aléatoire** ✅

## 🎯 Fonctionnalités implémentées

### ✅ Phase 2 - Partie 1
- [x] **FastAPI** avec Swagger/Redoc automatique
- [x] **Fonction `tirage_carte_wikipedia()`** 
- [x] **Rate limiting** pour respecter les limites Wikipédia
- [x] **User-Agent** obligatoire configuré
- [x] **Gestion d'erreurs** complète
- [x] **Documentation interactive** sur `/docs`

### 🔄 Fonction `tirage_carte_wikipedia()`
```python
# Appelle l'endpoint Wikipédia: /page/random/summary
# Retourne: {page_id, title, description, image_url, url}
# Rate limit: 2 requêtes/seconde
# User-Agent: "WikiCards-IAMSI (contact@example.com)"
```

## 🛠️ Structure du projet
```
API/
├── main.py              # Application FastAPI principale
├── requirements.txt     # Dépendances Python
├── .env.example        # Variables d'environnement exemple
├── start.sh            # Script de démarrage
└── README.md           # Cette documentation
```

## 🔧 Configuration

### Variables d'environnement (.env)
```env
API_PORT=8000
API_HOST=0.0.0.0
WIKIPEDIA_USER_AGENT=WikiCards-IAMSI (contact@example.com)
WIKIPEDIA_RATE_LIMIT=2
```

### User-Agent Wikipédia
**OBLIGATOIRE** pour éviter le ban IP de Wikimedia.  
Format recommandé : `NomProjet (contact@email.com)`

## 🧪 Testing avec Swagger

1. **Ouvrez** http://localhost:8000/docs
2. **Déployez** `/api/wikipedia/random`
3. **Cliquez** sur "Try it out"
4. **Exécutez** pour voir une carte Wikipédia aléatoire

## 🚀 Prochaines étapes

### Phase 2 - Partie 2
- [ ] Connexion à Dolibarr (API REST)
- [ ] Vérification existence carte dans Dolibarr
- [ ] Création Produit Dolibarr si inexistant
- [ ] Endpoint `/api/cards/generate` complet

### Phase 2 - Partie 3
- [ ] Intégration Pageviews API pour la rareté
- [ ] Endpoints joueurs/inventaire
- [ ] Authentification simple

## 📝 Notes importantes

- **Rate limiting** : Respectez 2 req/sec max pour Wikipédia
- **User-Agent** : Toujours défini, sinon ban IP
- **Swagger** : Documentation et testing intégrés
- **FastAPI** : Reload automatique lors du développement