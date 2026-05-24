import 'dart:convert';
import 'package:http/http.dart' as http;
import '../user/user_service.dart';
import '../../config/api_config.dart';

/// Service API pour le chat avec l'IA et les managers
class ChatApiService {
  static ChatApiService? _instance;
  static ChatApiService get instance => _instance ??= ChatApiService._internal();
  
  ChatApiService._internal();

  static String get _baseUrl => ApiConfig.baseUrl;

  /// Obtenir ou créer une conversation active
  Future<Map<String, dynamic>> getOrCreateConversation() async {
    try {
      final token = UserService.instance.authToken;
      if (token == null) {
        return {'success': false, 'message': 'Non authentifié'};
      }

      final uri = Uri.parse('$_baseUrl/chat/conversation');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'conversation': data['data']['conversation'],
          'messages': data['data']['messages'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Erreur lors de la récupération de la conversation',
        };
      }
    } catch (e) {
      print('❌ Erreur ChatApiService::getOrCreateConversation: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }

  /// Envoyer un message dans la conversation
  Future<Map<String, dynamic>> sendMessage({
    required int conversationId,
    required String message,
  }) async {
    try {
      final token = UserService.instance.authToken;
      if (token == null) {
        return {'success': false, 'message': 'Non authentifié'};
      }

      final uri = Uri.parse('$_baseUrl/chat/message');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'conversation_id': conversationId,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'user_message': data['data']['user_message'],
          'ai_message': data['data']['ai_message'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Erreur lors de l\'envoi du message',
        };
      }
    } catch (e) {
      print('❌ Erreur ChatApiService::sendMessage: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }

  /// Fermer une conversation
  Future<Map<String, dynamic>> closeConversation(int conversationId) async {
    try {
      final token = UserService.instance.authToken;
      if (token == null) {
        return {'success': false, 'message': 'Non authentifié'};
      }

      final uri = Uri.parse('$_baseUrl/chat/close');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'conversation_id': conversationId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Conversation fermée',
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Erreur lors de la fermeture',
        };
      }
    } catch (e) {
      print('❌ Erreur ChatApiService::closeConversation: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }

  /// Demander un transfert vers un manager
  Future<Map<String, dynamic>> requestManager() async {
    try {
      final token = UserService.instance.authToken;
      if (token == null) {
        return {'success': false, 'message': 'Non authentifié'};
      }

      final uri = Uri.parse('$_baseUrl/chat/request-manager');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Demande envoyée',
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Erreur lors de la demande',
        };
      }
    } catch (e) {
      print('❌ Erreur ChatApiService::requestManager: $e');
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }
}

