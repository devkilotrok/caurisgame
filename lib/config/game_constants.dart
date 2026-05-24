class GameConstants {
  GameConstants._();

  /// Nombre standard de joueurs requis par partie (règle officielle).
  static const int standardPlayerCount = 4;

  /// Mode temporaire: permettre de démarrer une partie humaine à 2 joueurs.
  /// ✅ Utilisé uniquement en mode développement pour faciliter les tests.
  static const int temporaryHumanPlayerCount = 2;

  /// 🎯 FLAG DE DÉVELOPPEMENT
  /// 
  /// - `true` : Mode développement (2 joueurs pour faciliter les tests)
  /// - `false` : Mode production (4 joueurs selon les règles officielles)
  /// 
  /// ✅ Changez simplement ce flag pour basculer entre dev et production !
  static const bool isDevelopment = false;

  /// Nombre total de cartes dans le paquet.
  static const int totalDeckCards = 52;

  /// Retourne le nombre de joueurs requis selon le mode actuel.
  /// 
  /// En mode développement (`isDevelopment = true`), les parties humaines
  /// nécessitent seulement 2 joueurs pour faciliter les tests.
  /// En production (`isDevelopment = false`), le nombre standard de 4 joueurs est requis.
  static int requiredPlayerCount({required bool playWithBots}) {
    if (playWithBots) return standardPlayerCount;
    return isDevelopment
        ? temporaryHumanPlayerCount
        : standardPlayerCount;
  }

  /// Nombre de cartes distribuées par joueur.
  ///
  /// On garde 13 cartes par joueur même en mode test (2 joueurs) pour limiter
  /// l'impact sur la logique existante. Cela facilite également le retour
  /// rapide au format 4 joueurs.
  static int cardsPerPlayerForCount(int playerCount) {
    if (playerCount <= 0) return 0;
    return totalDeckCards ~/ standardPlayerCount; // 13 cartes
  }
}

