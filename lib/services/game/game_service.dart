import '../websocket/game_websocket_service.dart';
import '../../models/game/game_session.dart';
import '../../models/game/local_card_manager.dart';
import '../../models/game/game_logic.dart';
import '../../models/room/room_manager.dart';
import '../user/user_service.dart';
import '../api/game_api_service.dart';

/// Service pour la gestion du jeu
/// 
/// 🔄 INTÉGRATION BACKEND :
/// 1. Créer un service API (lib/services/api/game_api_service.dart)
/// 2. Remplacer les appels à _roomManager par des appels API
/// 3. Supprimer la logique de simulation locale
/// 4. Voir INTEGRATION_API.md pour les détails
class GameService {
  static GameService? _instance;
  static GameService get instance => _instance ??= GameService._internal();
  
  GameService._internal();

  final GameSession _gameSession = GameSession.instance;
  final LocalCardManager _cardManager = LocalCardManager.instance;
  final GameLogic _gameLogic = GameLogic.instance;
  final RoomManager _roomManager = RoomManager.instance; // ✅ À REMPLACER par API
  final GameApiService _api = GameApiService.instance;
  final UserService _userService = UserService.instance;

  /// Créer une salle
  /// 
  /// TODO: INTÉGRER L'API BACKEND
  /// Actuellement: Simulation locale via _roomManager
  /// À changer par: Appel API POST /api/rooms/create
  /// 
  /// Exemple d'intégration :
  /// ```dart
  /// final response = await http.post(
  ///   Uri.parse('$apiUrl/rooms/create'),
  ///   headers: {'Authorization': 'Bearer $token'},
  ///   body: jsonEncode({'roomName': roomName, 'minimumBet': minimumBid}),
  /// );
  /// ```
  Future<String?> createRoom(String roomName, int minimumBid) async {
    try {
      // API backend obligatoire (pas de fallback local)
      final res = await _api.createRoom(roomName: roomName, minimumBet: minimumBid);
      final data = (res['data'] as Map?) ?? res; // backend renvoie souvent { success, data: {...} }
      final roomId = (data['room_id'] ?? data['roomId'] ?? '').toString();
      final roomCode = (data['room_code'] ?? data['roomCode'] ?? '') as String?;
      final players = (data['players'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
      if (roomId.isNotEmpty && roomCode != null) {
        final backendRoomName = (data['room_name'] ?? roomName) as String;
        _gameSession.initializeSession(
          roomId: roomId,
          roomName: backendRoomName,
          roomCode: roomCode,
          minimumBet: minimumBid,
          players: players,
        );
        return roomCode;
      }

      return null;
    } catch (e) {
      print('Erreur lors de la création de la salle: $e');
      return null;
    }
  }

  /// Rejoindre une salle
  Future<bool> joinRoom(String roomCode) async {
    try {
      // API backend obligatoire (pas de fallback local)
      final res = await _api.joinRoom(roomCode: roomCode);
      final data = (res['data'] as Map?) ?? res;
      final roomId = (data['room_id'] ?? data['roomId'] ?? '').toString();
      final roomName = (data['room_name'] ?? data['roomName'] ?? 'Room') as String;
      final code = (data['room_code'] ?? data['roomCode'] ?? roomCode) as String;
      final minBet = (data['minimum_bet'] ?? data['minimumBet'] ?? 0) as int;
      final players = (data['players'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (roomId.isNotEmpty) {
        final backendRoomName = (data['room_name'] ?? roomName) as String;
        _gameSession.initializeSession(
          roomId: roomId,
          roomName: backendRoomName,
          roomCode: code,
          minimumBet: minBet,
          players: players,
        );
        return true;
      }

      return false;
    } catch (e) {
      print('Erreur lors de la réunion de la salle: $e');
      return false;
    }
  }

  /// Démarrer le jeu (distribution locale, liste depuis la session)
  Future<void> startGame() async {
    try {
      final playerNames = _gameSession.players
          .map((p) => (p['name'] ?? p['pseudo'] ?? p['player'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();
      _cardManager.shuffleAndDealCards(playerNames);
      _gameLogic.configurePlayers(
        playerCount: playerNames.length,
        cardsPerPlayer: _cardManager.cardsPerPlayer,
      );
    } catch (e) {
      print('Erreur lors du démarrage du jeu: $e');
      rethrow;
    }
  }

  /// Obtenir la main du joueur actuel
  List<Map<String, dynamic>> getPlayerHand() {
    return _cardManager.getPlayerCards(_userService.currentUserPseudo ?? '');
  }

  /// Obtenir les données de la session
  GameSession get gameSession => _gameSession;

  /// Obtenir le gestionnaire de cartes
  LocalCardManager get cardManager => _cardManager;
}

