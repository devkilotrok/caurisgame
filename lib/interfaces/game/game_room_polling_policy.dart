/// Intervalles HTTP de secours pour les salles multijoueur.
///
/// Le WebSocket (Render Starter) est la source temps réel ;
/// le polling HTTP ne sert qu'en cas de déconnexion WS ou attente de joueurs.
class GameRoomPollingPolicy {
  GameRoomPollingPolicy._();

  /// Délai avant un secours HTTP si les cartes n'arrivent pas via WebSocket.
  static const Duration distributionFallbackDelay = Duration(seconds: 5);
  static const Duration distributionFirstRetryDelay = Duration(milliseconds: 800);

  /// Un seul GET /rooms/{id}/sync (fusion ancien room + state sync).
  static Duration roomSyncInterval({
    required bool webSocketConnected,
    required bool waitingForPlayers,
    required bool announcementPhase,
    required bool cardsReceived,
  }) {
    if (webSocketConnected) {
      // Phase d'annonces : polling de secours même si WS connecté (fin de phase manquée)
      if (announcementPhase && cardsReceived) {
        return const Duration(seconds: 8);
      }
      if (cardsReceived && !waitingForPlayers) {
        return const Duration(seconds: 60);
      }
      if (waitingForPlayers) {
        return const Duration(seconds: 15);
      }
      if (!cardsReceived) {
        return distributionFallbackDelay;
      }
      return const Duration(seconds: 45);
    }

    // WebSocket coupé : polling de secours plus fréquent
    if (waitingForPlayers) {
      return const Duration(seconds: 4);
    }
    if (announcementPhase) {
      return const Duration(seconds: 8);
    }
    if (!cardsReceived) {
      return const Duration(seconds: 5);
    }
    return const Duration(seconds: 6);
  }

  /// Pas d'appel sync si le WebSocket gère déjà la phase en cours.
  static bool shouldSkipRoomSync({
    required bool webSocketConnected,
    required bool announcementPhase,
    required bool waitingForPlayers,
    required bool cardsReceived,
  }) {
    if (!webSocketConnected) return false;
    if (waitingForPlayers) return false;
    if (!cardsReceived) return false;
    // Secours : vérifier /sync pendant les annonces si le WS a manqué announcements_complete
    if (announcementPhase) return false;
    return true;
  }
}
