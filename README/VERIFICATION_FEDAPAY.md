# 🔍 Vérification du Système FedaPay

## 📋 Problèmes identifiés et solutions

### ⚠️ Problème : Erreur ngrok lors des dépôts

**Symptômes** :
- Erreur lors de l'initiation d'un dépôt via FedaPay
- Message d'erreur mentionnant ngrok
- Impossible de charger la page de paiement

## 🔧 Solutions

### 1. Vérifier que ngrok est actif

```bash
# Vérifier si ngrok est en cours d'exécution
ps aux | grep ngrok

# Vérifier l'interface web ngrok
curl http://localhost:4040/api/tunnels

# Si ngrok n'est pas actif, le démarrer
cd /home/adolphe/cauris_app
./start_ngrok_all.sh
```

### 2. Vérifier l'URL ngrok dans la configuration

**Fichier** : `lib/config/api_config.dart`

```dart
static const String baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'http://192.168.1.80:8000/api', // ⚠️ IP locale
);
```

**Problème** : Si vous utilisez ngrok, l'URL doit être l'URL ngrok HTTPS, pas l'IP locale.

**Solution** :

1. **Récupérer l'URL ngrok** :
```bash
curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*' | head -1 | cut -d'"' -f4
```

2. **Mettre à jour la configuration** :

**Option A : Via --dart-define (recommandé)**
```bash
flutter run --dart-define=BASE_URL=https://votre-url-ngrok.ngrok-free.app/api
```

**Option B : Modifier directement dans api_config.dart**
```dart
static const String baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://votre-url-ngrok.ngrok-free.app/api', // ✅ URL ngrok
);
```

### 3. Vérifier la configuration FedaPay dans le backend

**Fichier backend** : `/opt/lampp/htdocs/backendCauris/.env`

```env
FEDAPAY_API_KEY=votre_clé_api
FEDAPAY_SECRET_KEY=votre_clé_secrète
FEDAPAY_ENVIRONMENT=sandbox # ou production

# ✅ IMPORTANT : URL de callback pour FedaPay
APP_URL=https://votre-url-ngrok.ngrok-free.app
```

**⚠️ CRITIQUE** : FedaPay a besoin d'une URL HTTPS publique pour les callbacks. L'URL doit être :
- En HTTPS (pas HTTP)
- Accessible depuis Internet (pas localhost)
- Stable (ngrok gratuit change l'URL à chaque redémarrage)

### 4. Vérifier que le backend Laravel est accessible

```bash
# Vérifier que Laravel répond
curl http://localhost:8000/api/payment/balance

# Vérifier via ngrok
curl https://votre-url-ngrok.ngrok-free.app/api/payment/balance
```

### 5. Vérifier les logs

**Logs ngrok** :
```bash
tail -f ~/ngrok_all.log
```

**Logs Laravel** :
```bash
tail -f /opt/lampp/htdocs/backendCauris/storage/logs/laravel.log
```

**Logs Flutter** : Consultez la console où vous avez lancé l'application

## 🐛 Diagnostic des erreurs courantes

### Erreur 1 : "Connection refused" ou "SocketException"

**Cause** : Le backend Laravel n'est pas démarré ou ngrok n'est pas actif.

**Solution** :
```bash
# Démarrer Laravel
cd /opt/lampp/htdocs/backendCauris
php artisan serve

# Démarrer ngrok
cd /home/adolphe/cauris_app
./start_ngrok_all.sh
```

### Erreur 2 : "502 Bad Gateway" ou "503 Service Unavailable"

**Cause** : ngrok ne peut pas atteindre le backend Laravel.

**Solution** :
1. Vérifier que Laravel est sur le port 8000
2. Vérifier que ngrok pointe vers le bon port
3. Vérifier les logs ngrok pour plus de détails

### Erreur 3 : "URL de paiement invalide"

**Cause** : Le backend retourne une URL de paiement invalide ou vide.

**Solution** :
1. Vérifier les logs du backend Laravel
2. Vérifier la configuration FedaPay dans `.env`
3. Vérifier que les clés API FedaPay sont correctes

### Erreur 4 : "Timeout" ou "Request timeout"

**Cause** : La connexion prend trop de temps.

**Solution** :
1. Vérifier votre connexion internet
2. Vérifier que ngrok n'est pas surchargé
3. Augmenter le timeout dans le code (déjà à 30 secondes)

## ✅ Checklist de vérification

Avant de tester un dépôt, vérifiez :

- [ ] Laravel est démarré sur le port 8000
- [ ] ngrok est actif et accessible
- [ ] L'URL ngrok est correcte dans `api_config.dart`
- [ ] L'URL ngrok est configurée dans `.env` du backend (APP_URL)
- [ ] Les clés API FedaPay sont correctes dans `.env`
- [ ] Le backend répond via ngrok : `curl https://votre-url-ngrok/api/payment/balance`
- [ ] Les logs ne montrent pas d'erreurs

## 🔄 Test rapide

```bash
# 1. Démarrer tous les services
cd /home/adolphe/cauris_app
./start_all.sh

# 2. Récupérer l'URL ngrok
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*' | head -1 | cut -d'"' -f4)
echo "URL ngrok: $NGROK_URL/api"

# 3. Tester l'endpoint de paiement
curl -X POST "$NGROK_URL/api/payment/deposit" \
  -H "Authorization: Bearer VOTRE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"amount_fcfa": 1000, "phone_number": "229XXXXXXXX"}'
```

## 📝 Notes importantes

1. **ngrok gratuit** : L'URL change à chaque redémarrage. Pour une URL stable, utilisez :
   - Un compte ngrok payant avec domaine réservé
   - Un serveur avec domaine et SSL (production)

2. **FedaPay en production** : 
   - Utilisez un domaine avec SSL (HTTPS)
   - Configurez les webhooks dans le dashboard FedaPay
   - Utilisez les clés API de production

3. **Sécurité** :
   - Ne partagez jamais vos clés API
   - Utilisez HTTPS en production
   - Vérifiez les signatures des webhooks FedaPay

## 🆘 Support

Si le problème persiste :
1. Consultez les logs détaillés (voir section "Vérifier les logs")
2. Vérifiez la documentation FedaPay : https://docs.fedapay.com
3. Contactez le support FedaPay si nécessaire

