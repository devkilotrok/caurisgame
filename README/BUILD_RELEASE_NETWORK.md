# 📱 Guide : Build Release pour Test Réseau Local

Ce guide explique comment construire une version release de l'application Flutter configurée pour être testée depuis d'autres appareils sur le même réseau local.

## 🎯 Objectif

Permettre de tester l'application sur un téléphone Android connecté au même réseau WiFi que votre machine de développement, sans avoir besoin de ngrok ou d'une connexion Internet.

## 📋 Prérequis

1. ✅ Flutter SDK installé et configuré
2. ✅ Backend Laravel configuré et accessible
3. ✅ Serveur WebSocket configuré et accessible
4. ✅ Téléphone Android et PC sur le même réseau WiFi

## 🚀 Étapes Rapides

### 1. Vérifier la Configuration Réseau

Avant de construire l'APK, vérifiez que vos services sont correctement configurés :

```bash
cd /home/adolphe/cauris_app
./check_network_setup.sh
```

Ce script vérifie :
- ✅ Que Laravel écoute sur `0.0.0.0:8000` (accessible depuis le réseau)
- ✅ Que le WebSocket écoute sur `0.0.0.0:3000`
- ✅ Que le firewall autorise les connexions
- ✅ Que les services sont accessibles depuis l'IP locale

### 2. Démarrer les Services Backend

Assurez-vous que les services backend sont démarrés :

```bash
# Option 1 : Utiliser le script de démarrage complet
./start_all.sh

# Option 2 : Démarrer manuellement
cd /opt/lampp/htdocs/backendCauris
php artisan serve --host=0.0.0.0 --port=8000

# Dans un autre terminal, démarrer le WebSocket
cd /opt/lampp/htdocs/backendCauris/websocket-server
node server.js
```

**⚠️ Important** : Utilisez `--host=0.0.0.0` pour Laravel afin qu'il soit accessible depuis le réseau local.

### 3. Construire l'APK Release

Utilisez le script automatique qui détecte votre IP et configure l'APK :

```bash
cd /home/adolphe/cauris_app
./build_release_network.sh
```

Le script :
1. 🔍 Détecte automatiquement votre IP locale
2. ✅ Vérifie que les services backend sont accessibles
3. 🧹 Nettoie les builds précédents (optionnel)
4. 📦 Construit l'APK release avec les bonnes configurations
5. 📱 Affiche le chemin de l'APK généré

### 4. Installer l'APK sur votre Téléphone

1. **Transférer l'APK** :
   - Via USB : `adb install build/app/outputs/flutter-apk/app-release.apk`
   - Via email/cloud : Envoyez-vous l'APK par email
   - Via partage réseau : Utilisez un partage de fichiers

2. **Activer les sources inconnues** :
   - Paramètres → Sécurité → Sources inconnues (activé)

3. **Installer l'APK** :
   - Ouvrez le fichier APK sur votre téléphone
   - Suivez les instructions d'installation

### 5. Tester la Connexion

Avant de lancer l'application, testez la connexion depuis votre téléphone :

1. **Ouvrez un navigateur** sur votre téléphone
2. **Allez à** : `http://VOTRE_IP:8000/api/payment/balance`
   - Remplacez `VOTRE_IP` par l'IP affichée par le script (ex: `192.168.1.87`)
3. **Si vous voyez une réponse JSON**, la connexion fonctionne ! ✅

## 🔧 Configuration Manuelle

Si vous préférez construire manuellement l'APK :

```bash
# 1. Détecter votre IP locale
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "IP locale: $LOCAL_IP"

# 2. Construire l'APK avec les variables d'environnement
flutter build apk --release \
    --dart-define=BASE_URL="http://${LOCAL_IP}:8000/api" \
    --dart-define=WEBSOCKET_URL="ws://${LOCAL_IP}:3000"
```

## 🐛 Résolution des Problèmes

### Problème : "Impossible de se connecter au serveur"

**Causes possibles** :
1. Laravel n'écoute pas sur `0.0.0.0`
2. Firewall bloque les ports 8000 et 3000
3. Téléphone et PC ne sont pas sur le même réseau WiFi
4. IP incorrecte dans l'APK

**Solutions** :
```bash
# 1. Vérifier que Laravel écoute sur 0.0.0.0
lsof -i :8000 | grep LISTEN
# Doit afficher: *:8000 ou 0.0.0.0:8000

# 2. Vérifier le firewall
sudo ufw status
sudo ufw allow 8000/tcp
sudo ufw allow 3000/tcp

# 3. Vérifier l'IP locale
hostname -I

# 4. Tester depuis le téléphone
# Ouvrez un navigateur et allez à: http://VOTRE_IP:8000/api/payment/balance
```

### Problème : "WebSocket connection failed"

**Causes possibles** :
1. Serveur WebSocket non démarré
2. Port 3000 bloqué par le firewall
3. URL WebSocket incorrecte dans l'APK

**Solutions** :
```bash
# 1. Vérifier que le WebSocket est démarré
ps aux | grep "node.*server.js"

# 2. Vérifier que le port 3000 est ouvert
nc -z VOTRE_IP 3000

# 3. Redémarrer le WebSocket
cd /opt/lampp/htdocs/backendCauris/websocket-server
node server.js
```

### Problème : "APK ne se connecte pas mais le navigateur oui"

**Cause** : L'APK a été construit avec une mauvaise IP ou sans les variables d'environnement.

**Solution** : Reconstruire l'APK avec le script `build_release_network.sh` qui configure automatiquement les bonnes valeurs.

## 📝 Notes Importantes

1. **IP Dynamique** : Si votre IP change (redémarrage du routeur), vous devrez reconstruire l'APK avec la nouvelle IP.

2. **Réseau Local Uniquement** : Cette configuration fonctionne uniquement sur le réseau local. Pour tester depuis Internet, utilisez ngrok ou un serveur avec IP publique.

3. **Sécurité** : Cette configuration expose vos services sur le réseau local. Assurez-vous que votre réseau WiFi est sécurisé.

4. **Production** : Pour la production, utilisez un serveur avec domaine et SSL, pas cette configuration locale.

## 🎉 C'est Prêt !

Une fois l'APK installé et les services démarrés, vous pouvez tester l'application sur votre téléphone depuis le même réseau WiFi que votre PC.

Pour toute question ou problème, consultez les logs :
- Laravel : `tail -f ~/laravel.log`
- WebSocket : `tail -f ~/websocket.log`
