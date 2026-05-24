import 'dart:convert';
import 'package:http/http.dart' as http;
import '../user/user_service.dart';
import '../../config/api_config.dart';

/// Service API pour l'authentification et l'envoi d'emails
class AuthApiService {
  static AuthApiService? _instance;
  static AuthApiService get instance => _instance ??= AuthApiService._internal();
  
  AuthApiService._internal();

  // URL du backend configurée via ApiConfig
  static String get _baseUrl => ApiConfig.baseUrl;
  
  /// Envoyer un code de vérification d'email
  /// 
  /// Cette méthode sera appelée lors de l'inscription pour :
  /// 1. Créer le compte utilisateur
  /// 2. Générer un code de vérification
  /// 3. Envoyer un email de confirmation avec le code
  /// 
  /// ✅ Backend Laravel : POST /api/auth/register
  /// Le backend doit :
  /// - Créer l'utilisateur avec statut 'unverified'
  /// - Générer un code aléatoire
  /// - Envoyer un email avec le code
  /// - Retourner {'success': true, 'message': 'Email envoyé'}
  Future<Map<String, dynamic>> registerWithEmail({
    required String pseudo,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    try {
      // ✅ Le backend exige un champ `name` (nom complet).
      // On le construit à partir de prénom + nom, avec fallback sur le pseudo.
      final String fullName = [
        (firstName ?? '').trim(),
        (lastName ?? '').trim(),
      ].where((part) => part.isNotEmpty).join(' ').trim();
      final String resolvedName = fullName.isNotEmpty ? fullName : pseudo;

      final Map<String, dynamic> payload = {
        'name': resolvedName,
        'pseudo': pseudo,
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        // Note: address n'est pas envoyé car non présent dans le formulaire d'inscription
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Accept-Language': 'fr',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(payload),
      );

      print('📤 Envoi données: ${jsonEncode(payload)}');
      
      print('📥 Réponse status: ${response.statusCode}');
      print('📥 Réponse body: ${response.body}');
      
      final responseBody = jsonDecode(response.body);
      
      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': responseBody['message'] ?? 'Email de vérification envoyé',
          'userId': responseBody['data']['user']['user_id'],
        };
      } else {
        return {
          'success': false,
          'message': responseBody['message'] ?? 'Erreur lors de l\'inscription',
          'errors': responseBody['errors'],
        };
      }
    } catch (e) {
      print('❌ Erreur API: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }

  /// Vérifier le code de confirmation d'email
  /// 
  /// Cette méthode est appelée après que l'utilisateur reçoive le code par email
  /// 
  /// ✅ Backend Laravel : POST /api/auth/verify-email
  /// Le backend doit :
  /// - Vérifier que le code correspond
  /// - Activer le compte (is_active = true)
  /// - Retourner {'success': true, 'message': 'Email vérifié'}
  Future<Map<String, dynamic>> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verify-email'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'email': email,
          'code': code,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Email vérifié avec succès',
          'token': data['token'], // Token JWT pour la connexion automatique
          'user': data['user'], // Données de l'utilisateur
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Code invalide ou expiré',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }

  /// Demander un code pour réinitialiser le mot de passe
  /// 
  /// Cette méthode envoie un email avec un code de réinitialisation
  /// 
  /// ✅ Backend Laravel : POST /api/auth/forgot-password
  /// Le backend doit :
  /// - Vérifier que l'email existe
  /// - Générer un code aléatoire
  /// - Envoyer un email avec le code
  /// - Retourner {'success': true, 'message': 'Email envoyé'}
  Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/forgot-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'email': email,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Code de réinitialisation envoyé par email',
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Erreur lors de l\'envoi',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }

  /// Vérifier le code de réinitialisation
  /// 
  /// Cette méthode vérifie que le code envoyé par email est correct
  /// 
  /// ✅ Backend Laravel : POST /api/auth/verify-reset-code
  /// Le backend doit :
  /// - Vérifier que le code correspond
  /// - Retourner un token temporaire pour réinitialiser le mot de passe
  Future<Map<String, dynamic>> verifyResetCode({
    required String email,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verify-reset-code'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'email': email,
          'code': code,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'resetToken': data['resetToken'], // Token pour réinitialiser le mot de passe
        };
      } else {
        return {
          'success': false,
          'message': 'Code invalide ou expiré',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }

  /// Réinitialiser le mot de passe avec un nouveau mot de passe
  /// 
  /// ✅ Backend Laravel : POST /api/auth/reset-password
  /// Le backend doit :
  /// - Vérifier le resetToken
  /// - Mettre à jour le mot de passe
  /// - Invalider le resetToken
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/reset-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'email': email,
          'resetToken': resetToken,
          'password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Mot de passe réinitialisé avec succès',
        };
      } else {
        return {
          'success': false,
          'message': 'Erreur lors de la réinitialisation',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }

  /// Renvoyer le code de vérification
  /// 
  /// ✅ Backend Laravel : POST /api/auth/resend-verification-code
  Future<Map<String, dynamic>> resendVerificationCode({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/resend-verification-code'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'email': email,
        }),
      );

      print('📤 Resend code - Réponse status: ${response.statusCode}');
      print('📥 Resend code - Réponse body: ${response.body}');

      final responseBody = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseBody['message'] ?? 'Code renvoyé avec succès',
        };
      } else {
        return {
          'success': false,
          'message': responseBody['message'] ?? 'Erreur lors de l\'envoi',
        };
      }
    } catch (e) {
      print('❌ Erreur resend code: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }

  /// Login après vérification ou login normal
  /// 
  /// ✅ Backend Laravel : POST /api/auth/login
  /// Accepte : pseudo ou email
  Future<Map<String, dynamic>> login({
    required String email, // En réalité c'est "login" qui peut être pseudo ou email
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'login': email, // Peut être email ou pseudo
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'token': data['token'] ?? data['data']['token'],
          'user': data['data']['user'] ?? {},
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Pseudo/Email ou mot de passe incorrect',
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

