import 'package:flutter/foundation.dart';

class GameConstants {
  GameConstants._();

  /// Nombre standard de joueurs requis par partie (règle officielle).
  static const int standardPlayerCount = 4;

  /// Mode test : 2 humains en salle, puis 2 bots ajoutés automatiquement.
  static const int temporaryHumanPlayerCount = 2;

  /// Active le test « 2 humains + 2 bots » au build (release ou debug).
  ///
  /// APK test :
  ///   flutter build apk --release --dart-define=ENABLE_TWO_HUMAN_TEST=true
  ///
  /// PC (debug) : activé aussi automatiquement via [kDebugMode].
  static const bool enableTwoHumanTest = bool.fromEnvironment(
    'ENABLE_TWO_HUMAN_TEST',
    defaultValue: false,
  );

  /// Mode test 2 humains + 2 bots (build flag ou `flutter run` debug).
  static bool get allowTwoHumanWithBotsTest =>
      enableTwoHumanTest || kDebugMode;

  /// Alias legacy (UI).
  static bool get isDevelopment => allowTwoHumanWithBotsTest;

  /// Nombre total de cartes dans le paquet.
  static const int totalDeckCards = 52;

  /// Retourne le nombre de joueurs humains requis avant d'entrer en partie.
  static int requiredPlayerCount({required bool playWithBots}) {
    if (playWithBots) return standardPlayerCount;
    return allowTwoHumanWithBotsTest
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

