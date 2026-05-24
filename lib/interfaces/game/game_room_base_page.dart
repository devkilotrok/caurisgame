import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../services/api/game_api_service.dart';
import '../../services/api/payment_api_service.dart';
import '../../models/game/game_session.dart';
import '../../models/game/local_card_manager.dart';
import '../../models/game/game_logic.dart';
import '../room/create_room_page.dart';
import '../../config/game_constants.dart';

/// Classe mère abstraite - Logique commune aux deux modes
abstract class GameRoomBasePage extends StatefulWidget {
  final String roomName;
  final String roomCode;
  final int minimumBet;
  final String currentPlayerName;

  const GameRoomBasePage({
    super.key,
    required this.roomName,
    required this.roomCode,
    required this.minimumBet,
    this.currentPlayerName = 'Vous',
  });
}

/// État de base abstraite - Gestion commune pour bot et humain
abstract class GameRoomBaseState<T extends GameRoomBasePage>
    extends State<T>
    with TickerProviderStateMixin {
  
  // ========== PROPRIÉTÉS COMMUNES ==========
  // Membres accessibles aux sous-classes (sans _ pour permettre l'accès depuis d'autres fichiers)
  late GameSession gameSession;
  late LocalCardManager cardManager;
  late GameLogic gameLogic;
  // Événements de cartes (pour ignorer les doublons WebSocket)
  static const Duration _cardEventTtl = Duration(minutes: 2);
  final Map<String, DateTime> _pendingLocalCardEvents = {};
  final Map<String, DateTime> _processedCardEvents = {};

  // État spécifique délégué aux sous-classes
  @protected
  Timer? get announcementTimer;
  @protected
  set announcementTimer(Timer? value);

  @protected
  Timer? get roomPollTimer;
  @protected
  set roomPollTimer(Timer? value);

  @protected
  Timer? get reconnectionCheckTimer;
  @protected
  set reconnectionCheckTimer(Timer? value);

  @protected
  Timer? get stateSyncTimer;
  @protected
  set stateSyncTimer(Timer? value);

  @protected
  Timer? get chatPollingTimer;
  @protected
  set chatPollingTimer(Timer? value);

  @protected
  Timer? get chatToastTimer;
  @protected
  set chatToastTimer(Timer? value);

  @protected
  Timer? get continueCountdownTimer;
  @protected
  set continueCountdownTimer(Timer? value);

  @protected
  Timer? get roomCodeCheckTimer;
  @protected
  set roomCodeCheckTimer(Timer? value);

  @protected
  int get announcementCountdown;
  @protected
  set announcementCountdown(int value);

  @protected
  bool get hasAnnounced;
  @protected
  set hasAnnounced(bool value);

  @protected
  String? get currentAnnouncementPlayer;
  @protected
  set currentAnnouncementPlayer(String? value);

  @protected
  int get currentAnnouncement;
  @protected
  set currentAnnouncement(int value);

  @protected
  bool get waitingForHumans;
  @protected
  set waitingForHumans(bool value);

  @protected
  bool get isProcessingAnnouncementTurn;
  @protected
  set isProcessingAnnouncementTurn(bool value);

  @protected
  bool get isProcessingAnnouncementCompletion;
  @protected
  set isProcessingAnnouncementCompletion(bool value);

  @protected
  String? get currentPlayerPlaying;
  @protected
  set currentPlayerPlaying(String? value);

  @protected
  bool get isWebSocketConnected;
  @protected
  set isWebSocketConnected(bool value);

  @protected
  int get consecutiveStatePollingErrors;
  @protected
  set consecutiveStatePollingErrors(int value);

  // ✅ Timer pour le timeout de 15 secondes par joueur
  Timer? _playerTurnTimeoutTimer;

  @protected
  bool get hasGameStarted;
  @protected
  set hasGameStarted(bool value);

  @protected
  DateTime? get lastSuccessfulStatePoll;
  @protected
  set lastSuccessfulStatePoll(DateTime? value);

  int get requiredPlayers =>
      GameConstants.requiredPlayerCount(playWithBots: gameSession.playWithBots);

  @protected
  StreamSubscription? get wsConnectSubscription;
  @protected
  set wsConnectSubscription(StreamSubscription? value);

  @protected
  StreamSubscription? get wsDisconnectSubscription;
  @protected
  set wsDisconnectSubscription(StreamSubscription? value);

  @protected
  StreamSubscription? get wsErrorSubscription;
  @protected
  set wsErrorSubscription(StreamSubscription? value);

  @protected
  StreamSubscription? get playerReplacedSubscription;
  @protected
  set playerReplacedSubscription(StreamSubscription? value);

  @protected
  StreamSubscription? get playerRestoredSubscription;
  @protected
  set playerRestoredSubscription(StreamSubscription? value);

  @protected
  StreamSubscription? get playerDisconnectedSubscription;
  @protected
  set playerDisconnectedSubscription(StreamSubscription? value);

  @protected
  StreamSubscription? get playerReconnectedSubscription;
  @protected
  set playerReconnectedSubscription(StreamSubscription? value);

  @protected
  StreamSubscription? get announcementMadeSubscription;
  @protected
  set announcementMadeSubscription(StreamSubscription? value);

  @protected
  StreamSubscription? get roomChatMessageSubscription;
  @protected
  set roomChatMessageSubscription(StreamSubscription? value);

  @protected
  StreamSubscription? get cardPlayedSubscription;
  @protected
  set cardPlayedSubscription(StreamSubscription? value);

  @protected
  Map<String, Map<String, dynamic>> get temporaryReplacements;

  @protected
  Set<String> get permanentlyExcludedPlayers;

  @protected
  AnimationController get cardAnimationController;
  @protected
  String buildCardEventKey(String playerName, String cardCode, int trickNumber) {
    final normalizedPlayer = playerName.trim();
    final normalizedCode = cardCode.trim().toUpperCase();
    return '$normalizedPlayer|$normalizedCode|$trickNumber';
  }

  @protected
  void registerLocalCardEvent(String eventKey) {
    _cleanupCardEventTracking();
    final now = DateTime.now();
    _pendingLocalCardEvents[eventKey] = now;
    _processedCardEvents[eventKey] = now;
  }

  @protected
  bool consumeLocalCardEvent(String eventKey) {
    _cleanupCardEventTracking();
    return _pendingLocalCardEvents.remove(eventKey) != null;
  }

  void _cleanupPendingLocalCardEvents() {
    if (_pendingLocalCardEvents.isEmpty) return;
    final cutoff = DateTime.now().subtract(_cardEventTtl);
    _pendingLocalCardEvents.removeWhere(
      (_, timestamp) => timestamp.isBefore(cutoff),
    );
  }

  void _cleanupProcessedCardEvents() {
    if (_processedCardEvents.isEmpty) return;
    final cutoff = DateTime.now().subtract(_cardEventTtl);
    _processedCardEvents.removeWhere(
      (_, timestamp) => timestamp.isBefore(cutoff),
    );
  }

  void _cleanupCardEventTracking() {
    _cleanupPendingLocalCardEvents();
    _cleanupProcessedCardEvents();
  }

  @protected
  bool markCardEventProcessedIfNew(String eventKey) {
    _cleanupCardEventTracking();
    if (_processedCardEvents.containsKey(eventKey)) {
      return false;
    }
    _processedCardEvents[eventKey] = DateTime.now();
    return true;
  }

  @protected
  void resetCardEventTracking() {
    _pendingLocalCardEvents.clear();
    _processedCardEvents.clear();
  }

  @protected
  set cardAnimationController(AnimationController controller);

  @protected
  Animation<double>? get cardAnimation;
  @protected
  set cardAnimation(Animation<double>? value);

  @protected
  Map<String, dynamic>? get animatedCard;
  @protected
  set animatedCard(Map<String, dynamic>? value);

  @protected
  String? get animatingPlayerName;
  @protected
  set animatingPlayerName(String? value);

  @protected
  bool get isAnimatingCard;
  @protected
  set isAnimatingCard(bool value);

  @protected
  bool get chatFeatureInitialized;
  @protected
  set chatFeatureInitialized(bool value);

  @protected
  bool get isChatPanelVisible;
  @protected
  set isChatPanelVisible(bool value);

  @protected
  TextEditingController get chatInputController;

  @protected
  ScrollController get chatScrollController;

  @protected
  List<Map<String, dynamic>> get chatMessages;
  @protected
  set chatMessages(List<Map<String, dynamic>> value);

  @protected
  bool get isSendingChatMessage;
  @protected
  set isSendingChatMessage(bool value);

  @protected
  Map<String, dynamic>? get chatToastMessage;
  @protected
  set chatToastMessage(Map<String, dynamic>? value);

  @protected
  AnimationController get chatToastAnimationController;
  @protected
  set chatToastAnimationController(AnimationController controller);

  @protected
  Animation<double>? get chatToastAnimation;
  @protected
  set chatToastAnimation(Animation<double>? value);

  @protected
  String? get lastTrickWinner;
  @protected
  set lastTrickWinner(String? value);

  @protected
  bool get isCollectingTrick;
  @protected
  set isCollectingTrick(bool value);

  @protected
  bool? get continueGameChoice;
  @protected
  set continueGameChoice(bool? value);

  @protected
  int get continueCountdown;
  @protected
  set continueCountdown(int value);

  static const Duration pollIntervalWebSocket = Duration(seconds: 6);
  static const Duration pollIntervalFallback = Duration(seconds: 3);

  // ========== LIFECYCLE ==========
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    gameSession = GameSession.instance;
    cardManager = LocalCardManager.instance;
    gameLogic = GameLogic.instance;

    onGameRoomInitialize();
    _initializeGameSession();
  }

  /// Hooks pour sous-classes
  @protected
  void onGameRoomInitialize() {}

  @protected
  void onGameRoomDispose() {}

  @override
  void dispose() {
    resetCardEventTracking();
    
    // ✅ Annuler le timer de timeout de tour
    _playerTurnTimeoutTimer?.cancel();
    _playerTurnTimeoutTimer = null;
    
    onGameRoomDispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    super.dispose();
  }

  // ========== INITIALISATION ==========
  void _initializeGameSession() {
    if (gameSession.roomId == null || (gameSession.roomId?.isEmpty ?? true)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return;
    }

    checkPlayerExclusion();
    initializeChatFeature();

    final players = gameSession.players;
    if (players.isEmpty || players.length < requiredPlayers) {
      loadPlayersFromBackend().then((_) {
        startCardDistribution();
      });
    } else {
      startCardDistribution();
    }
  }

  void initializeChatFeature() {
    if (chatFeatureInitialized) return;
    if (gameSession.playWithBots) return;
    if ((gameSession.roomId ?? '').isEmpty) return;
    chatFeatureInitialized = true;
    startChatPolling();
  }

  // ========== JOUEURS ==========
  Future<void> loadPlayersFromBackend() async {
    try {
      final roomId = gameSession.roomId ?? '';
      if (roomId.isEmpty) return;

      if (gameSession.playWithBots) {
        try {
          await GameApiService.instance.fillBots(roomId: roomId)
              .timeout(const Duration(seconds: 5));
        } catch (_) {}
      }

      Map<String, dynamic> res;
      try {
        res = await GameApiService.instance.getRoom(roomId: roomId)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        return;
      }

      final data = (res['data'] as Map?) ?? res;
      final players =
          (data['players'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (players.isEmpty) return;

      final currentName = widget.currentPlayerName;
      
      // ✅ Normaliser tous les joueurs avec leurs noms
      final normalizedPlayers = players.map((p) {
        final pseudo = (p['pseudo'] ?? '').toString();
        final first = (p['first_name'] ?? '').toString();
        final last = (p['last_name'] ?? '').toString();
        final name = (pseudo.isNotEmpty
                ? pseudo
                : ([first, last]
                      .where((s) => s.isNotEmpty)
                      .join(' ')
                      .trim()))
            .trim();
        
        // ✅ Préserver is_bot correctement (accepter 1, true, '1')
        final isBotValue = p['is_bot'];
        final isBot = isBotValue == true || isBotValue == 1 || (isBotValue is String && isBotValue == '1');
        
        // ✅ CRITIQUE: Préserver player_id et id pour getPlayerId()
        final playerId = p['player_id'] ?? p['id'];
        
        return {
          ...p,
          'name': name.isNotEmpty ? name : 'Joueur', // ✅ Ajouter 'name' pour compatibilité
          'normalizedName': name.isNotEmpty ? name : 'Joueur',
          'is_bot': isBot, // ✅ Forcer la valeur booléenne
          if (playerId != null) 'player_id': playerId, // ✅ Forcer la présence de player_id
          if (playerId != null) 'id': playerId, // ✅ Aussi dans 'id' pour compatibilité
        };
      }).toList();
      
      // ✅ Trier tous les joueurs par position backend pour avoir l'ordre de rotation
      normalizedPlayers.sort((a, b) =>
          ((a['position'] ?? 0) as int)
              .compareTo((b['position'] ?? 0) as int));
      
      // ✅ Trouver l'index du joueur actuel dans la liste triée
      final currentPlayerIndex = normalizedPlayers.indexWhere(
        (p) => (p['normalizedName'] as String?) == currentName && currentName.isNotEmpty,
      );
      
      if (currentPlayerIndex == -1) {
        print('⚠️ Joueur actuel non trouvé dans la liste des joueurs');
        return;
      }
      
      // ✅ Créer une rotation cyclique : le joueur actuel en premier (bottom), puis les suivants
      final rotatedPlayers = <Map<String, dynamic>>[];
      for (int i = 0; i < normalizedPlayers.length; i++) {
        final index = (currentPlayerIndex + i) % normalizedPlayers.length;
        rotatedPlayers.add(normalizedPlayers[index]);
      }
      
      // ✅ Positions d'affichage dans l'ordre : bottom, right, top, left
      final displayPositions = ['bottom', 'right', 'top', 'left'];
      final normalized = <Map<String, dynamic>>[];
      
      for (int i = 0; i < rotatedPlayers.length && i < 4; i++) {
        final p = rotatedPlayers[i];
        final name = p['normalizedName'] as String;
        final isCurrent = name == currentName && currentName.isNotEmpty;
        // ✅ Utiliser la valeur booléenne préservée dans normalizedPlayers
        final isBot = (p['is_bot'] as bool?) ?? false;
        final backendAvatar = (p['avatar'] ?? '').toString();
        final isCreator = ((p['is_creator'] ?? p['isCreator']) == true);
        
        final resolvedAvatar = isBot
            ? '🤖'
            : (backendAvatar.isNotEmpty ? backendAvatar : '👤');
        
        normalized.add({
          'name': name,
          'displayPosition': displayPositions[i],
          'avatar': resolvedAvatar,
          'isCurrentPlayer': isCurrent,
          'isCreator': isCreator,
          'score': '0/0',
          'cards': 13,
          'is_bot': isBot,
          'backendPosition': (p['position'] ?? 0) as int,
        });
      }

      if (mounted) {
        setState(() {
          gameSession.players = normalized;
          gameSession.globalScores = List.filled(normalized.length, 0.0);
        });
      }
    } catch (e) {
      print('❌ Erreur chargement joueurs: $e');
    }
  }

  Future<void> checkPlayerExclusion() async {
    final currentPlayerName = widget.currentPlayerName;
    final roomId = gameSession.roomId ?? '';

    if (roomId.isNotEmpty) {
      try {
        final result = await GameApiService.instance.checkPlayerExclusion(
          roomId: roomId,
          playerName: currentPlayerName,
        );
        if ((result['is_excluded'] as bool?) ?? false) {
          permanentlyExcludedPlayers.add(currentPlayerName);
        }
      } catch (_) {}
    }

    if (permanentlyExcludedPlayers.contains(currentPlayerName)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showPlayerExcludedDialog();
      });
    }
  }

  void showPlayerExcludedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2E2B23),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            '⚠️ Exclusion du salon',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Vous avez quitté le salon ou perdu la connexion. Vous ne pourrez plus être intégré à cette partie.',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const CreateRoomPage()),
                  (route) => false,
                );
              },
              child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ========== À IMPLÉMENTER PAR LES SOUS-CLASSES ==========

  String getStartingPlayerForRoundPlay(int roundNumber) {
    final Map<String, String> posToName = {};
    for (final p in gameSession.players) {
      final name = (p['name'] as String?) ?? 'Joueur';
      final pos = (p['displayPosition'] as String?) ?? 'bottom';
      posToName[pos] = name;
    }
    String creatorPos = 'bottom';
    for (final p in gameSession.players) {
      if ((p['isCreator'] as bool?) == true) {
        creatorPos = (p['displayPosition'] as String?) ?? creatorPos;
        break;
      }
    }
    final order = ['bottom', 'right', 'top', 'left'];
    final startIndex = order.indexOf(creatorPos);
    if (startIndex == -1) {
      return posToName['bottom'] ??
          (gameSession.players.first['name'] as String);
    }
    final pos = order[(startIndex + (roundNumber - 1)) % 4];
    return posToName[pos] ?? (gameSession.players.first['name'] as String);
  }

  // ========== MÉTHODES HELPER COMMUNES ==========
  
  String getDisplayPositionForPlayerName(String playerName) {
    final players = getPlayersFromCurrentPerspective();
    final found = players.firstWhere(
      (p) => p['name'] == playerName,
      orElse: () => <String, Object>{},
    );
    return (found['displayPosition'] as String?) ?? 'bottom';
  }

  List<Map<String, dynamic>> getPlayersFromCurrentPerspective() {
    final allPlayers = gameSession.players;
    final currentPlayerName = widget.currentPlayerName;

    if (allPlayers.isEmpty) {
      return [];
    }

    final currentIndex = allPlayers.indexWhere(
      (player) => (player['name'] as String?) == currentPlayerName,
    );

    if (currentIndex == -1 && allPlayers.isNotEmpty) {
      final orderedPlayers = <Map<String, dynamic>>[];
      orderedPlayers.add({
        ...Map<String, dynamic>.from(allPlayers[0] as Map),
        'displayPosition': 'bottom',
        'isCurrentPlayer': true,
        'displayName': allPlayers[0]['name'],
      });

      for (int i = 1; i < allPlayers.length; i++) {
        String displayPosition;
        switch (i) {
          case 1:
            displayPosition = 'right';
            break;
          case 2:
            displayPosition = 'top';
            break;
          case 3:
            displayPosition = 'left';
            break;
          default:
            displayPosition = 'bottom';
        }
        orderedPlayers.add({
          ...Map<String, dynamic>.from(allPlayers[i] as Map),
          'displayPosition': displayPosition,
          'isCurrentPlayer': false,
          'displayName': allPlayers[i]['name'],
        });
      }
      return orderedPlayers;
    }

    if (currentIndex == -1) return allPlayers;

    final orderedPlayers = <Map<String, dynamic>>[];
    orderedPlayers.add({
      ...Map<String, dynamic>.from(allPlayers[currentIndex] as Map),
      'displayPosition': 'bottom',
      'isCurrentPlayer': true,
      'displayName': 'Vous',
    });

    for (int i = 1; i < allPlayers.length; i++) {
      final nextIndex = (currentIndex + i) % allPlayers.length;
      final player = allPlayers[nextIndex];

      String displayPosition;
      switch (i) {
        case 1:
          displayPosition = 'right';
          break;
        case 2:
          displayPosition = 'top';
          break;
        case 3:
          displayPosition = 'left';
          break;
        default:
          displayPosition = 'bottom';
      }

      orderedPlayers.add({
        ...Map<String, dynamic>.from(player as Map),
        'displayPosition': displayPosition,
        'isCurrentPlayer': false,
        'displayName': player['name'],
      });
    }

    return orderedPlayers;
  }

  List<Map<String, dynamic>> sortCardsForDisplay(
    List<Map<String, dynamic>> cards,
  ) {
    final sorted = List<Map<String, dynamic>>.from(cards);
    sorted.sort((a, b) {
      final aCode = (a['code'] as String?) ?? '';
      final bCode = (b['code'] as String?) ?? '';

      final suitOrder = {'S': 0, 'H': 1, 'C': 2, 'D': 3};

      int suitRank(String code) {
        if (code.isEmpty) return 999;
        final s = code.substring(code.length - 1);
        return suitOrder[s] ?? 999;
      }

      int valueRank(String code) {
        if (code.isEmpty) return -1;
        final v = code.substring(0, 1);
        switch (v) {
          case 'A':
            return 14;
          case 'K':
            return 13;
          case 'Q':
            return 12;
          case 'J':
            return 11;
          case '0':
            return 10;
          case '9':
            return 9;
          case '8':
            return 8;
          case '7':
            return 7;
          case '6':
            return 6;
          case '5':
            return 5;
          case '4':
            return 4;
          case '3':
            return 3;
          case '2':
            return 2;
          default:
            return -1;
        }
      }

      final suitCmp = suitRank(aCode).compareTo(suitRank(bCode));
      if (suitCmp != 0) return suitCmp;

      return valueRank(bCode).compareTo(valueRank(aCode));
    });
    return sorted;
  }

  // ✅ NOUVEAU: Trier les cartes par valeur décroissante (plus grande d'abord)
  List<Map<String, dynamic>> _sortCardsByValue(
    List<Map<String, dynamic>> cards,
  ) {
    final sorted = List<Map<String, dynamic>>.from(cards);
    sorted.sort((a, b) {
      final aCode = (a['code'] as String?) ?? '';
      final bCode = (b['code'] as String?) ?? '';

      int valueRank(String code) {
        if (code.isEmpty) return -1;
        final v = code.substring(0, 1);
        switch (v) {
          case 'A':
            return 14;
          case 'K':
            return 13;
          case 'Q':
            return 12;
          case 'J':
            return 11;
          case '0':
            return 10;
          case '9':
            return 9;
          case '8':
            return 8;
          case '7':
            return 7;
          case '6':
            return 6;
          case '5':
            return 5;
          case '4':
            return 4;
          case '3':
            return 3;
          case '2':
            return 2;
          default:
            return -1;
        }
      }

      // Trier par valeur décroissante (plus grande d'abord)
      return valueRank(bCode).compareTo(valueRank(aCode));
    });
    return sorted;
  }

  String getPlayerAnnouncementDisplay(String playerName) {
    final announcements = cardManager.getCurrentRoundAnnouncements();
    
    final playerAnnouncement = announcements.firstWhere(
      (ann) => ann['player'] == playerName,
      orElse: () => <String, Object>{'announcement': 0},
    );
    final announced = playerAnnouncement['announcement'] as int? ?? 0;
    
    final obtained = cardManager.isAnnouncementPhase
        ? 0
        : cardManager.getObtainedTricks(playerName);
    
    // ✅ AJOUTER CE LOG pour déboguer les compteurs affichés
    if (!cardManager.isAnnouncementPhase && obtained > 0) {
      print('🔍 getPlayerAnnouncementDisplay($playerName): $obtained/$announced');
    }
    
    return '$obtained/$announced';
  }

  int getPlayerCardCount(String playerName) {
    final cardCount = cardManager.getPlayerCards(playerName).length;
    return cardCount.clamp(0, 13);
  }

  int getPlayerGlobalScore(String playerName) {
    if (gameSession.globalScores.isEmpty && gameSession.players.isNotEmpty) {
      gameSession.globalScores = List.filled(gameSession.players.length, 0.0);
    }

    final playerIndex = gameSession.players.indexWhere(
      (p) => (p['name'] as String?) == playerName,
    );

    if (playerIndex == -1 || playerIndex >= gameSession.globalScores.length) {
      return 0;
    }

    return gameSession.globalScores[playerIndex].toInt();
  }

  EdgeInsets getPlayerMargin(String position) {
    switch (position) {
      case 'top':
        return EdgeInsets.zero;
      case 'left':
        return const EdgeInsets.only(left: 0);
      case 'right':
        return const EdgeInsets.only(right: 0);
      case 'bottom':
        return const EdgeInsets.only(bottom: 0);
      default:
        return EdgeInsets.zero;
    }
  }

  String getSuitSymbol(String suit) {
    switch (suit.toLowerCase()) {
      case 'hearts':
      case 'h':
        return '♥';
      case 'diamonds':
      case 'd':
        return '♦';
      case 'clubs':
      case 'c':
        return '♣';
      case 'spades':
      case 's':
        return '♠';
      default:
        return '';
    }
  }

  Color getSuitColor(String suit) {
    switch (suit.toLowerCase()) {
      case 'hearts':
      case 'diamonds':
      case 'h':
      case 'd':
        return Colors.red;
      case 'clubs':
      case 'spades':
      case 'c':
      case 's':
        return Colors.black;
      default:
        return Colors.black;
    }
  }

  // ========== MÉTHODES DE JEU CRITIQUES ==========
  
  Future<void> playCard(Map<String, dynamic> card) async {
    // Vérifier si c'est le tour du joueur actuel
    if (cardManager.currentPlayerTurn != widget.currentPlayerName) {
      return;
    }

    // Vérifier si c'est la phase de jeu (pas d'annonces)
    if (cardManager.isAnnouncementPhase) {
      return;
    }
    
    // ✅ Vérifier si ce joueur est déjà en train de jouer (éviter les doublons)
    if (currentPlayerPlaying == widget.currentPlayerName) {
      print('⚠️ ${widget.currentPlayerName} est déjà en train de jouer - évitement du doublon');
      return;
    }

    // Obtenir les cartes du joueur actuel
    final playerCards = cardManager.getPlayerCards(widget.currentPlayerName);

    // ✅ NOUVEAU: Valider les cartes jouables depuis le backend
    try {
      // Obtenir gameId, roundId, trickId et playerId
      final gameId = await getGameId();
      final roundId = await getRoundIdForCurrentRound();
      final trickId = await getTrickIdForCurrentTrick();
      final playerId = await getPlayerId(widget.currentPlayerName);

      if (gameId != null && roundId != null && trickId != null && playerId != null) {
        // Appeler le backend pour obtenir les cartes jouables
        final playableCardCodes = await GameApiService.instance.getPlayableCards(
          gameId: gameId,
          roundId: roundId,
          trickId: trickId,
          playerId: playerId,
        );

        // Vérifier si la carte est jouable
        final cardCode = card['code'] as String;
        if (!playableCardCodes.contains(cardCode)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cette carte n\'est pas jouable selon les règles du jeu.'),
              duration: const Duration(milliseconds: 1500),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          );
          return;
        }
      } else {
        // Fallback: utiliser la logique locale si les IDs ne sont pas disponibles
        print('⚠️ IDs non disponibles, utilisation de la logique locale pour les cartes jouables');
        gameLogic.syncCurrentTrick(cardManager.currentTrick);
        final playable = gameLogic.getPlayableCards(
          playerCards,
          widget.currentPlayerName,
          gameLogic.currentTrick.isEmpty,
        );
        if (!playable.contains(card)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Cette carte n\'est pas jouable.'),
              duration: const Duration(milliseconds: 800),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          );
          return;
        }
      }
    } catch (e) {
      // Fallback: utiliser la logique locale en cas d'erreur
      print('⚠️ Erreur lors de la validation backend des cartes jouables: $e');
      print('   Utilisation de la logique locale comme fallback');
      gameLogic.syncCurrentTrick(cardManager.currentTrick);
      final playable = gameLogic.getPlayableCards(
        playerCards,
        widget.currentPlayerName,
        gameLogic.currentTrick.isEmpty,
      );
      if (!playable.contains(card)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cette carte n\'est pas jouable.'),
            duration: const Duration(milliseconds: 800),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        );
        return;
      }
    }

    // ✅ Annuler le timer de timeout si le joueur joue manuellement
    _playerTurnTimeoutTimer?.cancel();
    _playerTurnTimeoutTimer = null;

    // ✅ Marquer que ce joueur est en train de jouer (verrouillage de la main)
    // ⚠️ IMPORTANT: Le verrouillage se fait APRÈS la validation pour éviter de verrouiller si la carte n'est pas jouable
    currentPlayerPlaying = widget.currentPlayerName;
    if (mounted) {
      setState(() {
        // Mettre à jour l'UI pour désactiver toutes les cartes
      });
    }
    print('🎴 ${widget.currentPlayerName} commence à jouer la carte ${card['code']}');
    
    // ✅ Appeler directement l'API Laravel (pas d'animation locale avant)
    // Le backend gère tout : validation, diffusion WebSocket, animation via card_played
    final result = gameLogic.playCard(
      card,
      widget.currentPlayerName,
      playerCards,
    );

    if (result['success'] == true) {
      // ✅ Appeler l'API Laravel qui gère tout (détection 4ème carte, calcul gagnant, délai)
      await _playCardViaLaravelAPI(
        card,
        result,
        playerName: widget.currentPlayerName,
      );
    } else {
      // ✅ Libérer le flag si le résultat n'est pas success
      currentPlayerPlaying = null;
    }
  }

  // ✅ NOUVELLE MÉTHODE: Jouer une carte via l'API Laravel
  // Le backend gère la détection de la 4ème carte, le calcul du gagnant et le délai de 2 secondes
  Future<void> _playCardViaLaravelAPI(
    Map<String, dynamic> card,
    Map<String, dynamic> localResult, {
    String? playerName,
  }) async {
    final roomId = gameSession.roomId;
    if (roomId == null || roomId.isEmpty) {
      print('❌ RoomId manquant, impossible de jouer la carte via API');
      currentPlayerPlaying = null;
      return;
    }

    // ✅ Déclarer les variables avant le try pour qu'elles soient accessibles dans le catch
    String cardCode = '';
    String effectivePlayerName = playerName ?? widget.currentPlayerName;
    bool isLocalPlayer = effectivePlayerName == widget.currentPlayerName;

    try {
      // 1. Obtenir le round_id et trick_id depuis Laravel
      final roundNumber = gameSession.currentRound;
      // ✅ RÈGLE: Un round = exactement 13 tricks (4 joueurs × 13 cartes = 52 cartes)
      // ✅ S'assurer que trickNumber est au moins 1 (le premier trick est numéroté 1, pas 0)
      // ✅ Et qu'il ne dépasse jamais 13
      final trickNumber = (cardManager.currentTrickNumber > 0 
          ? cardManager.currentTrickNumber 
          : 1).clamp(1, 13);
      
      print('📤 Récupération round_id et trick_id: round=$roundNumber, trick=$trickNumber');
      
      // ✅ AMÉLIORATION: Gérer l'erreur 409 "Trick not ready yet" avec retry amélioré
      // ⚠️ IMPORTANT: Après trick_completed, le nouveau trick est créé par ProcessTrickEndJob
      //    Il peut y avoir un délai de 1-2 secondes, donc on augmente les tentatives et le délai
      Map<String, dynamic>? trickData;
      int retries = 0;
      const maxRetries = 5; // ✅ Augmenté de 3 à 5 tentatives
      const initialRetryDelay = Duration(milliseconds: 500);
      const maxRetryDelay = Duration(milliseconds: 1500); // ✅ Délai maximum de 1.5s
      
      while (retries < maxRetries) {
        try {
          trickData = await GameApiService.instance.getCurrentTrick(
            roomId: roomId,
            roundNumber: roundNumber,
            trickNumber: trickNumber,
          );
          
          if (trickData['success'] == true) {
            if (retries > 0) {
              print('✅ Trick récupéré après $retries tentative(s)');
            }
            break; // Succès, sortir de la boucle
          }
          
          // ✅ Si c'est une erreur 409 "Trick not ready yet", réessayer avec délai progressif
          final message = trickData['message'] as String? ?? '';
          if (message.contains('Trick not ready') || message.contains('not ready yet')) {
            retries++;
            if (retries < maxRetries) {
              // ✅ Délai progressif : 500ms, 750ms, 1000ms, 1250ms, 1500ms
              final delayMs = (initialRetryDelay.inMilliseconds + (retries * 250)).clamp(
                initialRetryDelay.inMilliseconds,
                maxRetryDelay.inMilliseconds,
              );
              print('⏳ Trick pas encore prêt (409), réessai $retries/$maxRetries dans ${delayMs}ms...');
              await Future.delayed(Duration(milliseconds: delayMs));
              continue;
            }
          }
          
          // Autre erreur, arrêter
          print('❌ Erreur lors de la récupération du trick: ${trickData['message']}');
          currentPlayerPlaying = null;
          return;
        } catch (e) {
          // ✅ Si c'est une exception avec "409" ou "Trick not ready", réessayer avec délai progressif
          final errorStr = e.toString();
          if (errorStr.contains('409') || errorStr.contains('Trick not ready')) {
            retries++;
            if (retries < maxRetries) {
              // ✅ Délai progressif
              final delayMs = (initialRetryDelay.inMilliseconds + (retries * 250)).clamp(
                initialRetryDelay.inMilliseconds,
                maxRetryDelay.inMilliseconds,
              );
              print('⏳ Trick pas encore prêt (exception 409), réessai $retries/$maxRetries dans ${delayMs}ms...');
              await Future.delayed(Duration(milliseconds: delayMs));
              continue;
            }
          }
          
          // Autre exception, arrêter
          print('❌ Exception lors de la récupération du trick: $e');
          currentPlayerPlaying = null;
          return;
        }
      }
      
      // ✅ Vérifier que trickData a été initialisé et que la requête a réussi
      if (trickData == null || trickData['success'] != true) {
        print('❌ Impossible de récupérer le trick après $maxRetries tentatives');
        currentPlayerPlaying = null;
        return;
      }

      final data = trickData['data'] as Map<String, dynamic>;
      final gameId = data['game_id'] as int;
      final roundId = data['round_id'] as int;
      final trickId = data['trick_id'] as int;

      // 2. Préparer le code de la carte
      cardCode = card['code'] as String? ?? '';
      if (cardCode.isEmpty) {
        // Construire le code depuis value et suit
        final cardValue = (card['value'] as String? ?? '').toUpperCase();
        final cardSuit = (card['suit'] as String? ?? '').toUpperCase();
        final suitMapping = {
          'SPADES': 'S',
          'HEARTS': 'H',
          'DIAMONDS': 'D',
          'CLUBS': 'C',
        };
        final valueMapping = {
          'ACE': 'A',
          'KING': 'K',
          'QUEEN': 'Q',
          'JACK': 'J',
          '10': '0',
        };
        final cardSuitShort = suitMapping[cardSuit] ?? cardSuit;
        final cardValueShort = valueMapping[cardValue] ?? cardValue;
        cardCode = '$cardValueShort$cardSuitShort';
      }
      
      print('📤 Envoi carte via API Laravel: gameId=$gameId, roundId=$roundId, trickId=$trickId, card=$cardCode');
      
      // ✅ ENREGISTRER L'ÉVÉNEMENT LOCAL AVANT L'APPEL API
      // Cela permet à consumeLocalCardEvent de détecter que c'était un événement local
      // et d'éviter la double animation quand l'événement WebSocket arrive
      effectivePlayerName = playerName ?? widget.currentPlayerName;
      final eventKey = buildCardEventKey(effectivePlayerName, cardCode, trickNumber);
      registerLocalCardEvent(eventKey);
      print('✅ Événement local enregistré: $eventKey (pour éviter la double animation)');
      
      // ✅ ANIMATION IMMÉDIATE pour le joueur local AVANT l'appel API
      // IMPORTANT: Retirer la carte de la main AVANT l'animation pour que l'animation fonctionne correctement
      isLocalPlayer = effectivePlayerName == widget.currentPlayerName;
      
      // ✅ CORRECTION: Pour les joueurs locaux, créer un Completer pour attendre la fin de l'animation
      Completer<void>? animationCompleter;
      if (isLocalPlayer) {
        animationCompleter = Completer<void>();
        // ✅ Démarrer l'animation immédiatement
        startCardAnimation(card, effectivePlayerName, () {
          // Animation terminée - compléter le completer
          animationCompleter?.complete();
        });
      }
      
      // 3. Appeler l'API Laravel playCard
      final result = await GameApiService.instance.playCard(
        gameId: gameId,
        roundId: roundId,
        trickId: trickId,
        cardCode: cardCode,
        roundNumber: roundNumber,
        trickNumber: trickNumber,
        playerName: playerName,
      );

      // 4. ✅ Pour les joueurs locaux, attendre que l'animation soit terminée avant d'ajouter la carte au trick
      // Cela garantit que la carte n'apparaît pas au centre avant la fin de l'animation
      if (isLocalPlayer && animationCompleter != null) {
        await animationCompleter.future;
      }

      // 5. ✅ Pour TOUS les joueurs (locaux et bots), ajouter la carte au trick APRÈS confirmation du backend
      // Pour les bots, la carte a déjà été ajoutée avant l'animation, donc on vérifie d'abord
      final currentTrick = cardManager.currentTrick;
      final cardAlreadyInTrick = currentTrick.any((entry) {
        final entryCard = entry['card'] as Map<String, dynamic>?;
        final entryPlayer = entry['player'] as String?;
        return entryPlayer == effectivePlayerName && (entryCard?['code'] as String?) == cardCode;
      });
      
      // ✅ IMPORTANT: Retirer la carte de la main IMMÉDIATEMENT après confirmation du backend
      // Cela garantit la synchronisation entre backend et frontend
      final playerHand = cardManager.getPlayerCards(effectivePlayerName);
      final cardIndex = playerHand.indexWhere((c) => (c['code'] as String?) == cardCode);
      if (cardIndex != -1) {
        playerHand.removeAt(cardIndex);
        print('✅ Carte $cardCode retirée de la main de $effectivePlayerName (${playerHand.length} cartes restantes)');
      } else {
        print('⚠️ Carte $cardCode non trouvée dans la main de $effectivePlayerName (déjà retirée?)');
      }
      
      // ✅ Ajouter la carte au trick si elle n'y est pas déjà
      if (!cardAlreadyInTrick) {
        // La carte n'est pas encore dans le trick, l'ajouter
        // ✅ CORRECTION: Utiliser addCardToTrick() au lieu de playCard()
        // car le tour a peut-être déjà changé via WebSocket
        cardManager.addCardToTrick(effectivePlayerName, card);
        if (isLocalPlayer) {
          print('✅ Carte $cardCode ajoutée au trick pour $effectivePlayerName (joueur local) - après animation');
        } else {
          print('✅ Carte $cardCode ajoutée au trick pour $effectivePlayerName après confirmation backend');
        }
      } else {
        print('ℹ️ Carte $cardCode déjà dans le trick pour $effectivePlayerName');
      }
      
      // ✅ Mettre à jour le cache des cartes jouables après qu'une carte soit jouée
      // (pour les joueurs locaux uniquement, via la classe enfant)
      if (isLocalPlayer && mounted) {
        // La classe enfant (GameRoomHumanPage) mettra à jour le cache si nécessaire
        setState(() {});
      }
      
      // 5. Libérer le flag
      currentPlayerPlaying = null;
      
      // 6. ✅ SOLUTION 2: Utiliser la réponse du backend pour synchroniser le tour
      // Le backend retourne maintenant current_turn dans la réponse, évitant la race condition
      final trickCompleted = result['data']?['trick_completed'] == true;
      
      if (!trickCompleted) {
        // ✅ Utiliser le tour retourné par le backend (évite de recalculer après 200ms)
        final currentTurnData = result['data']?['current_turn'] as Map<String, dynamic>?;
        if (currentTurnData != null) {
          final currentTurnPlayer = currentTurnData['player_name'] as String?;
          if (currentTurnPlayer != null && currentTurnPlayer.isNotEmpty) {
            print('✅ Tour synchronisé depuis la réponse backend: $currentTurnPlayer');
            cardManager.currentPlayerTurn = currentTurnPlayer;
          } else {
            print('⚠️ current_turn retourné mais player_name vide');
          }
        } else {
          print('⚠️ current_turn non présent dans la réponse backend');
        }
      }
      
      // 7. ✅ CORRECTION: Mettre à jour l'UI APRÈS avoir ajouté la carte au trick
      // Cela garantit que la carte est visible dans _buildCenterTrick
      if (mounted) {
        setState(() {
          // ✅ DEBUG: Vérifier que la carte est bien dans le trick
          final verifyTrick = cardManager.currentTrick;
          final cardFound = verifyTrick.any((entry) {
            final entryCard = entry['card'] as Map<String, dynamic>?;
            final entryPlayer = entry['player'] as String?;
            return entryPlayer == effectivePlayerName && (entryCard?['code'] as String?) == cardCode;
          });
          if (cardFound) {
            print('✅ Vérification: Carte $cardCode de $effectivePlayerName bien présente dans le trick (${verifyTrick.length} cartes)');
          } else {
            print('❌ ERREUR: Carte $cardCode de $effectivePlayerName n\'est PAS dans le trick après ajout !');
            print('   Trick actuel: ${verifyTrick.map((e) => '${e['player']}→${e['card']?['code']}').join(", ")}');
          }
        });
      }

      // 8. Le backend gère déjà :
      //    - La détection de la 4ème carte
      //    - Le calcul du gagnant
      //    - Le délai de 2 secondes
      //    - La diffusion de l'événement trick_completed
      //    Donc on n'a plus besoin de gérer trickComplete ici
      //    On attend juste l'événement WebSocket trick_completed
      
      // 9. Si ce n'est pas la 4ème carte, passer au joueur suivant
      // ✅ CORRECTION: Appeler maybeAutoPlayCurrentBot() comme solution de repli
      // L'événement WebSocket turn_changed devrait aussi l'appeler, mais on garde ceci comme backup
      // Le flag currentPlayerPlaying empêchera les appels en double
      if (!trickCompleted) {
        print('🔄 Tour synchronisé, prochain joueur: ${cardManager.currentPlayerTurn}');
        // ✅ Utiliser un délai plus long (800ms) pour laisser l'événement turn_changed se déclencher d'abord
        // Si turn_changed n'arrive pas, ceci servira de backup
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          // ✅ Démarrer le timer de timeout de 15 secondes pour le joueur actuel
          startPlayerTurnTimeout();
          // ✅ Vérifier que le tour n'a pas changé entre-temps
          if (currentPlayerPlaying == null) {
            print('🔄 Backup: Appel de maybeAutoPlayCurrentBot() après délai (si turn_changed n\'a pas fonctionné)');
            maybeAutoPlayCurrentBot();
          } else {
            print('🔄 Backup: maybeAutoPlayCurrentBot() ignoré car $currentPlayerPlaying est déjà en train de jouer');
          }
        });
      }
      // Si c'est la 4ème carte, on attend l'événement trick_completed du backend

    } catch (e) {
      print('❌ Erreur lors de l\'appel API Laravel playCard: $e');
      print('   Détails: ${e.toString()}');
      
      // ✅ Ne pas bloquer le jeu si c'est une erreur de validation (422) ou de permission (403)
      // Ces erreurs sont normales et ne doivent pas bloquer le jeu
      final errorString = e.toString().toLowerCase();
      final isValidationError = errorString.contains('422') || 
                                errorString.contains('validation') ||
                                errorString.contains('jouable');
      final isTurnError = errorString.contains('403') || 
                          errorString.contains('tour') ||
                          errorString.contains('ce n\'est pas votre tour');
      
      // ✅ IMPORTANT: Pour les erreurs 422 (carte non jouable), retirer la carte du trick
      // et la remettre dans la main (pour les bots ET les joueurs locaux)
      if (isValidationError && playerName != null) {
        print('⚠️ Erreur 422 pour $effectivePlayerName - carte $cardCode non jouable selon le backend');
        print('   Retrait de la carte du trick local si elle y est...');
        
        // Retirer la carte du trick si elle y est
        final currentTrick = cardManager.currentTrick;
        final trickIndex = currentTrick.indexWhere((entry) {
          final entryCard = entry['card'] as Map<String, dynamic>?;
          final entryPlayer = entry['player'] as String?;
          return entryPlayer == effectivePlayerName && 
                 (entryCard?['code'] as String?) == cardCode;
        });
        
        if (trickIndex != -1) {
          currentTrick.removeAt(trickIndex);
          print('✅ Carte $cardCode retirée du trick pour $effectivePlayerName');
        }
        
        // Remettre la carte dans la main du joueur si elle n'y est pas déjà
        final playerCards = cardManager.getPlayerCards(effectivePlayerName);
        final cardInHand = playerCards.any((c) => (c['code'] as String?) == cardCode);
        if (!cardInHand) {
          playerCards.add(card);
          print('✅ Carte $cardCode remise dans la main de $effectivePlayerName');
        }
        
        // Libérer le flag pour permettre de réessayer avec une autre carte
        currentPlayerPlaying = null;
        
        // Mettre à jour l'UI
        if (mounted) {
          setState(() {});
          
          // Afficher un message d'erreur pour les joueurs locaux
          if (isLocalPlayer) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cette carte ($cardCode) ne peut pas être jouée selon les règles du jeu.'),
                duration: const Duration(seconds: 3),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            );
          }
        }
        
        // Pour les bots, réessayer avec une carte jouable depuis le backend
        if (!isLocalPlayer) {
          print('🔄 Réessai automatique pour bot $effectivePlayerName avec une carte jouable...');
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            if (cardManager.currentPlayerTurn == effectivePlayerName && 
                currentPlayerPlaying == null &&
                !cardManager.isAnnouncementPhase) {
              maybeAutoPlayCurrentBot();
            }
          });
        }
        
        return; // Sortir pour éviter d'afficher un message d'erreur supplémentaire
      }
      
      // ✅ Pour les erreurs 403 (tour), si c'est un bot, réessayer après un délai
      // Cela peut arriver si le backend n'a pas encore synchronisé le tour après la carte précédente
      if (isTurnError && !isLocalPlayer && playerName != null) {
        print('⚠️ Erreur 403 pour bot $effectivePlayerName - Réessai après délai de synchronisation...');
        print('   Le backend n\'a pas encore synchronisé le tour - attente de 1.5s avant retry');
        
        // ✅ IMPORTANT: Pour les bots, la carte n'a PAS encore été retirée de la main
        // car on ne la retire qu'après confirmation du backend (ligne 1166)
        // Donc la carte est toujours dans la main et on peut réessayer
        
        // ✅ Réessayer après un délai pour laisser le backend se synchroniser
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!mounted) return;
          
          // Vérifier que c'est toujours le tour de ce bot
          if (cardManager.currentPlayerTurn != effectivePlayerName) {
            print('⚠️ Le tour a changé pour $effectivePlayerName - annulation du retry');
            currentPlayerPlaying = null;
            return;
          }
          
          // Vérifier que la carte est toujours dans la main
          final playerCards = cardManager.getPlayerCards(effectivePlayerName);
          final cardStillInHand = playerCards.any((c) => (c['code'] as String?) == cardCode);
          
          if (cardStillInHand && currentPlayerPlaying == null && !cardManager.isAnnouncementPhase) {
            print('🔄 Retry pour bot $effectivePlayerName après erreur 403 (carte $cardCode toujours dans la main)');
            // Réessayer de jouer la carte
            _playCardViaLaravelAPI(card, localResult, playerName: playerName);
          } else {
            if (!cardStillInHand) {
              print('✅ Carte $cardCode n\'est plus dans la main de $effectivePlayerName - déjà jouée via WebSocket');
            }
            currentPlayerPlaying = null;
          }
        });
        
        // Ne pas libérer le flag immédiatement - on attend le retry
        return; // Sortir pour éviter d'afficher un message d'erreur
      }
      
      // ✅ Libérer le flag pour permettre de réessayer
      currentPlayerPlaying = null;
      
      if (mounted) {
        if (isValidationError) {
          // Erreur de validation : message court, ne pas bloquer
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Cette carte ne peut pas être jouée.'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          );
        } else if (!isTurnError) {
          // Erreur réseau ou serveur : message plus long
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erreur lors de l\'envoi de la carte. Veuillez réessayer.'),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          );
        }
        // Pour les erreurs 403 de tour, on ne montre pas de message (retry automatique)
        
        // ✅ Note: La carte n'a pas été retirée car on ne la retire qu'après confirmation du backend (ligne 1066)
        // Donc pas besoin de la remettre en cas d'erreur - elle est toujours dans la main du joueur
        
        setState(() {});
      }
    }
  }

  // ========== MÉTHODES HELPER POUR BACKEND ==========

  /// Obtenir le game_id depuis le backend
  /// ✅ Méthode protected pour être accessible aux classes enfants
  Future<int?> getGameId() async {
    try {
      final roomId = gameSession.roomId;
      if (roomId == null || roomId.isEmpty) return null;

      // ✅ Utiliser currentRound mais s'assurer qu'il est au moins 1
      // Si currentRound est 0, utiliser 1 (premier round)
      final roundNumber = (gameSession.currentRound > 0 
          ? gameSession.currentRound 
          : 1).clamp(1, 13);
      final trickNumber = (cardManager.currentTrickNumber > 0 
          ? cardManager.currentTrickNumber 
          : 1).clamp(1, 13);

      final trickData = await GameApiService.instance.getCurrentTrick(
        roomId: roomId,
        roundNumber: roundNumber,
        trickNumber: trickNumber,
      );

      if (trickData['success'] == true) {
        final data = trickData['data'] as Map<String, dynamic>;
        return data['game_id'] as int?;
      }
      return null;
    } catch (e) {
      print('⚠️ Erreur lors de la récupération du game_id: $e');
      return null;
    }
  }

  /// Obtenir le round_id pour le round actuel
  @protected
  Future<int?> getRoundIdForCurrentRound() async {
    try {
      final roomId = gameSession.roomId;
      if (roomId == null || roomId.isEmpty) return null;

      final roundNumber = gameSession.currentRound;
      final trickNumber = (cardManager.currentTrickNumber > 0 
          ? cardManager.currentTrickNumber 
          : 1).clamp(1, 13);

      final trickData = await GameApiService.instance.getCurrentTrick(
        roomId: roomId,
        roundNumber: roundNumber,
        trickNumber: trickNumber,
      );

      if (trickData['success'] == true) {
        final data = trickData['data'] as Map<String, dynamic>;
        return data['round_id'] as int?;
      }
      return null;
    } catch (e) {
      print('⚠️ Erreur lors de la récupération du round_id: $e');
      return null;
    }
  }

  /// Obtenir le trick_id pour le trick actuel
  @protected
  Future<int?> getTrickIdForCurrentTrick() async {
    try {
      final roomId = gameSession.roomId;
      if (roomId == null || roomId.isEmpty) return null;

      final roundNumber = gameSession.currentRound;
      final trickNumber = (cardManager.currentTrickNumber > 0 
          ? cardManager.currentTrickNumber 
          : 1).clamp(1, 13);

      final trickData = await GameApiService.instance.getCurrentTrick(
        roomId: roomId,
        roundNumber: roundNumber,
        trickNumber: trickNumber,
      );

      if (trickData['success'] == true) {
        final data = trickData['data'] as Map<String, dynamic>;
        return data['trick_id'] as int?;
      }
      return null;
    } catch (e) {
      print('⚠️ Erreur lors de la récupération du trick_id: $e');
      return null;
    }
  }

  /// Obtenir le player_id pour un joueur donné
  @protected
  Future<int?> getPlayerId(String playerName) async {
    try {
      // Chercher dans gameSession.players
      final players = gameSession.players;
      print('🔍 getPlayerId($playerName): Recherche dans ${players.length} joueurs locaux...');
      for (final player in players) {
        // ✅ Chercher avec plusieurs variantes du nom
        final name = (player['name'] ?? player['pseudo'] ?? player['normalizedName'] ?? '').toString();
        final normalizedName = (player['normalizedName'] ?? player['name'] ?? '').toString();
        
        // ✅ Comparaison flexible (insensible à la casse et aux espaces)
        final nameMatch = name.toLowerCase().trim() == playerName.toLowerCase().trim();
        final normalizedMatch = normalizedName.toLowerCase().trim() == playerName.toLowerCase().trim();
        
        if (nameMatch || normalizedMatch) {
          // Essayer de récupérer player_id depuis les données du joueur
          final playerId = player['player_id'] ?? player['id'];
          if (playerId != null) {
            final id = playerId is int ? playerId : int.tryParse(playerId.toString());
            print('✅ getPlayerId($playerName): Trouvé localement = $id (nom trouvé: "$name" ou "$normalizedName")');
            return id;
          } else {
            print('⚠️ getPlayerId($playerName): Joueur trouvé localement mais player_id manquant. Nom: "$name", Champs disponibles: ${player.keys.join(", ")}');
          }
        }
      }
      print('⚠️ getPlayerId($playerName): Joueur non trouvé dans les ${players.length} joueurs locaux. Noms disponibles: ${players.map((p) => (p['name'] ?? p['pseudo'] ?? p['normalizedName'] ?? '?').toString()).join(", ")}');

      // Si player_id n'est pas disponible localement, essayer de le récupérer depuis le backend
      final roomId = gameSession.roomId;
      if (roomId != null && roomId.isNotEmpty) {
        try {
          print('🔍 getPlayerId($playerName): Recherche dans le backend (roomId=$roomId)...');
          final roomData = await GameApiService.instance.getRoom(roomId: roomId);
          final data = (roomData['data'] as Map?) ?? roomData;
          final backendPlayers = (data['players'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          print('🔍 getPlayerId($playerName): ${backendPlayers.length} joueurs dans le backend');
          for (final player in backendPlayers) {
            final pseudo = (player['pseudo'] ?? '').toString();
            final first = (player['first_name'] ?? '').toString();
            final last = (player['last_name'] ?? '').toString();
            final name = (pseudo.isNotEmpty
                ? pseudo
                : ([first, last].where((s) => s.isNotEmpty).join(' ').trim())).trim();
            if (name == playerName) {
              final playerId = player['player_id'] ?? player['id'];
              if (playerId != null) {
                final id = playerId is int ? playerId : int.tryParse(playerId.toString());
                print('✅ getPlayerId($playerName): Trouvé dans le backend = $id');
                // ✅ Mettre à jour gameSession.players pour éviter les appels futurs
                final localPlayerIndex = players.indexWhere((p) => 
                  (p['name'] ?? p['pseudo'] ?? p['normalizedName'] ?? '').toString() == playerName);
                if (localPlayerIndex != -1) {
                  players[localPlayerIndex]['player_id'] = id;
                  print('✅ getPlayerId($playerName): player_id mis à jour localement');
                }
                return id;
              } else {
                print('⚠️ getPlayerId($playerName): Joueur trouvé dans le backend mais player_id manquant. Champs disponibles: ${player.keys.join(", ")}');
              }
            }
          }
          print('❌ getPlayerId($playerName): Joueur non trouvé dans le backend');
        } catch (e) {
          print('⚠️ Erreur lors de la récupération du player_id depuis le backend: $e');
        }
      } else {
        print('❌ getPlayerId($playerName): roomId est null ou vide');
      }

      print('❌ getPlayerId($playerName): Aucun player_id trouvé');
      return null;
    } catch (e) {
      print('⚠️ Erreur lors de la récupération du player_id: $e');
      return null;
    }
  }


  // Démarre l'animation de la carte de la main vers le centre
  void startCardAnimation(
    Map<String, dynamic> card,
    String playerName,
    VoidCallback onComplete,
  ) {
    // ✅ S'assurer que l'animation est visible en forçant un setState immédiat
    if (mounted) {
      setState(() {
        animatedCard = card;
        animatingPlayerName = playerName;
        isAnimatingCard = true;
      });
    }

    // ✅ Petit délai pour s'assurer que le widget est bien rendu avant de démarrer l'animation
    Future.microtask(() {
      if (!mounted) {
        onComplete();
        return;
      }
      
      cardAnimationController.reset();
      cardAnimationController.forward().then((_) {
        // Animation terminée
        if (mounted) {
          setState(() {
            isAnimatingCard = false;
            animatedCard = null;
            animatingPlayerName = null;
          });
        }
        // Exécuter le callback
        onComplete();
      });
    });
  }

  // Si c'est un bot, jouer automatiquement une carte valide
  void maybeAutoPlayCurrentBot() async {
    if (!mounted) {
      print('⚠️ maybeAutoPlayCurrentBot: widget non monté - ignoré');
      return;
    }
    if (cardManager.isAnnouncementPhase) {
      print('⚠️ maybeAutoPlayCurrentBot appelé pendant la phase d\'annonces - ignoré');
      return;
    }
    
    // ✅ Vérifier qu'aucun joueur n'est déjà en train de jouer
    if (currentPlayerPlaying != null) {
      print('⚠️ maybeAutoPlayCurrentBot: $currentPlayerPlaying est déjà en train de jouer - ignoré');
      return;
    }
    
    print('🔍 maybeAutoPlayCurrentBot: Vérification du joueur actuel...');

    // ✅ OPTIMISATION: Vérifier si c'est le dernier trick (fin de manche)
    // Une manche = exactement 13 tricks (4 joueurs × 13 cartes = 52 cartes)
    // Si currentTrickNumber > 13, c'est la fin de la manche (le 13ème trick est terminé)
    final currentTrickNum = cardManager.currentTrickNumber;
    if (currentTrickNum > 13) {
      print('🎉 Dernier trick terminé ! Manche terminée (trick=$currentTrickNum).');
      onRoundCompleted();
      return;
    }

    final current = cardManager.currentPlayerTurn;
    if (current.isEmpty) return;
    
    // ✅ Vérifier si ce joueur est déjà en train de jouer (éviter les doublons)
    if (currentPlayerPlaying == current) {
      print('⚠️ $current est déjà en train de jouer - évitement du doublon');
      return;
    }

    // ⚠️ IMPORTANT: En mode humain, ne jamais jouer automatiquement pour un joueur humain
    // Les joueurs humains doivent jouer leurs cartes eux-mêmes en les touchant
    if (!gameSession.playWithBots) {
      print('🔍 Vérification du type de joueur pour $current (mode humain)');
      final playerInfo = gameSession.players.firstWhere(
        (p) => (p['name'] as String?) == current,
        orElse: () => <String, Object>{},
      );

      final isBotValue = playerInfo['is_bot'];
      final isReplacementBotValue = playerInfo['isReplacementBot'];
      final isBot = isBotValue == true || isBotValue == 1 || (isBotValue is String && isBotValue == '1');
      final isReplacementBot = isReplacementBotValue == true || isReplacementBotValue == 1 || (isReplacementBotValue is String && isReplacementBotValue == '1');

      if (!isBot && !isReplacementBot) {
        print('👤 Mode humain: $current doit jouer sa carte manuellement (JOUEUR HUMAIN)');
        return;
      }

      print('🤖 Mode humain: bot $current joue automatiquement');
    } else {
      // Mode bot - vérifier si c'est le joueur local ou un bot
      if (current == widget.currentPlayerName) {
        // C'est le joueur local - ne pas jouer automatiquement
        print(
          '👤 Mode bot: joueur local $current doit jouer sa carte manuellement',
        );
        return;
      }
      // C'est un bot - jouer automatiquement
      print('🤖 Mode bot: bot $current joue automatiquement');
    }

    // Vérifier s'il reste des cartes à jouer pour ce joueur
    final botCards = cardManager.getPlayerCards(current);
    if (botCards.isEmpty) {
      print('✅ $current a terminé ses cartes, on passe au suivant');
      // Le _finishTrick va gérer le passage au joueur suivant
      return;
    }

    // ✅ IMPORTANT: Utiliser l'API backend pour obtenir les cartes jouables
    // La logique locale peut ne pas correspondre exactement à celle du backend
    Map<String, dynamic>? cardToPlay;
    List<Map<String, dynamic>> playable = [];
    try {
      final gameId = await getGameId();
      final roundId = await getRoundIdForCurrentRound();
      final trickId = await getTrickIdForCurrentTrick();
      final playerId = await getPlayerId(current);
      
      if (gameId != null && roundId != null && trickId != null && playerId != null) {
        print('🔍 Récupération des cartes jouables depuis le backend pour $current...');
        final playableCardCodes = await GameApiService.instance.getPlayableCards(
          gameId: gameId,
          roundId: roundId,
          trickId: trickId,
          playerId: playerId,
        );
        
        if (playableCardCodes.isNotEmpty) {
          // Trouver la première carte jouable dans la main du bot
          for (final cardCode in playableCardCodes) {
            final card = botCards.firstWhere(
              (c) => (c['code'] as String?) == cardCode,
              orElse: () => <String, dynamic>{},
            );
            if (card.isNotEmpty) {
              cardToPlay = card;
              print('✅ Carte jouable trouvée depuis le backend: ${cardToPlay['code']}');
              break;
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ Erreur lors de la récupération des cartes jouables depuis le backend: $e');
      print('   Utilisation de la logique locale comme fallback');
    }
    
    // ✅ Fallback: utiliser la logique locale si l'API backend échoue
    if (cardToPlay == null) {
      gameLogic.syncCurrentTrick(cardManager.currentTrick);
      playable = gameLogic.getPlayableCards(
        botCards,
        current,
        gameLogic.currentTrick.isEmpty,
      );
      cardToPlay = playable.isEmpty ? botCards.first : playable.first;
      print('⚠️ Utilisation de la logique locale pour sélectionner la carte: ${cardToPlay['code']}');
    } else {
      // Si la carte vient du backend et playable vide, initialiser pour logs cohérents
      if (playable.isEmpty) {
        playable = [cardToPlay];
      }
    }

    if (botCards.isEmpty) {
      print('⚠️ $current n\'a plus de cartes');
      return;
    }

    if (playable.isEmpty) {
      print(
        '⚠️ Aucune carte jouable pour $current selon les règles, on joue ${cardToPlay['code']}',
      );
    }

    currentPlayerPlaying = current;
    print('🎴 $current commence à jouer la carte ${cardToPlay['code']}');

    final playTimeout = Timer(const Duration(seconds: 5), () {
      if (currentPlayerPlaying == current) {
        print('⚠️ TIMEOUT: Libération forcée de currentPlayerPlaying pour $current');
        currentPlayerPlaying = null;
      }
    });
    
    final chosenCard = cardToPlay; // non-null après sélection
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || cardManager.isAnnouncementPhase) {
        playTimeout.cancel();
        currentPlayerPlaying = null;
        return;
      }
      
      // Vérifier à nouveau que c'est toujours le tour de ce bot
      if (cardManager.currentPlayerTurn != current) {
        playTimeout.cancel();
        currentPlayerPlaying = null;
        return;
      }

      // ✅ CORRECTION: Ajouter la carte au trick AVANT l'animation pour qu'elle soit visible
      // MAIS ne PAS retirer la carte de la main avant confirmation du backend
      // Cela garantit que la carte apparaît au centre même si l'événement WebSocket est ignoré
      // La carte sera retirée de la main APRÈS confirmation du backend (dans _playCardViaLaravelAPI)
      // ✅ Ajouter la carte au trick SANS la retirer de la main (pour les bots)
      final currentTrick = cardManager.currentTrick;
      final cardAlreadyInTrick = currentTrick.any((entry) {
        final entryCard = entry['card'] as Map<String, dynamic>?;
        final entryPlayer = entry['player'] as String?;
        return entryPlayer == current && 
               (entryCard?['code'] as String?) == chosenCard?['code'];
      });
      
      if (!cardAlreadyInTrick) {
        currentTrick.add({
          'player': current,
          'card': chosenCard,
          'timestamp': DateTime.now(),
        });
        print('✅ Carte ${chosenCard?['code']} ajoutée au trick pour $current (bot) - visible avant animation (pas encore retirée de la main)');
      }
      
      // Démarrer l'animation de la carte du bot vers le centre
      // La carte est déjà dans le trick, donc l'animation la montrera au centre
      if (chosenCard == null) {
        playTimeout.cancel();
        currentPlayerPlaying = null;
        return;
      }
      startCardAnimation(chosenCard, current, () {
      playTimeout.cancel();
      // Après l'animation, jouer la carte via API
      if (!mounted || cardManager.isAnnouncementPhase) {
        currentPlayerPlaying = null; // Libérer le flag en cas d'erreur
        return;
      }
      
      // ✅ Vérifier à nouveau que c'est toujours le tour de ce bot
      if (cardManager.currentPlayerTurn != current) {
        print('⚠️ Le tour a changé pour $current pendant l\'animation - annulation');
        currentPlayerPlaying = null;
        return;
      }
      
      try {
        final card = chosenCard!;
        // ✅ CORRECTION: Ne pas valider avec gameLogic.playCard() pour les bots
        // Le backend est la source de vérité et validera la carte
        // On envoie directement la carte à l'API Laravel
        // La carte est déjà dans le trick (ajoutée ligne 1666), donc elle sera visible
        _playCardViaLaravelAPI(
          card,
          {'success': true}, // Simuler un succès pour le flux API
          playerName: current,
        );
      } catch (e, stackTrace) {
        print('❌ Erreur lors du jeu automatique du bot: $e');
        print('Stack trace: $stackTrace');
        // ✅ En cas d'erreur, retirer la carte du trick si elle y est
        final currentTrick = cardManager.currentTrick;
        final cardIndex = currentTrick.indexWhere((entry) {
          final entryCard = entry['card'] as Map<String, dynamic>?;
          final entryPlayer = entry['player'] as String?;
          return entryPlayer == current && (entryCard?['code'] as String?) == chosenCard?['code'];
        });
        if (cardIndex != -1) {
          currentTrick.removeAt(cardIndex);
          print('✅ Carte retirée du trick après erreur');
        }
        // ✅ Libérer le flag en cas d'erreur
        currentPlayerPlaying = null;
      }
      });
    });
  }

  // ✅ NOUVEAU: Démarrer le timer de timeout de 15 secondes pour le joueur actuel
  // Note: méthode sans _ pour être accessible depuis les sous-classes
  void startPlayerTurnTimeout() {
    // Annuler le timer précédent s'il existe
    _playerTurnTimeoutTimer?.cancel();
    _playerTurnTimeoutTimer = null;

    // Ne pas démarrer le timer si c'est la phase d'annonces
    if (cardManager.isAnnouncementPhase) {
      return;
    }

    final currentPlayer = cardManager.currentPlayerTurn;
    if (currentPlayer.isEmpty) {
      return;
    }

    // Ne pas démarrer le timer si un joueur est déjà en train de jouer
    if (currentPlayerPlaying != null) {
      return;
    }

    // Ne pas démarrer le timer pour les bots (ils jouent automatiquement)
    if (!gameSession.playWithBots) {
      final playerInfo = gameSession.players.firstWhere(
        (p) => (p['name'] as String?) == currentPlayer,
        orElse: () => <String, Object>{},
      );
      final isBotValue = playerInfo['is_bot'];
      final isReplacementBotValue = playerInfo['isReplacementBot'];
      final isBot = isBotValue == true || isBotValue == 1 || (isBotValue is String && isBotValue == '1');
      final isReplacementBot = isReplacementBotValue == true || isReplacementBotValue == 1 || (isReplacementBotValue is String && isReplacementBotValue == '1');
      if (isBot || isReplacementBot) {
        return; // Les bots jouent automatiquement, pas besoin de timer
      }
    } else {
      // En mode bot, ne pas démarrer le timer si ce n'est pas le joueur local
      if (currentPlayer != widget.currentPlayerName) {
        return;
      }
    }

    print('⏱️ Démarrage du timer de 15 secondes pour $currentPlayer');
    
    _playerTurnTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || cardManager.isAnnouncementPhase) {
        return;
      }

      // Vérifier que c'est toujours le tour de ce joueur
      if (cardManager.currentPlayerTurn != currentPlayer) {
        print('⏱️ Timer expiré mais le tour a changé pour $currentPlayer - ignoré');
        return;
      }

      // Vérifier qu'aucun joueur n'est déjà en train de jouer
      if (currentPlayerPlaying != null) {
        print('⏱️ Timer expiré mais $currentPlayerPlaying est déjà en train de jouer - ignoré');
        return;
      }

      print('⏱️ TIMEOUT: 15 secondes écoulées pour $currentPlayer - jeu automatique de la plus grande carte jouable');
      _playHighestPlayableCard(currentPlayer);
    });
  }

  // ✅ NOUVEAU: Jouer automatiquement la plus grande carte jouable
  Future<void> _playHighestPlayableCard(String playerName) async {
    if (!mounted || cardManager.isAnnouncementPhase) {
      return;
    }

    // Vérifier que c'est toujours le tour de ce joueur
    if (cardManager.currentPlayerTurn != playerName) {
      print('⚠️ _playHighestPlayableCard: le tour a changé pour $playerName');
      return;
    }

    // Vérifier qu'aucun joueur n'est déjà en train de jouer
    if (currentPlayerPlaying != null) {
      print('⚠️ _playHighestPlayableCard: $currentPlayerPlaying est déjà en train de jouer');
      return;
    }

    final playerCards = cardManager.getPlayerCards(playerName);
    if (playerCards.isEmpty) {
      print('⚠️ _playHighestPlayableCard: $playerName n\'a plus de cartes');
      return;
    }

    // ✅ IMPORTANT: Utiliser l'API backend pour obtenir les cartes jouables
    // La logique locale peut ne pas correspondre exactement à celle du backend
    List<String> playableCardCodes = [];
    try {
      final gameId = await getGameId();
      final roundId = await getRoundIdForCurrentRound();
      final trickId = await getTrickIdForCurrentTrick();
      final playerId = await getPlayerId(playerName);
      
      if (gameId != null && roundId != null && trickId != null && playerId != null) {
        print('🔍 Récupération des cartes jouables depuis le backend pour $playerName (timeout)...');
        playableCardCodes = await GameApiService.instance.getPlayableCards(
          gameId: gameId,
          roundId: roundId,
          trickId: trickId,
          playerId: playerId,
        );
      }
    } catch (e) {
      print('⚠️ Erreur lors de la récupération des cartes jouables depuis le backend: $e');
      print('   Utilisation de la logique locale comme fallback');
    }
    
    // ✅ Si on a des cartes jouables depuis le backend, les utiliser
    // IMPORTANT: Filtrer les cartes qui sont réellement dans la main locale
    List<Map<String, dynamic>> playable = [];
    if (playableCardCodes.isNotEmpty) {
      for (final cardCode in playableCardCodes) {
        final card = playerCards.firstWhere(
          (c) => (c['code'] as String?) == cardCode,
          orElse: () => <String, dynamic>{},
        );
        if (card.isNotEmpty) {
          playable.add(card);
        } else {
          // ✅ Carte jouable selon le backend mais pas dans la main locale
          // Cela peut arriver si la carte a été jouée via timeout mais pas encore synchronisée
          print('⚠️ _playHighestPlayableCard: carte $cardCode jouable selon backend mais absente de la main locale de $playerName');
        }
      }
    }
    
    // ✅ Fallback: utiliser la logique locale si l'API backend échoue ou ne retourne rien
    if (playable.isEmpty) {
      gameLogic.syncCurrentTrick(cardManager.currentTrick);
      playable = gameLogic.getPlayableCards(
        playerCards,
        playerName,
        gameLogic.currentTrick.isEmpty,
      );
    }

    if (playable.isEmpty) {
      print('⚠️ _playHighestPlayableCard: aucune carte jouable pour $playerName, utilisation de toutes les cartes');
      // Si aucune carte n'est jouable, utiliser toutes les cartes
      final sortedAll = _sortCardsByValue(playerCards);
      if (sortedAll.isNotEmpty) {
        await _playCardAutomatically(playerName, sortedAll.first);
      }
      return;
    }

    // Trier les cartes jouables par valeur (plus grande d'abord)
    final sortedPlayable = _sortCardsByValue(playable);
    if (sortedPlayable.isNotEmpty) {
      final highestCard = sortedPlayable.first;
      print('✅ _playHighestPlayableCard: $playerName joue automatiquement ${highestCard['code']} (plus grande carte jouable)');
      await _playCardAutomatically(playerName, highestCard);
    }
  }

  // ✅ NOUVEAU: Jouer une carte automatiquement (pour le timeout)
  Future<void> _playCardAutomatically(String playerName, Map<String, dynamic> card) async {
    if (!mounted || cardManager.isAnnouncementPhase) {
      return;
    }

    // Vérifier que c'est toujours le tour de ce joueur
    if (cardManager.currentPlayerTurn != playerName) {
      return;
    }

    // Marquer que ce joueur est en train de jouer
    currentPlayerPlaying = playerName;

    try {
      // Obtenir les cartes du joueur
      final playerCards = cardManager.getPlayerCards(playerName);
      final cardCode = card['code'] as String? ?? '';
      
      // ✅ Vérifier que la carte est toujours dans la main
      final cardInHand = playerCards.any((c) => (c['code'] as String?) == cardCode);
      if (!cardInHand) {
        print('⚠️ _playCardAutomatically: carte $cardCode n\'est plus dans la main de $playerName (déjà jouée?)');
        currentPlayerPlaying = null;
        return;
      }
      
      // Valider avec gameLogic
      final result = gameLogic.playCard(
        card,
        playerName,
        playerCards,
      );

      if (result['success'] == true) {
        // Jouer via l'API Laravel
        await _playCardViaLaravelAPI(
          card,
          result,
          playerName: playerName,
        );
        
        // ✅ IMPORTANT: Vérifier que la carte a bien été retirée de la main après l'appel API
        // Cela garantit la synchronisation même si l'événement WebSocket est ignoré
        final playerCardsAfter = cardManager.getPlayerCards(playerName);
        final cardStillInHand = playerCardsAfter.any((c) => (c['code'] as String?) == cardCode);
        
        if (cardStillInHand) {
          print('⚠️ _playCardAutomatically: carte $cardCode toujours dans la main après API - retrait manuel');
          // Retirer manuellement la carte de la main
          final cardIndex = playerCardsAfter.indexWhere((c) => (c['code'] as String?) == cardCode);
          if (cardIndex != -1) {
            playerCardsAfter.removeAt(cardIndex);
            print('✅ Carte $cardCode retirée manuellement de la main de $playerName');
            if (mounted) setState(() {});
          }
        } else {
          print('✅ _playCardAutomatically: carte $cardCode correctement retirée de la main de $playerName');
        }
      } else {
        currentPlayerPlaying = null;
        print('❌ _playCardAutomatically: validation échouée pour $playerName');
      }
    } catch (e) {
      currentPlayerPlaying = null;
      print('❌ _playCardAutomatically: erreur pour $playerName: $e');
    }
  }

  // Calcul et affichage du tableau de score à la fin de la manche
  // ✅ Méthode protégée accessible depuis les sous-classes
  Future<void> onRoundCompleted() async {
    try {
      final players = gameSession.players
          .map((p) => p['name'] as String? ?? 'Joueur')
          .toList();

      final announcements = cardManager.getCurrentRoundAnnouncements();
      // Construire une map {player -> announced}
      final Map<String, int> announcedByPlayer = {
        for (final p in players)
          p:
              (announcements.firstWhere(
                    (a) => a['player'] == p,
                    orElse: () => {'announcement': 0},
                  )['announcement']
                  as int? ??
              0),
      };

      // Obtenir les plis gagnés
      final Map<String, int> obtainedByPlayer = {
        for (final p in players) p: cardManager.getObtainedTricks(p),
      };

      // Enregistrer la fin de manche dans la session (persistance)
      // ⚠️ IMPORTANT: Cette méthode fonctionne pour les deux modes (bots et humains)
      final obtainedList = players
          .map((p) => obtainedByPlayer[p] ?? 0)
          .toList();
      gameSession.finalizeRound(gameSession.currentRound - 1, obtainedList);

      // ✅ Récupérer les scores calculés depuis le backend
      Map<String, int> scores = {};
      try {
        final roomId = gameSession.roomId ?? '';
        if (roomId.isNotEmpty) {
          // Sauvegarder le round d'abord pour obtenir le round_id
          final saveResult = await GameApiService.instance.saveRound(
            roomId: roomId,
            roundNumber: gameSession.currentRound,
            announcements: announcements.cast<Map<String, dynamic>>(),
            obtainedTricks: obtainedByPlayer,
          );
          
          // Récupérer le round_id depuis la réponse
          final roundId = saveResult['round_id'] as int?;
          if (roundId != null) {
            // Récupérer les scores calculés depuis le backend
            final scoresData = await GameApiService.instance.getRoundScores(roundId: roundId);
            final scoresFromBackend = scoresData['scores'] as Map<String, dynamic>?;
            if (scoresFromBackend != null) {
              // Convertir les scores en Map<String, int>
              // ✅ CORRECTION: Nettoyer les objets DateTime avant conversion
              for (final entry in scoresFromBackend.entries) {
                final value = entry.value;
                // Ignorer les objets DateTime et autres types non numériques
                if (value is num) {
                  scores[entry.key as String] = value.toInt();
                } else if (value is DateTime) {
                  // Ignorer les DateTime (ne pas les inclure dans les scores)
                  print('⚠️ DateTime ignoré dans scores: ${entry.key}');
                } else {
                  // Essayer de convertir en int si possible
                  scores[entry.key as String] = 0;
                }
              }
              print('✅ Scores récupérés depuis le backend: $scores');
            }
          }
        }
      } catch (e) {
        print('⚠️ Erreur lors de la récupération des scores depuis le backend: $e');
        // Fallback: calculer localement si l'API échoue
        for (final p in players) {
          final a = announcedByPlayer[p] ?? 0;
          final o = obtainedByPlayer[p] ?? 0;
          int s = 0;
          if (o == a) {
            s = a * 10;
          } else if (o < a) {
            s = -(a * 10);
          } else if (o > a && o <= a + 2) {
            s = (a * 10) + (o - a);
          } else if (o >= a + 3) {
            s = -(a * 10);
          }
          scores[p] = s;
        }
      }

      // Mettre à jour immédiatement l'affichage des scores globaux (compteur de cristal/SG)
      // Fonctionne identiquement pour les deux modes: playWithBots = true ou false
      if (mounted) {
        setState(() {
          // Les scores globaux sont maintenant à jour dans gameSession.globalScores
          // Le compteur de cristal se mettra à jour automatiquement via _getPlayerGlobalScore
        });
      }

      // ✅ Envoyer les données de fin de manche via WebSocket pour synchroniser tous les joueurs
      // (surchargé dans game_room_human_page.dart pour envoyer via WebSocket)
      // Le créateur envoie, et tous les joueurs (y compris le créateur) reçoivent le broadcast
      sendRoundCompletedViaWebSocket(
        gameSession.currentRound,
        announcedByPlayer,
        obtainedByPlayer,
        scores,
      );
      
      // ⚠️ IMPORTANT: Ne pas afficher le tableau de scores ici en mode humain
      // Il sera affiché via le listener round_completed_broadcast pour garantir la synchronisation
      // En mode bot, on affiche directement car il n'y a pas de WebSocket
      if (gameSession.playWithBots) {
        showScoreboardDialog(
          players,
          announcedByPlayer,
          obtainedByPlayer,
          scores,
          autoClose: true, // ✅ Fermeture automatique à la fin d'une manche
        );
      }

      // Après affichage des scores, décider de la suite
      // ⚠️ IMPORTANT: Vérifier si la partie est vraiment terminée avant d'appeler _handleGameWinner
      // La partie se termine uniquement si :
      // 1. Un joueur atteint ou dépasse 150 points, OU
      // 2. 10 rounds ont été complétés (pas seulement créés)

      final winnerIndex = gameSession.globalScores.indexWhere((s) => s >= 150);
      // Compter uniquement les rounds complétés
      final completedRounds = gameSession.roundsData
          .where((r) => (r['isCompleted'] as bool?) == true)
          .length;
      final isGameOver = winnerIndex != -1 || completedRounds >= 10;

      print('🔍 Fin de round - Vérification fin de partie:');
      print('   - WinnerIndex (≥150): $winnerIndex');
      print(
        '   - Rounds complétés: $completedRounds / ${gameSession.roundsData.length}',
      );
      print('   - CurrentRound: ${gameSession.currentRound}');
      print('   - IsGameOver: $isGameOver');

      if (isGameOver) {
        // ⚠️ PARTIE TERMINÉE - Ne PAS fermer le salon, seulement afficher le dialog de continuation
        String winnerName;
        int winnerScore;
        int winnerAmount = 0;
        int companyAmount = 0;
        int totalPot = 0;
        bool isReplacementBot = false;

        if (winnerIndex != -1) {
          // Gagnant direct ≥150: 90% au gagnant, 10% entreprise
          final entries = gameSession.globalScores.asMap().entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final top1 = entries.first;
          final winnerIdx = top1.key;
          winnerName =
              gameSession.players[winnerIdx]['name'] as String? ?? 'Joueur';
          winnerScore = gameSession.globalScores[winnerIdx].toInt();

          final minBet = gameSession.minimumBet ?? 0;
          totalPot = minBet * 4;
          winnerAmount = (totalPot * 0.9).round();
          companyAmount = totalPot - winnerAmount;

          // Vérifier si le gagnant est un bot remplaçant
          for (final player in gameSession.players) {
            if ((player['name'] as String?) == winnerName) {
              isReplacementBot = (player['isReplacementBot'] as bool?) ?? false;
              if (isReplacementBot) {
                // Bot remplaçant: 100% à l'entreprise
                winnerAmount = 0;
                companyAmount = totalPot;
              }
              break;
            }
          }

          print(
            '🏆 Gagnant direct: ' +
                winnerName +
                ' +' +
                winnerAmount.toString() +
                ' | Entreprise +' +
                companyAmount.toString(),
          );
        } else {
          // 10 rounds atteints: plus grand score gagne (pas de seuil 150)
          final entries = gameSession.globalScores.asMap().entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final winnerIdx = entries.first.key;
          winnerName =
              gameSession.players[winnerIdx]['name'] as String? ?? 'Joueur';
          winnerScore = gameSession.globalScores[winnerIdx].toInt();
          // Payout 90/10 sur la mise totale du salon (mise minimale × 4)
          final minBet = gameSession.minimumBet ?? 0;
          totalPot = minBet * 4;
          winnerAmount = (totalPot * 0.9).round();
          companyAmount = totalPot - winnerAmount;

          // Vérifier si le gagnant est un bot remplaçant
          for (final player in gameSession.players) {
            if ((player['name'] as String?) == winnerName) {
              isReplacementBot = (player['isReplacementBot'] as bool?) ?? false;
              if (isReplacementBot) {
                // Bot remplaçant: 100% à l'entreprise
                winnerAmount = 0;
                companyAmount = totalPot;
              }
              break;
            }
          }

          print(
            '🏁 Fin 10 manches: gagnant=' +
                winnerName +
                ' +' +
                winnerAmount.toString() +
                ' | Entreprise +' +
                companyAmount.toString(),
          );
        }

        // Distribuer les gains via le backend (uniquement en mode humain)
        if (!gameSession.playWithBots && totalPot > 0) {
          final roomIdStr = gameSession.roomId ?? '';
          final roomId = int.tryParse(roomIdStr) ?? 0;
          if (roomId > 0) {
            try {
              final distributeResult = await PaymentApiService.instance
                  .distributeWinnings(
                    roomId: roomId,
                    winnerName: winnerName,
                    winnerAmount: winnerAmount,
                    companyAmount: companyAmount,
                    isReplacementBot: isReplacementBot,
                    totalPot: totalPot,
                  );

              if (distributeResult['success'] == true) {
                print('✅ Gains distribués avec succès');
              } else {
                print(
                  '⚠️ Erreur lors de la distribution des gains: ${distributeResult['message']}',
                );
              }
            } catch (e) {
              print('❌ Exception lors de la distribution des gains: $e');
            }
          }
        }

        // Afficher le dialog de félicitations (qui appellera ensuite _showContinueGameDialog)
        handleGameWinner(winnerName);

        // Notifier le backend que la partie est terminée (MAIS NE PAS FERMER LE SALON)
        final roomId = gameSession.roomId ?? '';
        if (roomId.isNotEmpty) {
          try {
            GameApiService.instance.finalizeGame(
              roomId: roomId,
              winnerName: winnerName,
              winnerScore: winnerScore,
            );
          } catch (_) {}
        }
      } else {
        // ⚠️ PARTIE CONTINUE - Démarrer automatiquement une nouvelle manche dans le MÊME salon
        Future.delayed(const Duration(milliseconds: 400), () async {
          await startNewRound();
        });
      }
    } catch (e, st) {
      print('❌ Erreur calcul score: $e');
      print(st);
    }
  }

  Future<void> startNewRound() async {
    try {
      final playerNames = gameSession.players
          .map((p) => p['name'] as String? ?? 'Joueur')
          .toList();

      // Réinitialiser l'état d'annonces/pli et redistribuer (0/0)
      cardManager.resetRoundCounters();
      // ✅ S'assurer que le trick est bien vidé avant de commencer les annonces
      cardManager.clearCurrentTrick();
      
      gameLogic.configurePlayers(
        playerCount: playerNames.length,
        cardsPerPlayer: cardManager.cardsPerPlayer,
      );
      
      // ✅ Maintenant que tous les joueurs ont des piques, on peut démarrer la phase d'annonce
      cardManager.isAnnouncementPhase = true;
      cardManager.currentPlayerTurn = playerNames.first;
      hasAnnounced = false;
      currentAnnouncement = 2;
      if (mounted) {
        setState(() {});
        startAnnouncementTimerForCurrentPlayer(); // ✅ Maintenant async, mais on ne peut pas await ici
      }
    } catch (e) {
      print('❌ Erreur démarrage nouvelle manche: $e');
    }
  }

  // ========== MÉTHODES D'ANNONCES ==========

  void startAnnouncementTimer({
    required String playerName,
    required bool isLocalPlayer,
  }) {
    // ✅ IMPORTANT: Ne démarrer le timer QUE si c'est le tour du joueur local
    // pour éviter que le panneau apparaisse/disparaisse pour les autres joueurs
    if (!isLocalPlayer) {
      print('⚠️ Timer non démarré pour $playerName (joueur distant)');
      return;
    }
    
    // ✅ Ne pas réinitialiser le timer si c'est déjà le tour de ce joueur
    // pour éviter que le panneau clignote
    if (currentAnnouncementPlayer == playerName && announcementCountdown > 0) {
      print('⚠️ Timer déjà actif pour $playerName, ne pas réinitialiser');
      return;
    }
    
    // ⚠️ IMPORTANT: 30 secondes pour tous les modes (bot et humain)
    announcementTimer?.cancel();
    currentAnnouncementPlayer = playerName;
    announcementCountdown = 30;
    hasAnnounced = false;

    announcementTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (announcementCountdown > 0) {
          announcementCountdown--;
        }
      });

      if (announcementCountdown <= 0) {
        timer.cancel();
        _handleAnnouncementTimeout();
      }
    });
  }

  Future<void> startAnnouncementTimerForCurrentPlayer() async {
    // ✅ NOUVEAU: Obtenir le tour depuis le backend
    try {
      final gameId = await getGameId();
      final roundNumber = gameSession.currentRound;
      
      if (gameId != null) {
        final turnData = await GameApiService.instance.getAnnouncementTurn(
          gameId: gameId,
          roundNumber: roundNumber,
        );
        
        final currentPlayerName = turnData['current_player_name'] as String?;
        if (currentPlayerName != null && currentPlayerName.isNotEmpty) {
          // Synchroniser le tour avec le backend
          cardManager.currentPlayerTurn = currentPlayerName;
          print('🔄 Tour d\'annonces synchronisé depuis le backend: $currentPlayerName');
        }
      }
    } catch (e) {
      print('⚠️ Erreur lors de la récupération du tour d\'annonces depuis le backend: $e');
      // Fallback: utiliser la logique locale
    }
    
    final playerName = cardManager.getCurrentAnnouncingPlayer();
    if (playerName.isEmpty) {
      return;
    }
    final isLocalPlayer = playerName == widget.currentPlayerName;
    
    // ✅ Vérifier si c'est un bot - si oui, faire l'annonce automatiquement
    // Debug: Afficher tous les joueurs pour vérifier
    print('🔍 Vérification bot pour: $playerName');
    print('   isLocalPlayer: $isLocalPlayer');
    print('   gameSession.playWithBots: ${gameSession.playWithBots}');
    print('   Liste des joueurs:');
    for (final p in gameSession.players) {
      final name = p['name'] as String? ?? 'Joueur';
      // ✅ Accepter à la fois true (booléen) et 1 (entier) comme valeur "bot"
      final isBotValue = p['is_bot'];
      final isBot = isBotValue == true || isBotValue == 1 || (isBotValue is String && isBotValue == '1');
      print('     - $name: is_bot=$isBot');
    }
    
    final isBotPlayer = !isLocalPlayer &&
        (gameSession.playWithBots ||
            gameSession.players.any(
              (p) {
                final name = (p['name'] as String?);
                final isBotValue = p['is_bot'];
                final isBot = isBotValue == true || isBotValue == 1 || (isBotValue is String && isBotValue == '1');
                return name == playerName && isBot;
              },
            ));
    
    print('   isBotPlayer détecté: $isBotPlayer');
    
    if (isBotPlayer) {
      // ✅ Bot - annonce automatique après un court délai
      print('🤖 Démarrage annonce automatique pour bot : $playerName');
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && cardManager.isAnnouncementPhase) {
          try {
            // ✅ Calculer l'annonce dynamiquement en fonction de la main du bot
            final botAnnouncement = cardManager.getBotAnnouncement(playerName);
            print('🤖 $playerName annonce : $botAnnouncement plis (calculé dynamiquement)');
            cardManager.makeAnnouncement(playerName, botAnnouncement);
            
            // ✅ Envoyer l'annonce via WebSocket pour synchronisation temps réel (surchargé en mode humain)
            // Passer le nom du bot pour que le WebSocket sache qui fait l'annonce
            sendAnnouncementViaWebSocket(botAnnouncement, playerName: playerName);
            
            print('🤖 Annonce faite pour $playerName');
            
            // Forcer la mise à jour de l'interface
            if (mounted) {
              setState(() {});
            }
            
            // Passer au joueur suivant (récursif)
            handleAnnouncementTurnComplete();
          } catch (e, stackTrace) {
            print('❌ Erreur lors de l\'annonce automatique du bot : $e');
            print('Stack trace : $stackTrace');
            // En cas d'erreur, forcer le passage au joueur suivant
            final nextPlayers = gameSession.players
                .map((player) => player['name'] as String? ?? 'Joueur')
                .toList();
            cardManager.nextTurn(nextPlayers);
            if (mounted) {
              setState(() {});
            }
            handleAnnouncementTurnComplete();
          }
        } else {
          print(
            '⚠️ Mounted: $mounted, IsAnnouncementPhase: ${cardManager.isAnnouncementPhase}',
          );
        }
      });
    } else {
      // ✅ Joueur humain - démarrer le timer normal
      startAnnouncementTimer(
        playerName: playerName,
        isLocalPlayer: isLocalPlayer,
      );
    }
  }

  // Fonction pour gérer le timeout d'annonce
  void _handleAnnouncementTimeout() {
    final playerName = currentAnnouncementPlayer;
    if (playerName == null || playerName.isEmpty) {
      return;
    }

    final announcements = cardManager.getCurrentRoundAnnouncements();
    final alreadyAnnounced = announcements.any(
      (ann) => ann['player'] == playerName,
    );
    if (alreadyAnnounced) {
      // L'annonce a déjà été faite, passer au suivant
      handleAnnouncementTurnComplete();
      return;
    }

    // ✅ Timeout : Annonce automatique de 2 (minimum) et passage au suivant
    print('⏰ Timeout d\'annonce pour $playerName - Attribution automatique de 2 plis');
    _forceAnnouncementForPlayer(playerName, 2);
    
    // Envoyer l'annonce via WebSocket si c'est le joueur local (surchargé dans mode humain)
    sendAnnouncementTimeoutViaWebSocket(playerName);
    
    // Passer au joueur suivant
    handleAnnouncementTurnComplete();
  }

  // Hook pour envoyer l'annonce timeout via WebSocket (surchargé dans mode humain)
  void sendAnnouncementTimeoutViaWebSocket(String playerName) {
    // Par défaut, ne rien faire (mode bot)
    // Surchargée dans game_room_human_page.dart
  }
  
  // Hook pour envoyer les données de fin de manche via WebSocket (surchargé dans mode humain)
  void sendRoundCompletedViaWebSocket(
    int roundNumber,
    Map<String, int> announcedByPlayer,
    Map<String, int> obtainedByPlayer,
    Map<String, int> scores,
  ) {
    // Par défaut, ne rien faire (mode bot)
    // Surchargée dans game_room_human_page.dart
  }
  
  void _forceAnnouncementForPlayer(String playerName, int announcement) {
    announcementTimer?.cancel();
    final int clampedAnnouncement = announcement.clamp(2, 13).toInt();
    if (playerName == widget.currentPlayerName) {
      cardManager.makeAnnouncement(playerName, clampedAnnouncement);
      if (mounted) {
        setState(() {
          hasAnnounced = true;
          currentAnnouncement = clampedAnnouncement;
        });
      } else {
        hasAnnounced = true;
        currentAnnouncement = clampedAnnouncement;
      }
    } else {
      cardManager.forceAnnouncement(playerName, clampedAnnouncement);
    }

    currentAnnouncementPlayer = null;
  }

  // Hook pour envoyer l'annonce via WebSocket (surchargé dans mode humain)
  /// [playerName] est optionnel : si fourni, utilise ce nom (pour les bots), sinon utilise le joueur actuel
  void sendAnnouncementViaWebSocket(int announcement, {String? playerName}) {
    // Par défaut, ne rien faire (mode bot)
    // Surchargée dans game_room_human_page.dart
  }

  // Flag pour éviter les appels multiples à handleAnnouncementTurnComplete

  // Fonction pour gérer la fin du tour d'annonce
  Future<void> handleAnnouncementTurnComplete() async {
    // ⚠️ Si la phase d'annonces est déjà terminée, ignorer les appels tardifs
    if (!cardManager.isAnnouncementPhase) {
      print('⚠️ handleAnnouncementTurnComplete ignoré: phase d\'annonces déjà terminée');
      return;
    }

    // ✅ Protection contre les appels multiples
    if (isProcessingAnnouncementCompletion) {
      print('⚠️ handleAnnouncementTurnComplete déjà en cours - évitement du doublon');
      return;
    }
    
    final playerNames = gameSession.players
        .map((player) => player['name'] as String? ?? 'Joueur')
        .toList();
    
    // ✅ Vérifier si toutes les annonces sont faites AVANT de passer au tour suivant
    // ⚠️ IMPORTANT: Le round est déjà ajouté dans announcements_complete (game_room_human_page.dart)
    // On ne doit PAS l'ajouter ici pour éviter les doublons
    if (cardManager.areAllAnnouncementsDone(playerNames)) {
      // ✅ Protection contre les appels multiples pour l'ajout de round
      if (isProcessingAnnouncementCompletion) {
        print('⚠️ Round déjà en cours d\'ajout - évitement du doublon');
        return;
      }
      isProcessingAnnouncementCompletion = true;
      
      print('✅ Toutes les annonces sont terminées !');

      // Réinitialiser le timer d'annonce
      announcementTimer?.cancel();
      currentAnnouncementPlayer = null;
      announcementCountdown = 0;

      // ✅ NOUVEAU: Valider les enchères depuis le backend
      final announcements = cardManager.getCurrentRoundAnnouncements();
      print('📊 Annonces récupérées : $announcements');
      
      // Convertir les annonces en format Map<String, int> pour le backend
      final announcementsMap = <String, int>{};
      for (final ann in announcements) {
        final playerName = (ann['player'] as String?) ?? 'Joueur';
        final announcement = (ann['announcement'] as int?) ?? 0;
        announcementsMap[playerName] = announcement;
      }

      bool needsNewBids = false;
      try {
        // Obtenir le round_id pour la validation backend
        final roundId = await getRoundIdForCurrentRound();
        if (roundId != null) {
          // Valider depuis le backend
          await GameApiService.instance.validateAnnouncements(
            roundId: roundId,
            announcements: announcementsMap,
          );
          print('✅ Annonces validées par le backend');
        } else {
          // Fallback: validation locale si round_id n'est pas disponible
          print('⚠️ round_id non disponible, utilisation de la validation locale');
          final validationResult = gameLogic.validateAnnouncements(announcements);
          needsNewBids = validationResult['needsNewBids'] == true;
        }
      } catch (e) {
        // Si la validation backend échoue (ex: somme = 13), utiliser la logique locale
        print('⚠️ Erreur lors de la validation backend des annonces: $e');
        print('   Utilisation de la validation locale comme fallback');
        final validationResult = gameLogic.validateAnnouncements(announcements);
        needsNewBids = validationResult['needsNewBids'] == true;
      }

      if (needsNewBids) {
        // Cas 2: Total < 10 → Ajouter +1 à chaque annonce et démarrer le jeu après notification
        showLowTotalMessage();
        // Ajouter +1 à chaque annonce dans le gestionnaire (fonctionne pour mode bot et humain)
        cardManager.incrementAllAnnouncements();
        // Récupérer les annonces mises à jour
        final updatedAnnouncements = cardManager
            .getCurrentRoundAnnouncements();
        print('📊 Annonces augmentées de +1 chacune: $updatedAnnouncements');

        // Démarrer le jeu après 3 secondes
        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;
          try {
            // ✅ Réinitialiser le flag de joueur en cours avant de démarrer
            currentPlayerPlaying = null;
            
            // ✅ Utiliser startGamePhase() pour initialiser correctement currentTrickNumber à 1
            cardManager.startGamePhase();
            
            // ✅ CORRECTION: Dans le cas des annonces augmentées, on crée un nouveau round
            // donc on utilise currentRound + 1 (c'est différent du cas normal)
            final nextRoundNum = gameSession.currentRound + 1;
            final alreadyAdded = gameSession.roundsData.any(
              (r) => (r['roundNumber'] as int) == nextRoundNum
            );
            
            if (!alreadyAdded) {
              final players = gameSession.players
                  .map((p) => p['name'] as String? ?? 'Joueur')
                  .toList();
              final anns = players.map((name) {
                final a = updatedAnnouncements.firstWhere(
                  (e) => e['player'] == name,
                  orElse: () => <String, Object>{'announcement': 0},
                );
                return a['announcement'] as int? ?? 0;
              }).toList();
              gameSession.addRound(anns); // ✅ Ici on utilise addRound() car c'est un nouveau round
              print('✅ Round $nextRoundNum ajouté (total < 10, annonces augmentées)');
            }
            
            // Choisir le premier joueur de la phase de jeu selon la rotation par round
            // Utiliser le numéro de round qui vient d'être ajouté
            final starting = getStartingPlayerForRoundPlay(nextRoundNum);
            cardManager.currentPlayerTurn = starting;
            print('🎯 Premier joueur pour la phase de jeu (Round $nextRoundNum): $starting');

            print('✅ Phase de jeu configurée - Premier joueur: $starting');

          // ✅ Ajouter un délai pour éviter les animations incontrôlées
          Future.delayed(const Duration(milliseconds: 800), () {
            if (!mounted) return;
            setState(() {
              print('✅ Interface mise à jour');
            });

            // ✅ Le jeu démarre automatiquement sans message - les joueurs voient directement le premier tour

            // ✅ Démarrer le moteur de jeu automatique pour les bots avec un petit délai supplémentaire
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && !cardManager.isAnnouncementPhase) {
                maybeAutoPlayCurrentBot();
              }
            });
          });
          } catch (e, stackTrace) {
            print('❌ Erreur lors du démarrage de la phase de jeu : $e');
            print('Stack trace : $stackTrace');
          } finally {
            // ✅ Réinitialiser le flag après traitement
            isProcessingAnnouncementCompletion = false;
          }
        });
        return; // Sortir pour éviter d'exécuter le code suivant
      } else {
        // Cas 3: Annonces valides → Commencer directement la phase de jeu
        print('🎮 Démarrage de la phase de jeu !');
        
        // ✅ Démarrer directement la phase de jeu (pas d'affichage du tableau après les annonces)
        // Le tableau de scores s'affichera uniquement à la fin de la manche
        _startGamePhaseAfterAnnouncements();
      }
    } else {
      // ✅ Vérifier d'abord si le joueur actuel a déjà fait son annonce
      final currentPlayerBeforeTurn = cardManager.currentPlayerTurn;
      final announcements = cardManager.getCurrentRoundAnnouncements();
      final hasCurrentPlayerAnnounced = announcements.any(
        (ann) => ann['player'] == currentPlayerBeforeTurn,
      );
      
      // Si le joueur actuel n'a pas encore fait son annonce, ne pas passer au suivant
      if (!hasCurrentPlayerAnnounced && currentPlayerBeforeTurn.isNotEmpty) {
        print('⚠️ Le joueur $currentPlayerBeforeTurn n\'a pas encore fait son annonce - attente');
        // Démarrer le timer pour le joueur actuel s'il ne l'a pas déjà
        if (currentAnnouncementPlayer != currentPlayerBeforeTurn) {
          final isLocalPlayer = currentPlayerBeforeTurn == widget.currentPlayerName;
          
          // ✅ Debug: Vérifier la détection du bot
          print('🔍 Vérification bot dans handleAnnouncementTurnComplete: $currentPlayerBeforeTurn');
          print('   isLocalPlayer: $isLocalPlayer');
          print('   gameSession.playWithBots: ${gameSession.playWithBots}');
          for (final p in gameSession.players) {
            final name = p['name'] as String? ?? 'Joueur';
            // ✅ Accepter à la fois true (booléen) et 1 (entier) comme valeur "bot"
      final isBotValue = p['is_bot'];
      final isBot = isBotValue == true || isBotValue == 1 || (isBotValue is String && isBotValue == '1');
            if (name == currentPlayerBeforeTurn) {
              print('   ✅ Joueur trouvé: $name, is_bot=$isBot');
            }
          }
          
          final isBotPlayer = !isLocalPlayer &&
              (gameSession.playWithBots ||
                  gameSession.players.any(
                    (p) {
                      final name = (p['name'] as String?);
                      if (name != currentPlayerBeforeTurn) return false;
                      final isBotValue = p['is_bot'];
                      return isBotValue == true || isBotValue == 1 || (isBotValue is String && isBotValue == '1');
                    },
                  ));
          
          print('   isBotPlayer détecté: $isBotPlayer');
          
          if (isBotPlayer) {
            // Bot - annonce automatique
            // ✅ Vérifier si le bot a déjà fait son annonce (éviter les doublons)
            final announcements = cardManager.getCurrentRoundAnnouncements();
            final alreadyAnnounced = announcements.any(
              (ann) => ann['player'] == currentPlayerBeforeTurn,
            );
            
            if (alreadyAnnounced) {
              print('⚠️ $currentPlayerBeforeTurn a déjà annoncé, passage au joueur suivant');
              // Passer directement au joueur suivant
              final nextPlayers = gameSession.players
                  .map((player) => player['name'] as String? ?? 'Joueur')
                  .toList();
              cardManager.nextTurn(nextPlayers);
              if (mounted) {
                setState(() {});
              }
              handleAnnouncementTurnComplete();
            } else {
              Future.delayed(const Duration(milliseconds: 800), () async {
                if (mounted && cardManager.isAnnouncementPhase) {
                  try {
                    // ✅ Vérifier à nouveau si l'annonce n'a pas été faite entre-temps
                    final currentAnnouncements = cardManager.getCurrentRoundAnnouncements();
                    final stillNotAnnounced = !currentAnnouncements.any(
                      (ann) => ann['player'] == currentPlayerBeforeTurn,
                    );
                    
                    if (!stillNotAnnounced) {
                      print('⚠️ $currentPlayerBeforeTurn a déjà annoncé entre-temps, passage au joueur suivant');
                      final nextPlayers = gameSession.players
                          .map((player) => player['name'] as String? ?? 'Joueur')
                          .toList();
                      cardManager.nextTurn(nextPlayers);
                      if (mounted) {
                        setState(() {});
                      }
                      handleAnnouncementTurnComplete();
                      return;
                    }
                    
                    final botAnnouncement = cardManager.getBotAnnouncement(currentPlayerBeforeTurn);
                    print('🤖 $currentPlayerBeforeTurn annonce : $botAnnouncement plis');

                    final roundNumber = gameSession.currentRound > 0
                        ? gameSession.currentRound
                        : 1;

                    // Toujours enregistrer localement (mode bot sans WebSocket fiable)
                    cardManager.makeAnnouncement(
                      currentPlayerBeforeTurn,
                      botAnnouncement,
                    );

                    try {
                      final gameId = await getGameId();
                      if (gameId != null) {
                        await GameApiService.instance.makeAnnouncement(
                          gameId: gameId,
                          roundNumber: roundNumber,
                          announcementValue: botAnnouncement,
                          playerName: currentPlayerBeforeTurn,
                        );
                        print('✅ Annonce du bot envoyée au backend (round $roundNumber)');
                      }
                    } catch (e) {
                      print('⚠️ Annonce bot backend (round $roundNumber): $e');
                    }

                    if (!mounted) return;
                    setState(() {});
                    handleAnnouncementTurnComplete();
                  } catch (e) {
                    print('❌ Erreur annonce bot: $e');
                  }
                }
              });
            }
          } else if (isLocalPlayer) {
            currentAnnouncement = 2;
            hasAnnounced = false;
            startAnnouncementTimer(playerName: currentPlayerBeforeTurn, isLocalPlayer: true);
          } else {
            // ✅ Joueur distant - ne pas démarrer de timer
            // Le panneau apparaîtra automatiquement via getCurrentAnnouncingPlayer()
            print('🌐 Tour d\'un autre joueur humain : $currentPlayerBeforeTurn (pas de timer local)');
          }
        }
        return; // Ne pas passer au suivant tant que l'annonce n'est pas faite
      }
      
      // ✅ NOUVEAU: Obtenir le tour depuis le backend au lieu de gérer localement
      try {
        final gameId = await getGameId();
        final roundNumber = gameSession.currentRound;
        
        if (gameId != null) {
          // Obtenir le tour d'annonces depuis le backend
          final turnData = await GameApiService.instance.getAnnouncementTurn(
            gameId: gameId,
            roundNumber: roundNumber,
          );
          
          if (turnData['all_announced'] == true) {
            // Toutes les annonces sont faites, passer à la phase de jeu
            print('✅ Toutes les annonces sont terminées (backend) !');
            // Ne pas appeler handleAnnouncementTurnComplete ici pour éviter la récursion
            // L'événement WebSocket announcement_made déclenchera la fin
            return;
          }
          
          final currentPlayerName = turnData['current_player_name'] as String?;
          if (currentPlayerName != null && currentPlayerName.isNotEmpty) {
            // Synchroniser le tour avec le backend
            cardManager.currentPlayerTurn = currentPlayerName;
            print('🔄 Tour synchronisé depuis le backend: $currentPlayerName');
          }
        }
      } catch (e) {
        print('⚠️ Erreur lors de la récupération du tour depuis le backend: $e');
        // Fallback: utiliser la logique locale
        final playerNames = gameSession.players
            .map((player) => player['name'] as String? ?? 'Joueur')
            .toList();
        cardManager.nextTurn(playerNames);
      }
      
      // Démarrer le timer pour le prochain joueur
      final currentPlayer = cardManager.currentPlayerTurn;
      print('⏭️ Tour suivant pour : $currentPlayer');
      
      // ✅ Vérifier que le joueur précédent a bien fait son annonce avant de passer au suivant
      // pour éviter de réinitialiser le panneau du joueur actuel
      final currentAnnouncements = cardManager.getCurrentRoundAnnouncements();
      final allPlayers = gameSession.players
          .map((player) => player['name'] as String? ?? 'Joueur')
          .toList();
      
      // Trouver l'index du joueur actuel
      final currentIndex = allPlayers.indexOf(currentPlayer);
      if (currentIndex > 0) {
        final previousPlayer = allPlayers[currentIndex - 1];
        final previousPlayerAnnounced = currentAnnouncements.any(
          (ann) => ann['player'] == previousPlayer,
        );
        
        // Si le joueur précédent n'a pas encore fait son annonce, ne pas démarrer le timer
        // pour le joueur actuel (il attend encore son tour)
        if (!previousPlayerAnnounced && previousPlayer != widget.currentPlayerName) {
          print('⚠️ Le joueur précédent $previousPlayer n\'a pas encore fait son annonce, attente...');
          return;
        }
      }

      // ⚠️ IMPORTANT: Chaque joueur a 30 secondes pour faire son annonce
      // Vérifier si c'est un joueur humain (pas un bot)
      final isLocalPlayer = currentPlayer == widget.currentPlayerName;
      
      // ✅ Debug: Vérifier la détection du bot
      print('🔍 Vérification bot dans handleAnnouncementTurnComplete (suite): $currentPlayer');
      print('   isLocalPlayer: $isLocalPlayer');
      print('   gameSession.playWithBots: ${gameSession.playWithBots}');
      for (final p in gameSession.players) {
        final name = p['name'] as String? ?? 'Joueur';
        // ✅ Accepter à la fois true (booléen) et 1 (entier) comme valeur "bot"
      final isBotValue = p['is_bot'];
      final isBot = isBotValue == true || isBotValue == 1 || (isBotValue is String && isBotValue == '1');
        if (name == currentPlayer) {
          print('   ✅ Joueur trouvé: $name, is_bot=$isBot');
        }
      }
      
      final isBotPlayer =
          !isLocalPlayer &&
          (gameSession.playWithBots ||
              gameSession.players.any(
                (p) {
                  final name = (p['name'] as String?);
                  if (name != currentPlayer) return false;
                  final isBotValue = p['is_bot'];
                  return isBotValue == true || isBotValue == 1 || (isBotValue is String && isBotValue == '1');
                },
              ));

      print('   isBotPlayer détecté: $isBotPlayer');
      final isHumanRemotePlayer = !isLocalPlayer && !isBotPlayer;

      if (isBotPlayer) {
        // Bot - annonce automatique après 1 seconde
        print('🤖 Démarrage annonce automatique pour : $currentPlayer');
        
        // ✅ Vérifier si le bot a déjà fait son annonce (éviter les doublons)
        final announcements = cardManager.getCurrentRoundAnnouncements();
        final alreadyAnnounced = announcements.any(
          (ann) => ann['player'] == currentPlayer,
        );
        
        if (alreadyAnnounced) {
          print('⚠️ $currentPlayer a déjà annoncé, passage au joueur suivant');
          // Passer directement au joueur suivant sans attendre
          final nextPlayers = gameSession.players
              .map((player) => player['name'] as String? ?? 'Joueur')
              .toList();
          cardManager.nextTurn(nextPlayers);
          if (mounted) {
            setState(() {});
          }
          handleAnnouncementTurnComplete();
          return;
        }
        
        Future.delayed(const Duration(milliseconds: 800), () async {
          if (mounted && cardManager.isAnnouncementPhase) {
            try {
              // ✅ Vérifier à nouveau si l'annonce n'a pas été faite entre-temps
              final currentAnnouncements = cardManager.getCurrentRoundAnnouncements();
              final stillNotAnnounced = !currentAnnouncements.any(
                (ann) => ann['player'] == currentPlayer,
              );
              
              if (!stillNotAnnounced) {
                print('⚠️ $currentPlayer a déjà annoncé entre-temps, passage au joueur suivant');
                final nextPlayers = gameSession.players
                    .map((player) => player['name'] as String? ?? 'Joueur')
                    .toList();
                cardManager.nextTurn(nextPlayers);
                if (mounted) {
                  setState(() {});
                }
                handleAnnouncementTurnComplete();
                return;
              }
              
              final botAnnouncement = cardManager.getBotAnnouncement(
                currentPlayer,
              );
              print('🤖 $currentPlayer annonce : $botAnnouncement plis');

              final roundNumber = gameSession.currentRound > 0
                  ? gameSession.currentRound
                  : 1;

              cardManager.makeAnnouncement(currentPlayer, botAnnouncement);

              try {
                final gameId = await getGameId();
                if (gameId != null) {
                  await GameApiService.instance.makeAnnouncement(
                    gameId: gameId,
                    roundNumber: roundNumber,
                    announcementValue: botAnnouncement,
                    playerName: currentPlayer,
                  );
                  print('✅ Annonce du bot envoyée au backend (round $roundNumber)');
                }
              } catch (e) {
                print('⚠️ Annonce bot backend (round $roundNumber): $e');
              }

              print('🤖 Annonce faite pour $currentPlayer');

              if (mounted) {
                setState(() {});
                handleAnnouncementTurnComplete();
              }
            } catch (e, stackTrace) {
              print('❌ Erreur lors de l\'annonce automatique : $e');
              print('Stack trace : $stackTrace');
              // En cas d'erreur, forcer le passage au joueur suivant
              final nextPlayers = gameSession.players
                  .map((player) => player['name'] as String? ?? 'Joueur')
                  .toList();
              cardManager.nextTurn(nextPlayers);
              if (mounted) {
                setState(() {});
              }
              handleAnnouncementTurnComplete();
            }
          } else {
            print(
              '⚠️ Mounted: $mounted, IsAnnouncementPhase: ${cardManager.isAnnouncementPhase}',
            );
          }
        });
      } else if (isLocalPlayer) {
        // ✅ Joueur humain local - démarrer le timer de 30 secondes
        // Le panneau d'annonce sera visible uniquement pour ce joueur
        print('👤 Tour du joueur humain local : $currentPlayer');
        currentAnnouncement = 2; // Réinitialiser l'annonce par défaut
        hasAnnounced = false; // Réinitialiser le flag d'annonce
        startAnnouncementTimer(playerName: currentPlayer, isLocalPlayer: true);
      } else if (isHumanRemotePlayer) {
        // ✅ Joueur humain distant - ne pas démarrer de timer
        // Le panneau d'annonce sera affiché via getCurrentAnnouncingPlayer() quand ce sera son tour
        print('🌐 Tour d\'un autre joueur humain : $currentPlayer (pas de timer local)');
        // Ne pas appeler startAnnouncementTimer() pour les joueurs distants
        // Le panneau apparaîtra automatiquement via getCurrentAnnouncingPlayer()
      } else {
        // Par sécurité, annuler tout timer
        announcementTimer?.cancel();
        announcementCountdown = 0;
      }
    }

    setState(() {
      // Mettre à jour l'interface
    });
  }
  
  // ✅ Méthode helper pour démarrer la phase de jeu après les annonces
  void _startGamePhaseAfterAnnouncements() {
    try {
      // ✅ Réinitialiser le flag de joueur en cours avant de démarrer
      currentPlayerPlaying = null;
      
      // ✅ Utiliser startGamePhase() pour initialiser correctement currentTrickNumber à 1
      cardManager.startGamePhase();
      
      // ✅ CORRECTION: Utiliser le round actuel (pas currentRound + 1)
      // car les cartes ont été distribuées pour ce round et le round a déjà été ajouté
      // dans announcements_complete via addCurrentRound()
      final currentRoundNum = gameSession.currentRound;
      
      // ✅ IMPORTANT: Ne PAS ajouter le round ici car il est TOUJOURS ajouté dans announcements_complete
      // (game_room_human_page.dart ligne 1775) avant handleAnnouncementTurnComplete()
      // Vérifier que le round existe bien (devrait toujours être le cas)
      final alreadyAdded = gameSession.roundsData.any(
        (r) => (r['roundNumber'] as int) == currentRoundNum
      );
      
      if (!alreadyAdded) {
        // ⚠️ Ce cas ne devrait JAMAIS arriver car le round est toujours ajouté dans announcements_complete
        // Mais si cela arrive, on log juste un avertissement sans ajouter le round pour éviter les doublons
        print('⚠️ ATTENTION: Round $currentRoundNum non trouvé dans roundsData');
        print('   Le round devrait avoir été ajouté dans announcements_complete');
        print('   On ne l\'ajoute PAS ici pour éviter les doublons');
      } else {
        print('✅ Round $currentRoundNum confirmé dans roundsData (ajouté dans announcements_complete) - pas de duplication');
      }
      
      // Choisir le premier joueur de la phase de jeu selon la rotation par round
      // Utiliser le numéro de round actuel (celui pour lequel les cartes ont été distribuées)
      final starting = getStartingPlayerForRoundPlay(currentRoundNum);
      cardManager.currentPlayerTurn = starting;
      print('🎯 Premier joueur pour la phase de jeu (Round $currentRoundNum): $starting');

      // ✅ Ajouter un délai pour éviter les animations incontrôlées
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() {
          print('✅ Interface mise à jour');
        });

        // ✅ Le jeu démarre automatiquement sans message - les joueurs voient directement le premier tour

        // ✅ Démarrer le moteur de jeu automatique pour les bots avec un petit délai supplémentaire
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !cardManager.isAnnouncementPhase) {
            maybeAutoPlayCurrentBot();
          }
        });
      });
    } catch (e, stackTrace) {
      print('❌ Erreur lors du démarrage de la phase de jeu : $e');
      print('Stack trace : $stackTrace');
    } finally {
      // ✅ Réinitialiser le flag après traitement
      isProcessingAnnouncementCompletion = false;
    }
  }

  // ========== DISTRIBUTION DES CARTES ==========
  @protected
  Future<void> startCardDistribution() {
    throw UnimplementedError('startCardDistribution must be implemented by subclass');
  }

  @protected
  void startChatPolling() {
    throw UnimplementedError('startChatPolling must be implemented by subclass');
  }

  // ✅ Méthode virtuelle pour détecter le mode test (surchargée dans game_room_human_page.dart)
  @protected
  bool isTestMode() => false;

  // ========== MÉTHODES HELPER POUR DIALOGS ==========
  Future<void> showScoreboardDialog(
    List<String> players,
    Map<String, int> announcedByPlayer,
    Map<String, int> obtainedByPlayer,
    Map<String, int> scores, {
    bool autoClose = false, // ✅ Par défaut, ne pas fermer automatiquement (joueur ouvre manuellement)
  }) {
    // Somme = total des annonces (règle demandée)
    final int sommeAnnonces = players.fold(
      0,
      (sum, p) => sum + (announcedByPlayer[p] ?? 0),
    );

    // Infos salon (fallbacks si absent)
    final String roomName = gameSession.roomName ?? 'Salon';
    final String roomCode = gameSession.roomCode ?? '-----';
    final int minBet = gameSession.minimumBet ?? 0;

    // Timer pour la fermeture automatique (sera annulé si l'utilisateur ferme manuellement)
    Timer? autoCloseTimer;

    return showDialog(
      context: context,
      barrierDismissible:
          true, // Permettre la fermeture manuelle via le bouton ou en tapant à l'extérieur
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2E2B23),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Tableau de Score',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height:
                MediaQuery.of(context).size.height *
                0.6, // Limiter la hauteur à 60% de l'écran
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4B4941),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 2,
                          child: Text(
                            'Rondes',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        for (final p in players)
                          Expanded(
                            flex: 2,
                            child: Text(
                              p,
                              style: const TextStyle(
                                color: Colors.yellow,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const Expanded(
                          flex: 2,
                          child: Text(
                            'Somme',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Lignes des manches (R1..R10 max) à partir de la session
                  ...gameSession.roundsData.take(10).map((round) {
                    final rNum = round['roundNumber'] as int;
                    final rAnnouncements = (round['announcements'] as List<int>);
                    final rResults = (round['results'] as List<double?>);
                    final isCompleted = round['isCompleted'] as bool;
                    final somme = rAnnouncements.fold<int>(0, (s, a) => s + a);
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'R$rNum',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          for (int i = 0; i < players.length; i++)
                            Expanded(
                              flex: 2,
                              child: Text(
                                (isCompleted
                                    ? (rResults[i] ?? 0).toStringAsFixed(1)
                                    : rAnnouncements[i].toStringAsFixed(1)),
                                style: TextStyle(
                                  color: isCompleted ? Colors.white : Colors.yellow,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              somme.toStringAsFixed(1),
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4B4941).withOpacity(0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 2,
                          child: Text(
                            'Score global (SG)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        for (int i = 0; i < players.length; i++)
                          Expanded(
                            flex: 2,
                            child: Text(
                              (gameSession.globalScores[i]).toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            (gameSession.roundsData.isNotEmpty
                                    ? (gameSession.roundsData.last['announcements'] as List<int>)
                                            .fold<int>(0, (s, a) => s + a)
                                    : 0)
                                .toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),

                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                autoCloseTimer?.cancel();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Fermer',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      // ✅ Nettoyer le timer quand le dialog se ferme
      autoCloseTimer?.cancel();
    }).whenComplete(() {
      // ✅ Fermeture automatique après 5 secondes UNIQUEMENT si autoClose est true (fin de manche)
      if (autoClose) {
        autoCloseTimer = Timer(const Duration(seconds: 5), () {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
      }
    });
  }

  void handleGameWinner(String winnerName) {
    // ⚠️ IMPORTANT: En mode bot, pas de gains car pas de mise
    // En mode humains, afficher les gains (90% gagnant, 10% plateforme)
    // Si le gagnant est un bot remplaçant, 100% va à l'entreprise
    final bool isBotMode = gameSession.playWithBots;
    final int minBet = gameSession.minimumBet ?? 0;

    // Vérifier si le gagnant est un bot remplaçant
    bool isReplacementBot = false;
    String? replacedPlayerName;
    for (final player in gameSession.players) {
      if ((player['name'] as String?) == winnerName) {
        isReplacementBot = (player['isReplacementBot'] as bool?) ?? false;
        replacedPlayerName = player['replacedPlayerName'] as String?;
        break;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2E2B23),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '🎉 Félicitations !',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$winnerName a remporté la partie !',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (!isBotMode && minBet > 0) ...[
                // Mode humains - afficher les gains
                const SizedBox(height: 12),
                Text(
                  'Cagnotte: ${minBet * 4} cauris',
                  style: const TextStyle(color: Colors.white70),
                ),
                if (isReplacementBot) ...[
                  // Bot remplaçant gagnant : 100% à l'entreprise
                  Text(
                    '⚠️ Le joueur $replacedPlayerName a quitté le jeu.',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gain de l\'entreprise (100%): ${minBet * 4} cauris',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'La cagnotte revient entièrement à l\'entreprise car le bot remplaçant a gagné.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ] else ...[
                  // Joueur humain gagnant : 90% gagnant, 10% plateforme
                  Text(
                    'Gain du gagnant (90%): ${(minBet * 4 * 0.9).round()} cauris',
                    style: const TextStyle(color: Colors.greenAccent),
                  ),
                  Text(
                    'Part plateforme (10%): ${(minBet * 4 * 0.1).round()} cauris',
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                ],
              ] else ...[
                // Mode bot - message simple sans gains (pas de mise donc pas de gains)
                const Text(
                  'Partie terminée avec succès !',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ],
          ),
          // Pas de bouton - fermeture automatique après 10 secondes
        );
      },
    );

    // Fermer automatiquement après 10 secondes, puis afficher le dialog de continuation
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        _showContinueGameDialog();
      }
    });
  }

  void showLowTotalMessage() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            decoration: BoxDecoration(
              color: const Color(0xFF2E2B23), // ✅ Style cohérent avec l'application
              borderRadius: BorderRadius.circular(20), // ✅ Coins plus arrondis
              border: Border.all(
                color: const Color(0xFFFFD700), // ✅ Bordure dorée pour l'accent
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ Icône avec fond circulaire
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF228B22).withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF228B22),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Color(0xFF228B22),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                // ✅ Titre avec style amélioré
                const Text(
                  'Total des annonces < 10',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // ✅ Message principal avec style amélioré
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4B4941).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Chaque joueur a reçu +1 à son annonce',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                // ✅ Message de démarrage avec accent doré
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.play_circle_outline,
                      color: Color(0xFFFFD700),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Le jeu démarre automatiquement...',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    // Fermer automatiquement après 3 secondes
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  void _showContinueGameDialog() {
    // À implémenter dans les sous-classes si nécessaire
  }

}