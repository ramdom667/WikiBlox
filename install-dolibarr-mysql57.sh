#!/bin/bash

echo "🔧 Installation de Dolibarr avec MySQL 5.7..."

# Démarrer MySQL 5.7
echo "🐬 Démarrage de MySQL 5.7..."
docker run -d \
  --name mysql \
  -e MYSQL_ROOT_PASSWORD=dolibarr \
  -e MYSQL_DATABASE=dolibarr \
  -e MYSQL_USER=dolibarr \
  -e MYSQL_PASSWORD=dolibarr \
  -p 3306:3306 \
  mysql:5.7

echo "⏳ Attente du démarrage de MySQL (30 secondes)..."
sleep 30

# Vérifier que MySQL est prêt
echo "🔍 Vérification de MySQL..."
docker exec mysql mysql -u root -pdolibarr -e "SELECT 1;" dolibarr

if [ $? -eq 0 ]; then
    echo "✅ MySQL 5.7 est prêt !"
else
    echo "❌ Problème avec MySQL"
    exit 1
fi

# Démarrer Dolibarr avec plus de temps d'attente
echo "🚀 Démarrage de Dolibarr..."
docker run -d \
  --name dolibarr \
  --link mysql:db \
  -e DATABASE_HOST=db \
  -e DATABASE_USER=dolibarr \
  -e DATABASE_PASSWORD=dolibarr \
  -e DATABASE_NAME=dolibarr \
  -e DOLI_DB_TYPE=mysqli \
  -e DOLI_INSTALL_AUTO=1 \
  -e DOLI_ADMIN_LOGIN=admin \
  -e DOLI_ADMIN_PASSWORD=admin123 \
  -e DOLI_ADMIN_MAIL=admin@wikicards.local \
  -e PHP_INI_DATE_TIMEZONE=Europe/Paris \
  -p 8080:80 \
  dolibarr/dolibarr:latest

echo "⏳ Installation en cours (peut prendre 2-3 minutes)..."
echo "📋 Suivi des logs (Ctrl+C pour arrêter le suivi)..."

# Afficher les logs pendant 60 secondes
timeout 60 docker logs -f dolibarr

echo ""
echo "📊 État final des conteneurs :"
docker ps

echo ""
echo "🌐 Dolibarr devrait être accessible sur : http://localhost:8080"
echo "📝 Identifiants : admin / admin123"
echo "🔑 Base de données : dolibarr / dolibarr"
echo ""
echo "Pour voir les logs : docker logs dolibarr"
echo "Pour arrêter : docker stop dolibarr mysql && docker rm dolibarr mysql"