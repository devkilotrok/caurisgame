import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../config/api_config.dart';

/// Service WebSocket utilisant Socket.io pour la gestion des communications temps réel du jeu Cauris
/// 
/// Compatible avec le serveur Node.js Socket.io sur le port 3000
class GameWebSocketService {
  static final GameWebSocketService _instance = GameWebSocketService._internal();
  factory GameWebSocketService() => _instance;
  GameWebSocketService._internal();

  IO.Socket? _socket;
  String? _currentRoomId;
  String? _currentPlayerName;
  final Map<String, StreamController<dynamic>> _eventControllers = {};
  Completer<void>? _connectCompleter;

  /// Se connecter au serveur Socket.io
  /// 
  /// Utilise l'URL de l'API configurée dans ApiConfig par défaut
  /// Peut être surchargée avec serverUrl pour des tests
  Future<void> connect({String? serverUrl}) async {
    if (_socket != null && _socket!.connected) {
      return;
    }

    // Utiliser l'URL fournie ou celle de la configuration
    // Socket.io utilise HTTP/HTTPS, pas ws/wss directement
    var url = serverUrl ?? ApiConfig.websocketUrl;
    
    // Convertir ws:// en http:// et wss:// en https:// pour Socket.io
    if (url.startsWith('ws://')) {
      url = url.replaceFirst('ws://', 'http://');
    } else if (url.startsWith('wss://')) {
      url = url.replaceFirst('wss://', 'https://');
    }
    
    print('🔌 Tentative de connexion Socket.io à: $url');
    
    try {
      _connectCompleter = Completer<void>();

      _socket = IO.io(
        url,
        IO.OptionBuilder()
            // WebSocket en premier : serveur Render Starter toujours actif
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setReconnectionAttempts(10)
            .setTimeout(15000)
            .build(),
      );

      // Écouter la connexion
      _socket!.onConnect((_) {
        print('✅ Connexion Socket.io établie');
        if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
          _connectCompleter!.complete();
        }
        if (_eventControllers.containsKey('connect')) {
          _eventControllers['connect']!.add(null);
        }
        if (_currentRoomId != null &&
            _currentRoomId!.isNotEmpty &&
            _currentPlayerName != null &&
            _currentPlayerName!.isNotEmpty) {
          _emit('join_room', {
            'roomId': _currentRoomId.toString(),
            'playerName': _currentPlayerName,
          });
        }
      });

      // Écouter les erreurs de connexion
      _socket!.onConnectError((error) {
        print('❌ Erreur de connexion Socket.io: $error');
        if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
          _connectCompleter!.completeError(error);
        }
        _handleError(error);
      });

      // Écouter la déconnexion
      _socket!.onDisconnect((reason) {
        print('🔌 Déconnexion Socket.io: $reason');
        _handleDisconnect();
      });

      // Écouter tous les événements personnalisés
      _socket!.onAny((event, data) {
        _handleMessage(event, data);
      });

      // Connecter
      _socket!.connect();

      await _connectCompleter!.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('❌ Timeout connexion Socket.io (15s)');
          throw TimeoutException('Socket.io connection timeout');
        },
      );
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation Socket.io: $e');
      _connectCompleter = null;
      // Ne pas rethrow : l'app continue via HTTP /sync
    }
  }

  /// Gérer les messages entrants depuis Socket.io
  void _handleMessage(String event, dynamic data) {
    try {
      // Convertir les données en Map si nécessaire
      dynamic payload = data;
      if (data is String) {
        try {
          payload = jsonDecode(data);
        } catch (e) {
          payload = data;
        }
      }

      // ✅ Log pour les événements importants
      if (event == 'card_distribution') {
        print('📥 Événement card_distribution reçu du serveur: $payload');
      }

      // Dispatcher l'événement aux listeners
      if (_eventControllers.containsKey(event)) {
        _eventControllers[event]!.add(payload);
        if (event == 'card_distribution') {
          print('✅ Événement card_distribution dispatché aux listeners');
        }
      } else {
        if (event == 'card_distribution') {
          print('⚠️ Aucun listener pour card_distribution');
        }
      }
      
      // Événement générique
      if (_eventControllers.containsKey('*')) {
        _eventControllers['*']!.add({'event': event, 'data': payload});
      }
    } catch (e) {
      print('Erreur lors du traitement du message Socket.io: $e');
    }
  }

  /// Gérer les erreurs
  void _handleError(dynamic error) {
    print('Erreur WebSocket: $error');
    if (_eventControllers.containsKey('error')) {
      _eventControllers['error']!.add(error);
    }
  }

  /// Gérer la déconnexion
  void _handleDisconnect() {
    print('Déconnexion WebSocket');
    if (_eventControllers.containsKey('disconnect')) {
      _eventControllers['disconnect']!.add(null);
    }
  }

  /// Rejoindre une salle
  Future<void> joinRoom(String roomId, String playerName) async {
    _currentRoomId = roomId;
    _currentPlayerName = playerName;

    if (_socket == null || !_socket!.connected) {
      try {
        await connect();
      } catch (e) {
        print('⚠️ joinRoom: WebSocket indisponible ($e)');
        return;
      }
    }

    await _emit('join_room', {
      'roomId': roomId.toString(),
      'playerName': playerName,
    });
  }

  /// Quitter une salle
  Future<void> leaveRoom() async {
    if (_currentRoomId != null && _currentPlayerName != null) {
      await _emit('leave_room', {
        'roomId': _currentRoomId,
        'playerName': _currentPlayerName,
      });
    }
    _currentRoomId = null;
    _currentPlayerName = null;
  }


  /// Faire une annonce
  /// [playerName] est optionnel : si fourni, utilise ce nom (pour les bots), sinon utilise le joueur actuel
  Future<void> makeAnnouncement(int announcement, {String? playerName}) async {
    await _emit('make_announcement', {
      'roomId': _currentRoomId,
      'playerName': playerName ?? _currentPlayerName,
      'announcement': announcement,
    });
  }

  /// Envoyer un message de chat dans la salle
  Future<void> sendChatMessage({
    required String message,
    String type = 'text',
    String? presetCode,
  }) async {
    await _emit('room_chat_message', {
      'roomId': _currentRoomId,
      'playerName': _currentPlayerName,
      'message': message,
      'message_type': type,
      if (presetCode != null) 'preset_code': presetCode,
    });
  }

  /// Démarrer le jeu
  Future<void> startGame(List<String> players) async {
    await _emit('start_game', {
      'roomId': _currentRoomId,
      'players': players,
    });
  }

  /// Annoncer qu'un round est terminé
  Future<void> roundCompleted(
    int roundNumber,
    Map<String, int> scores, {
    Map<String, int>? announcedByPlayer,
    Map<String, int>? obtainedByPlayer,
  }) async {
    await _emit('round_completed', {
      'roomId': _currentRoomId,
      'roundNumber': roundNumber,
      'scores': scores,
      if (announcedByPlayer != null) 'announcedByPlayer': announcedByPlayer,
      if (obtainedByPlayer != null) 'obtainedByPlayer': obtainedByPlayer,
    });
  }

  /// Envoyer la distribution des cartes (créateur uniquement)
  Future<void> broadcastCardDistribution({
    required Map<String, List<String>> distribution,
    required int roundNumber,
  }) async {
    final data = {
      'roomId': _currentRoomId,
      'distribution': distribution,
      'round_number': roundNumber,
      'timestamp': DateTime.now().toIso8601String(),
    };
    print('📤 Émission card_distribution: roomId=$_currentRoomId, round=$roundNumber, joueurs=${distribution.keys.toList()}');
    await _emit('card_distribution', data);
  }

  /// Émettre un événement via Socket.io
  Future<void> _emit(String event, Map<String, dynamic> data) async {
    if (_socket == null || !_socket!.connected) {
      print('⚠️ Tentative d\'émission Socket.io sans connexion: $event');
      // Ne pas throw pour éviter de bloquer l'application
      return;
    }

    try {
      _socket!.emit(event, data);
    } catch (e) {
      print('⚠️ Erreur lors de l\'émission Socket.io: $e');
      // Ne pas throw pour éviter de bloquer l'application
    }
  }

  /// S'abonner à un événement
  Stream<dynamic> on(String event) {
    if (!_eventControllers.containsKey(event)) {
      _eventControllers[event] = StreamController<dynamic>.broadcast();
    }
    return _eventControllers[event]!.stream;
  }

  /// S'abonner à tous les événements
  Stream<dynamic> onAny() {
    return on('*');
  }

  /// S'abonner au join de joueur
  Stream<dynamic> onPlayerJoined() => on('player_joined');
  
  /// S'abonner au leave de joueur
  Stream<dynamic> onPlayerLeft() => on('player_left');
  
  /// S'abonner à la jouée de carte
  Stream<dynamic> onCardPlayed() => on('card_played');
  
  /// S'abonner à l'annonce faite (ancien système séquentiel)
  Stream<dynamic> onAnnouncementMade() => on('announcement_made');
  
  /// ✅ NOUVEAU: S'abonner au démarrage de la phase d'annonces simultanée
  Stream<dynamic> onAnnouncementPhaseStarted() => on('announcement_phase_started');
  
  /// ✅ NOUVEAU: S'abonner à une soumission d'annonce (système simultané)
  Stream<dynamic> onAnnouncementSubmitted() => on('announcement_submitted');
  
  /// ✅ NOUVEAU: S'abonner à la fin des annonces (système simultané)
  Stream<dynamic> onAnnouncementsComplete() => on('announcements_complete');
  
  /// S'abonner au démarrage du jeu
  Stream<dynamic> onGameStarted() => on('game_started');
  
  /// S'abonner à la fin d'un pli
  Stream<dynamic> onTrickCompleted() => on('trick_completed');

  /// ✅ NOUVEAU: Écouter l'événement turn_changed pour synchroniser le tour
  Stream<dynamic> onTurnChanged() => on('turn_changed');
  
  /// S'abonner à la mise à jour des scores d'un round
  Stream<dynamic> onRoundScoresUpdated() => on('round_scores_updated');
  
  /// S'abonner à la fin d'un round
  Stream<dynamic> onRoundCompleted() => on('round_completed_broadcast');
  
  /// ✅ NOUVEAU: S'abonner à l'événement de fin des annonces
  Stream<dynamic> onAllAnnouncementsCompleted() => on('all_announcements_completed');
  
  /// S'abonner à la connexion
  Stream<dynamic> onConnect() => on('connect');
  
  /// S'abonner aux erreurs
  Stream<dynamic> onError() => on('error');
  
  /// S'abonner à la déconnexion
  Stream<dynamic> onDisconnect() => on('disconnect');

  // ⚠️ NOUVEAU: S'abonner au remplacement d'un joueur par un bot
  Stream<dynamic> onPlayerReplaced() => on('player_replaced');
  
  // ⚠️ NOUVEAU: S'abonner à la restauration d'un joueur
  Stream<dynamic> onPlayerRestored() => on('player_restored');
  
  // ⚠️ NOUVEAU: S'abonner à la déconnexion d'un joueur (événement backend)
  Stream<dynamic> onPlayerDisconnected() => on('player_disconnected');
  
  // ⚠️ NOUVEAU: S'abonner à la reconnexion d'un joueur (événement backend)
  Stream<dynamic> onPlayerReconnected() => on('player_reconnected');
  
  // S'abonner aux messages de chat de la salle
  Stream<dynamic> onRoomChatMessage() => on('room_chat_message');

  // S'abonner à la distribution de cartes
  Stream<dynamic> onCardDistribution() => on('card_distribution');

  /// Se déconnecter
  Future<void> disconnect() async {
    if (_currentRoomId != null && _currentPlayerName != null) {
      await leaveRoom();
    }

    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    
    // Fermer tous les controllers
    for (var controller in _eventControllers.values) {
      await controller.close();
    }
    _eventControllers.clear();
  }

  /// Obtenir l'ID de la salle actuelle
  String? get currentRoomId => _currentRoomId;
  
  /// Obtenir le nom du joueur actuel
  String? get currentPlayerName => _currentPlayerName;
  
  /// Vérifier si connecté
  bool get isConnected => _socket != null && _socket!.connected;
}

