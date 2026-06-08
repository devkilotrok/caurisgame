import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/game_constants.dart';
import 'bot_strategy.dart';

class LocalCardManager {
  static LocalCardManager? _instance;
  static LocalCardManager get instance => _instance ??= LocalCardManager._internal();
  
  LocalCardManager._internal();

  // Déclaration directe de toutes les 52 cartes avec leurs images
  static const List<Map<String, dynamic>> _allCards = [
    // PIQUES (SPADES) - 13 cartes
    {'code': 'AS', 'value': 'ACE', 'suit': 'SPADES', 'image': 'assets/images/cards/spades_A.png'},
    {'code': '2S', 'value': '2', 'suit': 'SPADES', 'image': 'assets/images/cards/spades_2.png'},
    {'code': '3S', 'value': '3', 'suit': 'SPADES', 'image': 'assets/images/cards/spades_3.png'},
    {'code': '4S', 'value': '4', 'suit': 'SPADES', 'image': 'assets/images/cards/spades_4.png'},
    {'code': '5S', 'value': '5', 'suit': 'SPADES', 'image': 'assets/images/cards/spades_5.png'},
    {'code': '6S', 'value': '6', 'suit': 'SPADES', 'image': 'assets/images/cards/spades_6.png'},
    {'code': '7S', 'value': '7', 'suit': 'SPADES', 'image': 'assets/images/cards/spades_7.png'},
    {'code': '8S', 'value': '8', 'suit': 'SPADES', 'image': 'assets/images/cards/spades_8.png'},
    {'code': '9S', 'value': '9', 'suit': 'SPADES', 'image': 'assets/images/cards/spades_9.png'},
    {'code': '0S', 'value': '10', 'suit': 'SPADES', 'image': 'assets/images/cards/spades_10.png'},
    {'code': 'JS', 'value': 'JACK', 'suit': 'SPADES', 'image': 'assets/images/cards/spades_J.png'},
    {'code': 'QS', 'value': 'QUEEN', 'suit': 'SPADES', 'image': 'assets/images/cards/spades_Q.png'},
    {'code': 'KS', 'value': 'KING', 'suit': 'SPADES', 'image': 'assets/images/cards/spades_K.png'},
    
    // CŒURS (HEARTS) - 13 cartes
    {'code': 'AH', 'value': 'ACE', 'suit': 'HEARTS', 'image': 'assets/images/cards/hearts_A.png'},
    {'code': '2H', 'value': '2', 'suit': 'HEARTS', 'image': 'assets/images/cards/hearts_2.png'},
    {'code': '3H', 'value': '3', 'suit': 'HEARTS', 'image': 'assets/images/cards/hearts_3.png'},
    {'code': '4H', 'value': '4', 'suit': 'HEARTS', 'image': 'assets/images/cards/hearts_4.png'},
    {'code': '5H', 'value': '5', 'suit': 'HEARTS', 'image': 'assets/images/cards/hearts_5.png'},
    {'code': '6H', 'value': '6', 'suit': 'HEARTS', 'image': 'assets/images/cards/hearts_6.png'},
    {'code': '7H', 'value': '7', 'suit': 'HEARTS', 'image': 'assets/images/cards/hearts_7.png'},
    {'code': '8H', 'value': '8', 'suit': 'HEARTS', 'image': 'assets/images/cards/hearts_8.png'},
    {'code': '9H', 'value': '9', 'suit': 'HEARTS', 'image': 'assets/images/cards/hearts_9.png'},
    {'code': '0H', 'value': '10', 'suit': 'HEARTS', 'image': 'assets/images/cards/hearts_10.png'},
    {'code': 'JH', 'value': 'JACK', 'suit': 'HEARTS', 'image': 'assets/images/cards/hearts_J.png'},
    {'code': 'QH', 'value': 'QUEEN', 'suit': 'HEARTS', 'image': 'assets/images/cards/hearts_Q.png'},
    {'code': 'KH', 'value': 'KING', 'suit': 'HEARTS', 'image': 'assets/images/cards/hearts_K.png'},
    
    // CARREAUX (DIAMONDS) - 13 cartes
    {'code': 'AD', 'value': 'ACE', 'suit': 'DIAMONDS', 'image': 'assets/images/cards/diamonds_A.png'},
    {'code': '2D', 'value': '2', 'suit': 'DIAMONDS', 'image': 'assets/images/cards/diamonds_2.png'},
    {'code': '3D', 'value': '3', 'suit': 'DIAMONDS', 'image': 'assets/images/cards/diamonds_3.png'},
    {'code': '4D', 'value': '4', 'suit': 'DIAMONDS', 'image': 'assets/images/cards/diamonds_4.png'},
    {'code': '5D', 'value': '5', 'suit': 'DIAMONDS', 'image': 'assets/images/cards/diamonds_5.png'},
    {'code': '6D', 'value': '6', 'suit': 'DIAMONDS', 'image': 'assets/images/cards/diamonds_6.png'},
    {'code': '7D', 'value': '7', 'suit': 'DIAMONDS', 'image': 'assets/images/cards/diamonds_7.png'},
    {'code': '8D', 'value': '8', 'suit': 'DIAMONDS', 'image': 'assets/images/cards/diamonds_8.png'},
    {'code': '9D', 'value': '9', 'suit': 'DIAMONDS', 'image': 'assets/images/cards/diamonds_9.png'},
    {'code': '0D', 'value': '10', 'suit': 'DIAMONDS', 'image': 'assets/images/cards/diamonds_10.png'},
    {'code': 'JD', 'value': 'JACK', 'suit': 'DIAMONDS', 'image': 'assets/images/cards/diamonds_J.png'},
    {'code': 'QD', 'value': 'QUEEN', 'suit': 'DIAMONDS', 'image': 'assets/images/cards/diamonds_Q.png'},
    {'code': 'KD', 'value': 'KING', 'suit': 'DIAMONDS', 'image': 'assets/images/cards/diamonds_K.png'},
    
    // TRÈFLES (CLUBS) - 13 cartes
    {'code': 'AC', 'value': 'ACE', 'suit': 'CLUBS', 'image': 'assets/images/cards/clubs_A.png'},
    {'code': '2C', 'value': '2', 'suit': 'CLUBS', 'image': 'assets/images/cards/clubs_2.png'},
    {'code': '3C', 'value': '3', 'suit': 'CLUBS', 'image': 'assets/images/cards/clubs_3.png'},
    {'code': '4C', 'value': '4', 'suit': 'CLUBS', 'image': 'assets/images/cards/clubs_4.png'},
    {'code': '5C', 'value': '5', 'suit': 'CLUBS', 'image': 'assets/images/cards/clubs_5.png'},
    {'code': '6C', 'value': '6', 'suit': 'CLUBS', 'image': 'assets/images/cards/clubs_6.png'},
    {'code': '7C', 'value': '7', 'suit': 'CLUBS', 'image': 'assets/images/cards/clubs_7.png'},
    {'code': '8C', 'value': '8', 'suit': 'CLUBS', 'image': 'assets/images/cards/clubs_8.png'},
    {'code': '9C', 'value': '9', 'suit': 'CLUBS', 'image': 'assets/images/cards/clubs_9.png'},
    {'code': '0C', 'value': '10', 'suit': 'CLUBS', 'image': 'assets/images/cards/clubs_10.png'},
    {'code': 'JC', 'value': 'JACK', 'suit': 'CLUBS', 'image': 'assets/images/cards/clubs_J.png'},
    {'code': 'QC', 'value': 'QUEEN', 'suit': 'CLUBS', 'image': 'assets/images/cards/clubs_Q.png'},
    {'code': 'KC', 'value': 'KING', 'suit': 'CLUBS', 'image': 'assets/images/cards/clubs_K.png'},
  ];

  // Variables pour la gestion du jeu
  Map<String, List<Map<String, dynamic>>> _distributedCards = {};
  String _currentPlayerTurn = '';
  bool _isAnnouncementPhase = true;
  List<Map<String, dynamic>> _currentRoundAnnouncements = [];
  int _currentTrickNumber = 0;
  bool _isRoundEnding = false;
  List<Map<String, dynamic>> _currentTrick = [];
  String? _lastPlayerWithoutSpades;
  final Map<String, int> _obtainedTricks = {}; // plis gagnés par joueur pour la manche courante
  int _expectedPlayerCount = GameConstants.standardPlayerCount;
  int _cardsPerPlayer =
      GameConstants.cardsPerPlayerForCount(GameConstants.standardPlayerCount);

  // Callback déclenché à la fin d'une manche (toutes les cartes jouées)
  // Paramètres: (annonces du round, plis obtenus par joueur)
  void Function(List<Map<String, dynamic>>, Map<String, int>)? onRoundCompleted;

  // Fonction pour mélanger et distribuer les cartes
  int get expectedPlayerCount => _expectedPlayerCount;
  int get cardsPerPlayer => _cardsPerPlayer;

  Map<String, dynamic> shuffleAndDealCards(List<String> playerNames) {
    try {
      print('=== DISTRIBUTION LOCALE DES CARTES ===');
      
      // ✅ Nettoyer la liste des joueurs: retirer les noms vides et doublons tout en gardant l'ordre
      final filteredPlayerNames = <String>[];
      for (final name in playerNames) {
        final trimmed = name.trim();
        if (trimmed.isEmpty) continue;
        if (!filteredPlayerNames.contains(trimmed)) {
          filteredPlayerNames.add(trimmed);
        }
      }

      _expectedPlayerCount = filteredPlayerNames.length;
      _cardsPerPlayer =
          GameConstants.cardsPerPlayerForCount(_expectedPlayerCount);

      // ⚠️ Vérifier que nous avons le bon nombre de joueurs uniques
      if (filteredPlayerNames.length != _expectedPlayerCount) {
        print(
            '❌ ERREUR: Nombre de joueurs invalide pour la distribution: ${filteredPlayerNames.length}');
        print('   Joueurs reçus: $playerNames');
        print('   Joueurs filtrés (uniques/non vides): $filteredPlayerNames');
        return {
          'success': false,
          'message':
              'Nombre de joueurs invalide (${filteredPlayerNames.length}). Il faut exactement $_expectedPlayerCount joueurs uniques.'
        };
      }
      
      // ⚠️ IMPORTANT: Créer une copie profonde (deep copy) de toutes les cartes pour éviter les références partagées
      List<Map<String, dynamic>> shuffledCards = _allCards.map((card) => {
        'code': card['code'] as String,
        'value': card['value'] as String,
        'suit': card['suit'] as String,
        'image': card['image'] as String,
      }).toList();
      
      shuffledCards.shuffle(Random());
      
      print('Cartes mélangées: ${shuffledCards.length} cartes');
      
      // ⚠️ VALIDATION: Vérifier que toutes les cartes sont uniques avant distribution
      final cardCodes = shuffledCards.map((c) => c['code'] as String).toList();
      final uniqueCodes = cardCodes.toSet();
      if (cardCodes.length != uniqueCodes.length) {
        print('❌ ERREUR: Des cartes en double détectées dans le paquet mélangé!');
        print('   Total: ${cardCodes.length}, Uniques: ${uniqueCodes.length}');
        // Trouver les doublons
        final duplicates = <String, int>{};
        for (final code in cardCodes) {
          duplicates[code] = (duplicates[code] ?? 0) + 1;
        }
        duplicates.removeWhere((key, value) => value == 1);
        print('   Doublons: $duplicates');
        // Reconstruire un paquet propre
        shuffledCards = _allCards.map((card) => {
          'code': card['code'] as String,
          'value': card['value'] as String,
          'suit': card['suit'] as String,
          'image': card['image'] as String,
        }).toList();
        shuffledCards.shuffle(Random());
        print('✅ Paquet reconstruit et mélangé');
      }
      
      // ✅ Distribuer le nombre configuré de cartes à chaque joueur
      _distributedCards.clear();
      int cardIndex = 0;
      final Set<String> usedCardCodes = {}; // ✅ Suivre les cartes déjà distribuées
      
      for (String playerName in filteredPlayerNames) {
        List<Map<String, dynamic>> playerCards = [];
        
        for (int i = 0; i < _cardsPerPlayer; i++) {
          // ✅ Trouver la prochaine carte non utilisée
          while (cardIndex < shuffledCards.length) {
            final card = shuffledCards[cardIndex];
            final cardCode = card['code'] as String;
            
            // ✅ Vérifier que cette carte n'a pas déjà été distribuée
            if (!usedCardCodes.contains(cardCode)) {
              // ⚠️ IMPORTANT: Créer une copie profonde de chaque carte pour chaque joueur
              playerCards.add({
                'code': cardCode,
                'value': card['value'] as String,
                'suit': card['suit'] as String,
                'image': card['image'] as String,
              });
              usedCardCodes.add(cardCode); // ✅ Marquer comme utilisée
              cardIndex++;
              break; // Carte trouvée, passer à la suivante
            } else {
              // Carte déjà utilisée, passer à la suivante
              cardIndex++;
            }
          }
          
        // Si on a épuisé toutes les cartes, arrêter
        if (cardIndex >= shuffledCards.length &&
            playerCards.length < _cardsPerPlayer) {
          print(
              '⚠️ Plus assez de cartes pour $playerName (${playerCards.length}/$_cardsPerPlayer)');
            break;
          }
        }
        
        _distributedCards[playerName] = playerCards;
        print('Cartes distribuées pour $playerName: ${playerCards.length} cartes');
        
        // Afficher les premières cartes pour debug
        if (playerCards.isNotEmpty) {
          print('Première carte: ${playerCards[0]['code']} - ${playerCards[0]['image']}');
        }
      }
      
      // ✅ Vérification finale : s'assurer qu'aucune carte n'est en double
      if (usedCardCodes.length != shuffledCards.length) {
        print('⚠️ ATTENTION: ${shuffledCards.length - usedCardCodes.length} cartes non distribuées');
      }
      
      // ⚠️ VALIDATION FINALE: Vérifier qu'aucune carte n'est partagée entre les joueurs
      final allDistributedCards = <String>[];
      final allCardCodes = <String>[];
      for (final playerName in filteredPlayerNames) {
        final playerCards = _distributedCards[playerName] ?? [];
        for (final card in playerCards) {
          final cardCode = card['code'] as String;
          allDistributedCards.add('$playerName: $cardCode');
          allCardCodes.add(cardCode);
        }
      }
      
      final uniqueDistributedCodes = allCardCodes.toSet();
      if (allCardCodes.length != uniqueDistributedCodes.length) {
        print('❌ ERREUR CRITIQUE: Des cartes en double détectées après distribution!');
        print('   Total cartes distribuées: ${allCardCodes.length}');
        print('   Cartes uniques: ${uniqueDistributedCodes.length}');
        
        // Trouver les doublons
        final duplicates = <String, List<String>>{};
        for (int i = 0; i < allCardCodes.length; i++) {
          final code = allCardCodes[i];
          final playerCardInfo = allDistributedCards[i];
          if (!duplicates.containsKey(code)) {
            duplicates[code] = [];
          }
          duplicates[code]!.add(playerCardInfo);
        }
        duplicates.removeWhere((key, value) => value.length == 1);
        
        print('   ⚠️ Cartes dupliquées:');
        duplicates.forEach((code, players) {
          print('      $code: ${players.join(', ')}');
        });
        
        // Redistribuer complètement en cas d'erreur
        print('🔄 Redistribution complète pour corriger les doublons...');
        return shuffleAndDealCards(filteredPlayerNames);
      } else {
        print('✅ Validation OK: Toutes les cartes sont uniques (${allCardCodes.length} cartes distribuées)');
      }

      // ✅ Vérifier que chaque joueur possède le bon nombre de cartes
      bool invalidHand = false;
      for (final playerName in filteredPlayerNames) {
        final length = _distributedCards[playerName]?.length ?? 0;
        if (length != _cardsPerPlayer) {
          invalidHand = true;
          print(
              '❌ ERREUR: $playerName possède $length cartes au lieu de $_cardsPerPlayer');
        }
      }

      if (invalidHand) {
        print(
            '🔄 Redistribution complète car tous les joueurs n\'ont pas $_cardsPerPlayer cartes.');
        return shuffleAndDealCards(filteredPlayerNames);
      }

      // ✅ Vérifier que chaque joueur possède au moins un pique
      for (final playerName in filteredPlayerNames) {
        final playerCards = _distributedCards[playerName] ?? [];
        final hasSpade = playerCards.any((card) {
          final suit = (card['suit'] as String?)?.toUpperCase() ?? '';
          final code = (card['code'] as String?)?.toUpperCase() ?? '';
          return suit == 'SPADES' || code.endsWith('S');
        });
        if (!hasSpade) {
          print('⚠️ Redistribution: $playerName n\'a reçu aucune carte de pique.');
          _lastPlayerWithoutSpades = playerName;
          return shuffleAndDealCards(filteredPlayerNames);
        }
      }
      
      // Initialiser la phase d'annonces
      _isAnnouncementPhase = true;
      _currentRoundAnnouncements.clear();
      _currentTrickNumber = 0;
      _currentTrick.clear();
      
      // Le premier joueur commence les annonces
      _currentPlayerTurn = filteredPlayerNames.isNotEmpty ? filteredPlayerNames[0] : '';
      
      print('Phase d\'annonces démarrée pour: $_currentPlayerTurn');
      print('=====================================');
      final note = _lastPlayerWithoutSpades != null
          ? 'Redistribution forcée: ${_lastPlayerWithoutSpades!} n\'avait aucune carte de pique.'
          : null;
      _lastPlayerWithoutSpades = null;
      
      return {
        'success': true,
        'message': 'Cartes distribuées avec succès',
        'distributedCards': _distributedCards,
        'note': note,
      };
      
    } catch (e, stackTrace) {
      print('❌ Erreur lors de la distribution: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Erreur lors de la distribution des cartes: $e',
      };
    }
  }

  // Fonction pour obtenir les cartes d'un joueur
  List<Map<String, dynamic>> getPlayerCards(String playerName) {
    final cards = _distributedCards[playerName] ?? [];
    if (cards.isEmpty && _distributedCards.isNotEmpty) {
      // ✅ Vérifier si toutes les cartes ont été jouées (état normal en fin de partie)
      bool allCardsPlayed = true;
      for (var hand in _distributedCards.values) {
        if (hand.isNotEmpty) {
          allCardsPlayed = false;
          break;
        }
      }
      
      // Ne pas afficher le message si toutes les cartes ont été jouées (c'est normal)
      if (!allCardsPlayed) {
        // ✅ Debug: vérifier si le nom ne correspond pas exactement (uniquement si problème réel)
        print('⚠️ Aucune carte pour "$playerName" (mais d\'autres joueurs ont encore des cartes)');
        print('   Joueurs disponibles: ${_distributedCards.keys.toList()}');
      }
    }
    return cards;
  }
  
  // Getter pour accéder aux cartes distribuées (pour debug)
  Map<String, List<Map<String, dynamic>>> get distributedCards => Map.from(_distributedCards);

  /// Définir explicitement les cartes d'un joueur (pour synchronisation WebSocket)
  void setPlayerCards(String playerName, List<Map<String, dynamic>> cards) {
    if (playerName.isEmpty) return;
    _distributedCards[playerName] = List<Map<String, dynamic>>.from(cards);
    print('✅ Cartes définies pour $playerName: ${cards.length} cartes');
  }

  // Fonction pour transférer les cartes d'un joueur à un autre (remplacement par bot)
  void transferPlayerCards(String fromPlayerName, String toPlayerName) {
    if (_distributedCards.containsKey(fromPlayerName)) {
      _distributedCards[toPlayerName] = List.from(_distributedCards[fromPlayerName]!);
      _distributedCards.remove(fromPlayerName);
      print('✅ Cartes transférées de $fromPlayerName à $toPlayerName (${_distributedCards[toPlayerName]?.length ?? 0} cartes)');
    }
  }

  // Fonction pour transférer les plis gagnés d'un joueur à un autre (remplacement par bot)
  void transferObtainedTricks(String fromPlayerName, String toPlayerName) {
    if (_obtainedTricks.containsKey(fromPlayerName)) {
      final tricks = _obtainedTricks[fromPlayerName] ?? 0;
      _obtainedTricks[toPlayerName] = (_obtainedTricks[toPlayerName] ?? 0) + tricks;
      _obtainedTricks.remove(fromPlayerName);
      print('✅ Plis gagnés transférés de $fromPlayerName à $toPlayerName ($tricks plis)');
    }
  }

  // Fonction pour mettre à jour le nom du joueur dans le pli en cours
  void updatePlayerNameInCurrentTrick(String oldPlayerName, String newPlayerName) {
    for (var trickEntry in _currentTrick) {
      if ((trickEntry['player'] as String?) == oldPlayerName) {
        trickEntry['player'] = newPlayerName;
        print('✅ Nom du joueur mis à jour dans le pli en cours: $oldPlayerName → $newPlayerName');
      }
    }
  }

  // Fonction pour obtenir le chemin de l'image d'une carte
  String getCardImagePath(Map<String, dynamic> card) {
    return card['image'] as String? ?? 'assets/images/cards/spades_A.png';
  }

  // Fonction pour créer un widget de dos de carte
  Widget buildCardBack({double width = 30, double height = 42}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.red.shade800,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'CAURIS',
          style: TextStyle(
            color: Colors.white,
            fontSize: width * 0.15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Fonction pour faire une annonce
  void makeAnnouncement(String playerName, int announcement) {
    if (_isAnnouncementPhase) {
      // Normaliser l'annonce entre 2 et 13
      final int clampedAnnouncement = announcement.clamp(2, 13).toInt();
      // Vérifier si le joueur a déjà annoncé
      bool alreadyAnnounced = _currentRoundAnnouncements.any(
        (ann) => ann['player'] == playerName
      );
      
      if (!alreadyAnnounced) {
        _currentRoundAnnouncements.add({
          'player': playerName,
          'announcement': clampedAnnouncement,
          'timestamp': DateTime.now(),
        });
        
        print('Annonce de $playerName: $clampedAnnouncement plis');
        
        // ✅ Supprimé le passage automatique au joueur suivant
        // Car cela est géré par la logique de jeu
      }
    }
  }
  
  // Fonction pour forcer une annonce (sans vérifier le tour)
  void forceAnnouncement(String playerName, int announcement) {
    if (_isAnnouncementPhase) {
      final int clampedAnnouncement = announcement.clamp(2, 13).toInt();
      // Vérifier si le joueur a déjà annoncé
      bool alreadyAnnounced = _currentRoundAnnouncements.any(
        (ann) => ann['player'] == playerName
      );
      
      if (!alreadyAnnounced) {
        _currentRoundAnnouncements.add({
          'player': playerName,
          'announcement': clampedAnnouncement,
          'timestamp': DateTime.now(),
        });
        
        print('Annonce forcée de $playerName: $clampedAnnouncement plis');
      }
    }
  }

  // Fonction pour passer au joueur suivant pour les annonces
  // SENS ANTI-HORAIRE (contre sens des aiguilles d'une montre)
  void _nextAnnouncementPlayer() {
    List<String> players = _distributedCards.keys.toList();
    int currentIndex = players.indexOf(_currentPlayerTurn);
    
    // Sens anti-horaire: on va dans l'ordre inverse
    // Créateur (index 0) → Premier rejoint (index 1) → Deuxième rejoint (index 2) → Dernier (index 3)
    int nextIndex = (currentIndex + 1) % players.length;
    _currentPlayerTurn = players[nextIndex];
    
    print('Tour d\'annonce passé à: $_currentPlayerTurn');
  }

  // Fonction pour vérifier si toutes les annonces sont faites
  bool areAllAnnouncementsDone(List<String> playerNames) {
    // ✅ Vérifier que TOUS les joueurs ont annoncé (pas seulement le nombre d'annonces)
    if (_currentRoundAnnouncements.length < playerNames.length) {
      return false;
    }
    
    // Vérifier que chaque joueur a bien une annonce
    final announcedPlayers = _currentRoundAnnouncements
        .map((ann) => ann['player'] as String?)
        .where((name) => name != null)
        .toSet();
    
    final allPlayersSet = playerNames.toSet();
    
    // Tous les joueurs doivent avoir annoncé
    final allDone = allPlayersSet.every((playerName) => announcedPlayers.contains(playerName));
    
    if (allDone) {
      print('✅ Toutes les annonces sont faites: ${_currentRoundAnnouncements.length} annonces pour ${playerNames.length} joueurs');
      for (final ann in _currentRoundAnnouncements) {
        print('   - ${ann['player']}: ${ann['announcement']} plis');
      }
    } else {
      final missing = allPlayersSet.difference(announcedPlayers);
      print('⚠️ Annonces incomplètes: ${_currentRoundAnnouncements.length}/${playerNames.length}, manquants: $missing');
    }
    
    return allDone;
  }

  // Fonction pour obtenir les annonces du round actuel
  List<Map<String, dynamic>> getCurrentRoundAnnouncements() {
    return List.from(_currentRoundAnnouncements);
  }

  // Fonction pour mettre à jour toutes les annonces (ajouter +1 à chacune)
  void incrementAllAnnouncements() {
    for (var announcement in _currentRoundAnnouncements) {
      final currentAnnouncement = (announcement['announcement'] as int?) ?? 0;
      announcement['announcement'] = min(currentAnnouncement + 1, 13).toInt();
    }
    print('📊 Toutes les annonces ont été augmentées de +1');
  }

  /// Remplace ou ajoute les annonces locales avec les valeurs du backend (ex. +1 si total < 10).
  void syncAnnouncementsFromBackend(Map<String, dynamic> announcements) {
    for (final entry in announcements.entries) {
      final playerName = entry.key.toString();
      final value = ((entry.value as num?)?.toInt() ?? 2).clamp(2, 13);

      final index = _currentRoundAnnouncements.indexWhere(
        (ann) => ann['player'] == playerName,
      );

      if (index >= 0) {
        _currentRoundAnnouncements[index]['announcement'] = value;
      } else {
        _currentRoundAnnouncements.add({
          'player': playerName,
          'announcement': value,
          'timestamp': DateTime.now(),
        });
      }
    }

    print('📊 Annonces synchronisées depuis le backend: $_currentRoundAnnouncements');
  }

  /// True si toutes les mains sont vides (manche terminée).
  bool allCardsPlayed() {
    if (_distributedCards.isEmpty) return false;
    for (final hand in _distributedCards.values) {
      if (hand.isNotEmpty) return false;
    }
    return true;
  }

  bool hasCardsRemaining(String playerName) {
    return (_distributedCards[playerName] ?? []).isNotEmpty;
  }

  /// Passe au joueur suivant qui a encore des cartes (sens anti-horaire).
  /// [preferredStart] : gagnant du pli s'il a encore des cartes, sinon joueur suivant.
  /// Retourne false si la manche est terminée.
  bool advanceToNextPlayerWithCards({String? preferredStart}) {
    if (allCardsPlayed()) {
      _isRoundEnding = true;
      return false;
    }

    final players = _distributedCards.keys.toList();
    if (players.isEmpty) return false;

    if (preferredStart != null &&
        preferredStart.isNotEmpty &&
        hasCardsRemaining(preferredStart)) {
      _currentPlayerTurn = preferredStart;
      print('Tour (gagnant du pli): $_currentPlayerTurn');
      return true;
    }

    final startIndex = players.indexOf(_currentPlayerTurn);
    final baseIndex = startIndex >= 0 ? startIndex : 0;

    for (int i = 1; i <= players.length; i++) {
      final name = players[(baseIndex + i) % players.length];
      if (hasCardsRemaining(name)) {
        _currentPlayerTurn = name;
        print('Tour passé à: $_currentPlayerTurn');
        return true;
      }
    }

    _isRoundEnding = true;
    return false;
  }

  // Fonction pour passer à la phase de jeu
  void startGamePhase() {
    _isAnnouncementPhase = false;
    _currentTrickNumber = 1;
    _isRoundEnding = false;
    _currentTrick.clear();
    // Réinitialiser les compteurs de plis gagnés
    _obtainedTricks.clear();
    for (final name in _distributedCards.keys) {
      _obtainedTricks[name] = 0;
    }
    
    print('Phase de jeu démarrée. Premier joueur: $_currentPlayerTurn');
  }

  // Fonction pour jouer une carte
  void playCard(String playerName, Map<String, dynamic> card) {
    if (!_isAnnouncementPhase && _currentPlayerTurn == playerName) {
      final cardCode = card['code'] as String? ?? '';
      
      // ✅ Empêcher un joueur de jouer plusieurs cartes dans le même pli
      final alreadyPlayed = _currentTrick.any(
        (entry) => (entry['player'] as String?) == playerName,
      );
      if (alreadyPlayed) {
        print('⚠️ $playerName a déjà joué une carte pour ce pli. Action ignorée.');
        return;
      }
      
      // ✅ Empêcher qu'une carte spécifique soit jouée deux fois (déjà dans le trick)
      final cardAlreadyInTrick = _currentTrick.any(
        (entry) {
          final card = entry['card'] as Map<String, dynamic>?;
          return card != null && (card['code'] as String?) == cardCode;
        },
      );
      if (cardAlreadyInTrick) {
        print('⚠️ Carte $cardCode déjà jouée dans ce pli. Action ignorée.');
        return;
      }

      // ✅ Vérifier que la carte existe encore dans la main du joueur
      final playerHand = _distributedCards[playerName];
      if (playerHand == null) {
        print('⚠️ Main du joueur $playerName introuvable. Action ignorée.');
        return;
      }
      
      final codeToRemove = cardCode;
      final index = playerHand.indexWhere((c) => (c['code'] as String?) == codeToRemove);
      if (index == -1) {
        print('⚠️ Carte $cardCode introuvable dans la main de $playerName. Action ignorée.');
        return;
      }
      
      // ✅ Retirer la carte de la main du joueur AVANT de l'ajouter au trick
      playerHand.removeAt(index);
      print('✅ Carte $cardCode retirée de la main de $playerName (${playerHand.length} cartes restantes)');

      // ✅ Ajouter la carte au trick
      _currentTrick.add({
        'player': playerName,
        'card': card,
        'timestamp': DateTime.now(),
      });
      
      print('✅ Carte jouée par $playerName: $cardCode (trick contient ${_currentTrick.length} cartes)');
      
      // ✅ Si toutes les cartes du pli sont jouées (selon le nombre de joueurs), le pli est terminé
      final expectedTrickSize = _expectedPlayerCount;
      if (_currentTrick.length >= expectedTrickSize) {
        _finishTrick();
      } else {
        advanceToNextPlayerWithCards();
      }
    } else {
      if (_isAnnouncementPhase) {
        print('⚠️ Tentative de jouer une carte pendant la phase d\'annonces. Action ignorée.');
      } else {
        print('⚠️ Ce n\'est pas le tour de $playerName (tour actuel: $_currentPlayerTurn). Action ignorée.');
      }
    }
  }

  // ✅ NOUVELLE MÉTHODE: Ajouter une carte au trick sans vérifier le tour
  // Utilisée après confirmation du backend quand le tour a déjà changé
  void addCardToTrick(String playerName, Map<String, dynamic> card) {
    if (_isAnnouncementPhase) {
      print('⚠️ Tentative d\'ajouter une carte pendant la phase d\'annonces. Action ignorée.');
      return;
    }
    
    final cardCode = card['code'] as String? ?? '';
    
    // ✅ Empêcher un joueur de jouer plusieurs cartes dans le même pli
    final alreadyPlayed = _currentTrick.any(
      (entry) => (entry['player'] as String?) == playerName,
    );
    if (alreadyPlayed) {
      print('⚠️ $playerName a déjà joué une carte pour ce pli. Action ignorée.');
      return;
    }
    
    // ✅ Empêcher qu'une carte spécifique soit jouée deux fois (déjà dans le trick)
    final cardAlreadyInTrick = _currentTrick.any(
      (entry) {
        final entryCard = entry['card'] as Map<String, dynamic>?;
        return entryCard != null && (entryCard['code'] as String?) == cardCode;
      },
    );
    if (cardAlreadyInTrick) {
      print('⚠️ Carte $cardCode déjà jouée dans ce pli. Action ignorée.');
      return;
    }

    // ✅ Retirer la carte de la main du joueur si elle existe
    final playerHand = _distributedCards[playerName];
    if (playerHand != null) {
      final codeToRemove = cardCode;
      final index = playerHand.indexWhere((c) => (c['code'] as String?) == codeToRemove);
      if (index != -1) {
        playerHand.removeAt(index);
        print('✅ Carte $cardCode retirée de la main de $playerName (${playerHand.length} cartes restantes)');
      }
    }

    // ✅ Ajouter la carte au trick
    _currentTrick.add({
      'player': playerName,
      'card': card,
      'timestamp': DateTime.now(),
    });
    
    print('✅ Carte ajoutée au trick pour $playerName: $cardCode (trick contient ${_currentTrick.length} cartes)');
    
    // ⚠️ NE PAS appeler _nextPlayer() ou _finishTrick() ici
    // Le backend gère déjà le tour et la fin du pli
  }

  // Fonction pour terminer un pli
  // ✅ RÈGLE: Un round = exactement 13 tricks (4 joueurs × 13 cartes = 52 cartes)
  void _finishTrick() {
    if (_isRoundEnding) return;

    print('Pli terminé: ${_currentTrick.length} cartes');

    final completedTrick = _currentTrickNumber;
    if (completedTrick > 13) {
      print(
        '⚠️ ATTENTION: plus de 13 plis comptabilisés ($completedTrick). Vérifier la logique de fin de manche.',
      );
    }

    final winner = _determineTrickWinner();
    if (winner.isNotEmpty) {
      final currentObtained = _obtainedTricks[winner] ?? 0;
      _obtainedTricks[winner] = currentObtained + 1;
      print(
        '✅ Pli gagné par $winner -> total: ${_obtainedTricks[winner]} (trick #$completedTrick/13)',
      );
    }

    final roundOver = allCardsPlayed();
    if (roundOver) {
      _isRoundEnding = true;
      print('🎉 TOUTES LES CARTES ONT ÉTÉ JOUÉES ! MANCHE TERMINÉE !');
      final announcements = getCurrentRoundAnnouncements();
      final obtained = Map<String, int>.from(_obtainedTricks);
      onRoundCompleted?.call(announcements, obtained);
      return;
    }

    if (completedTrick < 13) {
      _currentTrickNumber = completedTrick + 1;
    }

    if (winner.isNotEmpty) {
      advanceToNextPlayerWithCards(preferredStart: winner);
    } else {
      advanceToNextPlayerWithCards();
    }
  }

  // Getter: nombre de plis remportés
  int getObtainedTricks(String playerName) {
    return _obtainedTricks[playerName] ?? 0;
  }
  
  // ✅ Méthode pour mettre à jour les compteurs de plis obtenus (pour synchronisation WebSocket)
  void setObtainedTricks(String playerName, int count) {
    _obtainedTricks[playerName] = count;
  }
  
  // ✅ Méthode pour incrémenter un compteur de plis obtenu (pour synchronisation WebSocket)
  void incrementObtainedTrick(String playerName) {
    _obtainedTricks[playerName] = (_obtainedTricks[playerName] ?? 0) + 1;
  }
  
  // ✅ Méthode pour forcer la fin d'un pli et mettre à jour les compteurs (pour synchronisation)
  // ⚠️ IMPORTANT: Cette méthode ne doit être appelée QUE si _finishTrick() n'a PAS été appelé
  void forceFinishTrick(String winnerName) {
    if (winnerName.isEmpty || _isRoundEnding) return;

    final currentObtained = _obtainedTricks[winnerName] ?? 0;
    final completedTrick = _currentTrickNumber;

    print('🔧 Force finish trick pour $winnerName (trick #$completedTrick)');

    final expectedObtained = currentObtained + 1;
    if (_obtainedTricks[winnerName] == null ||
        _obtainedTricks[winnerName]! < expectedObtained) {
      _obtainedTricks[winnerName] = expectedObtained;
      print(
        '✅ Pli forcé gagné par $winnerName -> total: ${_obtainedTricks[winnerName]} (trick #$completedTrick/13)',
      );
    }

    if (allCardsPlayed()) {
      _isRoundEnding = true;
      print('🎉 TOUTES LES CARTES ONT ÉTÉ JOUÉES ! MANCHE TERMINÉE !');
      final announcements = getCurrentRoundAnnouncements();
      final obtained = Map<String, int>.from(_obtainedTricks);
      onRoundCompleted?.call(announcements, obtained);
      return;
    }

    if (completedTrick < 13) {
      _currentTrickNumber = completedTrick + 1;
    }
    advanceToNextPlayerWithCards(preferredStart: winnerName);
  }

  // Réinitialise explicitement les compteurs d'une nouvelle manche (0/0)
  void resetRoundCounters() {
    _currentRoundAnnouncements.clear();
    _isAnnouncementPhase = true;
    _currentTrickNumber = 0;
    _isRoundEnding = false;
    _currentTrick.clear();
    _obtainedTricks.clear();
    for (final name in _distributedCards.keys) {
      _obtainedTricks[name] = 0;
    }
  }

  // IA d'annonce pour les bots
  int getBotAnnouncement(String botName) {
    // 1) Récupérer les cartes du bot
    final cards = getPlayerCards(botName);
    // 2) Total des annonces déjà faites
    final totalAlready = _currentRoundAnnouncements
        .map((ann) => (ann['announcement'] as int?) ?? 0)
        .fold<int>(0, (a, b) => a + b);
    // 3) Calcul stratégique
    final ann = BotStrategy.calculateSmartAnnouncement(cards, totalAlready);
    // 4) Retourner (clamp entre 2 et 13)
    final int clamped = ann.clamp(2, 13).toInt();
    // 5) Log
    print('🤖 Annonce de ' + botName + ' calculée: ' + clamped.toString() + ' plis');
    return clamped;
  }

  // Détermination simple du gagnant du pli courant (même logique que GameLogic)
  String _determineTrickWinner() {
    if (_currentTrick.isEmpty) return '';
    String winner = '';
    Map<String, dynamic>? winningCard;
    int highestValue = 0;
    bool hasSpade = false;
    String leadingSuit = (_currentTrick.first['card']['code'] as String).substring(1);
    for (var play in _currentTrick) {
      final card = play['card'] as Map<String, dynamic>;
      final player = play['player'] as String;
      final code = card['code'] as String;
      final suit = code.substring(1);
      final value = code.substring(0, 1);
      int cardValue;
      switch (value) {
        case 'A': cardValue = 14; break;
        case 'K': cardValue = 13; break;
        case 'Q': cardValue = 12; break;
        case 'J': cardValue = 11; break;
        case '0': cardValue = 10; break;
        case '9': cardValue = 9; break;
        case '8': cardValue = 8; break;
        case '7': cardValue = 7; break;
        case '6': cardValue = 6; break;
        case '5': cardValue = 5; break;
        case '4': cardValue = 4; break;
        case '3': cardValue = 3; break;
        case '2': cardValue = 2; break;
        default: cardValue = 0; break;
      }
      if (suit == 'S') {
        if (!hasSpade || cardValue > highestValue) {
          hasSpade = true;
          highestValue = cardValue;
          winningCard = card;
          winner = player;
        }
      } else if (!hasSpade && suit == leadingSuit) {
        if (cardValue > highestValue) {
          highestValue = cardValue;
          winningCard = card;
          winner = player;
        }
      }
    }
    return winner;
  }

  // Fonction pour obtenir le joueur qui fait actuellement son annonce
  String getCurrentAnnouncingPlayer() {
    return _currentPlayerTurn;
  }

  // Getters et Setters pour l'état du jeu
  String get currentPlayerTurn => _currentPlayerTurn;
  set currentPlayerTurn(String player) => _currentPlayerTurn = player;
  
  bool get isAnnouncementPhase => _isAnnouncementPhase;
  set isAnnouncementPhase(bool phase) => _isAnnouncementPhase = phase;
  
  int get currentTrickNumber => _currentTrickNumber;

  bool get isRoundEnding => _isRoundEnding;

  void setCurrentTrickNumber(int value) {
    if (value < 0) {
      value = 0;
    } else if (value > 13) {
      value = 13;
    }
    _currentTrickNumber = value;
  }
  List<Map<String, dynamic>> get currentTrick => List.from(_currentTrick);
  
  // Méthode publique pour vider le trick (utilisée après l'animation de collection)
  void clearCurrentTrick() {
    if (_currentTrick.isNotEmpty) {
      print('🧹 Nettoyage du trick: ${_currentTrick.length} cartes supprimées');
      for (final entry in _currentTrick) {
        final player = entry['player'] as String? ?? 'Inconnu';
        final card = entry['card'] as Map<String, dynamic>?;
        final code = card?['code'] as String? ?? '?';
        print('   - $player: $code');
      }
    }
    _currentTrick.clear();
    print('✅ Trick vidé (${_currentTrick.length} cartes)');
  }
  
  // Obtenir une carte complète à partir de son code (ex: "AS", "0H")
  Map<String, dynamic>? getCardByCode(String code) {
    final normalized = code.toUpperCase();
    final found = _allCards.firstWhere(
      (card) => (card['code'] as String).toUpperCase() == normalized,
      orElse: () => {},
    );
    if (found.isEmpty) return null;
    
    return {
      'code': found['code'],
      'value': found['value'],
      'suit': found['suit'],
      'image': found['image'],
    };
  }
  
  /// S'assurer qu'une carte spécifique est présente dans la main d'un joueur
  void ensureCardInPlayerHand(String playerName, Map<String, dynamic> card) {
    final normalizedCode = (card['code'] as String?)?.toUpperCase();
    if (normalizedCode == null || normalizedCode.isEmpty) return;
    
    _distributedCards.putIfAbsent(playerName, () => []);
    final hand = _distributedCards[playerName]!;
    
    final alreadyExists = hand.any(
      (c) => (c['code'] as String?)?.toUpperCase() == normalizedCode,
    );
    
    if (!alreadyExists) {
      hand.add({
        'code': card['code'],
        'value': card['value'],
        'suit': card['suit'],
        'image': card['image'],
      });
    }
  }

  // Fonction pour passer au tour suivant
  // SENS ANTI-HORAIRE (contre sens des aiguilles d'une montre)
  void nextTurn(List<String> playerNames) {
    int currentIndex = playerNames.indexOf(_currentPlayerTurn);
    if (currentIndex == -1) currentIndex = 0;
    // Sens anti-horaire: on décrémente (ordre inverse)
    int nextIndex = (currentIndex - 1) % playerNames.length;
    if (nextIndex < 0) nextIndex += playerNames.length;
    _currentPlayerTurn = playerNames[nextIndex];
    
    print('Tour passé à: $_currentPlayerTurn');
  }

  // Fonction pour vider les annonces du round actuel
  void clearCurrentRoundAnnouncements() {
    _currentRoundAnnouncements.clear();
  }

  // Fonction pour vérifier si une carte est une figure
  bool isFigure(Map<String, dynamic> card) {
    final value = card['value'] as String?;
    return value == 'JACK' || value == 'QUEEN' || value == 'KING' || value == 'ACE';
  }

  // Fonction pour vérifier si une carte est un pique
  bool isSpade(Map<String, dynamic> card) {
    return card['suit'] == 'SPADES';
  }

  // Fonction pour obtenir la valeur numérique d'une carte
  int getCardNumericValue(Map<String, dynamic> card) {
    final value = card['value'] as String?;
    switch (value) {
      case 'ACE': return 14;
      case 'KING': return 13;
      case 'QUEEN': return 12;
      case 'JACK': return 11;
      case '10': return 10;
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
