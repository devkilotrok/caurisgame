import 'dart:convert';
import 'dart:io';
import 'dart:async'; // Pour TimeoutException
import 'package:http/http.dart' as http;
import '../user/user_service.dart';
import '../../config/api_config.dart';

/// Service API pour gérer les paiements et les soldes
/// 
/// Ce service gère :
/// - La vérification des soldes avant de créer/rejoindre un salon
/// - Le débit des mises des joueurs
/// - Le crédit au compte entreprise
class PaymentApiService {
  static PaymentApiService? _instance;
  static PaymentApiService get instance => _instance ??= PaymentApiService._internal();
  
  PaymentApiService._internal();

  // URL du backend configurée via ApiConfig
  static String get _baseUrl => ApiConfig.baseUrl;

  /// Vérifier si l'utilisateur a assez d'argent pour créer un salon
  /// 
  /// ✅ Backend Laravel : GET /api/payment/check-balance
  /// Retourne le solde actuel et vérifie si suffisant pour la mise
  Future<Map<String, dynamic>> checkBalance({
    required int requiredAmount,
  }) async {
    print('');
    print('   ═══ DETAILS CHECK BALANCE ═══');
    try {
      final token = UserService.instance.authToken;
      print('   → Token disponible : ${token != null}');
      
      if (token == null) {
        print('   ❌ ERREUR : Pas de token d\'authentification');
        return {
          'success': false,
          'message': 'Non authentifié',
        };
      }

      final url = Uri.parse('$_baseUrl/payment/check-balance').replace(queryParameters: {
        'required_amount': requiredAmount.toString(),
      });
      
      print('   → URL complète : $url');
      print('   → Headers : Authorization: Bearer $token');
      print('   → Query params : required_amount=$requiredAmount');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      print('   → Status code : ${response.statusCode}');
      print('   → Response body : ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('   → Données parsées : $data');
        
        final balance = data['balance'] as int;
        final hasEnough = balance >= requiredAmount;
        
        print('   → Solde : $balance');
        print('   → Suffisant : $hasEnough (requis : $requiredAmount)');
        print('   ✅ SUCCESS');
        
        return {
          'success': true,
          'balance': balance,
          'hasEnough': hasEnough,
          'required': requiredAmount,
        };
      } else {
        final errorBody = response.body;
        print('   ❌ ERREUR : Status ${response.statusCode}');
        print('   → Body : $errorBody');
        
        return {
          'success': false,
          'message': 'Erreur lors de la vérification (${response.statusCode})',
          'status_code': response.statusCode,
          'error_body': errorBody,
        };
      }
    } catch (e, stackTrace) {
      print('   ❌❌❌ EXCEPTION ❌❌❌');
      print('   → Erreur : $e');
      print('   → Stack trace : $stackTrace');
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }

  /// Débiter le montant pour créer/rejoindre un salon
  /// 
  /// ✅ Backend Laravel : POST /api/payment/debit-room-bet
  /// Le backend doit :
  /// - Vérifier que l'utilisateur a assez d'argent
  /// - Débiter le montant du compte utilisateur
  /// - Créditer le compte entreprise
  /// - Enregistrer la transaction
  Future<Map<String, dynamic>> debitRoomBet({
    required int amount,
    required int roomId,
  }) async {
    try {
      final token = UserService.instance.authToken;
      if (token == null) {
        return {
          'success': false,
          'message': 'Non authentifié',
        };
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/payment/debit-room-bet'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'amount': amount,
          'room_id': roomId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Mise débitée avec succès',
          'new_balance': data['new_balance'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Erreur lors du débit',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }

  /// Obtenir le solde actuel de l'utilisateur
  /// 
  /// ✅ Backend Laravel : GET /api/payment/balance
  Future<Map<String, dynamic>> getBalance() async {
    try {
      final token = UserService.instance.authToken;
      if (token == null) {
        return {
          'success': false,
          'balance': 0,
          'message': 'Non authentifié',
        };
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/payment/balance'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'balance': data['balance'] ?? 0,
          'company_balance': data['company_balance'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'balance': 0,
          'message': 'Erreur',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'balance': 0,
        'message': 'Erreur: $e',
      };
    }
  }

  /// ✅ Vérifier la connectivité au backend avant de faire un dépôt
  Future<Map<String, dynamic>> checkBackendConnectivity() async {
    try {
      print('🔍 Vérification de la connectivité au backend...');
      print('   → URL: $_baseUrl');
      
      // Tester avec un endpoint simple (balance)
      final response = await http.get(
        Uri.parse('$_baseUrl/payment/balance'),
        headers: {
          'Authorization': 'Bearer ${UserService.instance.authToken ?? ""}',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200 || response.statusCode == 401) {
        // 200 = OK, 401 = Non authentifié mais serveur accessible
        print('   ✅ Backend accessible');
        return {'success': true, 'accessible': true};
      } else if (response.statusCode == 502 || response.statusCode == 503) {
        print('   ❌ Backend non accessible (502/503)');
        return {
          'success': false,
          'accessible': false,
          'message': 'Le backend n\'est pas accessible. Vérifiez que Laravel est démarré: php artisan serve',
        };
      } else {
        print('   ⚠️  Backend répond mais avec erreur: ${response.statusCode}');
        return {'success': true, 'accessible': true}; // Accessible mais erreur métier
      }
    } on TimeoutException {
      print('   ❌ Timeout lors de la vérification');
      return {
        'success': false,
        'accessible': false,
        'message': 'Timeout: Le backend ne répond pas. Vérifiez votre connexion et que le serveur est démarré.',
      };
    } on SocketException catch (e) {
      print('   ❌ Erreur de connexion: $e');
      String message = 'Impossible de se connecter au backend.';
      message += ' Vérifiez que Laravel est démarré: cd /opt/lampp/htdocs/backendCauris && php artisan serve';
      if (_baseUrl.contains('192.168.') || _baseUrl.contains('10.') || _baseUrl.contains('172.')) {
        message += '\nVérifiez aussi que votre téléphone est sur le même réseau WiFi que votre PC.';
      }
      return {
        'success': false,
        'accessible': false,
        'message': message,
      };
    } catch (e) {
      print('   ❌ Erreur lors de la vérification: $e');
      return {
        'success': false,
        'accessible': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }

  /// Déposer (achat de cauris) via FedaPay - initie un paiement FedaPay
  /// POST /api/payment/deposit { amount_fcfa, phone_number }
  Future<Map<String, dynamic>> deposit({
    required int amountFcfa,
    required String phoneNumber,
  }) async {
    print('');
    print('   ═══ DETAILS DEPOT FEDAPAY ═══');
    print('   → Montant FCFA: $amountFcfa');
    print('   → Numéro téléphone: $phoneNumber');
    print('   → URL complète: $_baseUrl/payment/deposit');
    
    try {
      final token = UserService.instance.authToken;
      if (token == null) {
        print('   ❌ Token non disponible');
        return {'success': false, 'message': 'Non authentifié'};
      }
      
      print('   → Token disponible : true');
      print('   → Headers : Authorization: Bearer ${token.substring(0, 20)}...');
      
      // ✅ Vérifier la connectivité AVANT d'essayer le dépôt
      final connectivityCheck = await checkBackendConnectivity();
      if (connectivityCheck['accessible'] != true) {
        print('   ❌ Backend non accessible, arrêt du dépôt');
        return {
          'success': false,
          'message': connectivityCheck['message'] ?? 'Backend non accessible',
          'connectivity_error': true,
        };
      }
      
      // ✅ Vérifier la configuration de l'URL
      if (!_baseUrl.contains('https://') && !_baseUrl.contains('localhost') && !_baseUrl.contains('192.168.')) {
        print('   ⚠️  ATTENTION: URL HTTP (non sécurisée)');
        print('   → FedaPay nécessite HTTPS pour les callbacks en production');
        print('   → En développement local, HTTP est acceptable');
      }
      
      final requestBody = {
        'amount_fcfa': amountFcfa,
        'phone_number': phoneNumber,
      };
      print('   → Body : ${jsonEncode(requestBody)}');
      
      final resp = await http.post(
        Uri.parse('$_baseUrl/payment/deposit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true', // ✅ Ajouter pour éviter les warnings ngrok
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('   ❌ TIMEOUT : La requête a pris plus de 30 secondes');
          throw TimeoutException('La requête a pris trop de temps. Vérifiez votre connexion.');
        },
      );
      
      print('   → Status code : ${resp.statusCode}');
      print('   → Response body : ${resp.body}');
      
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        try {
          final data = jsonDecode(resp.body);
          final responseData = data['data'] as Map<String, dynamic>?;
          
          print('   ✅ SUCCESS');
          print('   → Données parsées : $data');
          
          final paymentUrl = responseData?['payment_url'] as String?;
          if (paymentUrl != null) {
            print('   → URL de paiement : $paymentUrl');
            
            // ✅ Vérifier que l'URL de paiement est valide
            try {
              final uri = Uri.parse(paymentUrl);
              if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
                print('   ⚠️  URL de paiement invalide : $paymentUrl');
                return {
                  'success': false,
                  'message': 'URL de paiement invalide reçue du serveur',
                };
              }
            } catch (e) {
              print('   ❌ Erreur de parsing de l\'URL de paiement : $e');
              return {
                'success': false,
                'message': 'URL de paiement invalide : $e',
              };
            }
          } else {
            print('   ⚠️  URL de paiement manquante dans la réponse');
          }
          
          return {
            'success': true,
            'data': responseData,
            'payment_url': paymentUrl,
            'transaction_id': responseData?['transaction_id'],
            'payment_token': responseData?['payment_token'],
          };
        } catch (e) {
          print('   ❌ Erreur de parsing JSON : $e');
          print('   → Body brut : ${resp.body}');
          return {
            'success': false,
            'message': 'Erreur de format de réponse du serveur : $e',
            'raw_response': resp.body,
          };
        }
      } else {
        // ✅ Gestion détaillée des erreurs
        print('   ❌ ERREUR : Status ${resp.statusCode}');
        
        String errorMessage = 'Erreur lors de l\'initiation du paiement';
        Map<String, dynamic>? errorData;
        
        try {
          errorData = jsonDecode(resp.body) as Map<String, dynamic>;
          errorMessage = errorData['message'] as String? ?? errorData['error'] as String? ?? resp.body;
          
          // ✅ Détecter les erreurs spécifiques
          if (resp.statusCode == 502 || resp.statusCode == 503) {
            errorMessage = 'Serveur temporairement indisponible. Vérifiez que le backend Laravel est démarré.';
          } else if (resp.statusCode == 404) {
            errorMessage = 'Endpoint non trouvé. Vérifiez que l\'URL du backend est correcte.';
          } else if (resp.statusCode == 500) {
            errorMessage = 'Erreur serveur. Vérifiez les logs du backend.';
          } else if (resp.statusCode == 404) {
            errorMessage = 'Endpoint non trouvé. Vérifiez que l\'URL du backend est correcte.';
          }
          
          print('   → Message d\'erreur : $errorMessage');
          print('   → Données d\'erreur : $errorData');
        } catch (e) {
          print('   → Erreur de parsing du body d\'erreur : $e');
          print('   → Body brut : ${resp.body}');
          errorMessage = resp.body.isNotEmpty ? resp.body : 'Erreur ${resp.statusCode}';
        }
        
        return {
          'success': false,
          'message': errorMessage,
          'status_code': resp.statusCode,
          'error_data': errorData,
        };
      }
    } on TimeoutException catch (e) {
      print('   ❌ TIMEOUT EXCEPTION');
      print('   → Erreur : $e');
      return {
        'success': false,
        'message': 'La connexion a pris trop de temps. Vérifiez votre connexion internet et que le serveur est accessible.',
      };
    } on SocketException catch (e) {
      print('   ❌ SOCKET EXCEPTION');
      print('   → Erreur : $e');
      String message = 'Impossible de se connecter au serveur.';
      if (_baseUrl.contains('localhost') || _baseUrl.contains('127.0.0.1')) {
        message += ' Vérifiez que Laravel est démarré: php artisan serve';
      } else if (_baseUrl.contains('192.168.') || _baseUrl.contains('10.') || _baseUrl.contains('172.')) {
        message += ' Vérifiez que Laravel est démarré et que l\'IP est accessible depuis votre téléphone.';
      } else {
        message += ' Vérifiez que le backend Laravel est démarré sur ${_baseUrl.replaceAll('/api', '')}';
      }
      return {
        'success': false,
        'message': message,
      };
    } catch (e, stackTrace) {
      print('   ❌❌❌ EXCEPTION GÉNÉRALE ❌❌❌');
      print('   → Erreur : $e');
      print('   → Stack trace : $stackTrace');
      return {
        'success': false,
        'message': 'Erreur inattendue : $e',
      };
    }
  }

  /// Retrait de cauris -> FCFA (initie une demande de retrait)
  /// POST /api/payment/withdraw { cauris, beneficiary_name, phone }
  Future<Map<String, dynamic>> withdraw({
    required int cauris,
    required String beneficiaryName,
    required String phone,
  }) async {
    try {
      final token = UserService.instance.authToken;
      if (token == null) {
        return {'success': false, 'message': 'Non authentifié'};
      }
      final resp = await http.post(
        Uri.parse('$_baseUrl/payment/withdraw'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'cauris': cauris,
          'beneficiary_name': beneficiaryName,
          'phone': phone,
        }),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': resp.body};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  /// Transactions de l'utilisateur connecté
  /// Limité aux 20 transactions les plus récentes (dépôts et retraits uniquement)
  /// Exclut automatiquement les transactions de mise de salon et de gains de partie
  Future<Map<String, dynamic>> getTransactions({int limit = 20}) async {
    try {
      final token = UserService.instance.authToken;
      if (token == null) {
        return {'success': false, 'message': 'Non authentifié'};
      }
      final resp = await http.get(
        Uri.parse('$_baseUrl/payment/transactions').replace(queryParameters: {
          'limit': limit.toString(),
        }),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        return {'success': true, 'data': data['data'] ?? []};
      }
      return {'success': false, 'message': resp.body};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  /// Distribuer les gains au gagnant d'une partie
  /// 
  /// ✅ Backend Laravel : POST /api/payment/distribute-winnings
  /// Le backend doit :
  /// - Créditer le compte du gagnant (si ce n'est pas un bot remplaçant)
  /// - Débiter le compte entreprise (super admin)
  /// - Enregistrer la transaction
  Future<Map<String, dynamic>> distributeWinnings({
    required int roomId,
    required String winnerName,
    required int winnerAmount,
    required int companyAmount,
    required bool isReplacementBot,
    required int totalPot,
  }) async {
    try {
      final token = UserService.instance.authToken;
      if (token == null) {
        return {
          'success': false,
          'message': 'Non authentifié',
        };
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/payment/distribute-winnings'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'room_id': roomId,
          'winner_name': winnerName,
          'winner_amount': winnerAmount,
          'company_amount': companyAmount,
          'is_replacement_bot': isReplacementBot,
          'total_pot': totalPot,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Gains distribués avec succès',
          'data': data['data'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Erreur lors de la distribution des gains',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }
}

