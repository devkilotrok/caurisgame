import 'package:flutter/material.dart';
import '../../models/game/game_session.dart';
import 'game_room_bot_page.dart';
import 'game_room_human_page.dart';

/// Router pour diriger vers la bonne page de jeu selon le mode (bot ou humain)
class GameRoomRouter {
  /// Crée la page de jeu appropriée selon le mode
  static Widget buildGameRoomPage({
    required String roomName,
    required String roomCode,
    required int minimumBet,
    required String currentPlayerName,
  }) {
    // Obtenir la session de jeu pour déterminer le mode
    final session = GameSession.instance;
    
    // Utiliser la page modulaire appropriée selon le mode
    if (session.playWithBots) {
      return GameRoomBotPage(
        roomName: roomName,
        roomCode: roomCode,
        minimumBet: minimumBet,
        currentPlayerName: currentPlayerName,
      );
    } else {
      return GameRoomHumanPage(
        roomName: roomName,
        roomCode: roomCode,
        minimumBet: minimumBet,
        currentPlayerName: currentPlayerName,
      );
    }
  }
}

