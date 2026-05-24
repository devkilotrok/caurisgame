import 'dart:convert';
import 'package:http/http.dart' as http;
import '../user/user_service.dart';
import '../../config/api_config.dart';

/// Service API pour récupérer le profil utilisateur authentifié
class UserApiService {
  static UserApiService? _instance;
  static UserApiService get instance => _instance ??= UserApiService._internal();

  UserApiService._internal();

  static String get _baseUrl => ApiConfig.baseUrl;

  /// Récupérer le profil de l'utilisateur connecté.
  /// Essaie plusieurs endpoints courants: /user/me, /me, /profile
  Future<Map<String, dynamic>> getProfile() async {
    final token = UserService.instance.authToken;
    if (token == null) {
      return {'success': false, 'message': 'Non authentifié'};
    }

    final endpoints = <String>['$_baseUrl/user/me', '$_baseUrl/me', '$_baseUrl/profile'];

    for (final url in endpoints) {
      try {
        final resp = await http.get(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
        );
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final user = data['user'] ?? data['data'] ?? data;
          return {'success': true, 'user': user};
        }
      } catch (_) {}
    }

    return {'success': false, 'message': 'Profil introuvable'};
  }
}



