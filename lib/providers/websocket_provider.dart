import 'package:flutter/material.dart';
import 'dart:async';
import '../config/api_config.dart';
import '../services/websocket/game_websocket_service.dart';

/// Provider pour la gestion des communications WebSocket
class WebSocketProvider extends ChangeNotifier {
  final GameWebSocketService _wsService = GameWebSocketService();

  bool _isConnected = false;
  String? _currentRoomId;
  String? _currentPlayerName;
  String? _serverUrl = ApiConfig.websocketUrl;

  bool get isConnected => _isConnected;
  String? get currentRoomId => _currentRoomId;
  String? get currentPlayerName => _currentPlayerName;
  String get serverUrl => _serverUrl!;

  /// Se connecter au serveur WebSocket
  Future<bool> connect({String? serverUrl}) async {
    try {
      if (serverUrl != null) {
        _serverUrl = serverUrl;
      }

      await _wsService.connect(serverUrl: _serverUrl);
      _isConnected = true;

      // Écouter les événements
      _listenToEvents();

      notifyListeners();
      return true;
    } catch (e) {
      print('Erreur de connexion WebSocket: $e');
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  /// Écouter tous les événements
  void _listenToEvents() {
    _wsService.onAny().listen((data) {
      // Traiter les événements reçus
      notifyListeners();
    });

    _wsService.onError().listen((error) {
      print('Erreur WebSocket: $error');
    });

    _wsService.onDisconnect().listen((_) {
      _isConnected = false;
      notifyListeners();
    });
  }

  /// Rejoindre une salle
  Future<bool> joinRoom(String roomId, String playerName) async {
    try {
      await _wsService.joinRoom(roomId, playerName);
      _currentRoomId = roomId;
      _currentPlayerName = playerName;
      notifyListeners();
      return true;
    } catch (e) {
      print('Erreur lors de la réunion de la salle: $e');
      return false;
    }
  }

  /// Quitter une salle
  Future<bool> leaveRoom() async {
    try {
      await _wsService.leaveRoom();
      _currentRoomId = null;
      _currentPlayerName = null;
      notifyListeners();
      return true;
    } catch (e) {
      print('Erreur lors de la sortie de la salle: $e');
      return false;
    }
  }


  /// Faire une annonce
  Future<bool> makeAnnouncement(int announcement) async {
    try {
      await _wsService.makeAnnouncement(announcement);
      return true;
    } catch (e) {
      print('Erreur lors de l\'annonce: $e');
      return false;
    }
  }

  /// Démarrer le jeu
  Future<bool> startGame(List<String> players) async {
    try {
      await _wsService.startGame(players);
      return true;
    } catch (e) {
      print('Erreur lors du démarrage du jeu: $e');
      return false;
    }
  }

  /// Se déconnecter
  Future<void> disconnect() async {
    try {
      await _wsService.disconnect();
      _isConnected = false;
      _currentRoomId = null;
      _currentPlayerName = null;
      notifyListeners();
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
    }
  }

  /// Obtenir le service WebSocket pour les listeners
  GameWebSocketService get wsService => _wsService;

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

