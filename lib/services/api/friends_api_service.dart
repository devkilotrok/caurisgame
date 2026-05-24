import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/user/user_models.dart';
import '../user/user_service.dart';
import '../../config/api_config.dart';

/// Service API pour gérer les amis
class FriendsApiService {
  static FriendsApiService? _instance;
  static FriendsApiService get instance => _instance ??= FriendsApiService._internal();
  
  FriendsApiService._internal();

  // URL du backend configurée via ApiConfig
  static String get _baseUrl => ApiConfig.baseUrl;

  /// Rechercher des amis
  /// 
  /// ✅ Backend Laravel : GET /api/friends/search
  /// Query params: q (search query)
  Future<List<User>> searchFriends(String query) async {
    try {
      final token = UserService.instance.authToken;
      if (token == null) {
        return [];
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/friends/search?q=$query'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> users = data['users'] ?? [];
        return users.map((json) => User.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Erreur lors de la recherche d\'amis: $e');
      return [];
    }
  }

  /// Obtenir la liste des amis
  /// 
  /// ✅ Backend Laravel : GET /api/friends
  Future<List<Friend>> getFriendsList() async {
    try {
      final token = UserService.instance.authToken;
      if (token == null) {
        return [];
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/friends'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> friends = data['friends'] ?? [];
        return friends.map((json) => Friend.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Erreur lors de la récupération de la liste d\'amis: $e');
      return [];
    }
  }

  /// Envoyer une demande d'amitié
  /// 
  /// ✅ Backend Laravel : POST /api/friends/send-request
  Future<Map<String, dynamic>> sendFriendRequest({
    required String friendId,
    String? message,
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
        Uri.parse('$_baseUrl/friends/send-request'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'friend_id': friendId,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Demande d\'amitié envoyée',
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

  /// Accepter une demande d'amitié
  /// 
  /// ✅ Backend Laravel : POST /api/friends/accept-request
  Future<Map<String, dynamic>> acceptFriendRequest({
    required String requestId,
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
        Uri.parse('$_baseUrl/friends/accept-request'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'request_id': requestId,
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Demande d\'amitié acceptée',
        };
      } else {
        return {
          'success': false,
          'message': 'Erreur lors de l\'acceptation',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }

  /// Refuser une demande d'amitié
  /// 
  /// ✅ Backend Laravel : POST /api/friends/decline-request
  Future<Map<String, dynamic>> declineFriendRequest({
    required String requestId,
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
        Uri.parse('$_baseUrl/friends/decline-request'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'request_id': requestId,
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Demande d\'amitié refusée',
        };
      } else {
        return {
          'success': false,
          'message': 'Erreur lors du refus',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur de connexion: $e',
      };
    }
  }

  /// Obtenir les demandes d'amitié en attente
  /// 
  /// ✅ Backend Laravel : GET /api/friends/requests
  Future<List<FriendRequest>> getFriendRequests() async {
    try {
      final token = UserService.instance.authToken;
      if (token == null) {
        return [];
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/friends/requests'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> requests = data['requests'] ?? [];
        return requests.map((json) => FriendRequest.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Erreur lors de la récupération des demandes: $e');
      return [];
    }
  }

  /// Supprimer un ami
  /// 
  /// ✅ Backend Laravel : DELETE /api/friends/{friendId}
  Future<Map<String, dynamic>> removeFriend({
    required String friendId,
  }) async {
    try {
      final token = UserService.instance.authToken;
      if (token == null) {
        return {
          'success': false,
          'message': 'Non authentifié',
        };
      }

      final response = await http.delete(
        Uri.parse('$_baseUrl/friends/$friendId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Ami supprimé',
        };
      } else {
        return {
          'success': false,
          'message': 'Erreur lors de la suppression',
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

