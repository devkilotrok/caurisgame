# 💰 Système de Paiement Cauris

## 📋 Vue d'ensemble

Le système de paiement gère automatiquement les débits et crédits lors de la création et du rejoignement des salons.

## 🔄 Fonctionnement

### 1. Création d'un salon
**Flux** :
1. User choisit une mise minimum (ex: 50 cauris)
2. Vérification que le solde est suffisant
3. Si oui → Débit du compte user, crédit au compte entreprise
4. Salon créé

### 2. Rejoindre un salon
**Flux** :
1. User essaie de rejoindre un salon avec mise minimum (ex: 50 cauris)
2. Vérification que le solde est suffisant
3. Si oui → Débit, crédit entreprise
4. User rejoint le salon
5. Si non → Erreur "Solde insuffisant"

## 🗄️ Base de données

### Colonnes ajoutées dans `users`

```sql
cauris_balance INT DEFAULT 0      -- Solde du joueur
company_balance INT DEFAULT 0     -- Solde de l'entreprise
```

### Migration

**Fichier** : `database/migration_add_balance.sql`

```bash
mysql -u root < database/migration_add_balance.sql
```

## 📁 Fichiers créés

### Backend Laravel

1. **`app/Http/Controllers/API/PaymentController.php`**
   - `getBalance()` - Obtenir le solde
   - `checkBalance()` - Vérifier si suffisant
   - `debitRoomBet()` - Débiter pour créer/rejoindre
   - `creditRoomBet()` - Créditer en cas d'annulation

2. **Routes** (`routes/api.php`)
   - `GET /api/payment/balance`
   - `GET /api/payment/check-balance`
   - `POST /api/payment/debit-room-bet`
   - `POST /api/payment/credit-room-bet`

### Frontend Flutter

1. **`lib/services/api/payment_api_service.dart`**
   - Service API pour les paiements
   - Vérifications et débits/crédits

## ✅ Modifications apportées

### 1. Table `users`

Ajout de 2 colonnes :
- `cauris_balance` : Solde du joueur (défaut 0)
- `company_balance` : Solde entreprise (géré par admin)

### 2. Compte entreprise

Le solde entreprise est stocké dans le premier compte admin :
```sql
UPDATE users 
SET company_balance = 1000000 
WHERE is_admin = TRUE 
LIMIT 1;
```

### 3. Débit automatique

**Lors de la création** :
```php
// Vérifier le solde
if ($user->cauris_balance < $minimum_bet) {
    return error('Solde insuffisant');
}

// Débiter l'utilisateur
$user->decrement('cauris_balance', $amount);

// Créditer l'entreprise
$companyUser->increment('company_balance', $amount);
```

**Lors du rejoignement** :
Même processus automatique.

## 🎯 Exemple d'utilisation

### Scénario 1 : Création de salon

```
Solde initial joueur : 500 cauris
Mise minimum : 50 cauris
→ Vérification : 500 >= 50 ✅
→ Débit : 500 - 50 = 450 cauris
→ Crédit entreprise : +50 cauris
```

### Scénario 2 : Rejoindre un salon

```
Solde joueur : 450 cauris
Mise salon : 50 cauris
→ Vérification : 450 >= 50 ✅
→ Débit : 450 - 50 = 400 cauris
→ Crédit entreprise : +50 cauris
```

### Scénario 3 : Solde insuffisant

```
Solde joueur : 30 cauris
Mise salon : 50 cauris
→ Vérification : 30 >= 50 ❌
→ Erreur : "Solde insuffisant. Il vous manque 20 cauris"
```

## 📝 Prochaines étapes

### Backend
- [x] Ajouter colonnes dans `users`
- [x] Créer `PaymentController`
- [x] Ajouter routes
- [ ] Tester les endpoints
- [ ] Initialiser le solde entreprise

### Frontend
- [x] Créer `PaymentApiService`
- [ ] Modifier `RoomManager.createRoom()` pour appeler l'API
- [ ] Modifier `RoomManager.joinRoom()` pour appeler l'API
- [ ] Afficher le solde dans l'interface
- [ ] Gérer l'erreur "Solde insuffisant"

## 🔧 Configuration

### 1. Importer la migration

```bash
mysql -u root cauris_db < database/migration_add_balance.sql
```

### 2. Initialiser les soldes

```sql
USE cauris_db;

-- Ajouter 1000 cauris à quelques utilisateurs de test
UPDATE users 
SET cauris_balance = 1000 
WHERE is_admin = FALSE 
LIMIT 3;

-- Initialiser le solde entreprise
UPDATE users 
SET company_balance = 1000000 
WHERE is_admin = TRUE 
LIMIT 1;
```

### 3. Vérifier

```sql
-- Voir les soldes
SELECT user_id, pseudo, cauris_balance, company_balance 
FROM users 
ORDER BY is_admin DESC, user_id;
```

## ✅ Checklist

- [x] Ajouter colonnes dans `users`
- [x] Créer migration SQL
- [x] Créer `PaymentController`
- [x] Ajouter routes API
- [x] Créer `PaymentApiService` Flutter
- [ ] Intégrer dans `RoomManager.createRoom()`
- [ ] Intégrer dans `RoomManager.joinRoom()`
- [ ] Tester le flux complet
- [ ] Gérer les erreurs UI

## 🎯 Résumé

Le système est prêt à fonctionner ! Il ne reste plus qu'à :
1. Exécuter la migration
2. Initialiser les soldes
3. Connecter les appels API dans Flutter
4. Tester

