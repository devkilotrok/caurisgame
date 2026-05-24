# 💳 Configuration FedaPay - Mode Local (Sans ngrok)

## 📋 Vue d'ensemble

Le système FedaPay est configuré pour fonctionner en mode local, sans ngrok, en utilisant directement l'IP locale de votre machine.

## ⚙️ Configuration

### 1. Configuration Frontend (Flutter)

**Fichier** : `lib/config/api_config.dart`

```dart
static const String baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'http://192.168.1.80:8000/api', // ✅ IP locale de votre machine
);
```

**Pour changer l'IP** :
- Modifiez `192.168.1.80` par l'IP de votre machine
- Ou utilisez `--dart-define` : `flutter run --dart-define=BASE_URL=http://VOTRE_IP:8000/api`

**Pour trouver votre IP** :
```bash
# Linux
ip addr show | grep "inet " | grep -v 127.0.0.1

# Ou
hostname -I
```

### 2. Configuration Backend (Laravel)

**Fichier** : `/opt/lampp/htdocs/backendCauris/.env`

```env
FEDAPAY_API_KEY=votre_clé_api
FEDAPAY_SECRET_KEY=votre_clé_secrète
FEDAPAY_ENVIRONMENT=sandbox # ou production

# ✅ IMPORTANT : URL pour les callbacks FedaPay
# En développement local, utilisez votre IP locale
APP_URL=http://192.168.1.80:8000
```

**⚠️ Note importante** : FedaPay nécessite une URL HTTPS publique pour les callbacks en production. En développement local avec HTTP, certains callbacks peuvent ne pas fonctionner. Pour tester complètement, vous devrez :
- Soit utiliser un serveur avec domaine et SSL
- Soit utiliser ngrok temporairement pour les tests de callbacks

### 3. Configuration WebSocket

**Fichier** : `lib/config/api_config.dart`

Le WebSocket utilise automatiquement la même IP que l'API :
- API : `http://192.168.1.80:8000/api`
- WebSocket : `ws://192.168.1.80:3000`

## 🚀 Démarrage

### 1. Démarrer Laravel

```bash
cd /opt/lampp/htdocs/backendCauris
php artisan serve --host=0.0.0.0 --port=8000
```

**Important** : Utilisez `--host=0.0.0.0` pour que Laravel soit accessible depuis votre téléphone sur le réseau local.

### 2. Démarrer le serveur WebSocket (si nécessaire)

```bash
cd /opt/lampp/htdocs/backendCauris
# Le serveur WebSocket doit être démarré séparément
```

### 3. Lancer l'application Flutter

```bash
cd /home/adolphe/cauris_app
flutter run
```

**Ou avec une IP spécifique** :
```bash
flutter run --dart-define=BASE_URL=http://192.168.1.80:8000/api
```

## ✅ Vérifications

### Vérifier que Laravel est accessible

```bash
# Depuis votre PC
curl http://192.168.1.80:8000/api/payment/balance

# Depuis votre téléphone (dans un navigateur)
http://192.168.1.80:8000/api/payment/balance
```

### Vérifier la configuration

Le script de vérification a été mis à jour pour ne plus vérifier ngrok :

```bash
cd /home/adolphe/cauris_app
./scripts/check_fedapay_setup.sh
```

## 🔧 Résolution des problèmes

### Problème : "Impossible de se connecter au serveur"

**Causes possibles** :
1. Laravel n'est pas démarré
2. IP incorrecte dans la configuration
3. Téléphone et PC ne sont pas sur le même réseau WiFi
4. Firewall bloque la connexion

**Solutions** :
1. Vérifier que Laravel est démarré : `curl http://192.168.1.80:8000/api/payment/balance`
2. Vérifier l'IP de votre machine : `hostname -I`
3. Vérifier que le téléphone est sur le même WiFi
4. Vérifier le firewall : `sudo ufw status`

### Problème : "502 Bad Gateway" ou "503 Service Unavailable"

**Causes possibles** :
1. Laravel a crashé
2. Port 8000 occupé par autre chose
3. Laravel n'écoute pas sur 0.0.0.0

**Solutions** :
1. Redémarrer Laravel : `php artisan serve --host=0.0.0.0 --port=8000`
2. Vérifier le port : `lsof -i :8000`
3. Vérifier les logs : `tail -f storage/logs/laravel.log`

### Problème : "Timeout"

**Causes possibles** :
1. Connexion internet lente
2. Serveur Laravel trop lent
3. Problème de réseau local

**Solutions** :
1. Vérifier votre connexion internet
2. Vérifier les performances du backend
3. Vérifier que le téléphone et le PC sont bien sur le même réseau

## 📝 Notes importantes

1. **Réseau local requis** : Le téléphone et le PC doivent être sur le même réseau WiFi
2. **IP dynamique** : Si votre IP change, mettez à jour la configuration
3. **FedaPay en production** : Pour la production, vous devrez utiliser un domaine avec SSL (HTTPS)
4. **Callbacks FedaPay** : En développement local avec HTTP, certains callbacks peuvent ne pas fonctionner. FedaPay préfère HTTPS pour les callbacks.

## 🔐 Sécurité

- En développement local, HTTP est acceptable
- En production, utilisez toujours HTTPS
- Ne partagez jamais vos clés API FedaPay
- Vérifiez les signatures des webhooks FedaPay

