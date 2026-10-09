#!/bin/bash

echo "=== Démarrage de WikiCards API Structurée ==="
echo "=============================================="
echo "Données sur 3 mois complets"
echo "Rareté calculée sur le TOTAL 3 mois"
echo "Architecture modulaire"
echo "=============================================="
echo ""

# Vérification Python
if ! command -v python3 &> /dev/null; then
    echo "ERREUR: Python3 n'est pas installé"
    exit 1
fi

# Création environnement virtuel si nécessaire
if [ ! -d "venv" ]; then
    echo "Création de l'environnement virtuel..."
    python3 -m venv venv
fi

# Activation environnement virtuel
echo "Activation de l'environnement virtuel..."
source venv/bin/activate

# Installation dépendances
echo "Installation/vérification des dépendances..."
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet

# Vérification fichier .env
if [ ! -f ".env" ]; then
    echo "Création du fichier .env..."
    echo 'WIKIPEDIA_USER_AGENT="WikiCards-IAMSI (votre.email@domaine.com)"' > .env
    echo 'WIKIPEDIA_RATE_LIMIT=1' >> .env
    echo 'API_PORT=8000' >> .env
    echo 'API_HOST=0.0.0.0' >> .env
    echo 'RELOAD=true' >> .env
    echo ""
    echo "ATTENTION: .env créé avec email de démo"
    echo "MODIFIEZ avec votre VRAI email !"
    echo ""
fi

# Vérification email valide
USER_AGENT=$(grep 'WIKIPEDIA_USER_AGENT' .env | cut -d'"' -f2)
if [[ "$USER_AGENT" == *"example.com"* ]] || [[ "$USER_AGENT" == *"contact@example.com"* ]]; then
    echo ""
    echo "ERREUR CRITIQUE: User-Agent contient 'example.com'"
    echo "Wikipédia va BLOQUER l'API !"
    echo ""
    echo "Modifiez .env avec votre VRAI email"
    echo "nano .env  # ou votre éditeur favori"
    echo ""
    exit 1
fi

# Démarrer l'API
echo ""
echo "PRÊT À DÉMARRER !"
echo "=============================================="
echo "Swagger: http://localhost:8000/docs"
echo "Configuration: http://localhost:8000/config"
echo "Testez: /api/cards/random"
echo "Recherche: /api/cards/title/Cat"
echo "Exemples: /api/cards/examples"
echo "=============================================="
echo ""
echo "Pour arrêter: Ctrl+C"
echo ""

python main.py