# 📱 Intégration Directe MTN Mobile Money (Sans FedaPay)

## 📋 Vue d'ensemble

Il est **techniquement possible** d'intégrer directement l'API MTN Mobile Money pour les dépôts, sans passer par FedaPay, comme le fait BetPawa.

## ✅ Avantages de l'intégration directe

1. **Coûts réduits** : Pas de commission intermédiaire (FedaPay prend ~2-3% par transaction)
2. **Contrôle total** : Gestion directe des transactions et des webhooks
3. **Meilleure expérience utilisateur** : Interface personnalisée, pas de redirection
4. **Performance** : Moins de latence, pas de dépendance à un tiers

## ⚠️ Inconvénients et exigences

1. **Démarches administratives** :
   - Création d'un compte développeur MTN
   - Accord commercial avec MTN
   - Vérification de conformité réglementaire
   - Certification de sécurité

2. **Complexité technique** :
   - Gestion de la sécurité (OAuth2, tokens, signatures)
   - Gestion des webhooks et callbacks
   - Gestion des erreurs et retry logic
   - Monitoring et logging

3. **Support** :
   - Support technique à gérer en interne
   - Documentation MTN parfois limitée

## 🔧 Étapes d'intégration

### 1. Créer un compte développeur MTN

**Pour le Bénin** :
- Portail : https://developer.mtn.com/ (ou portail local MTN Bénin)
- Contact : Service commercial MTN Bénin

**Pour le Togo** :
- Portail : https://developer.mtn.com/ (ou portail local MTN Togo)
- Contact : Service commercial MTN Togo

**Pour la Côte d'Ivoire** :
- Portail : https://www.mtn.ci/momo/developpeurs/
- Documentation : API MoMo Pay et Cash Collect

### 2. Obtenir les clés API

Une fois le compte créé, vous recevrez :
- `api_key` : Clé API publique
- `api_secret` : Clé secrète (à garder confidentielle)
- `subscription_key` : Clé d'abonnement
- `environment` : Sandbox ou Production
- `callback_url` : URL pour recevoir les notifications

### 3. APIs MTN Mobile Money disponibles

#### A. **MoMo Pay** (Collecte de fonds)
- Permet de collecter des paiements depuis un compte MTN Mobile Money
- Utilisé pour les dépôts dans votre application

#### B. **Cash Collect** (Déboursement)
- Permet d'envoyer de l'argent à un compte MTN Mobile Money
- Utilisé pour les retraits

#### C. **Disbursement** (Déboursement multiple)
- Permet d'envoyer de l'argent à plusieurs comptes
- Utile pour les promotions ou remboursements

## 💻 Exemple d'intégration backend (Laravel)

### Structure de base

```php
<?php
// app/Services/MtnMobileMoneyService.php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class MtnMobileMoneyService
{
    private $apiKey;
    private $apiSecret;
    private $subscriptionKey;
    private $baseUrl;
    private $callbackUrl;
    
    public function __construct()
    {
        $this->apiKey = config('mtn.api_key');
        $this->apiSecret = config('mtn.api_secret');
        $this->subscriptionKey = config('mtn.subscription_key');
        $this->baseUrl = config('mtn.environment') === 'production' 
            ? 'https://api.mtn.com/v1' 
            : 'https://sandbox.momodeveloper.mtn.com/v1';
        $this->callbackUrl = config('app.url') . '/api/payment/mtn/callback';
    }
    
    /**
     * Obtenir un token d'accès OAuth2
     */
    private function getAccessToken(): string
    {
        $response = Http::withBasicAuth($this->apiKey, $this->apiSecret)
            ->post("{$this->baseUrl}/collection/token/", [
                'grant_type' => 'client_credentials',
            ]);
            
        if ($response->successful()) {
            $data = $response->json();
            return $data['access_token'];
        }
        
        throw new \Exception('Erreur lors de l\'obtention du token MTN');
    }
    
    /**
     * Initier un paiement (dépôt)
     * 
     * @param string $phoneNumber Numéro MTN (ex: 229XXXXXXXX)
     * @param int $amount Montant en FCFA
     * @param string $reference Référence unique de la transaction
     * @return array
     */
    public function initiatePayment(string $phoneNumber, int $amount, string $reference): array
    {
        try {
            $accessToken = $this->getAccessToken();
            
            $response = Http::withHeaders([
                'Authorization' => "Bearer {$accessToken}",
                'X-Target-Environment' => config('mtn.environment'),
                'X-Callback-Url' => $this->callbackUrl,
                'Content-Type' => 'application/json',
            ])
            ->post("{$this->baseUrl}/collection/v1_0/requesttopay", [
                'amount' => (string) $amount,
                'currency' => 'XOF', // FCFA
                'externalId' => $reference,
                'payer' => [
                    'partyIdType' => 'MSISDN',
                    'partyId' => $phoneNumber,
                ],
                'payerMessage' => "Dépôt de {$amount} FCFA",
                'payeeNote' => "Transaction {$reference}",
            ]);
            
            if ($response->successful()) {
                return [
                    'success' => true,
                    'transaction_id' => $reference,
                    'status' => 'PENDING',
                    'message' => 'Paiement initié avec succès',
                ];
            }
            
            return [
                'success' => false,
                'message' => $response->json()['message'] ?? 'Erreur lors de l\'initiation du paiement',
            ];
            
        } catch (\Exception $e) {
            Log::error('Erreur MTN Mobile Money: ' . $e->getMessage());
            return [
                'success' => false,
                'message' => 'Erreur technique: ' . $e->getMessage(),
            ];
        }
    }
    
    /**
     * Vérifier le statut d'une transaction
     */
    public function checkTransactionStatus(string $reference): array
    {
        try {
            $accessToken = $this->getAccessToken();
            
            $response = Http::withHeaders([
                'Authorization' => "Bearer {$accessToken}",
                'X-Target-Environment' => config('mtn.environment'),
            ])
            ->get("{$this->baseUrl}/collection/v1_0/requesttopay/{$reference}");
            
            if ($response->successful()) {
                $data = $response->json();
                return [
                    'success' => true,
                    'status' => $data['status'] ?? 'UNKNOWN',
                    'amount' => $data['amount'] ?? 0,
                    'currency' => $data['currency'] ?? 'XOF',
                ];
            }
            
            return [
                'success' => false,
                'message' => 'Transaction non trouvée',
            ];
            
        } catch (\Exception $e) {
            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }
}
```

### Configuration (config/mtn.php)

```php
<?php

return [
    'api_key' => env('MTN_API_KEY'),
    'api_secret' => env('MTN_API_SECRET'),
    'subscription_key' => env('MTN_SUBSCRIPTION_KEY'),
    'environment' => env('MTN_ENVIRONMENT', 'sandbox'), // sandbox ou production
];
```

### Controller (app/Http/Controllers/API/PaymentController.php)

```php
<?php

namespace App\Http\Controllers\API;

use App\Services\MtnMobileMoneyService;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class PaymentController extends Controller
{
    protected $mtnService;
    
    public function __construct(MtnMobileMoneyService $mtnService)
    {
        $this->mtnService = $mtnService;
    }
    
    /**
     * Initier un dépôt via MTN Mobile Money
     * POST /api/payment/deposit-mtn
     */
    public function depositMtn(Request $request)
    {
        $request->validate([
            'amount_fcfa' => 'required|integer|min:100',
            'phone_number' => 'required|string|regex:/^229\d{8}$/', // Format Bénin
        ]);
        
        $user = auth()->user();
        $amount = $request->amount_fcfa;
        $phoneNumber = $request->phone_number;
        
        // Calculer le nombre de cauris (ex: 1 FCFA = 1 cauris)
        $cauris = $amount;
        
        // Créer une transaction en attente
        $transaction = Transaction::create([
            'user_id' => $user->user_id,
            'type' => 'depot',
            'fcfa_amount' => $amount,
            'cauris_amount' => $cauris,
            'status' => 'en_attente',
            'phone_number' => $phoneNumber,
        ]);
        
        // Générer une référence unique
        $reference = 'DEP' . $transaction->transaction_id . '_' . Str::random(8);
        
        // Initier le paiement MTN
        $result = $this->mtnService->initiatePayment(
            $phoneNumber,
            $amount,
            $reference
        );
        
        if ($result['success']) {
            // Mettre à jour la transaction avec la référence MTN
            $transaction->update([
                'mtn_reference' => $reference,
                'mtn_status' => 'PENDING',
            ]);
            
            return response()->json([
                'success' => true,
                'message' => 'Paiement initié avec succès',
                'data' => [
                    'transaction_id' => $transaction->transaction_id,
                    'reference' => $reference,
                    'amount' => $amount,
                    'cauris' => $cauris,
                    'phone_number' => $phoneNumber,
                    'status' => 'PENDING',
                ],
            ]);
        }
        
        return response()->json([
            'success' => false,
            'message' => $result['message'] ?? 'Erreur lors de l\'initiation du paiement',
        ], 400);
    }
    
    /**
     * Webhook MTN pour les notifications de paiement
     * POST /api/payment/mtn/callback
     */
    public function mtnCallback(Request $request)
    {
        // Vérifier la signature MTN (important pour la sécurité)
        $signature = $request->header('X-MTN-Signature');
        if (!$this->verifyMtnSignature($request, $signature)) {
            return response()->json(['error' => 'Signature invalide'], 401);
        }
        
        $data = $request->all();
        $reference = $data['externalId'] ?? null;
        
        if (!$reference) {
            return response()->json(['error' => 'Référence manquante'], 400);
        }
        
        // Trouver la transaction
        $transaction = Transaction::where('mtn_reference', $reference)->first();
        
        if (!$transaction) {
            return response()->json(['error' => 'Transaction non trouvée'], 404);
        }
        
        $status = $data['status'] ?? 'UNKNOWN';
        
        // Mettre à jour la transaction selon le statut
        if ($status === 'SUCCESSFUL') {
            $transaction->update([
                'status' => 'valide',
                'mtn_status' => 'SUCCESSFUL',
                'validated_at' => now(),
            ]);
            
            // Créditer le compte utilisateur
            $user = $transaction->user;
            $user->increment('cauris_balance', $transaction->cauris_amount);
            
            // Notifier l'utilisateur (push notification, email, etc.)
            // ...
        } elseif ($status === 'FAILED') {
            $transaction->update([
                'status' => 'rejete',
                'mtn_status' => 'FAILED',
            ]);
        }
        
        return response()->json(['success' => true]);
    }
    
    /**
     * Vérifier la signature MTN (sécurité)
     */
    private function verifyMtnSignature(Request $request, string $signature): bool
    {
        // Implémenter la vérification de signature selon la documentation MTN
        // Généralement, c'est une signature HMAC-SHA256
        $payload = $request->getContent();
        $expectedSignature = hash_hmac('sha256', $payload, config('mtn.api_secret'));
        
        return hash_equals($expectedSignature, $signature);
    }
}
```

## 📱 Exemple d'intégration frontend (Flutter)

### Service API (lib/services/api/mtn_payment_service.dart)

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../user/user_service.dart';
import '../../config/api_config.dart';

class MtnPaymentService {
  static MtnPaymentService? _instance;
  static MtnPaymentService get instance => _instance ??= MtnPaymentService._internal();
  
  MtnPaymentService._internal();
  
  static String get _baseUrl => ApiConfig.baseUrl;
  
  /// Initier un dépôt via MTN Mobile Money
  Future<Map<String, dynamic>> deposit({
    required int amountFcfa,
    required String phoneNumber,
  }) async {
    try {
      final token = UserService.instance.authToken;
      if (token == null) {
        return {'success': false, 'message': 'Non authentifié'};
      }
      
      final response = await http.post(
        Uri.parse('$_baseUrl/payment/deposit-mtn'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'amount_fcfa': amountFcfa,
          'phone_number': phoneNumber,
        }),
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'transaction_id': data['data']['transaction_id'],
          'reference': data['data']['reference'],
          'amount': data['data']['amount'],
          'cauris': data['data']['cauris'],
          'phone_number': data['data']['phone_number'],
          'status': data['data']['status'],
        };
      }
      
      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['message'] ?? 'Erreur lors de l\'initiation du paiement',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }
  
  /// Vérifier le statut d'une transaction
  Future<Map<String, dynamic>> checkStatus(String reference) async {
    try {
      final token = UserService.instance.authToken;
      if (token == null) {
        return {'success': false, 'message': 'Non authentifié'};
      }
      
      final response = await http.get(
        Uri.parse('$_baseUrl/payment/mtn/status/$reference'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'status': data['status'],
          'amount': data['amount'],
        };
      }
      
      return {'success': false, 'message': 'Transaction non trouvée'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }
}
```

### Page de paiement MTN (lib/interfaces/caisse/mtn_payment_page.dart)

```dart
import 'package:flutter/material.dart';
import '../../services/api/mtn_payment_service.dart';

class MtnPaymentPage extends StatefulWidget {
  final int amountFcfa;
  final String phoneNumber;
  final String reference;
  
  const MtnPaymentPage({
    super.key,
    required this.amountFcfa,
    required this.phoneNumber,
    required this.reference,
  });
  
  @override
  State<MtnPaymentPage> createState() => _MtnPaymentPageState();
}

class _MtnPaymentPageState extends State<MtnPaymentPage> {
  bool _isChecking = false;
  String _status = 'PENDING';
  
  @override
  void initState() {
    super.initState();
    _startPolling();
  }
  
  /// Vérifier périodiquement le statut du paiement
  void _startPolling() {
    Future.delayed(const Duration(seconds: 3), () {
      _checkStatus();
    });
  }
  
  Future<void> _checkStatus() async {
    if (_isChecking || _status != 'PENDING') return;
    
    setState(() => _isChecking = true);
    
    final result = await MtnPaymentService.instance.checkStatus(widget.reference);
    
    if (result['success'] == true) {
      final status = result['status'] as String;
      
      if (status == 'SUCCESSFUL') {
        setState(() => _status = 'SUCCESS');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        });
      } else if (status == 'FAILED') {
        setState(() => _status = 'FAILED');
      } else {
        // Continuer à vérifier
        _startPolling();
      }
    }
    
    setState(() => _isChecking = false);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement MTN Mobile Money'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo MTN
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.yellow,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(Icons.phone_android, size: 50, color: Colors.black),
              ),
              const SizedBox(height: 24),
              
              // Instructions
              Text(
                'Un code USSD a été envoyé à votre numéro',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.phoneNumber,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              // Montant
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text('Montant à payer'),
                    Text(
                      '${widget.amountFcfa} FCFA',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Instructions
              const Text(
                '1. Composez *150# sur votre téléphone\n'
                '2. Suivez les instructions pour confirmer le paiement\n'
                '3. Le paiement sera validé automatiquement',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Statut
              if (_isChecking)
                const CircularProgressIndicator()
              else if (_status == 'SUCCESS')
                const Icon(Icons.check_circle, color: Colors.green, size: 64)
              else if (_status == 'FAILED')
                const Icon(Icons.error, color: Colors.red, size: 64),
            ],
          ),
        ),
      ),
    );
  }
}
```

## 🔐 Sécurité

1. **Vérification des signatures** : Toujours vérifier les signatures MTN dans les webhooks
2. **HTTPS obligatoire** : Toutes les communications doivent être en HTTPS
3. **Stockage sécurisé** : Les clés API doivent être dans `.env`, jamais dans le code
4. **Rate limiting** : Limiter le nombre de requêtes pour éviter les abus
5. **Logging** : Logger toutes les transactions pour audit

## 📊 Comparaison FedaPay vs MTN Direct

| Critère | FedaPay | MTN Direct |
|---------|---------|------------|
| **Coût** | ~2-3% par transaction | Négociable avec MTN |
| **Complexité** | Faible | Élevée |
| **Temps d'intégration** | 1-2 jours | 1-2 semaines |
| **Support** | Support FedaPay | Support interne |
| **Contrôle** | Limité | Total |
| **Démarches** | Rapides | Longues (contrat MTN) |

## 🚀 Recommandation

**Pour démarrer rapidement** : Utiliser FedaPay
**Pour optimiser les coûts à long terme** : Intégrer directement MTN après avoir obtenu un volume de transactions significatif

## 📞 Contacts MTN

- **Bénin** : Contactez le service commercial MTN Bénin
- **Togo** : Contactez le service commercial MTN Togo
- **Côte d'Ivoire** : https://www.mtn.ci/momo/developpeurs/

## 📚 Documentation MTN

- Portail développeur : https://developer.mtn.com/
- Documentation API : Disponible après création du compte développeur
- Support : support@mtn.com (selon le pays)

