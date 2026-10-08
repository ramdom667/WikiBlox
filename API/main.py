"""
API WikiCards - Version structurée (3 mois de données)
Architecture propre avec dossiers
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os
from dotenv import load_dotenv

# Chargement des variables d'environnement
load_dotenv()

# Import des routes
from routes.cards import router as cards_router
from routes.simple import router as simple_router
from routes.dolibarr import router as dolibarr_router

# Initialisation FastAPI
app = FastAPI(
    title="WikiCards API Structurée",
    description="Middleware structuré pour le jeu de cartes Wikipédia - Vues sur 3 mois",
    version="6.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json"
)

# CORS pour les appels frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Inclusion des routes
app.include_router(cards_router)
app.include_router(simple_router)
app.include_router(dolibarr_router)


@app.get("/")
async def root():
    """Page d'accueil"""
    return {
        "message": "WikiCards API Structurée",
        "version": "6.0.0",
        "architecture": "modulaire avec dossiers",
        "data_period": "3 derniers mois complets",
        "docs": "/docs",
        "health": "/health",
        "endpoints": {
            "cartes_completes": {
                "random": "/api/cards/random",
                "search": "/api/cards/title/{title}",
                "examples": "/api/cards/examples",
                "health": "/api/cards/health"
            },
            "simple": {
                "random": "/api/wikipedia/random",
                "search": "/api/wikipedia/title/{title}"
            }
        },
        "structure": {
            "models/": "Modèles de données",
            "services/": "Logique métier",
            "routes/": "Endpoints API",
            "utils/": "Fonctions utilitaires",
            "docs/": "Documentation"
        }
    }


@app.get("/health")
async def health_check():
    """Vérification santé globale"""
    return {
        "status": "healthy",
        "service": "wikicards-structured",
        "version": "6.0.0",
        "environment": os.getenv("ENVIRONMENT", "development"),
        "wikipedia_user_agent": os.getenv("WIKIPEDIA_USER_AGENT", "non configuré")
    }


@app.get("/config")
async def config():
    """Configuration de l'API (sans valeurs sensibles)"""
    return {
        "api": {
            "port": int(os.getenv("API_PORT", 8000)),
            "host": os.getenv("API_HOST", "0.0.0.0"),
            "reload": os.getenv("RELOAD", "true").lower() == "true"
        },
        "wikipedia": {
            "rate_limit": int(os.getenv("WIKIPEDIA_RATE_LIMIT", 1)),
            "user_agent_configured": bool(os.getenv("WIKIPEDIA_USER_AGENT")),
            "data_period": "3 mois complets",
            "reference_months": ["2024-07", "2024-08", "2024-09"]
        },
        "rarity_system": {
            "basis": "Moyenne vues sur 3 mois",
            "thresholds": {
                "common": "< 1,000 vues/mois",
                "uncommon": "1,000 - 10,000 vues/mois",
                "rare": "10,000 - 100,000 vues/mois",
                "epic": "100,000 - 1,000,000 vues/mois",
                "legendary": "> 1,000,000 vues/mois"
            }
        }
    }


if __name__ == "__main__":
    import uvicorn
    
    port = int(os.getenv("API_PORT", 8000))
    host = os.getenv("API_HOST", "0.0.0.0")
    reload = os.getenv("RELOAD", "true").lower() == "true"
    
    print("=" * 60)
    print("🚀 WIKICARDS API STRUCTURÉE")
    print("=" * 60)
    print(f"📡 URL: http://{host}:{port}")
    print(f"📚 Documentation: http://{host}:{port}/docs")
    print(f"⚙️  Configuration: http://{host}:{port}/config")
    print()
    print("📊 DONNÉES SUR 3 MOIS COMPLETS")
    print("   → Juillet 2024")
    print("   → Août 2024")
    print("   → Septembre 2024")
    print()
    print("🎴 ENDPOINTS PRINCIPAUX:")
    print("   /api/cards/random     → Carte avec rareté")
    print("   /api/cards/title/Cat  → Recherche par titre")
    print("   /api/cards/examples   → Exemples de titres")
    print()
    print("⚡ ENDPOINTS SIMPLES:")
    print("   /api/wikipedia/random → Très rapide (sans rareté)")
    print()
    print("📁 ARCHITECTURE:")
    print("   models/    → Modèles de données")
    print("   services/  → Logique métier")
    print("   routes/    → Endpoints API")
    print("=" * 60)
    print()
    print("⚠️  IMPORTANT: Vérifiez le fichier .env")
    print("   WIKIPEDIA_USER_AGENT doit contenir un VRAI email !")
    print("=" * 60)
    
    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=reload,
        log_level="info"
    )