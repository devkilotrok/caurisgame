import 'dart:convert';
import 'package:http/http.dart' as http;
import '../user/user_service.dart';
import '../../config/api_config.dart';

class RoomChatApiService {
  RoomChatApiService._internal();
  static final RoomChatApiService instance = RoomChatApiService._internal();

  static String get _baseUrl => ApiConfig.baseUrl;

  Future<Map<String, dynamic>> fetchMessages({
    required int roomId,
    int? lastId,
  }) async {
    try {
      final token = UserService.instance.authToken;
      if (token == null) {
        return {'success': false, 'message': 'Non authentifié'};
      }

      final uri = Uri.parse('$_baseUrl/rooms/$roomId/chat/messages')
          .replace(queryParameters: {
        if (lastId != null) 'last_id': lastId.toString(),
      });

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      final body = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'messages': body['data'] ?? []};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Erreur lors de la récupération du chat',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion: $e'};
    }
  }

  Future<Map<String, dynamic>> sendMessage({
    required int roomId,
    required String message,
    String type = 'text',
    String? presetCode,
  }) async {
    try {
      final token = UserService.instance.authToken;
      if (token == null) {
        return {'success': false, 'message': 'Non authentifié'};
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/rooms/$roomId/chat/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'message': message,
          'message_type': type,
          if (presetCode != null) 'preset_code': presetCode,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'messageData': body['data']};
      }

      return {
        'success': false,
        'message': body['message'] ?? 'Erreur lors de l\'envoi du message',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion: $e'};
    }
  }
}


