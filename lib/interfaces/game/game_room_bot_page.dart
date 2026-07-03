import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import '../../services/api/game_api_service.dart';
import '../../services/user/user_service.dart';
import 'game_room_base_page.dart';

/// Page de jeu pour le MODE BOT uniquement
class GameRoomBotPage extends GameRoomBasePage {
  const GameRoomBotPage({
    super.key,
    required super.roomName,
    required super.roomCode,
    required super.minimumBet,
    super.currentPlayerName,
  });

  @override
  State<GameRoomBotPage> createState() => _GameRoomBotPageState();
}

class _GameRoomBotPageState extends GameRoomBaseState<GameRoomBotPage> {
  // Timers
  Timer? _announcementTimer;
  Timer? _roomPollTimer;
  Timer? _reconnectionCheckTimer;
  Timer? _stateSyncTimer;
  Timer? _chatPollingTimer;
  Timer? _chatToastTimer;
  Timer? _continueCountdownTimer;
  Timer? _roomCodeCheckTimer;

  // États bool/int
  int _announcementCountdown = 30;
  bool _hasAnnounced = false;
  String? _currentAnnouncementPlayer;
  int _currentAnnouncement = 2;
  bool _waitingForHumans = false;
  bool _isProcessingAnnouncementTurn = false;
  bool _isProcessingAnnouncementCompletion = false;
  String? _currentPlayerPlaying;
  bool _isWebSocketConnected = false;
  int _consecutiveStatePollingErrors = 0;
  bool _hasGameStarted = false;
  DateTime? _lastSuccessfulStatePoll;
  bool? _continueGameChoice;
  int _continueCountdown = 5;

  // Subscriptions
  StreamSubscription? _wsConnectSubscription;
  StreamSubscription? _wsDisconnectSubscription;
  StreamSubscription? _wsErrorSubscription;
  StreamSubscription? _playerReplacedSubscription;
  StreamSubscription? _playerRestoredSubscription;
  StreamSubscription? _playerDisconnectedSubscription;
  StreamSubscription? _playerReconnectedSubscription;
  StreamSubscription? _announcementMadeSubscription;
  StreamSubscription? _roomChatMessageSubscription;
  StreamSubscription? _cardPlayedSubscription;

  // Collections
  final Map<String, Map<String, dynamic>> _temporaryReplacements = {};
  final Set<String> _permanentlyExcludedPlayers = {};
  final List<Map<String, dynamic>> _chatMessages = [];

  // Animations & controllers
  late AnimationController _cardAnimationController;
  Animation<double>? _cardAnimation;
  Map<String, dynamic>? _animatedCard;
  String? _animatingPlayerName;
  bool _isAnimatingCard = false;

  bool _chatFeatureInitialized = false;
  bool _isChatPanelVisible = false;
  late TextEditingController _chatInputController;
  late ScrollController _chatScrollController;
  bool _isSendingChatMessage = false;
  Map<String, dynamic>? _chatToastMessage;
  late AnimationController _chatToastAnimationController;
  Animation<double>? _chatToastAnimation;

  String? _lastTrickWinner;
  bool _isCollectingTrick = false;

  // ===================== Getter/Setter overrides =====================
  @override
  Timer? get announcementTimer => _announcementTimer;
  @override
  set announcementTimer(Timer? value) => _announcementTimer = value;

  @override
  Timer? get roomPollTimer => _roomPollTimer;
  @override
  set roomPollTimer(Timer? value) => _roomPollTimer = value;

  @override
  Timer? get reconnectionCheckTimer => _reconnectionCheckTimer;
  @override
  set reconnectionCheckTimer(Timer? value) => _reconnectionCheckTimer = value;

  @override
  Timer? get stateSyncTimer => _stateSyncTimer;
  @override
  set stateSyncTimer(Timer? value) => _stateSyncTimer = value;

  @override
  Timer? get chatPollingTimer => _chatPollingTimer;
  @override
  set chatPollingTimer(Timer? value) => _chatPollingTimer = value;

  @override
  Timer? get chatToastTimer => _chatToastTimer;
  @override
  set chatToastTimer(Timer? value) => _chatToastTimer = value;

  @override
  Timer? get continueCountdownTimer => _continueCountdownTimer;
  @override
  set continueCountdownTimer(Timer? value) => _continueCountdownTimer = value;

  @override
  Timer? get roomCodeCheckTimer => _roomCodeCheckTimer;
  @override
  set roomCodeCheckTimer(Timer? value) => _roomCodeCheckTimer = value;

  @override
  int get announcementCountdown => _announcementCountdown;
  @override
  set announcementCountdown(int value) => _announcementCountdown = value;

  @override
  bool get hasAnnounced => _hasAnnounced;
  @override
  set hasAnnounced(bool value) => _hasAnnounced = value;

  @override
  String? get currentAnnouncementPlayer => _currentAnnouncementPlayer;
  @override
  set currentAnnouncementPlayer(String? value) =>
      _currentAnnouncementPlayer = value;

  @override
  int get currentAnnouncement => _currentAnnouncement;
  @override
  set currentAnnouncement(int value) => _currentAnnouncement = value;

  @override
  bool get waitingForHumans => _waitingForHumans;
  @override
  set waitingForHumans(bool value) => _waitingForHumans = value;

  @override
  bool get isProcessingAnnouncementTurn => _isProcessingAnnouncementTurn;
  @override
  set isProcessingAnnouncementTurn(bool value) =>
      _isProcessingAnnouncementTurn = value;

  @override
  bool get isProcessingAnnouncementCompletion =>
      _isProcessingAnnouncementCompletion;
  @override
  set isProcessingAnnouncementCompletion(bool value) =>
      _isProcessingAnnouncementCompletion = value;

  @override
  String? get currentPlayerPlaying => _currentPlayerPlaying;
  @override
  set currentPlayerPlaying(String? value) => _currentPlayerPlaying = value;

  @override
  bool get isWebSocketConnected => _isWebSocketConnected;
  @override
  set isWebSocketConnected(bool value) => _isWebSocketConnected = value;

  @override
  int get consecutiveStatePollingErrors => _consecutiveStatePollingErrors;
  @override
  set consecutiveStatePollingErrors(int value) =>
      _consecutiveStatePollingErrors = value;

  @override
  bool get hasGameStarted => _hasGameStarted;
  @override
  set hasGameStarted(bool value) => _hasGameStarted = value;

  @override
  DateTime? get lastSuccessfulStatePoll => _lastSuccessfulStatePoll;
  @override
  set lastSuccessfulStatePoll(DateTime? value) =>
      _lastSuccessfulStatePoll = value;

  @override
  StreamSubscription? get wsConnectSubscription => _wsConnectSubscription;
  @override
  set wsConnectSubscription(StreamSubscription? value) =>
      _wsConnectSubscription = value;

  @override
  StreamSubscription? get wsDisconnectSubscription =>
      _wsDisconnectSubscription;
  @override
  set wsDisconnectSubscription(StreamSubscription? value) =>
      _wsDisconnectSubscription = value;

  @override
  StreamSubscription? get wsErrorSubscription => _wsErrorSubscription;
  @override
  set wsErrorSubscription(StreamSubscription? value) =>
      _wsErrorSubscription = value;

  @override
  StreamSubscription? get playerReplacedSubscription =>
      _playerReplacedSubscription;
  @override
  set playerReplacedSubscription(StreamSubscription? value) =>
      _playerReplacedSubscription = value;

  @override
  StreamSubscription? get playerRestoredSubscription =>
      _playerRestoredSubscription;
  @override
  set playerRestoredSubscription(StreamSubscription? value) =>
      _playerRestoredSubscription = value;

  @override
  StreamSubscription? get playerDisconnectedSubscription =>
      _playerDisconnectedSubscription;
  @override
  set playerDisconnectedSubscription(StreamSubscription? value) =>
      _playerDisconnectedSubscription = value;

  @override
  StreamSubscription? get playerReconnectedSubscription =>
      _playerReconnectedSubscription;
  @override
  set playerReconnectedSubscription(StreamSubscription? value) =>
      _playerReconnectedSubscription = value;

  @override
  StreamSubscription? get announcementMadeSubscription =>
      _announcementMadeSubscription;
  @override
  set announcementMadeSubscription(StreamSubscription? value) =>
      _announcementMadeSubscription = value;

  @override
  StreamSubscription? get roomChatMessageSubscription =>
      _roomChatMessageSubscription;
  @override
  set roomChatMessageSubscription(StreamSubscription? value) =>
      _roomChatMessageSubscription = value;

  @override
  StreamSubscription? get cardPlayedSubscription => _cardPlayedSubscription;
  @override
  set cardPlayedSubscription(StreamSubscription? value) =>
      _cardPlayedSubscription = value;

  @override
  Map<String, Map<String, dynamic>> get temporaryReplacements =>
      _temporaryReplacements;

  @override
  Set<String> get permanentlyExcludedPlayers =>
      _permanentlyExcludedPlayers;

  @override
  AnimationController get cardAnimationController => _cardAnimationController;
  @override
  set cardAnimationController(AnimationController controller) =>
      _cardAnimationController = controller;

  @override
  Animation<double>? get cardAnimation => _cardAnimation;
  @override
  set cardAnimation(Animation<double>? value) => _cardAnimation = value;

  @override
  Map<String, dynamic>? get animatedCard => _animatedCard;
  @override
  set animatedCard(Map<String, dynamic>? value) => _animatedCard = value;

  @override
  String? get animatingPlayerName => _animatingPlayerName;
  @override
  set animatingPlayerName(String? value) => _animatingPlayerName = value;

  @override
  bool get isAnimatingCard => _isAnimatingCard;
  @override
  set isAnimatingCard(bool value) => _isAnimatingCard = value;

  @override
  bool get chatFeatureInitialized => _chatFeatureInitialized;
  @override
  set chatFeatureInitialized(bool value) => _chatFeatureInitialized = value;

  @override
  bool get isChatPanelVisible => _isChatPanelVisible;
  @override
  set isChatPanelVisible(bool value) => _isChatPanelVisible = value;

  @override
  TextEditingController get chatInputController => _chatInputController;

  @override
  ScrollController get chatScrollController => _chatScrollController;

  @override
  List<Map<String, dynamic>> get chatMessages => _chatMessages;
  @override
  set chatMessages(List<Map<String, dynamic>> value) {
    _chatMessages
      ..clear()
      ..addAll(value);
  }

  @override
  bool get isSendingChatMessage => _isSendingChatMessage;
  @override
  set isSendingChatMessage(bool value) => _isSendingChatMessage = value;

  @override
  Map<String, dynamic>? get chatToastMessage => _chatToastMessage;
  @override
  set chatToastMessage(Map<String, dynamic>? value) =>
      _chatToastMessage = value;

  @override
  AnimationController get chatToastAnimationController =>
      _chatToastAnimationController;
  @override
  set chatToastAnimationController(AnimationController controller) =>
      _chatToastAnimationController = controller;

  @override
  Animation<double>? get chatToastAnimation => _chatToastAnimation;
  @override
  set chatToastAnimation(Animation<double>? value) =>
      _chatToastAnimation = value;

  @override
  String? get lastTrickWinner => _lastTrickWinner;
  @override
  set lastTrickWinner(String? value) => _lastTrickWinner = value;

  @override
  bool get isCollectingTrick => _isCollectingTrick;
  @override
  set isCollectingTrick(bool value) => _isCollectingTrick = value;

  @override
  bool? get continueGameChoice => _continueGameChoice;
  @override
  set continueGameChoice(bool? value) => _continueGameChoice = value;

  @override
  int get continueCountdown => _continueCountdown;
  @override
  set continueCountdown(int value) => _continueCountdown = value;
  
  @override
  void onGameRoomInitialize() {
    _chatInputController = TextEditingController();
    _chatScrollController = ScrollController();
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );
    cardAnimation = CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeInOut,
    );
    _chatToastAnimationController = AnimationController(
      duration: const Duration(milliseconds: 7000),
      vsync: this,
    );
    chatToastAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _chatToastAnimationController, curve: Curves.linear),
    );
  }
  
  @override
  void onGameRoomDispose() {
    announcementTimer?.cancel();
    roomPollTimer?.cancel();
    reconnectionCheckTimer?.cancel();
    stateSyncTimer?.cancel();
    chatPollingTimer?.cancel();
    chatToastTimer?.cancel();
    continueCountdownTimer?.cancel();
    roomCodeCheckTimer?.cancel();

    wsConnectSubscription?.cancel();
    wsDisconnectSubscription?.cancel();
    wsErrorSubscription?.cancel();
    playerReplacedSubscription?.cancel();
    playerRestoredSubscription?.cancel();
    playerDisconnectedSubscription?.cancel();
    playerReconnectedSubscription?.cancel();
    announcementMadeSubscription?.cancel();
    roomChatMessageSubscription?.cancel();
    cardPlayedSubscription?.cancel();

    _chatInputController.dispose();
    _chatScrollController.dispose();
    _cardAnimationController.dispose();
    _chatToastAnimationController.dispose();
  }

  @override
  void startChatPolling() {
    chatPollingTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          showLeaveGameConfirmation();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/roomTable.jpeg'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                if (waitingForHumans)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.6),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: Colors.white),
                            const SizedBox(height: 16),
                            Text(
                              'Mode Bot - En cours d\'initialisation (${gameSession.players.length}/$requiredPlayers)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                buildPlayerHand(),
                buildPlayers(),
                buildCenterTrick(),
                
                if (isAnimatingCard && animatedCard != null)
                  buildAnimatedCard(),

                buildGameControls(),
                buildTurnMessage(),
                buildAnnouncementPanel(),
                buildAnnouncementNotification(),
                
                // ✅ Message d'annonce supprimé - les joueurs font simplement leur annonce

                _buildRoomInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Future<void> startCardDistribution() async {
    try {
      final playerNames = gameSession.players
          .map((player) => player['name'] as String? ?? 'Joueur')
          .toList();

      if (playerNames.isEmpty) {
        final roomId = gameSession.roomId ?? '';
        if (roomId.isNotEmpty) {
          try {
            if (gameSession.playWithBots &&
                gameSession.players.length < requiredPlayers) {
              await GameApiService.instance.fillBots(roomId: roomId);
            }
            final res = await GameApiService.instance.getRoom(roomId: roomId);
            final data = (res['data'] as Map?) ?? res;
            final players =
                (data['players'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            final currentName = UserService.instance.currentUserPseudo ?? '';
            final othersPositions = ['right', 'top', 'left'];
            
            int idx = 0;
            final normalized = players.map((p) {
              final pseudo = (p['pseudo'] ?? '').toString();
              final first = (p['first_name'] ?? '').toString();
              final last = (p['last_name'] ?? '').toString();
              final isBot = (p['is_bot'] ?? false) == true;
              final backendAvatar = (p['avatar'] ?? '').toString();
              final isCreator = ((p['is_creator'] ?? p['isCreator']) == true);
              final name = (pseudo.isNotEmpty
                      ? pseudo
                      : ([first, last]
                            .where((s) => s.isNotEmpty)
                            .join(' ')
                            .trim()))
                  .trim();
              final isCurrent = name == currentName && currentName.isNotEmpty;

              final displayPos = isCurrent
                  ? 'bottom'
                  : othersPositions[(idx++) % othersPositions.length];

              return {
                'name': name.isNotEmpty ? name : 'Joueur',
                'displayPosition': displayPos,
                'avatar': backendAvatar.isNotEmpty
                    ? backendAvatar
                    : (isBot ? '🤖' : '👤'),
                'isCurrentPlayer': isCurrent,
                'isCreator': isCreator,
                'score': '0/0',
                'cards': 13,
              };
            }).toList();
            
            if (normalized.isNotEmpty) {
              gameSession.players = normalized;
              gameSession.globalScores = List.filled(normalized.length, 0.0);
            }
          } catch (_) {}
        }
      }

      final effectivePlayerNames = gameSession.players
          .map((player) => player['name'] as String? ?? 'Joueur')
          .where((n) => n.isNotEmpty)
          .toList();
          
      if (effectivePlayerNames.isEmpty) {
        print('⚠️ Aucun joueur disponible');
        return;
      }

      final result = cardManager.shuffleAndDealCards(effectivePlayerNames);

      if (result['success'] == true) {
        if (gameSession.currentRound < 1) {
          gameSession.currentRound = 1;
        }

        gameLogic.configurePlayers(
          playerCount: effectivePlayerNames.length,
          cardsPerPlayer: cardManager.cardsPerPlayer,
        );

        try {
          final List<String> orderedCodes = [];
          for (final name in effectivePlayerNames) {
            final hand = cardManager.getPlayerCards(name);
            for (final c in hand) {
              orderedCodes.add((c['code'] as String?) ?? '');
            }
          }
          final payload = orderedCodes.join('-');
          final bytes = utf8.encode(payload);
          final hash = crypto.sha256.convert(bytes).toString();
          final roomId = gameSession.roomId ?? '';
          final roundNumber = gameSession.currentRound;
          if (roomId.isNotEmpty) {
            try {
              await GameApiService.instance.distributeCards(
                roomId: roomId,
                roundNumber: roundNumber,
              );
            } catch (e) {
              print('⚠️ Round $roundNumber distributeCards: $e');
            }
            await GameApiService.instance.startRound(
              roomId: roomId,
              roundNumber: roundNumber,
              deckHash: hash,
            );
          }
        } catch (_) {}

        cardManager.onRoundCompleted = (announcements, obtained) async {
          final roomId = gameSession.roomId ?? '';
          if (roomId.isNotEmpty) {
            try {
              await GameApiService.instance.saveRound(
                roomId: roomId,
                roundNumber: gameSession.currentRound,
                announcements: announcements,
                obtainedTricks: obtained,
              );
            } catch (_) {}
          }
          if (mounted) {
            tryCompleteRoundIfFinished();
          }
        };

        setState(() {});

        // Mode bot : les bots annoncent automatiquement
        final botNames = playerNames
            .where((name) => name != widget.currentPlayerName)
            .toList();
        for (final botName in botNames) {
          final computed = cardManager.getBotAnnouncement(botName);
          cardManager.forceAnnouncement(botName, computed);
        }
        
        cardManager.currentPlayerTurn = widget.currentPlayerName;

        setState(() {});
        startAnnouncementTimerForCurrentPlayer();

        hasGameStarted = true;
      }
    } catch (e) {
      print('❌ Erreur distribution: $e');
    }
  }

  // Widgets de base
  Widget buildPlayerHand() {
    final currentPlayerCards = sortCardsForDisplay(
      cardManager.getPlayerCards(widget.currentPlayerName),
    );

    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Container(
        height: 90, // Un peu de marge en hauteur pour l'animation
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final cardWidth = 55.0;
            final numCards = currentPlayerCards.length;

            if (numCards == 0) return const SizedBox.shrink();

            double step = cardWidth + 2.0; // Espacement par défaut
            if (numCards > 1) {
              final maxStep = (availableWidth - cardWidth - 20) / (numCards - 1);
              if (maxStep < step) {
                step = maxStep; // On compresse si ça ne rentre pas
              }
            }

            final totalWidth = (numCards - 1) * step + cardWidth;
            final startX = (availableWidth - totalWidth) / 2;

            return Stack(
              clipBehavior: Clip.none,
              children: List.generate(numCards, (index) {
                final card = currentPlayerCards[index];
                return Positioned(
                  left: startX + index * step,
                  bottom: 0,
                  child: buildHandCard(card),
                );
              }),
            );
          },
        ),
      ),
    );
  }

  Widget buildHandCard(Map<String, dynamic> card) {
    final isCurrentPlayerTurn =
        cardManager.currentPlayerTurn == widget.currentPlayerName;
    final isAnnouncementPhase = cardManager.isAnnouncementPhase;

    final playerCards = cardManager.getPlayerCards(widget.currentPlayerName);

    // ✅ Synchroniser le pli actuel avec GameLogic pour déterminer correctement les cartes jouables
    gameLogic.syncCurrentTrick(cardManager.currentTrick);

    final isPlayable = isCurrentPlayerTurn &&
        !isAnnouncementPhase &&
        gameLogic
            .getPlayableCards(
              playerCards,
              widget.currentPlayerName,
              gameLogic.currentTrick.isEmpty,
            )
            .contains(card);

    final isAnimating = isAnimatingCard &&
        animatedCard != null &&
        animatingPlayerName == widget.currentPlayerName &&
        animatedCard!['code'] == card['code'];

    if (isAnimating) {
      return Opacity(
        opacity: 0.0,
        child: Container(width: 55, height: 80),
      );
    }

    return GestureDetector(
      onTap: isPlayable ? () => _playCard(card) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 55,
        height: isPlayable ? 85 : 80,
        margin: EdgeInsets.only(bottom: isPlayable ? 5 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isPlayable ? Colors.green : Colors.grey.shade400,
            width: isPlayable ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            cardManager.getCardImagePath(card),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.white,
                child: Center(
                  child: Text(
                    card['code'] ?? '??',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildPlayers() {
    if (gameSession.players.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        loadPlayersFromBackend();
      });
      return const SizedBox.shrink();
    }

    final playersFromPerspective = getPlayersFromCurrentPerspective();
    if (playersFromPerspective.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: playersFromPerspective
          .map((player) => buildPlayer(player))
          .toList(),
    );
  }

  Widget buildPlayer(Map<String, dynamic> player) {
    final position = player['displayPosition'] as String? ?? 'bottom';
    Alignment alignment;

    switch (position) {
      case 'top':
        alignment = Alignment.topCenter;
        break;
      case 'left':
        alignment = Alignment.centerLeft;
        break;
      case 'right':
        alignment = Alignment.centerRight;
        break;
      case 'bottom':
        alignment = Alignment.bottomCenter;
        break;
      default:
        alignment = Alignment.center;
    }

    final current = cardManager.currentPlayerTurn;
    final isCurrentTurn = current == player['name'];
    final isThisCurrentPlayer = player['name'] == widget.currentPlayerName;

    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Transform.translate(
          offset: position == 'top' ? const Offset(0, -20) : Offset.zero,
          child: Container(
            margin: getPlayerMargin(position),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (position == 'bottom')
                  buildPlayerBottomWidget(player, isCurrentTurn, isThisCurrentPlayer)
                else if (position == 'left')
                  buildPlayerLeftWidget(player)
                else if (position == 'right')
                  buildPlayerRightWidget(player)
                else
                  buildPlayerTopWidget(player),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildPlayerBottomWidget(Map<String, dynamic> player, bool isCurrentTurn, bool isThisCurrentPlayer) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF8B4513),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.yellow,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text(
                    '♠',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                player['name'],
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.yellow.shade700,
              width: 3,
            ),
          ),
          child: CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Text(player['avatar'], style: const TextStyle(fontSize: 24)),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFF8B4513), borderRadius: BorderRadius.circular(12)),
          child: Text(
            getPlayerAnnouncementDisplay(player['name']),
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFF8B4513), borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.diamond, color: Colors.blue, size: 16),
              const SizedBox(width: 4),
              Text(
                getPlayerGlobalScore(player['name']).toString(),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildPlayerLeftWidget(Map<String, dynamic> player) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFF8B4513), borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.yellow,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text(
                    '♠',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(player['name'], style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Stack avec cartes en éventail et avatar (orienté vers la droite)
        SizedBox(
          width: 90,
          height: 100,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              // Cartes en éventail derrière l'avatar (orienté vers la droite)
              ...List.generate(getPlayerCardCount(player['name']), (index) {
                final cardCount = getPlayerCardCount(player['name']);
                final angle = cardCount > 0
                    ? (index - (cardCount - 1) / 2) * 0.12
                    : 0.0;
                final radius = 35.0;
                final centerX = 30.0;
                final centerY = 50.0;
                final cardX = centerX + radius * math.cos(angle) - 17.5;
                final cardY = centerY + radius * math.sin(angle) - 25;
                return Positioned(
                  left: cardX,
                  top: cardY,
                  child: Transform.rotate(
                    angle: angle,
                    child: cardManager.buildCardBack(width: 40, height: 55),
                  ),
                );
              }),
              // Avatar circulaire au centre
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Text(player['avatar'], style: const TextStyle(fontSize: 24)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Compteurs dynamiques sous l'avatar
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                getPlayerAnnouncementDisplay(player['name']),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.diamond, color: Colors.blue, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    getPlayerGlobalScore(player['name']).toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildPlayerRightWidget(Map<String, dynamic> player) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFF8B4513), borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.yellow,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text(
                    '♠',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(player['name'], style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Stack avec cartes en éventail et avatar (orienté vers la gauche)
        SizedBox(
          width: 90,
          height: 100,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerRight,
            children: [
              // Cartes en éventail derrière l'avatar (orienté vers la gauche)
              ...List.generate(getPlayerCardCount(player['name']), (index) {
                final cardCount = getPlayerCardCount(player['name']);
                final angle = cardCount > 0
                    ? (index - (cardCount - 1) / 2) * 0.12
                    : 0.0;
                final radius = 35.0;
                final centerX = 60.0;
                final centerY = 50.0;
                final cardX = centerX - radius * math.cos(angle) - 17.5;
                final cardY = centerY + radius * math.sin(angle) - 25;
                return Positioned(
                  left: cardX,
                  top: cardY,
                  child: Transform.rotate(
                    angle: -angle,
                    child: cardManager.buildCardBack(width: 40, height: 55),
                  ),
                );
              }),
              // Avatar circulaire au centre
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Text(player['avatar'], style: const TextStyle(fontSize: 24)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Compteurs dynamiques sous l'avatar
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                getPlayerAnnouncementDisplay(player['name']),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.diamond, color: Colors.blue, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    getPlayerGlobalScore(player['name']).toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildPlayerTopWidget(Map<String, dynamic> player) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Conteneur pour le nom
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF8B4513),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.yellow,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text(
                    '♠',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                player['name'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        // Stack avec cartes en éventail et avatar
        SizedBox(
          width: 60,
          height: 100,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Cartes en éventail derrière l'avatar
              ...List.generate(getPlayerCardCount(player['name']), (index) {
                final cardCount = getPlayerCardCount(player['name']);
                final angle = cardCount > 0
                    ? (index - (cardCount - 1) / 2) * 0.12
                    : 0.0;
                final radius = 35.0;
                final centerX = 30.0;
                final centerY = 50.0;
                final cardX = centerX - radius * math.sin(angle) - 17.5;
                final cardY = centerY + radius * math.cos(angle) - 25;
                return Positioned(
                  left: cardX,
                  top: cardY,
                  child: Transform.rotate(
                    angle: angle,
                    child: cardManager.buildCardBack(width: 30, height: 42),
                  ),
                );
              }),
              // Avatar circulaire au centre
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Text(player['avatar'], style: const TextStyle(fontSize: 24)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        // Conteneur pour le compteur d'annonce
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF8B4513),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            getPlayerAnnouncementDisplay(player['name']),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Conteneur pour le compteur de score avec diamant
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF8B4513),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.diamond, color: Colors.blue, size: 16),
              const SizedBox(width: 4),
              Text(
                getPlayerGlobalScore(player['name']).toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildCenterTrick() {
    // ✅ Ne pas afficher les cartes pendant la phase d'annonces
    if (cardManager.isAnnouncementPhase) return const SizedBox.shrink();
    
    final currentTrick = cardManager.currentTrick;
    if (currentTrick.isEmpty) return const SizedBox.shrink();

    return Positioned.fill(
      child: Center(
        child: SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: currentTrick.asMap().entries.map((entry) {
              final index = entry.key;
              final play = entry.value;
              try {
                final playerName = play['player'] as String? ?? '';
                final card = play['card'] as Map<String, dynamic>? ?? {};
                final pos = getDisplayPositionForPlayerName(playerName);
                final winnerPos = isCollectingTrick && lastTrickWinner != null
                    ? getDisplayPositionForPlayerName(lastTrickWinner!)
                    : null;
                return buildCardAtPosition(card, pos, index, winnerPos);
              } catch (_) {
                return const SizedBox.shrink();
              }
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget buildCardAtPosition(
    Map<String, dynamic> card,
    String position,
    int index,
    String? collectingTowardsPosition,
  ) {
    double rotation = 0;
    double offsetX = 0, offsetY = 0;
    bool shouldRotateCard = false;
    double indexOffset = (index % 4) * 3;

    switch (position) {
      case 'top':
        offsetY = -60 - indexOffset;
        offsetX = indexOffset;
        rotation = -0.1 + (index * 0.02);
        break;
      case 'bottom':
        offsetY = 60 + indexOffset;
        offsetX = -indexOffset;
        rotation = 0.1 - (index * 0.02);
        break;
      case 'left':
        offsetX = -60 - indexOffset;
        offsetY = -indexOffset;
        rotation = -0.2 + (index * 0.03);
        shouldRotateCard = true;
        break;
      case 'right':
        offsetX = 60 + indexOffset;
        offsetY = indexOffset;
        rotation = 0.2 - (index * 0.03);
        shouldRotateCard = true;
        break;
    }

    double collectDx = 0, collectDy = 0;
    if (collectingTowardsPosition != null) {
      switch (collectingTowardsPosition) {
        case 'top':
          collectDy = -200;
          break;
        case 'bottom':
          collectDy = 200;
          break;
        case 'left':
          collectDx = -200;
          break;
        case 'right':
          collectDx = 200;
          break;
      }
    }

    return Positioned(
      left: 110 + offsetX - 28,
      top: 110 + offsetY - 40,
      child: TweenAnimationBuilder<Offset>(
        tween: Tween<Offset>(
          begin: const Offset(0, 0),
          end: isCollectingTrick
              ? Offset(collectDx, collectDy)
              : const Offset(0, 0),
        ),
        duration: const Duration(milliseconds: 500),
        builder: (context, value, child) {
          return Transform.translate(
            offset: value,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: isCollectingTrick ? 0.0 : 1.0,
              child: Transform.scale(
                scale: 0.95 - (index * 0.01),
                child: Transform.rotate(
                  angle: rotation,
                  child: buildPlayedCard(card, rotate: shouldRotateCard),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildPlayedCard(Map<String, dynamic> card, {bool rotate = false}) {
    final imagePath = cardManager.getCardImagePath(card);
    final content = Container(
      width: 56,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black.withOpacity(0.2), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(imagePath, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
        return Container(
          color: Colors.white,
          child: Center(child: Text(card['code'] ?? '??', style: const TextStyle(fontWeight: FontWeight.bold))),
        );
      }),
    );

    if (rotate) {
      return Transform.rotate(angle: math.pi / 2, child: content);
    }
    return content;
  }

  Widget buildAnimatedCard() {
    if (animatedCard == null || cardAnimation == null || animatingPlayerName == null) {
      return const SizedBox.shrink();
    }

    final playerPosition = getDisplayPositionForPlayerName(animatingPlayerName!);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    double startX = screenWidth / 2;
    double startY = screenHeight / 2;

    switch (playerPosition) {
      case 'bottom':
        startY = screenHeight - 150;
        startX = screenWidth / 2;
        break;
      case 'right':
        startX = screenWidth - 100;
        startY = screenHeight / 2;
        break;
      case 'top':
        startY = 150;
        startX = screenWidth / 2;
        break;
      case 'left':
        startX = 100;
        startY = screenHeight / 2;
        break;
    }

    final centerX = screenWidth / 2;
    final centerY = screenHeight / 2;

    return AnimatedBuilder(
      animation: cardAnimation!,
      builder: (context, child) {
        final currentY = startY + (centerY - startY) * cardAnimation!.value;
        final currentX = startX + (centerX - startX) * cardAnimation!.value;
        final scale = 1.0 + (cardAnimation!.value * 0.3);
        final rotation = (cardAnimation!.value * 0.1);

        return Positioned(
          left: currentX - 30,
          top: currentY - 42,
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: rotation,
              child: Container(
                width: 60,
                height: 85,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    cardManager.getCardImagePath(animatedCard!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildGameControls() {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 20,
          child: _buildControlButton(
            icon: Icons.list,
            onTap: () => _showGameMenu(),
          ),
        ),
        Positioned(
          top: 0,
          right: 20,
          child: _buildControlButton(
            icon: Icons.exit_to_app,
            onTap: () => showLeaveGameConfirmation(),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF8B4513).withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildRoomInfo() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Positioned(
      top: isSmallScreen ? 60 : 0,
      left: isSmallScreen ? 20 : 80,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: isSmallScreen ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Text(
              widget.roomName,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              'Code: ${widget.roomCode}',
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
            Text(
              'Mise: ${widget.minimumBet} cauris',
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTurnMessage() {
    return const SizedBox.shrink();
  }

  Widget buildAnnouncementNotification() {
    // ✅ Supprimé : Les compteurs de plis indiquent déjà qui a annoncé
    // Pas besoin d'afficher un message supplémentaire
    return const SizedBox.shrink();
  }

  Widget buildAnnouncementPanel() {
    final isAnnouncementPhase = cardManager.isAnnouncementPhase;
    if (!isAnnouncementPhase) return const SizedBox.shrink();

    final currentAnnouncingPlayer = cardManager.getCurrentAnnouncingPlayer();
    final announcements = cardManager.getCurrentRoundAnnouncements();
    final hasCurrentPlayerAnnounced = announcements.any(
      (ann) => ann['player'] == currentAnnouncingPlayer,
    );

    if (hasCurrentPlayerAnnounced && currentAnnouncingPlayer.isNotEmpty) {
      if (!isProcessingAnnouncementTurn) {
        isProcessingAnnouncementTurn = true;
        Future.delayed(const Duration(milliseconds: 100), () {
          isProcessingAnnouncementTurn = false;
          if (mounted && cardManager.isAnnouncementPhase) {
            handleAnnouncementTurnComplete();
          }
        });
      }
      return const SizedBox.shrink();
    }

    final isCurrentPlayerTurn = currentAnnouncingPlayer == widget.currentPlayerName;
    if (!isCurrentPlayerTurn || hasAnnounced) {
      return const SizedBox.shrink();
    }

    return _buildCurrentPlayerAnnouncementPanel();
  }

  Widget _buildCurrentPlayerAnnouncementPanel() {
    if (!cardManager.isAnnouncementPhase) return const SizedBox.shrink();

    return Positioned(
      bottom: 120,
      left: 20,
      right: 20,
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5E6D3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF8B4513), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Combien de plis gagnerez-vous ?',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: announcementCountdown <= 10 ? Colors.red : Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$announcementCountdown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!hasAnnounced) ...[
                // Slider avec labels de nombres visibles
                Column(
                  children: [
                    // Labels des nombres au-dessus du slider
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(12, (index) {
                          final value = index + 2; // 2 à 13
                          final isSelected = value == currentAnnouncement;
                          return Expanded(
                            child: Center(
                              child: Text(
                                value.toString(),
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFF8B4513) : Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF8B4513),
                        inactiveTrackColor: Colors.grey.shade300,
                        thumbColor: const Color(0xFF8B4513),
                        overlayColor: const Color(0xFF8B4513).withOpacity(0.2),
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                      ),
                      child: Slider(
                        value: currentAnnouncement.toDouble(),
                        min: 2,
                        max: 13,
                        divisions: 11,
                        label: currentAnnouncement.toString(),
                        onChanged: (value) {
                          setState(() {
                            currentAnnouncement = value.toInt();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Contrôles : - | Nombre | + | Valider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Bouton -
                    Material(
                      color: const Color(0xFF8B4513),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () {
                          if (currentAnnouncement > 2) {
                            setState(() {
                              currentAnnouncement--;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B4513),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: const Icon(Icons.remove, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                    // Affichage du nombre central
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF8B4513), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          currentAnnouncement.toString(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Bouton +
                    Material(
                      color: const Color(0xFF8B4513),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () {
                          if (currentAnnouncement < 13) {
                            setState(() {
                              currentAnnouncement++;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B4513),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                    // Bouton Valider (checkmark vert)
                    Material(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(25),
                      child: InkWell(
                        onTap: () {
                          makeAnnouncementWithTimer(currentAnnouncement);
                        },
                        borderRadius: BorderRadius.circular(25),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Text(
                    'Annonce faite: ${_getPlayerAnnouncement()}/X',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  int _getPlayerAnnouncement() {
    final announcements = cardManager.getCurrentRoundAnnouncements();
    final playerAnnouncement = announcements.firstWhere(
      (ann) => ann['player'] == widget.currentPlayerName,
      orElse: () => <String, dynamic>{'announcement': 0},
    );
    return playerAnnouncement['announcement'] as int;
  }

  void _playCard(Map<String, dynamic> card) {
    if (cardManager.currentPlayerTurn != widget.currentPlayerName) return;
    if (cardManager.isAnnouncementPhase) return;
    if (currentPlayerPlaying == widget.currentPlayerName) return;

    final playerCards = cardManager.getPlayerCards(widget.currentPlayerName);
    
    // ✅ Synchroniser le pli actuel avec GameLogic pour déterminer correctement les cartes jouables
    gameLogic.syncCurrentTrick(cardManager.currentTrick);
    
    final playable = gameLogic.getPlayableCards(
      playerCards,
      widget.currentPlayerName,
      gameLogic.currentTrick.isEmpty,
    );
    if (!playable.contains(card)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cette carte n\'est pas jouable.'),
          duration: Duration(milliseconds: 800),
        ),
      );
      return;
    }

    currentPlayerPlaying = widget.currentPlayerName;
    print('🎴 ${widget.currentPlayerName} commence à jouer la carte ${card['code']}');
    startCardAnimation(card, widget.currentPlayerName, () {
      try {
        final result = gameLogic.playCard(card, widget.currentPlayerName, playerCards);
        if (result['success'] == true) {
          cardManager.playCard(widget.currentPlayerName, card);
          currentPlayerPlaying = null;

          if (result['trickComplete'] == true) {
            final winner = result['winner'] as String? ?? '';
            print('🕒 Pli complété (joueur humain) - animation et nettoyage du trick (winner: $winner)');
            // ✅ Afficher d'abord les 4 cartes puis animer la collecte
            if (mounted) {
              setState(() {
                lastTrickWinner = winner;
                isCollectingTrick = false;
              });
            }
            Future.delayed(const Duration(milliseconds: 250), () {
              if (!mounted) return;
              setState(() {
                isCollectingTrick = true;
              });
            });
            // ✅ Après l'animation, vider le trick et passer au suivant
            Future.delayed(const Duration(milliseconds: 1200), () {
              if (!mounted || !shouldAllowAutoPlay()) {
                if (mounted &&
                    (cardManager.isRoundEnding || cardManager.allCardsPlayed())) {
                  tryCompleteRoundIfFinished();
                }
                return;
              }
              _resumePlayAfterTrick(winner);
            });
          } else {
            if (mounted) setState(() {});
            scheduleMaybeAutoPlayCurrentBot();
          }
        } else {
          print('❌ Échec du jeu de carte pour ${widget.currentPlayerName}: ${result['error']}');
          currentPlayerPlaying = null;
        }
      } catch (e, stackTrace) {
        print('❌ Erreur lors du jeu de carte pour ${widget.currentPlayerName}: $e');
        print('Stack trace: $stackTrace');
        currentPlayerPlaying = null;
      }
    });
  }

  @override
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
        if (mounted) {
          setState(() {
            isAnimatingCard = false;
            animatedCard = null;
            animatingPlayerName = null;
          });
        }
        onComplete();
      });
    });
  }

  void _resumePlayAfterTrick(String winner) {
    gameLogic.nextTrick();
    cardManager.clearCurrentTrick();
    if (cardManager.isRoundEnding || cardManager.allCardsPlayed()) {
      tryCompleteRoundIfFinished();
      return;
    }
    cardManager.advanceToNextPlayerWithCards(preferredStart: winner);
    if (mounted) {
      setState(() {
        isCollectingTrick = false;
        lastTrickWinner = null;
      });
    }
    scheduleMaybeAutoPlayCurrentBot();
  }

  @override
  void maybeAutoPlayCurrentBot() {
    if (!mounted || cardManager.isAnnouncementPhase) {
      print('⚠️ maybeAutoPlayCurrentBot: widget non monté ou phase d\'annonces');
      return;
    }

    if (cardManager.isRoundEnding || cardManager.allCardsPlayed()) {
      tryCompleteRoundIfFinished();
      return;
    }

    if (isProcessingRoundCompletion) {
      return;
    }

    // ✅ Vérifier qu'aucun joueur n'est déjà en train de jouer
    if (currentPlayerPlaying != null) {
      print('⚠️ maybeAutoPlayCurrentBot: $currentPlayerPlaying est déjà en train de jouer - ignoré');
      return;
    }

    final current = cardManager.currentPlayerTurn;
    if (current.isEmpty) {
      print('⚠️ maybeAutoPlayCurrentBot: currentPlayerTurn est vide');
      return;
    }
    
    if (currentPlayerPlaying == current) {
      print('⚠️ maybeAutoPlayCurrentBot: $current est déjà en train de jouer (doublon)');
      return;
    }

    if (current == widget.currentPlayerName) {
      print('👤 maybeAutoPlayCurrentBot: c\'est le tour du joueur humain $current');
      return;
    }

    final botCards = cardManager.getPlayerCards(current);
    if (botCards.isEmpty) {
      print('⏭️ maybeAutoPlayCurrentBot: $current n\'a plus de cartes — joueur suivant');
      final advanced = cardManager.advanceToNextPlayerWithCards();
      if (advanced && shouldAllowAutoPlay()) {
        maybeAutoPlayCurrentBot();
      } else if (!advanced) {
        tryCompleteRoundIfFinished();
      }
      return;
    }

    // ✅ Synchroniser le pli actuel avec GameLogic pour déterminer correctement les cartes jouables
    gameLogic.syncCurrentTrick(cardManager.currentTrick);

    final playable = gameLogic.getPlayableCards(
      botCards,
      current,
      gameLogic.currentTrick.isEmpty,
    );
    final cardToPlay = playable.isEmpty ? botCards.first : playable.first;

    print('🤖 maybeAutoPlayCurrentBot: $current va jouer ${cardToPlay['code']}');

    // ✅ Ajouter un petit délai avant de jouer pour que l'utilisateur voie que c'est le tour du bot
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || cardManager.isAnnouncementPhase) {
        print('⚠️ maybeAutoPlayCurrentBot (delayed): widget non monté ou phase d\'annonces');
        currentPlayerPlaying = null;
        return;
      }
      
      // Vérifier à nouveau que c'est toujours le tour de ce bot
      if (cardManager.currentPlayerTurn != current) {
        print('⚠️ maybeAutoPlayCurrentBot (delayed): le tour a changé (était $current, maintenant ${cardManager.currentPlayerTurn})');
        currentPlayerPlaying = null;
        return;
      }

      currentPlayerPlaying = current;
      startCardAnimation(cardToPlay, current, () {
        if (!mounted || cardManager.isAnnouncementPhase) {
          print('⚠️ maybeAutoPlayCurrentBot (animation complete): widget non monté ou phase d\'annonces');
          currentPlayerPlaying = null;
          return;
        }
        
        try {
          final res = gameLogic.playCard(cardToPlay, current, botCards);
          if (res['success'] == true) {
            cardManager.playCard(current, cardToPlay);
            currentPlayerPlaying = null;

          if (res['trickComplete'] == true) {
            final winner = res['winner'] as String? ?? '';
            print('🕒 Pli complété (bot automatique) - animation et nettoyage du trick (winner: $winner)');
            // ✅ Afficher d'abord les 4 cartes puis animer la collecte
            if (mounted) {
              setState(() {
                lastTrickWinner = winner;
                isCollectingTrick = false;
              });
            }
            Future.delayed(const Duration(milliseconds: 250), () {
              if (!mounted) return;
              setState(() {
                isCollectingTrick = true;
              });
            });
            // ✅ Après l'animation, vider le trick et passer au suivant
            Future.delayed(const Duration(milliseconds: 1200), () {
              if (!mounted || !shouldAllowAutoPlay()) {
                if (mounted &&
                    (cardManager.isRoundEnding || cardManager.allCardsPlayed())) {
                  tryCompleteRoundIfFinished();
                }
                return;
              }
              _resumePlayAfterTrick(winner);
            });
          } else {
              if (mounted) setState(() {});
              scheduleMaybeAutoPlayCurrentBot();
            }
          } else {
            print('❌ Échec du jeu de carte pour $current: ${res['error']}');
            currentPlayerPlaying = null;
            // ✅ Réessayer après un court délai si le jeu a échoué
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted &&
                  cardManager.currentPlayerTurn == current &&
                  shouldAllowAutoPlay()) {
                maybeAutoPlayCurrentBot();
              }
            });
          }
        } catch (e, stackTrace) {
          print('❌ Erreur lors du jeu de carte pour $current: $e');
          print('Stack trace: $stackTrace');
          currentPlayerPlaying = null;
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted &&
                cardManager.currentPlayerTurn == current &&
                shouldAllowAutoPlay()) {
              maybeAutoPlayCurrentBot();
            }
          });
        }
      });
    });
  }

  void makeAnnouncementWithTimer(int announcement) {
    forceAnnouncementForPlayer(widget.currentPlayerName, announcement);
    if (mounted) setState(() {});
    handleAnnouncementTurnComplete();
  }

  void forceAnnouncementForPlayer(String playerName, int announcement) {
    announcementTimer?.cancel();
    final int clampedAnnouncement = announcement.clamp(2, 13).toInt();
    if (playerName == widget.currentPlayerName) {
      cardManager.makeAnnouncement(playerName, clampedAnnouncement);
      if (mounted) {
        setState(() {
          hasAnnounced = true;
          currentAnnouncement = clampedAnnouncement;
        });
      }
    } else {
      cardManager.forceAnnouncement(playerName, clampedAnnouncement);
    }
    currentAnnouncementPlayer = null;
  }

  @override
  Future<void> startAnnouncementTimerForCurrentPlayer() async {
    final playerName = cardManager.getCurrentAnnouncingPlayer();
    if (playerName.isEmpty) return;
    final isLocalPlayer = playerName == widget.currentPlayerName;
    startAnnouncementTimer(playerName: playerName, isLocalPlayer: isLocalPlayer);
  }

  @override
  void startAnnouncementTimer({
    required String playerName,
    required bool isLocalPlayer,
  }) {
    announcementTimer?.cancel();
    currentAnnouncementPlayer = playerName;
    announcementCountdown = 30;
    if (isLocalPlayer) {
      hasAnnounced = false;
    }

    announcementTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (announcementCountdown > 0) {
          announcementCountdown--;
        }
      });

      if (announcementCountdown <= 0) {
        timer.cancel();
        handleAnnouncementTimeout();
      }
    });
  }

  void handleAnnouncementTimeout() {
    final playerName = currentAnnouncementPlayer;
    if (playerName == null || playerName.isEmpty) return;

    final announcements = cardManager.getCurrentRoundAnnouncements();
    final alreadyAnnounced = announcements.any((ann) => ann['player'] == playerName);
    if (alreadyAnnounced) {
      handleAnnouncementTurnComplete();
      return;
    }

    forceAnnouncementForPlayer(playerName, 2);
    handleAnnouncementTurnComplete();
  }

  @override
  Future<void> onRoundCompleted() async {
    if (isProcessingRoundCompletion) return;
    isProcessingRoundCompletion = true;

    try {
      final players = gameSession.players
          .map((p) => p['name'] as String? ?? 'Joueur')
          .toList();

      final announcements = cardManager.getCurrentRoundAnnouncements();
      final Map<String, int> announcedByPlayer = {
        for (final p in players)
          p: (announcements.firstWhere(
                (a) => a['player'] == p,
                orElse: () => {'announcement': 0},
              )['announcement']
              as int? ??
              0),
      };

      final Map<String, int> obtainedByPlayer = {
        for (final p in players) p: cardManager.getObtainedTricks(p),
      };

      final Map<String, int> scores = {};
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

      final obtainedList = players
          .map((p) => obtainedByPlayer[p] ?? 0)
          .toList();
      
      // ✅ CORRECTION: Trouver l'index du round actuel dans roundsData
      // currentRound peut être différent de l'index dans roundsData
      final currentRoundNumber = gameSession.currentRound;
      final roundIndex = gameSession.roundsData.indexWhere(
        (r) => (r['roundNumber'] as int?) == currentRoundNumber
      );
      
      // ✅ S'assurer que le round existe dans roundsData avec les bonnes annonces
      if (roundIndex == -1) {
        print('⚠️ Round $currentRoundNumber non trouvé dans roundsData. Création du round avec les annonces...');
        // Créer le round avec les annonces actuelles (sans incrémenter currentRound)
        final announcementsList = players
            .map((p) => announcedByPlayer[p] ?? 0)
            .toList();
        gameSession.addCurrentRound(announcementsList);
        
        // Trouver à nouveau l'index après création
        final newRoundIndex = gameSession.roundsData.indexWhere(
          (r) => (r['roundNumber'] as int?) == currentRoundNumber
        );
        
        if (newRoundIndex != -1) {
          print('✅ Round $currentRoundNumber créé (index: $newRoundIndex) avec annonces: $announcementsList');
          gameSession.finalizeRound(newRoundIndex, obtainedList);
        } else {
          print('❌ Impossible de créer le round $currentRoundNumber');
          // Fallback: utiliser le dernier round
          final fallbackIndex = gameSession.roundsData.length - 1;
          if (fallbackIndex >= 0) {
            // Mettre à jour les annonces du fallback si elles sont manquantes
            final fallbackRound = gameSession.roundsData[fallbackIndex];
            if (fallbackRound['announcements'] == null || 
                (fallbackRound['announcements'] as List).isEmpty) {
              final announcementsList = players
                  .map((p) => announcedByPlayer[p] ?? 0)
                  .toList();
              fallbackRound['announcements'] = announcementsList;
              print('⚠️ Mise à jour des annonces du round fallback: $announcementsList');
            }
            gameSession.finalizeRound(fallbackIndex, obtainedList);
          }
        }
      } else {
        // ✅ Vérifier que le round a bien les annonces, sinon les mettre à jour
        final round = gameSession.roundsData[roundIndex];
        if (round['announcements'] == null || 
            (round['announcements'] as List).isEmpty) {
          final announcementsList = players
              .map((p) => announcedByPlayer[p] ?? 0)
              .toList();
          round['announcements'] = announcementsList;
          print('⚠️ Mise à jour des annonces du round $currentRoundNumber: $announcementsList');
        }
        print('✅ Finalisation du round $currentRoundNumber (index: $roundIndex)');
        gameSession.finalizeRound(roundIndex, obtainedList);
      }

      if (mounted) {
        setState(() {});
      }

      try {
        final roomId = gameSession.roomId ?? '';
        if (roomId.isNotEmpty) {
          await GameApiService.instance.saveRound(
            roomId: roomId,
            roundNumber: gameSession.currentRound,
            announcements: announcements.cast<Map<String, dynamic>>(),
            obtainedTricks: obtainedByPlayer,
          );
        }
      } catch (_) {}

      // ✅ Afficher le tableau de scores et attendre sa fermeture avant de continuer
      print('📊 Affichage du tableau de scores (autoClose: true)...');
      showScoreboardDialog(
        players,
        announcedByPlayer,
        obtainedByPlayer,
        scores,
        autoClose: true, // ✅ Fermeture automatique à la fin d'une manche
      ).then((_) {
        // ✅ Attendre que le dialog se ferme avant de continuer
        print('✅ Tableau de scores fermé, vérification de la suite...');
        
        // Vérifier si la partie est terminée
        final winnerIndex = gameSession.globalScores.indexWhere((s) => s >= 150);
        final completedRounds = gameSession.roundsData
            .where((r) => (r['isCompleted'] as bool?) == true)
            .length;
        final isGameOver = winnerIndex != -1 || completedRounds >= 10;

        print('🔍 Fin de round - Vérification fin de partie:');
        print('   - WinnerIndex (≥150): $winnerIndex');
        print('   - Rounds complétés: $completedRounds / ${gameSession.roundsData.length}');
        print('   - CurrentRound: ${gameSession.currentRound}');
        print('   - IsGameOver: $isGameOver');

        if (isGameOver) {
          String winnerName;
          if (winnerIndex != -1) {
            final entries = gameSession.globalScores.asMap().entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final top1 = entries.first;
            final winnerIdx = top1.key;
            winnerName = gameSession.players[winnerIdx]['name'] as String? ?? 'Joueur';
          } else {
            final entries = gameSession.globalScores.asMap().entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final winnerIdx = entries.first.key;
            winnerName = gameSession.players[winnerIdx]['name'] as String? ?? 'Joueur';
          }
          print('🎯 Partie terminée, gagnant: $winnerName');
          handleGameWinner(winnerName);
        } else {
          print('🔄 Démarrage d\'une nouvelle manche...');
          Future.delayed(const Duration(milliseconds: 500), () async {
            if (mounted) {
              await startNewRound();
            }
          });
        }
      });
    } catch (e) {
      print('❌ Erreur calcul score: $e');
      isProcessingRoundCompletion = false;
    }
  }

  @override
  Future<void> startNewRound() async {
    try {
      final playerNames = gameSession.players
          .map((p) => p['name'] as String? ?? 'Joueur')
          .toList();

      if (playerNames.isEmpty) {
        print('⚠️ startNewRound: aucun joueur');
        return;
      }

      // Passer à la manche suivante (1 → 2 → 3…)
      gameSession.currentRound++;
      final roundNumber = gameSession.currentRound;

      isProcessingAnnouncementCompletion = false;
      isProcessingAnnouncementTurn = false;
      isProcessingRoundCompletion = false;
      cardManager.resetRoundCounters();
      cardManager.clearCurrentTrick();
      cardManager.isAnnouncementPhase = true;

      final dealResult = cardManager.shuffleAndDealCards(playerNames);
      if (dealResult['success'] != true) {
        print('❌ startNewRound: échec distribution locale');
        return;
      }

      gameLogic.configurePlayers(
        playerCount: playerNames.length,
        cardsPerPlayer: cardManager.cardsPerPlayer,
      );

      String firstPlayer = playerNames.first;
      final creator = gameSession.players.firstWhere(
        (p) => (p['isCreator'] as bool?) == true,
        orElse: () => gameSession.players.first,
      );
      if ((creator['name'] as String?) != null) {
        firstPlayer = creator['name'] as String;
      }
      cardManager.currentPlayerTurn = firstPlayer;

      // ✅ Mettre à jour l'UI IMMÉDIATEMENT pour la nouvelle donne !
      if (mounted) setState(() {});

      // ✅ Synchroniser la distribution avec le backend avant de continuer
      final roomId = gameSession.roomId ?? '';
      if (roomId.isNotEmpty) {
        try {
          await GameApiService.instance.distributeCards(
            roomId: roomId,
            roundNumber: roundNumber,
          );
          print('✅ Round $roundNumber: cartes distribuées via backend');
        } catch (e) {
          print('⚠️ Round $roundNumber: distributeCards backend — $e');
        }

        try {
          final orderedCodes = <String>[];
          for (final name in playerNames) {
            for (final c in cardManager.getPlayerCards(name)) {
              orderedCodes.add((c['code'] as String?) ?? '');
            }
          }
          final hash = crypto.sha256.convert(utf8.encode(orderedCodes.join('-'))).toString();
          await GameApiService.instance.startRound(
            roomId: roomId,
            roundNumber: roundNumber,
            deckHash: hash,
          );
        } catch (e) {
          print('⚠️ Round $roundNumber: startRound backend — $e');
        }
      }

      // Annonces automatiques des bots (identique au premier round)
      for (final botName in playerNames) {
        if (botName == widget.currentPlayerName) continue;
        final computed = cardManager.getBotAnnouncement(botName);
        cardManager.forceAnnouncement(botName, computed);
        try {
          final gameId = await getGameId();
          if (gameId != null) {
            await GameApiService.instance.makeAnnouncement(
              gameId: gameId,
              roundNumber: roundNumber,
              announcementValue: computed,
              playerName: botName,
            );
          }
        } catch (e) {
          print('⚠️ Annonce bot $botName (round $roundNumber) backend — $e');
        }
      }

      if (firstPlayer == widget.currentPlayerName) {
        startAnnouncementTimerForCurrentPlayer();
      } else {
        handleAnnouncementTurnComplete();
      }
    } catch (e) {
      print('❌ Erreur démarrage nouvelle manche: $e');
    }
  }

  @override
  void handleGameWinner(String winnerName) {
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
              const Text(
                'Partie terminée avec succès !',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
        _showContinueGameDialog();
      }
    });
  }

  void _showContinueGameDialog() {
    continueGameChoice = null;
    continueCountdown = 5;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (continueCountdownTimer == null || !continueCountdownTimer!.isActive) {
              continueCountdownTimer?.cancel();
              continueCountdownTimer = Timer.periodic(
                const Duration(seconds: 1),
                (timer) {
                  if (continueCountdown > 0) {
                    continueCountdown--;
                    if (mounted) {
                      setDialogState(() {});
                    }
                  } else {
                    timer.cancel();
                    if (continueGameChoice == null) {
                      continueGameChoice = true;
                      Navigator.of(context).pop();
                      _handleContinueGame(true);
                    }
                  }
                },
              );
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF2E2B23),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Nouvelle partie ?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Une autre partie va commencer',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'dans $continueCountdown seconde${continueCountdown > 1 ? "s" : ""}',
                    style: TextStyle(
                      color: Colors.yellow,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Voulez-vous continuer ?',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    continueGameChoice = false;
                    continueCountdownTimer?.cancel();
                    Navigator.of(context).pop();
                    _handleContinueGame(false);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.3),
                  ),
                  child: const Text(
                    'Non',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    continueGameChoice = true;
                    continueCountdownTimer?.cancel();
                    Navigator.of(context).pop();
                    _handleContinueGame(true);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.3),
                  ),
                  child: const Text(
                    'Oui',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleContinueGame(bool wantsToContinue) async {
    if (!wantsToContinue) {
      await navigateToUserDashboard();
      return;
    }

    try {
      final playerNames = gameSession.players
          .map((p) => p['name'] as String? ?? 'Joueur')
          .toList();

      if (mounted) {
        setState(() {
          gameSession.globalScores = List.filled(
            gameSession.players.length,
            0.0,
          );
          gameSession.roundsData = [];
          gameSession.currentRound = 0;
          gameSession.isGameActive = true;
          gameSession.isGameCompleted = false;
          gameSession.winnerName = null;
          gameSession.winnerScore = null;
        });

        // ✅ Réinitialiser complètement pour une nouvelle partie
        cardManager.resetRoundCounters();
        cardManager.clearCurrentTrick();
        cardManager.isAnnouncementPhase = false;
        
        // ✅ Redistribuer les cartes pour une nouvelle partie
        final result = cardManager.shuffleAndDealCards(playerNames);
        if (result['success'] != true) {
          print('❌ Erreur lors de la redistribution des cartes');
          return;
        }
        
        // ✅ Reconfigurer le jeu
        gameLogic.configurePlayers(
          playerCount: playerNames.length,
          cardsPerPlayer: cardManager.cardsPerPlayer,
        );
        
        // ✅ Remettre en phase d'annonces
        cardManager.isAnnouncementPhase = true;

        // ✅ Déterminer le premier joueur (créateur ou premier de la liste)
        String firstPlayer = playerNames.first;
        final creator = gameSession.players.firstWhere(
          (p) => (p['isCreator'] as bool?) == true,
          orElse: () => gameSession.players.first,
        );
        if ((creator['name'] as String?) != null) {
          firstPlayer = creator['name'] as String;
        }
        cardManager.currentPlayerTurn = firstPlayer;

        // ✅ Démarrer les annonces
        if (mounted) {
          setState(() {
            hasGameStarted = true;
          });
          
          if (firstPlayer != widget.currentPlayerName) {
            // Si c'est un bot qui commence, faire son annonce automatiquement
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                handleAnnouncementTurnComplete();
              }
            });
          } else {
            // Si c'est le joueur humain, démarrer le timer d'annonce
            startAnnouncementTimerForCurrentPlayer();
          }
        }
      }
    } catch (e) {
      print('❌ Erreur: $e');
    }
  }

  @override
  Future<void> showScoreboardDialog(
    List<String> players,
    Map<String, int> announced,
    Map<String, int> obtained,
    Map<String, int> scores, {
    bool autoClose = false, // ✅ Par défaut, ne pas fermer automatiquement
  }) async {
    Timer? autoCloseTimer;
    late BuildContext dialogContext;

    // On garde une référence sur le Future du dialog pour pouvoir
    // à la fois lancer un timer d'auto-fermeture et attendre la fermeture.
    final dialogFuture = showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) {
        // ✅ Capturer le context du dialog (important pour le fermer proprement)
        dialogContext = ctx;

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
            height: MediaQuery.of(context).size.height * 0.6,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
                Navigator.of(ctx).pop();
              },
              child: const Text(
                'Fermer',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    // ⏰ Si autoClose est demandé (fin de manche), on démarre le timer
    // APRES le rendu du dialog (prochain frame), pour éviter les cas où
    // le timer se déclenche avant que le dialog ne soit visible.
    if (autoClose) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        autoCloseTimer = Timer(const Duration(seconds: 5), () {
          try {
            if (mounted && Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
          } catch (_) {
            // Dialog déjà fermé / context invalide
          }
        });
      });
    }

    await dialogFuture.then((_) {
      // ✅ Nettoyer le timer quand le dialog se ferme
      autoCloseTimer?.cancel();
    });
  }

  @override
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

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  void _showGameMenu() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Tableau de Score',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[600]!, width: 1),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[700],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Rondes',
                                  style: TextStyle(
                                    color: Colors.yellow,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                              ...gameSession.players.map((player) {
                                return Expanded(
                                  flex: 1,
                                  child: Text(
                                    player['name'],
                                    style: TextStyle(
                                      color: Colors.yellow,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }).toList(),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Somme',
                                  style: TextStyle(
                                    color: Colors.yellow,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...gameSession.roundsData.map((round) {
                          final roundLabel = 'R${round['roundNumber']}';
                          final announcements = round['announcements'] as List<int>;
                          final results = round['results'] as List<dynamic>;
                          final isCompleted = round['isCompleted'] as bool;
                          final displayData = isCompleted ? results : announcements;
                          final scoreStrings = displayData.map((score) {
                            if (score == null) return '—';
                            return score.toString();
                          }).toList();
                          final sum = displayData
                              .where((score) => score != null)
                              .fold<double>(0.0, (sum, score) {
                                if (score is double) return sum + score;
                                if (score is int) return sum + score.toDouble();
                                return sum;
                              });
                          scoreStrings.add(sum.toString());

                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey[600]!, width: 1)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    roundLabel,
                                    style: TextStyle(
                                      color: Colors.yellow,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                                ...scoreStrings.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final score = entry.value;
                                  Color textColor = Colors.white;
                                  if (index < gameSession.players.length) {
                                    final player = gameSession.players[index];
                                    final isCurrentPlayer = player['isCurrentPlayer'] as bool;
                                    textColor = isCurrentPlayer ? Colors.yellow : Colors.white;
                                  }
                                  return Expanded(
                                    flex: 1,
                                    child: Text(
                                      score,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          );
                        }).toList(),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey[600]!, width: 1)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Score global (SG)',
                                  style: TextStyle(
                                    color: Colors.yellow,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                              ...gameSession.globalScores.map(
                                (score) => Expanded(
                                  flex: 1,
                                  child: Text(
                                    score.toString(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  gameSession.globalScores
                                      .fold(0.0, (sum, score) => sum + score)
                                      .toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
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
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          gameSession.roomName ?? 'Salon',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Code: ${gameSession.roomCode ?? 'N/A'}',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mise minimum: ${gameSession.minimumBet ?? 50} cauris',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
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
                Navigator.pop(context);
              },
              child: const Text(
                'Fermer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showGameSettings() {
    // Paramètres du jeu
  }

  void showLeaveGameConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2E2B23),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '⚠️ Quitter le jeu',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Si vous quittez le jeu maintenant, un bot vous remplacera automatiquement.',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Annuler',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _confirmLeaveGame();
              },
              child: const Text(
                'Quitter quand même',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmLeaveGame() async {
    try {
      final playerName = widget.currentPlayerName;
      permanentlyExcludedPlayers.add(playerName);
      await _replacePlayerWithBot(playerName, isPermanent: true);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('❌ Erreur: $e');
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _replacePlayerWithBot(String playerName, {bool isPermanent = true}) async {
    try {
      final roomId = gameSession.roomId ?? '';
      if (roomId.isEmpty) return;

      final players = gameSession.players;
      final playerIndex = players.indexWhere(
        (p) => (p['name'] as String?) == playerName,
      );

      if (playerIndex != -1) {
        final botName = 'Bot_Remplaceur_${playerName}';
        final playerCards = cardManager.getPlayerCards(playerName);

        setState(() {
          players[playerIndex] = {
            ...players[playerIndex],
            'name': botName,
            'avatar': '🤖',
            'is_bot': true,
            'isReplacementBot': true,
            'replacedPlayerName': playerName,
          };
        });

        if (playerCards.isNotEmpty) {
          cardManager.transferPlayerCards(playerName, botName);
        }

        final announcements = cardManager.getCurrentRoundAnnouncements();
        final playerAnnouncement = announcements.firstWhere(
          (ann) => (ann['player'] as String?) == playerName,
          orElse: () => <String, Object>{},
        );
        if ((playerAnnouncement['announcement'] as int?) != null) {
          playerAnnouncement['player'] = botName;
        }

        cardManager.transferObtainedTricks(playerName, botName);
        cardManager.updatePlayerNameInCurrentTrick(playerName, botName);

        if (cardManager.currentPlayerTurn == playerName) {
          cardManager.currentPlayerTurn = botName;
        }

        if (cardManager.isAnnouncementPhase && cardManager.currentPlayerTurn == botName) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              final botAnnouncement = cardManager.getBotAnnouncement(botName);
              cardManager.makeAnnouncement(botName, botAnnouncement);
              handleAnnouncementTurnComplete();
            }
          });
        }

        try {
          await GameApiService.instance.replacePlayerWithBot(
            roomId: roomId,
            playerName: playerName,
            botName: botName,
            isPermanent: isPermanent,
          );
        } catch (e) {
          print('⚠️ Erreur notification backend: $e');
        }

        setState(() {});
      }
    } catch (e) {
      print('❌ Erreur: $e');
    }
  }
}