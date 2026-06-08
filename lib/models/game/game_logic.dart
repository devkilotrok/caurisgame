import 'dart:math' as math;

class GameLogic {
  static GameLogic? _instance;
  static GameLogic get instance => _instance ??= GameLogic._internal();
  
  GameLogic._internal();

  // Ordre des cartes (de la plus forte à la plus faible)
  static const Map<String, int> cardValues = {
    'A': 14, 'K': 13, 'Q': 12, 'J': 11, '0': 10,
    '9': 9, '8': 8, '7': 7, '6': 6, '5': 5, '4': 4, '3': 3, '2': 2
  };

  // Couleurs des cartes
  static const Map<String, String> cardColors = {
    'H': 'hearts',    // Cœur (rouge)
    'D': 'diamonds',  // Carreau (rouge)
    'S': 'spades',    // Pique (noir) - ATOUT
    'C': 'clubs'      // Trèfle (noir)
  };

  // État du jeu actuel
  List<Map<String, dynamic>> _currentTrick = [];
  String? _leadingSuit;
  String? _leadingPlayer;
  List<Map<String, dynamic>> _playedCards = [];
  List<Map<String, dynamic>> _announcements = [];
  bool _isTrickComplete = false;
  String? _trickWinner;
  int _playersPerTrick = 4;
  int _cardsPerPlayer = 13;

  // Getters
  List<Map<String, dynamic>> get currentTrick => List.from(_currentTrick);
  String? get leadingSuit => _leadingSuit;
  String? get leadingPlayer => _leadingPlayer;
  List<Map<String, dynamic>> get playedCards => List.from(_playedCards);
  List<Map<String, dynamic>> get announcements => List.from(_announcements);
  bool get isTrickComplete => _isTrickComplete;
  String? get trickWinner => _trickWinner;
  int get playersPerTrick => _playersPerTrick;

  /// Configure dynamiquement le nombre de joueurs/cartes selon le mode courant.
  void configurePlayers({
    required int playerCount,
    required int cardsPerPlayer,
  }) {
    if (playerCount >= 2) {
      _playersPerTrick = playerCount;
    }
    if (cardsPerPlayer > 0) {
      _cardsPerPlayer = cardsPerPlayer;
    }
  }

  /// Synchronise le pli actuel avec celui du LocalCardManager
  /// Cette méthode doit être appelée avant getPlayableCards pour garantir
  /// que _leadingSuit est correctement défini
  void syncCurrentTrick(List<Map<String, dynamic>> currentTrick) {
    _currentTrick = List.from(currentTrick);
    
    // Mettre à jour _leadingSuit et _leadingPlayer si le pli n'est pas vide
    if (_currentTrick.isNotEmpty) {
      final firstCard = _currentTrick.first['card'] as Map<String, dynamic>?;
      if (firstCard != null) {
        final cardCode = firstCard['code'] as String? ?? '';
        if (cardCode.isNotEmpty) {
          _leadingSuit = cardCode.substring(1); // Dernier caractère = couleur
          _leadingPlayer = _currentTrick.first['player'] as String?;
        }
      }
    } else {
      _leadingSuit = null;
      _leadingPlayer = null;
    }
  }

  // Fonction pour valider les enchères
  Map<String, dynamic> validateAnnouncements(List<Map<String, dynamic>> announcements) {
    print('📊 Validation des annonces reçues: $announcements');
    
    // Vérifier si le total des mises est inférieur à 10
    final totalAnnouncements = announcements.fold<int>(
      0, 
      (sum, announcement) => sum + (announcement['announcement'] as int? ?? 0)
    );
    
    print('📊 Total des annonces: $totalAnnouncements');

    if (totalAnnouncements < 10) {
      print('⚠️ Total < 10, besoin d\'augmenter les annonces de +1');
      return {
        'valid': false,
        'needsRedistribution': false,
        'needsNewBids': true,
        'reason': 'Total des annonces inférieur à 10'
      };
    }

    print('✅ Annonces valides, total > 10');
    return {
      'valid': true,
      'needsRedistribution': false,
      'needsNewBids': false,
      'reason': 'Annonces valides'
    };
  }

  // Fonction pour vérifier si un joueur a des piques (atouts)
  bool hasSpades(List<Map<String, dynamic>> cards) {
    for (var card in cards) {
      final code = card['code'] as String;
      final suit = code.substring(1); // Ex: "AS" -> "S"
      
      // Vérifier si c'est un pique (atout)
      if (suit == 'S') {
        return true;
      }
    }
    return false;
  }

  // Fonction pour vérifier si un joueur a des figures ou des piques (ancienne fonction, conservée pour compatibilité)
  bool _hasFiguresOrSpades(List<Map<String, dynamic>> cards) {
    for (var card in cards) {
      final code = card['code'] as String;
      final suit = code.substring(1); // Ex: "AS" -> "S"
      final value = code.substring(0, 1); // Ex: "AS" -> "A"
      
      // Vérifier si c'est une figure (J, Q, K, A)
      if (['J', 'Q', 'K', 'A'].contains(value)) {
        return true;
      }
      
      // Vérifier si c'est un pique (atout)
      if (suit == 'S') {
        return true;
      }
    }
    return false;
  }

  // Fonction pour déterminer les cartes jouables
  List<Map<String, dynamic>> getPlayableCards(
    List<Map<String, dynamic>> playerCards,
    String playerName,
    bool isFirstCard
  ) {
    if (isFirstCard) {
      // Premier joueur peut jouer n'importe quelle carte
      return playerCards;
    }

    final playableCards = <Map<String, dynamic>>[];
    
    for (var card in playerCards) {
      if (_canPlayCard(card, playerCards)) {
        playableCards.add(card);
      }
    }

    // « Surmontage forcé »: si on peut battre la meilleure carte courante
    // alors on DOIT jouer une carte qui bat.
    if (_currentTrick.isNotEmpty && playableCards.isNotEmpty) {
      final bestSoFar = _getCurrentBestPlay();
      if (bestSoFar != null) {
        final winners = playableCards.where((c) => _doesCardBeat(c, bestSoFar)).toList();
        if (winners.isNotEmpty) {
          return winners;
        }
      }
    }

    // SI AUCUNE CARTE N'EST JOUABLE SELON LES RÈGLES STRICTES,
    // retourner toutes les cartes du joueur (fallback)
    if (playableCards.isEmpty && playerCards.isNotEmpty) {
      print('⚠️ Aucune carte strictement jouable pour $playerName, on permet toutes les cartes');
      return playerCards;
    }

    return playableCards;
  }

  // Fonction pour vérifier si une carte peut être jouée
  bool _canPlayCard(Map<String, dynamic> card, List<Map<String, dynamic>> playerCards) {
    final code = card['code'] as String;
    final cardSuit = code.substring(1);

    // Si c'est la première carte du pli, toutes les cartes sont jouables
    if (_currentTrick.isEmpty) {
      return true;
    }

    // Obtenir la couleur demandée (première carte du pli)
    final leadingCardSuit = _leadingSuit!; // 'D', 'C', 'H', 'S'

    // 1. Si le joueur a la couleur demandée, il DOIT jouer cette couleur
    final hasLeadingSuit = _hasSuit(playerCards, leadingCardSuit);
    if (hasLeadingSuit) {
      final canPlay = cardSuit == leadingCardSuit;
      // ❌ Supprimer le log pour éviter les boucles infinies lors des rebuilds
      // if (!canPlay) print('🚫 Carte $code refusée: doit jouer $leadingCardSuit');
      return canPlay;
    }

    // 2. Si le joueur n'a pas la couleur demandée MAIS a des atouts (piques)
    //    alors il DOIT jouer un atout (pique)
    if (leadingCardSuit != 'S') { // Si la couleur demandée n'est pas déjà un pique
      final hasSpades = _hasSpades(playerCards);
      if (hasSpades) {
        final canPlay = cardSuit == 'S';
        // ❌ Supprimer le log pour éviter les boucles infinies lors des rebuilds
        // if (!canPlay) print('🚫 Carte $code refusée: doit jouer un atout (S)');
        return canPlay;
      }
    }

    // 3. Si le joueur n'a ni la couleur demandée ni d'atout, il peut jouer n'importe quelle carte
    // ❌ Supprimer le log pour éviter les boucles infinies lors des rebuilds
    // print('✅ Carte $code acceptée: pas de $leadingCardSuit ni d\'atout');
    return true;
  }

  // Fonction pour vérifier si le joueur peut suivre la couleur
  bool _canFollowSuit(String suit, List<Map<String, dynamic>> playerCards) {
    return playerCards.any((card) => card['code'].toString().substring(1) == suit);
  }

  // Fonction pour vérifier si le joueur a une couleur donnée
  bool _hasSuit(List<Map<String, dynamic>> playerCards, String suit) {
    // ✅ Vérifier à la fois le code ET le suit pour éviter les confusions
    return playerCards.any((card) {
      final code = card['code'] as String? ?? '';
      final cardSuit = card['suit'] as String? ?? '';
      final codeSuit = code.isNotEmpty ? code.substring(1) : '';
      
      // Mapping des codes aux suits
      final suitMapping = {
        'S': 'SPADES',
        'C': 'CLUBS',
        'H': 'HEARTS',
        'D': 'DIAMONDS',
      };
      
      // Vérifier que le code correspond ET que le suit correspond (si défini)
      final expectedSuit = suitMapping[suit] ?? '';
      return codeSuit == suit && 
             (cardSuit.isEmpty || cardSuit == expectedSuit);
    });
  }

  // Fonction pour vérifier si le joueur a des piques
  bool _hasSpades(List<Map<String, dynamic>> playerCards) {
    // ✅ Vérifier à la fois le code ET le suit pour éviter les confusions
    return playerCards.any((card) {
      final code = card['code'] as String? ?? '';
      final suit = card['suit'] as String? ?? '';
      // Vérifier que c'est bien un pique (S dans le code ET SPADES dans le suit)
      return code.isNotEmpty && 
             code.substring(1) == 'S' && 
             (suit == 'SPADES' || suit.isEmpty); // Permettre si suit n'est pas défini
    });
  }

  // Fonction pour jouer une carte
  Map<String, dynamic> playCard(
    Map<String, dynamic> card,
    String playerName,
    List<Map<String, dynamic>> playerCards
  ) {
    final playableCards = getPlayableCards(playerCards, playerName, _currentTrick.isEmpty);
    final cardCode = (card['code'] as String?)?.toUpperCase() ?? '';
    final isPlayable = cardCode.isNotEmpty &&
        playableCards.any(
          (c) => ((c['code'] as String?)?.toUpperCase() ?? '') == cardCode,
        );

    if (!isPlayable) {
      return {
        'success': false,
        'message': 'Carte non jouable',
      };
    }

    // Ajouter la carte au pli actuel
    _currentTrick.add({
      'card': card,
      'player': playerName,
      'timestamp': DateTime.now(),
    });

    // Si c'est la première carte, définir la couleur menante
    if (_currentTrick.length == 1) {
      _leadingSuit = card['code'].toString().substring(1);
      _leadingPlayer = playerName;
    }

    // Vérifier si le pli est complet (nombre de joueurs courant)
    if (_currentTrick.length == _playersPerTrick) {
      _isTrickComplete = true;
      _trickWinner = _determineTrickWinner();
      
      return {
        'success': true,
        'trickComplete': true,
        'winner': _trickWinner,
        'message': 'Pli terminé',
      };
    }

    return {
      'success': true,
      'trickComplete': false,
      'message': 'Carte jouée',
    };
  }

  // Fonction pour déterminer le gagnant du pli
  String _determineTrickWinner() {
    if (_currentTrick.isEmpty) return '';

    String winner = '';
    Map<String, dynamic>? winningCard;
    int highestValue = 0;
    bool hasSpade = false;

    for (var play in _currentTrick) {
      final card = play['card'] as Map<String, dynamic>;
      final player = play['player'] as String;
      final code = card['code'] as String;
      final suit = code.substring(1);
      final value = code.substring(0, 1);
      final cardValue = cardValues[value] ?? 0;

      // Si c'est un pique (atout)
      if (suit == 'S') {
        if (!hasSpade || cardValue > highestValue) {
          hasSpade = true;
          highestValue = cardValue;
          winningCard = card;
          winner = player;
        }
      } else if (!hasSpade && suit == _leadingSuit) {
        // Si ce n'est pas un pique mais que c'est la couleur menante
        if (cardValue > highestValue) {
          highestValue = cardValue;
          winningCard = card;
          winner = player;
        }
      }
    }

    return winner;
  }

  // Retourne le meilleur jeu actuel (carte + joueur) selon l'atout pique
  Map<String, dynamic>? _getCurrentBestPlay() {
    if (_currentTrick.isEmpty) return null;

    Map<String, dynamic>? bestPlay;
    int highestValue = 0;
    bool hasSpade = false;
    final leading = _leadingSuit ?? (_currentTrick.first['card']['code'] as String).substring(1);

    for (var play in _currentTrick) {
      final card = play['card'] as Map<String, dynamic>;
      final code = card['code'] as String;
      final suit = code.substring(1);
      final value = code.substring(0, 1);
      final v = cardValues[value] ?? 0;

      if (suit == 'S') {
        if (!hasSpade || v > highestValue) {
          hasSpade = true;
          highestValue = v;
          bestPlay = play;
        }
      } else if (!hasSpade && suit == leading) {
        if (v > highestValue) {
          highestValue = v;
          bestPlay = play;
        }
      }
    }

    return bestPlay;
  }

  // Indique si « candidate » bat la meilleure carte déjà jouée (bestPlay)
  bool _doesCardBeat(Map<String, dynamic> candidate, Map<String, dynamic> bestPlay) {
    final bestCard = bestPlay['card'] as Map<String, dynamic>;

    final candCode = candidate['code'] as String;
    final candSuit = candCode.substring(1);
    final candValKey = candCode.substring(0, 1);
    final candVal = cardValues[candValKey] ?? 0;

    final bestCode = bestCard['code'] as String;
    final bestSuit = bestCode.substring(1);
    final bestValKey = bestCode.substring(0, 1);
    final bestVal = cardValues[bestValKey] ?? 0;

    final leading = _leadingSuit ?? (_currentTrick.first['card']['code'] as String).substring(1);

    // Règles d'opposition:
    // - Un pique bat toute carte non-pique
    // - Entre piques, la plus forte valeur gagne
    // - Si aucun pique impliqué, seule la couleur menante se compare; cartes d'autres couleurs ne battent pas
    if (candSuit == 'S' && bestSuit != 'S') {
      return true;
    }
    if (candSuit == 'S' && bestSuit == 'S') {
      return candVal > bestVal;
    }
    if (bestSuit == 'S' && candSuit != 'S') {
      return false;
    }
    // Aucun pique en jeu: doit être de la couleur menante et plus fort
    if (candSuit == leading && bestSuit == leading) {
      return candVal > bestVal;
    }
    // Si la meilleure carte actuelle est de la couleur menante, une autre couleur ne peut pas la battre
    return false;
  }

  // Fonction pour passer au pli suivant
  void nextTrick() {
    _currentTrick.clear();
    _leadingSuit = null;
    _leadingPlayer = null;
    _isTrickComplete = false;
    _trickWinner = null;
  }

  // Fonction pour calculer les scores d'un pli
  Map<String, dynamic> calculateTrickScores(
    List<Map<String, dynamic>> announcements,
    List<Map<String, dynamic>> trickResults
  ) {
    final scores = <String, int>{};

    for (var announcement in announcements) {
      final playerName = announcement['player'] as String;
      final announced = announcement['announcement'] as int;
      
      // Trouver le nombre de plis obtenus par ce joueur
      final obtained = trickResults.where((result) => 
          result['player'] == playerName).length;

      // Calculer le score selon les règles
      if (announced == obtained) {
        scores[playerName] = announced * 10;
      } else if (obtained < announced) {
        scores[playerName] = -(announced * 10);
      } else if (obtained > announced && obtained <= announced + 2) {
        final surplus = obtained - announced;
        scores[playerName] = (announced * 10) + surplus;
      } else if (obtained >= announced + 3) {
        scores[playerName] = -(announced * 10);
      }
    }

    return {
      'success': true,
      'scores': scores,
    };
  }

  // Fonction pour vérifier si la manche est terminée
  bool isRoundComplete(List<Map<String, dynamic>> playedCards) {
    return playedCards.length >= _playersPerTrick * _cardsPerPlayer;
  }

  // Fonction pour vérifier si le jeu est terminé
  bool isGameComplete(Map<String, double> globalScores) {
    return globalScores.values.any((score) => score >= 150);
  }

  // Fonction pour obtenir le gagnant du jeu
  String? getGameWinner(Map<String, double> globalScores) {
    if (!isGameComplete(globalScores)) return null;
    
    return globalScores.entries
        .where((entry) => entry.value >= 150)
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  // Fonction pour réinitialiser la logique de jeu
  void reset() {
    _currentTrick.clear();
    _leadingSuit = null;
    _leadingPlayer = null;
    _playedCards.clear();
    _announcements.clear();
    _isTrickComplete = false;
    _trickWinner = null;
  }

  // Fonction pour obtenir les statistiques du jeu
  Map<String, dynamic> getGameStats() {
    return {
      'currentTrick': _currentTrick.length,
      'leadingSuit': _leadingSuit,
      'leadingPlayer': _leadingPlayer,
      'isTrickComplete': _isTrickComplete,
      'trickWinner': _trickWinner,
      'totalPlayedCards': _playedCards.length,
      'totalAnnouncements': _announcements.length,
    };
  }
}
