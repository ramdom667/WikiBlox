#!/bin/bash

echo "==========================================="
echo "📦 INSTALLATION DOLIBARR - ÉTAPE PAR ÉTAPE"
echo "==========================================="

echo ""
echo "1️⃣  CRÉATION DU RÉSEAU DOCKER"
docker network create dolibarr-network 2>/dev/null || echo "Réseau existe déjà"

echo ""
echo "2️⃣  DÉMARRAGE DE MARIADB"
docker run -d \
  --name dolibarr-db \
  --network dolibarr-network \
  -e MYSQL_ROOT_PASSWORD=dolibarr \
  -e MYSQL_DATABASE=dolibarr \
  -e MYSQL_USER=dolibarr \
  -e MYSQL_PASSWORD=dolibarr \
  -p 3306:3306 \
  mariadb:10.11

echo "⏳ Attente du démarrage de MariaDB (30 secondes)..."
sleep 30

echo ""
echo "3️⃣  VÉRIFICATION DE LA BASE DE DONNÉES"
if docker exec dolibarr-db mariadb -u dolibarr -pdolibarr -e "SELECT 'OK' as status;" dolibarr 2>/dev/null; then
    echo "✅ MariaDB fonctionne correctement"
else
    echo "❌ ERREUR: MariaDB ne répond pas"
    echo "Logs MariaDB:"
    docker logs dolibarr-db --tail=20
    exit 1
fi

echo ""
echo "4️⃣  DÉMARRAGE DE DOLIBARR (SANS INSTALLATION AUTO)"
echo "⚠️  Nous allons d'abord démarrer Dolibarr sans installation auto"
echo "   pour pouvoir configurer manuellement si nécessaire"

docker run -d \
  --name dolibarr-app \
  --network dolibarr-network \
  -e DATABASE_HOST=dolibarr-db \
  -e DATABASE_USER=dolibarr \
  -e DATABASE_PASSWORD=dolibarr \
  -e DATABASE_NAME=dolibarr \
  -e DOLI_DB_TYPE=mysqli \
  -e PHP_INI_DATE_TIMEZONE=Europe/Paris \
  -p 8080:80 \
  dolibarr/dolibarr:latest

echo "⏳ Attente du démarrage de Dolibarr (20 secondes)..."
sleep 20

echo ""
echo "5️⃣  VÉRIFICATION DE L'ACCÈS WEB"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 || echo "000")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "✅ Dolibarr accessible sur http://localhost:8080"
    echo ""
    echo "==========================================="
    echo "🎉 INSTALLATION RÉUSSIE !"
    echo "==========================================="
    echo ""
    echo "🔗 Accès : http://localhost:8080"
    echo "👤 Identifiant : admin"
    echo "🔐 Mot de passe : (à définir via l'assistant web)"
    echo ""
    echo "Si vous voyez l'assistant d'installation :"
    echo "1. Choisissez votre langue"
    echo "2. Configuration base de données :"
    echo "   - Serveur : dolibarr-db"
    echo "   - Utilisateur : dolibarr"
    echo "   - Mot de passe : dolibarr"
    echo "   - Base : dolibarr"
    echo ""
elif [ "$HTTP_CODE" = "000" ]; then
    echo "⚠️  Dolibarr ne répond pas encore. Vérifiez les logs :"
    docker logs dolibarr-app --tail=30
    echo ""
    echo "Essayez d'accéder à http://localhost:8080 dans 1-2 minutes"
else
    echo "⚠️  Code HTTP : $HTTP_CODE"
    echo "Vérifiez les logs :"
    docker logs dolibarr-app --tail=20
fi

echo ""
echo "6️⃣  COMMANDES UTILES :"
echo "   📋 Voir les logs : docker logs dolibarr-app"
echo "   🔄 Redémarrer : docker restart dolibarr-app"
echo "   🛑 Arrêter : docker stop dolibarr-app dolibarr-db"
echo "   🗑️  Supprimer : docker rm dolibarr-app dolibarr-db"
echo "   🌐 Réseau : docker network ls"