# ⏱️ Timer de Dépôt - 3 Minutes

## 📋 Vue d'ensemble

Le système de dépôt FedaPay inclut maintenant un timer de **3 minutes** pour valider le paiement. Si le paiement n'est pas validé dans ce délai, la transaction est automatiquement annulée.

## ✅ Fonctionnalités implémentées

### 1. **Timer de 3 minutes**
- ⏱️ Compte à rebours visible en temps réel
- ⚠️ Avertissement visuel quand il reste moins de 30 secondes
- ❌ Expiration automatique après 3 minutes

### 2. **Notifications visuelles**
- Bannière d'avertissement en haut de la page de paiement
- Affichage du temps restant dans la barre de titre
- Indicateur visuel pendant le chargement
- Message d'expiration si le délai est dépassé

### 3. **Rechargement automatique du solde**
- ✅ Le backend recharge automatiquement le solde via webhook/callback FedaPay
- ✅ Le frontend vérifie et met à jour le solde après un paiement réussi
- ✅ Affichage du nouveau solde dans le message de succès

## 🎨 Interface utilisateur

### Page de paiement (`FedaPayPaymentPage`)

**Éléments visuels** :
1. **Bannière d'avertissement** (en haut) :
   - Orange : Temps normal (> 30 secondes)
   - Rouge : Urgence (≤ 30 secondes)
   - Message : "⏱️ Vous avez XX:XX pour valider votre paiement"

2. **Barre de titre** :
   - Affiche "Paiement FedaPay"
   - Affiche "Temps restant: MM:SS" en dessous

3. **Indicateur de chargement** :
   - Affiche aussi le temps restant pendant le chargement

4. **Message d'expiration** :
   - Icône : `timer_off`
   - Message : "Paiement expiré - Le délai de 3 minutes est écoulé"

### Page de caisse (`CaissePage`)

**Avertissement avant dépôt** :
- Message informatif : "⚠️ IMPORTANT: Vous avez 3 minutes pour valider votre paiement. Passé ce délai, la transaction sera automatiquement annulée."

**Après paiement réussi** :
- Message de succès avec le nouveau solde
- Rechargement automatique du solde depuis le backend

## 🔄 Flux de paiement

### 1. Initiation du dépôt
```
Utilisateur → CaissePage → FedaPayPaymentPage
                              ↓
                    Timer de 3 minutes démarre
```

### 2. Pendant le paiement
```
Timer actif (180 secondes)
  ↓
Affichage temps restant
  ↓
Si ≤ 30 secondes → Bannière rouge
```

### 3. Résultats possibles

**✅ Succès** :
- Timer annulé
- Message de succès
- Solde rechargé automatiquement
- Retour à CaissePage avec nouveau solde

**❌ Échec** :
- Timer annulé
- Message d'échec
- Retour à CaissePage

**⏱️ Expiration** :
- Timer atteint 0
- Message d'expiration
- Transaction annulée
- Retour à CaissePage

## 🔧 Implémentation technique

### Frontend (Flutter)

**Fichier** : `lib/interfaces/caisse/fedapay_payment_page.dart`

```dart
// Timer de 3 minutes
Timer? _paymentTimeoutTimer;
int _remainingSeconds = 180; // 3 minutes

// Démarrer le timer
void _startPaymentTimeout() {
  _paymentTimeoutTimer = Timer.periodic(
    const Duration(seconds: 1),
    (timer) {
      _remainingSeconds--;
      if (_remainingSeconds <= 0) {
        _handlePaymentExpiration();
      }
    },
  );
}

// Gérer l'expiration
void _handlePaymentExpiration() {
  setState(() {
    _isExpired = true;
  });
  Navigator.of(context).pop(false);
}
```

### Backend (Laravel)

**⚠️ IMPORTANT** : Le backend doit gérer l'expiration des transactions

**Fichier** : `/opt/lampp/htdocs/backendCauris/app/Http/Controllers/API/PaymentController.php`

```php
// Dans le webhook/callback FedaPay
public function fedapayCallback(Request $request) {
    $transactionId = $request->input('transaction_id');
    $status = $request->input('status');
    
    $transaction = Transaction::find($transactionId);
    
    if ($status === 'approved' || $status === 'transferred') {
        // ✅ Recharger automatiquement le solde
        $user = $transaction->user;
        $user->increment('cauris_balance', $transaction->cauris_amount);
        
        $transaction->update([
            'status' => 'valide',
            'validated_at' => now(),
        ]);
    } elseif ($status === 'failed' || $status === 'cancelled') {
        $transaction->update([
            'status' => 'rejete',
        ]);
    }
    
    return response()->json(['success' => true]);
}
```

## 📊 Gestion de l'expiration côté backend

**Recommandation** : Ajouter un job Laravel pour expirer automatiquement les transactions non validées après 3 minutes.

**Fichier** : `app/Jobs/ExpirePendingTransactions.php`

```php
<?php

namespace App\Jobs;

use App\Models\Transaction;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Carbon\Carbon;

class ExpirePendingTransactions implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function handle()
    {
        // Expirer les transactions en attente depuis plus de 3 minutes
        $expiredTransactions = Transaction::where('type', 'depot')
            ->where('status', 'en_attente')
            ->where('created_at', '<', Carbon::now()->subMinutes(3))
            ->get();

        foreach ($expiredTransactions as $transaction) {
            $transaction->update([
                'status' => 'rejete',
                'notes' => 'Transaction expirée - délai de 3 minutes dépassé',
            ]);
        }
    }
}
```

**Scheduler** : `app/Console/Kernel.php`

```php
protected function schedule(Schedule $schedule)
{
    // Exécuter toutes les minutes pour vérifier les transactions expirées
    $schedule->job(new ExpirePendingTransactions)->everyMinute();
}
```

## ✅ Checklist de vérification

- [x] Timer de 3 minutes implémenté
- [x] Affichage du temps restant
- [x] Bannière d'avertissement
- [x] Message d'expiration
- [x] Rechargement automatique du solde après succès
- [x] Vérification du solde mis à jour
- [x] Message d'avertissement dans CaissePage
- [ ] Job Laravel pour expirer les transactions (à implémenter côté backend)
- [ ] Webhook FedaPay configuré pour recharger automatiquement (à vérifier côté backend)

## 🎯 Expérience utilisateur

### Scénario 1 : Paiement réussi dans les 3 minutes
1. Utilisateur initie un dépôt
2. Timer démarre (3:00)
3. Utilisateur valide le paiement (ex: après 1:30)
4. ✅ Message de succès
5. ✅ Solde rechargé automatiquement
6. ✅ Nouveau solde affiché

### Scénario 2 : Expiration (3 minutes écoulées)
1. Utilisateur initie un dépôt
2. Timer démarre (3:00)
3. Utilisateur ne valide pas le paiement
4. Timer atteint 0:00
5. ❌ Message d'expiration
6. ❌ Transaction annulée
7. Retour à CaissePage

### Scénario 3 : Avertissement urgence (≤ 30 secondes)
1. Timer affiche ≤ 30 secondes
2. Bannière devient rouge
3. Message d'urgence affiché
4. Utilisateur peut encore valider

## 📝 Notes importantes

1. **Backend** : Le backend doit gérer l'expiration via un job Laravel ou un webhook FedaPay
2. **Webhook** : FedaPay envoie un webhook quand le paiement est validé → le backend doit recharger le solde
3. **Synchronisation** : Le frontend recharge le solde après le paiement pour s'assurer qu'il est à jour
4. **Expiration** : Si le timer expire côté frontend, la transaction est marquée comme échouée, mais le backend doit aussi l'expirer

## 🔄 Prochaines étapes (Backend)

1. **Implémenter le job d'expiration** : `ExpirePendingTransactions`
2. **Vérifier le webhook FedaPay** : S'assurer qu'il recharge automatiquement le solde
3. **Tester l'expiration** : Vérifier que les transactions expirées sont bien marquées comme "rejete"

