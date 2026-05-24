import 'package:flutter/material.dart';
import '../services/game/game_service.dart';
import '../services/websocket/game_websocket_service.dart';
import '../models/room/room_manager.dart';

/// Provider pour la gestion des salles et des parties
class RoomProvider extends ChangeNotifier {
  final GameService _gameService = GameService.instance;
  final RoomManager _roomManager = RoomManager.instance;
  final GameWebSocketService _wsService = GameWebSocketService();

  String? _currentRoomId;
  String? _currentRoomCode;
  String? _currentRoomName;
  List<String> _players = [];
  bool _isInRoom = false;
  bool _isGameStarted = false;
  String? _currentPlayerTurn;

  String? get currentRoomId => _currentRoomId;
  String? get currentRoomCode => _currentRoomCode;
  String? get currentRoomName => _currentRoomName;
  List<String> get players => _players;
  bool get isInRoom => _isInRoom;
  bool get isGameStarted => _isGameStarted;
  String? get currentPlayerTurn => _currentPlayerTurn;

  /// Créer une salle
  Future<String?> createRoom(String roomName, int minimumBid) async {
    try {
      final roomCode = await _gameService.createRoom(roomName, minimumBid);

      if (roomCode != null) {
        _currentRoomId = _roomManager.getCurrentRoomId();
        _currentRoomCode = roomCode;
        _currentRoomName = roomName;
        _isInRoom = true;

        // Rejoindre via WebSocket si connecté
        if (_wsService.isConnected) {
          await _wsService.joinRoom(_currentRoomId!, _roomManager.getCreatorPseudo()!);
        }

        notifyListeners();
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
      final success = await _gameService.joinRoom(roomCode);

      if (success) {
        _currentRoomId = _roomManager.getCurrentRoomId();
        _currentRoomCode = roomCode;
        _currentRoomName = _roomManager.getCurrentRoomName();
        _players = _roomManager.getRoomPlayers();
        _isInRoom = true;

        // Rejoindre via WebSocket si connecté
        if (_wsService.isConnected) {
          await _wsService.joinRoom(_currentRoomId!, _roomManager.getCurrentPlayerPseudo()!);
        }

        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      print('Erreur lors de la réunion de la salle: $e');
      return false;
    }
  }

  /// Démarrer le jeu
  Future<void> startGame() async {
    try {
      await _gameService.startGame();
      _isGameStarted = true;

      // Notifier via WebSocket
      if (_wsService.isConnected) {
        await _wsService.startGame(_players);
      }

      notifyListeners();
    } catch (e) {
      print('Erreur lors du démarrage du jeu: $e');
      rethrow;
    }
  }

  /// Quitter la salle
  Future<void> leaveRoom() async {
    try {
      // Quitter via WebSocket
      if (_wsService.isConnected) {
        await _wsService.leaveRoom();
      }

      _currentRoomId = null;
      _currentRoomCode = null;
      _currentRoomName = null;
      _players.clear();
      _isInRoom = false;
      _isGameStarted = false;
      _currentPlayerTurn = null;

      notifyListeners();
    } catch (e) {
      print('Erreur lors de la sortie de la salle: $e');
    }
  }

  /// Obtenir les données de la session
  getGameSessionData() {
    return _gameService.gameSession;
  }
}

