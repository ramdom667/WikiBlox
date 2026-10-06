#!/bin/bash

echo "🔧 Installation de Dolibarr avec Docker..."

# Arrêter tout conteneur existant
docker stop dolibarr mysql 2>/dev/null || true
docker rm dolibarr mysql 2>/dev/null || true

# Démarrer MySQL
echo "🐬 Démarrage de MySQL..."
docker run -d \
  --name mysql \
  -e MYSQL_ROOT_PASSWORD=dolibarr \
  -e MYSQL_DATABASE=dolibarr \
  -e MYSQL_USER=dolibarr \
  -e MYSQL_PASSWORD=dolibarr \
  -p 3306:3306 \
  mysql:8.0 \
  --default-authentication-plugin=mysql_native_password

echo "⏳ Attente du démarrage de MySQL..."
sleep 10

# Vérifier que MySQL est prêt
until docker exec mysql mysqladmin ping -h localhost -u root -pdolibarr --silent; do
    echo "⏳ En attente de MySQL..."
    sleep 5
done

echo "✅ MySQL est prêt !"

# Démarrer Dolibarr
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

echo "⏳ Attente du démarrage de Dolibarr..."
sleep 20

# Vérifier l'état
echo "📊 État des conteneurs :"
docker ps

echo ""
echo "🌐 Dolibarr devrait être accessible sur : http://localhost:8080"
echo "📝 Identifiants : admin / admin123"
echo "🔑 Base de données : dolibarr / dolibarr"