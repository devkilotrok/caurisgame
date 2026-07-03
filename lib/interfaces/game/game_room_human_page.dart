import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import '../../services/api/game_api_service.dart';
import '../../services/user/user_service.dart';
import '../../models/game/local_card_manager.dart';
import '../../services/websocket/game_websocket_service.dart';
import '../../config/game_constants.dart';
import 'game_room_base_page.dart';
import 'game_room_polling_policy.dart';

/// Page de jeu pour le MODE HUMAIN uniquement
class GameRoomHumanPage extends GameRoomBasePage {
  const GameRoomHumanPage({
    super.key,
    required super.roomName,
    required super.roomCode,
    required super.minimumBet,
    super.currentPlayerName,
  });

  @override
  State<GameRoomHumanPage> createState() => _GameRoomHumanPageState();
}

class _GameRoomHumanPageState extends GameRoomBaseState<GameRoomHumanPage> {
  // Timers
  Timer? _announcementTimer;
  Timer? _roomPollTimer;
  Timer? _reconnectionCheckTimer;
  Timer? _stateSyncTimer;
  Timer? _chatPollingTimer;
  Timer? _chatToastTimer;
  Timer? _continueCountdownTimer;
  Timer? _roomCodeCheckTimer;
  Timer? _countersSyncTimer; // ✅ Timer pour synchroniser les compteurs de plis automatiquement
  Timer? _distributionFallbackTimer;
  bool _forceSyncDistribution = false;

  // États bool/int
  int _announcementCountdown = 30;
  bool _hasAnnounced = false;
  String? _currentAnnouncementPlayer;
  int _currentAnnouncement = 2;
  // ✅ NOUVEAU: États pour le système d'annonces simultané
  int? _announcementPhaseStartTimestamp; // Timestamp serveur du début de la phase
  int _announcementPhaseDuration = 30; // Durée en secondes
  Timer? _announcementPhaseTimer; // Timer pour le compte à rebours
  int? _currentGameId; // ✅ game_id reçu dans announcement_phase_started
  int? _announcementPhaseRoundApplied;
  int? _distributionRoundApplied;
  bool _waitingForHumans = false;
  bool _distributionRequestInFlight = false;
  bool _botsFillInFlight = false;
  final Set<String> _wsJoinedPlayerNames = <String>{};
  Map<String, dynamic>? _pendingAnnouncementPhasePayload;
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
  StreamSubscription? _allAnnouncementsCompletedSubscription;
  StreamSubscription? _announcementPhaseStartedSubscription;
  StreamSubscription? _announcementSubmittedSubscription;
  StreamSubscription? _announcementsCompleteSubscription;
  StreamSubscription? _announcementsAdjustedSubscription;
  StreamSubscription? _roomChatMessageSubscription;
  StreamSubscription? _cardPlayedSubscription;
  StreamSubscription? _trickCompletedSubscription;
    StreamSubscription? _roundCompletedSubscription;
  StreamSubscription? _roundScoresUpdatedSubscription;
  StreamSubscription? _playerJoinedSubscription;

  bool _hasFullHttpRoom() {
    return gameSession.players.length >= requiredPlayers;
  }

  bool _localPlayerHasCards() {
    return cardManager.getPlayerCards(widget.currentPlayerName).isNotEmpty;
  }

  Set<String> _expectedHumanPlayerNames() {
    return gameSession.players
        .map((p) => (p['name'] as String?)?.trim() ?? '')
        .where((n) => n.isNotEmpty)
        .toSet();
  }

  bool _hasAllPlayersJoinedWebSocket() {
    if (!_hasFullHttpRoom()) return false;
    final expected = _expectedHumanPlayerNames();
    if (expected.length < requiredPlayers) return false;
    return expected.every(_wsJoinedPlayerNames.contains);
  }

  void _ingestWsPlayerJoinedPayload(dynamic data) {
    if (data is! Map) return;
    final payload = Map<String, dynamic>.from(data);
    final joinedName = payload['playerName']?.toString().trim();
    if (joinedName != null && joinedName.isNotEmpty) {
      _wsJoinedPlayerNames.add(joinedName);
    }
    final players = payload['players'] as List?;
    if (players != null) {
      for (final player in players) {
        if (player is Map && player['name'] != null) {
          final name = player['name'].toString().trim();
          if (name.isNotEmpty) {
            _wsJoinedPlayerNames.add(name);
          }
        }
      }
    }
    print(
      '👥 WS room: ${_wsJoinedPlayerNames.length}/$requiredPlayers '
      '(${_wsJoinedPlayerNames.join(", ")})',
    );

    if (!hasGameStarted &&
        !_distributionRequestInFlight &&
        !_botsFillInFlight &&
        _hasFullHttpRoom() &&
        _hasAllPlayersJoinedWebSocket()) {
      if (_useTestDistribution &&
          gameSession.players.length < GameConstants.standardPlayerCount) {
        print('⏳ Mode test: fillBots requis avant distribution auto');
        return;
      }
      final isCreator = gameSession.players.any(
        (p) =>
            (p['name'] as String?) == widget.currentPlayerName &&
            (p['isCreator'] as bool?) == true,
      );
      if (isCreator) {
        print('👑 Tous les joueurs WS présents — lancement distribution');
        unawaited(_creatorRequestDistributionWhenReady());
      }
    }
  }

  void _maybeApplyPendingAnnouncementPhase() {
    if (_pendingAnnouncementPhasePayload == null || !_localPlayerHasCards()) {
      return;
    }
    final pending = _pendingAnnouncementPhasePayload!;
    _pendingAnnouncementPhasePayload = null;
    print('▶️ Application différée de la phase d\'annonces (cartes reçues)');
    _applyAnnouncementPhaseStartedNow(pending);
  }

  /// Numéro de manche côté serveur (évite currentRound=0 au premier round).
  void _syncRoundNumber(int? roundNumber) {
    if (roundNumber != null && roundNumber > 0) {
      if (gameSession.currentRound != roundNumber) {
        print('✅ currentRound synchronisé: ${gameSession.currentRound} → $roundNumber');
      }
      gameSession.currentRound = roundNumber;
      return;
    }
    if (gameSession.currentRound < 1) {
      gameSession.currentRound = 1;
      print('✅ currentRound initialisé à 1 (première manche)');
    }
  }

  int _effectiveRoundNumber() {
    return gameSession.currentRound > 0 ? gameSession.currentRound : 1;
  }



  Map<String, dynamic>? _parseDistributedCards(dynamic raw) {
    if (raw == null) return null;
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        print('⚠️ distributed_cards JSON invalide: $e');
      }
      return null;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  @override
  Future<void> handleAnnouncementTurnComplete({bool fromBackend = false}) async {
    if (cardManager.getPlayerCards(widget.currentPlayerName).isEmpty) {
      print('⚠️ Pas de cartes — /sync avant passage en phase de jeu');
      await _pullDistributionFromSync();
      if (cardManager.getPlayerCards(widget.currentPlayerName).isEmpty) {
        print('❌ Phase de jeu bloquée: cartes toujours absentes après /sync');
        isProcessingAnnouncementCompletion = false;
        _scheduleDistributionSyncFallback();
        return;
      }
    }
    await super.handleAnnouncementTurnComplete(fromBackend: fromBackend);
  }

  bool _needsDistributionApply(int? roundNumber) {
    if (cardManager.getPlayerCards(widget.currentPlayerName).isEmpty) {
      return true;
    }
    if (roundNumber == null) return false;
    return _distributionRoundApplied != roundNumber;
  }

  void _markDistributionApplied(int? roundNumber) {
    if (roundNumber != null) {
      _distributionRoundApplied = roundNumber;
    }
  }

  Map<String, dynamic> _canonicalizeDistributionKeys(
    Map<String, dynamic> distribution,
  ) {
    final knownNames = gameSession.players
        .map((p) => (p['name'] as String?)?.trim() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    final canonical = <String, dynamic>{};
    for (final entry in distribution.entries) {
      final rawKey = entry.key.toString().trim();
      String resolved = rawKey;
      for (final name in knownNames) {
        if (name.toLowerCase() == rawKey.toLowerCase()) {
          resolved = name;
          break;
        }
      }
      canonical[resolved] = entry.value;
    }
    return canonical;
  }

  bool _validateFullDistribution(Map<String, dynamic> distribution) {
    final allDistributedCards = <String>{};
    var totalCardsDistributed = 0;

    for (final entry in distribution.entries) {
      final cardCodes = (entry.value as List).cast<String>();
      totalCardsDistributed += cardCodes.length;

      if (cardCodes.length != cardCodes.toSet().length) {
        print('❌ Distribution invalide: doublons pour ${entry.key}');
        return false;
      }

      for (final code in cardCodes) {
        if (allDistributedCards.contains(code)) {
          print('❌ Distribution invalide: carte $code en double entre joueurs');
          return false;
        }
        allDistributedCards.add(code);
      }
    }

    if (totalCardsDistributed != 52) {
      print(
        '❌ Distribution invalide: $totalCardsDistributed/52 cartes '
        '(joueurs: ${distribution.keys.toList()})',
      );
      return false;
    }

    return true;
  }

  bool _roomIdsMatch(Object? a, Object? b) {
    if (a == null || b == null) return false;
    return a.toString() == b.toString();
  }

  Timer? _announcementCompletionPollTimer;

  int? _parseRoundNumber(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  void _scheduleAnnouncementCompletionPoll() {
    if (!cardManager.isAnnouncementPhase) return;
    _announcementCompletionPollTimer?.cancel();
    _announcementCompletionPollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        if (!mounted || !cardManager.isAnnouncementPhase) {
          _announcementCompletionPollTimer?.cancel();
          return;
        }
        unawaited(_tryCompleteAnnouncementPhaseFromBackend(
          reason: 'waiting_panel_poll',
        ));
      },
    );
  }

  void _cancelAnnouncementCompletionPoll() {
    _announcementCompletionPollTimer?.cancel();
    _announcementCompletionPollTimer = null;
  }

  bool _announcementCompletionCheckInFlight = false;

  bool _matchesRoundNumber(int? roundNumber) {
    if (roundNumber == null || roundNumber < 1) return false;
    if (gameSession.currentRound < 1) return true;
    return roundNumber == gameSession.currentRound;
  }

  @override
  String getStartingPlayerForRoundPlay(int roundNumber) {
    if (_backendPlayFirstPlayer != null &&
        _backendPlayFirstPlayer!.isNotEmpty &&
        roundNumber == gameSession.currentRound) {
      return _backendPlayFirstPlayer!;
    }
    return super.getStartingPlayerForRoundPlay(roundNumber);
  }

  /// Démarre la phase de jeu quand le backend confirme que toutes les annonces sont faites.
  Future<void> _completeAnnouncementPhaseFromBackend({
    Map<String, dynamic>? announcements,
    String? firstPlayer,
    int? roundNumber,
    bool announcementsAdjusted = false,
    required String source,
  }) async {
    if (!mounted || !cardManager.isAnnouncementPhase) return;
    if (_isProcessingAnnouncementCompletion) {
      print('ℹ️ Fin phase annonces ignorée ($source): déjà en cours');
      return;
    }

    print('✅ Fin phase annonces via $source');

    _announcementPhaseTimer?.cancel();
    _announcementPhaseStartTimestamp = null;

    if (roundNumber != null) {
      _syncRoundNumber(roundNumber);
    }

    var showAdjustmentMessage = announcementsAdjusted;

    if (announcements != null && announcements.isNotEmpty) {
      showAdjustmentMessage = syncAnnouncementsFromBackendMap(
        announcements,
        announcementsAdjusted: announcementsAdjusted,
      );
      registerScoreboardFromSyncedAnnouncements();
    }

    if (showAdjustmentMessage) {
      await delayForLowTotalAnnouncementMessage(true);
      if (!mounted) return;
    }

    if (mounted) setState(() {});

    if (firstPlayer != null && firstPlayer.isNotEmpty) {
      _backendPlayFirstPlayer = firstPlayer;
    }

    await handleAnnouncementTurnComplete(fromBackend: true);
    _restartRoomSyncPolling(forceRestart: true);

    if (!cardManager.isAnnouncementPhase) {
      _cancelAnnouncementCompletionPoll();
    }

    if (_backendPlayFirstPlayer != null &&
        _backendPlayFirstPlayer!.isNotEmpty &&
        mounted &&
        !cardManager.isAnnouncementPhase) {
      cardManager.currentPlayerTurn = _backendPlayFirstPlayer!;
      if (_backendPlayFirstPlayer == widget.currentPlayerName) {
        setState(() {
          _playableCardCodes.clear();
          _playableCardsReady = false;
        });
        unawaited(_updatePlayableCardsFromBackend(force: true));
      }
      setState(() {});
      startPlayerTurnTimeout();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !cardManager.isAnnouncementPhase) {
          maybeAutoPlayCurrentBot();
        }
      });
    }
  }

  /// Secours HTTP si announcements_complete WS n'arrive pas.
  Future<void> _tryCompleteAnnouncementPhaseFromBackend({
    required String reason,
  }) async {
    if (!mounted || !cardManager.isAnnouncementPhase) return;
    if (_announcementCompletionCheckInFlight) return;

    _announcementCompletionCheckInFlight = true;
    try {
      final gameId = await _resolveGameId();
      if (gameId == null) return;

      final turnData = await GameApiService.instance.getAnnouncementTurn(
        gameId: gameId,
        roundNumber: _effectiveRoundNumber(),
      );

      if (turnData['all_announced'] != true) {
        print('ℹ️ Secours annonces ($reason): BDD pas encore complète');
        return;
      }

      final announcementsRaw = turnData['announcements'];
      Map<String, dynamic>? announcementsMap;
      if (announcementsRaw is Map) {
        announcementsMap = Map<String, dynamic>.from(announcementsRaw);
      }

      await _completeAnnouncementPhaseFromBackend(
        announcements: announcementsMap,
        firstPlayer: turnData['first_player'] as String?,
        roundNumber: _effectiveRoundNumber(),
        source: 'getAnnouncementTurn/$reason',
      );
    } catch (e) {
      print('⚠️ Secours annonces ($reason): $e');
    } finally {
      _announcementCompletionCheckInFlight = false;
    }
  }

  Future<int?> _resolveGameId() async {
    if (_currentGameId != null) return _currentGameId;
    try {
      final id = await getGameId();
      if (id != null) {
        _currentGameId = id;
      }
      return id;
    } catch (e) {
      print('⚠️ Impossible de résoudre gameId: $e');
    }
    if (_currentGameId == null && !isWebSocketConnected) {
      await _pullDistributionFromSync();
    }
    return _currentGameId;
  }

  void _cancelDistributionSyncFallback() {
    _distributionFallbackTimer?.cancel();
    _distributionFallbackTimer = null;
  }

  Future<void> _ensureMyCardsFromSyncIfMissing() async {
    if (!mounted || gameSession.playWithBots) return;
    if (cardManager.getPlayerCards(widget.currentPlayerName).isNotEmpty) return;
    await _pullDistributionFromSync();
  }

  static const List<Duration> _distributionSyncRetryDelays = [
    Duration(milliseconds: 800),
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 8),
    Duration(seconds: 12),
  ];

  void _scheduleDistributionSyncFallback() {
    _cancelDistributionSyncFallback();
    _distributionFallbackTimer = Timer(
      _distributionSyncRetryDelays.first,
      () => unawaited(_runDistributionSyncRetries()),
    );
  }

  Future<void> _runDistributionSyncRetries() async {
    for (var i = 0; i < _distributionSyncRetryDelays.length; i++) {
      if (!mounted || gameSession.playWithBots) return;
      if (_localPlayerHasCards()) return;

      if (i > 0) {
        print(
          '⚠️ Secours /sync (tentative ${i + 1}/'
          '${_distributionSyncRetryDelays.length})',
        );
        await Future.delayed(_distributionSyncRetryDelays[i]);
        if (!mounted || _localPlayerHasCards()) return;
      } else {
        print('⚠️ Secours /sync (1ère tentative, WS a peut-être manqué card_distribution)');
      }

      await _pullDistributionFromSync();
    }
  }

  /// Récupère cartes + game_id via GET /rooms/{id}/sync (secours WS uniquement).
  Future<void> _pullDistributionFromSync() async {
    if (!mounted || gameSession.playWithBots) return;
    final roomId = gameSession.roomId ?? '';
    if (roomId.isEmpty) return;

    _forceSyncDistribution = true;
    try {
      final res = await GameApiService.instance.syncRoom(
        roomId: roomId,
        lastChatId: _lastChatMessageId,
      );
      final rawData = res['data'];
      final Map<String, dynamic> data;
      if (rawData is Map) {
        data = Map<String, dynamic>.from(rawData);
      } else if (res is Map) {
        data = Map<String, dynamic>.from(res);
      } else {
        print('⚠️ sync distribution: payload inattendu (${rawData.runtimeType})');
        return;
      }
      final roundRaw = data['round'];
      final round = roundRaw is Map
          ? Map<String, dynamic>.from(roundRaw)
          : null;
      final distributed = round?['distributed_cards'];
      final hasCards = distributed is Map && distributed.isNotEmpty;
      print(
        '🔍 Sync room=$roomId round=${round?['round_number']} '
        'has_distributed_cards=$hasCards',
      );
      _applyRoomSyncPayload(data);
    } catch (e) {
      print('⚠️ sync distribution: $e');
    } finally {
      _forceSyncDistribution = false;
    }
  }
  StreamSubscription? _cardDistributionSubscription;
  StreamSubscription? _turnChangedSubscription; // ✅ NOUVEAU: Écouter les changements de tour

  // Collections
  final Map<String, Map<String, dynamic>> _temporaryReplacements = {};
  final Set<String> _permanentlyExcludedPlayers = {};
  final List<Map<String, dynamic>> _chatMessages = [];
  final Set<int> _knownChatMessageIds = <int>{};
  int? _lastChatMessageId;
  bool _isFetchingChat = false;
  
  // ✅ Cache des cartes jouables depuis le backend (pour éviter les erreurs 422)
  Set<String> _playableCardCodes = {};
  bool _playableCardsReady = false;
  bool _isUpdatingPlayableCards = false;

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
  
  // ✅ Système de logs pour débogage (affichage dans l'UI)
  final List<String> _debugLogs = [];
  bool _showDebugLogs = false;
  static const int _maxLogs = 20;

  String? _backendPlayFirstPlayer;

  @override
  bool get serverDrivesBots => !gameSession.playWithBots;

  bool get _isRoomCreator => gameSession.players.any(
        (p) =>
            (p['name'] as String?) == widget.currentPlayerName &&
            ((p['isCreator'] as bool?) == true ||
                (p['is_creator'] as bool?) == true),
      );

  bool _isBotPlayerName(String name) {
    if (name.isEmpty) return false;
    return gameSession.players.any((p) {
      if ((p['name'] as String?) != name) return false;
      final isBotValue = p['is_bot'];
      final isReplacementBotValue = p['isReplacementBot'];
      final isBot = isBotValue == true ||
          isBotValue == 1 ||
          (isBotValue is String && isBotValue == '1');
      final isReplacementBot = isReplacementBotValue == true ||
          isReplacementBotValue == 1 ||
          (isReplacementBotValue is String && isReplacementBotValue == '1');
      return isBot || isReplacementBot;
    });
  }

  bool get _useTestDistribution {
    if (!GameConstants.allowTwoHumanWithBotsTest) return false;

    final players = gameSession.players;
    if (players.isEmpty) return false;

    int humanCount = 0;
    for (final player in players) {
      final isBotValue = player['is_bot'];
      final isBot = isBotValue == true ||
          isBotValue == 1 ||
          (isBotValue is String && isBotValue == '1');
      if (!isBot) humanCount++;
    }

    // 2 humains seuls, ou 2 humains + bots déjà ajoutés (4 en salle).
    return humanCount == 2 &&
        (players.length == 2 ||
            players.length >= GameConstants.standardPlayerCount);
  }

  // ✅ Surcharger isTestMode pour retourner _useTestDistribution
  @override
  bool isTestMode() => _useTestDistribution;

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
      CurvedAnimation(
        parent: _chatToastAnimationController,
        curve: Curves.linear,
      ),
    );

    _initializeWebSocketListeners();

    if (!gameSession.playWithBots && requiredPlayers > 0) {
      waitingForHumans = true;
      _restartRoomSyncPolling(forceRestart: true);
    }
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
    _countersSyncTimer?.cancel(); // ✅ Annuler le timer de synchronisation des compteurs
    _cancelDistributionSyncFallback();

    _playerJoinedSubscription?.cancel();
    wsConnectSubscription?.cancel();
    wsDisconnectSubscription?.cancel();
    wsErrorSubscription?.cancel();
    playerReplacedSubscription?.cancel();
    playerRestoredSubscription?.cancel();
    playerDisconnectedSubscription?.cancel();
    playerReconnectedSubscription?.cancel();
    announcementMadeSubscription?.cancel();
    _allAnnouncementsCompletedSubscription?.cancel();
    _announcementPhaseStartedSubscription?.cancel();
    _announcementSubmittedSubscription?.cancel();
    _announcementsCompleteSubscription?.cancel();
    _announcementsAdjustedSubscription?.cancel();
    _announcementPhaseTimer?.cancel();
    roomChatMessageSubscription?.cancel();
    cardPlayedSubscription?.cancel();
    _trickCompletedSubscription?.cancel();
    _roundCompletedSubscription?.cancel();
    _cardDistributionSubscription?.cancel();
    _turnChangedSubscription?.cancel(); // ✅ NOUVEAU: Annuler l'écoute des changements de tour
    _trickCompletionWatchdog?.cancel();
    _cancelAnnouncementCompletionPoll();

    _chatInputController.dispose();
    _chatScrollController.dispose();
    _cardAnimationController.dispose();
    _chatToastAnimationController.dispose();
  }

  @override
  void startChatPolling() {
    if (gameSession.playWithBots) {
      chatPollingTimer?.cancel();
      return;
    }

    // Chat : WebSocket en temps réel + messages inclus dans syncRoom (pas de timer dédié).
    chatPollingTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          _showLeaveGameConfirmation();
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
                              'Attendons les autres joueurs (${gameSession.players.length}/$requiredPlayers)',
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
                
                _buildPlayerHand(),
                _buildPlayers(),
                _buildCenterTrick(),
                
                if (isAnimatingCard && animatedCard != null)
                  _buildAnimatedCard(),

                _buildGameControls(),
                _buildTurnMessage(),
                _buildAnnouncementPanel(),
                _buildAnnouncementNotification(),
                
                // ✅ Widget de logs de débogage (uniquement en mode debug)
                if (kDebugMode) _buildDebugLogs(),
                
                // ✅ Message d'annonce supprimé - les joueurs font simplement leur annonce

                _buildRoomInfo(),
                
                // Chat pour le mode humain uniquement
                _buildChatOverlay(),
                _buildChatToast(),
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
            final res = await GameApiService.instance.getRoom(roomId: roomId);
            final data = (res['data'] as Map?) ?? res;
            final players = (data['players'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            final currentName = UserService.instance.currentUserPseudo ?? '';
            
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
              return {
                ...p,
                'normalizedName': name.isNotEmpty ? name : 'Joueur',
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
            
            if (currentPlayerIndex == -1 && normalizedPlayers.isNotEmpty) {
              // Si le joueur actuel n'est pas trouvé, utiliser le premier
              final firstPlayer = normalizedPlayers[0];
              final normalized = <Map<String, dynamic>>[];
              final name = firstPlayer['normalizedName'] as String;
              final isBot = (firstPlayer['is_bot'] ?? false) == true;
              final backendAvatar = (firstPlayer['avatar'] ?? '').toString();
              final isCreator = ((firstPlayer['is_creator'] ?? firstPlayer['isCreator']) == true);
              
              final resolvedAvatar = isBot
                  ? '🤖'
                  : (backendAvatar.isNotEmpty ? backendAvatar : '👤');
              
              normalized.add({
                'name': name,
                'displayPosition': 'bottom',
                'avatar': resolvedAvatar,
                'isCurrentPlayer': true,
                'isCreator': isCreator,
                'score': '0/0',
                'cards': 13,
                'is_bot': isBot,
              });
              
              // Ajouter les autres joueurs
              final displayPositions = ['right', 'top', 'left'];
              for (int i = 1; i < normalizedPlayers.length && i < 4; i++) {
                final p = normalizedPlayers[i];
                final pName = p['normalizedName'] as String;
                final pIsBot = (p['is_bot'] ?? false) == true;
                final pAvatar = (p['avatar'] ?? '').toString();
                final pIsCreator = ((p['is_creator'] ?? p['isCreator']) == true);
                
                final resolvedAvatar = pIsBot
                    ? '🤖'
                    : (pAvatar.isNotEmpty ? pAvatar : '👤');
                
                normalized.add({
                  'name': pName,
                  'displayPosition': displayPositions[i - 1],
                  'avatar': resolvedAvatar,
                  'isCurrentPlayer': false,
                  'isCreator': pIsCreator,
                  'score': '0/0',
                  'cards': 13,
                  'is_bot': pIsBot,
                });
              }
              
              if (normalized.isNotEmpty) {
                setState(() {
                  gameSession.players = normalized;
                  gameSession.globalScores = List.filled(normalized.length, 0.0);
                });
              }
              return;
            }
            
            if (currentPlayerIndex == -1) {
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
              // ✅ Accepter à la fois true (booléen) et 1 (entier) comme valeur "bot"
              final isBotValue = p['is_bot'];
              final isBot = isBotValue == true || isBotValue == 1 || (isBotValue is String && isBotValue == '1');
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
              });
            }
            
            if (normalized.isNotEmpty) {
              setState(() {
                gameSession.players = normalized;
                gameSession.globalScores = List.filled(normalized.length, 0.0);
              });
            }
          } catch (_) {}
        }
      }

      var effectivePlayerNames = gameSession.players
          .map((player) => player['name'] as String? ?? 'Joueur')
          .where((n) => n.isNotEmpty)
          .toList();
          
      if (effectivePlayerNames.isEmpty) {
        print('⚠️ Aucun joueur disponible');
        return;
      }

      // ✅ AJOUT AUTOMATIQUE DE BOTS: Si seulement 2 joueurs, compléter avec Bot 1 et Bot 2
      // En mode test, on veut toujours 4 joueurs (2 humains + 2 bots) pour que le backend distribue correctement
      print('🔍 Vérification ajout bots:');
      print('   effectivePlayerNames.length=${effectivePlayerNames.length}');
      print('   gameSession.players.length=${gameSession.players.length}');
      print('   _useTestDistribution=$_useTestDistribution');
      print('   kDebugMode=${kDebugMode}');
      
      if (_useTestDistribution &&
          gameSession.players.length < GameConstants.standardPlayerCount) {
        final roomId = gameSession.roomId ?? '';
        if (roomId.isEmpty) {
          print('⚠️ Room ID vide, impossible d\'ajouter les bots');
        } else if (_botsFillInFlight) {
          print('⏳ fillBots déjà en cours...');
        } else {
          _botsFillInFlight = true;
          try {
            print('🤖 Compléter la salle à 4 joueurs (mode test)...');
            final fillBotsResult =
                await GameApiService.instance.fillBots(roomId: roomId);
            print('✅ fillBots appelé avec succès: $fillBotsResult');
            
            // ✅ Attendre un peu pour que le backend traite l'ajout des bots
            await Future.delayed(const Duration(milliseconds: 500));
            
            // ✅ Recharger les joueurs depuis le backend après ajout des bots
            final res = await GameApiService.instance.getRoom(roomId: roomId);
            final data = (res['data'] as Map?) ?? res;
            final players = (data['players'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            print('📊 Joueurs récupérés depuis backend après fillBots: ${players.length}');
            for (var p in players) {
              final pseudo = (p['pseudo'] ?? '').toString();
              final first = (p['first_name'] ?? '').toString();
              final last = (p['last_name'] ?? '').toString();
              // ✅ Accepter à la fois true (booléen) et 1 (entier) comme valeur "bot"
              final isBotValue = p['is_bot'];
              final isBot = isBotValue == true || isBotValue == 1 || (isBotValue is String && isBotValue == '1');
              final name = (pseudo.isNotEmpty
                      ? pseudo
                      : ([first, last]
                            .where((s) => s.isNotEmpty)
                            .join(' ')
                            .trim()))
                  .trim();
              print('   - $name: is_bot=$isBotValue (type: ${isBotValue.runtimeType}), normalisé=$isBot');
              // ✅ Debug: Afficher toutes les clés pour voir ce que le backend retourne
              if (name.contains('Bot')) {
                print('      🔍 Toutes les clés du bot: ${p.keys.toList()}');
                print('      🔍 Valeur brute is_bot: ${p['is_bot']} (type: ${p['is_bot']?.runtimeType})');
              }
            }
            
            final currentName = UserService.instance.currentUserPseudo ?? '';
            
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
              
              // ✅ Debug détaillé pour les bots
              if (name.contains('Bot') || pseudo.contains('Bot')) {
                print('   🔍 Normalisation BOT $name:');
                print('      - pseudo: $pseudo');
                print('      - isBotValue brut: $isBotValue (type: ${isBotValue?.runtimeType})');
                print('      - isBot calculé: $isBot');
                print('      - Toutes les clés: ${p.keys.toList()}');
              }
              
              return {
                ...p,
                'normalizedName': name.isNotEmpty ? name : 'Joueur',
                'is_bot': isBot, // ✅ Forcer la valeur booléenne
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
              print('⚠️ Joueur actuel non trouvé dans la liste des joueurs après fillBots');
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
              
              // ✅ Debug: Afficher la valeur pour vérifier
              if (name.contains('Bot')) {
                print('   🔍 Debug bot $name: is_bot=$isBot (type: ${isBot.runtimeType})');
              }
              
              final backendAvatar = (p['avatar'] ?? '').toString();
              final isCreator = ((p['is_creator'] ?? p['isCreator']) == true);
              
              normalized.add({
                'name': name,
                'displayPosition': displayPositions[i],
                'avatar': backendAvatar.isNotEmpty
                    ? backendAvatar
                    : (isBot ? '🤖' : '👤'),
                'isCurrentPlayer': isCurrent,
                'isCreator': isCreator,
                'score': '0/0',
                'cards': 13,
                'is_bot': isBot, // ✅ Valeur booléenne préservée
              });
            }
            
            if (normalized.isNotEmpty) {
              setState(() {
                gameSession.players = normalized;
                gameSession.globalScores = List.filled(normalized.length, 0.0);
              });
              
              // ✅ Mettre à jour la liste des noms de joueurs
              effectivePlayerNames = normalized
                  .map((player) => player['name'] as String? ?? 'Joueur')
                  .where((n) => n.isNotEmpty)
                  .toList();
              
              print('✅ Bots ajoutés: ${effectivePlayerNames.length} joueurs maintenant');
              print('   Liste des joueurs: ${effectivePlayerNames.join(", ")}');
              // ✅ Debug: Afficher les détails de chaque joueur pour vérifier is_bot
              print('   📊 Détails des joueurs normalisés:');
              for (final player in normalized) {
                final name = player['name'] as String? ?? 'Joueur';
                final isBot = (player['is_bot'] as bool?) == true;
                print('     - $name: is_bot=$isBot');
              }
            } else {
              print('⚠️ Aucun joueur normalisé après fillBots');
            }
          } catch (e, stackTrace) {
            print('⚠️ Erreur lors de l\'ajout des bots: $e');
            print('   Stack trace: $stackTrace');
          } finally {
            _botsFillInFlight = false;
          }
        }
      } else if (!_useTestDistribution) {
        print('ℹ️ Condition non remplie pour ajout automatique des bots');
      }

      final minPlayersForDistribution = _useTestDistribution
          ? GameConstants.standardPlayerCount
          : requiredPlayers;

      if (effectivePlayerNames.length < minPlayersForDistribution) {
        waitingForHumans = true;
        setState(() {});
        print(
          '⏳ Distribution reportée: ${effectivePlayerNames.length}/$minPlayersForDistribution '
          'joueurs HTTP dans la salle',
        );
        return;
      }

      waitingForHumans = false;
      setState(() {});

      // ✅ Déterminer qui est le créateur
      final isCreator = gameSession.players.any(
        (p) => (p['name'] as String?) == widget.currentPlayerName && 
               (p['isCreator'] as bool?) == true,
      );

      if (isCreator) {
        await _creatorRequestDistributionWhenReady();
      } else {
        print('⏳ En attente de la distribution via WebSocket...');
        _scheduleDistributionSyncFallback();
        unawaited(_ensureMyCardsFromSyncIfMissing());
      }
    } catch (e) {
      print('❌ Erreur distribution: $e');
    }
  }

  Future<void> _creatorRequestDistributionWhenReady() async {
    if (_distributionRequestInFlight || !mounted) return;

    final roomId = gameSession.roomId ?? '';
    if (roomId.isEmpty) {
      print('❌ Room ID manquant, impossible de distribuer');
      return;
    }

    _distributionRequestInFlight = true;
    print(
      '👑 Créateur: attente de $requiredPlayers joueurs en salle (HTTP)...',
    );

    try {
      for (var attempt = 0; attempt < 45 && mounted; attempt++) {
        if (!_hasFullHttpRoom()) {
          print(
            '⏳ HTTP: ${gameSession.players.length}/$requiredPlayers joueurs',
          );
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        if (!_hasAllPlayersJoinedWebSocket()) {
          final expected = _expectedHumanPlayerNames();
          final missing = expected.difference(_wsJoinedPlayerNames);
          print(
            'ℹ️ WS: ${_wsJoinedPlayerNames.length}/$requiredPlayers'
            '${missing.isEmpty ? '' : ' — manque: ${missing.join(", ")}'} '
            '(distribution via BDD + replay WS)',
          );
        } else {
          print(
            '👑 Salle prête (${gameSession.players.length} HTTP, '
            '${_wsJoinedPlayerNames.length} WS) — distribution...',
          );
        }

        try {
          final response = await GameApiService.instance.distributeCards(
            roomId: roomId,
            roundNumber: gameSession.currentRound + 1,
            testMode: _useTestDistribution,
          );
          print('✅ Backend a distribué les cartes: $response');
          _applyGameStateFromDistributeCardsResponse(response);
          return;
        } catch (e) {
          final message = e.toString();
          if (message.contains('409') ||
              message.contains('ROOM_NOT_READY') ||
              message.contains('ROOM_NOT_FULL')) {
            print('⚠️ Backend: salle pas prête ($message) — retry...');
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          print('❌ Erreur lors de la demande de distribution: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Erreur: Impossible de distribuer les cartes. Veuillez réessayer.',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }
      }

      print(
        '❌ Timeout: distribution impossible — tous les joueurs ne sont pas prêts',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'En attente des $requiredPlayers joueurs dans la salle...',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      _distributionRequestInFlight = false;
    }
  }

  /// Applique distribution + phase d'annonces depuis la réponse HTTP (secours si WS en retard).
  void _applyGameStateFromDistributeCardsResponse(Map<String, dynamic> response) {
    if (!mounted || response['success'] != true) return;

    final raw = response['data'];
    if (raw is! Map) return;
    final data = Map<String, dynamic>.from(raw);

    final distribution = data['distribution'] as Map<String, dynamic>?;
    final roundNumber = (data['round_number'] as num?)?.toInt();
    final gameIdRaw = data['game_id'];
    if (gameIdRaw is int) {
      _currentGameId = gameIdRaw;
    } else if (gameIdRaw != null) {
      _currentGameId = int.tryParse(gameIdRaw.toString());
    }

    if (distribution != null &&
        distribution.isNotEmpty &&
        _needsDistributionApply(roundNumber)) {
      print('📥 Application distribution depuis réponse HTTP (créateur)');
      _applyCardDistributionPayload(
        _canonicalizeDistributionKeys(
          Map<String, dynamic>.from(distribution),
        ),
        roundNumber: roundNumber,
      );
    }

    final phase = data['announcement_phase'];
    if (phase is Map) {
      _handleAnnouncementPhaseStartedPayload(
        Map<String, dynamic>.from(phase),
      );
    }
  }

  void _applyCardDistributionPayload(
    Map<String, dynamic> distribution, {
    int? roundNumber,
    bool skipConfigureIfAnnouncementActive = false,
  }) {
    final normalized = _canonicalizeDistributionKeys(distribution);
    if (!_validateFullDistribution(normalized)) {
      print('⚠️ Distribution ignorée (validation échouée)');
      return;
    }

    _cancelDistributionSyncFallback();
    _syncRoundNumber(roundNumber);
    _markDistributionApplied(roundNumber);

    cardManager.resetRoundCounters();
    cardManager.clearCurrentTrick();
    _lastProcessedTrickCompletedNumber = null;
    _activeBackendTrickNumber = 1;

    for (final entry in normalized.entries) {
      final playerName = entry.key.toString();
      final cardCodes = (entry.value as List).cast<String>();
      final cards = cardCodes.map((code) {
        return LocalCardManager.instance.getCardByCode(code) ?? {
          'code': code,
          'value': code.substring(0, 1),
          'suit': code.length > 1 ? code.substring(1) : '',
        };
      }).toList();
      cardManager.setPlayerCards(playerName, cards);
    }

    final playerNames = gameSession.players
        .map((p) => p['name'] as String? ?? 'Joueur')
        .toList();

    if (mounted) {
      setState(() {
        hasGameStarted = true;
      });
    }

    if (skipConfigureIfAnnouncementActive && cardManager.isAnnouncementPhase) {
      print('ℹ️ Cartes appliquées — phase d\'annonces déjà active');
      _maybeApplyPendingAnnouncementPhase();
      return;
    }

    _configureGameAfterDistribution(playerNames);
    _maybeApplyPendingAnnouncementPhase();
  }

  void _handleAnnouncementPhaseStartedPayload(Map<String, dynamic> data) {
    if (!_localPlayerHasCards()) {
      _pendingAnnouncementPhasePayload = Map<String, dynamic>.from(data);
      print(
        '⏸️ Phase d\'annonces différée — cartes manquantes pour '
        '${widget.currentPlayerName}',
      );
      unawaited(_ensureMyCardsFromSyncIfMissing());
      return;
    }
    _applyAnnouncementPhaseStartedNow(data);
  }

  void _applyAnnouncementPhaseStartedNow(Map<String, dynamic> data) {
    final roomId = data['roomId'] as String? ?? data['room_id']?.toString();
    final roundNumber = (data['round_number'] as num?)?.toInt();
    final startTimestamp = (data['start_timestamp'] as num?)?.toInt();
    final duration = (data['duration'] as num?)?.toInt() ?? 30;
    final gameIdRaw = data['game_id'];
    final gameId =
        gameIdRaw is int ? gameIdRaw : int.tryParse('$gameIdRaw');

    if (roomId != null &&
        gameSession.roomId != null &&
        !_roomIdsMatch(roomId, gameSession.roomId)) {
      return;
    }
    if (startTimestamp == null) return;

    if (roundNumber != null &&
        _announcementPhaseRoundApplied == roundNumber &&
        cardManager.isAnnouncementPhase) {
      if (gameId != null) _currentGameId = gameId;
      return;
    }

    if (roundNumber != null) {
      _announcementPhaseRoundApplied = roundNumber;
      _syncRoundNumber(roundNumber);
    }

    print(
      '🎬 Phase d\'annonces: round=$roundNumber, start=$startTimestamp, game_id=$gameId',
    );

    _announcementPhaseStartTimestamp = startTimestamp;
    _announcementPhaseDuration = duration;
    if (gameId != null) _currentGameId = gameId;
    hasAnnounced = false;

    _startAnnouncementPhaseTimer(startTimestamp, duration);

    if (mounted) {
      setState(() {
        cardManager.isAnnouncementPhase = true;
      });
    }
    _restartRoomSyncPolling(forceRestart: true);
    _scheduleBotAnnouncementsAfterPhaseStart();
  }

  void _scheduleBotAnnouncementsAfterPhaseStart() {
    if (!_isRoomCreator) {
      print('ℹ️ Annonces bots : gérées par le créateur (pas ce client)');
      return;
    }

    Future.delayed(const Duration(seconds: 10), () async {
      if (!mounted || !cardManager.isAnnouncementPhase) return;

      final bots = gameSession.players.where((p) {
        final isBotValue = p['is_bot'];
        return isBotValue == true ||
            isBotValue == 1 ||
            (isBotValue is String && isBotValue == '1');
      }).toList();

      for (int i = 0; i < bots.length; i++) {
        final botName = bots[i]['name'] as String? ?? 'Joueur';
        Future.delayed(Duration(milliseconds: 300 + (i * 400)), () async {
          if (!mounted || !cardManager.isAnnouncementPhase) return;
          final announcements = cardManager.getCurrentRoundAnnouncements();
          final alreadyAnnounced =
              announcements.any((ann) => ann['player'] == botName);
          if (!alreadyAnnounced) {
            await _sendBotAnnouncementWithRetry(botName);
          }
        });
      }
    });
  }

  Future<void> _configureGameAfterDistribution(List<String> playerNames) async {
    _syncRoundNumber(null);

    // ✅ Réinitialiser les événements de cartes pour éviter les doublons sur un nouveau round
    resetCardEventTracking();
    // ✅ S'assurer que le trick est bien vidé avant de commencer les annonces
    cardManager.clearCurrentTrick();
    
    gameLogic.configurePlayers(
      playerCount: playerNames.length,
      cardsPerPlayer: cardManager.cardsPerPlayer,
    );

    // Hash de vérification (optionnel pour le créateur)
    try {
      final List<String> orderedCodes = [];
      for (final name in playerNames) {
        final hand = cardManager.getPlayerCards(name);
        for (final c in hand) {
          orderedCodes.add((c['code'] as String?) ?? '');
        }
      }
      final payload = orderedCodes.join('-');
      final bytes = utf8.encode(payload);
      final hash = crypto.sha256.convert(bytes).toString();
      final roomId = gameSession.roomId ?? '';
      if (roomId.isNotEmpty) {
        GameApiService.instance.startRound(
          roomId: roomId,
          roundNumber: gameSession.currentRound + 1,
          deckHash: hash,
        ).catchError((_) {
          return <String, dynamic>{};
        });
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

    // La phase d'annonces est pilotée par announcement_phase_started (WebSocket / HTTP).
    cardManager.isAnnouncementPhase = false;

    print('✅ Jeu configuré après distribution — attente phase d\'annonces backend');
    print('   Joueur actuel: ${widget.currentPlayerName}');
    print('   Trick vidé: ${cardManager.currentTrick.isEmpty}');
    
    if (mounted) {
      setState(() {});
    }
    
    // ✅ NOUVEAU: Les bots annonceront automatiquement après réception de announcement_phase_started
    // (géré dans le listener _announcementPhaseStartedSubscription)
    
    // Mode simultané : announcement_phase_started (WS) pilote les annonces.
    hasGameStarted = true;
  }

  @override
  Future<void> beforePlayCardValidation() async {
    if (!serverDrivesBots || isCollectingTrick) return;

    final alreadyPlayed = cardManager.currentTrick.any(
      (e) => (e['player'] as String?) == widget.currentPlayerName,
    );
    if (alreadyPlayed) return;

    if (cardManager.currentTrick.length < cardManager.expectedPlayerCount) {
      await _resyncCurrentTrickFromBackend();
    }
  }

  // Surcharger sendRoundCompletedViaWebSocket pour envoyer via WebSocket
  @override
  void sendRoundCompletedViaWebSocket(
    int roundNumber,
    Map<String, int> announcedByPlayer,
    Map<String, int> obtainedByPlayer,
    Map<String, int> scores,
  ) {
    final roomId = gameSession.roomId;
    if (roomId != null && roomId.isNotEmpty && isWebSocketConnected) {
      try {
        final wsService = GameWebSocketService();
        if (wsService.isConnected) {
          wsService.roundCompleted(
            roundNumber,
            scores,
            announcedByPlayer: announcedByPlayer,
            obtainedByPlayer: obtainedByPlayer,
          ).catchError((e) {
            print('⚠️ Erreur WebSocket lors de l\'envoi de round_completed: $e');
          });
          print('📤 Envoi round_completed via WebSocket: round=$roundNumber, scores=$scores');
        }
      } catch (e) {
        print('⚠️ Erreur lors de l\'envoi de round_completed via WebSocket: $e');
      }
    }
  }

  // Surcharger sendAnnouncementViaWebSocket pour envoyer via WebSocket
  @override
  void sendAnnouncementViaWebSocket(int announcement, {String? playerName}) {
    final roomId = gameSession.roomId;
    if (roomId != null && roomId.isNotEmpty && isWebSocketConnected) {
      try {
        final wsService = GameWebSocketService();
        if (wsService.isConnected) {
          // ✅ Utiliser playerName si fourni (pour les bots), sinon utilise le joueur actuel
          wsService.makeAnnouncement(announcement, playerName: playerName).catchError((e) {
            print('⚠️ Erreur WebSocket lors de l\'envoi de l\'annonce: $e');
          });
          print('📤 Annonce envoyée via WebSocket: ${playerName ?? widget.currentPlayerName} → $announcement plis');
        }
      } catch (e) {
        print('⚠️ Erreur lors de l\'envoi de l\'annonce via WebSocket: $e');
      }
    }
  }

  // Surcharger sendAnnouncementTimeoutViaWebSocket pour envoyer via WebSocket
  @override
  void sendAnnouncementTimeoutViaWebSocket(String playerName) {
    // ✅ CORRECTION: Envoyer l'annonce timeout pour tous les joueurs (pas seulement le local)
    // Car le timeout peut assigner 2 plis à n'importe quel joueur qui n'a pas annoncé
    final roomId = gameSession.roomId;
    if (roomId != null && roomId.isNotEmpty && isWebSocketConnected) {
      try {
        final wsService = GameWebSocketService();
        if (wsService.isConnected) {
          // ✅ Passer le nom du joueur pour que le backend sache qui fait l'annonce
          wsService.makeAnnouncement(2, playerName: playerName).catchError((e) {
            print('⚠️ Erreur WebSocket lors de l\'envoi de l\'annonce timeout pour $playerName: $e');
          });
          print('📤 Annonce timeout (2 plis) envoyée via WebSocket pour $playerName');
        }
      } catch (e) {
        print('⚠️ Erreur lors de l\'envoi de l\'annonce timeout via WebSocket pour $playerName: $e');
      }
    }
  }

  void _initializeWebSocketListeners() {
    final wsService = GameWebSocketService();

    wsConnectSubscription = wsService.onConnect().listen((_) {
      if (!mounted) return;
      setState(() {
        isWebSocketConnected = true;
      });
      final roomId = gameSession.roomId;
      final playerName = widget.currentPlayerName;
      if (playerName.isNotEmpty) {
        _wsJoinedPlayerNames.add(playerName);
      }
      if (roomId != null && roomId.isNotEmpty && playerName.isNotEmpty) {
        wsService.joinRoom(roomId, playerName).catchError((error) {
          print('⚠️ Erreur lors de la jointure de la room WebSocket: $error');
        });
      }
      _countersSyncTimer?.cancel();
      _restartRoomSyncPolling(forceRestart: true);
      if (!waitingForHumans) {
        _ensureMyCardsFromSyncIfMissing();
      }
    });

    _playerJoinedSubscription = wsService.onPlayerJoined().listen((data) {
      if (!mounted) return;
      _ingestWsPlayerJoinedPayload(data);
    });

    wsDisconnectSubscription = wsService.onDisconnect().listen((_) {
      if (!mounted) return;
      setState(() {
        isWebSocketConnected = false;
      });
      _restartRoomSyncPolling(forceRestart: true);
    });

    wsErrorSubscription = wsService.onError().listen((error) {
      if (!mounted) return;
      setState(() {
        isWebSocketConnected = false;
      });
      _restartRoomSyncPolling(forceRestart: true);
    });

    // ✅ NOUVEAU: Écouter la distribution de cartes
    _cardDistributionSubscription = wsService.onCardDistribution().listen((data) {
      print('🃏 card_distribution brut: $data');
      if (!mounted) return;

      final distributionRaw = data['distribution'] as Map<String, dynamic>?;
      final roundNumber = (data['round_number'] as num?)?.toInt();
      final roomId = (data['roomId'] ?? data['room_id'])?.toString();

      if (distributionRaw == null || distributionRaw.isEmpty) {
        print('⚠️ Distribution null/vide dans card_distribution');
        return;
      }

      if (roomId != null && !_roomIdsMatch(roomId, gameSession.roomId)) {
        print('⚠️ Room ID ne correspond pas: $roomId vs ${gameSession.roomId}');
        return;
      }

      if (!_needsDistributionApply(roundNumber)) {
        print('ℹ️ Distribution round=$roundNumber déjà appliquée localement');
        return;
      }

      print(
        '📥 Application distribution WS round=$roundNumber '
        'pour ${widget.currentPlayerName}',
      );

      _applyCardDistributionPayload(
        Map<String, dynamic>.from(distributionRaw),
        roundNumber: roundNumber,
      );
    });

        playerReplacedSubscription = wsService.onPlayerReplaced().listen((data) {
      if (mounted) {
        final playerName = data['player_name'] as String?;
        final botName = data['bot_name'] as String?;
        final isPermanent = (data['is_permanent'] as bool?) ?? false;

        if (playerName != null && botName != null) {
          if (playerName != widget.currentPlayerName) {
            _synchronizePlayerReplacement(playerName, botName, isPermanent);
          } else if (isPermanent) {
            permanentlyExcludedPlayers.add(playerName);
            if (mounted) {
              super.showPlayerExcludedDialog();
            }
          }
        }
      }
    });

    playerRestoredSubscription = wsService.onPlayerRestored().listen((data) {
      if (mounted) {
        final playerName = data['player_name'] as String?;
        final botName = data['bot_name'] as String?;

        if (playerName != null && botName != null) {
          if (playerName != widget.currentPlayerName) {
            _synchronizePlayerRestoration(playerName, botName);
          } else {
            temporaryReplacements.remove(playerName);
          }
        }
      }
    });

    playerDisconnectedSubscription = wsService.onPlayerDisconnected().listen((data) {
      if (mounted) {
        final playerName = data['player_name'] as String?;
        final roomId = data['room_id'] as String?;

        if (playerName != null && roomId == gameSession.roomId) {
          if (playerName != widget.currentPlayerName &&
              !temporaryReplacements.containsKey(playerName)) {
            _handlePlayerDisconnection(playerName);
          }
        }
      }
    });

    playerReconnectedSubscription = wsService.onPlayerReconnected().listen((data) {
      if (mounted) {
        final playerName = data['player_name'] as String?;
        final canRestore = (data['can_restore'] as bool?) ?? false;
        final roomId = data['room_id'] as String?;

        if (playerName != null && roomId == gameSession.roomId) {
          if (canRestore && temporaryReplacements.containsKey(playerName)) {
            _handlePlayerReconnection(playerName);
          } else if (!canRestore) {
            if (temporaryReplacements.containsKey(playerName)) {
              temporaryReplacements[playerName]!['isPermanent'] = true;
              permanentlyExcludedPlayers.add(playerName);
            }
          }
        }
      }
    });

    announcementMadeSubscription = wsService.onAnnouncementMade().listen((data) async {
      if (mounted) {
        final playerName = data['playerName'] as String? ?? data['player_name'] as String?;
        final announcement = data['announcement'] as int?;
        final roomId = data['roomId'] as String? ?? data['room_id'] as String?;

        // ✅ Accepter TOUS les messages d'annonce (y compris ceux de l'expéditeur)
        // pour garantir la synchronisation complète
        if (playerName != null && 
            announcement != null && 
            roomId == gameSession.roomId) {
          print('📡 Annonce reçue via WebSocket: $playerName → $announcement plis');

          if (!_localPlayerHasCards()) {
            print('⏸️ Annonce ignorée — cartes manquantes');
            unawaited(_ensureMyCardsFromSyncIfMissing());
            return;
          }

          if (gameSession.currentRound < 1) {
            _syncRoundNumber(1);
          }
          
          // ✅ Vérifier si l'annonce n'existe pas déjà (éviter les doublons)
          final existingAnnouncements = cardManager.getCurrentRoundAnnouncements();
          final alreadyExists = existingAnnouncements.any(
            (ann) => ann['player'] == playerName,
          );
          
          if (!alreadyExists) {
            print('   ✅ Ajout de l\'annonce pour $playerName: $announcement plis');
            cardManager.makeAnnouncement(playerName, announcement);
            
            // ✅ Vérifier que l'annonce a bien été ajoutée
            final updatedAnnouncements = cardManager.getCurrentRoundAnnouncements();
            print('   📊 Annonces après ajout: ${updatedAnnouncements.length}');
            for (var ann in updatedAnnouncements) {
              print('      - ${ann['player']}: ${ann['announcement']} plis');
            }
            
            // ✅ Forcer la mise à jour de l'UI pour tous les joueurs
            // ⚠️ IMPORTANT: Ne pas réinitialiser _currentAnnouncementPlayer ici
            // pour que le panneau reste stable pendant les 30 secondes
            if (mounted) {
              setState(() {
                // Mettre à jour l'interface - cela déclenchera la reconstruction
                // de tous les widgets qui utilisent getPlayerAnnouncementDisplay
                // Mais _currentAnnouncementPlayer reste inchangé pour maintenir le panneau stable
              });
              print('   ✅ setState() appelé pour mettre à jour les compteurs d\'annonces');
              print('   📊 Annonce synchronisée en temps réel: $playerName → $announcement plis');
            }
          } else {
            print('⚠️ Annonce déjà existante pour $playerName, ignorée');
          }
          
          // ✅ Vérifier avec le backend si toutes les annonces sont faites
          unawaited(
            _tryCompleteAnnouncementPhaseFromBackend(
              reason: 'announcement_made',
            ),
          );
        } else {
          print('⚠️ Annonce reçue mais conditions non remplies:');
          if (playerName == null) print('      - playerName est null');
          if (announcement == null) print('      - announcement est null');
          if (roomId != gameSession.roomId) print('      - roomId ne correspond pas: $roomId vs ${gameSession.roomId}');
        }
      }
    });

    // ✅ NOUVEAU: Écouter l'événement de fin des annonces depuis le backend (ancien système)
    _allAnnouncementsCompletedSubscription = wsService.onAllAnnouncementsCompleted().listen((data) {
      if (!mounted) return;
      
      final roomId = data['roomId'] as String? ?? data['room_id'] as String?;
      final roundNumber = _parseRoundNumber(data['round_number']);
      final announcements = data['announcements'] as Map<String, dynamic>?;
      
      if (roomId?.toString() == gameSession.roomId?.toString() &&
          _matchesRoundNumber(roundNumber)) {
        unawaited(_completeAnnouncementPhaseFromBackend(
          announcements: announcements != null
              ? Map<String, dynamic>.from(announcements)
              : null,
          roundNumber: roundNumber,
          source: 'all_announcements_completed_ws',
        ));
      }
    });

    // ✅ NOUVEAU: Écouter l'événement de démarrage de la phase d'annonces simultanée
    _announcementPhaseStartedSubscription = wsService.onAnnouncementPhaseStarted().listen((data) {
      if (!mounted) return;
      if (data is Map) {
        _handleAnnouncementPhaseStartedPayload(
          Map<String, dynamic>.from(data),
        );
      }
    });

    // ✅ NOUVEAU: Écouter les soumissions d'annonces en temps réel
    _announcementSubmittedSubscription = wsService.onAnnouncementSubmitted().listen((data) {
      if (!mounted) return;
      
      final roomId = data['roomId'] as String? ?? data['room_id'] as String?;
      final roundNumber = _parseRoundNumber(data['round_number']);
      final playerName = data['playerName'] as String? ?? data['player_pseudo'] as String?;
      final announcement = data['announcement'] as int? ?? data['announcement_value'] as int?;
      final submittedCount = data['submitted_count'] as int?;
      
      if (roomId == gameSession.roomId &&
          _matchesRoundNumber(roundNumber) &&
          playerName != null &&
          announcement != null) {
        print('📡 Annonce soumise: $playerName → $announcement plis (total: $submittedCount/4)');
        
        // Synchroniser l'annonce localement
        final existingAnnouncements = cardManager.getCurrentRoundAnnouncements();
        final alreadyExists = existingAnnouncements.any(
          (ann) => ann['player'] == playerName,
        );
        
        if (!alreadyExists) {
          cardManager.makeAnnouncement(playerName, announcement);
          
          // Mettre à jour l'UI
          if (mounted) {
            setState(() {});
          }
        }

        final playerNames = gameSession.players
            .map((p) => p['name'] as String? ?? 'Joueur')
            .toList();
        if (cardManager.areAllAnnouncementsDone(playerNames)) {
          unawaited(
            _tryCompleteAnnouncementPhaseFromBackend(
              reason: 'announcement_submitted_all_local',
            ),
          );
        }
      }
    });

    // ✅ NOUVEAU: Écouter l'événement de fin des annonces (système simultané)
    _announcementsCompleteSubscription = wsService.onAnnouncementsComplete().listen((data) {
      if (!mounted) return;
      
      print('📥 Événement announcements_complete reçu: $data');
      
      final roomId = data['roomId'] as String? ?? data['room_id'] as String?;
      final roundNumber = _parseRoundNumber(data['round_number']);
      final announcements = data['announcements'] as Map<String, dynamic>?;
      final firstPlayer = data['first_player'] as String?;
      final announcementsAdjusted = data['announcements_adjusted'] == true;
      
      print('🔍 Vérification événement announcements_complete:');
      print('   - roomId reçu: $roomId (type: ${roomId.runtimeType})');
      print('   - roomId session: ${gameSession.roomId} (type: ${gameSession.roomId.runtimeType})');
      print('   - roundNumber reçu: $roundNumber (type: ${roundNumber.runtimeType})');
      print('   - roundNumber session: ${gameSession.currentRound} (type: ${gameSession.currentRound.runtimeType})');
      
      // ✅ AMÉLIORATION: Comparer les roomId en convertissant en string pour éviter les problèmes de type
      final roomIdMatch = roomId?.toString() == gameSession.roomId?.toString();
      final roundNumberMatch = _matchesRoundNumber(roundNumber);
      
      print('   - Match roomId: $roomIdMatch');
      print('   - Match roundNumber: $roundNumberMatch');
      print('   - Match total: ${roomIdMatch && roundNumberMatch}');
      
      if (roomIdMatch && roundNumberMatch) {
        unawaited(_completeAnnouncementPhaseFromBackend(
          announcements: announcements != null
              ? Map<String, dynamic>.from(announcements)
              : null,
          firstPlayer: firstPlayer,
          roundNumber: roundNumber,
          announcementsAdjusted: announcementsAdjusted,
          source: 'announcements_complete_ws',
        ));
      } else {
        print('⚠️ Événement announcements_complete ignoré (roomId ou roundNumber ne correspondent pas)');
      }
    });

    _announcementsAdjustedSubscription =
        wsService.onAnnouncementsAdjusted().listen((data) {
      if (!mounted || !cardManager.isAnnouncementPhase) return;

      final roomId = data['roomId'] as String? ?? data['room_id'] as String?;
      if (roomId?.toString() != gameSession.roomId?.toString()) return;

      final announcements = data['announcements'];
      if (announcements is! Map) return;

      print('📥 Événement announcements_adjusted reçu: $data');
      syncAnnouncementsFromBackendMap(
        Map<String, dynamic>.from(announcements),
        announcementsAdjusted: true,
      );
      registerScoreboardFromSyncedAnnouncements();
      if (mounted) setState(() {});
    });

    roomChatMessageSubscription = wsService.onRoomChatMessage().listen((data) {
      if (mounted) {
        final playerName = data['playerName'] as String? ?? data['player_name'] as String?;
        final message = data['message'] as String?;
        final messageType = data['message_type'] as String? ?? 'text';
        final roomId = data['roomId'] as String? ?? data['room_id'] as String?;
        final messageIdRaw = data['id'] ?? data['message_id'] ?? data['messageId'];
        final messageId = _normalizeMessageId(messageIdRaw);

        // ✅ LOG: Réception d'un message via WebSocket
        print('📥 RÉCEPTION MESSAGE CHAT VIA WEBSOCKET');
        print('   Expéditeur reçu: $playerName');
        print('   Expéditeur actuel: ${widget.currentPlayerName}');
        print('   Est l\'expéditeur: ${playerName == widget.currentPlayerName}');
        print('   Message: $message');
        print('   RoomId reçu: $roomId');
        print('   RoomId actuel: ${gameSession.roomId}');
        print('   MessageId: $messageId');

        // ✅ TRAITEMENT SPÉCIAL: Message système "REDISTRIBUTE_CARDS"
        if (message == 'REDISTRIBUTE_CARDS' && messageType == 'system') {
          // ✅ Seul le créateur peut redistribuer les cartes
          final isCreator = gameSession.players.any(
            (p) => (p['name'] as String?) == widget.currentPlayerName &&
                (p['isCreator'] as bool?) == true,
          );
          
          if (isCreator && mounted) {
            print('🔄 Message REDISTRIBUTE_CARDS reçu - Redistribution des cartes par le créateur');
            // Ne pas ajouter ce message au chat, c'est un message système
            // Redistribuer les cartes seulement si le jeu n'a pas encore démarré
            // ou si c'est une nouvelle manche
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                try {
                  // ✅ Vérifier que le jeu n'est pas en cours (sauf si c'est une nouvelle manche)
                  final playerCards = cardManager.getPlayerCards(widget.currentPlayerName);
                  if (playerCards.isEmpty || !hasGameStarted) {
                    print('✅ Redistribution autorisée (cartes vides ou jeu non démarré)');
                    startCardDistribution();
                  } else {
                    print('⚠️ Redistribution ignorée: le jeu a déjà démarré et le joueur a des cartes');
                  }
                } catch (e) {
                  print('❌ Erreur lors de la redistribution: $e');
                }
              }
            });
            return; // Ne pas traiter comme un message de chat normal
          } else {
            print('ℹ️ Message REDISTRIBUTE_CARDS ignoré (pas le créateur ou widget non monté)');
            return; // Ignorer si ce n'est pas le créateur
          }
        }
        
        // ✅ Accepter TOUS les messages (y compris ceux de l'expéditeur) pour garantir la visibilité
        // La déduplication sera gérée par _ingestChatMessages via _knownChatMessageIds
        if (playerName != null && 
            message != null && 
            roomId == gameSession.roomId) {
          print('   ✅ Conditions remplies, ajout du message...');
          final messageData = <String, dynamic>{
            'id': messageId ?? DateTime.now().millisecondsSinceEpoch,
            'user_id': null,
            'pseudo': playerName,
            'message': message,
            'message_type': messageType,
            if (data['preset_code'] != null) 'preset_code': data['preset_code'],
            'created_at': DateTime.now().toIso8601String(),
          };

          _ingestChatMessages([messageData]);
        } else {
          print('   ❌ Conditions non remplies:');
          if (playerName == null) print('      - playerName est null');
          if (message == null) print('      - message est null');
          if (roomId != gameSession.roomId) print('      - roomId ne correspond pas: $roomId vs ${gameSession.roomId}');
        }
      }
    });


    // ✅ Écouter trick_completed : resync cartes + compteurs backend, puis animation
    _trickCompletedSubscription = wsService.onTrickCompleted().listen((data) {
      if (!mounted) return;
      _onTrickCompletedFromWebSocket(Map<String, dynamic>.from(data));
    });

    // ✅ Écouter l'événement round_completed_broadcast pour synchroniser le tableau de scores
    // Note: Les scores sont maintenant calculés par le backend et reçus via round_scores_updated
    _roundCompletedSubscription = wsService.onRoundCompleted().listen((data) {
      if (!mounted) return;
      
      final roomId = data['roomId'] as String? ?? data['room_id'] as String?;
      final roundNumber = data['roundNumber'] as int? ?? data['round_number'] as int?;
      final scores = data['scores'] as Map<String, dynamic>?;
      final announcedByPlayer = data['announcedByPlayer'] as Map<String, dynamic>?;
      final obtainedByPlayer = data['obtainedByPlayer'] as Map<String, dynamic>?;
      
      // ✅ NOUVEAU: Récupérer les scores globaux depuis le backend
      Map<String, dynamic>? globalScores;
      final globalScoresRaw = data['global_scores'] ?? data['globalScores'];
      if (globalScoresRaw is Map) {
        globalScores = globalScoresRaw as Map<String, dynamic>?;
      } else if (globalScoresRaw is List) {
        globalScores = {};
        print('⚠️ GlobalScores reçus comme List dans round_completed, conversion en Map');
      }
      
      if (roomId == gameSession.roomId && roundNumber != null) {
        print('📊 Round $roundNumber terminé - Synchronisation du tableau de scores');
        
        // ✅ Convertir les données reçues
        final players = gameSession.players
            .map((p) => p['name'] as String? ?? 'Joueur')
            .toList();
        
        final announcedMap = <String, int>{};
        final obtainedMap = <String, int>{};
        final scoresMap = <String, int>{};
        
        for (final player in players) {
          if (announcedByPlayer != null) {
            announcedMap[player] = (announcedByPlayer[player] as num?)?.toInt() ?? 0;
          }
          if (obtainedByPlayer != null) {
            obtainedMap[player] = (obtainedByPlayer[player] as num?)?.toInt() ?? 0;
          }
          // ✅ Utiliser les scores du backend s'ils sont disponibles
          if (scores != null) {
            scoresMap[player] = (scores[player] as num?)?.toInt() ?? 0;
          }
        }
        
        // ✅ Synchroniser les compteurs de plis obtenus si fournis
        if (obtainedByPlayer != null) {
          for (final entry in obtainedByPlayer.entries) {
            final playerName = entry.key as String;
            final count = (entry.value as num?)?.toInt() ?? 0;
            cardManager.setObtainedTricks(playerName, count);
          }
        }
        
        // ✅ CRITIQUE: Mettre à jour les scores globaux (compteurs de cristal) depuis le backend
        // Cela garantit que tous les joueurs voient les mêmes scores en temps réel
        if (globalScores != null && globalScores.isNotEmpty) {
          print('💎 Synchronisation des scores globaux depuis round_completed_broadcast');
          for (int i = 0; i < players.length; i++) {
            final playerName = players[i];
            final globalScore = globalScores[playerName] as num?;
            
            if (globalScore != null && i < gameSession.globalScores.length) {
              final oldScore = gameSession.globalScores[i];
              gameSession.globalScores[i] = globalScore.toDouble();
              print('💎 Score global mis à jour pour $playerName: ${oldScore.toInt()} → ${globalScore.toInt()}');
            }
          }
        } else {
          // ✅ Fallback: Si le backend n'envoie pas global_scores, recalculer localement
          print('⚠️ GlobalScores non fourni par le backend, recalcul local');
          if (obtainedMap.isNotEmpty && announcedMap.isNotEmpty && roundNumber > 0) {
            final roundIndex = roundNumber - 1;
            if (roundIndex >= 0 && roundIndex < gameSession.roundsData.length) {
              final obtainedList = players
                  .map((p) => obtainedMap[p] ?? 0)
                  .toList();
              
              // S'assurer que le round a les bonnes annonces
              final round = gameSession.roundsData[roundIndex];
              if (round['announcements'] == null || (round['announcements'] as List).isEmpty) {
                final announcementsList = players
                    .map((p) => announcedMap[p] ?? 0)
                    .toList();
                round['announcements'] = announcementsList;
              }
              
              // Recalculer les scores globaux
              gameSession.finalizeRound(roundIndex, obtainedList);
              print('💎 Scores globaux recalculés localement pour Round $roundNumber');
            }
          }
        }
        
        // ✅ Mettre à jour l'UI pour refléter les nouveaux scores globaux
        if (mounted) {
          setState(() {
            // Les scores globaux sont maintenant à jour dans gameSession.globalScores
            // Le compteur de cristal se mettra à jour automatiquement via getPlayerGlobalScore
          });
        }
        
        // ✅ Afficher le tableau de scores immédiatement (il se fermera automatiquement après 5 secondes)
        if (mounted && scoresMap.isNotEmpty) {
          showScoreboardDialog(
            players,
            announcedMap.isNotEmpty ? announcedMap : {},
            obtainedMap.isNotEmpty ? obtainedMap : {},
            scoresMap,
            autoClose: true, // ✅ Fermeture automatique à la fin d'une manche
          );
          
          // ✅ Après la fermeture du tableau, démarrer une nouvelle manche si la partie n'est pas terminée
          Future.delayed(const Duration(seconds: 6), () async {
            if (!mounted) return;
            
            // Vérifier si la partie est terminée
            final winnerIndex = gameSession.globalScores.indexWhere((s) => s >= 150);
            final completedRounds = gameSession.roundsData
                .where((r) => (r['isCompleted'] as bool?) == true)
                .length;
            final isGameOver = winnerIndex != -1 || completedRounds >= 10;
            
            if (!isGameOver) {
              print('🔄 Démarrage automatique d\'une nouvelle manche après affichage du tableau de scores');
              await startNewRound();
            } else {
              print('🎯 Partie terminée, pas de nouvelle manche');
            }
          });
        }
      }
    });

    // ✅ Écouter l'événement round_scores_updated pour mettre à jour les scores en temps réel
    _roundScoresUpdatedSubscription = wsService.onRoundScoresUpdated().listen((data) {
      if (!mounted) return;
      
      final roomId = data['roomId'] as String? ?? data['room_id'] as String?;
      final roundId = data['round_id'] as int?;
      final roundNumber = _parseRoundNumber(data['round_number']);
      
      // ✅ Gérer le cas où scores peut être une List ou une Map
      final scoresRaw = data['scores'];
      Map<String, dynamic>? scores;
      if (scoresRaw is Map) {
        scores = scoresRaw as Map<String, dynamic>?;
      } else if (scoresRaw is List) {
        // Si c'est une liste, la convertir en Map (cas rare mais possible)
        scores = {};
        print('⚠️ Scores reçus comme List, conversion en Map');
      }
      
      // ✅ Gérer le cas où announcements, obtainedTricks ou globalScores peuvent être des List
      Map<String, dynamic>? announcements;
      final announcementsRaw = data['announcements'];
      if (announcementsRaw is Map) {
        announcements = announcementsRaw as Map<String, dynamic>?;
      } else if (announcementsRaw is List) {
        announcements = {};
        print('⚠️ Announcements reçus comme List, conversion en Map');
      }
      
      Map<String, dynamic>? obtainedTricks;
      final obtainedTricksRaw = data['obtained_tricks'];
      if (obtainedTricksRaw is Map) {
        obtainedTricks = obtainedTricksRaw as Map<String, dynamic>?;
      } else if (obtainedTricksRaw is List) {
        obtainedTricks = {};
        print('⚠️ ObtainedTricks reçus comme List, conversion en Map');
      }
      
      Map<String, dynamic>? globalScores;
      final globalScoresRaw = data['global_scores'];
      if (globalScoresRaw is Map) {
        globalScores = globalScoresRaw as Map<String, dynamic>?;
      } else if (globalScoresRaw is List) {
        globalScores = {};
        print('⚠️ GlobalScores reçus comme List, conversion en Map');
      }
      
      if (roomId == gameSession.roomId && scores != null && scores.isNotEmpty) {
        print('📊 Scores mis à jour (round_scores_updated): Round $roundNumber');
        
        // Convertir les scores en Map<String, int>
        final scoresMap = <String, int>{};
        for (final entry in scores.entries) {
          scoresMap[entry.key as String] = (entry.value as num?)?.toInt() ?? 0;
        }
        
        // Convertir les annonces et plis obtenus
        final announcedMap = <String, int>{};
        final obtainedMap = <String, int>{};
        
        if (announcements != null) {
          for (final entry in announcements.entries) {
            announcedMap[entry.key as String] = (entry.value as num?)?.toInt() ?? 0;
          }
        }
        
        // ⚠️ NOTE: On ne synchronise PAS les compteurs depuis round_scores_updated
        // Les compteurs sont mis à jour uniquement lors de trick_completed pour le gagnant
        // Cela évite les désynchronisations et les écrasements de valeurs locales
        if (obtainedTricks != null) {
          for (final entry in obtainedTricks.entries) {
            final playerName = entry.key as String;
            final serverCount = (entry.value as num?)?.toInt() ?? 0;
            obtainedMap[playerName] = serverCount;
            // ⚠️ On ne met PAS à jour les compteurs locaux ici
            // Ils sont mis à jour uniquement lors de trick_completed pour le gagnant
          }
        }
        
        // ✅ CRITIQUE: Mettre à jour les scores globaux (compteur de cristal) depuis le backend
        // Les scores globaux doivent être synchronisés en temps réel pour tous les joueurs
        if (globalScores != null && globalScores.isNotEmpty) {
          // ✅ Si le backend envoie global_scores, les utiliser directement (source de vérité)
          print('💎 Synchronisation des scores globaux depuis round_scores_updated');
          final players = gameSession.players
              .map((p) => p['name'] as String? ?? 'Joueur')
              .toList();
          
          for (int i = 0; i < players.length; i++) {
            final playerName = players[i];
            final globalScore = globalScores[playerName] as num?;
            
            if (globalScore != null && i < gameSession.globalScores.length) {
              final oldScore = gameSession.globalScores[i];
              gameSession.globalScores[i] = globalScore.toDouble();
              if (oldScore != globalScore.toDouble()) {
                print('💎 Score global mis à jour pour $playerName: ${oldScore.toInt()} → ${globalScore.toInt()}');
              }
            }
          }
        } else if (obtainedMap.isNotEmpty && announcedMap.isNotEmpty && roundNumber != null) {
          // ✅ Fallback: Si le backend n'envoie pas global_scores, recalculer localement
          // Note: round_scores_updated est envoyé après chaque trick, mais on ne met à jour
          // les scores globaux qu'à la fin du round (trick 13) pour éviter les calculs répétés
          final players = gameSession.players
              .map((p) => p['name'] as String? ?? 'Joueur')
              .toList();
          
          // Vérifier si c'est la fin du round (trick 13)
          // On peut le détecter en vérifiant si tous les joueurs ont obtenu 13 plis au total
          final totalObtained = obtainedMap.values.fold<int>(0, (sum, val) => sum + (val ?? 0));
          final isRoundComplete = totalObtained >= 13 * players.length;
          
          if (isRoundComplete) {
            // Fallback: Si le backend n'envoie pas global_scores et que le round est complet,
            // utiliser finalizeRound pour calculer et mettre à jour les scores globaux
            final obtainedList = players
                .map((p) => obtainedMap[p] ?? 0)
                .toList();
            
            // S'assurer que le round existe dans roundsData
            final roundIndex = roundNumber - 1;
            if (roundIndex >= 0 && roundIndex < gameSession.roundsData.length) {
              // Mettre à jour les annonces du round si nécessaire
              final round = gameSession.roundsData[roundIndex];
              if (round['announcements'] == null || (round['announcements'] as List).isEmpty) {
                final announcementsList = players
                    .map((p) => announcedMap[p] ?? 0)
                    .toList();
                round['announcements'] = announcementsList;
              }
              
              // Appeler finalizeRound pour mettre à jour globalScores
              gameSession.finalizeRound(roundIndex, obtainedList);
              print('💎 Scores globaux recalculés via finalizeRound pour Round $roundNumber');
            }
          }
        }
        
        // Mettre à jour l'affichage si nécessaire
        if (mounted) {
          setState(() {
            // Le compteur de cristal se mettra à jour automatiquement via getPlayerGlobalScore
          });
        }
      }
    });

    // ✅ NOUVEAU: Écouter l'événement turn_changed pour synchroniser le tour depuis le backend
    // Cela garantit que tous les clients sont synchronisés même si la réponse HTTP est perdue
    _turnChangedSubscription = wsService.onTurnChanged().listen((data) {
      if (!mounted) return;
      
      final roomId = data['roomId'] as String? ?? data['room_id'] as String?;
      final currentPlayerName = data['current_player_name'] as String? ?? data['currentPlayerName'] as String?;
      
      if (roomId != gameSession.roomId || currentPlayerName == null || currentPlayerName.isEmpty) {
        return;
      }

      if (isCollectingTrick ||
          cardManager.currentTrick.length >= cardManager.expectedPlayerCount) {
        print(
          'ℹ️ turn_changed ignoré: pli complet ou collecte en cours '
          '(${cardManager.currentTrick.length}/${cardManager.expectedPlayerCount})',
        );
        return;
      }
      
      // ✅ Synchroniser le tour depuis le backend
      if (cardManager.currentPlayerTurn != currentPlayerName) {
        print('🔄 Tour synchronisé via WebSocket (turn_changed): $currentPlayerName');
        cardManager.currentPlayerTurn = currentPlayerName;
        
        if (mounted) {
          if (currentPlayerName == widget.currentPlayerName) {
            setState(() {
              _playableCardCodes.clear();
              _playableCardsReady = false;
            });
            _updatePlayableCardsFromBackend(force: true);
          } else {
            setState(() {
              _playableCardCodes.clear();
              _playableCardsReady = false;
            });
          }
          setState(() {});

          startPlayerTurnTimeout();

          if (!serverDrivesBots && currentPlayerPlaying == null) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted && currentPlayerPlaying == null) {
                maybeAutoPlayCurrentBot();
              }
            });
          }
        }
      }
    });

    cardPlayedSubscription = wsService.onCardPlayed().listen((data) {
      if (mounted) {
        final playerName = data['playerName'] as String? ?? data['player_name'] as String?;
        final cardData = data['card'] as Map<String, dynamic>?;
        final roomId = data['roomId'] as String? ?? data['room_id'] as String?;

        if (playerName != null && 
            cardData != null && 
            roomId == gameSession.roomId) {
          
          // ✅ Mettre à jour les cartes jouables si c'est le tour du joueur local après qu'une carte soit jouée
          if (cardManager.currentPlayerTurn == widget.currentPlayerName) {
            _updatePlayableCardsFromBackend();
          }
          
          // ✅ CORRECTION: Ignorer l'événement pour le joueur local (évite double animation)
          if (playerName == widget.currentPlayerName) {
            // Vérifier si c'est un événement local qu'on a déjà traité
            final cardSuitShort = (cardData['suit'] as String? ?? '').toUpperCase();
            final cardValueShort = (cardData['value'] as String? ?? '').toUpperCase();
            final normalizedValue = cardValueShort == '10' ? '0' : cardValueShort;
            final cardCode = '$normalizedValue$cardSuitShort';
            final trickNumber =
                (data['trickNumber'] as int?) ?? (data['trick_number'] as int?) ?? cardManager.currentTrickNumber;
            final eventKey = buildCardEventKey(playerName, cardCode, trickNumber);
            
            if (consumeLocalCardEvent(eventKey)) {
              print('ℹ️ Événement WebSocket ignoré pour joueur local $playerName (carte $cardCode déjà jouée localement)');
              return;
            }
            // Si l'événement local n'a pas été consommé, ignorer quand même pour éviter double animation
            print('ℹ️ Événement WebSocket ignoré pour joueur local $playerName (évite double animation)');
            return;
          }
          
          // ✅ NOUVEAU: Construire cardCode immédiatement
          final cardSuitShort = (cardData['suit'] as String? ?? '').toUpperCase();
          final cardValueShort = (cardData['value'] as String? ?? '').toUpperCase();
          final normalizedValue = cardValueShort == '10' ? '0' : cardValueShort;
          final cardCode = '$normalizedValue$cardSuitShort';
          final trickNumber =
              (data['trickNumber'] as int?) ?? (data['trick_number'] as int?) ?? cardManager.currentTrickNumber;
          final activeTrickNumber = _trickNumberForApi();
          if (trickNumber != activeTrickNumber &&
              trickNumber != cardManager.currentTrickNumber) {
            print(
              '⚠️ card_played ignoré: pli #$trickNumber vs actif '
              '#$activeTrickNumber (local #${cardManager.currentTrickNumber})',
            );
            unawaited(_resyncCurrentTrickFromBackend());
            return;
          }
          final eventKey = buildCardEventKey(playerName, cardCode, trickNumber);
          
          // ✅ Vérifier d'abord si c'est un événement local qu'on a déjà traité
          if (consumeLocalCardEvent(eventKey)) {
            print('ℹ️ Carte $cardCode de $playerName déjà appliquée localement (echo WebSocket ignoré)');
            return;
          }
          
          // ✅ IMPORTANT: Vérifier si c'est un bot AVANT de vérifier le tour
          // Car les bots jouent automatiquement et on ne doit pas les attendre
          final isBotPlayer = gameSession.players.any((p) {
            final name = p['name'] as String?;
            if (name != playerName) return false;
            
            final isBotValue = p['isBot'];
            if (isBotValue == true || isBotValue == 1 || (isBotValue is String && isBotValue == '1')) {
              return true;
            }
            
            final is_botValue = p['is_bot'];
            if (is_botValue == true || is_botValue == 1 || (is_botValue is String && is_botValue == '1')) {
              return true;
            }
            
            final isReplacementBotValue = p['isReplacementBot'];
            if (isReplacementBotValue == true || isReplacementBotValue == 1 || (isReplacementBotValue is String && isReplacementBotValue == '1')) {
              return true;
            }
            
            return false;
          });
          
          // ✅ VÉRIFIER QUE LA CARTE N'A PAS DÉJÀ ÉTÉ JOUÉE (pour tous les joueurs, bots et humains)
          final currentTrick = cardManager.currentTrick;
          final cardAlreadyPlayed = currentTrick.any(
            (entry) {
              final entryCard = entry['card'] as Map<String, dynamic>?;
              final entryPlayer = entry['player'] as String?;
              return entryCard != null &&
                  entryPlayer == playerName &&
                  (entryCard['code'] as String?) == cardCode;
            },
          );
          
          if (cardAlreadyPlayed) {
            // Pour les bots : la carte a été ajoutée localement, ignorer l'événement WebSocket
            // Pour les humains : la carte a déjà été traitée, ignorer
            if (isBotPlayer) {
              print('ℹ️ Carte $cardCode de bot $playerName déjà dans le trick (ajoutée localement) - événement WebSocket ignoré pour éviter doublon');
            } else {
              print('⚠️ Carte $cardCode déjà jouée par $playerName dans le trick actuel - IGNORÉE');
            }
            return;
          }
          
          // ✅ CORRECTION: Pour les bots, on NE DOIT PAS ignorer l'événement WebSocket si la carte n'est pas encore dans le trick
          // Car les autres clients (Alpha, Elias) doivent voir les cartes des bots
          if (isBotPlayer) {
            print('📨 Carte de bot $playerName reçue via WebSocket: $cardCode (synchronisation pour autres clients)');
          } else {
            print('📨 Carte reçue via WebSocket: $cardCode pour $playerName');
          }
          
          // ✅ POUR LES JOUEURS HUMAINS: Vérifier maintenant le tour
          // ⚠️ Mais ne pas sortir immédiatement si ce n'est pas le tour
          // Car le tour peut avoir changé entre l'émission et la réception
          // Juste logger et continuer
          if (!isBotPlayer && cardManager.currentPlayerTurn != playerName) {
            print('⚠️ Tour désynchronisé: reçu carte de $playerName mais le tour est ${cardManager.currentPlayerTurn}');
            print('   Cela peut se produire si le tour a changé après l\'envoi de la carte');
            print('   On continue quand même - ajouter la carte et synchroniser le tour');
          }
          
          // Construire la carte depuis le backend (main locale parfois désynchronisée)
          Map<String, dynamic>? validCard;
          if (!isBotPlayer) {
            final playerCards = cardManager.getPlayerCards(playerName);
            print('   Cartes de $playerName: ${playerCards.map((c) => c['code']).join(", ")}');

            try {
              validCard = playerCards.firstWhere(
                (c) => (c['code'] as String?)?.toUpperCase() == cardCode,
              );
            } catch (_) {
              print(
                '⚠️ Carte $cardCode absente de la main locale de $playerName '
                '— utilisation du code backend',
              );
              validCard = _cardMapFromCode(cardCode);
            }
          } else {
            // Pour les bots, construire la carte depuis les données WebSocket
            final cardSuitShort = (cardData['suit'] as String? ?? '').toUpperCase();
            final cardValueShort = (cardData['value'] as String? ?? '').toUpperCase();
            final suitMapping = {
              'S': 'SPADES',
              'C': 'CLUBS',
              'H': 'HEARTS',
              'D': 'DIAMONDS',
            };
            final valueMapping = {
              'A': 'ACE',
              'K': 'KING',
              'Q': 'QUEEN',
              'J': 'JACK',
              '0': '10',
            };
            final suitName = suitMapping[cardSuitShort] ?? cardSuitShort;
            final valueName = valueMapping[cardValueShort] ?? cardValueShort;
            
            // Construire la carte complète
            validCard = {
              'code': cardCode,
              'suit': suitName,
              'value': valueName,
              'image': 'assets/images/cards/${suitName.toLowerCase()}_${cardValueShort == '0' ? '10' : cardValueShort}.png',
            };
            print('   Carte de bot construite depuis WebSocket: $cardCode');
          }

          if (!markCardEventProcessedIfNew(eventKey)) {
            print('⚠️ Événement carte $cardCode de $playerName déjà traité - IGNORÉ');
            return;
          }

          // ✅ AJOUTER LA CARTE AU TRICK (pour tous les joueurs : humains et bots)
          // Cela garantit que tous les clients voient les cartes, même celles des bots
          if (validCard == null) {
            print('❌ ERREUR: validCard est null pour $playerName - impossible d\'ajouter au trick');
            return;
          }
          print('✅ Ajout de la carte $cardCode au trick pour $playerName (${isBotPlayer ? "bot" : "humain"})');
          // ✅ CORRECTION: Utiliser addCardToTrick() au lieu de playCard()
          // car le tour a peut-être déjà changé via WebSocket
          cardManager.addCardToTrick(playerName, validCard);
          cardManager.currentPlayerTurn = playerName; // ✅ Synchroniser le tour
          
          // ✅ DEBUG: Vérifier que la carte a bien été ajoutée au trick
          final verifyTrick = cardManager.currentTrick;
          final cardFound = verifyTrick.any((entry) {
            final card = entry['card'] as Map<String, dynamic>?;
            final entryPlayer = entry['player'] as String?;
            return entryPlayer == playerName && (card?['code'] as String?) == cardCode;
          });
          
          if (!cardFound) {
            print('❌ ERREUR: Carte $cardCode de $playerName n\'a PAS été ajoutée au trick !');
            print('   Trick actuel: ${verifyTrick.map((e) => '${e['player']}→${e['card']?['code']}').join(", ")}');
          } else {
            print('✅ Vérification: Carte $cardCode de $playerName bien présente dans le trick');
          }
          
          if (mounted) {
            setState(() {});
            print('✅ setState() appelé après ajout de carte au trick');
          }
          
          // ✅ Vérifier si le pli est complet (4 cartes)
          final updatedTrick = cardManager.currentTrick;
          if (updatedTrick.length >= cardManager.expectedPlayerCount) {
            print('🕒 Pli complété (4 cartes) - attente de trick_completed du backend');
            _onTrickMayBeComplete();
          } else {
            print('   Pli incomplet: ${updatedTrick.length}/4 cartes');
          }
          
          // ✅ Ne plus faire d'animation pour les joueurs distants - la carte est déjà ajoutée
          // L'animation sera gérée par le backend via WebSocket si nécessaire
          
          // ✅ Vérifier si le prochain joueur est un bot et déclencher le jeu automatique
          final nextPlayer = cardManager.currentPlayerTurn;
          if (nextPlayer.isNotEmpty && nextPlayer != playerName) {
            // ✅ Accepter à la fois true (booléen) et 1 (entier) comme valeur "bot"
            final isNextPlayerBot = gameSession.players.any(
              (p) {
                final name = (p['name'] as String?);
                if (name != nextPlayer) return false;
                final isReplacementBotValue = p['isReplacementBot'];
                final isBotValue = p['is_bot'] ?? p['isBot'];
                final isReplacement = isReplacementBotValue == true || isReplacementBotValue == 1 || (isReplacementBotValue is String && isReplacementBotValue == '1');
                final isBot = isBotValue == true || isBotValue == 1 || (isBotValue is String && isBotValue == '1');
                return isReplacement || isBot;
              },
            );
            
            if (isNextPlayerBot) {
              print('🔄 Appel maybeAutoPlayCurrentBot après carte distante (bot suivant: $nextPlayer)');
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted && currentPlayerPlaying == null) {
                  maybeAutoPlayCurrentBot();
                }
              });
            } else {
              print('👤 Pas d\'appel automatique: $nextPlayer est un joueur humain');
            }
          }
        }
      }
    });
    setState(() {
      isWebSocketConnected = wsService.isConnected;
    });

    final roomId = gameSession.roomId;
    final playerName = widget.currentPlayerName;

    if (!wsService.isConnected) {
      wsService.connect().then((_) {
        if (roomId != null && roomId.isNotEmpty && playerName.isNotEmpty) {
          wsService.joinRoom(roomId, playerName).catchError((error) {
            print('⚠️ Erreur lors de la jointure de la room WebSocket: $error');
          });
        }
      }).catchError((error) {
        print('⚠️ Impossible de se connecter au WebSocket: $error');
        if (mounted) _restartRoomSyncPolling(forceRestart: true);
      });
    } else if (roomId != null && roomId.isNotEmpty && playerName.isNotEmpty) {
      wsService.joinRoom(roomId, playerName).catchError((error) {
        print('⚠️ Erreur lors de la jointure de la room WebSocket: $error');
      });
    }
  }


  /// Méthode utilitaire pour ajouter un log de débogage (pour l'UI et la console)
  void _addDebugLog(String log) {
    if (!kDebugMode) return;

    final timestamp = DateTime.now().toIso8601String().substring(11, 23); // HH:mm:ss.sss

    final formattedLog = '[$timestamp] $log';

    if (mounted) {
      setState(() {
        _debugLogs.insert(0, formattedLog); // Ajouter au début
        if (_debugLogs.length > _maxLogs) {
          _debugLogs.removeLast(); // Maintenir la taille max
        }
      });
    }
  }

  /// Implémentation de la méthode abstraite:
  /// Récupère la liste des codes de cartes jouables pour le joueur actuel depuis le backend.
  @override
  Future<void> _updatePlayableCardsFromBackend({bool force = false}) async {
    // 🚀 OPTIMISATION: Calculer les cartes jouables localement et instantanément
    // au lieu de faire 4 appels réseau qui ralentissaient considérablement l'affichage.
    
    final playerName = widget.currentPlayerName;
    if (playerName.isEmpty || playerName != cardManager.currentPlayerTurn) {
      if (mounted) {
        setState(() {
          _playableCardCodes.clear();
          _playableCardsReady = false;
        });
      }
      return;
    }

    try {
      gameLogic.syncCurrentTrick(cardManager.currentTrick);
      final playerCards = cardManager.getPlayerCards(playerName);
      
      final playableCards = gameLogic.getPlayableCards(
        playerCards,
        playerName,
        gameLogic.currentTrick.isEmpty,
      );

      final playableCardCodes = playableCards.map((c) => c['code'] as String).toSet();

      final message = '✅ Cartes jouables calculées localement : ${playableCardCodes.length} cartes. Codes: ${playableCardCodes.take(5).join(', ')}...';
      _addDebugLog(message);
      print(message); // Console log

      if (mounted) {
        setState(() {
          _playableCardCodes = playableCardCodes;
          _playableCardsReady = true;
          _isUpdatingPlayableCards = false;
        });
      }
    } catch (e) {
      final errorMsg = '❌ Erreur lors du calcul local des cartes jouables: $e';
      _addDebugLog(errorMsg);
      print(errorMsg); // Console log
      if (mounted) {
        setState(() {
          _playableCardCodes.clear();
          _playableCardsReady = false;
          _isUpdatingPlayableCards = false;
        });
      }
    }
  }

  // ✅ Méthode publique helper pour être accessible dans les closures
  Future<void> updatePlayableCardsFromBackend() async {
    return _updatePlayableCardsFromBackend();
  }

  int? _lastProcessedTrickCompletedNumber;
  int? _activeBackendTrickNumber;
  Timer? _trickCompletionWatchdog;

  void _onTrickMayBeComplete() {
    if (cardManager.currentTrick.length < cardManager.expectedPlayerCount) {
      return;
    }
    _scheduleTrickCompletionWatchdog();
  }

  void _scheduleTrickCompletionWatchdog() {
    _trickCompletionWatchdog?.cancel();
    _trickCompletionWatchdog = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      unawaited(_recoverTrickCompletionFromBackend());
    });
  }

  /// Fallback si trick_completed WebSocket n'arrive pas alors que 4 cartes sont au centre.
  Future<void> _recoverTrickCompletionFromBackend() async {
    if (!mounted || isCollectingTrick) return;

    final expected = cardManager.expectedPlayerCount;
    if (cardManager.currentTrick.length < expected) return;

    final currentTrickNum = _trickNumberForApi();
    if (_lastProcessedTrickCompletedNumber == currentTrickNum) return;

    final roomId = gameSession.roomId;
    if (roomId == null || roomId.isEmpty) return;

    print('🩹 Watchdog: récupération fin de pli #$currentTrickNum via API');
    _addDebugLog('🩹 Watchdog fin de pli #$currentTrickNum');

    try {
      final trickData = await GameApiService.instance.getCurrentTrick(
        roomId: roomId,
        roundNumber: _effectiveRoundNumber(),
        trickNumber: currentTrickNum.clamp(1, 13),
      );

      if (trickData['success'] != true) return;

      final rawData = trickData['data'];
      if (rawData is! Map) return;
      final data = Map<String, dynamic>.from(rawData);

      final status = data['trick_status'] as String? ?? 'in_progress';
      final winnerName = data['winner_name'] as String?;
      final cardsInTrick = (data['cards_in_trick'] as num?)?.toInt() ?? 0;

      if (status == 'completed' &&
          winnerName != null &&
          winnerName.isNotEmpty &&
          cardsInTrick >= expected) {
        await _onTrickCompletedFromWebSocket({
          'roomId': roomId,
          'winner_name': winnerName,
          'current_trick_number': currentTrickNum,
          'next_trick_number': data['next_trick_number'],
          'obtained_tricks': data['obtained_tricks'],
          'trick_cards': data['played_cards'],
        });
        return;
      }

      if (cardsInTrick >= expected && status != 'completed') {
        print('⚠️ Watchdog: pli #$currentTrickNum toujours bloqué — nouvelle tentative');
        _scheduleTrickCompletionWatchdog();
      }
    } catch (e) {
      print('⚠️ Watchdog fin de pli: $e');
    }
  }

  @override
  void onTrickCompletedPlayCardResponse() {
    _onTrickMayBeComplete();
  }

  int _trickNumberForApi() {
    if (_activeBackendTrickNumber != null && _activeBackendTrickNumber! > 0) {
      return _activeBackendTrickNumber!;
    }
    return cardManager.currentTrickNumber > 0 ? cardManager.currentTrickNumber : 1;
  }

  @override
  Future<int?> getTrickIdForCurrentTrick() async {
    try {
      final roomId = gameSession.roomId;
      if (roomId == null || roomId.isEmpty) return null;

      final roundNumber = _effectiveRoundNumber();
      final trickNumber = _trickNumberForApi().clamp(1, 13);

      final trickData = await GameApiService.instance.getCurrentTrick(
        roomId: roomId,
        roundNumber: roundNumber,
        trickNumber: trickNumber,
      );

      if (trickData['success'] == true) {
        final rawData = trickData['data'];
        if (rawData is Map) {
          final data = Map<String, dynamic>.from(rawData);
          final backendTrickNumber = (data['trick_number'] as num?)?.toInt();
          if (backendTrickNumber != null) {
            _activeBackendTrickNumber = backendTrickNumber;
            if (backendTrickNumber != cardManager.currentTrickNumber) {
              cardManager.setCurrentTrickNumber(backendTrickNumber);
            }
          }
          return data['trick_id'] as int?;
        }
      }
      return null;
    } catch (e) {
      print('⚠️ Erreur lors de la récupération du trick_id: $e');
      return null;
    }
  }

  /// Construit une carte jouable à partir d'un code (ex: 7H, AS).
  Map<String, dynamic> _cardMapFromCode(String cardCode) {
    final code = cardCode.toUpperCase();
    final suitShort = code.substring(code.length - 1);
    final valueShort = code.substring(0, code.length - 1);
    const suitMapping = {
      'S': 'SPADES',
      'C': 'CLUBS',
      'H': 'HEARTS',
      'D': 'DIAMONDS',
    };
    const valueMapping = {
      'A': 'ACE',
      'K': 'KING',
      'Q': 'QUEEN',
      'J': 'JACK',
      '0': '10',
    };
    final suitName = suitMapping[suitShort] ?? suitShort;
    final valueName = valueMapping[valueShort] ?? valueShort;
    return {
      'code': code,
      'suit': suitName,
      'value': valueName,
      'image': 'assets/images/cards/${suitName.toLowerCase()}_$valueName.png',
    };
  }

  /// Resynchronise le pli et le tour depuis GET get-current-trick (source de vérité).
  Future<void> _resyncCurrentTrickFromBackend() async {
    if (isCollectingTrick) {
      print('ℹ️ Resync pli ignoré: animation de collecte en cours');
      return;
    }

    final roomId = gameSession.roomId;
    if (roomId == null || roomId.isEmpty) return;

    try {
      final roundNumber = _effectiveRoundNumber();
      final trickNumber = _trickNumberForApi().clamp(1, 13);

      final trickData = await GameApiService.instance.getCurrentTrick(
        roomId: roomId,
        roundNumber: roundNumber,
        trickNumber: trickNumber,
      );

      if (trickData['success'] != true) return;

      final rawData = trickData['data'];
      if (rawData is! Map) return;
      final data = Map<String, dynamic>.from(rawData);

      final backendTrickNumber = (data['trick_number'] as num?)?.toInt();
      if (backendTrickNumber != null) {
        _activeBackendTrickNumber = backendTrickNumber;
        if (backendTrickNumber != cardManager.currentTrickNumber) {
          cardManager.setCurrentTrickNumber(backendTrickNumber);
        }
      }

      final trickStatus = data['trick_status'] as String? ?? 'in_progress';
      final winnerName = data['winner_name'] as String?;
      final backendCount = (data['cards_in_trick'] as num?)?.toInt() ?? 0;
      final expected = cardManager.expectedPlayerCount;

      if (trickStatus == 'completed' &&
          winnerName != null &&
          winnerName.isNotEmpty &&
          backendCount >= expected &&
          backendTrickNumber != null &&
          _lastProcessedTrickCompletedNumber != backendTrickNumber) {
        print('🩹 Resync: pli #$backendTrickNumber terminé côté backend — clôture locale');
        await _onTrickCompletedFromWebSocket({
          'roomId': roomId,
          'winner_name': winnerName,
          'current_trick_number': backendTrickNumber,
          'next_trick_number': data['next_trick_number'],
          'obtained_tricks': data['obtained_tricks'],
          'trick_cards': data['played_cards'],
        });
        return;
      }

      final currentTurn = data['current_turn'];
      if (currentTurn is Map) {
        final name = (currentTurn['player_name'] ?? currentTurn['playerName'])
            as String?;
        if (name != null && name.isNotEmpty) {
          cardManager.currentPlayerTurn = name;
        }
      }

      final playedRaw = data['played_cards'];
      if (playedRaw is! List) return;

      final entries = _trickEntriesFromPayload(playedRaw);
      final localCount = cardManager.currentTrick.length;
      final payloadCount = entries.length;

      // Pli terminé côté backend : ne pas réinjecter dans un centre vide
      if (payloadCount >= expected && localCount == 0) {
        print(
          'ℹ️ Resync ignoré: pli #$backendTrickNumber terminé — '
          'passage au pli ${(backendTrickNumber ?? trickNumber) + 1}',
        );
        if (backendTrickNumber != null) {
          _activeBackendTrickNumber = backendTrickNumber + 1;
          cardManager.setCurrentTrickNumber(backendTrickNumber + 1);
        }
        return;
      }

      // Compléter uniquement si le backend a plus de cartes (pli en cours)
      if (payloadCount > localCount && payloadCount < expected) {
        _replaceTrickFromBackendPayload(playedRaw);
        gameLogic.syncCurrentTrick(cardManager.currentTrick);
      }
    } catch (e) {
      print('⚠️ resync trick: $e');
    }
  }

  List<Map<String, dynamic>> _trickEntriesFromPayload(List<dynamic> payload) {
    final entries = <Map<String, dynamic>>[];
    for (final raw in payload) {
      if (raw is! Map) continue;
      final playerName = (raw['player_name'] ?? raw['playerName']) as String?;
      final cardCode =
          ((raw['card_code'] ?? raw['cardCode']) as String?)?.toUpperCase();
      if (playerName == null || cardCode == null || cardCode.isEmpty) continue;
      entries.add({
        'player': playerName,
        'card': _cardMapFromCode(cardCode),
        'timestamp': DateTime.now(),
      });
    }
    return entries;
  }

  void _replaceTrickFromBackendPayload(List<dynamic> payload) {
    final entries = _trickEntriesFromPayload(payload);
    if (entries.isEmpty) return;
    cardManager.replaceCurrentTrickFromSync(entries);
    print('🔄 Pli remplacé depuis backend (${entries.length} cartes)');
  }

  /// Synchronise le pli local avec les cartes envoyées par le backend.
  Future<void> _syncTrickCardsFromPayload(List<dynamic> trickCardsPayload) async {
    if (trickCardsPayload.length >= cardManager.expectedPlayerCount) {
      _replaceTrickFromBackendPayload(trickCardsPayload);
      return;
    }

    for (final raw in trickCardsPayload) {
      if (raw is! Map) continue;
      final playerName = (raw['player_name'] ?? raw['playerName']) as String?;
      final cardCode =
          ((raw['card_code'] ?? raw['cardCode']) as String?)?.toUpperCase();
      if (playerName == null || cardCode == null || cardCode.isEmpty) continue;

      final alreadyPresent = cardManager.currentTrick.any((entry) {
        final entryPlayer = entry['player'] as String?;
        final entryCard = entry['card'] as Map<String, dynamic>?;
        return entryPlayer == playerName &&
            (entryCard?['code'] as String?)?.toUpperCase() == cardCode;
      });
      if (alreadyPresent) continue;

      print('🔄 Resync trick: ajout $cardCode pour $playerName (payload backend)');
      cardManager.addCardToTrick(playerName, _cardMapFromCode(cardCode));
    }
  }

  /// Applique les compteurs de plis depuis le backend (source de vérité).
  void _applyObtainedTricksFromBackend(dynamic obtainedTricksRaw) {
    if (obtainedTricksRaw == null) return;

    Map<String, dynamic> obtainedMap;
    if (obtainedTricksRaw is Map) {
      obtainedMap = Map<String, dynamic>.from(obtainedTricksRaw);
    } else if (obtainedTricksRaw is List) {
      print('⚠️ obtained_tricks reçu comme List, conversion ignorée');
      return;
    } else {
      return;
    }

    for (final entry in obtainedMap.entries) {
      final playerName = entry.key;
      final count = (entry.value as num?)?.toInt() ?? 0;
      cardManager.setObtainedTricks(playerName, count);
      print('📊 Compteur backend: $playerName → $count plis');
    }
  }

  /// Traite trick_completed : resync cartes, compteurs backend, puis animation.
  Future<void> _onTrickCompletedFromWebSocket(Map<String, dynamic> data) async {
    if (!mounted) return;

    final roomId = data['roomId'] as String? ?? data['room_id'] as String?;
    final winnerName = data['winnerName'] as String? ?? data['winner_name'] as String?;
    final currentTrickNumber = data['currentTrickNumber'] as int? ??
        data['current_trick_number'] as int?;
    final nextTrickNumber = data['nextTrickNumber'] as int? ??
        data['next_trick_number'] as int?;
    final obtainedTricks = data['obtainedTricks'] ?? data['obtained_tricks'];
    final trickCardsPayload = data['trick_cards'] ?? data['trickCards'];

    if (roomId != gameSession.roomId || winnerName == null || winnerName.isEmpty) {
      return;
    }

    if (currentTrickNumber != null &&
        _lastProcessedTrickCompletedNumber == currentTrickNumber) {
      print('ℹ️ trick_completed #$currentTrickNumber déjà traité — ignoré');
      return;
    }

    final logMsg = '📥 Événement trick_completed reçu: winner=$winnerName, trick=$currentTrickNumber';
    print(logMsg);
    _addDebugLog(logMsg);

    // 1. Compléter le pli local depuis le payload backend si incomplet
    if (trickCardsPayload is List && trickCardsPayload.isNotEmpty) {
      await _syncTrickCardsFromPayload(trickCardsPayload);
    } else {
      int attempts = 0;
      while (attempts < 20 &&
          cardManager.currentTrick.length < cardManager.expectedPlayerCount) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
    }

    // 2. Compteurs depuis le backend (pas d'incrément local)
    _applyObtainedTricksFromBackend(obtainedTricks);

    if (currentTrickNumber != null) {
      _lastProcessedTrickCompletedNumber = currentTrickNumber;
    }

    if (nextTrickNumber != null) {
      _activeBackendTrickNumber = nextTrickNumber;
    } else if (currentTrickNumber != null && currentTrickNumber < 13) {
      _activeBackendTrickNumber = currentTrickNumber + 1;
    }

    final isRoundComplete = (nextTrickNumber != null && nextTrickNumber > 13) ||
        (nextTrickNumber == null &&
            currentTrickNumber != null &&
            currentTrickNumber >= 13) ||
        (currentTrickNumber != null && currentTrickNumber > 13);

    if (isRoundComplete) {
      print('🎉 Dernier trick terminé ! Manche terminée.');
      if (mounted) setState(() {});
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !cardManager.isAnnouncementPhase) {
          onRoundCompleted();
        }
      });
      return;
    }

    if (mounted) {
      setState(() {});
      print('✅ Compteurs synchronisés depuis backend pour trick #$currentTrickNumber');
    }

    // 3. Animation + nettoyage ; le numéro de pli suivant est appliqué après l'animation
    await _handleTrickEnd(
      winnerName,
      currentTrickNumber,
      nextTrickNumber: nextTrickNumber,
    );

    _trickCompletionWatchdog?.cancel();
  }

  /// Méthode dédiée pour gérer la fin d'un pli (animation + nettoyage)
  /// Appelée depuis le listener trick_completed
  Future<void> _handleTrickEnd(
    String winnerName,
    int? trickNumber, {
    int? nextTrickNumber,
  }) async {
    if (!mounted) return;

    final trickCards = cardManager.currentTrick;
    final logMsg1 = '🎬 _handleTrickEnd: winner=$winnerName, trick=$trickNumber, cartes=${trickCards.length}';
    print(logMsg1);
    _addDebugLog(logMsg1);

    // 1. Mettre à jour l'état du gagnant et préparer l'animation
    if (mounted) {
      setState(() {
        lastTrickWinner = winnerName;
        isCollectingTrick = false; // Commencer avec l'animation désactivée
      });
    }

    if (trickCards.isEmpty) {
      final logMsg2 = '⚠️ Trick vide - impossible de déclencher l\'animation de collecte';
      print(logMsg2);
      _addDebugLog(logMsg2);
      cardManager.clearCurrentTrick();
      if (nextTrickNumber != null) {
        cardManager.setCurrentTrickNumber(nextTrickNumber);
      } else if (trickNumber != null && trickNumber < 13) {
        cardManager.setCurrentTrickNumber(trickNumber + 1);
      }
      cardManager.currentPlayerTurn = winnerName;
      if (mounted) {
        setState(() {
          isCollectingTrick = false;
          lastTrickWinner = null;
        });
      }
      if (cardManager.currentPlayerTurn == widget.currentPlayerName) {
        _updatePlayableCardsFromBackend();
      }
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        final current = cardManager.currentPlayerTurn;
        if (current.isNotEmpty && current != widget.currentPlayerName) {
          print('🔄 Appel maybeAutoPlayCurrentBot (trick vide)');
          maybeAutoPlayCurrentBot();
        }
      });
      return;
    }

    // ✅ Le trick contient des cartes, on peut déclencher l'animation
    final expectedPlayerCount = cardManager.expectedPlayerCount;
    final logMsg3 = '🎬 Démarrage animation collecte vers $winnerName (${trickCards.length}/$expectedPlayerCount cartes)';
    print(logMsg3);
    _addDebugLog(logMsg3);

    // 2. ✅ ATTENDRE QUE TOUTES LES CARTES SOIENT PRÉSENTES avant de démarrer l'animation
    // Cela garantit que les 4 cartes sont visibles au centre avant l'animation de collecte
    Future<void> startCollectionAnimation() async {
      int attempts = 0;
      const maxAttempts = 20; // Maximum 2 secondes d'attente (20 * 100ms)
      const delayMs = 100;
      
      while (attempts < maxAttempts) {
        if (!mounted) return;
        
        final currentTrickSize = cardManager.currentTrick.length;
        final expectedSize = cardManager.expectedPlayerCount;
        
        if (currentTrickSize >= expectedSize) {
          // ✅ Toutes les cartes sont présentes, démarrer l'animation
          if (mounted) {
            setState(() {
              isCollectingTrick = true; // Active l'animation dans _buildCardAtPosition
            });
            final logMsg4 = '🎬 Animation collecte activée (${currentTrickSize}/$expectedSize cartes - TOUTES PRÉSENTES)';
            print(logMsg4);
            _addDebugLog(logMsg4);
            
            // ✅ Log détaillé des cartes présentes
            final trickCards = cardManager.currentTrick;
            print('📋 Cartes dans le trick avant animation:');
            for (int i = 0; i < trickCards.length; i++) {
              final play = trickCards[i];
              final player = play['player'] as String? ?? 'Inconnu';
              final card = play['card'] as Map<String, dynamic>?;
              final cardCode = card?['code'] as String? ?? 'N/A';
              print('   [$i] $player → $cardCode');
            }
          }
          return;
        }
        
        attempts++;
        if (attempts < maxAttempts) {
          print('⏳ Attente des cartes manquantes: ${currentTrickSize}/$expectedSize (tentative $attempts/$maxAttempts)');
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
      
      // ⚠️ Timeout: démarrer l'animation même si toutes les cartes ne sont pas arrivées
      if (mounted) {
        final finalTrickSize = cardManager.currentTrick.length;
        print('⚠️ Timeout: Animation démarrée avec $finalTrickSize/$expectedPlayerCount cartes (certaines cartes manquantes)');
        setState(() {
          isCollectingTrick = true;
        });
      }
    }
    
    // Démarrer la vérification
    startCollectionAnimation();

    // 3. Après 1200ms (durée de l'animation), nettoyer le trick et passer au suivant
    // ✅ Remettre la durée d'animation à 1200ms pour une animation fluide
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      
      // Vider le trick actuel (les cartes ont été animées vers le gagnant)
      final trickSizeBeforeClear = cardManager.currentTrick.length;
      cardManager.clearCurrentTrick();
      final logMsg5 = '🧹 Trick vidé après animation (${trickSizeBeforeClear} cartes supprimées)';
      print(logMsg5);
      _addDebugLog(logMsg5);

      // Appliquer le numéro du prochain pli APRÈS l'animation (évite désync visuelle)
      if (nextTrickNumber != null) {
        cardManager.setCurrentTrickNumber(nextTrickNumber);
        _activeBackendTrickNumber = nextTrickNumber;
      } else if (trickNumber != null && trickNumber < 13) {
        cardManager.setCurrentTrickNumber(trickNumber + 1);
        _activeBackendTrickNumber = trickNumber + 1;
      }

      cardManager.currentPlayerTurn = winnerName;
      print('Tour (gagnant du pli): $winnerName');

      if (cardManager.currentPlayerTurn == widget.currentPlayerName) {
        _updatePlayableCardsFromBackend();
      }
      
      // Mettre à jour l'UI pour cacher l'animation et réinitialiser les variables
      if (mounted) {
        setState(() {
          isCollectingTrick = false;
          lastTrickWinner = null;
        });
        print('✅ UI mise à jour: animation terminée, trick nettoyé');
      }

      if (cardManager.isRoundEnding || cardManager.allCardsPlayed()) {
        cardManager.advanceToNextPlayerWithCards(preferredStart: winnerName);
        tryCompleteRoundIfFinished();
        return;
      }

      cardManager.advanceToNextPlayerWithCards(preferredStart: winnerName);

      // ✅ Augmenter le délai pour laisser le temps au backend de créer le nouveau trick
      Future.delayed(const Duration(milliseconds: 1500), () async {
        if (!mounted || !shouldAllowAutoPlay()) {
          if (mounted &&
              (cardManager.isRoundEnding || cardManager.allCardsPlayed())) {
            tryCompleteRoundIfFinished();
          }
          return;
        }
        final current = cardManager.currentPlayerTurn;
        if (current.isNotEmpty && current != widget.currentPlayerName) {
          print('🔄 Appel maybeAutoPlayCurrentBot après nettoyage trick (délai 1.5s)');
          
          // ✅ Vérifier que le nouveau trick est prêt avant de jouer
          try {
            final roomId = gameSession.roomId;
            if (roomId != null && roomId.isNotEmpty) {
              final roundNumber = gameSession.currentRound;
              final trickNumber = cardManager.currentTrickNumber > 0 
                  ? cardManager.currentTrickNumber 
                  : 1;
              
              // Vérifier que le trick est prêt
              final trickData = await GameApiService.instance.getCurrentTrick(
                roomId: roomId,
                roundNumber: roundNumber,
                trickNumber: trickNumber,
              );
              
                if (trickData['success'] == true) {
                print('✅ Nouveau trick prêt');
                if (!serverDrivesBots) {
                  scheduleMaybeAutoPlayCurrentBot();
                }
              } else {
                // ✅ Erreur 409 - le trick n'est pas encore prêt, attendre plus longtemps
                final errorMessage = trickData['message']?.toString() ?? '';
                if (errorMessage.contains('Trick not ready yet') || errorMessage.contains('409')) {
                  print('⏳ Trick pas encore prêt (409), attente de 1.5s avant nouvelle tentative...');
                  Future.delayed(const Duration(milliseconds: 1500), () {
                    if (mounted) scheduleMaybeAutoPlayCurrentBot();
                  });
                } else {
                  print('⚠️ Erreur lors de la vérification du trick: $errorMessage');
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) scheduleMaybeAutoPlayCurrentBot();
                  });
                }
              }
          } else {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) scheduleMaybeAutoPlayCurrentBot();
            });
          }
        } catch (e) {
          print('⚠️ Erreur lors de la vérification du trick: $e');
          final errorString = e.toString();
          if (errorString.contains('Trick not ready yet') || errorString.contains('409')) {
            print('⏳ Trick pas encore prêt (exception 409), attente de 1.5s...');
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) scheduleMaybeAutoPlayCurrentBot();
            });
          } else {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) scheduleMaybeAutoPlayCurrentBot();
            });
          }
        }
        }
      });
    });
  }
  /// Un seul timer HTTP pour la salle (remplace room + state sync doublons).
  void _restartRoomSyncPolling({bool forceRestart = false}) {
    if (gameSession.playWithBots) return;
    if (stateSyncTimer != null && !forceRestart) return;

    roomPollTimer?.cancel();
    roomPollTimer = null;
    stateSyncTimer?.cancel();

    final cardsReceived =
        cardManager.getPlayerCards(widget.currentPlayerName).isNotEmpty;

    final interval = GameRoomPollingPolicy.roomSyncInterval(
      webSocketConnected: isWebSocketConnected,
      waitingForPlayers: waitingForHumans,
      announcementPhase: cardManager.isAnnouncementPhase,
      cardsReceived: cardsReceived,
    );

    stateSyncTimer = Timer.periodic(interval, (_) => _pollGameState());
    print(
      '🔁 Polling HTTP (${interval.inSeconds}s) — WS=${isWebSocketConnected ? 'ON' : 'OFF'}',
    );
  }

  void _startRoomPolling() => _restartRoomSyncPolling(forceRestart: true);

  void _startStateSyncPolling({bool forceRestart = false}) =>
      _restartRoomSyncPolling(forceRestart: forceRestart);

  Future<void> _pollGameState() async {
    if (!mounted || gameSession.playWithBots) return;

    final cardsReceived =
        cardManager.getPlayerCards(widget.currentPlayerName).isNotEmpty;

    if (GameRoomPollingPolicy.shouldSkipRoomSync(
      webSocketConnected: isWebSocketConnected,
      announcementPhase: cardManager.isAnnouncementPhase,
      waitingForPlayers: waitingForHumans,
      cardsReceived: cardsReceived,
    )) {
      return;
    }

    try {
      final roomId = gameSession.roomId ?? '';
      if (roomId.isEmpty) return;

      final res = await GameApiService.instance.syncRoom(
        roomId: roomId,
        lastChatId: _lastChatMessageId,
      );
      final data = Map<String, dynamic>.from(
        (res['data'] as Map?) ?? res as Map,
      );
      final players =
          (data['players'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (players.isNotEmpty) {
        _applyBackendPlayersState(
          players,
          startGameIfReady: waitingForHumans,
        );
      }

      _applyRoomSyncPayload(data);

      consecutiveStatePollingErrors = 0;
      lastSuccessfulStatePoll = DateTime.now();
    } catch (e) {
      consecutiveStatePollingErrors++;
      if (consecutiveStatePollingErrors > 5) {
        print('⚠️ Trop d\'erreurs de polling, pause 30s');
        stateSyncTimer?.cancel();
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted) _restartRoomSyncPolling(forceRestart: true);
        });
      }
    }
  }

  /// Manche, annonces (hors WS) et chat depuis GET /rooms/{id}/sync.
  void _applyRoomSyncPayload(Map<String, dynamic> data) {
    final gameId = data['game_id'];
    if (gameId is int) {
      _currentGameId = gameId;
    } else if (gameId != null) {
      _currentGameId = int.tryParse(gameId.toString());
    }

    final chatRaw = data['chat'];
    if (chatRaw is Map) {
      _ingestChatFromSync(Map<String, dynamic>.from(chatRaw));
    }

    Map<String, dynamic>? round;
    final roundRaw = data['round'];
    if (roundRaw is Map) {
      round = Map<String, dynamic>.from(roundRaw);
    }

    if (round != null) {
      _applyDistributionFromSyncRound(round);

      final status = round['status'] as String?;
      if (status == 'ANNOUNCEMENT_PHASE' &&
          !cardManager.isAnnouncementPhase &&
          _localPlayerHasCards()) {
        final startTs =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) -
            (30 - ((round['announcement_seconds_remaining'] as num?)?.toInt() ?? 30));
        _handleAnnouncementPhaseStartedPayload({
          'room_id': gameSession.roomId,
          'game_id': gameId,
          'round_number': round['round_number'],
          'start_timestamp': startTs,
          'duration': 30,
        });
      }

      // Secours : BDD en PLAYING mais client encore en phase d'annonces (WS manqué)
      if (cardManager.isAnnouncementPhase && status == 'PLAYING') {
        final announcementsRaw = round['announcements'];
        Map<String, dynamic>? announcementsMap;
        if (announcementsRaw is Map) {
          announcementsMap = Map<String, dynamic>.from(announcementsRaw);
        }
        unawaited(_completeAnnouncementPhaseFromBackend(
          announcements: announcementsMap,
          roundNumber: (round['round_number'] as num?)?.toInt(),
          source: 'sync_playing_status',
        ));
      }
    }

    if (isWebSocketConnected) return;

    if (round == null) return;

    final status = round['status'] as String?;
    final announcementsRaw = round['announcements'];
    Map<String, dynamic>? announcements;
    if (announcementsRaw is Map) {
      announcements = Map<String, dynamic>.from(announcementsRaw);
    }
    if (status == 'ANNOUNCEMENT_PHASE' &&
        announcements != null &&
        _localPlayerHasCards()) {
      for (final entry in announcements.entries) {
        final playerName = entry.key;
        final value = (entry.value as num?)?.toInt() ?? 0;
        final exists = cardManager.getCurrentRoundAnnouncements().any(
          (ann) => ann['player'] == playerName,
        );
        if (!exists && value >= 2) {
          cardManager.makeAnnouncement(playerName, value);
        }
      }
      if (mounted) setState(() {});
    }
  }

  void _applyDistributionFromSyncRound(Map<String, dynamic> round) {
    final distribution = _parseDistributedCards(round['distributed_cards']);
    if (distribution == null || distribution.isEmpty) {
      print(
        '⚠️ /sync: distributed_cards absent ou vide '
        '(round=${round['round_number']}, status=${round['status']})',
      );
      return;
    }

    final roundNumber = (round['round_number'] as num?)?.toInt();
    if (!_needsDistributionApply(roundNumber)) {
      return;
    }

    final normalized = _canonicalizeDistributionKeys(distribution);

    print(
      '📥 Cartes récupérées via /sync pour ${widget.currentPlayerName} '
      '(round $roundNumber, ${normalized.length} joueurs)',
    );

    _applyCardDistributionPayload(
      normalized,
      roundNumber: roundNumber,
      skipConfigureIfAnnouncementActive: cardManager.isAnnouncementPhase,
    );
    _maybeApplyPendingAnnouncementPhase();
  }

  void _ingestChatFromSync(Map<String, dynamic> chat) {
    if (!mounted || gameSession.playWithBots || _isFetchingChat) return;

    final rawMessages =
        (chat['messages'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (rawMessages.isEmpty) return;

    final syncLastId = chat['last_chat_id'];
    if (syncLastId is int) {
      _lastChatMessageId = _lastChatMessageId == null
          ? syncLastId
          : math.max(_lastChatMessageId!, syncLastId);
    } else if (syncLastId != null) {
      final parsed = int.tryParse(syncLastId.toString());
      if (parsed != null) {
        _lastChatMessageId = _lastChatMessageId == null
            ? parsed
            : math.max(_lastChatMessageId!, parsed);
      }
    }

    final normalized = rawMessages.map((raw) {
      final map = Map<String, dynamic>.from(raw);
      map['id'] = _normalizeMessageId(map['id']) ?? map['id'];
      map['pseudo'] =
          (map['pseudo'] ?? map['player_name'] ?? 'Joueur').toString();
      map['message'] = (map['message'] ?? '').toString();
      map['message_type'] = (map['message_type'] ?? 'text').toString();
      map['created_at'] =
          map['created_at']?.toString() ?? DateTime.now().toIso8601String();
      return map;
    }).toList();

    _ingestChatMessages(normalized, enableToast: !isWebSocketConnected);
  }

  void _applyBackendPlayersState(List<Map<String, dynamic>> players, {bool startGameIfReady = false}) {
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
      return {
        ...p,
        'normalizedName': name.isNotEmpty ? name : 'Joueur',
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
        'is_bot': isBot, // ✅ Valeur booléenne préservée
        'backendPosition': (p['position'] ?? 0) as int,
      });
    }

    if (mounted) {
      setState(() {
        gameSession.players = normalized;
        if (gameSession.globalScores.length != normalized.length) {
          gameSession.globalScores = List.filled(normalized.length, 0.0);
        }
      });
    }

    if (startGameIfReady &&
        normalized.length >= requiredPlayers &&
        !hasGameStarted) {
      waitingForHumans = false;
      _restartRoomSyncPolling(forceRestart: true);
      startCardDistribution();
    }
  }

  void _synchronizePlayerReplacement(String playerName, String botName, bool isPermanent) {
    final players = gameSession.players;
    final playerIndex = players.indexWhere(
      (p) => (p['name'] as String?) == playerName,
    );

    if (playerIndex != -1) {
      if (!isPermanent) {
        temporaryReplacements[playerName] = {
          'botName': botName,
          'timestamp': DateTime.now(),
          'isPermanent': false,
        };
      } else {
        permanentlyExcludedPlayers.add(playerName);
      }

      _replacePlayerWithBotLocally(playerName, botName, isPermanent);
    }
  }

  void _synchronizePlayerRestoration(String playerName, String botName) {
    _restorePlayer(playerName);
  }

  void _replacePlayerWithBotLocally(String playerName, String botName, bool isPermanent) {
    final players = gameSession.players;
    final playerIndex = players.indexWhere(
      (p) => (p['name'] as String?) == playerName,
    );

    if (playerIndex != -1) {
      final player = players[playerIndex];
      final playerCards = cardManager.getPlayerCards(playerName);

      setState(() {
        players[playerIndex] = {
          ...player,
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
            super.handleAnnouncementTurnComplete();
          }
        });
      }

      setState(() {});
    }
  }

  void _restorePlayer(String playerName) {
    final players = gameSession.players;
    final botIndex = players.indexWhere(
      (p) => (p['isReplacementBot'] as bool?) == true &&
             (p['replacedPlayerName'] as String?) == playerName,
    );

    if (botIndex != -1) {
      final bot = players[botIndex];
      final botName = bot['name'] as String;
      final botCards = cardManager.getPlayerCards(botName);

      setState(() {
        players[botIndex] = {
          ...bot,
          'name': playerName,
          'avatar': '👤',
          'is_bot': false,
          'isReplacementBot': false,
          'replacedPlayerName': null,
        };
      });

      if (botCards.isNotEmpty) {
        cardManager.transferPlayerCards(botName, playerName);
      }

      final announcements = cardManager.getCurrentRoundAnnouncements();
      final botAnnouncement = announcements.firstWhere(
        (ann) => (ann['player'] as String?) == botName,
        orElse: () => <String, Object>{},
      );
      if ((botAnnouncement['announcement'] as int?) != null) {
        botAnnouncement['player'] = playerName;
      }

      cardManager.transferObtainedTricks(botName, playerName);
      cardManager.updatePlayerNameInCurrentTrick(botName, playerName);

      if (cardManager.currentPlayerTurn == botName) {
        cardManager.currentPlayerTurn = playerName;
      }

      temporaryReplacements.remove(playerName);
      setState(() {});
    }
  }

  Future<void> _handlePlayerDisconnection(String playerName) async {
    final hasGameStarted = gameSession.currentRound > 0 || 
                          cardManager.isAnnouncementPhase ||
                          cardManager.getPlayerCards(playerName).isNotEmpty;
    
    if (playerName != widget.currentPlayerName) {
      if (!hasGameStarted) {
        final botName = 'Bot_Remplaceur_${playerName}';
        temporaryReplacements[playerName] = {
          'botName': botName,
          'timestamp': DateTime.now(),
          'isPermanent': false,
          'canReconnect': true,
        };

        final roomId = gameSession.roomId ?? '';
        if (roomId.isNotEmpty) {
          try {
            await GameApiService.instance.notifyPlayerDisconnection(
              roomId: roomId,
              playerName: playerName,
            );
          } catch (e) {
            print('⚠️ Erreur notification backend déconnexion: $e');
          }
        }

        _replacePlayerWithBotLocally(playerName, botName, false);
      } else {
        final botName = 'Bot_Remplaceur_${playerName}';
        temporaryReplacements[playerName] = {
          'botName': botName,
          'timestamp': DateTime.now(),
          'isPermanent': false,
        };

        _replacePlayerWithBotLocally(playerName, botName, false);

        reconnectionCheckTimer = Timer(const Duration(seconds: 15), () {
          if (temporaryReplacements.containsKey(playerName)) {
            final replacement = temporaryReplacements[playerName];
            if ((replacement?['isPermanent'] as bool?) != true) {
              temporaryReplacements[playerName]!['isPermanent'] = true;
              permanentlyExcludedPlayers.add(playerName);
              _replacePlayerWithBotLocally(playerName, botName, true);
            }
          }
        });
      }
    }
  }

  void _handlePlayerReconnection(String playerName) {
    reconnectionCheckTimer?.cancel();
    _restorePlayer(playerName);
    
    final roomId = gameSession.roomId ?? '';
    if (roomId.isNotEmpty) {
      try {
        GameApiService.instance.notifyPlayerReconnection(
          roomId: roomId,
          playerName: playerName,
        );
      } catch (e) {
        print('⚠️ Erreur notification backend reconnexion: $e');
      }
    }
  }

  // ========== CHAT (MODE HUMAIN UNIQUEMENT) ==========
  
  final List<Map<String, String>> _quickChatOptions = [
    {'label': 'Jouez vite les gars !', 'message': 'Jouez vite les gars !', 'code': 'play_fast'},
    {'label': 'Je suis mort 😢', 'message': 'Je suis mort 😢', 'code': 'i_am_dead'},
    {'label': 'Ok', 'message': 'Ok', 'code': 'ok'},
    {'label': 'Bonne chance !', 'message': 'Bonne chance à tous !', 'code': 'good_luck'},
  ];
  
  final List<String> _emojiOptions = ['😂', '😭', '👍', '👎', '✅', '💪', '👀', '🖕', '💋', '🥇'];

  Widget _buildChatOverlay() {
    return Positioned(
      bottom: 16,
      left: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isChatPanelVisible) _buildChatPanel(),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'room_chat_toggle',
            backgroundColor: Colors.black.withOpacity(0.75),
            onPressed: () {
              setState(() {
                isChatPanelVisible = !isChatPanelVisible;
              });
              if (isChatPanelVisible) {
                _scrollChatToBottom();
              }
            },
            child: const Icon(Icons.forum, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel() {
    return Container(
      width: 330,
      constraints: const BoxConstraints(maxHeight: 400),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Chat du salon',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () {
                  setState(() {
                    isChatPanelVisible = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ..._quickChatOptions.map(
                    (opt) => ActionChip(
                      label: Text(opt['label']!, style: const TextStyle(fontSize: 11)),
                      onPressed: () => _handleQuickMessage(opt),
                      backgroundColor: Colors.white12,
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  ),
                  ..._emojiOptions.map(
                    (emoji) => Container(
                      margin: const EdgeInsets.only(right: 6),
                      child: Material(
                        color: _getEmojiBackgroundColor(emoji),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: () => _handleEmojiTap(emoji),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Text(emoji, style: const TextStyle(fontSize: 20)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: chatInputController,
                  style: const TextStyle(color: Colors.white),
                  minLines: 1,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Tapez un message...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    filled: true,
                    fillColor: Colors.white12,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (_) => _handleSendChatInput(),
                ),
              ),
              const SizedBox(width: 8),
              isSendingChatMessage
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _handleSendChatInput,
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatToast() {
    if (chatToastMessage == null || chatToastAnimation == null) {
      return const SizedBox.shrink();
    }
    final pseudo = (chatToastMessage!['pseudo'] ?? 'Joueur').toString();
    final message = (chatToastMessage!['message'] ?? '').toString();

    return AnimatedBuilder(
      animation: chatToastAnimation!,
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final leftPosition = (chatToastAnimation!.value + 1.0) / 2.0;
        final left = leftPosition * (screenWidth + 300) - 300;

        return Positioned(
          bottom: isChatPanelVisible ? 310 : 120,
          left: left,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pseudo,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.3),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleSendChatInput() {
    final text = chatInputController.text.trim();
    if (text.isEmpty) return;
    _sendChatMessage(message: text, type: 'text');
  }

  void _handleQuickMessage(Map<String, String> option) {
    final message = option['message'] ?? '';
    if (message.isEmpty) return;
    _sendChatMessage(
      message: message,
      type: 'preset',
      presetCode: option['code'],
    );
  }

  void _handleEmojiTap(String emoji) {
    _sendChatMessage(message: emoji, type: 'emoji', presetCode: 'emoji_$emoji');
  }

  Future<void> _sendChatMessage({
    required String message,
    String type = 'text',
    String? presetCode,
  }) async {
    if (isSendingChatMessage) return;
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      isSendingChatMessage = true;
    });

    if (!mounted) return;
    chatInputController.clear();
    
    if (isChatPanelVisible) {
      setState(() {
        isChatPanelVisible = false;
      });
    }

    // ✅ LOG: Envoi du message
    print('📤 ENVOI MESSAGE CHAT');
    print('   Expéditeur: ${widget.currentPlayerName}');
    print('   Message: $trimmed');
    print('   Type: $type');
    
    // ✅ Envoyer le message via WebSocket - il sera ajouté quand il reviendra du serveur
    final roomId = gameSession.roomId;
    if (roomId != null && roomId.isNotEmpty) {
      try {
        final wsService = GameWebSocketService();
        if (wsService.isConnected) {
          print('   ✅ WebSocket connecté, envoi en cours...');
          await wsService.sendChatMessage(
            message: trimmed,
            type: type,
            presetCode: presetCode,
          ).then((_) {
            print('   ✅ Message envoyé via WebSocket avec succès');
          }).catchError((e) {
            print('⚠️ Erreur WebSocket chat: $e');
          });
        } else {
          print('   ❌ WebSocket non connecté');
        }
      } catch (e) {
        print('⚠️ Erreur envoi chat: $e');
      }
    } else {
      print('   ❌ RoomId invalide: $roomId');
    }

  if (mounted) {
      setState(() {
        isSendingChatMessage = false;
      });
    } else {
      isSendingChatMessage = false;
    }
  }

  Color _getEmojiBackgroundColor(String emoji) {
    switch (emoji) {
      case '😂':
        return Colors.amber.withOpacity(0.3);
      case '😭':
        return Colors.blue.withOpacity(0.3);
      case '👍':
        return Colors.green.withOpacity(0.3);
      case '👎':
        return Colors.red.withOpacity(0.3);
      case '✅':
        return Colors.greenAccent.withOpacity(0.3);
      case '💪':
        return Colors.orange.withOpacity(0.3);
      case '👀':
        return Colors.purple.withOpacity(0.3);
      case '🖕':
        return Colors.redAccent.withOpacity(0.3);
      case '💋':
        return Colors.pink.withOpacity(0.3);
      case '🥇':
        return Colors.amberAccent.withOpacity(0.3);
      default:
        return Colors.white12;
    }
  }

  void _showChatToast(Map<String, dynamic> message) {
    if (!mounted) return;
    chatToastTimer?.cancel();
    chatToastAnimationController.stop();
    chatToastAnimationController.reset();

    setState(() {
      chatToastMessage = message;
    });

    chatToastAnimationController.forward();
    chatToastTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        chatToastAnimationController.stop();
        setState(() {
          chatToastMessage = null;
        });
      }
    });
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!chatScrollController.hasClients) return;
      chatScrollController.animateTo(
        chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  int? _normalizeMessageId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  void _ingestChatMessages(
    List<Map<String, dynamic>> messages, {
    bool enableToast = true,
  }) {
    if (messages.isEmpty) {
      print('📥 _ingestChatMessages: Liste vide, ignoré');
      return;
    }
    
    print('📥 _ingestChatMessages: ${messages.length} message(s) à traiter');
    final toAppend = <Map<String, dynamic>>[];

    for (final message in messages) {
      final normalized = Map<String, dynamic>.from(message);
      final messageId = _normalizeMessageId(normalized['id']);
      final pseudo = normalized['pseudo'] as String? ?? 'Joueur';
      final messageText = normalized['message'] as String? ?? '';
      
      print('   📨 Message: pseudo=$pseudo, id=$messageId, texte="$messageText"');
      print('      Est l\'expéditeur: ${pseudo == widget.currentPlayerName}');
      
      // ✅ SIMPLIFICATION: Vérification uniquement par messageId
      if (messageId != null) {
        if (_knownChatMessageIds.contains(messageId)) {
          print('      ⚠️ Message déjà connu (ID: $messageId), ignoré');
          continue; // Message déjà connu, ignorer
        }
        print('      ✅ Nouveau message, ajouté (ID: $messageId)');
        _knownChatMessageIds.add(messageId);
        _lastChatMessageId = _lastChatMessageId == null
            ? messageId
            : math.max(_lastChatMessageId!, messageId);
        normalized['id'] = messageId;
      } else {
        print('      ⚠️ MessageId null, utilisation d\'un ID temporaire');
      }
      
      toAppend.add(normalized);
    }

    if (toAppend.isEmpty) {
      print('   ❌ Aucun message à ajouter après déduplication');
      return;
    }
    
    if (!mounted) {
      print('   ❌ Widget non monté, impossible d\'ajouter les messages');
      return;
    }
    
    print('   ✅ Ajout de ${toAppend.length} message(s) à chatMessages');
    print('      Avant: ${chatMessages.length} messages');
    setState(() {
      chatMessages.addAll(toAppend);
      if (chatMessages.length > 120) {
        chatMessages = chatMessages.sublist(chatMessages.length - 120);
      }
    });
    print('      Après: ${chatMessages.length} messages');

    final lastMessage = toAppend.last;
    // ✅ Afficher le toast pour TOUS les messages (y compris ceux de l'expéditeur)
    if (enableToast) {
      print('   🔔 Affichage du toast pour: ${lastMessage['pseudo']} (expéditeur: ${lastMessage['pseudo'] == widget.currentPlayerName ? "moi" : "autre"})');
      _showChatToast(lastMessage);
    }
    _scrollChatToBottom();
  }

  // ========== UI BUILDING ==========
  
  Widget _buildPlayerHand() {
    final playerCards = cardManager.getPlayerCards(widget.currentPlayerName);
    
    // ✅ Debug: vérifier si les cartes existent (uniquement si problème réel)
    if (playerCards.isEmpty && hasGameStarted) {
      // Vérifier si toutes les cartes ont été jouées (état normal en fin de partie)
      bool allCardsPlayed = true;
      for (var hand in cardManager.distributedCards.values) {
        if (hand.isNotEmpty) {
          allCardsPlayed = false;
          break;
        }
      }
      
      // Ne pas afficher le message si toutes les cartes ont été jouées (c'est normal)
      if (!allCardsPlayed) {
        print('⚠️ ATTENTION: Aucune carte trouvée pour ${widget.currentPlayerName}');
        print('   Joueurs avec cartes: ${cardManager.distributedCards.keys.toList()}');
        // Vérifier si le nom du joueur correspond exactement
        for (final key in cardManager.distributedCards.keys) {
          print('   - "$key" (identique: ${key == widget.currentPlayerName})');
        }
      }
    }
    
    final currentPlayerCards = sortCardsForDisplay(playerCards);

    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Container(
        height: 80,
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: currentPlayerCards.map((card) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  child: _buildHandCard(card),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandCard(Map<String, dynamic> card) {
    final isCurrentPlayerTurn =
        cardManager.currentPlayerTurn == widget.currentPlayerName;
    final isAnnouncementPhase = cardManager.isAnnouncementPhase;

    final playerCards = cardManager.getPlayerCards(widget.currentPlayerName);

    // ✅ Vérifier si le joueur est déjà en train de jouer une carte (verrouillage de la main)
    final isPlayerPlaying = currentPlayerPlaying == widget.currentPlayerName;

    // ✅ PRIORITÉ: Calcul local immédiat pour éviter toute latence UI due au réseau
    final cardCode = card['code'] as String? ?? '';
    bool isPlayable = false;
    
    if (isCurrentPlayerTurn &&
        !isAnnouncementPhase &&
        !isPlayerPlaying) {
      // ✅ Calculer les cartes jouables localement pour une réactivité instantanée
      gameLogic.syncCurrentTrick(cardManager.currentTrick);
      final playableLocal = gameLogic.getPlayableCards(
        playerCards,
        widget.currentPlayerName,
        cardManager.currentTrick.isEmpty,
      );
      isPlayable = playableLocal.any((c) => c['code'] == cardCode);
    }

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
    
    // ✅ Capturer 'this' avant la closure pour forcer la résolution
    final self = this;
    return GestureDetector(
      onTap: isPlayable ? () async {
        // Validation locale instantanée
        gameLogic.syncCurrentTrick(cardManager.currentTrick);
        final playableLocal = gameLogic.getPlayableCards(
          playerCards,
          widget.currentPlayerName,
          cardManager.currentTrick.isEmpty,
        );
        if (!playableLocal.any((c) => c['code'] == cardCode)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cette carte ($cardCode) n\'est plus jouable.'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        await playCard(card);
        // ⚠️ COMMENTÉ: Appel dans onTap closure - problème de résolution du compilateur
        // ✅ Mettre à jour le cache après avoir joué une carte
        // if (self.mounted) {
        //   await self._updatePlayableCardsFromBackend();
        // }
      } : null,
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

  Widget _buildPlayers() {
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
          .map((player) => _buildPlayer(player))
          .toList(),
    );
  }

  Widget _buildPlayer(Map<String, dynamic> player) {
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
          offset: position == 'top' ? const Offset(0, -10) : Offset.zero,
          child: Container(
            margin: getPlayerMargin(position),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (position == 'bottom')
                  _buildPlayerBottomWidget(player, isCurrentTurn, isThisCurrentPlayer)
                else if (position == 'left')
                  _buildPlayerLeftWidget(player)
                else if (position == 'right')
                  _buildPlayerRightWidget(player)
                else
                  _buildPlayerTopWidget(player),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerBottomWidget(Map<String, dynamic> player, bool isCurrentTurn, bool isThisCurrentPlayer) {
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

  Widget _buildPlayerLeftWidget(Map<String, dynamic> player) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
          width: 120,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Cartes en éventail derrière l'avatar (orienté vers la droite)
              ...List.generate(getPlayerCardCount(player['name']), (index) {
                final cardCount = getPlayerCardCount(player['name']);
                final angle = cardCount > 0
                    ? (index - (cardCount - 1) / 2) * 0.12
                    : 0.0;
                final radius = 35.0;
                final centerX = 60.0;
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

  Widget _buildPlayerRightWidget(Map<String, dynamic> player) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
          width: 120,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
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

  Widget _buildPlayerTopWidget(Map<String, dynamic> player) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Row avec Nom, compteur d'annonce et compteur de score (au-dessus de l'avatar)
        Row(
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
            const SizedBox(width: 8),
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
            const SizedBox(width: 8),
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
        ),
        const SizedBox(height: 8),
        // Stack avec cartes en éventail et avatar (en dessous des compteurs)
        SizedBox(
          width: 150,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Cartes en éventail derrière l'avatar (rotation 90°)
              ...List.generate(getPlayerCardCount(player['name']), (index) {
                final cardCount = getPlayerCardCount(player['name']);
                final angle = cardCount > 0
                    ? (index - (cardCount - 1) / 2) * 0.12
                    : 0.0;
                final radius = 35.0;
                final centerX = 75.0;
                final centerY = 60.0;
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
      ],
    );
  }

  Widget _buildCenterTrick() {
    // ✅ Ne pas afficher les cartes pendant la phase d'annonces
    if (cardManager.isAnnouncementPhase) return const SizedBox.shrink();
    
    final currentTrick = cardManager.currentTrick;
    if (currentTrick.isEmpty) return const SizedBox.shrink();

    // ✅ DEBUG: Log les cartes présentes dans le trick pour diagnostiquer les cartes manquantes
    final expectedCount = cardManager.expectedPlayerCount;
    if (currentTrick.length != expectedCount && currentTrick.length > 0) {
      print('⚠️ _buildCenterTrick: Trick incomplet - ${currentTrick.length}/$expectedCount cartes');
      print('   Cartes présentes:');
      for (int i = 0; i < currentTrick.length; i++) {
        final play = currentTrick[i];
        final player = play['player'] as String? ?? 'Inconnu';
        final card = play['card'] as Map<String, dynamic>?;
        final cardCode = card?['code'] as String? ?? 'N/A';
        print('     [$i] $player → $cardCode');
      }
    }

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
                
                // ✅ Vérifier que la carte a bien un code (sinon elle ne s'affichera pas)
                final cardCode = card['code'] as String?;
                if (card.isEmpty || cardCode == null || cardCode.isEmpty) {
                  print('⚠️ _buildCenterTrick: Carte invalide pour $playerName à l\'index $index');
                  return const SizedBox.shrink();
                }
                
                final pos = getDisplayPositionForPlayerName(playerName);
                final winnerPos = isCollectingTrick && lastTrickWinner != null
                    ? getDisplayPositionForPlayerName(lastTrickWinner!)
                    : null;
                return _buildCardAtPosition(card, pos, index, winnerPos);
              } catch (e) {
                print('❌ _buildCenterTrick: Erreur lors de l\'affichage de la carte à l\'index $index: $e');
                return const SizedBox.shrink();
              }
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCardAtPosition(
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
                  child: _buildPlayedCard(card, rotate: shouldRotateCard),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayedCard(Map<String, dynamic> card, {bool rotate = false}) {
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

  Widget _buildAnimatedCard() {
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

  Widget _buildGameControls() {
    return Stack(
      children: [
        Positioned(
          top: 20,
          left: 20,
          child: _buildControlButton(
            icon: Icons.list,
            onTap: () => _showGameMenu(),
          ),
        ),
        Positioned(
          top: 20,
          right: 20,
          child: _buildControlButton(
            icon: Icons.exit_to_app,
            onTap: () => _showLeaveGameConfirmation(),
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
    return Positioned(
      top: 20,
      left: 80,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Text(
              widget.roomName,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              'Code: ${widget.roomCode} • Mise: ${widget.minimumBet} cauris',
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnMessage() {
    return const SizedBox.shrink();
  }

  Widget _buildAnnouncementPanel() {
    final isAnnouncementPhase = cardManager.isAnnouncementPhase;
    if (!isAnnouncementPhase) return const SizedBox.shrink();

    // ✅ NOUVEAU: Système simultané - afficher le panneau pour tous les joueurs
    // Le panneau est visible si la phase est active ET que le joueur n'a pas encore soumis
    final announcements = cardManager.getCurrentRoundAnnouncements();
    final hasCurrentPlayerAnnounced = announcements.any(
      (ann) => ann['player'] == widget.currentPlayerName,
    );

    // ✅ Si le joueur a déjà fait son annonce, afficher un message d'attente au lieu du panneau
    if (hasCurrentPlayerAnnounced || _hasAnnounced) {
      return _buildWaitingForOthersPanel();
    }

    // ✅ Vérifier que le timer est toujours actif (countdown > 0)
    if (announcementCountdown <= 0 && _announcementPhaseStartTimestamp == null) {
      return const SizedBox.shrink();
    }

    // ✅ Afficher le panneau pour le joueur local (système simultané)
    return _buildCurrentPlayerAnnouncementPanel();
  }

  // ✅ NOUVEAU: Panneau d'attente quand le joueur a déjà soumis son annonce
  Widget _buildWaitingForOthersPanel() {
    final announcements = cardManager.getCurrentRoundAnnouncements();
    final submittedCount = announcements.length;
    final expectedCount = gameSession.players.length;

    if (submittedCount >= expectedCount && cardManager.isAnnouncementPhase) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleAnnouncementCompletionPoll();
        unawaited(_tryCompleteAnnouncementPhaseFromBackend(
          reason: 'waiting_panel_4of4',
        ));
      });
    }
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
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Annonce soumise',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B4513),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'En attente des autres joueurs...\n($submittedCount/$expectedCount)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8B4513),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                  // ✅ Afficher uniquement le compte à rebours (rond du minuteur)
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
                          _makeAnnouncementWithTimer(currentAnnouncement);
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
      orElse: () => <String, Object>{'announcement': 0},
    );
    return playerAnnouncement['announcement'] as int;
  }

  Future<void> _makeAnnouncementWithTimer(int announcement) async {
    // ✅ NOUVEAU: Utiliser le backend pour gérer les annonces (système simultané)
    final playerName = widget.currentPlayerName;
    final int clampedAnnouncement = announcement.clamp(2, 13).toInt();
    
    print('📤 Envoi annonce au backend: $playerName → $clampedAnnouncement plis');
    
    try {
      // ✅ Utiliser le game_id stocké depuis announcement_phase_started
      // ✅ CORRECTION: Si gameId est null, essayer de le récupérer via l'API
      _syncRoundNumber(null);
      final roundNumber = _effectiveRoundNumber();
      var gameId = await _resolveGameId();

      if (gameId == null) {
        print('❌ Impossible d\'obtenir le gameId (phase d\'annonces non démarrée?)');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur: partie non synchronisée avec le serveur. Réessayez dans quelques secondes.'),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(bottom: 100, left: 20, right: 20),
            ),
          );
        }
        return;
      }
      
      if (clampedAnnouncement < 2 || clampedAnnouncement > 13) {
        print('❌ announcementValue invalide: $clampedAnnouncement (doit être entre 2 et 13)');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur: La valeur d\'annonce doit être entre 2 et 13 plis'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        );
        return;
      }
      
      print('✅ Validation OK: gameId=$gameId, roundNumber=$roundNumber, announcementValue=$clampedAnnouncement');
      
      // ✅ Envoyer l'annonce au backend (système simultané)
      final response = await GameApiService.instance.makeAnnouncement(
        gameId: gameId,
        roundNumber: roundNumber,
        announcementValue: clampedAnnouncement,
      );
      
      print('✅ Annonce envoyée au backend avec succès');

      final responseData = response['data'];
      if (responseData is Map && responseData['is_complete'] == true) {
        final announcementsRaw = responseData['announcements'];
        Map<String, dynamic>? announcementsMap;
        if (announcementsRaw is Map) {
          announcementsMap = Map<String, dynamic>.from(announcementsRaw);
        }
        await _completeAnnouncementPhaseFromBackend(
          announcements: announcementsMap,
          firstPlayer: responseData['first_player'] as String?,
          roundNumber: (responseData['round_number'] as num?)?.toInt() ??
              roundNumber,
          announcementsAdjusted: responseData['announcements_adjusted'] == true,
          source: 'announce_http_response',
        );
      }
      
      // ✅ Mettre à jour l'état local (l'annonce sera aussi reçue via WebSocket)
      if (mounted) {
        setState(() {
          hasAnnounced = true;
          currentAnnouncement = clampedAnnouncement;
        });
      } else {
        hasAnnounced = true;
        currentAnnouncement = clampedAnnouncement;
      }
      
      // ✅ Le backend enverra l'événement WebSocket announcement_submitted
      // qui sera traité par le listener
      
    } catch (e) {
      print('❌ Erreur lors de l\'envoi de l\'annonce au backend: $e');

      final errorText = e.toString().toLowerCase();
      final phaseAlreadyClosed = errorText.contains('phase d\'annonces n\'est pas active') ||
          errorText.contains('not active');

      if (phaseAlreadyClosed) {
        print('ℹ️ Phase déjà fermée côté serveur — resync HTTP');
        unawaited(_tryCompleteAnnouncementPhaseFromBackend(
          reason: 'announce_after_phase_closed',
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Phase d\'annonces terminée. Synchronisation en cours…',
              ),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(bottom: 100, left: 20, right: 20),
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur annonce: ${e.toString().split('\n').first}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
          ),
        );
      }
    }
  }

  // ✅ NOUVEAU: Envoyer l'annonce d'un bot au backend avec retry
  Future<void> _sendBotAnnouncementWithRetry(String botName, {int maxRetries = 3}) async {
    int attempts = 0;
    Exception? lastError;
    
    while (attempts < maxRetries) {
      try {
        if (!mounted || !cardManager.isAnnouncementPhase) {
          print('⚠️ Phase d\'annonces terminée, arrêt de l\'envoi pour $botName');
          return;
        }
        
        // Vérifier si le bot a déjà fait son annonce (peut-être via WebSocket entre-temps)
        final announcements = cardManager.getCurrentRoundAnnouncements();
        final alreadyAnnounced = announcements.any(
          (ann) => ann['player'] == botName,
        );
        
        if (alreadyAnnounced) {
          print('✅ $botName a déjà fait son annonce (via WebSocket), ignoré');
          return;
        }
        
        final botAnnouncement = cardManager.getBotAnnouncement(botName);
        final int clampedAnnouncement = botAnnouncement.clamp(2, 13).toInt();
        print('🤖 [$botName] Tentative ${attempts + 1}/$maxRetries: annonce = $clampedAnnouncement plis');
        
        // ✅ Utiliser le game_id stocké depuis announcement_phase_started
        _syncRoundNumber(null);
        final gameId = await _resolveGameId();
        final roundNumber = _effectiveRoundNumber();
        
        if (gameId == null) {
          print('⚠️ gameId null pour $botName (phase d\'annonces non démarrée?), nouvelle tentative dans 1 seconde...');
          attempts++;
          if (attempts < maxRetries) {
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
          throw Exception('Impossible d\'obtenir le gameId après $maxRetries tentatives (phase d\'annonces non démarrée?)');
        }
        
        if (roundNumber < 1) {
          print('⚠️ roundNumber invalide pour $botName: $roundNumber (doit être >= 1)');
          attempts++;
          if (attempts < maxRetries) {
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
          throw Exception('roundNumber invalide: $roundNumber');
        }
        
        if (clampedAnnouncement < 2 || clampedAnnouncement > 13) {
          print('⚠️ announcementValue invalide pour $botName: $clampedAnnouncement (doit être entre 2 et 13)');
          throw Exception('announcementValue invalide: $clampedAnnouncement (doit être entre 2 et 13)');
        }
        
        print('✅ Validation OK pour $botName: gameId=$gameId, roundNumber=$roundNumber, announcementValue=$clampedAnnouncement');
        
        // ✅ Envoyer l'annonce au backend
        await GameApiService.instance.makeAnnouncement(
          gameId: gameId,
          roundNumber: roundNumber,
          announcementValue: clampedAnnouncement,
          playerName: botName, // ✅ Passer le nom du bot
        );
        
        print('✅ Annonce du bot $botName envoyée au backend avec succès: $clampedAnnouncement plis');
        
        // Mettre à jour l'UI
        if (mounted) {
          setState(() {});
        }
        
        return; // Succès, sortir de la boucle
        
      } catch (e) {
        lastError = e is Exception ? e : Exception('$e');
        attempts++;
        
        // ✅ CORRECTION: Si l'erreur indique que l'annonce a déjà été soumise (400), ne pas retry
        final errorString = e.toString().toLowerCase();
        final isAlreadySubmitted = errorString.contains('déjà soumis') || 
                                   errorString.contains('already submitted') ||
                                   errorString.contains('400');
        
        if (isAlreadySubmitted) {
          print('✅ $botName a déjà soumis son annonce (erreur 400), arrêt des tentatives');
          // Vérifier si l'annonce est dans l'état local, sinon l'ajouter
          final announcements = cardManager.getCurrentRoundAnnouncements();
          final alreadyInLocal = announcements.any(
            (ann) => ann['player'] == botName,
          );
          if (!alreadyInLocal) {
            // L'annonce a été soumise au backend mais n'est pas encore dans l'état local
            // Elle sera ajoutée via l'événement WebSocket, donc on attend juste
            print('   ⏳ Attente de l\'événement WebSocket pour synchroniser l\'annonce...');
          }
          return; // Sortir sans erreur car l'annonce a bien été soumise
        }
        
        print('❌ Erreur annonce automatique bot $botName (tentative $attempts/$maxRetries): $e');
        
        if (attempts < maxRetries) {
          // Attendre avant de réessayer (délai progressif)
          final delay = Duration(milliseconds: 1000 * attempts);
          print('⏳ Nouvelle tentative dans ${delay.inSeconds} seconde(s)...');
          await Future.delayed(delay);
        }
      }
    }
    
    // Si on arrive ici, toutes les tentatives ont échoué
    print('❌ Échec définitif: Impossible d\'envoyer l\'annonce du bot $botName après $maxRetries tentatives');
    if (lastError != null) {
      print('   Dernière erreur: $lastError');
    }
  }

  // ✅ NOUVEAU: Démarrer le minuteur de la phase d'annonces basé sur le timestamp serveur
  void _startAnnouncementPhaseTimer(int startTimestamp, int duration) {
    _announcementPhaseTimer?.cancel();
    
    // Calculer le temps restant basé sur le timestamp serveur
    void updateCountdown() {
      if (!mounted) return;
      
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000; // Timestamp en secondes
      final elapsed = now - startTimestamp;
      final remaining = (duration - elapsed).clamp(0, duration);
      
      if (mounted) {
        setState(() {
          _announcementCountdown = remaining;
        });
      }
      
      // ✅ CORRECTION: Si le temps est écoulé, vérifier que tous les joueurs ont annoncé
      // Si certains n'ont pas annoncé, leur assigner automatiquement 2 plis
      if (remaining <= 0) {
        _announcementPhaseTimer?.cancel();
        
        // ✅ Vérifier que tous les joueurs ont fait leur annonce (de manière asynchrone)
        if (mounted && cardManager.isAnnouncementPhase) {
          _handleAnnouncementPhaseTimeout();
        }
      }
    }
    
    // Mettre à jour immédiatement
    updateCountdown();
    
    // Mettre à jour chaque seconde
    _announcementPhaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      updateCountdown();
    });
  }

  // ✅ NOUVEAU: Gérer le timeout de la phase d'annonces simultanées
  Future<void> _handleAnnouncementPhaseTimeout() async {
    final allPlayers = gameSession.players
        .map((p) => p['name'] as String? ?? 'Joueur')
        .toList();
    final announcements = cardManager.getCurrentRoundAnnouncements();
    
    for (final playerName in allPlayers) {
      final hasAnnounced = announcements.any(
        (ann) => ann['player'] == playerName,
      );
      
      if (!hasAnnounced) {
        print('⏰ Fin du timer de phase - $playerName n\'a pas annoncé, assignation automatique de 2 plis');
        _forceAnnouncementForPlayer(playerName, 2);
        
        // ✅ Envoyer l'annonce au backend si c'est le joueur local
        if (playerName == widget.currentPlayerName) {
          try {
            var gameId = _currentGameId;
            if (gameId == null) {
              gameId = await getGameId();
            }
            final roundNumber = gameSession.currentRound;
            
            if (gameId != null && roundNumber >= 1) {
              await GameApiService.instance.makeAnnouncement(
                gameId: gameId,
                roundNumber: roundNumber,
                announcementValue: 2,
              );
              print('✅ Annonce timeout (2 plis) envoyée au backend pour $playerName');
            }
          } catch (e) {
            print('⚠️ Erreur lors de l\'envoi de l\'annonce timeout au backend: $e');
            // L'annonce est déjà enregistrée localement, le backend la synchronisera via WebSocket
          }
        } else {
          // ✅ Envoyer au backend au nom du joueur qui a timeout
          // Cela permet de forcer la sauvegarde de son annonce en BDD si son appareil a crash/déconnecté
          try {
            var gameId = _currentGameId;
            if (gameId == null) {
              gameId = await getGameId();
            }
            final roundNumber = gameSession.currentRound;
            
            if (gameId != null && roundNumber >= 1) {
              await GameApiService.instance.makeAnnouncement(
                gameId: gameId,
                roundNumber: roundNumber,
                announcementValue: 2,
                playerName: playerName, // Le backend accepte qu'on fournisse un nom
              );
              print('✅ Annonce timeout (2 plis) envoyée au backend pour $playerName par ${widget.currentPlayerName}');
            }
          } catch (e) {
            print('⚠️ Erreur lors de l\'envoi de l\'annonce timeout au backend pour $playerName: $e');
          }
        }
      }
    }

    await _tryCompleteAnnouncementPhaseFromBackend(reason: 'phase_timeout');
  }

  void _forceAnnouncementForPlayer(String playerName, int announcement) {
    final int clampedAnnouncement = announcement.clamp(2, 13).toInt();
    if (playerName == widget.currentPlayerName) {
      // ✅ Joueur local - annuler le timer et cacher le panneau
      announcementTimer?.cancel();
      cardManager.makeAnnouncement(playerName, clampedAnnouncement);
      if (mounted) {
        setState(() {
          hasAnnounced = true;
          currentAnnouncement = clampedAnnouncement;
          // ✅ Réinitialiser currentAnnouncementPlayer pour cacher le panneau
          currentAnnouncementPlayer = null;
        });
      } else {
        hasAnnounced = true;
        currentAnnouncement = clampedAnnouncement;
        currentAnnouncementPlayer = null;
      }
    } else {
      // ✅ Autre joueur - ne pas toucher au timer ni au panneau du joueur local
      print('   ✅ Force annonce pour $playerName: $clampedAnnouncement plis');
      cardManager.forceAnnouncement(playerName, clampedAnnouncement);
      // ✅ Mettre à jour l'UI même pour les autres joueurs (pour afficher leur annonce)
      if (mounted) {
        setState(() {});
      }
    }
  }
  
  // ✅ Surcharger startNewRound pour envoyer la distribution via WebSocket
  @override
  Future<void> startNewRound() async {
    try {
      final playerNames = gameSession.players
          .map((p) => p['name'] as String? ?? 'Joueur')
          .toList();

      // ✅ Vérifier si c'est le créateur qui démarre la nouvelle manche
      final isCreator = gameSession.players.any(
        (p) => (p['name'] as String?) == widget.currentPlayerName &&
            (p['isCreator'] as bool?) == true,
      );

      if (isCreator) {
        // ✅ LE CRÉATEUR demande au backend de distribuer les cartes
        print('👑 Créateur: demande de redistribution des cartes au backend...');
        
        // Réinitialiser l'état d'annonces/pli
        isProcessingRoundCompletion = false;
        cardManager.resetRoundCounters();
        cardManager.clearCurrentTrick();
        
        final roomId = gameSession.roomId ?? '';
        if (roomId.isEmpty) {
          print('❌ Room ID manquant, impossible de redistribuer');
          return;
        }
        
        try {
          // ✅ Appeler l'API backend pour distribuer les cartes
          await GameApiService.instance.distributeCards(
            roomId: roomId,
            roundNumber: gameSession.currentRound + 1,
            testMode: _useTestDistribution,
          ).then((response) {
            print('✅ Backend a redistribué les cartes: $response');
            _applyGameStateFromDistributeCardsResponse(response);
          }).catchError((e) {
            print('❌ Erreur lors de la demande de redistribution: $e');
            print('❌ ERREUR CRITIQUE: Le backend n\'a pas pu redistribuer les cartes');
            print('   La distribution locale est DÉSACTIVÉE - seul le backend peut distribuer');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Erreur: Impossible de redistribuer les cartes. Veuillez réessayer.'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              );
            }
          });
        } catch (e) {
          print('❌ Exception lors de la demande de redistribution: $e');
          print('❌ ERREUR CRITIQUE: Exception lors de la redistribution');
          print('   La distribution locale est DÉSACTIVÉE - seul le backend peut distribuer');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erreur: Impossible de redistribuer les cartes. Veuillez réessayer.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      } else {
        // ✅ LES AUTRES JOUEURS attendent la distribution via WebSocket
        // La distribution sera reçue via _cardDistributionSubscription
        print('⏳ Attente de la redistribution depuis le créateur...');
      }
    } catch (e) {
      print('❌ Erreur démarrage nouvelle manche: $e');
    }
  }

  Widget _buildAnnouncementNotification() {
    // ✅ Supprimé : Les compteurs de plis indiquent déjà qui a annoncé
    // Pas besoin d'afficher un message supplémentaire
    return const SizedBox.shrink();
  }

  void _showGameMenu() {
    // Afficher directement le tableau de scores
    final players = gameSession.players
        .map((p) => p['name'] as String? ?? 'Joueur')
        .toList();
    
    final announcements = cardManager.getCurrentRoundAnnouncements();
    final Map<String, int> announcedByPlayer = {
      for (final p in players)
        p: (announcements.firstWhere(
              (a) => a['player'] == p,
              orElse: () => {'announcement': 0},
            )['announcement'] as int? ?? 0),
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
    
    showScoreboardDialog(
      players,
      announcedByPlayer,
      obtainedByPlayer,
      scores,
      autoClose: false, // ✅ Joueur ouvre manuellement, pas de fermeture automatique
    );
  }

  void _showLeaveGameConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E2B23),
        title: const Text('Quitter la partie?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Êtes-vous sûr de vouloir quitter la partie?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Quitter', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Widget pour afficher les logs de débogage dans l'UI
  Widget _buildDebugLogs() {
    return Positioned(
      top: 50,
      right: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bouton pour activer/désactiver l'affichage des logs
          GestureDetector(
            onTap: () {
              setState(() {
                _showDebugLogs = !_showDebugLogs;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _showDebugLogs ? Colors.green : Colors.grey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _showDebugLogs ? '📋' : '📋',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          // Panneau de logs
          if (_showDebugLogs)
            Container(
              width: 300,
              height: 400,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Logs Debug',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _debugLogs.clear();
                          });
                        },
                        child: const Text(
                          'Effacer',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  Expanded(
                    child: ListView.builder(
                      reverse: true, // Afficher les plus récents en premier
                      itemCount: _debugLogs.length,
                      itemBuilder: (context, index) {
                        final log = _debugLogs[_debugLogs.length - 1 - index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            log,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}