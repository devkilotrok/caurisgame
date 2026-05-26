/// Intervalles HTTP de secours pour les salles multijoueur.
///
/// Le WebSocket reste la source temps réel ; le polling ne sert qu'à
/// rattraper les déconnexions et l'attente des joueurs.
class GameRoomPollingPolicy {
  GameRoomPollingPolicy._();

  /// Un seul GET /rooms/{id} (fusion ancien room + state sync).
  static Duration roomSyncInterval({
    required bool webSocketConnected,
    required bool waitingForPlayers,
    required bool announcementPhase,
  }) {
    if (announcementPhase && webSocketConnected) {
      return const Duration(seconds: 30);
    }
    if (waitingForPlayers) {
      return webSocketConnected
          ? const Duration(seconds: 6)
          : const Duration(seconds: 4);
    }
    return webSocketConnected
        ? const Duration(seconds: 12)
        : const Duration(seconds: 6);
  }

  /// Pas d'appel getRoom si WS actif et phase d'annonces gérée par événements.
  static bool shouldSkipRoomSync({
    required bool webSocketConnected,
    required bool announcementPhase,
  }) {
    return announcementPhase && webSocketConnected;
  }

}
