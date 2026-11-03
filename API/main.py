"""
API WikiCards - Version structurée (3 mois de données)
Architecture propre avec dossiers
"""
from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os
from dotenv import load_dotenv

# Chargement des variables d'environnement
# override=True : le .env fait foi, même après un rechargement à chaud (reload)
load_dotenv(override=True)

# Import des routes
from routes.cards import router as cards_router
from routes.simple import router as simple_router
from routes.dolibarr import router as dolibarr_router
from routes.catalog import router as catalog_router
from routes.boosters import router as boosters_router, players_router
from security import require_admin_key

# Swagger / ReDoc : désactivables en production (DOCS_ENABLED=false)
DOCS_ENABLED = os.getenv("DOCS_ENABLED", "true").lower() == "true"

# Initialisation FastAPI
app = FastAPI(
    title="WikiCards API",
    description=(
        "API du jeu WikiBlox : catalogue de cartes Wikipédia (Dolibarr), boosters et collections des joueurs Roblox.\n\n"
        "Authentification : bouton **Authorize** puis la clé (en-tête `X-API-Key`)."
    ),
    version="7.0.0",
    docs_url="/docs" if DOCS_ENABLED else None,
    redoc_url="/redoc" if DOCS_ENABLED else None,
    openapi_url="/openapi.json" if DOCS_ENABLED else None
)

# CORS (Roblox n'en a pas besoin : les appels viennent du serveur de jeu)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Inclusion des routes
app.include_router(cards_router)
app.include_router(simple_router)
app.include_router(dolibarr_router)
app.include_router(catalog_router)
app.include_router(boosters_router)
app.include_router(players_router)


@app.get("/")
async def root():
    """Page d'accueil (publique)"""
    return {
        "message": "WikiCards API",
        "version": "7.0.0",
        "docs": "/docs" if DOCS_ENABLED else None,
        "health": "/health",
        "auth": "En-tête X-API-Key (clé de jeu ou clé d'administration)",
        "endpoints": {
            "jeu (clé de jeu)": {
                "boosters": "GET /api/boosters",
                "ouvrir": "POST /api/boosters/open",
                "simuler": "GET /api/boosters/{type}/simulate",
                "collection": "GET /api/players/{roblox_user_id}/collection"
            },
            "admin (clé d'admin)": {
                "catalogue": "/api/catalog/*",
                "dolibarr": "/api/dolibarr/*",
                "cartes": "/api/cards/*",
                "wikipedia": "/api/wikipedia/*",
                "config": "/config"
            }
        }
    }


@app.get("/health")
async def health_check():
    """Vérification santé globale"""
    return {
        "status": "healthy",
        "service": "wikicards-structured",
        "version": "7.0.0",
        "environment": os.getenv("ENVIRONMENT", "development"),
        "wikipedia_user_agent": os.getenv("WIKIPEDIA_USER_AGENT", "non configuré")
    }


@app.get("/config", dependencies=[Depends(require_admin_key)])
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
    
    # Version minimaliste du lancement (sans emojis)
    print("=== WikiCards API démarrée ===")
    print(f"URL: http://{host}:{port}")
    print(f"Docs: http://{host}:{port}/docs")
    
    # Vérification rapide des configurations
    print("\nConfiguration:")
    
    # Dolibarr config
    dolibarr_url = os.getenv("DOLIBARR_URL")
    dolibarr_key = os.getenv("DOLIBARR_API_KEY")
    if dolibarr_url and dolibarr_key and dolibarr_key != "your_dolibarr_api_key_here":
        print("   Dolibarr: Connecté")
    else:
        print("   Dolibarr: Non configuré")
    
    # Wikipedia config
    wikipedia_ua = os.getenv("WIKIPEDIA_USER_AGENT")
    if wikipedia_ua and "example.com" not in wikipedia_ua:
        print("   Wikipedia: User-Agent configuré")
    else:
        print("   Wikipedia: User-Agent REQUIS")
    
    print(f"   Période données: Juil-Août-Sept 2024")
    print(f"   Reload: {'Activé' if reload else 'Désactivé'}")
    
    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=reload,
        log_level="info"
    )