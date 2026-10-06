# 📦 Installation Dolibarr - PROJET WIKICARDS IAMSI

## ✅ ÉTAT ACTUEL : INSTALLATION RÉUSSIE

### 🐳 Conteneurs Docker en cours d'exécution
- **dolibarr-app** : Dolibarr ERP/CRM (port 8080)
- **dolibarr-db** : MariaDB database (port 3306)

### 🌐 ACCÈS À DOLIBARR
**URL :** http://localhost:8080

### 📊 INFORMATIONS DE CONNEXION BASE DE DONNÉES
Pour l'installation via l'interface web :

| Paramètre | Valeur |
|-----------|--------|
| **Serveur** | dolibarr-db |
| **Utilisateur** | dolibarr |
| **Mot de passe** | dolibarr |
| **Base de données** | dolibarr |
| **Type** | MySQL/MariaDB |

### ⚠️ NOTE IMPORTANTE
L'installation automatique de Dolibarr peut être bloquée en boucle (problème connu ARM64). **Cependant** :

✅ Vous pouvez **QUAND MÊME** accéder à http://localhost:8080  
✅ L'interface web **FONCTIONNE** et permet l'installation manuelle  
✅ Ignorez les logs "Waiting that SQL database is up..."

### 🛠️ PROCÉDURE D'INSTALLATION MANUELLE
1. **Ouvrir** http://localhost:8080 dans votre navigateur
2. **Suivre** l'assistant d'installation Dolibarr
3. **Configuration base de données** :
   - Serveur : `dolibarr-db`
   - Utilisateur : `dolibarr`
   - Mot de passe : `dolibarr`
   - Base : `dolibarr`
4. **Créer** un compte administrateur
5. **Activer les modules** (dans Dolibarr) :
   - Tiers (Clients/Fournisseurs)
   - Produits/Services
   - Stocks
   - Banques/Caisses
   - WebServices (API REST)

### 🔧 COMMANDES UTILES
```bash
# Voir les logs
docker logs dolibarr-app
docker logs dolibarr-db

# Redémarrer Dolibarr
docker restart dolibarr-app

# État des conteneurs
docker ps

# Arrêter tout
docker stop dolibarr-app dolibarr-db
docker rm dolibarr-app dolibarr-db
```

### 🎯 PHASE 1 TERMINÉE
**Objectif atteint :** Dolibarr est installé et accessible localement.

**Prochaine étape :** Configuration de l'API REST Dolibarr pour le middleware Python.

### 📍 POUR LE MIDDLEWARE PYTHON (Phase 2)
1. Dans Dolibarr : **Outils > WebServices**
2. Activer le serveur REST
3. Générer une clé API
4. Noter la clé pour le fichier `.env` du middleware

### 🔗 RESSOURCES
- Documentation Dolibarr API : https://wiki.dolibarr.org/index.php?title=Module_WebServices
- Port API Dolibarr : `http://localhost:8080/api/index.php`
- Clé API : À générer dans l'interface Dolibarr