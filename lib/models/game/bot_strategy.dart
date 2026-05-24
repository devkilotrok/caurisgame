class BotStrategy {
  /// Calcule une annonce "intelligente" entre 2 et 13 en fonction
  /// de la force réelle de la main (atouts, longueurs, honneurs).
  /// cards: List<Map> avec au moins 'code' (ex: 'AS') et 'value', 'suit' (optionnels)
  static int calculateSmartAnnouncement(
    List<Map<String, dynamic>> cards,
    int totalAlreadyAnnounced,
  ) {
    if (cards.isEmpty || cards.length != 13) return 2;

    // Analyser la main en détail
    final atouts = <Map<String, dynamic>>[]; // Piques (atouts)
    final hearts = <Map<String, dynamic>>[];
    final diamonds = <Map<String, dynamic>>[];
    final clubs = <Map<String, dynamic>>[];
    
    // Séparer les cartes par couleur
    for (final c in cards) {
      final code = (c['code'] as String?) ?? '';
      if (code.length < 2) continue;
      final suit = code.substring(1); // S,H,D,C
      switch (suit) {
        case 'S':
          atouts.add(c);
          break;
        case 'H':
          hearts.add(c);
          break;
        case 'D':
          diamonds.add(c);
          break;
        case 'C':
          clubs.add(c);
          break;
      }
    }

    // 1. ÉVALUER LES ATOUTS (Piques) - C'est la force principale
    int tricksFromAtouts = _evaluateAtouts(atouts);
    
    // 2. ÉVALUER LES COULEURS LONGUES (5+ cartes)
    int tricksFromLongSuits = 0;
    if (hearts.length >= 5) tricksFromLongSuits += _evaluateLongSuit(hearts);
    if (diamonds.length >= 5) tricksFromLongSuits += _evaluateLongSuit(diamonds);
    if (clubs.length >= 5) tricksFromLongSuits += _evaluateLongSuit(clubs);
    
    // 3. ÉVALUER LES HONNEURS DANS LES AUTRES COULEURS (pour plis défensifs)
    int tricksFromHonors = 0;
    tricksFromHonors += _evaluateHonors(hearts);
    tricksFromHonors += _evaluateHonors(diamonds);
    tricksFromHonors += _evaluateHonors(clubs);
    
    // 4. BONUS si beaucoup d'atouts (contrôle)
    int bonus = 0;
    if (atouts.length >= 5) bonus += 1; // 5+ atouts = contrôle
    if (atouts.length >= 6) bonus += 1; // 6+ atouts = fort contrôle
    
    // 5. CALCULER LE TOTAL DE PLIS PROBABLES
    int probableTricks = tricksFromAtouts + tricksFromLongSuits + tricksFromHonors + bonus;
    
    // 6. Ajuster selon les annonces déjà faites
    int remainingTricks = 13 - totalAlreadyAnnounced;
    if (probableTricks > remainingTricks) {
      // On ne peut pas annoncer plus que ce qui reste
      probableTricks = remainingTricks;
    }
    
    // 7. Être conservateur : annoncer 70-80% de ce qu'on pense faire
    int announcement = (probableTricks * 0.75).round().clamp(2, 13);
    
    // 8. Si beaucoup d'annonces déjà faites, être encore plus conservateur
    if (totalAlreadyAnnounced >= 8) {
      announcement = (announcement * 0.8).round().clamp(2, 13);
    } else if (totalAlreadyAnnounced >= 6) {
      announcement = (announcement * 0.85).round().clamp(2, 13);
    }
    
    return announcement.clamp(2, 13);
  }

  /// Évalue les atouts (piques) pour déterminer combien de plis ils peuvent faire
  static int _evaluateAtouts(List<Map<String, dynamic>> atouts) {
    if (atouts.isEmpty) return 0;
    
    // Trier les atouts par valeur (A, K, Q, J, 10, 9, ...)
    final sortedAtouts = List<Map<String, dynamic>>.from(atouts);
    sortedAtouts.sort((a, b) {
      final aCode = (a['code'] as String).substring(0, 1);
      final bCode = (b['code'] as String).substring(0, 1);
      return _getValueOrder(bCode) - _getValueOrder(aCode);
    });
    
    double tricks = 0.0;
    int highAtouts = 0; // A, K, Q, J, 10
    
    for (final card in sortedAtouts) {
      final code = card['code'] as String;
      final value = code.substring(0, 1);
      
      if (value == 'A') {
        tricks += 1.0; // As d'atout fait presque toujours un pli
        highAtouts++;
      } else if (value == 'K') {
        if (atouts.length >= 2) tricks += 1.0; // Roi fait un pli si on a au moins 2 atouts
        highAtouts++;
      } else if (value == 'Q') {
        if (atouts.length >= 3) tricks += 1.0; // Dame fait un pli si on a au moins 3 atouts
        highAtouts++;
      } else if (value == 'J') {
        if (atouts.length >= 4) tricks += 0.5; // Valet fait souvent un pli
        highAtouts++;
      } else if (value == '0') { // 10
        if (atouts.length >= 5) tricks += 0.5; // 10 peut faire un pli si beaucoup d'atouts
        highAtouts++;
      } else {
        // Atouts moyens/faibles : valeur selon la longueur
        if (atouts.length >= 6) tricks += 0.3;
      }
    }
    
    // Bonus pour avoir plusieurs hauts atouts consécutifs
    if (highAtouts >= 3) tricks += 0.5;
    if (highAtouts >= 4) tricks += 0.5;
    
    return tricks.round().clamp(0, atouts.length);
  }

  /// Évalue une couleur longue (5+ cartes) pour déterminer les plis possibles
  static int _evaluateLongSuit(List<Map<String, dynamic>> suit) {
    if (suit.length < 5) return 0;
    
    int tricks = 0;
    int honors = 0; // A, K, Q, J, 10
    
    for (final card in suit) {
      final code = card['code'] as String;
      final value = code.substring(0, 1);
      if (['A', 'K', 'Q', 'J', '0'].contains(value)) {
        honors++;
      }
    }
    
    // Une couleur longue avec honneurs peut faire plusieurs plis
    if (suit.length == 5) {
      tricks = honors >= 2 ? 1 : 0;
    } else if (suit.length == 6) {
      tricks = honors >= 2 ? 2 : 1;
    } else if (suit.length >= 7) {
      tricks = honors >= 2 ? 3 : 2;
    }
    
    return tricks;
  }

  /// Évalue les honneurs dans une couleur pour les plis défensifs
  static int _evaluateHonors(List<Map<String, dynamic>> suit) {
    if (suit.isEmpty || suit.length < 2) return 0;
    
    double tricks = 0.0;
    bool hasAce = false;
    bool hasKing = false;
    bool hasQueen = false;
    
    for (final card in suit) {
      final code = card['code'] as String;
      final value = code.substring(0, 1);
      if (value == 'A') hasAce = true;
      if (value == 'K') hasKing = true;
      if (value == 'Q') hasQueen = true;
    }
    
    // A-K ensemble font presque toujours 2 plis
    if (hasAce && hasKing && suit.length >= 3) {
      tricks += 1.0;
    } else if (hasAce && suit.length >= 2) {
      tricks += 0.5; // As seul peut faire un pli
    }
    
    return tricks.round();
  }

  /// Retourne l'ordre de valeur d'une carte (14 pour A, 13 pour K, etc.)
  static int _getValueOrder(String value) {
    switch (value) {
      case 'A': return 14;
      case 'K': return 13;
      case 'Q': return 12;
      case 'J': return 11;
      case '0': return 10;
      case '9': return 9;
      case '8': return 8;
      case '7': return 7;
      case '6': return 6;
      case '5': return 5;
      case '4': return 4;
      case '3': return 3;
      case '2': return 2;
      default: return 0;
    }
  }
}


