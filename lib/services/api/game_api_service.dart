import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../user/user_service.dart';

class GameApiService {
  GameApiService._();
  static final GameApiService instance = GameApiService._();

  static Map<String, String> _jsonHeaders() {
    final token = UserService.instance.authToken;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> createRoom({
    required String roomName,
    required int minimumBet,
  }) async {
    final token = UserService.instance.authToken;
    final uri = Uri.parse(ApiConfig.endpoint('rooms/create'));
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'room_name': roomName,
        'minimum_bet': minimumBet,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur createRoom: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> joinRoom({
    required String roomCode,
  }) async {
    final token = UserService.instance.authToken;
    final uri = Uri.parse(ApiConfig.endpoint('rooms/join'));
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'room_code': roomCode,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    
    // Essayer d'extraire un message clair de l'erreur du backend
    String errorMessage = 'Erreur serveur (${res.statusCode})';
    try {
      final errorData = jsonDecode(res.body);
      if (errorData['message'] != null) {
        errorMessage = errorData['message'];
      }
    } catch (_) {}
    
    throw Exception(errorMessage);
  }

  Future<Map<String, dynamic>> fillBots({
    required String roomId,
  }) async {
    final token = UserService.instance.authToken;
    final uri = Uri.parse(ApiConfig.endpoint('rooms/fill-bots'));
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'room_id': roomId,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur fillBots: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> registerPlayer({
    required String roomId,
  }) async {
    final token = UserService.instance.authToken;
    final uri = Uri.parse(ApiConfig.endpoint('rooms/register-player'));
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'room_id': roomId}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur registerPlayer: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> saveRound({
    required String roomId,
    required int roundNumber,
    required List<Map<String, dynamic>> announcements,
    required Map<String, int> obtainedTricks,
  }) async {
    final token = UserService.instance.authToken;
    final uri = Uri.parse(ApiConfig.endpoint('rounds/save'));
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'room_id': roomId,
        'round_number': roundNumber,
        'announcements': announcements,
        'obtained_tricks': obtainedTricks,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur saveRound: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> finalizeGame({
    required String roomId,
    required String winnerName,
    required int winnerScore,
  }) async {
    final token = UserService.instance.authToken;
    final uri = Uri.parse(ApiConfig.endpoint('games/finalize'));
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'room_id': roomId,
        'winner_name': winnerName,
        'winner_score': winnerScore,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur finalizeGame: ${res.statusCode} ${res.body}');
  }

  /// Demander au backend de distribuer les cartes
  /// Le backend gère le mélange et envoie la distribution via WebSocket
  Future<Map<String, dynamic>> distributeCards({
    required String roomId,
    required int roundNumber,
    bool testMode = false,
  }) async {
    final token = UserService.instance.authToken;
    final uri = Uri.parse(ApiConfig.endpoint('rounds/distribute-cards'));
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'room_id': roomId,
        'round_number': roundNumber,
        if (testMode) 'test_mode': true,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur distributeCards: ${res.statusCode} ${res.body}');
  }

  /// Obtenir ou créer le round_id et trick_id actuels
  /// Cette méthode est appelée avant de jouer une carte
  Future<Map<String, dynamic>> getCurrentTrick({
    required String roomId,
    required int roundNumber,
    required int trickNumber,
  }) async {
    final token = UserService.instance.authToken;
    final uri = Uri.parse(ApiConfig.endpoint('games/get-current-trick'));
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'room_id': roomId,
        'round_number': roundNumber,
        'trick_number': trickNumber,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur getCurrentTrick: ${res.statusCode} ${res.body}');
  }

  /// Jouer une carte via l'API Laravel
  /// Le backend gère la détection de la 4ème carte, le calcul du gagnant et le délai
  Future<Map<String, dynamic>> playCard({
    required int gameId,
    required int roundId,
    required int trickId,
    required String cardCode,
    required int roundNumber,
    required int trickNumber,
    String? playerName,
  }) async {
    final token = UserService.instance.authToken;
    final uri = Uri.parse(ApiConfig.endpoint('games/$gameId/play-card'));
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'round_id': roundId,
        'trick_id': trickId,
        'card_code': cardCode,
        'round_number': roundNumber,
        'trick_number': trickNumber,
        if (playerName != null) 'player_name': playerName,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur playCard: ${res.statusCode} ${res.body}');
  }

  /// Enregistrer un pli gagné au backend
  /// Le backend maintient l'état des compteurs et diffuse via WebSocket
  /// ⚠️ Cette méthode est maintenant dépréciée - utiliser playCard qui gère tout automatiquement
  @Deprecated('Utiliser playCard qui gère automatiquement la fin du pli')
  Future<Map<String, dynamic>> recordTrickWon({
    required String roomId,
    required int roundNumber,
    required String winnerName,
    required int trickNumber,
  }) async {
    final token = UserService.instance.authToken;
    final uri = Uri.parse(ApiConfig.endpoint('rounds/record-trick-won'));
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'room_id': roomId,
        'round_number': roundNumber,
        'winner_name': winnerName,
        'trick_number': trickNumber,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur recordTrickWon: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> startRound({
    required String roomId,
    required int roundNumber,
    required String deckHash,
  }) async {
    final token = UserService.instance.authToken;
    final uri = Uri.parse(ApiConfig.endpoint('rounds/start'));
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'room_id': roomId,
        'round_number': roundNumber,
        'deck_hash': deckHash,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur startRound: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> getRoom({
    required String roomId,
  }) async {
    final uri = Uri.parse(ApiConfig.endpoint('rooms/$roomId'));
    final res = await http.get(
      uri,
      headers: _jsonHeaders(),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur getRoom: ${res.statusCode} ${res.body}');
  }

  /// État consolidé : joueurs + game_id + manche + annonces + compteurs de plis.
  Future<Map<String, dynamic>> syncRoom({
    required String roomId,
    int? lastChatId,
  }) async {
    final uri = Uri.parse(ApiConfig.endpoint('rooms/$roomId/sync')).replace(
      queryParameters: {
        if (lastChatId != null) 'last_chat_id': lastChatId.toString(),
      },
    );
    final res = await http.get(
      uri,
      headers: _jsonHeaders(),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur syncRoom: ${res.statusCode} ${res.body}');
  }

  /// Récupérer la liste des salles disponibles
  /// 
  /// ✅ Backend Laravel : GET /api/rooms
  Future<List<Map<String, dynamic>>> getAvailableRooms() async {
    try {
      final token = UserService.instance.authToken;
      final uri = Uri.parse(ApiConfig.endpoint('rooms'));
      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final List<dynamic> rooms = data['data'] ?? [];
        return rooms.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Erreur lors de la récupération des salles disponibles: $e');
      return [];
    }
  }

  // ⚠️ NOUVEAU: Remplacer un joueur par un bot (en cas de déconnexion ou départ)
  Future<Map<String, dynamic>> replacePlayerWithBot({
    required String roomId,
    required String playerName,
    required String botName,
    required bool isPermanent,
  }) async {
    final token = UserService.instance.authToken;
    final uri = Uri.parse(ApiConfig.endpoint('rooms/replace-player'));
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'room_id': roomId,
        'player_name': playerName,
        'bot_name': botName,
        'is_permanent': isPermanent,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur replacePlayerWithBot: ${res.statusCode} ${res.body}');
  }

  // ⚠️ NOUVEAU: Restaurer un joueur (annuler remplacement temporaire)
  Future<Map<String, dynamic>> restorePlayer({
    required String roomId,
    required String playerName,
    required String botName,
  }) async {
    final token = UserService.instance.authToken;
    final uri = Uri.parse(ApiConfig.endpoint('rooms/restore-player'));
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'room_id': roomId,
        'player_name': playerName,
        'bot_name': botName,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur restorePlayer: ${res.statusCode} ${res.body}');
  }

  // ⚠️ NOUVEAU: Notifier une déconnexion de joueur
  Future<Map<String, dynamic>> notifyPlayerDisconnection({
    required String roomId,
    required String playerName,
  }) async {
    final token = UserService.instance.authToken;
    final uri = Uri.parse(ApiConfig.endpoint('rooms/player-disconnected'));
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'room_id': roomId,
        'player_name': playerName,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur notifyPlayerDisconnection: ${res.statusCode} ${res.body}');
  }

  // ⚠️ NOUVEAU: Notifier une reconnexion de joueur
  Future<Map<String, dynamic>> notifyPlayerReconnection({
    required String roomId,
    required String playerName,
  }) async {
    final token = UserService.instance.authToken;
    final uri = Uri.parse(ApiConfig.endpoint('rooms/player-reconnected'));
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'room_id': roomId,
        'player_name': playerName,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur notifyPlayerReconnection: ${res.statusCode} ${res.body}');
  }

  // ⚠️ NOUVEAU: Vérifier si un joueur est exclu d'une room
  Future<Map<String, dynamic>> checkPlayerExclusion({
    required String roomId,
    required String playerName,
  }) async {
    final token = UserService.instance.authToken;
    final uri = Uri.parse(ApiConfig.endpoint('rooms/check-exclusion'));
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'room_id': roomId,
        'player_name': playerName,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur checkPlayerExclusion: ${res.statusCode} ${res.body}');
  }

  /// ✅ Récupérer les compteurs de plis obtenus pour tous les joueurs
  /// Récupérer les scores calculés d'un round depuis le backend
  /// ✅ OPTIMISATION: Avec timeout et retry pour les connexions lentes
  Future<Map<String, dynamic>> getRoundScores({
    required int roundId,
    int maxRetries = 2,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    int attempts = 0;
    Exception? lastError;
    
    while (attempts <= maxRetries) {
      try {
        final token = UserService.instance.authToken;
        final uri = Uri.parse(ApiConfig.endpoint('rounds/$roundId/scores'));
        
        // ✅ OPTIMISATION: Timeout pour éviter les blocages avec connexion lente
        final res = await http.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ).timeout(timeout);

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final response = jsonDecode(res.body) as Map<String, dynamic>;
          if (response['success'] == true) {
            return response['data'] as Map<String, dynamic>;
          }
          throw Exception('Erreur getRoundScores: ${response['message']}');
        }
        throw Exception('Erreur getRoundScores: ${res.statusCode} ${res.body}');
      } catch (e) {
        lastError = e is Exception ? e : Exception('Erreur getRoundScores: $e');
        attempts++;
        
        // Ne pas retry si c'est une erreur de timeout et qu'on a déjà essayé
        if (attempts > maxRetries) {
          break;
        }
        
        // Attendre un peu avant de réessayer (backoff exponentiel)
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
    
    throw lastError ?? Exception('Erreur getRoundScores: Échec après $maxRetries tentatives');
  }

  Future<Map<String, dynamic>> getCurrentTrickCounters({
    required String roomId,
  }) async {
    try {
      final token = UserService.instance.authToken;
      final uri = Uri.parse(ApiConfig.endpoint('rooms/$roomId/trick-counters'));
      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return {'success': false, 'error': 'Erreur HTTP ${res.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// ✅ NOUVEAU: Obtenir les cartes jouables pour un joueur depuis le backend
  Future<List<String>> getPlayableCards({
    required int gameId,
    required int roundId,
    required int trickId,
    required int playerId,
    int maxRetries = 2,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    int attempts = 0;
    Exception? lastError;
    
    while (attempts <= maxRetries) {
      try {
        final token = UserService.instance.authToken;
        final uri = Uri.parse(ApiConfig.endpoint('games/$gameId/playable-cards'))
            .replace(queryParameters: {
          'round_id': roundId.toString(),
          'trick_id': trickId.toString(),
          'player_id': playerId.toString(),
        });
        
        final res = await http.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ).timeout(timeout);

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final response = jsonDecode(res.body) as Map<String, dynamic>;
          if (response['success'] == true && response['data'] != null) {
            final playableCards = response['data']['playable_cards'] as List<dynamic>?;
            return playableCards?.map((e) => e.toString()).toList() ?? [];
          }
          throw Exception('Erreur getPlayableCards: ${response['message'] ?? 'Réponse invalide'}');
        }
        throw Exception('Erreur getPlayableCards: ${res.statusCode} ${res.body}');
      } catch (e) {
        lastError = e is Exception ? e : Exception('Erreur getPlayableCards: $e');
        attempts++;
        
        if (attempts > maxRetries) {
          break;
        }
        
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
    
    throw lastError ?? Exception('Erreur getPlayableCards: Échec après $maxRetries tentatives');
  }

  /// ✅ NOUVEAU: Obtenir le joueur actuel qui doit jouer depuis le backend
  Future<Map<String, dynamic>> getCurrentTurn({
    required int gameId,
    required int roundId,
    required int trickId,
    int maxRetries = 2,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    int attempts = 0;
    Exception? lastError;
    
    while (attempts <= maxRetries) {
      try {
        final token = UserService.instance.authToken;
        final uri = Uri.parse(ApiConfig.endpoint('games/$gameId/current-turn'))
            .replace(queryParameters: {
          'round_id': roundId.toString(),
          'trick_id': trickId.toString(),
        });
        
        final res = await http.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ).timeout(timeout);

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final response = jsonDecode(res.body) as Map<String, dynamic>;
          if (response['success'] == true && response['data'] != null) {
            return response['data'] as Map<String, dynamic>;
          }
          throw Exception('Erreur getCurrentTurn: ${response['message'] ?? 'Réponse invalide'}');
        }
        throw Exception('Erreur getCurrentTurn: ${res.statusCode} ${res.body}');
      } catch (e) {
        lastError = e is Exception ? e : Exception('Erreur getCurrentTurn: $e');
        attempts++;
        
        if (attempts > maxRetries) {
          break;
        }
        
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
    
    throw lastError ?? Exception('Erreur getCurrentTurn: Échec après $maxRetries tentatives');
  }

  /// ✅ NOUVEAU: Valider les annonces depuis le backend
  Future<bool> validateAnnouncements({
    required int roundId,
    required Map<String, int> announcements,
    int maxRetries = 2,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    int attempts = 0;
    Exception? lastError;
    
    while (attempts <= maxRetries) {
      try {
        final token = UserService.instance.authToken;
        final uri = Uri.parse(ApiConfig.endpoint('rounds/validate-announcements'));
        
        final res = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'round_id': roundId,
            'announcements': announcements,
          }),
        ).timeout(timeout);

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final response = jsonDecode(res.body) as Map<String, dynamic>;
          if (response['success'] == true) {
            return true;
          }
          throw Exception('Erreur validateAnnouncements: ${response['message'] ?? 'Annonces invalides'}');
        }
        throw Exception('Erreur validateAnnouncements: ${res.statusCode} ${res.body}');
      } catch (e) {
        lastError = e is Exception ? e : Exception('Erreur validateAnnouncements: $e');
        attempts++;
        
        if (attempts > maxRetries) {
          break;
        }
        
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
    
    throw lastError ?? Exception('Erreur validateAnnouncements: Échec après $maxRetries tentatives');
  }

  /// ✅ Faire une annonce via le backend
  /// Le backend enregistre l'annonce et diffuse via WebSocket
  /// [playerName] est optionnel et utilisé pour les bots
  Future<Map<String, dynamic>> makeAnnouncement({
    required int gameId,
    required int roundNumber,
    required int announcementValue,
    String? playerName, // ✅ Optionnel pour les bots
    int maxRetries = 2,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    int attempts = 0;
    Exception? lastError;
    
    while (attempts <= maxRetries) {
      try {
        final token = UserService.instance.authToken;
        final uri = Uri.parse(ApiConfig.endpoint('games/$gameId/announce'));
        
        final res = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'round_number': roundNumber,
            'announcement_value': announcementValue,
            if (playerName != null) 'player_name': playerName, // ✅ Pour les bots
          }),
        ).timeout(timeout);

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final response = jsonDecode(res.body) as Map<String, dynamic>;
          if (response['success'] == true) {
            return response;
          }
          throw Exception('Erreur makeAnnouncement: ${response['message'] ?? 'Annonce échouée'}');
        }
        throw Exception('Erreur makeAnnouncement: ${res.statusCode} ${res.body}');
      } catch (e) {
        lastError = e is Exception ? e : Exception('Erreur makeAnnouncement: $e');
        attempts++;
        
        if (attempts > maxRetries) {
          break;
        }
        
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
    
    throw lastError ?? Exception('Erreur makeAnnouncement: Échec après $maxRetries tentatives');
  }

  /// ✅ Obtenir le tour d'annonces actuel depuis le backend
  Future<Map<String, dynamic>> getAnnouncementTurn({
    required int gameId,
    required int roundNumber,
    int maxRetries = 2,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    int attempts = 0;
    Exception? lastError;
    
    while (attempts <= maxRetries) {
      try {
        final token = UserService.instance.authToken;
        final uri = Uri.parse(ApiConfig.endpoint('games/$gameId/announcement-turn'))
            .replace(queryParameters: {
          'round_number': roundNumber.toString(),
        });
        
        final res = await http.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ).timeout(timeout);

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final response = jsonDecode(res.body) as Map<String, dynamic>;
          if (response['success'] == true && response['data'] != null) {
            return response['data'] as Map<String, dynamic>;
          }
          throw Exception('Erreur getAnnouncementTurn: ${response['message'] ?? 'Réponse invalide'}');
        }
        throw Exception('Erreur getAnnouncementTurn: ${res.statusCode} ${res.body}');
      } catch (e) {
        lastError = e is Exception ? e : Exception('Erreur getAnnouncementTurn: $e');
        attempts++;
        
        if (attempts > maxRetries) {
          break;
        }
        
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
    
    throw lastError ?? Exception('Erreur getAnnouncementTurn: Échec après $maxRetries tentatives');
  }

}
