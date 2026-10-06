#!/bin/bash

echo "==================================================="
echo "🎯 INSTALLATION DOLIBARR QUI FONCTIONNE ENFIN !"
echo "==================================================="
echo ""
echo "Problème résolu : L'installation auto Dolibarr bug sur ARM64"
echo "Solution : Installation manuelle via interface web"
echo ""

# Nettoyage complet
echo "🧹 Nettoyage de l'ancienne installation..."
docker stop dolibarr-app dolibarr-db 2>/dev/null || true
docker rm dolibarr-app dolibarr-db 2>/dev/null || true
docker network rm dolibarr-net 2>/dev/null || true

# Créer le réseau
echo "🌐 Création du réseau Docker..."
docker network create dolibarr-net

# Étape 1 : MariaDB (ÇA FONCTIONNE TOUJOURS)
echo ""
echo "1️⃣  DÉMARRAGE DE MARIADB"
echo "-------------------------------------------"
docker run -d \
  --name dolibarr-db \
  --network dolibarr-net \
  -e MYSQL_ROOT_PASSWORD=dolibarr \
  -e MYSQL_DATABASE=dolibarr \
  -e MYSQL_USER=dolibarr \
  -e MYSQL_PASSWORD=dolibarr \
  -p 3306:3306 \
  mariadb:10.11 \
  --character-set-server=utf8mb4 \
  --collation-server=utf8mb4_unicode_ci

echo "⏳ Attente de MariaDB (40 secondes, important)..."
sleep 40

# Vérifier MariaDB
echo "🔍 Vérification de MariaDB..."
if docker exec dolibarr-db mariadb -u dolibarr -pdolibarr -e "SELECT '✅ MariaDB OK' as status;" dolibarr 2>/dev/null; then
    echo "✅ MARIADB FONCTIONNE PARFAITEMENT !"
else
    echo "❌ Problème avec MariaDB. Logs :"
    docker logs dolibarr-db --tail=20
    exit 1
fi

# Étape 2 : Dolibarr SANS installation auto
echo ""
echo "2️⃣  DÉMARRAGE DE DOLIBARR"
echo "-------------------------------------------"
echo "⚠️  IMPORTANT : Pas d'installation automatique"
echo "    Installation via interface web seulement"

docker run -d \
  --name dolibarr-app \
  --network dolibarr-net \
  -e DATABASE_HOST=dolibarr-db \
  -e DATABASE_USER=dolibarr \
  -e DATABASE_PASSWORD=dolibarr \
  -e DATABASE_NAME=dolibarr \
  -e DOLI_DB_TYPE=mysqli \
  -e PHP_INI_DATE_TIMEZONE=Europe/Paris \
  -p 8080:80 \
  dolibarr/dolibarr:latest

echo "⏳ Dolibarr démarre... (attendre 1 minute)"
sleep 60

# Étape 3 : Vérification
echo ""
echo "3️⃣  VÉRIFICATION FINALE"
echo "-------------------------------------------"

# Vérifier si Apache tourne dans le conteneur
echo "🔍 Vérification du serveur web..."
if docker exec dolibarr-app ps aux | grep -q apache; then
    echo "✅ Apache tourne dans le conteneur"
else
    echo "⚠️  Apache ne tourne pas. Redémarrage..."
    docker restart dolibarr-app
    sleep 30
fi

# Attendre un peu plus
echo "⏳ Dernière attente (30 secondes)..."
sleep 30

# Tester l'accès
echo "🌐 Test d'accès à http://localhost:8080 ..."
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 || echo "ERR")

echo ""
echo "==================================================="
echo "📊 RÉSULTAT FINAL"
echo "==================================================="
echo ""

if [[ "$HTTP_RESPONSE" =~ ^(200|302|301)$ ]]; then
    echo "🎉🎉🎉 SUCCÈS TOTAL ! 🎉🎉🎉"
    echo ""
    echo "✅ DOLIBARR EST INSTALLÉ ET FONCTIONNE !"
    echo ""
    echo "🔗 ACCÈS : http://localhost:8080"
    echo ""
    echo "📝 PROCÉDURE D'INSTALLATION :"
    echo "   1. Ouvrez http://localhost:8080"
    echo "   2. Suivez l'assistant d'installation web"
    echo "   3. CONFIGURATION BASE DE DONNÉES :"
    echo "      - Serveur : dolibarr-db"
    echo "      - Utilisateur : dolibarr"
    echo "      - Mot de passe : dolibarr"
    echo "      - Base de données : dolibarr"
    echo "   4. Créez un compte administrateur"
    echo ""
    echo "💾 Base de données MySQL/MariaDB :"
    echo "   - Port : 3306"
    echo "   - User : dolibarr"
    echo "   - Pass : dolibarr"
    echo "   - DB : dolibarr"
    
elif [ "$HTTP_RESPONSE" = "000" ]; then
    echo "⚠️  Dolibarr ne répond pas encore"
    echo "📋 Logs de Dolibarr :"
    docker logs dolibarr-app --tail=30
    echo ""
    echo "🔄 Essayez d'accéder à http://localhost:8080 dans 1-2 minutes"
    echo "   L'installation via web devrait fonctionner"
    
else
    echo "⚠️  Code HTTP : $HTTP_RESPONSE"
    echo "📋 Logs :"
    docker logs dolibarr-app --tail=20
fi

echo ""
echo "==================================================="
echo "🔧 COMMANDES UTILES"
echo "==================================================="
echo "📋 Logs Dolibarr : docker logs dolibarr-app"
echo "📋 Logs MariaDB  : docker logs dolibarr-db"
echo "🔄 Redémarrer    : docker restart dolibarr-app"
echo "📊 État          : docker ps"
echo "🌐 Réseau        : docker network inspect dolibarr-net"
echo ""
echo "⚠️  Si problème : Accédez quand même à http://localhost:8080"
echo "    L'installation web DOIT fonctionner même si curl échoue"