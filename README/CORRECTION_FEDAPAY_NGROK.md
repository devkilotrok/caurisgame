# 🔧 Corrections du Système FedaPay - Problème ngrok

## ✅ Améliorations apportées

### 1. **Vérification automatique de connectivité**

Avant chaque dépôt, le système vérifie maintenant automatiquement si le backend est accessible :

```dart
// Nouvelle méthode dans PaymentApiService
Future<Map<String, dynamic>> checkBackendConnectivity()
```

**Avantages** :
- Détecte les problèmes de connexion AVANT d'essayer le dépôt
- Messages d'erreur plus clairs et spécifiques
- Évite les timeouts inutiles

### 2. **Messages d'erreur améliorés**

Les messages d'erreur incluent maintenant :
- ✅ Détection automatique des erreurs ngrok
- ✅ Instructions étape par étape pour résoudre le problème
- ✅ Commandes exactes à exécuter
- ✅ Vérification des logs

### 3. **Gestion spécifique des erreurs ngrok**

Le système détecte automatiquement :
- Erreurs 502/503 (Bad Gateway / Service Unavailable)
- Erreurs de tunnel ngrok
- Timeouts de connexion
- Erreurs SocketException

### 4. **Script de vérification automatique**

Nouveau script : `scripts/check_fedapay_setup.sh`

**Utilisation** :
```bash
cd /home/adolphe/cauris_app
./scripts/check_fedapay_setup.sh
```

**Vérifie** :
- ✅ Laravel est démarré
- ✅ ngrok est actif
- ✅ Configuration FedaPay dans .env
- ✅ Logs récents pour erreurs
- ✅ URL ngrok accessible

## 🚀 Utilisation

### Étape 1 : Vérifier la configuration

```bash
cd /home/adolphe/cauris_app
./scripts/check_fedapay_setup.sh
```

### Étape 2 : Démarrer les services (si nécessaire)

```bash
# Terminal 1 : Laravel
cd /opt/lampp/htdocs/backendCauris
php artisan serve

# Terminal 2 : ngrok
cd /home/adolphe/cauris_app
./start_ngrok_all.sh
```

### Étape 3 : Récupérer l'URL ngrok

```bash
curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*' | head -1 | cut -d'"' -f4
```

### Étape 4 : Lancer l'app avec l'URL ngrok

```bash
# Remplacer VOTRE-URL-NGROK par l'URL obtenue à l'étape 3
flutter run --dart-define=BASE_URL=https://VOTRE-URL-NGROK/api
```

## 🔍 Diagnostic des erreurs

### Erreur : "Backend non accessible"

**Causes possibles** :
1. Laravel n'est pas démarré
2. ngrok n'est pas actif
3. URL incorrecte dans ApiConfig

**Solutions** :
1. Vérifier Laravel : `curl http://localhost:8000/api/payment/balance`
2. Vérifier ngrok : `curl http://localhost:4040/api/tunnels`
3. Vérifier l'URL : Regarder les logs de l'app

### Erreur : "502 Bad Gateway" ou "503 Service Unavailable"

**Causes possibles** :
1. ngrok ne peut pas atteindre Laravel
2. Laravel a crashé
3. Port 8000 occupé par autre chose

**Solutions** :
1. Redémarrer Laravel : `php artisan serve`
2. Vérifier les logs Laravel : `tail -f storage/logs/laravel.log`
3. Vérifier que le port 8000 est libre : `lsof -i :8000`

### Erreur : "Timeout"

**Causes possibles** :
1. Connexion internet lente
2. ngrok surchargé
3. Backend Laravel trop lent

**Solutions** :
1. Vérifier votre connexion internet
2. Redémarrer ngrok
3. Vérifier les performances du backend

## 📝 Configuration requise

### Backend Laravel (.env)

```env
FEDAPAY_API_KEY=votre_clé_api
FEDAPAY_SECRET_KEY=votre_clé_secrète
FEDAPAY_ENVIRONMENT=sandbox # ou production

# ✅ IMPORTANT : URL HTTPS publique pour les callbacks
APP_URL=https://votre-url-ngrok.ngrok-free.app
```

### Frontend Flutter

**Option 1 : Via --dart-define (recommandé)**
```bash
flutter run --dart-define=BASE_URL=https://votre-url-ngrok.ngrok-free.app/api
```

**Option 2 : Modifier api_config.dart**
```dart
static const String baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://votre-url-ngrok.ngrok-free.app/api',
);
```

## ✅ Checklist avant un dépôt

- [ ] Laravel est démarré : `curl http://localhost:8000/api/payment/balance`
- [ ] ngrok est actif : `curl http://localhost:4040/api/tunnels`
- [ ] URL ngrok est correcte dans ApiConfig.baseUrl
- [ ] APP_URL est configuré dans .env du backend
- [ ] Clés API FedaPay sont correctes dans .env
- [ ] Backend répond via ngrok : `curl https://votre-url-ngrok/api/payment/balance`
- [ ] Aucune erreur dans les logs récents

## 🆘 Support

Si le problème persiste après avoir suivi toutes les étapes :

1. **Consulter les logs** :
   ```bash
   # Logs ngrok
   tail -f ~/ngrok_all.log
   
   # Logs Laravel
   tail -f /opt/lampp/htdocs/backendCauris/storage/logs/laravel.log
   ```

2. **Exécuter le script de vérification** :
   ```bash
   ./scripts/check_fedapay_setup.sh
   ```

3. **Tester manuellement** :
   ```bash
   # Tester l'endpoint de dépôt
   curl -X POST "https://votre-url-ngrok/api/payment/deposit" \
     -H "Authorization: Bearer VOTRE_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"amount_fcfa": 1000, "phone_number": "229XXXXXXXX"}'
   ```

4. **Vérifier la documentation FedaPay** : https://docs.fedapay.com

