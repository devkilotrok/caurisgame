import 'dart:convert';
import 'package:http/http.dart' as http;
import '../user/user_service.dart';
import '../../config/api_config.dart';

/// Service de test de connexion au backend
class TestConnectionService {
  static Future<void> testAllEndpoints() async {
    final token = UserService.instance.authToken;
    
    if (token == null) {
      print('❌ Pas de token d\'authentification');
      return;
    }

    print('🔍 Test des endpoints API...\n');

    // Test 1: Check Balance
    print('1. Test /payment/check-balance');
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/payment/check-balance'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      print('   Status: ${response.statusCode}');
      print('   Response: ${response.body}');
    } catch (e) {
      print('   ❌ Erreur: $e');
    }

    print('\n');

    // Test 2: Get Balance
    print('2. Test /payment/balance');
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/payment/balance'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      print('   Status: ${response.statusCode}');
      print('   Response: ${response.body}');
    } catch (e) {
      print('   ❌ Erreur: $e');
    }

    print('\n✅ Tests terminés');
  }
}

