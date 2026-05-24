import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/user/user_service.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import '../../services/api/game_api_service.dart';
import '../../services/api/payment_api_service.dart';
import '../../services/game/game_service.dart';
import 'dart:async';
import '../../models/game/game_session.dart';
import '../../models/game/local_card_manager.dart';
import '../../models/game/game_logic.dart';
import '../room/create_room_page.dart';
import '../home/user_menu_page.dart';
import '../../services/websocket/game_websocket_service.dart';
import '../../services/api/user_api_service.dart';
import '../../config/game_constants.dart';

class GameRoomPage extends StatefulWidget {
  final String roomName;
  final String roomCode;
  final int minimumBet;
  final String currentPlayerName; // Nom du joueur actuel

  const GameRoomPage({
    super.key,
    required this.roomName,
    required this.roomCode,
    required this.minimumBet,
    this.currentPlayerName = 'Vous', // Par défaut "Vous"
  });

  @override
  State<GameRoomPage> createState() => _GameRoomPageState();
}

class _GameRoomPageState extends State<GameRoomPage>
    with TickerProviderStateMixin {
  late GameSession _gameSession;
  late LocalCardManager _cardManager;
  late GameLogic _gameLogic;

  // Timer pour les annonces
  Timer? _announcementTimer;
  Timer? _roomPollTimer;
  Timer? _reconnectionCheckTimer;
  int _announcementCountdown =
      30; // Valeur par défaut (sera ajustée selon le mode dans _startAnnouncementTimer)
  bool _hasAnnounced = false;
  String? _currentAnnouncementPlayer;
  int _currentAnnouncement = 2; // Valeur par défaut pour l'annonce
  bool _waitingForHumans = false;
  bool _isProcessingAnnouncementTurn = false; // Flag pour éviter les appels multiples
  String? _currentPlayerPlaying; // Flag pour empêcher qu'un joueur joue plusieurs cartes au même tour
  bool _isWebSocketConnected = false;
  Timer? _stateSyncTimer;
  int _consecutiveStatePollingErrors = 0;
  DateTime? _lastSuccessfulStatePoll;
  bool _hasGameStarted = false;
  int get _requiredPlayers =>
      GameConstants.requiredPlayerCount(playWithBots: _gameSession.playWithBots);

  // Gestion WebSocket
  StreamSubscription? _wsConnectSubscription;
  StreamSubscription? _wsDisconnectSubscription;
  StreamSubscription? _wsErrorSubscription;

  // Gestion des remplacements temporaires (déconnexion < 15s) et définitifs (> 15s ou départ manuel)
  // Map<playerName, replacementInfo> où replacementInfo contient {botName, timestamp, isPermanent}
  final Map<String, Map<String, dynamic>> _temporaryReplacements = {};
  final Set<String> _permanentlyExcludedPlayers =
      {}; // Joueurs définitivement exclus

  // Subscriptions WebSocket pour les événements de remplacement
  StreamSubscription? _playerReplacedSubscription;
  StreamSubscription? _playerRestoredSubscription;
  StreamSubscription? _playerDisconnectedSubscription;
  StreamSubscription? _playerReconnectedSubscription;
  StreamSubscription? _announcementMadeSubscription;
  StreamSubscription? _roomChatMessageSubscription;
  StreamSubscription? _cardPlayedSubscription;

  // Animation pour la carte qui se déplace vers le centre
  late AnimationController _cardAnimationController;
  Animation<double>? _cardAnimation;
  Map<String, dynamic>? _animatedCard;
  String? _animatingPlayerName; // Nom du joueur qui anime la carte
  bool _isAnimatingCard = false;

  // Chat de salon (mode humain)
  bool _chatFeatureInitialized = false;
  bool _isChatPanelVisible = false;
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<Map<String, String>> _quickChatOptions = [
    {
      'label': 'Jouez vite les gars !',
      'message': 'Jouez vite les gars !',
      'code': 'play_fast',
    },
    {
      'label': 'Je suis mort 😢',
      'message': 'Je suis mort 😢',
      'code': 'i_am_dead',
    },
    {'label': 'Ok', 'message': 'Ok', 'code': 'ok'},
    {
      'label': 'Bonne chance !',
      'message': 'Bonne chance à tous !',
      'code': 'good_luck',
    },
  ];
  final List<String> _emojiOptions = [
    '😂',
    '😭',
    '👍',
    '👎',
    '✅',
    '💪',
    '👀',
    '🖕',
    '💋',
    '🥇',
  ];
  List<Map<String, dynamic>> _chatMessages = [];
  Timer? _chatPollingTimer;
  Timer? _chatToastTimer;
  int? _lastChatMessageId;
  bool _isSendingChatMessage = false;
  Map<String, dynamic>? _chatToastMessage;
  // Animation pour le toast qui traverse l'écran
  late AnimationController _chatToastAnimationController;
  Animation<double>? _chatToastAnimation;

  static const Duration _pollIntervalWebSocket = Duration(seconds: 6);
  static const Duration _pollIntervalFallback = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    // Forcer le mode paysage pendant le salon
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _gameSession = GameSession.instance;
    _cardManager = LocalCardManager.instance;
    _gameLogic = GameLogic.instance;

    // Initialiser l'animation de la carte
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );
    _cardAnimation = CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeInOut,
    );

    // Initialiser l'animation du toast de chat
    _chatToastAnimationController = AnimationController(
      duration: const Duration(milliseconds: 7000), // 7 secondes pour traverser (plus de temps pour lire)
      vsync: this,
    );
    _chatToastAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _chatToastAnimationController,
        curve: Curves.linear,
      ),
    );

    _initializeGameSession();

    // Si partie humains, attendre le nombre requis de joueurs avant de démarrer
    if (!_gameSession.playWithBots && _requiredPlayers > 0) {
      _waitingForHumans = true;
      _startRoomPolling();
    }

    // ⚠️ IMPORTANT: Initialiser les listeners WebSocket pour les événements backend
    _initializeWebSocketListeners();
  }

  // Initialiser les listeners WebSocket pour les événements de remplacement
  void _initializeWebSocketListeners() {
    final wsService = GameWebSocketService();
    
    // Se connecter au WebSocket si pas déjà connecté
    if (!wsService.isConnected) {
      wsService.connect().then((_) {
        // ✅ IMPORTANT: Rejoindre la room une fois connecté
        final roomId = _gameSession.roomId;
        final playerName = widget.currentPlayerName;
        if (roomId != null && roomId.isNotEmpty && playerName.isNotEmpty) {
          wsService.joinRoom(roomId, playerName).catchError((error) {
            print('⚠️ Erreur lors de la jointure de la room WebSocket: $error');
          });
        }
      }).catchError((error) {
        print('⚠️ Impossible de se connecter au WebSocket: $error');
        print('ℹ️ L\'application continuera en mode local (sans synchronisation temps réel)');
        // Ne pas bloquer l'application si le WebSocket n'est pas disponible
      });
    } else {
      // ✅ Si déjà connecté, rejoindre la room immédiatement
      final roomId = _gameSession.roomId;
      final playerName = widget.currentPlayerName;
      if (roomId != null && roomId.isNotEmpty && playerName.isNotEmpty) {
        wsService.joinRoom(roomId, playerName).catchError((error) {
          print('⚠️ Erreur lors de la jointure de la room WebSocket: $error');
        });
      }
    }
    setState(() {
      _isWebSocketConnected = wsService.isConnected;
    });

    _wsConnectSubscription = wsService.onConnect().listen((_) {
      if (!mounted) return;
      setState(() {
        _isWebSocketConnected = true;
      });
      // ✅ Rejoindre la room après connexion
      final roomId = _gameSession.roomId;
      final playerName = widget.currentPlayerName;
      if (roomId != null && roomId.isNotEmpty && playerName.isNotEmpty) {
        wsService.joinRoom(roomId, playerName).catchError((error) {
          print('⚠️ Erreur lors de la jointure de la room WebSocket: $error');
        });
      }
      _startStateSyncPolling(forceRestart: true);
    });

    _wsDisconnectSubscription = wsService.onDisconnect().listen((_) {
      if (!mounted) return;
      setState(() {
        _isWebSocketConnected = false;
      });
      _startStateSyncPolling(forceRestart: true);
    });

    _wsErrorSubscription = wsService.onError().listen((error) {
      if (!mounted) return;
      setState(() {
        _isWebSocketConnected = false;
      });
      _startStateSyncPolling(forceRestart: true);
    });

    // Écouter le remplacement d'un joueur par un bot (événement backend)
    _playerReplacedSubscription = wsService.onPlayerReplaced().listen((data) {
      if (mounted) {
        final playerName = data['player_name'] as String?;
        final botName = data['bot_name'] as String?;
        final isPermanent = (data['is_permanent'] as bool?) ?? false;

        if (playerName != null && botName != null) {
          print(
            '📡 WebSocket: Joueur $playerName remplacé par $botName (permanent: $isPermanent)',
          );

          // Si ce n'est pas le joueur actuel, synchroniser le remplacement
          if (playerName != widget.currentPlayerName) {
            // Le backend a confirmé le remplacement, synchroniser localement
            _synchronizePlayerReplacement(playerName, botName, isPermanent);
          } else if (isPermanent) {
            // Le joueur actuel a été exclu définitivement
            _permanentlyExcludedPlayers.add(playerName);
            if (mounted) {
              _showPlayerExcludedDialog();
            }
          }
        }
      }
    });

    // Écouter la restauration d'un joueur (événement backend)
    _playerRestoredSubscription = wsService.onPlayerRestored().listen((data) {
      if (mounted) {
        final playerName = data['player_name'] as String?;
        final botName = data['bot_name'] as String?;

        if (playerName != null && botName != null) {
          print(
            '📡 WebSocket: Joueur $playerName restauré, bot $botName retiré',
          );

          // Synchroniser la restauration
          if (playerName != widget.currentPlayerName) {
            _synchronizePlayerRestoration(playerName, botName);
          } else {
            // Le joueur actuel a été restauré
            _temporaryReplacements.remove(playerName);
          }
        }
      }
    });

    // Écouter les déconnexions (événement backend)
    _playerDisconnectedSubscription = wsService.onPlayerDisconnected().listen((
      data,
    ) {
      if (mounted) {
        final playerName = data['player_name'] as String?;
        final roomId = data['room_id'] as String?;

        if (playerName != null && roomId == _gameSession.roomId) {
          print('📡 WebSocket: Déconnexion détectée pour $playerName');

          // Si ce n'est pas le joueur actuel et qu'on n'a pas déjà géré cette déconnexion
          if (playerName != widget.currentPlayerName &&
              !_temporaryReplacements.containsKey(playerName)) {
            _handlePlayerDisconnection(playerName);
          }
        }
      }
    });

    // Écouter les reconnexions (événement backend)
    _playerReconnectedSubscription = wsService.onPlayerReconnected().listen((
      data,
    ) {
      if (mounted) {
        final playerName = data['player_name'] as String?;
        final canRestore = (data['can_restore'] as bool?) ?? false;
        final roomId = data['room_id'] as String?;

        if (playerName != null && roomId == _gameSession.roomId) {
          print(
            '📡 WebSocket: Reconnexion détectée pour $playerName (peut restaurer: $canRestore)',
          );

          if (canRestore && _temporaryReplacements.containsKey(playerName)) {
            _handlePlayerReconnection(playerName);
          } else if (!canRestore) {
            // Reconnexion trop tardive, rendre permanent
            if (_temporaryReplacements.containsKey(playerName)) {
              _temporaryReplacements[playerName]!['isPermanent'] = true;
              _permanentlyExcludedPlayers.add(playerName);
            }
          }
        }
      }
    });

    // Écouter les annonces faites par les autres joueurs
    _announcementMadeSubscription = wsService.onAnnouncementMade().listen((data) {
      if (mounted) {
        // Gérer les deux formats : camelCase et snake_case
        final playerName = data['playerName'] as String? ?? 
                          data['player_name'] as String?;
        final announcement = data['announcement'] as int?;
        final roomId = data['roomId'] as String? ?? 
                      data['room_id'] as String?;

        if (playerName != null && 
            announcement != null && 
            roomId == _gameSession.roomId &&
            playerName != widget.currentPlayerName) {
          print('📡 WebSocket: Annonce reçue de $playerName : $announcement plis');
          
          // Synchroniser l'annonce localement
          _cardManager.makeAnnouncement(playerName, announcement);
          
          // Debug: vérifier que l'annonce a bien été ajoutée
          final allAnnouncements = _cardManager.getCurrentRoundAnnouncements();
          print('📊 Total annonces après ajout: ${allAnnouncements.length}');
          for (var ann in allAnnouncements) {
            print('  - ${ann['player']}: ${ann['announcement']} plis');
          }
          
          // Forcer la mise à jour de l'interface pour afficher toutes les annonces
          if (mounted) {
            setState(() {
              // Mettre à jour l'interface - cela déclenchera la reconstruction
              // de tous les widgets qui utilisent _getPlayerAnnouncementDisplay
            });
            print('✅ setState() appelé pour mettre à jour l\'affichage des annonces');
          }
          
          // Vérifier si toutes les annonces sont faites
          final playerNames = _gameSession.players
              .map((player) => player['name'] as String? ?? 'Joueur')
              .toList();
          if (_cardManager.areAllAnnouncementsDone(playerNames)) {
            _handleAnnouncementTurnComplete();
          }
        }
      }
    });

    // Écouter les messages de chat des autres joueurs
    _roomChatMessageSubscription = wsService.onRoomChatMessage().listen((data) {
      if (mounted) {
        // Gérer les deux formats : camelCase et snake_case
        final playerName = data['playerName'] as String? ?? 
                          data['player_name'] as String?;
        final message = data['message'] as String?;
        final messageType = data['message_type'] as String? ?? 'text';
        final roomId = data['roomId'] as String? ?? 
                      data['room_id'] as String?;

        if (playerName != null && 
            message != null && 
            roomId == _gameSession.roomId &&
            playerName != widget.currentPlayerName) {
          print('📡 WebSocket: Message de chat reçu de $playerName : $message');
          
          // Créer le message pour l'afficher
          final messageData = <String, dynamic>{
            'id': DateTime.now().millisecondsSinceEpoch,
            'user_id': null,
            'pseudo': playerName,
            'message': message,
            'message_type': messageType,
            if (data['preset_code'] != null) 'preset_code': data['preset_code'],
            'created_at': DateTime.now().toIso8601String(),
          };

          setState(() {
            // Ajouter le message à la liste locale
            _chatMessages.add(messageData);
            // Limiter à 120 messages en mémoire
            if (_chatMessages.length > 120) {
              _chatMessages = _chatMessages.sublist(_chatMessages.length - 120);
            }
          });

          // Afficher le toast pour tous les joueurs
          _showChatToast(messageData);
          _scrollChatToBottom();
        }
      }
    });

    // ✅ Écouter les cartes jouées par les autres joueurs
    _cardPlayedSubscription = wsService.onCardPlayed().listen((data) {
      if (mounted) {
        // Gérer les deux formats : camelCase et snake_case
        final playerName = data['playerName'] as String? ?? 
                          data['player_name'] as String?;
        final cardData = data['card'] as Map<String, dynamic>?;
        final roomId = data['roomId'] as String? ?? 
                      data['room_id'] as String?;

        if (playerName != null && 
            cardData != null && 
            roomId == _gameSession.roomId &&
            playerName != widget.currentPlayerName) {
          print('📡 WebSocket: Carte jouée reçue de $playerName : $cardData');
          
          // Reconstruire la carte depuis les données reçues
          final cardSuitShort = (cardData['suit'] as String? ?? '').toUpperCase();
          final cardValueShort = (cardData['value'] as String? ?? '').toUpperCase();
          
          // Mapping des suits (format court -> format long)
          final suitMapping = {
            'S': 'SPADES',
            'C': 'CLUBS',
            'H': 'HEARTS',
            'D': 'DIAMONDS',
          };
          final suitName = suitMapping[cardSuitShort] ?? cardSuitShort;
          
          // Mapping des valeurs (format court -> format long)
          final valueMapping = {
            'A': 'ACE',
            'K': 'KING',
            'Q': 'QUEEN',
            'J': 'JACK',
            '0': '10', // Le 10 est stocké comme "0" dans le code
          };
          final valueName = valueMapping[cardValueShort] ?? cardValueShort;
          
          // Construire le code de la carte (format: "AS", "0S", "JS", etc.)
          final normalizedValue = cardValueShort == '10' ? '0' : cardValueShort;
          final cardCode = '$normalizedValue$cardSuitShort';
          
          // Synchroniser la carte jouée localement
          // Forcer le tour localement pour rester aligné avec le backend
          _cardManager.currentPlayerTurn = playerName;
          
          final playerCards = _cardManager.getPlayerCards(playerName);
          // Trouver la carte exacte dans la main du joueur
          Map<String, dynamic>? existingCard;
          try {
            existingCard = playerCards.firstWhere(
              (c) => (c['code'] as String?) == cardCode,
            );
          } catch (_) {
            existingCard = null;
          }
          
          final fallbackCard = LocalCardManager.instance.getCardByCode(cardCode);
          
          var card = existingCard ??
              fallbackCard ??
              {
                'code': cardCode,
                'value': valueName,
                'suit': suitName,
                'image': _cardManager.getCardImagePath({
                  'code': cardCode,
                  'value': valueName,
                  'suit': suitName,
                }),
              };
          
          // S'assurer que la carte existe dans la main du joueur (pour permettre à la logique de jeu de la traiter)
          _cardManager.ensureCardInPlayerHand(playerName, card);
          final refreshedPlayerCards = _cardManager.getPlayerCards(playerName);
          // Rechercher à nouveau la carte dans la main après ajout pour garantir la référence correcte
          try {
            card = refreshedPlayerCards.firstWhere(
              (c) => (c['code'] as String?) == cardCode,
            );
          } catch (_) {
            // garder la carte existante
          }
          
          // Animer la carte depuis le joueur concerné
          _startCardAnimation(card, playerName, () {
            if (!mounted) return;
            
            final result = _gameLogic.playCard(
              card,
              playerName,
              refreshedPlayerCards,
            );
            
            if (result['success'] == true) {
              _cardManager.playCard(playerName, card);
              
              if (mounted) {
                setState(() {});
              }
              
              if (result['trickComplete'] == true) {
                final winner = result['winner'] as String? ?? '';
                print('🕒 Pli complété (carte distante) - attente de trick_completed du backend (winner: $winner)');
              } else {
                if (mounted) setState(() {});
                _maybeAutoPlayCurrentBot();
              }
            }
          });
        }
      }
    });
  }

  // Synchroniser un remplacement venant du backend
  void _synchronizePlayerReplacement(
    String playerName,
    String botName,
    bool isPermanent,
  ) {
    // Vérifier si le joueur existe dans la liste
    final players = _gameSession.players;
    final playerIndex = players.indexWhere(
      (p) => (p['name'] as String?) == playerName,
    );

    if (playerIndex != -1) {
      // Enregistrer le remplacement temporaire si nécessaire
      if (!isPermanent) {
        _temporaryReplacements[playerName] = {
          'botName': botName,
          'timestamp': DateTime.now(),
          'isPermanent': false,
        };
      } else {
        _permanentlyExcludedPlayers.add(playerName);
      }

      // Appliquer le remplacement localement (sans appeler l'API pour éviter une boucle)
      _replacePlayerWithBotLocally(playerName, botName, isPermanent);
    }
  }

  // Synchroniser une restauration venant du backend
  void _synchronizePlayerRestoration(String playerName, String botName) {
    // Restaurer le joueur localement
    _restorePlayer(playerName);
  }

  // Remplacer un joueur localement (sans notifier le backend - utilisé pour la synchronisation)
  void _replacePlayerWithBotLocally(
    String playerName,
    String botName,
    bool isPermanent,
  ) {
    final players = _gameSession.players;
    final playerIndex = players.indexWhere(
      (p) => (p['name'] as String?) == playerName,
    );

    if (playerIndex != -1) {
      final player = players[playerIndex];
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

      // Transférer les cartes
      final playerCards = _cardManager.getPlayerCards(playerName);
      if (playerCards.isNotEmpty) {
        _cardManager.transferPlayerCards(playerName, botName);
      }

      // Transférer les plis
      _cardManager.transferObtainedTricks(playerName, botName);

      // Mettre à jour le tour
      if (_cardManager.currentPlayerTurn == playerName) {
        _cardManager.currentPlayerTurn = botName;
      }

      print('✅ Synchronisation locale: $playerName → $botName');
      setState(() {});
    }
  }

  // Détermine le joueur qui doit commencer la PHASE DE JEU pour un round donné
  // Rotation: créateur → droite → haut → gauche → créateur → ...
  String _getStartingPlayerForRoundPlay(int roundNumber) {
    // Construire le mapping position -> nom
    final Map<String, String> posToName = {};
    for (final p in _gameSession.players) {
      final name = (p['name'] as String?) ?? 'Joueur';
      final pos = (p['displayPosition'] as String?) ?? 'bottom';
      posToName[pos] = name;
    }
    // Récupérer la position du créateur
    String creatorPos = 'bottom';
    for (final p in _gameSession.players) {
      if ((p['isCreator'] as bool?) == true) {
        creatorPos = (p['displayPosition'] as String?) ?? creatorPos;
        break;
      }
    }
    final order = ['bottom', 'right', 'top', 'left'];
    final startIndex = order.indexOf(creatorPos);
    if (startIndex == -1)
      return posToName['bottom'] ??
          (_gameSession.players.first['name'] as String);
    final pos = order[(startIndex + (roundNumber - 1)) % 4];
    return posToName[pos] ?? (_gameSession.players.first['name'] as String);
  }

  @override
  void dispose() {
    _roomPollTimer?.cancel();
    _stateSyncTimer?.cancel();
    _continueCountdownTimer?.cancel(); // Nettoyer le timer de continuation
    _roomCodeCheckTimer
        ?.cancel(); // Nettoyer le timer de vérification du code du salon
    _reconnectionCheckTimer
        ?.cancel(); // Nettoyer le timer de vérification de reconnexion
    _chatPollingTimer?.cancel();
    _chatToastTimer?.cancel();
    _chatToastAnimationController.dispose();

    // Nettoyer les subscriptions WebSocket
    _playerReplacedSubscription?.cancel();
    _playerRestoredSubscription?.cancel();
    _playerDisconnectedSubscription?.cancel();
    _playerReconnectedSubscription?.cancel();
    _announcementMadeSubscription?.cancel();
    _roomChatMessageSubscription?.cancel();
    _cardPlayedSubscription?.cancel();
    _wsConnectSubscription?.cancel();
    _wsDisconnectSubscription?.cancel();
    _wsErrorSubscription?.cancel();

    // Rétablir orientations par défaut (portrait autorisé)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _announcementTimer?.cancel();
    _cardAnimationController.dispose();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _initializeGameSession() {
    // Bloquer l'accès si la session backend n'est pas initialisée
    if (_gameSession.roomId == null || (_gameSession.roomId?.isEmpty ?? true)) {
      print('⚠️ Aucune session backend. Redirection création/join requise.');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return;
    }

    // ⚠️ IMPORTANT: Vérifier si le joueur actuel a été exclu définitivement
    _checkPlayerExclusion();

    // Initialiser le chat de salon (mode humain)
    _initializeChatFeature();

    // Utiliser les joueurs déjà fournis par la session (créés via backend)
    final players = _gameSession.players;
    print('📊 Liste des joueurs dans session: ${players.length}');
    print('📊 Liste des joueurs : ${players.map((p) => p['name']).join(', ')}');

    // ⚠️ IMPORTANT: En mode bot, si les joueurs ne sont pas initialisés, les récupérer depuis le backend
    if (players.isEmpty || players.length < _requiredPlayers) {
      print(
        '⚠️ Liste de joueurs vide ou incomplète. Récupération depuis le backend...',
      );
      _loadPlayersFromBackend().then((_) {
        // Après chargement, démarrer la distribution
        _startCardDistribution();
      });
    } else {
      // Démarrer la distribution des cartes
      _startCardDistribution();
    }
  }

  void _initializeChatFeature() {
    if (_chatFeatureInitialized) return;
    // Le chat est uniquement disponible en mode humain
    if (_gameSession.playWithBots) return;
    if ((_gameSession.roomId ?? '').isEmpty) return;
    _chatFeatureInitialized = true;
    _startChatPolling();
  }

  int? _parseRoomId() {
    final value = _gameSession.roomId ?? '';
    return int.tryParse(value);
  }

  void _startChatPolling() {
    // Le chat fonctionne uniquement en mode local, pas de polling nécessaire
    // Les messages sont stockés uniquement en mémoire pendant la session
    _chatPollingTimer?.cancel();
    print('💬 Chat du salon initialisé en mode local (pas de stockage en base)');
  }

  // Fonction supprimée : _fetchChatMessages n'est plus nécessaire
  // Les messages sont gérés uniquement en mémoire locale

  Future<void> _sendChatMessage({
    required String message,
    String type = 'text',
    String? presetCode,
  }) async {
    if (_isSendingChatMessage) return;
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isSendingChatMessage = true;
    });

    // Créer le message localement
    final messageData = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch, // ID unique basé sur le timestamp
      'user_id': null, // Pas nécessaire pour le chat local
      'pseudo': widget.currentPlayerName,
      'message': trimmed,
      'message_type': type,
      if (presetCode != null) 'preset_code': presetCode,
      'created_at': DateTime.now().toIso8601String(),
    };

    if (!mounted) return;

    // Ajouter le message localement immédiatement (optimistic UI)
    setState(() {
      _chatMessages.add(messageData);
      // Limiter à 120 messages en mémoire
      if (_chatMessages.length > 120) {
        _chatMessages = _chatMessages.sublist(_chatMessages.length - 120);
      }
      _lastChatMessageId = messageData['id'] as int?;
    });

    _chatInputController.clear();
    _showChatToast(messageData);
    _scrollChatToBottom();
    // Fermer automatiquement le panneau de chat après envoi
    if (_isChatPanelVisible) {
      setState(() {
        _isChatPanelVisible = false;
      });
    }

    // Envoyer le message via WebSocket pour synchroniser avec les autres joueurs
    final roomId = _gameSession.roomId;
    if (roomId != null && roomId.isNotEmpty) {
      try {
        final wsService = GameWebSocketService();
        if (wsService.isConnected) {
          await wsService.sendChatMessage(
            message: trimmed,
            type: type,
            presetCode: presetCode,
          ).catchError((e) {
            print('⚠️ Erreur WebSocket lors de l\'envoi du message: $e');
            // Continuer même en cas d'erreur WebSocket
          });
        }
      } catch (e) {
        print('⚠️ Erreur lors de l\'envoi du message via WebSocket: $e');
        // Continuer même en cas d'erreur WebSocket
      }
    }

    setState(() {
      _isSendingChatMessage = false;
    });
  }

  void _handleSendChatInput() {
    final text = _chatInputController.text.trim();
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

  // Obtenir la couleur de fond pour un emoji donné
  Color _getEmojiBackgroundColor(String emoji) {
    switch (emoji) {
      case '😂':
        return Colors.amber.withOpacity(0.3); // Jaune/Orange pour le rire
      case '😭':
        return Colors.blue.withOpacity(0.3); // Bleu pour la tristesse
      case '👍':
        return Colors.green.withOpacity(0.3); // Vert pour l'approbation
      case '👎':
        return Colors.red.withOpacity(0.3); // Rouge pour la désapprobation
      case '✅':
        return Colors.greenAccent.withOpacity(
          0.3,
        ); // Vert clair pour la validation
      case '💪':
        return Colors.orange.withOpacity(0.3); // Orange pour la force
      case '👀':
        return Colors.purple.withOpacity(0.3); // Violet pour l'observation
      case '🖕':
        return Colors.redAccent.withOpacity(0.3); // Rouge vif pour la défiance
      case '💋':
        return Colors.pink.withOpacity(0.3); // Rose pour le baiser
      case '🥇':
        return Colors.amberAccent.withOpacity(0.3); // Or pour la médaille
      default:
        return Colors.white12;
    }
  }

  // Charger les joueurs depuis le backend (optimisé)
  Future<void> _loadPlayersFromBackend() async {
    try {
      final roomId = _gameSession.roomId ?? '';
      if (roomId.isEmpty) return;

      // ✅ Optimisation : Utiliser un timeout pour éviter les blocages
      final timeoutDuration = const Duration(seconds: 5);
      
      // Compléter avec des bots si nécessaire (avec timeout)
      if (_gameSession.playWithBots) {
        try {
          await GameApiService.instance.fillBots(roomId: roomId)
              .timeout(timeoutDuration);
        } catch (e) {
          print('⚠️ Timeout ou erreur fillBots - continuation sans bots: $e');
          // Continuer même en cas de timeout
        }
      }

      // ✅ Récupérer les joueurs depuis le backend (avec timeout)
      Map<String, dynamic> res;
      try {
        res = await GameApiService.instance.getRoom(roomId: roomId)
            .timeout(timeoutDuration);
      } catch (e) {
        print('⚠️ Timeout ou erreur getRoom - utilisation des joueurs locaux: $e');
        return; // Retourner sans erreur si timeout
      }
      final data = (res['data'] as Map?) ?? res;
      final players =
          (data['players'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (players.isEmpty) {
        print('⚠️ Aucun joueur retourné par le backend');
        return;
      }

      // Normaliser les joueurs
      final currentName = widget.currentPlayerName;
      final othersPositions = ['right', 'top', 'left'];

      // ⚠️ IMPORTANT: Séparer le joueur actuel des autres pour un positionnement correct
      final currentPlayer = players.firstWhere((p) {
        final pseudo = (p['pseudo'] ?? '').toString();
        final first = (p['first_name'] ?? '').toString();
        final last = (p['last_name'] ?? '').toString();
        final name =
            (pseudo.isNotEmpty
                    ? pseudo
                    : ([
                        first,
                        last,
                      ].where((s) => s.isNotEmpty).join(' ').trim()))
                .trim();
        return name == currentName && currentName.isNotEmpty;
      }, orElse: () => players.isNotEmpty ? players[0] : <String, dynamic>{});

      final otherPlayers = players.where((p) {
        final pseudo = (p['pseudo'] ?? '').toString();
        final first = (p['first_name'] ?? '').toString();
        final last = (p['last_name'] ?? '').toString();
        final name =
            (pseudo.isNotEmpty
                    ? pseudo
                    : ([
                        first,
                        last,
                      ].where((s) => s.isNotEmpty).join(' ').trim()))
                .trim();
        return name != currentName || currentName.isEmpty;
      }).toList();

      final normalized = <Map<String, dynamic>>[];

      // ⚠️ CRITIQUE: Le joueur actuel est TOUJOURS en premier avec position "bottom"
      if (players.isNotEmpty) {
        final pseudo = (currentPlayer['pseudo'] ?? '').toString();
        final first = (currentPlayer['first_name'] ?? '').toString();
        final last = (currentPlayer['last_name'] ?? '').toString();
        final isBot = (currentPlayer['is_bot'] ?? false) == true;
        final backendAvatar = (currentPlayer['avatar'] ?? '').toString();
        final isCreator =
            ((currentPlayer['is_creator'] ?? currentPlayer['isCreator']) ==
            true);
        final name =
            (pseudo.isNotEmpty
                    ? pseudo
                    : ([
                        first,
                        last,
                      ].where((s) => s.isNotEmpty).join(' ').trim()))
                .trim();

        normalized.add({
          'name': name.isNotEmpty ? name : 'Joueur',
          'displayPosition':
              'bottom', // ⚠️ TOUJOURS en bas pour le joueur actuel
          'avatar': backendAvatar.isNotEmpty
              ? backendAvatar
              : (isBot ? '🤖' : '👤'),
          'isCurrentPlayer': true,
          'isCreator': isCreator,
          'score': '0/0',
          'cards': 13,
          'is_bot': isBot,
        });
      }

      // ✅ Ajouter les autres joueurs avec positions right/top/left
      // Trier les autres joueurs par position backend pour maintenir l'ordre relatif
      otherPlayers.sort((a, b) => ((a['position'] ?? 0) as int).compareTo((b['position'] ?? 0) as int));
      
      for (int i = 0; i < otherPlayers.length && i < 3; i++) {
        final p = otherPlayers[i];
        final pseudo = (p['pseudo'] ?? '').toString();
        final first = (p['first_name'] ?? '').toString();
        final last = (p['last_name'] ?? '').toString();
        final isBot = (p['is_bot'] ?? false) == true;
        final backendAvatar = (p['avatar'] ?? '').toString();
        final isCreator = ((p['is_creator'] ?? p['isCreator']) == true);
        final name =
            (pseudo.isNotEmpty
                    ? pseudo
                    : ([
                        first,
                        last,
                      ].where((s) => s.isNotEmpty).join(' ').trim()))
                .trim();

        normalized.add({
          'name': name.isNotEmpty ? name : 'Joueur',
          'displayPosition':
              othersPositions[i % othersPositions.length], // right, top, left
          'avatar': backendAvatar.isNotEmpty
              ? backendAvatar
              : (isBot ? '🤖' : '👤'),
          'isCurrentPlayer': false,
          'isCreator': isCreator,
          'score': '0/0',
          'cards': 13,
          'is_bot': isBot,
          'backendPosition': (p['position'] ?? 0) as int, // Conserver la position backend
        });
      }

      if (mounted) {
        setState(() {
          _gameSession.players = normalized;
          _gameSession.globalScores = List.filled(normalized.length, 0.0);
        });
        print(
          '✅ Joueurs chargés depuis le backend: ${normalized.map((p) => p['name']).join(', ')}',
        );
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des joueurs depuis le backend: $e');
    }
  }

  // Vérifier si le joueur actuel a été exclu définitivement
  Future<void> _checkPlayerExclusion() async {
    final currentPlayerName = widget.currentPlayerName;
    final roomId = _gameSession.roomId ?? '';

    // ⚠️ IMPORTANT: Vérifier avec le backend si le joueur est exclu
    if (roomId.isNotEmpty) {
      try {
        final result = await GameApiService.instance.checkPlayerExclusion(
          roomId: roomId,
          playerName: currentPlayerName,
        );
        final isExcluded = (result['is_excluded'] as bool?) ?? false;
        if (isExcluded) {
          _permanentlyExcludedPlayers.add(currentPlayerName);
        }
      } catch (e) {
        print('⚠️ Erreur vérification exclusion backend: $e');
        // Continuer avec la vérification locale
      }
    }

    // Vérifier si le joueur a été exclu définitivement
    if (_permanentlyExcludedPlayers.contains(currentPlayerName)) {
      // Afficher le dialog d'erreur et rediriger
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPlayerExcludedDialog();
      });
      return;
    }

    // Vérifier si le joueur a été remplacé par un bot (même temporairement)
    // Si c'est le cas et que c'est définitif (> 15 secondes), l'exclure
    final players = _gameSession.players;
    for (final player in players) {
      final isReplacementBot = (player['isReplacementBot'] as bool?) ?? false;
      final replacedPlayerName = player['replacedPlayerName'] as String?;

      if (isReplacementBot && replacedPlayerName == currentPlayerName) {
        // Le joueur a été remplacé, vérifier si c'est définitif
        final replacementInfo = _temporaryReplacements[currentPlayerName];
        if (replacementInfo != null) {
          final isPermanent =
              (replacementInfo['isPermanent'] as bool?) ?? false;
          if (isPermanent) {
            // Exclusion définitive
            _permanentlyExcludedPlayers.add(currentPlayerName);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showPlayerExcludedDialog();
            });
          }
        } else {
          // Pas d'info de remplacement temporaire = départ manuel = définitif
          _permanentlyExcludedPlayers.add(currentPlayerName);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showPlayerExcludedDialog();
          });
        }
      }
    }
  }

  // Afficher le dialog d'exclusion et rediriger vers la création de salon
  void _showPlayerExcludedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2E2B23),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '⚠️ Exclusion du salon',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Désolé, vous avez quitté le salon du jeu ou perdu la connexion pendant plus de 15 secondes. Vous ne pourrez plus être intégré à cette partie.',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Rediriger vers la page de création de salon
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const CreateRoomPage(),
                  ),
                  (route) => false, // Retirer toutes les routes précédentes
                );
              },
              child: const Text(
                'OK',
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
  }

  void _startRoomPolling() {
    if (_gameSession.playWithBots) return;
    _roomPollTimer?.cancel();
    _roomPollTimer = Timer.periodic(const Duration(seconds: 3), (t) async {
      try {
        final roomId = _gameSession.roomId ?? '';
        if (roomId.isEmpty) return;
        final res = await GameApiService.instance.getRoom(roomId: roomId);
        final data = (res['data'] as Map?) ?? res;
        final players =
            (data['players'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (players.isEmpty) return;
        _applyBackendPlayersState(players, startGameIfReady: true);
      } catch (e) {
        print('⚠️ Erreur lors du polling des joueurs: $e');
      }
    });
  }

  void _startStateSyncPolling({bool forceRestart = false}) {
    if (_gameSession.playWithBots) return;
    // ✅ Démarrer le polling même si le jeu n'a pas encore commencé (pour synchroniser les joueurs)
    // if (!_hasGameStarted) return;
    if (_stateSyncTimer != null && !forceRestart) return;
    _stateSyncTimer?.cancel();
    final interval =
        _isWebSocketConnected ? _pollIntervalWebSocket : _pollIntervalFallback;
    _stateSyncTimer = Timer.periodic(interval, (_) => _pollGameState());
    print('🔁 Polling HTTP actif (${interval.inSeconds}s) - WS=${_isWebSocketConnected ? 'ON' : 'OFF'}');
  }

  Future<void> _pollGameState() async {
    if (!mounted || _gameSession.playWithBots) return;
    // ✅ Permettre le polling même en attente de joueurs (pour synchroniser les arrivées)
    // if (_waitingForHumans) return;
    final roomId = _gameSession.roomId ?? '';
    if (roomId.isEmpty) return;
    try {
      final res = await GameApiService.instance
          .getRoom(roomId: roomId)
          .timeout(const Duration(seconds: 5));
      final data = (res['data'] as Map?) ?? res;
      final players =
          (data['players'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (players.isNotEmpty) {
        _applyBackendPlayersState(players);
      }
      _consecutiveStatePollingErrors = 0;
      _lastSuccessfulStatePoll = DateTime.now();
    } catch (e) {
      _consecutiveStatePollingErrors++;
      print('⚠️ Erreur lors du polling HTTP: $e');
      if (_consecutiveStatePollingErrors >= 3 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Connexion instable, tentative de resynchronisation...'),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
        _consecutiveStatePollingErrors = 0;
      }
    }
  }

  void _applyBackendPlayersState(
    List<Map<String, dynamic>> players, {
    bool startGameIfReady = false,
  }) {
    if (players.isEmpty) return;
    players.sort(
      (a, b) => ((a['position'] ?? 0) as int).compareTo(
        (b['position'] ?? 0) as int,
      ),
    );
    final currentName = widget.currentPlayerName;
    int currentPlayerIndex =
        players.indexWhere((p) => (p['pseudo'] ?? '') == currentName);
    if (currentPlayerIndex == -1) currentPlayerIndex = 0;

    final rotated = [
      ...players.sublist(currentPlayerIndex),
      ...players.sublist(0, currentPlayerIndex),
    ];

    final posOrder = ['bottom', 'right', 'top', 'left'];
    final normalized = <Map<String, dynamic>>[];

    for (int i = 0; i < rotated.length && i < posOrder.length; i++) {
      final p = rotated[i];
      final name = (p['pseudo'] ?? '') as String;
      final isCurrent = name == currentName;

      normalized.add({
        'name': name,
        'displayPosition': posOrder[i],
        'avatar': (p['is_bot'] ?? false) ? '🤖' : '👤',
        'isCurrentPlayer': isCurrent,
        'isCreator': (p['is_creator'] ?? false) == true,
        'score': _formatPlayerScore(p),
        'cards': (p['cards_remaining'] ?? 13) as int? ?? 13,
        'backendPosition': (p['position'] ?? 0) as int,
      });
    }

    setState(() {
      final currentPlayerNames = normalized
          .map((p) => (p['name'] as String?) ?? '')
          .toList();

      for (final replacementEntry in _temporaryReplacements.entries) {
        final replacedPlayerName = replacementEntry.key;
        final replacementInfo = replacementEntry.value;
        final isPermanent =
            (replacementInfo['isPermanent'] as bool?) ?? false;

        if (currentPlayerNames.contains(replacedPlayerName) &&
            !isPermanent) {
          _handlePlayerReconnection(replacedPlayerName);
        }
      }

      _gameSession.players = normalized;
      if (_gameSession.globalScores.length != normalized.length) {
        _gameSession.globalScores = List.filled(normalized.length, 0.0);
      }

      for (int i = 0; i < normalized.length && i < rotated.length; i++) {
        final scoreValue =
            (rotated[i]['global_score'] as num?)?.toDouble();
        if (scoreValue != null) {
          _gameSession.globalScores[i] = scoreValue;
        }
      }
    });

    if (startGameIfReady &&
        normalized.length >= _requiredPlayers &&
        _waitingForHumans) {
      _waitingForHumans = false;
      _roomPollTimer?.cancel();
      _startCardDistribution();
    }
  }

  String _formatPlayerScore(Map<String, dynamic> backendPlayer) {
    final obtained = backendPlayer['plis_realises'] ?? backendPlayer['obtained'] ?? 0;
    final announced = backendPlayer['annonce'] ?? backendPlayer['announced'] ?? 0;
    return '$obtained/$announced';
  }

  // Fonction pour démarrer la distribution des cartes
  Future<void> _startCardDistribution() async {
    try {
      // Obtenir la liste des joueurs dans l'ordre
      final playerNames = _gameSession.players
          .map((player) => player['name'] as String? ?? 'Joueur')
          .toList();

      // Si on attend des humains, ne pas distribuer tant qu'on n'a pas le quota
      if (!_gameSession.playWithBots &&
          playerNames.length < _requiredPlayers) {
        return;
      }

      print('🔍 Distribution des cartes à: $playerNames');

      // Si la liste est vide ou incomplète, tenter de récupérer via backend
      if (playerNames.isEmpty || playerNames.length < _requiredPlayers) {
        final roomId = _gameSession.roomId ?? '';
        if (roomId.isNotEmpty) {
          try {
            // Tenter de compléter avec des bots uniquement pour le mode bot
            if (_gameSession.playWithBots &&
                playerNames.length < _requiredPlayers) {
              try {
                await GameApiService.instance.fillBots(roomId: roomId);
              } catch (_) {}
            }
            final res = await GameApiService.instance.getRoom(roomId: roomId);
            final data = (res['data'] as Map?) ?? res;
            final players =
                (data['players'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            final currentName = UserService.instance.currentUserPseudo ?? '';
            final othersPositions = ['right', 'top', 'left'];
            // ⚠️ IMPORTANT: Garantir que le joueur connecté est toujours en position "bottom"
            // Cela permet d'afficher ses cartes ouvertes en bas et les cartes des autres fermées
            int idx = 0;
            final normalized = players.map((p) {
              final pseudo = (p['pseudo'] ?? '').toString();
              final first = (p['first_name'] ?? '').toString();
              final last = (p['last_name'] ?? '').toString();
              final isBot = (p['is_bot'] ?? false) == true;
              final backendAvatar = (p['avatar'] ?? '').toString();
              final isCreator = ((p['is_creator'] ?? p['isCreator']) == true);
              final name =
                  (pseudo.isNotEmpty
                          ? pseudo
                          : ([
                              first,
                              last,
                            ].where((s) => s.isNotEmpty).join(' ').trim()))
                      .trim();
              final isCurrent = name == currentName && currentName.isNotEmpty;

              // ⚠️ CRITIQUE: Le joueur connecté est TOUJOURS en "bottom"
              // Les autres joueurs (bots ou humains) sont en top/left/right avec cartes fermées
              final displayPos = isCurrent
                  ? 'bottom'
                  : othersPositions[(idx++) % othersPositions.length];

              return {
                'name': name.isNotEmpty ? name : 'Joueur',
                'displayPosition':
                    displayPos, // Le joueur actuel sera toujours 'bottom'
                'avatar': backendAvatar.isNotEmpty
                    ? backendAvatar
                    : (isBot ? '🤖' : '👤'),
                'isCurrentPlayer': isCurrent, // Marquer le joueur actuel
                'isCreator': isCreator,
                'score': '0/0',
                'cards': 13,
              };
            }).toList();
            if (normalized.isNotEmpty) {
              _gameSession.players = normalized;
              _gameSession.globalScores = List.filled(normalized.length, 0.0);
            }
          } catch (_) {}
        }
      }

      // Recalcule après éventuel fetch
      final effectivePlayerNames = _gameSession.players
          .map((player) => player['name'] as String? ?? 'Joueur')
          .where((n) => (n).isNotEmpty)
          .toList();
      if (effectivePlayerNames.isEmpty) {
        print(
          '⚠️ Aucun joueur disponible pour distribuer. Abandon de la distribution.',
        );
        return;
      }

      // Distribuer les cartes localement
      final result = _cardManager.shuffleAndDealCards(effectivePlayerNames);

      if (result['success'] == true) {
        _gameLogic.configurePlayers(
          playerCount: effectivePlayerNames.length,
          cardsPerPlayer: _cardManager.cardsPerPlayer,
        );
        final note = result['note'] as String?;
        if (note != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(note),
              backgroundColor: Colors.orange.shade700,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        // Calculer un hash déterministe du paquet distribué et l'envoyer au backend
        try {
          final List<String> orderedCodes = [];
          for (final name in playerNames) {
            final hand = _cardManager.getPlayerCards(name);
            for (final c in hand) {
              final code = (c['code'] as String?) ?? '';
              orderedCodes.add(code);
            }
          }
          final payload = orderedCodes.join('-');
          final bytes = utf8.encode(payload);
          final hash = crypto.sha256.convert(bytes).toString();
          final roomId = _gameSession.roomId ?? '';
          if (roomId.isNotEmpty) {
            await GameApiService.instance.startRound(
              roomId: roomId,
              roundNumber: _gameSession.currentRound + 1,
              deckHash: hash,
            );
          }
        } catch (_) {}
        // Brancher le callback de fin de manche pour sauvegarde API
        _cardManager.onRoundCompleted = (announcements, obtained) async {
          final roomId = _gameSession.roomId ?? '';
          if (roomId.isEmpty) return;
          try {
            await GameApiService.instance.saveRound(
              roomId: roomId,
              roundNumber: _gameSession.currentRound + 1,
              announcements: announcements,
              obtainedTricks: obtained,
            );
          } catch (e) {
            // Ignorer les erreurs réseau pour ne pas bloquer l'UI
          }
        };

        setState(() {
          // Les cartes sont maintenant distribuées
        });

        // ✅ Initialiser les annonces
        if (_gameSession.playWithBots) {
          // Mode bot : les bots annoncent automatiquement au début
          final botNames = playerNames
              .where((name) => name != widget.currentPlayerName)
              .toList();
          for (final botName in botNames) {
            final computed = _cardManager.getBotAnnouncement(botName);
            _cardManager.forceAnnouncement(botName, computed);
            print(
              '🤖 Annonce initiale de ' +
                  botName +
                  ' : ' +
                  computed.toString() +
                  ' plis',
            );
          }
          
          // Donner la main au joueur humain pour qu'il fasse son annonce
          _cardManager.currentPlayerTurn = widget.currentPlayerName;
          print(
            '👤 C\'est maintenant au tour de ${widget.currentPlayerName} d\'annoncer',
          );
        } else {
          // ✅ Mode humain : le premier joueur commence les annonces (tour par tour)
          final firstPlayer = playerNames.first;
          _cardManager.currentPlayerTurn = firstPlayer;
          print(
            '🌐 Mode humain: C\'est au tour de $firstPlayer d\'annoncer',
          );
        }

        print(
          '📊 Total annonces après initialisation: ${_cardManager.getCurrentRoundAnnouncements().length}',
        );

        // ✅ Mettre à jour l'interface et démarrer le timer pour le joueur actuel
        setState(() {});
        _startAnnouncementTimerForCurrentPlayer();

        _hasGameStarted = true;
        if (!_gameSession.playWithBots) {
          _startStateSyncPolling(forceRestart: true);
        }

        // Cartes distribuées avec succès
      } else {
        // Afficher un dialog d'erreur
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.red.shade800,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Erreur',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Erreur lors de la distribution des cartes:\n${result['message']}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Réessayer la distribution
                    _initializeGameSession();
                  },
                  child: const Text(
                    'Réessayer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'OK',
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
      }
    } catch (e) {
      // Ignorer silencieusement les erreurs de connexion WebSocket
      // car le jeu peut fonctionner sans WebSocket (mode local)
      final errorMessage = e.toString();
      if (errorMessage.contains('HandshakeException') ||
          errorMessage.contains('Connection terminated') ||
          errorMessage.contains('WebSocket') ||
          errorMessage.contains('websocket')) {
        print('⚠️ Erreur WebSocket ignorée (mode local): $errorMessage');
        // Continuer le jeu sans WebSocket
        return;
      }

      // Afficher un dialog d'erreur pour les autres exceptions
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.red.shade800,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Erreur',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Erreur de connexion: ${e.toString()}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Réessayer la distribution
                    _initializeGameSession();
                  },
                  child: const Text(
                    'Réessayer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'OK',
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
      }
    }
  }

  // Main du joueur
  final List<Map<String, dynamic>> _playerHand = [
    {'suit': 'spades', 'value': 'A'},
    {'suit': 'spades', 'value': '10'},
    {'suit': 'spades', 'value': '6'},
    {'suit': 'spades', 'value': '2'},
    {'suit': 'hearts', 'value': '10'},
    {'suit': 'hearts', 'value': '6'},
    {'suit': 'hearts', 'value': '4'},
    {'suit': 'clubs', 'value': 'K'},
    {'suit': 'clubs', 'value': 'Q'},
    {'suit': 'clubs', 'value': 'J'},
    {'suit': 'clubs', 'value': '7'},
    {'suit': 'clubs', 'value': '6'},
    {'suit': 'diamonds', 'value': '5'},
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Empêcher le retour automatique
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          // Afficher le dialog de confirmation si le joueur essaie de quitter
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
                if (_waitingForHumans)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.6),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Attendons les autres joueurs (${_gameSession.players.length}/$_requiredPlayers)',
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
                // ⚠️ IMPORTANT: Main du joueur connecté en bas (cartes OUVERTES)
                // Le joueur connecté voit toujours ses propres cartes ouvertes via _buildPlayerHand()
                // Cette fonction affiche uniquement les cartes du joueur connecté (widget.currentPlayerName)
                _buildPlayerHand(),

                // ⚠️ IMPORTANT: Joueurs autour de la table (cartes FERMÉES)
                // Les autres joueurs (bots ou humains) sont affichés avec leurs cartes fermées
                // Le joueur connecté voit leurs cartes retournées (dos rouge) via _buildPlayerCards()
                _buildPlayers(),

                // Cartes jouées au centre (pli en cours)
                _buildCenterTrick(),

                // Animation de la carte qui se déplace vers le centre
                // ⚠️ IMPORTANT: L'animation doit être visible pour tous les joueurs (bots et humains)
                // Positionnée après les autres éléments pour être au-dessus
                if (_isAnimatingCard && _animatedCard != null)
                  _buildAnimatedCard(),

                // Contrôles et informations
                _buildGameControls(),

                // Message "À ton tour"
                _buildTurnMessage(),

                // Panneau d'annonce automatique
                _buildAnnouncementPanel(),

                // Notification "Qui fait son annonce"
                _buildAnnouncementNotification(),
                
                // ✅ Message d'annonce supprimé - les joueurs font simplement leur annonce

                // Informations du salon
                _buildRoomInfo(),
                // Le chat est uniquement disponible en mode humain
                if (!_gameSession.playWithBots) ...[
                  _buildChatOverlay(),
                  _buildChatToast(),
                ],
              ],
            ),
          ),
        ),
      ), // Fermeture du PopScope
    );
  }

  // Animation de collecte du pli
  String? _lastTrickWinner;
  bool _isCollectingTrick = false;

  // Récupérer la position d'affichage (bottom/right/top/left) pour un joueur donné
  String _getDisplayPositionForPlayerName(String playerName) {
    final players = _getPlayersFromCurrentPerspective();
    final found = players.firstWhere(
      (p) => p['name'] == playerName,
      orElse: () => <String, Object>{},
    );
    return (found['displayPosition'] as String?) ?? 'bottom';
  }

  // Affiche le pli en cours avec les cartes au centre de la table
  Widget _buildCenterTrick() {
    // ✅ Ne pas afficher les cartes pendant la phase d'annonces
    if (_cardManager.isAnnouncementPhase) return const SizedBox.shrink();
    
    final currentTrick =
        _cardManager.currentTrick; // [{player, card, timestamp}]
    if (currentTrick.isEmpty) return const SizedBox.shrink();

    print('🎴 === AFFICHAGE PLI ===');
    print('🎴 Nombre de cartes: ${currentTrick.length}');
    for (int i = 0; i < currentTrick.length; i++) {
      final play = currentTrick[i];
      print('🎴 Carte [$i]: ${play['player']} → ${play['card']['code']}');
    }
    print('🎴 ====================');

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

                // Utiliser la méthode existante pour obtenir la position RELATIVE du joueur
                final pos = _getDisplayPositionForPlayerName(playerName);

                print(
                  '🎴 Carte [$index] de $playerName en position RELATIVE: $pos, carte: ${card['code']}',
                );

                // Utiliser la méthode _buildCardAtPosition pour positionner la carte
                final winnerPos = _isCollectingTrick && _lastTrickWinner != null
                    ? _getDisplayPositionForPlayerName(_lastTrickWinner!)
                    : null;
                return _buildCardAtPosition(card, pos, index, winnerPos);
              } catch (e) {
                print('❌ Erreur lors de l\'affichage d\'une carte: $e');
                return const SizedBox.shrink();
              }
            }).toList(),
          ),
        ),
      ),
    );
  }

  // Construit une carte à une position donnée avec rotation
  Widget _buildCardAtPosition(
    Map<String, dynamic> card,
    String position,
    int index,
    String? collectingTowardsPosition,
  ) {
    // Déterminer la rotation et les offsets selon la position
    double rotation = 0;
    double offsetX = 0, offsetY = 0;
    bool shouldRotateCard = false;

    // Calculer un décalage supplémentaire basé sur l'ordre de jeu pour éviter la superposition
    double indexOffset = (index % 4) * 3; // Décalage subtil pour chaque carte

    // Positions avec décalage selon l'ordre
    switch (position) {
      case 'top':
        offsetY = -60 - indexOffset; // Position en haut avec décalage
        offsetX = indexOffset; // Léger décalage horizontal
        rotation = -0.1 + (index * 0.02); // Rotation variable
        break;
      case 'bottom':
        offsetY = 60 + indexOffset; // Position en bas avec décalage
        offsetX = -indexOffset; // Léger décalage horizontal
        rotation = 0.1 - (index * 0.02); // Rotation variable
        break;
      case 'left':
        offsetX = -60 - indexOffset; // Position à gauche avec décalage
        offsetY = -indexOffset; // Léger décalage vertical
        rotation = -0.2 + (index * 0.03); // Rotation variable
        shouldRotateCard = true;
        break;
      case 'right':
        offsetX = 60 + indexOffset; // Position à droite avec décalage
        offsetY = indexOffset; // Léger décalage vertical
        rotation = 0.2 - (index * 0.03); // Rotation variable
        shouldRotateCard = true;
        break;
      default:
        offsetX = 0;
        offsetY = 0;
        rotation = 0;
    }

    print(
      '🎴 Carte [$index] position $position: offsetX=$offsetX, offsetY=$offsetY, rotation=$rotation',
    );

    // Vecteur de translation pendant la collecte
    double collectDx = 0, collectDy = 0;
    if (collectingTowardsPosition != null) {
      switch (collectingTowardsPosition) {
        case 'top':
          collectDy = -200; // dépasser vers le haut
          break;
        case 'bottom':
          collectDy = 200; // dépasser vers le bas
          break;
        case 'left':
          collectDx = -200; // dépasser vers la gauche
          break;
        case 'right':
          collectDx = 200; // dépasser vers la droite
          break;
        default:
          collectDx = 0;
          collectDy = 0;
      }
    }

    // Positionner la carte au centre + offset
    return Positioned(
      left: 110 + offsetX - 28, // Centre X - moitié largeur (56/2 = 28)
      top: 110 + offsetY - 40, // Centre Y - moitié hauteur (80/2 = 40)
      child: TweenAnimationBuilder<Offset>(
        tween: Tween<Offset>(
          begin: const Offset(0, 0),
          end: _isCollectingTrick
              ? Offset(collectDx, collectDy)
              : const Offset(0, 0),
        ),
        duration: const Duration(milliseconds: 500),
        builder: (context, value, child) {
          return Transform.translate(
            offset: value,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: _isCollectingTrick ? 0.0 : 1.0,
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

  // Carte jouée affichée avec style
  Widget _buildPlayedCard(Map<String, dynamic> card, {bool rotate = false}) {
    final imagePath = _cardManager.getCardImagePath(card);
    final content = Container(
      width: 56,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.2), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        imagePath,
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
    );

    if (rotate) {
      return Transform.rotate(angle: math.pi / 2, child: content);
    }
    return content;
  }

  // Fonction pour obtenir l'ordre des joueurs selon la perspective du joueur actuel
  List<Map<String, dynamic>> _getPlayersFromCurrentPerspective() {
    final allPlayers = _gameSession.players;
    final currentPlayerName = widget.currentPlayerName;

    print(
      '🔍 _getPlayersFromCurrentPerspective: ${allPlayers.length} joueurs dans session',
    );

    // ⚠️ IMPORTANT: Si la liste de joueurs est vide, retourner une liste vide
    // Le chargement depuis le backend se fera dans _initializeGameSession() ou _buildPlayers()
    if (allPlayers.isEmpty) {
      print('⚠️ Liste de joueurs vide dans _getPlayersFromCurrentPerspective');
      return [];
    }

    // ⚠️ IMPORTANT: Garantir que le joueur connecté est TOUJOURS en position "bottom"
    // Cela permet d'afficher ses cartes ouvertes en bas et les cartes des autres fermées

    // Trouver l'index du joueur actuel
    final currentIndex = allPlayers.indexWhere(
      (player) => (player['name'] as String?) == currentPlayerName,
    );

    if (currentIndex == -1 && allPlayers.isNotEmpty) {
      // Si le joueur actuel n'est pas trouvé, prendre le premier et le mettre en bas
      final orderedPlayers = <Map<String, dynamic>>[];
      orderedPlayers.add({
        ...allPlayers[0],
        'displayPosition': 'bottom',
        'isCurrentPlayer': true,
        'displayName': allPlayers[0]['name'],
      });

      // Ajouter les autres joueurs
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
          ...allPlayers[i],
          'displayPosition': displayPosition,
          'isCurrentPlayer': false,
          'displayName': allPlayers[i]['name'],
        });
      }
      return orderedPlayers;
    }

    if (currentIndex == -1) return allPlayers;

    // Créer l'ordre cyclique dans le sens contraire des aiguilles d'une montre
    final orderedPlayers = <Map<String, dynamic>>[];

    // ⚠️ CRITIQUE: Le joueur connecté est TOUJOURS en bas (position "bottom")
    // Ses cartes seront affichées ouvertes via _buildPlayerHand()
    orderedPlayers.add({
      ...allPlayers[currentIndex],
      'displayPosition': 'bottom', // FORCER en bas
      'isCurrentPlayer': true, // Marquer comme joueur actuel
      'displayName': 'Vous',
    });

    // Ajouter les autres joueurs dans l'ordre cyclique
    // Leurs cartes seront affichées fermées via _buildPlayerCards()
    for (int i = 1; i < allPlayers.length; i++) {
      final nextIndex = (currentIndex + i) % allPlayers.length;
      final player = allPlayers[nextIndex];

      String displayPosition;
      switch (i) {
        case 1:
          displayPosition = 'right'; // Joueur 1 à droite (cartes fermées)
          break;
        case 2:
          displayPosition = 'top'; // Joueur 2 en haut (cartes fermées)
          break;
        case 3:
          displayPosition = 'left'; // Joueur 3 à gauche (cartes fermées)
          break;
        default:
          displayPosition = 'bottom';
      }

      orderedPlayers.add({
        ...player,
        'displayPosition': displayPosition,
        'isCurrentPlayer': false, // Pas le joueur actuel
        'displayName': player['name'],
      });
    }

    return orderedPlayers;
  }

  Widget _buildPlayers() {
    // ⚠️ IMPORTANT: Si la liste de joueurs est vide, déclencher un chargement depuis le backend
    if (_gameSession.players.isEmpty) {
      print(
        '⚠️ Liste de joueurs vide dans _buildPlayers, déclenchement du chargement...',
      );
      // Déclencher le chargement de manière asynchrone
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPlayersFromBackend();
      });
      // Retourner un widget vide temporairement
      return const SizedBox.shrink();
    }

    final playersFromPerspective = _getPlayersFromCurrentPerspective();
    print(
      '🎮 _buildPlayers: ${playersFromPerspective.length} joueurs affichés: ${playersFromPerspective.map((p) => "${p['name']} (${p['displayPosition']})").join(', ')}',
    );

    // Si toujours vide après getPlayersFromCurrentPerspective, retourner vide
    if (playersFromPerspective.isEmpty) {
      print(
        '⚠️ _buildPlayers: Liste vide après _getPlayersFromCurrentPerspective',
      );
      return const SizedBox.shrink();
    }

    return Stack(
      children: playersFromPerspective.map((player) {
        return _buildPlayer(player);
      }).toList(),
    );
  }

  Widget _buildPlayer(Map<String, dynamic> player) {
    final position = player['displayPosition'] as String? ?? 'bottom';
    Offset positionOffset;
    Alignment alignment;

    switch (position) {
      case 'top':
        positionOffset = const Offset(0, 0);
        alignment = Alignment.topCenter;
        break;
      case 'left':
        positionOffset = const Offset(0, 0);
        alignment = Alignment.centerLeft;
        break;
      case 'right':
        positionOffset = const Offset(0, 0);
        alignment = Alignment.centerRight;
        break;
      case 'bottom':
        positionOffset = const Offset(0, 0);
        alignment = Alignment.bottomCenter;
        break;
      default:
        positionOffset = const Offset(0, 0);
        alignment = Alignment.center;
    }

    // Vérifier si c'est le tour de ce joueur ET que c'est le joueur actuel
    final current = _cardManager.currentPlayerTurn;
    final isCurrentTurn = current == player['name'];
    final isThisCurrentPlayer = player['name'] == widget.currentPlayerName;

    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Transform.translate(
          offset: position == 'top'
              ? const Offset(0, -10) // Décaler vers le haut pour coller au bord
              : Offset.zero,
          child: Container(
            margin: _getPlayerMargin(position),
            child: Stack(
              children: [
                // Message de tour au-dessus du joueur UNIQUEMENT si :
                // 1. C'est le tour de ce joueur
                // 2. ET c'est le joueur actuel (soi-même)
                if (isCurrentTurn && isThisCurrentPlayer)
                  Positioned(
                    top: position == 'top' ? -70 : null,
                    bottom: position == 'bottom' ? -70 : null,
                    left: position == 'left' ? -100 : 0,
                    right: position == 'right' ? -100 : 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700), // Jaune doré
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'À TON TOUR',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.arrow_downward,
                            color: Colors.black,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Widget joueur/bot selon les spécifications
                    if (position == 'left')
                      _buildPlayerWidget(player)
                    else if (position == 'right')
                      _buildPlayerWidgetRight(player)
                    else if (position == 'top')
                      _buildPlayerWidgetTop(player)
                    else
                    // Joueur "You" - design avec nom à gauche et compteurs à droite
                    if (position == 'bottom')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Nom du joueur à gauche
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF8B4513,
                              ), // Marron foncé comme les autres
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              player['name'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 16,
                          ), // Espace entre nom et avatar
                          // Avatar au centre
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: player['isCurrentPlayer']
                                    ? Colors.yellow
                                    : Colors.grey,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                player['avatar'],
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 16,
                          ), // Espace entre avatar et compteurs
                          // Compteurs à droite
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Conteneur pour le compteur d'annonce
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF8B4513,
                                  ), // Marron foncé comme les autres
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getPlayerAnnouncementDisplay(player['name']),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              const SizedBox(
                                width: 8,
                              ), // Espace entre les conteneurs
                              // Conteneur pour le compteur de points avec cristal
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF8B4513,
                                  ), // Marron foncé comme les autres
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.diamond,
                                      color: Colors.blue,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getPlayerGlobalScore(
                                        player['name'],
                                      ).toString(),
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
                        ],
                      )
                    else
                      // Autres bots - design simple
                      Column(
                        children: [
                          // Nom du joueur
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              player['name'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Avatar avec cartes
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Cartes en éventail derrière l'avatar
                              if (position != 'bottom')
                                Positioned(
                                  child: _buildPlayerCards(
                                    player['cards'],
                                    position,
                                  ),
                                ),

                              // Avatar au premier plan
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: player['isCurrentPlayer']
                                        ? Colors.yellow
                                        : Colors.grey,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    player['avatar'],
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Tags séparés : compteur d'annonce et compteur de points avec cristal
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Conteneur pour le compteur d'annonce
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF8B4513,
                                  ), // Marron foncé comme les autres
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  player['score'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              const SizedBox(
                                width: 8,
                              ), // Espace entre les conteneurs
                              // Conteneur pour le compteur de points avec cristal
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF8B4513,
                                  ), // Marron foncé comme les autres
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.diamond,
                                      color: Colors.blue,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '157', // Points total du joueur
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
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerWidget(Map<String, dynamic> player) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tag du nom avec fond marron foncé et coins arrondis stylisés
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF8B4513), // Marron foncé
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                player['name'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              // Icône de pique
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.yellow.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Center(
                  child: Text(
                    '♠',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Stack avec cartes en éventail et avatar
        SizedBox(
          width: 120,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Cartes en éventail derrière l'avatar
              ...List.generate(_getPlayerCardCount(player['name']), (index) {
                final cardCount = _getPlayerCardCount(player['name']);
                // Calculer l'angle pour l'effet éventail (centré autour de l'avatar)
                // Si cardCount est 0, on ne génère aucune carte (List.generate avec 0)
                final angle = cardCount > 0
                    ? (index - (cardCount - 1) / 2) * 0.12
                    : 0.0; // Angle en radians, centré
                final radius = 35.0; // Rayon de l'arc
                final centerX = 60.0; // Centre horizontal
                final centerY = 50.0; // Centre vertical

                // Position sur l'arc de cercle
                final cardX =
                    centerX +
                    radius * math.cos(angle) -
                    15; // -15 pour centrer la carte (30/2)
                final cardY =
                    centerY +
                    radius * math.sin(angle) -
                    21; // -21 pour centrer la carte (42/2)

                return Positioned(
                  left: cardX,
                  top: cardY,
                  child: Transform.rotate(
                    angle: angle,
                    child: _cardManager.buildCardBack(width: 30, height: 42),
                  ),
                );
              }),

              // Avatar circulaire au centre, superposé aux cartes
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Text(
                  player['avatar'],
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // Compteurs dynamiques sous l'avatar
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Compteur d'annonce
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getPlayerAnnouncementDisplay(player['name']),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 6),

            // Compteur de score global
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
                    _getPlayerGlobalScore(player['name']).toString(),
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

  Widget _buildPlayerWidgetRight(Map<String, dynamic> player) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tag du nom avec fond marron foncé et coins arrondis stylisés
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF8B4513), // Marron foncé
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                player['name'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              // Icône de pique
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.yellow.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Center(
                  child: Text(
                    '♠',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
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
              ...List.generate(_getPlayerCardCount(player['name']), (index) {
                final cardCount = _getPlayerCardCount(player['name']);
                // Calculer l'angle pour l'effet éventail (orienté vers la gauche, centré)
                // Si cardCount est 0, on ne génère aucune carte (List.generate avec 0)
                final angle = cardCount > 0
                    ? (index - (cardCount - 1) / 2) * 0.12
                    : 0.0; // Angle en radians, centré
                final radius = 35.0; // Rayon de l'arc
                final centerX = 60.0; // Centre horizontal
                final centerY = 50.0; // Centre vertical

                // Position sur l'arc de cercle (orienté vers la gauche)
                final cardX =
                    centerX -
                    radius * math.cos(angle) -
                    17.5; // -cos pour orienter vers la gauche
                final cardY =
                    centerY +
                    radius * math.sin(angle) -
                    25; // -25 pour centrer la carte (50/2)

                return Positioned(
                  left: cardX,
                  top: cardY,
                  child: Transform.rotate(
                    angle: -angle, // Rotation inverse pour l'orientation gauche
                    child: _cardManager.buildCardBack(width: 40, height: 55),
                  ),
                );
              }),

              // Avatar circulaire au centre, superposé aux cartes
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Text(
                  player['avatar'],
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // Compteurs dynamiques sous l'avatar
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Compteur d'annonce
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getPlayerAnnouncementDisplay(player['name']),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 6),

            // Compteur de score global
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
                    _getPlayerGlobalScore(player['name']).toString(),
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

  Widget _buildPlayerWidgetTop(Map<String, dynamic> player) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Row avec Nom, compteur d'annonce et compteur de cristal (avec espace entre eux)
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Conteneur pour le nom
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513), // Marron foncé
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                player['name'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(
              width: 8,
            ), // Espace entre le nom et le compteur d'annonce
            // Conteneur pour le compteur d'annonce
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513), // Marron foncé
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getPlayerAnnouncementDisplay(player['name']),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(
              width: 8,
            ), // Espace entre le compteur d'annonce et le compteur de cristal
            // Conteneur pour le compteur de points avec cristal
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513), // Marron foncé
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.diamond, color: Colors.blue, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _getPlayerGlobalScore(player['name']).toString(),
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

        const SizedBox(
          height: 8,
        ), // Espace vertical entre le bloc nom/compteurs et l'avatar/éventail
        // Stack avec cartes en éventail et avatar (en dessous du bloc nom/compteurs)
        SizedBox(
          width: 150,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Cartes en éventail derrière l'avatar (rotation 90°)
              ...List.generate(_getPlayerCardCount(player['name']), (index) {
                final cardCount = _getPlayerCardCount(player['name']);
                // Calculer l'angle pour l'effet éventail (centré)
                // Si cardCount est 0, on ne génère aucune carte (List.generate avec 0)
                final angle = cardCount > 0
                    ? (index - (cardCount - 1) / 2) * 0.12
                    : 0.0; // Angle en radians, centré
                final radius = 35.0; // Rayon de l'arc
                final centerX = 75.0; // Centre horizontal (150/2)
                final centerY = 60.0; // Centre vertical (120/2)

                // Position sur l'arc de cercle avec rotation 90° horaire
                final cardX =
                    centerX -
                    radius * math.sin(angle) -
                    17.5; // -sin pour rotation 90° horaire
                final cardY =
                    centerY +
                    radius * math.cos(angle) -
                    25; // +cos pour rotation 90° horaire

                return Positioned(
                  left: cardX,
                  top: cardY,
                  child: Transform.rotate(
                    angle: angle,
                    child: _cardManager.buildCardBack(width: 30, height: 42),
                  ),
                );
              }),

              // Avatar circulaire au centre, superposé aux cartes
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Text(
                  player['avatar'],
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Affiche les cartes fermées (retournées) pour les autres joueurs (top, left, right)
  // ⚠️ IMPORTANT: Cette fonction est utilisée UNIQUEMENT pour les positions autres que "bottom"
  // Le joueur en "bottom" utilise _buildPlayerHand() qui affiche les cartes ouvertes
  Widget _buildPlayerCards(int cardCount, String position) {
    // Autres joueurs (bots ou humains) - cartes fermées (retournées)
    // Ces cartes ne montrent pas le contenu, juste le dos rouge
    return SizedBox(
      width: 60,
      height: 40,
      child: Stack(
        children: List.generate(cardCount.clamp(0, 6), (index) {
          final angle = (index - cardCount / 2) * 0.2;
          final offsetX = index * 2.0;
          final offsetY = (index - cardCount / 2) * 1.0;

          return Positioned(
            left: offsetX,
            top: offsetY,
            child: Transform.rotate(
              angle: angle,
              child: Container(
                width: 18,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: Colors.white, width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // Affiche les cartes ouvertes (visibles) pour le joueur connecté en bas
  // ⚠️ IMPORTANT: Cette fonction est utilisée UNIQUEMENT pour le joueur en position "bottom"
  // Les autres joueurs utilisent _buildPlayerCards() qui affiche les cartes fermées
  Widget _buildPlayerHand() {
    // Obtenir les cartes du joueur actuel (celui qui est connecté, toujours en "bottom")
    final currentPlayerCards = _sortCardsForDisplay(
      _cardManager.getPlayerCards(widget.currentPlayerName),
    );

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

  // Trier les cartes par couleur puis par valeur décroissante
  List<Map<String, dynamic>> _sortCardsForDisplay(
    List<Map<String, dynamic>> cards,
  ) {
    final sorted = List<Map<String, dynamic>>.from(cards);
    sorted.sort((a, b) {
      final aCode = (a['code'] as String?) ?? '';
      final bCode = (b['code'] as String?) ?? '';

      // Suit order: Spades (S), Hearts (H), Clubs (C), Diamonds (D)
      final suitOrder = {'S': 0, 'H': 1, 'C': 2, 'D': 3};

      int suitRank(String code) {
        if (code.isEmpty) return 999;
        final s = code.substring(code.length - 1);
        return suitOrder[s] ?? 999;
      }

      int valueRank(String code) {
        if (code.isEmpty) return -1;
        final v = code.substring(0, 1); // A, K, Q, J, 0(=10), 9..2
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
            return 10; // 10 est encodé par '0'
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

      // Valeur décroissante au sein de la même couleur
      return valueRank(bCode).compareTo(valueRank(aCode));
    });
    return sorted;
  }

  Widget _buildHandCard(Map<String, dynamic> card) {
    // Vérifier si c'est le tour du joueur actuel
    final isCurrentPlayerTurn =
        _cardManager.currentPlayerTurn == widget.currentPlayerName;
    final isAnnouncementPhase = _cardManager.isAnnouncementPhase;

    // Obtenir les cartes du joueur actuel
    final playerCards = _cardManager.getPlayerCards(widget.currentPlayerName);

    // ✅ Synchroniser le pli actuel avec GameLogic pour déterminer correctement les cartes jouables
    _gameLogic.syncCurrentTrick(_cardManager.currentTrick);

    // Déterminer si la carte est jouable selon les règles du jeu
    final isPlayable =
        isCurrentPlayerTurn &&
        !isAnnouncementPhase &&
        _gameLogic
            .getPlayableCards(
              playerCards,
              widget.currentPlayerName,
              _gameLogic.currentTrick.isEmpty,
            )
            .contains(card);

    // Si cette carte est en cours d'animation ET que c'est le joueur actuel qui anime, la masquer dans la main
    final isAnimating =
        _isAnimatingCard &&
        _animatedCard != null &&
        _animatingPlayerName == widget.currentPlayerName &&
        _animatedCard!['code'] == card['code'];

    if (isAnimating) {
      return Opacity(
        opacity: 0.0, // Carte invisible dans la main pendant l'animation
        child: Container(width: 55, height: 80),
      );
    }

    return GestureDetector(
      onTap: isPlayable ? () => _playCard(card) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 55,
        height: isPlayable ? 85 : 80, // Élévation pour les cartes jouables
        margin: EdgeInsets.only(
          bottom: isPlayable ? 5 : 0, // Élévation visuelle
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isPlayable
                ? Colors
                      .green // Bordure verte pour les cartes jouables
                : Colors.grey.shade400,
            width: isPlayable ? 2 : 1, // Bordure plus épaisse pour les jouables
          ),
          boxShadow: [
            BoxShadow(
              color: isPlayable
                  ? Colors.green.withOpacity(
                      0.3,
                    ) // Ombre verte pour les jouables
                  : Colors.grey.withOpacity(0.1),
              blurRadius: isPlayable ? 4 : 2,
              offset: Offset(0, isPlayable ? 3 : 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            _cardManager.getCardImagePath(card),
            width: 55,
            height: isPlayable ? 85 : 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback si l'image n'est pas trouvée
              return Container(
                color: isPlayable ? Colors.white : Colors.grey.shade300,
                child: Center(
                  child: Text(
                    card['code'] ??
                        '${card['value']}${_getSuitSymbol(card['suit'])}',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: isPlayable
                          ? _getSuitColor(card['suit'])
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTurnMessage() {
    // Ne plus afficher le message au centre, on l'ajoute à chaque joueur
    return const SizedBox.shrink();
  }

  Widget _buildAnnouncementNotification() {
    // ✅ Supprimé : Les compteurs de plis indiquent déjà qui a annoncé
    // Pas besoin d'afficher un message supplémentaire
    return const SizedBox.shrink();
  }

  Widget _buildAnnouncementPanel() {
    // Vérifier si c'est la phase d'annonces
    final isAnnouncementPhase = _cardManager.isAnnouncementPhase;

    if (!isAnnouncementPhase) {
      return const SizedBox.shrink();
    }

    // Obtenir le joueur qui fait actuellement son annonce
    final currentAnnouncingPlayer = _cardManager.getCurrentAnnouncingPlayer();

    // Vérifier si le joueur dont c'est le tour a déjà fait son annonce
    final announcements = _cardManager.getCurrentRoundAnnouncements();
    final hasCurrentPlayerAnnounced = announcements.any(
      (ann) => ann['player'] == currentAnnouncingPlayer,
    );

    // ✅ Si le joueur dont c'est le tour a déjà fait son annonce, passer au suivant
    if (hasCurrentPlayerAnnounced && currentAnnouncingPlayer.isNotEmpty) {
      // Passer automatiquement au tour suivant (avec un petit délai pour éviter les appels multiples)
      if (!_isProcessingAnnouncementTurn) {
        _isProcessingAnnouncementTurn = true;
        Future.delayed(const Duration(milliseconds: 100), () {
          _isProcessingAnnouncementTurn = false;
          if (mounted && _cardManager.isAnnouncementPhase) {
            _handleAnnouncementTurnComplete();
          }
        });
      }
      return const SizedBox.shrink();
    }

    // Afficher le panneau d'annonce seulement si c'est le tour du joueur actuel
    final isCurrentPlayerTurn =
        currentAnnouncingPlayer == widget.currentPlayerName;

    // Cacher le panneau si ce n'est pas le tour du joueur OU si l'annonce a déjà été faite
    if (!isCurrentPlayerTurn || _hasAnnounced) {
      return const SizedBox.shrink();
    }

    return _buildCurrentPlayerAnnouncementPanel();
  }

  Widget _buildCurrentPlayerAnnouncementPanel() {
    // ✅ Ne pas afficher ce panneau si la phase d'annonces est terminée
    if (!_cardManager.isAnnouncementPhase) {
      return const SizedBox.shrink();
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
            color: const Color(0xFFF5E6D3), // Couleur beige/peach comme l'image
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
              // Titre avec minuteur
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Combien de plis gagnerez-vous ?',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _announcementCountdown <= 10
                          ? Colors.red
                          : Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_announcementCountdown',
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

              // Slider pour choisir l'annonce
              if (!_hasAnnounced) ...[
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF8B4513),
                    inactiveTrackColor: Colors.grey.shade300,
                    thumbColor: const Color(0xFF8B4513),
                    overlayColor: const Color(0xFF8B4513).withOpacity(0.2),
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                  ),
                  child: Slider(
                    value: _currentAnnouncement.toDouble(),
                    min: 2,
                    max: 13,
                    divisions: 11,
                    onChanged: (value) {
                      setState(() {
                        _currentAnnouncement = value
                            .round()
                            .clamp(2, 13)
                            .toInt();
                      });
                    },
                  ),
                ),

                const SizedBox(height: 6),

                // Contrôles d'annonce compacts
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Icône ampoule (hint)
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.orange.shade600,
                      size: 18,
                    ),

                    // Bouton moins
                    GestureDetector(
                      onTap: () {
                        if (_currentAnnouncement > 2) {
                          setState(() {
                            _currentAnnouncement = (_currentAnnouncement - 1)
                                .clamp(2, 13)
                                .toInt();
                          });
                        }
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: const Icon(
                          Icons.remove,
                          color: Colors.black,
                          size: 14,
                        ),
                      ),
                    ),

                    // Valeur actuelle
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF8B4513),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '$_currentAnnouncement',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Bouton plus
                    GestureDetector(
                      onTap: () {
                        if (_currentAnnouncement < 13) {
                          setState(() {
                            _currentAnnouncement = (_currentAnnouncement + 1)
                                .clamp(2, 13)
                                .toInt();
                          });
                        }
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.black,
                          size: 14,
                        ),
                      ),
                    ),

                    // Bouton validation (checkmark vert)
                    GestureDetector(
                      onTap: () {
                        // _makeAnnouncementWithTimer appelle déjà _handleAnnouncementTurnComplete()
                        _makeAnnouncementWithTimer(_currentAnnouncement);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Message après annonce
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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

  Widget _buildOtherPlayerAnnouncementMessage() {
    final currentPlayerName = _cardManager.currentPlayerTurn ?? 'Un joueur';

    return Positioned(
      top: MediaQuery.of(context).size.height * 0.3,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            'C\'est le tour d\'annonce de $currentPlayerName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementButton() {
    // Cette fonction n'est plus utilisée
    return const SizedBox.shrink();
  }

  Widget _buildGameControls() {
    return Stack(
      children: [
        // Bouton liste (haut gauche)
        Positioned(
          top: 20,
          left: 20,
          child: _buildControlButton(
            icon: Icons.list,
            onTap: () {
              _showGameMenu();
            },
          ),
        ),

        // Bouton paramètres (haut droite)
        Positioned(
          top: 20,
          right: 20,
          child: _buildControlButton(
            icon: Icons.settings,
            onTap: () {
              _showGameSettings();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    String? label,
    IconData? subIcon,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            if (label != null) ...[
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subIcon != null) ...[
                Icon(subIcon, color: Colors.red, size: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoomInfo() {
    return Positioned(
      top: 20,
      left: 80, // Collé au menu (menu fait ~50px + marge)
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
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

  Widget _buildChatOverlay() {
    // Le chat est uniquement disponible en mode humain
    if (_gameSession.playWithBots) return const SizedBox.shrink();
    return Positioned(
      bottom: 16,
      left: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isChatPanelVisible) _buildChatPanel(),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'room_chat_toggle',
            backgroundColor: Colors.black.withOpacity(0.75),
            onPressed: () {
              setState(() {
                _isChatPanelVisible = !_isChatPanelVisible;
              });
              if (_isChatPanelVisible) {
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
                    _isChatPanelVisible = false;
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
                      label: Text(
                        opt['label']!,
                        style: const TextStyle(fontSize: 11),
                      ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
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
                  controller: _chatInputController,
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onSubmitted: (_) => _handleSendChatInput(),
                ),
              ),
              const SizedBox(width: 8),
              _isSendingChatMessage
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
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
    if (_chatToastMessage == null || _chatToastAnimation == null) {
      return const SizedBox.shrink();
    }
    final pseudo = (_chatToastMessage!['pseudo'] ?? 'Joueur').toString();
    final message = (_chatToastMessage!['message'] ?? '').toString();

    return AnimatedBuilder(
      animation: _chatToastAnimation!,
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        // Calculer la position de gauche à droite (-1.0 à 1.0)
        // -1.0 = complètement à gauche (hors écran), 1.0 = complètement à droite (hors écran)
        final leftPosition =
            (_chatToastAnimation!.value + 1.0) /
            2.0; // Convertir de [-1,1] à [0,1]
        final left =
            leftPosition * (screenWidth + 300) -
            300; // 300 = largeur approximative du toast

        return Positioned(
          bottom: _isChatPanelVisible ? 310 : 120,
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChatToast(Map<String, dynamic> message) {
    if (!mounted) return;
    // Annuler le timer précédent si un nouveau message arrive
    _chatToastTimer?.cancel();
    _chatToastAnimationController.stop();
    _chatToastAnimationController.reset();

    setState(() {
      _chatToastMessage = message;
    });

    // Démarrer l'animation de traversée de l'écran
    _chatToastAnimationController.forward();
    
    // Cacher le message après l'animation (8 secondes pour laisser le temps de lire)
    _chatToastTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        _chatToastAnimationController.stop();
        setState(() {
          _chatToastMessage = null;
        });
      }
    });
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showChatError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  EdgeInsets _getPlayerMargin(String position) {
    switch (position) {
      case 'top':
        return EdgeInsets.zero; // Pas de marge pour coller au bord
      case 'left':
        return const EdgeInsets.only(left: 0); // Collé au bord gauche
      case 'right':
        return const EdgeInsets.only(right: 0); // Collé au bord droit
      case 'bottom':
        return const EdgeInsets.only(bottom: 0); // Collé complètement en bas
      default:
        return EdgeInsets.zero;
    }
  }

  String _getSuitSymbol(String suit) {
    switch (suit) {
      case 'hearts':
        return '♥';
      case 'diamonds':
        return '♦';
      case 'clubs':
        return '♣';
      case 'spades':
        return '♠';
      default:
        return '';
    }
  }

  Color _getSuitColor(String suit) {
    switch (suit) {
      case 'hearts':
      case 'diamonds':
        return Colors.red;
      case 'clubs':
      case 'spades':
        return Colors.black;
      default:
        return Colors.black;
    }
  }

  void _playCard(Map<String, dynamic> card) {
    // Vérifier si c'est le tour du joueur actuel
    if (_cardManager.currentPlayerTurn != widget.currentPlayerName) {
      return;
    }

    // Vérifier si c'est la phase de jeu (pas d'annonces)
    if (_cardManager.isAnnouncementPhase) {
      return;
    }
    
    // ✅ Vérifier si ce joueur est déjà en train de jouer (éviter les doublons)
    if (_currentPlayerPlaying == widget.currentPlayerName) {
      print('⚠️ ${widget.currentPlayerName} est déjà en train de jouer - évitement du doublon');
      return;
    }

    // Obtenir les cartes du joueur actuel
    final playerCards = _cardManager.getPlayerCards(widget.currentPlayerName);

    // ✅ Synchroniser le pli actuel avec GameLogic pour déterminer correctement les cartes jouables
    _gameLogic.syncCurrentTrick(_cardManager.currentTrick);

    // Jouer la carte selon les règles du jeu
    final playable = _gameLogic.getPlayableCards(
      playerCards,
      widget.currentPlayerName,
      _gameLogic.currentTrick.isEmpty,
    );
    if (!playable.contains(card)) {
      // Carte non jouable → feedback léger
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

    // ✅ Marquer que ce joueur est en train de jouer
    _currentPlayerPlaying = widget.currentPlayerName;
    print('🎴 ${widget.currentPlayerName} commence à jouer la carte ${card['code']}');
    
    // ✅ Appeler directement l'API Laravel (pas d'animation locale avant)
    // Le backend gère tout : validation, diffusion WebSocket, animation via card_played
    final result = _gameLogic.playCard(
      card,
      widget.currentPlayerName,
      playerCards,
    );

    if (result['success'] == true) {
      // ✅ Appeler l'API Laravel qui gère tout (détection 4ème carte, calcul gagnant, délai)
      _playCardViaLaravelAPI(
        card,
        result,
        playerName: widget.currentPlayerName,
      );
    } else {
      // ✅ Libérer le flag si le résultat n'est pas success
      _currentPlayerPlaying = null;
    }
  }

  // ✅ NOUVELLE MÉTHODE: Jouer une carte via l'API Laravel
  // Le backend gère la détection de la 4ème carte, le calcul du gagnant et le délai de 2 secondes
  Future<void> _playCardViaLaravelAPI(
    Map<String, dynamic> card,
    Map<String, dynamic> localResult, {
    String? playerName,
  }) async {
    final roomId = _gameSession.roomId;
    if (roomId == null || roomId.isEmpty) {
      print('❌ RoomId manquant, impossible de jouer la carte via API');
      _currentPlayerPlaying = null;
      return;
    }

    try {
      // 1. Obtenir le round_id et trick_id depuis Laravel
      final roundNumber = _gameSession.currentRound;
      // ✅ RÈGLE: Un round = exactement 13 tricks (4 joueurs × 13 cartes = 52 cartes)
      // ✅ S'assurer que trickNumber est au moins 1 (le premier trick est numéroté 1, pas 0)
      // ✅ Et qu'il ne dépasse jamais 13
      final trickNumber = (_cardManager.currentTrickNumber > 0 
          ? _cardManager.currentTrickNumber 
          : 1).clamp(1, 13);
      
      print('📤 Récupération round_id et trick_id: round=$roundNumber, trick=$trickNumber');
      final trickData = await GameApiService.instance.getCurrentTrick(
        roomId: roomId,
        roundNumber: roundNumber,
        trickNumber: trickNumber,
      );

      if (trickData['success'] != true) {
        print('❌ Erreur lors de la récupération du trick: ${trickData['message']}');
        _currentPlayerPlaying = null;
        return;
      }

      final data = trickData['data'] as Map<String, dynamic>;
      final gameId = data['game_id'] as int;
      final roundId = data['round_id'] as int;
      final trickId = data['trick_id'] as int;

      // 2. Préparer le code de la carte
      String cardCode = card['code'] as String? ?? '';
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
      
      // 3. Appeler l'API Laravel playCard
      await GameApiService.instance.playCard(
        gameId: gameId,
        roundId: roundId,
        trickId: trickId,
        cardCode: cardCode,
        roundNumber: roundNumber,
        trickNumber: trickNumber,
        playerName: playerName,
      );

      // 4. ✅ Retirer la carte de la main du joueur UNIQUEMENT après confirmation du backend
      // Le backend a déjà diffusé via WebSocket, donc la carte est bien jouée
      final effectivePlayerName = playerName ?? widget.currentPlayerName;
      _cardManager.playCard(effectivePlayerName, card);
      
      // 5. Libérer le flag
      _currentPlayerPlaying = null;
      
      // 6. Mettre à jour l'UI
      if (mounted) {
        setState(() {});
      }

      // 7. Le backend gère déjà :
      //    - La détection de la 4ème carte
      //    - Le calcul du gagnant
      //    - Le délai de 2 secondes
      //    - La diffusion de l'événement trick_completed
      //    Donc on n'a plus besoin de gérer trickComplete ici
      //    On attend juste l'événement WebSocket trick_completed
      
      // 8. Si ce n'est pas la 4ème carte, passer au joueur suivant
      if (localResult['trickComplete'] != true) {
        // ✅ Obtenir le tour actuel depuis le backend pour s'assurer de la synchronisation
        Future.delayed(const Duration(milliseconds: 200), () async {
          if (!mounted) return;
          try {
            final trickData = await GameApiService.instance.getCurrentTrick(
              roomId: roomId,
              roundNumber: roundNumber,
              trickNumber: trickNumber,
            );
            
            if (trickData['success'] == true && trickData['data'] != null) {
              final data = trickData['data'] as Map<String, dynamic>;
              final gameId = data['game_id'] as int;
              final roundId = data['round_id'] as int;
              final trickId = data['trick_id'] as int;
              
              final turnData = await GameApiService.instance.getCurrentTurn(
                gameId: gameId,
                roundId: roundId,
                trickId: trickId,
              );
              
              if (turnData['success'] == true && turnData['data'] != null) {
                final currentTurnPlayer = turnData['data']['player_name'] as String?;
                if (currentTurnPlayer != null && currentTurnPlayer.isNotEmpty) {
                  print('🔄 Tour actuel depuis le backend: $currentTurnPlayer');
                  _cardManager.currentPlayerTurn = currentTurnPlayer;
                  if (mounted) setState(() {});
                }
              }
            }
          } catch (e) {
            print('⚠️ Erreur lors de la récupération du tour depuis le backend: $e');
          }
          
          if (!mounted) return;
          print('🔄 Vérification du prochain joueur après carte jouée: ${_cardManager.currentPlayerTurn}');
          if (mounted) setState(() {});
          _maybeAutoPlayCurrentBot();
        });
      }
      // Si c'est la 4ème carte, on attend l'événement trick_completed du backend

    } catch (e) {
      print('❌ Erreur lors de l\'appel API Laravel playCard: $e');
      print('   Détails: ${e.toString()}');
      
      // ✅ Libérer le flag pour permettre de réessayer
      _currentPlayerPlaying = null;
      
      // ✅ Ne pas bloquer le jeu si c'est une erreur de validation (422) ou de permission (403)
      // Ces erreurs sont normales et ne doivent pas bloquer le jeu
      final errorString = e.toString().toLowerCase();
      final isValidationError = errorString.contains('422') || 
                                errorString.contains('validation') ||
                                errorString.contains('jouable') ||
                                errorString.contains('tour');
      
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
        } else {
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
      }
    }
  }

  // Démarre l'animation de la carte de la main vers le centre
  void _startCardAnimation(
    Map<String, dynamic> card,
    String playerName,
    VoidCallback onComplete,
  ) {
    setState(() {
      _animatedCard = card;
      _animatingPlayerName = playerName;
      _isAnimatingCard = true;
    });

    _cardAnimationController.reset();
    _cardAnimationController.forward().then((_) {
      // Animation terminée
      setState(() {
        _isAnimatingCard = false;
        _animatedCard = null;
        _animatingPlayerName = null;
      });
      // Exécuter le callback
      onComplete();
    });
  }

  // Construit le widget de la carte animée
  Widget _buildAnimatedCard() {
    if (_animatedCard == null ||
        _cardAnimation == null ||
        _animatingPlayerName == null) {
      return const SizedBox.shrink();
    }

    // Obtenir la position du joueur (bottom, right, top, left)
    final playerPosition = _getDisplayPositionForPlayerName(
      _animatingPlayerName!,
    );
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Positions de départ selon la position du joueur
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

    // Position d'arrivée (centre de l'écran)
    final centerX = screenWidth / 2;
    final centerY = screenHeight / 2;

    return AnimatedBuilder(
      animation: _cardAnimation!,
      builder: (context, child) {
        // Interpoler la position depuis la position du joueur vers le centre
        final currentY = startY + (centerY - startY) * _cardAnimation!.value;
        final currentX = startX + (centerX - startX) * _cardAnimation!.value;

        // Interpoler la taille (légèrement plus grande au centre)
        final scale = 1.0 + (_cardAnimation!.value * 0.3);

        // Interpoler la rotation (légère rotation pendant le mouvement)
        final rotation = (_cardAnimation!.value * 0.1);

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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    _cardManager.getCardImagePath(_animatedCard!),
                    width: 60,
                    height: 85,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.white,
                        child: Center(
                          child: Text(
                            _animatedCard!['code'] ?? '',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Fonction pour obtenir l'annonce du joueur actuel
  int _getPlayerAnnouncement() {
    final announcements = _cardManager.getCurrentRoundAnnouncements();
    final playerAnnouncement = announcements.firstWhere(
      (ann) => ann['player'] == widget.currentPlayerName,
      orElse: () => <String, Object>{'announcement': 0},
    );
    return playerAnnouncement['announcement'] as int;
  }

  // Fonction pour obtenir l'affichage de l'annonce d'un joueur (0/X)
  String _getPlayerAnnouncementDisplay(String playerName) {
    // Afficher {plis gagnés}/{annonce}
    final announcements = _cardManager.getCurrentRoundAnnouncements();
    
    final playerAnnouncement = announcements.firstWhere(
      (ann) => ann['player'] == playerName,
      orElse: () => <String, Object>{'announcement': 0},
    );
    final announced = playerAnnouncement['announcement'] as int? ?? 0;
    
    // Pendant la phase d'annonces, on veut 0/X (compteur de plis repart à 0)
    final obtained = _cardManager.isAnnouncementPhase
        ? 0
        : _cardManager.getObtainedTricks(playerName);
    return '$obtained/$announced';
  }

  // Fonction pour obtenir le nombre de cartes restantes d'un joueur
  // ⚠️ IMPORTANT: Fonctionne pour les deux modes (bot et humain)
  // En mode bot: toutes les cartes sont gérées localement
  // En mode humain: les cartes de chaque joueur sont gérées localement par chaque client
  int _getPlayerCardCount(String playerName) {
    // Récupérer le nombre réel de cartes depuis LocalCardManager
    // Ce nombre diminue automatiquement quand une carte est jouée via _cardManager.playCard()
    final cardCount = _cardManager.getPlayerCards(playerName).length;

    // ⚠️ IMPORTANT: Si cardCount est 0 mais qu'on est encore en phase de jeu,
    // c'est normal (toutes les cartes ont été jouées)
    // Si cardCount est > 13, c'est une erreur, on limite à 13
    return cardCount.clamp(0, 13);
  }

  // Fonction pour obtenir le score global d'un joueur (mise à jour en temps réel)
  // ⚠️ IMPORTANT: Fonctionne pour les deux modes (bots et humains)
  int _getPlayerGlobalScore(String playerName) {
    // Vérifier que les scores globaux sont initialisés
    if (_gameSession.globalScores.isEmpty && _gameSession.players.isNotEmpty) {
      // Si non initialisés, initialiser à 0
      _gameSession.globalScores = List.filled(_gameSession.players.length, 0.0);
    }

    // Utiliser directement globalScores pour une mise à jour en temps réel
    // Fonctionne identiquement pour playWithBots = true ou false
    final playerIndex = _gameSession.players.indexWhere(
      (p) => (p['name'] as String?) == playerName,
    );

    if (playerIndex == -1 || playerIndex >= _gameSession.globalScores.length) {
      return 0;
    }

    // Retourner le score global directement depuis globalScores
    // Ce score est mis à jour après chaque manche via finalizeRound() dans _onRoundCompleted()
    return _gameSession.globalScores[playerIndex].toInt();
  }

  // Fonction pour démarrer le timer d'annonces
  void _startAnnouncementTimer({
    required String playerName,
    required bool isLocalPlayer,
  }) {
    // ⚠️ IMPORTANT: 30 secondes pour tous les modes (bot et humain)
    _announcementTimer?.cancel();
    _currentAnnouncementPlayer = playerName;
    _announcementCountdown = 30;
    if (isLocalPlayer) {
      _hasAnnounced = false;
    }

    _announcementTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_announcementCountdown > 0) {
          _announcementCountdown--;
        }
      });

      if (_announcementCountdown <= 0) {
        timer.cancel();
        _handleAnnouncementTimeout();
      }
    });
  }

  void _startAnnouncementTimerForCurrentPlayer() {
    final playerName = _cardManager.getCurrentAnnouncingPlayer();
    if (playerName.isEmpty) {
      return;
    }
    final isLocalPlayer = playerName == widget.currentPlayerName;
    _startAnnouncementTimer(
      playerName: playerName,
      isLocalPlayer: isLocalPlayer,
    );
  }

  // Fonction pour gérer le timeout d'annonce
  void _handleAnnouncementTimeout() {
    final playerName = _currentAnnouncementPlayer;
    if (playerName == null || playerName.isEmpty) {
      return;
    }

    final announcements = _cardManager.getCurrentRoundAnnouncements();
    final alreadyAnnounced = announcements.any(
      (ann) => ann['player'] == playerName,
    );
    if (alreadyAnnounced) {
      // L'annonce a déjà été faite, passer au suivant
      _handleAnnouncementTurnComplete();
      return;
    }

    // ✅ Timeout : Annonce automatique de 2 (minimum) et passage au suivant
    print('⏰ Timeout d\'annonce pour $playerName - Attribution automatique de 2 plis');
    _forceAnnouncementForPlayer(playerName, 2);
    
    // Envoyer l'annonce via WebSocket si c'est le joueur local
    if (playerName == widget.currentPlayerName) {
      final roomId = _gameSession.roomId;
      if (roomId != null && roomId.isNotEmpty) {
        try {
          final wsService = GameWebSocketService();
          if (wsService.isConnected) {
            wsService.makeAnnouncement(2).catchError((e) {
              print('⚠️ Erreur WebSocket lors de l\'envoi de l\'annonce timeout: $e');
            });
          }
        } catch (e) {
          print('⚠️ Erreur lors de l\'envoi de l\'annonce timeout via WebSocket: $e');
        }
      }
    }
    
    // Passer au joueur suivant
    _handleAnnouncementTurnComplete();
  }

  void _forceAnnouncementForPlayer(String playerName, int announcement) {
    _announcementTimer?.cancel();
    final int clampedAnnouncement = announcement.clamp(2, 13).toInt();
    if (playerName == widget.currentPlayerName) {
      _cardManager.makeAnnouncement(playerName, clampedAnnouncement);
      if (mounted) {
        setState(() {
          _hasAnnounced = true;
          _currentAnnouncement = clampedAnnouncement;
        });
      } else {
        _hasAnnounced = true;
        _currentAnnouncement = clampedAnnouncement;
      }
    } else {
      _cardManager.forceAnnouncement(playerName, clampedAnnouncement);
    }

    _currentAnnouncementPlayer = null;
  }

  // Fonction pour faire une annonce avec timer
  void _makeAnnouncementWithTimer(int announcement) {
    _forceAnnouncementForPlayer(widget.currentPlayerName, announcement);
    
    // Forcer la mise à jour de l'interface pour afficher l'annonce du joueur local
    if (mounted) {
      setState(() {
        // Mettre à jour l'interface pour afficher l'annonce du joueur local
      });
    }
    
    // Envoyer l'annonce via WebSocket pour synchroniser avec les autres joueurs
    final roomId = _gameSession.roomId;
    if (roomId != null && roomId.isNotEmpty) {
      try {
        final wsService = GameWebSocketService();
        if (wsService.isConnected) {
          wsService.makeAnnouncement(announcement).catchError((e) {
            print('⚠️ Erreur WebSocket lors de l\'envoi de l\'annonce: $e');
            // Continuer même en cas d'erreur WebSocket
          });
        }
      } catch (e) {
        print('⚠️ Erreur lors de l\'envoi de l\'annonce via WebSocket: $e');
        // Continuer même en cas d'erreur WebSocket
      }
    }
    
    // ✅ IMPORTANT: Passer au joueur suivant après l'annonce
    _handleAnnouncementTurnComplete();
  }

  void _makeAnnouncement(int announcement) {
    // Cette fonction est maintenant remplacée par _makeAnnouncementWithTimer
    // Elle est gardée pour compatibilité mais ne devrait plus être utilisée
    _makeAnnouncementWithTimer(announcement);

    // Gérer le passage au tour suivant
    _handleAnnouncementTurnComplete();
  }

  // Fonction pour gérer la fin du tour d'annonce
  void _handleAnnouncementTurnComplete() {
    final playerNames = _gameSession.players
        .map((player) => player['name'] as String? ?? 'Joueur')
        .toList();
    
    // Vérifier si toutes les annonces sont faites AVANT de passer au tour suivant
    if (_cardManager.areAllAnnouncementsDone(playerNames)) {
      print('✅ Toutes les annonces sont terminées !');

      // Réinitialiser le timer d'annonce
      _announcementTimer?.cancel();
      _currentAnnouncementPlayer = null;
      _announcementCountdown = 0;

      // Valider les enchères (vérifier si total < 10)
      final announcements = _cardManager.getCurrentRoundAnnouncements();
      print('📊 Annonces récupérées : $announcements');
      final validationResult = _gameLogic.validateAnnouncements(announcements);

      if (validationResult['needsNewBids'] == true) {
        // Cas 2: Total < 10 → Ajouter +1 à chaque annonce et démarrer le jeu après notification
        _showLowTotalMessage();
        // Ajouter +1 à chaque annonce dans le gestionnaire (fonctionne pour mode bot et humain)
        _cardManager.incrementAllAnnouncements();
        // Récupérer les annonces mises à jour
        final updatedAnnouncements = _cardManager
            .getCurrentRoundAnnouncements();
        print('📊 Annonces augmentées de +1 chacune: $updatedAnnouncements');

        // Démarrer le jeu après 3 secondes
        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;
          try {
            _cardManager.isAnnouncementPhase = false;
            // Choisir le premier joueur de la phase de jeu selon la rotation par round
            final starting = _getStartingPlayerForRoundPlay(
              _gameSession.currentRound + 1,
            );
            _cardManager.currentPlayerTurn = starting;

            // Enregistrer la ronde (annonces augmentées dans l'ordre des joueurs)
            final players = _gameSession.players
                .map((p) => p['name'] as String? ?? 'Joueur')
                .toList();
            // Utiliser les annonces mises à jour depuis le gestionnaire
            final anns = players.map((name) {
              final a = updatedAnnouncements.firstWhere(
                (e) => e['player'] == name,
                orElse: () => <String, Object>{'announcement': 0},
              );
              return a['announcement'] as int? ?? 0;
            }).toList();
            
            // ✅ Vérifier que la ronde n'a pas déjà été ajoutée
            final nextRoundNum = _gameSession.currentRound + 1;
            final alreadyAdded = _gameSession.roundsData.any(
              (r) => (r['roundNumber'] as int) == nextRoundNum
            );
            
            if (!alreadyAdded) {
              _gameSession.addRound(anns);
              print('✅ Round $nextRoundNum ajouté (total < 10, annonces augmentées)');
            } else {
              print('⚠️ Round $nextRoundNum déjà ajouté - évitement du doublon');
            }

            print('✅ Phase de jeu configurée - Premier joueur: $starting');

            // Utiliser un Future pour s'assurer que le setState est appelé après la configuration
            Future.microtask(() {
              if (mounted) {
                setState(() {
                  print('✅ Interface mise à jour');
                });

                // ✅ Le jeu démarre automatiquement sans message - les joueurs voient directement le premier tour

                // Démarrer le moteur de jeu automatique pour les bots
                _maybeAutoPlayCurrentBot();
              }
            });
          } catch (e, stackTrace) {
            print('❌ Erreur lors du démarrage de la phase de jeu : $e');
            print('Stack trace : $stackTrace');
          }
        });
      } else {
        // Cas 3: Annonces valides → Commencer la phase de jeu
        print('🎮 Démarrage de la phase de jeu !');
        try {
          _cardManager.isAnnouncementPhase = false;
          // Choisir le premier joueur de la phase de jeu selon la rotation par round
          final starting = _getStartingPlayerForRoundPlay(
            _gameSession.currentRound + 1,
          );
          _cardManager.currentPlayerTurn = starting;

          // Enregistrer la ronde (annonces dans l'ordre des joueurs)
          final players = _gameSession.players
              .map((p) => p['name'] as String? ?? 'Joueur')
              .toList();
          final anns = players.map((name) {
            final a = _cardManager.getCurrentRoundAnnouncements().firstWhere(
              (e) => e['player'] == name,
              orElse: () => <String, Object>{'announcement': 0},
            );
            return a['announcement'] as int? ?? 0;
          }).toList();
          
          // ✅ Vérifier que la ronde n'a pas déjà été ajoutée
          final nextRoundNum = _gameSession.currentRound + 1;
          final alreadyAdded = _gameSession.roundsData.any(
            (r) => (r['roundNumber'] as int) == nextRoundNum
          );
          
          if (!alreadyAdded) {
            _gameSession.addRound(anns);
            print('✅ Round $nextRoundNum ajouté (annonces valides)');
          } else {
            print('⚠️ Round $nextRoundNum déjà ajouté - évitement du doublon');
          }

          print('✅ Phase de jeu configurée - Premier joueur: $starting');

          // Utiliser un Future pour s'assurer que le setState est appelé après la configuration
          Future.microtask(() {
            if (mounted) {
              setState(() {
                print('✅ Interface mise à jour');
              });

              // Afficher un message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Phase de jeu démarrée ! 🎮'),
                  backgroundColor: Color(0xFF228B22),
                  duration: Duration(seconds: 2),
                ),
              );

              // Démarrer le moteur de jeu automatique pour les bots
              _maybeAutoPlayCurrentBot();
            }
          });
        } catch (e, stackTrace) {
          print('❌ Erreur lors du démarrage de la phase de jeu : $e');
          print('Stack trace : $stackTrace');
        }
      }
    } else {
      // ✅ Vérifier d'abord si le joueur actuel a déjà fait son annonce
      final currentPlayerBeforeTurn = _cardManager.currentPlayerTurn ?? 'Joueur';
      final announcements = _cardManager.getCurrentRoundAnnouncements();
      final hasCurrentPlayerAnnounced = announcements.any(
        (ann) => ann['player'] == currentPlayerBeforeTurn,
      );
      
      // Si le joueur actuel n'a pas encore fait son annonce, ne pas passer au suivant
      if (!hasCurrentPlayerAnnounced && currentPlayerBeforeTurn.isNotEmpty) {
        print('⚠️ Le joueur $currentPlayerBeforeTurn n\'a pas encore fait son annonce - attente');
        // Démarrer le timer pour le joueur actuel s'il ne l'a pas déjà
        if (_currentAnnouncementPlayer != currentPlayerBeforeTurn) {
          final isLocalPlayer = currentPlayerBeforeTurn == widget.currentPlayerName;
          final isBotPlayer = !isLocalPlayer &&
              (_gameSession.playWithBots ||
                  _gameSession.players.any(
                    (p) =>
                        (p['name'] as String?) == currentPlayerBeforeTurn &&
                        (p['is_bot'] as bool?) == true,
                  ));
          
          if (isBotPlayer) {
            // Bot - annonce automatique
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted && _cardManager.isAnnouncementPhase) {
                try {
                  final botAnnouncement = _cardManager.getBotAnnouncement(currentPlayerBeforeTurn);
                  print('🤖 $currentPlayerBeforeTurn annonce : $botAnnouncement plis');
                  _cardManager.makeAnnouncement(currentPlayerBeforeTurn, botAnnouncement);
                  if (mounted) setState(() {});
                  _handleAnnouncementTurnComplete();
                } catch (e) {
                  print('❌ Erreur annonce bot: $e');
                }
              }
            });
          } else if (isLocalPlayer) {
            _currentAnnouncement = 2;
            _hasAnnounced = false;
            _startAnnouncementTimer(playerName: currentPlayerBeforeTurn, isLocalPlayer: true);
          } else {
            _startAnnouncementTimer(playerName: currentPlayerBeforeTurn, isLocalPlayer: false);
          }
        }
        return; // Ne pas passer au suivant tant que l'annonce n'est pas faite
      }
      
      // ✅ Passer au joueur suivant seulement si l'annonce a été faite
      final playerNames = _gameSession.players
          .map((player) => player['name'] as String? ?? 'Joueur')
          .toList();
      _cardManager.nextTurn(playerNames);
      
      // Démarrer le timer pour le prochain joueur
      final currentPlayer = _cardManager.currentPlayerTurn ?? 'Joueur';
      print('⏭️ Tour suivant pour : $currentPlayer');

      // ⚠️ IMPORTANT: Chaque joueur a 30 secondes pour faire son annonce
      // Vérifier si c'est un joueur humain (pas un bot)
      final isLocalPlayer = currentPlayer == widget.currentPlayerName;
      final isBotPlayer =
          !isLocalPlayer &&
          (_gameSession.playWithBots ||
              _gameSession.players.any(
                (p) =>
                    (p['name'] as String?) == currentPlayer &&
                    (p['is_bot'] as bool?) == true,
              ));

      final isHumanRemotePlayer = !isLocalPlayer && !isBotPlayer;

      if (isBotPlayer) {
        // Bot - annonce automatique après 1 seconde
        print('🤖 Démarrage annonce automatique pour : $currentPlayer');
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && _cardManager.isAnnouncementPhase) {
            try {
              final botAnnouncement = _cardManager.getBotAnnouncement(
                currentPlayer,
              );
              print('🤖 $currentPlayer annonce : $botAnnouncement plis');
              _cardManager.makeAnnouncement(currentPlayer, botAnnouncement);
              print('🤖 Annonce faite pour $currentPlayer');
              
              // Forcer la mise à jour de l'interface
              if (mounted) {
                setState(() {});
              }
              
              // Passer au joueur suivant (récursif)
              _handleAnnouncementTurnComplete();
            } catch (e, stackTrace) {
              print('❌ Erreur lors de l\'annonce automatique : $e');
              print('Stack trace : $stackTrace');
              // En cas d'erreur, forcer le passage au joueur suivant
              final nextPlayers = _gameSession.players
                  .map((player) => player['name'] as String? ?? 'Joueur')
                  .toList();
              _cardManager.nextTurn(nextPlayers);
              if (mounted) {
                setState(() {});
              }
              _handleAnnouncementTurnComplete();
            }
          } else {
            print(
              '⚠️ Mounted: $mounted, IsAnnouncementPhase: ${_cardManager.isAnnouncementPhase}',
            );
          }
        });
      } else if (isLocalPlayer) {
        // ✅ Joueur humain local - démarrer le timer de 30 secondes
        // Le panneau d'annonce sera visible uniquement pour ce joueur
        print('👤 Tour du joueur humain local : $currentPlayer');
        _currentAnnouncement = 2; // Réinitialiser l'annonce par défaut
        _hasAnnounced = false; // Réinitialiser le flag d'annonce
        _startAnnouncementTimer(playerName: currentPlayer, isLocalPlayer: true);
      } else if (isHumanRemotePlayer) {
        // ✅ Joueur humain distant - démarrer un timer de 30 secondes
        // Le panneau d'annonce ne sera PAS visible (seul le joueur local voit son panneau)
        print('🌐 Tour d\'un autre joueur humain : $currentPlayer');
        _startAnnouncementTimer(
          playerName: currentPlayer,
          isLocalPlayer: false,
        );
      } else {
        // Par sécurité, annuler tout timer
        _announcementTimer?.cancel();
        _announcementCountdown = 0;
      }
    }

    setState(() {
      // Mettre à jour l'interface
    });
  }

  // Si c'est un bot, jouer automatiquement une carte valide
  void _maybeAutoPlayCurrentBot() {
    if (!mounted) return;
    if (_cardManager.isAnnouncementPhase) return;

    // Vérifier si tous les joueurs ont joué toutes leurs cartes
    final allPlayers = _gameSession.players;
    bool allPlayersFinished = true;
    for (var p in allPlayers) {
      final name = p['name'] as String;
      if (_cardManager.getPlayerCards(name).isNotEmpty) {
        allPlayersFinished = false;
        break;
      }
    }

    if (allPlayersFinished) {
      print('🎉 Tous les joueurs ont joué leurs cartes ! Manche terminée.');
      _onRoundCompleted();
      return;
    }

    final current = _cardManager.currentPlayerTurn;
    if (current == null || current.isEmpty) return;
    
    // ✅ Vérifier si ce joueur est déjà en train de jouer (éviter les doublons)
    if (_currentPlayerPlaying == current) {
      print('⚠️ $current est déjà en train de jouer - évitement du doublon');
      return;
    }

    // ⚠️ IMPORTANT: En mode humain, ne jamais jouer automatiquement pour un joueur humain
    // Les joueurs humains doivent jouer leurs cartes eux-mêmes en les touchant
    if (!_gameSession.playWithBots) {
      // Mode humain - vérifier si c'est un bot remplaçant ou un joueur humain
      final isReplacementBot = _gameSession.players.any(
        (p) =>
            (p['name'] as String?) == current &&
            ((p['isReplacementBot'] as bool?) == true ||
                (p['is_bot'] as bool?) == true),
      );

      if (!isReplacementBot) {
        // C'est un joueur humain - ne pas jouer automatiquement
        print('👤 Mode humain: $current doit jouer sa carte manuellement');
        return;
      }
      // Si c'est un bot remplaçant, continuer avec le jeu automatique
      print('🤖 Mode humain: bot remplaçant $current joue automatiquement');
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
    final botCards = _cardManager.getPlayerCards(current);
    if (botCards.isEmpty) {
      print('✅ $current a terminé ses cartes, on passe au suivant');
      // Le _finishTrick va gérer le passage au joueur suivant
      return;
    }

    // ✅ Synchroniser le pli actuel avec GameLogic pour déterminer correctement les cartes jouables
    _gameLogic.syncCurrentTrick(_cardManager.currentTrick);

    // Trouver une carte jouable pour le bot
    final playable = _gameLogic.getPlayableCards(
      botCards,
      current,
      _gameLogic.currentTrick.isEmpty,
    );

    // Si aucune carte n'est jouable selon les règles strictes, jouer n'importe quelle carte
    final cardToPlay = playable.isEmpty ? botCards.first : playable.first;

    if (botCards.isEmpty) {
      print('⚠️ $current n\'a plus de cartes');
      return;
    }

    if (playable.isEmpty) {
      print(
        '⚠️ Aucune carte jouable pour $current selon les règles, on joue ${cardToPlay['code']}',
      );
    }

    // ✅ Marquer que ce joueur est en train de jouer
    _currentPlayerPlaying = current;
    print('🎴 $current commence à jouer la carte ${cardToPlay['code']}');
    
    // Démarrer l'animation de la carte du bot vers le centre
    _startCardAnimation(cardToPlay, current, () {
      // Après l'animation, jouer la carte
      if (!mounted || _cardManager.isAnnouncementPhase) {
        _currentPlayerPlaying = null; // Libérer le flag en cas d'erreur
        return;
      }
      try {
        final card = cardToPlay;
        final res = _gameLogic.playCard(card, current, botCards);
        if (res['success'] == true) {
          _cardManager.playCard(current, card);
          
          // ✅ Libérer le flag après avoir joué la carte
          _currentPlayerPlaying = null;

          if (res['trickComplete'] == true) {
            final winner = res['winner'] as String? ?? '';
            // Afficher d'abord les 4 cartes puis animer la collecte
            setState(() {
              _lastTrickWinner = winner;
              _isCollectingTrick = false;
            });
            Future.delayed(const Duration(milliseconds: 250), () {
              if (!mounted) return;
              setState(() {
                _isCollectingTrick = true;
              });
            });
            Future.delayed(const Duration(milliseconds: 1200), () {
              if (!mounted) return;
              // ✅ Vider le trick dans GameLogic ET dans cardManager
              _gameLogic.nextTrick();
              _cardManager.clearCurrentTrick(); // ✅ Vider le trick du cardManager pour retirer les cartes du centre
              _cardManager.currentPlayerTurn = winner; // Le gagnant commence
              if (mounted) {
                setState(() {
                  _isCollectingTrick = false;
                });
              }
              _maybeAutoPlayCurrentBot();
            });
          } else {
            // Le manager avance déjà au joueur suivant
            if (mounted) setState(() {});
            _maybeAutoPlayCurrentBot();
          }
        } else {
          // ✅ Libérer le flag si la carte n'a pas pu être jouée
          _currentPlayerPlaying = null;
        }
      } catch (e, stackTrace) {
        print('❌ Erreur lors du jeu automatique du bot: $e');
        print('Stack trace: $stackTrace');
        // ✅ Libérer le flag en cas d'erreur
        _currentPlayerPlaying = null;
      }
    });
  }

  // Calcul et affichage du tableau de score à la fin de la manche
  Future<void> _onRoundCompleted() async {
    try {
      final players = _gameSession.players
          .map((p) => p['name'] as String? ?? 'Joueur')
          .toList();

      final announcements = _cardManager.getCurrentRoundAnnouncements();
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
        for (final p in players) p: _cardManager.getObtainedTricks(p),
      };

      // Calcul des scores selon les règles
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

      // Enregistrer la fin de manche dans la session (persistance)
      // ⚠️ IMPORTANT: Cette méthode fonctionne pour les deux modes (bots et humains)
      final obtainedList = players
          .map((p) => obtainedByPlayer[p] ?? 0)
          .toList();
      _gameSession.finalizeRound(_gameSession.currentRound - 1, obtainedList);

      // Mettre à jour immédiatement l'affichage des scores globaux (compteur de cristal/SG)
      // Fonctionne identiquement pour les deux modes: playWithBots = true ou false
      if (mounted) {
        setState(() {
          // Les scores globaux sont maintenant à jour dans _gameSession.globalScores
          // Le compteur de cristal se mettra à jour automatiquement via _getPlayerGlobalScore
        });
      }

      // Sauvegarde backend de la manche (pour les deux modes)
      try {
        final roomId = _gameSession.roomId ?? '';
        if (roomId.isNotEmpty) {
          await GameApiService.instance.saveRound(
            roomId: roomId,
            roundNumber: _gameSession.currentRound,
            announcements: announcements.cast<Map<String, dynamic>>(),
            obtainedTricks: obtainedByPlayer,
          );
        }
      } catch (_) {}

      // Afficher le tableau de scores (identique pour les deux modes)
      _showScoreboardDialog(
        players,
        announcedByPlayer,
        obtainedByPlayer,
        scores,
      );

      // Après affichage des scores, décider de la suite
      // ⚠️ IMPORTANT: Vérifier si la partie est vraiment terminée avant d'appeler _handleGameWinner
      // La partie se termine uniquement si :
      // 1. Un joueur atteint ou dépasse 150 points, OU
      // 2. 10 rounds ont été complétés (pas seulement créés)

      final winnerIndex = _gameSession.globalScores.indexWhere((s) => s >= 150);
      // Compter uniquement les rounds complétés
      final completedRounds = _gameSession.roundsData
          .where((r) => (r['isCompleted'] as bool?) == true)
          .length;
      final isGameOver = winnerIndex != -1 || completedRounds >= 10;

      print('🔍 Fin de round - Vérification fin de partie:');
      print('   - WinnerIndex (≥150): $winnerIndex');
      print(
        '   - Rounds complétés: $completedRounds / ${_gameSession.roundsData.length}',
      );
      print('   - CurrentRound: ${_gameSession.currentRound}');
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
          final entries = _gameSession.globalScores.asMap().entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final top1 = entries.first;
          final winnerIdx = top1.key;
          winnerName =
              _gameSession.players[winnerIdx]['name'] as String? ?? 'Joueur';
          winnerScore = _gameSession.globalScores[winnerIdx].toInt();

          final minBet = _gameSession.minimumBet ?? 0;
          totalPot = minBet * 4;
          winnerAmount = (totalPot * 0.9).round();
          companyAmount = totalPot - winnerAmount;

          // Vérifier si le gagnant est un bot remplaçant
          for (final player in _gameSession.players) {
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
          final entries = _gameSession.globalScores.asMap().entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final winnerIdx = entries.first.key;
          winnerName =
              _gameSession.players[winnerIdx]['name'] as String? ?? 'Joueur';
          winnerScore = _gameSession.globalScores[winnerIdx].toInt();
          // Payout 90/10 sur la mise totale du salon (mise minimale × 4)
          final minBet = _gameSession.minimumBet ?? 0;
          totalPot = minBet * 4;
          winnerAmount = (totalPot * 0.9).round();
          companyAmount = totalPot - winnerAmount;

          // Vérifier si le gagnant est un bot remplaçant
          for (final player in _gameSession.players) {
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
        if (!_gameSession.playWithBots && totalPot > 0) {
          final roomIdStr = _gameSession.roomId ?? '';
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
        _handleGameWinner(winnerName);

        // Notifier le backend que la partie est terminée (MAIS NE PAS FERMER LE SALON)
        final roomId = _gameSession.roomId ?? '';
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
        Future.delayed(const Duration(milliseconds: 400), _startNewRound);
      }
    } catch (e, st) {
      print('❌ Erreur calcul score: $e');
      print(st);
    }
  }

  void _startNewRound() {
    try {
      final playerNames = _gameSession.players
          .map((p) => p['name'] as String? ?? 'Joueur')
          .toList();

      // Réinitialiser l'état d'annonces/pli et redistribuer (0/0)
      _cardManager.resetRoundCounters();
      _cardManager.shuffleAndDealCards(playerNames);
      _gameLogic.configurePlayers(
        playerCount: playerNames.length,
        cardsPerPlayer: _cardManager.cardsPerPlayer,
      );
      _cardManager.isAnnouncementPhase = true;

      // Premier joueur pour les annonces: créateur si présent
      String firstPlayer = playerNames.first;
      final creator = _gameSession.players.firstWhere(
        (p) => (p['isCreator'] as bool?) == true,
        orElse: () => <String, Object>{},
      );
      if ((creator['name'] as String?) != null) {
        firstPlayer = creator['name'] as String;
      }
      _cardManager.currentPlayerTurn = firstPlayer;

      // Ne pas créer de round "vide" avec 0; on créera le round
      // une fois toutes les annonces terminées (comme pour la manche 1)

      setState(() {});

      // Laisser la boucle d'annonces normale se dérouler (bots/humain)
      if (firstPlayer != widget.currentPlayerName) {
        // Lancer le bot d'annonce initial via la routine existante
        _handleAnnouncementTurnComplete();
      } else {
        setState(() {});
        _startAnnouncementTimerForCurrentPlayer();
      }
    } catch (e, st) {
      print('❌ Erreur démarrage nouvelle manche: $e');
      print(st);
    }
  }

  void _handleGameWinner(String winnerName) {
    // ⚠️ IMPORTANT: En mode bot, pas de gains car pas de mise
    // En mode humains, afficher les gains (90% gagnant, 10% plateforme)
    // Si le gagnant est un bot remplaçant, 100% va à l'entreprise
    final bool isBotMode = _gameSession.playWithBots;
    final int minBet = (_gameSession.minimumBet as int?) ?? 0;

    // Vérifier si le gagnant est un bot remplaçant
    bool isReplacementBot = false;
    String? replacedPlayerName;
    for (final player in _gameSession.players) {
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
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
        // Afficher le dialog de continuation avec décompte
        _showContinueGameDialog();
      }
    });
  }

  // Variable pour gérer le choix de continuation
  bool? _continueGameChoice;
  Timer? _continueCountdownTimer;
  int _continueCountdown = 5;

  // Dialog pour demander si le joueur veut continuer
  void _showContinueGameDialog() {
    _continueGameChoice = null;
    _continueCountdown = 5;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Démarrer le décompte
            if (_continueCountdownTimer == null ||
                !_continueCountdownTimer!.isActive) {
              _continueCountdownTimer?.cancel();
              _continueCountdownTimer = Timer.periodic(
                const Duration(seconds: 1),
                (timer) {
                  if (_continueCountdown > 0) {
                    _continueCountdown--;
                    if (mounted) {
                      setDialogState(() {});
                    }
                  } else {
                    timer.cancel();
                    // Si pas de choix fait, considérer comme "Oui" et continuer automatiquement
                    if (_continueGameChoice == null) {
                      _continueGameChoice = true;
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
                    'dans $_continueCountdown seconde${_continueCountdown > 1 ? "s" : ""}',
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
                // Bouton Non - Quitter
                TextButton(
                  onPressed: () {
                    _continueGameChoice = false;
                    _continueCountdownTimer?.cancel();
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
                // Bouton Oui - Continuer
                TextButton(
                  onPressed: () {
                    _continueGameChoice = true;
                    _continueCountdownTimer?.cancel();
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

  // Gérer le choix de continuation
  Future<void> _navigateToUserDashboard() async {
    _continueCountdownTimer?.cancel();

    try {
      await GameWebSocketService().disconnect();
    } catch (_) {}

    _gameSession.isGameActive = false;
    _gameSession.isGameCompleted = true;

    String pseudo =
        UserService.instance.currentUserPseudo ?? widget.currentPlayerName;
    int balance = 1000;

    try {
      final profile = await UserApiService.instance.getProfile();
      if (profile['success'] == true) {
        final user = profile['user'];
        if (user is Map<String, dynamic>) {
          pseudo = user['pseudo']?.toString() ?? pseudo;
          balance = (user['cauris_balance'] as num?)?.toInt() ?? balance;
        }
      }
    } catch (e) {
      print('⚠️ Profil non rechargé avant retour dashboard: $e');
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => UserMenuPage(
          pseudo: pseudo,
          caurisBalance: balance,
        ),
      ),
      (_) => false,
    );
  }

  Future<void> _handleContinueGame(bool wantsToContinue) async {
    if (!wantsToContinue) {
      await _navigateToUserDashboard();
      return;
    }

    // ⚠️ IMPORTANT: En mode bot, redémarrer dans le même salon (pas de nouveau salon)
    if (_gameSession.playWithBots) {
      try {
        // Réinitialiser la session pour une nouvelle partie dans le même salon
        final playerNames = _gameSession.players
            .map((p) => p['name'] as String? ?? 'Joueur')
            .toList();

        if (mounted) {
          setState(() {
            // Réinitialiser les scores globaux à 0
            _gameSession.globalScores = List.filled(
              _gameSession.players.length,
              0.0,
            );
            _gameSession.roundsData = [];
            _gameSession.currentRound = 0;
            _gameSession.isGameActive = true;
            _gameSession.isGameCompleted = false;
            _gameSession.winnerName = null;
            _gameSession.winnerScore = null;
          });

          // Réinitialiser les compteurs d'annonces
          _cardManager.resetRoundCounters();

          // Redistribuer les cartes dans le même salon
          _cardManager.shuffleAndDealCards(playerNames);
          _gameLogic.configurePlayers(
            playerCount: playerNames.length,
            cardsPerPlayer: _cardManager.cardsPerPlayer,
          );
          _cardManager.isAnnouncementPhase = true;

          // Le premier joueur pour les annonces (créateur ou premier joueur)
          String firstPlayer = playerNames.first;
          final creator = _gameSession.players.firstWhere(
            (p) => (p['isCreator'] as bool?) == true,
            orElse: () => <String, Object>{},
          );
          if ((creator['name'] as String?) != null) {
            firstPlayer = creator['name'] as String;
          }
          _cardManager.currentPlayerTurn = firstPlayer;

          // Si c'est un bot qui commence, faire son annonce automatiquement
          if (firstPlayer != widget.currentPlayerName) {
            _handleAnnouncementTurnComplete();
          } else {
            setState(() {});
            _startAnnouncementTimerForCurrentPlayer();
          }
        }
      } catch (e) {
        print('❌ Erreur lors du redémarrage en mode bot: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
      return;
    }

    // Mode humains - créer automatiquement un nouveau salon
    try {
      final minBet = _gameSession.minimumBet ?? 100;
      final currentPlayerName = widget.currentPlayerName;

      // Créer un nouveau salon avec la même mise minimale
      final newRoomCode = await GameService.instance.createRoom(
        'Nouvelle Partie',
        minBet,
      );

      if (newRoomCode != null && mounted) {
        // Rejoindre le nouveau salon automatiquement
        final joined = await GameService.instance.joinRoom(newRoomCode);

        if (joined && !_gameSession.playWithBots) {
          // Mode humains - afficher le code
          if (mounted) {
                // Récupérer les joueurs actuels pour vérifier si on a déjà le quota requis
            final newRoomId = _gameSession.roomId ?? '';
            if (newRoomId.isNotEmpty) {
              try {
                final roomRes = await GameApiService.instance.getRoom(
                  roomId: newRoomId,
                );
                final data = (roomRes['data'] as Map?) ?? roomRes;
                final players =
                    (data['players'] as List?)?.cast<Map<String, dynamic>>() ??
                    [];

                // Normaliser les joueurs
                final othersPositions = ['right', 'top', 'left'];
                int idx = 0;
                final normalized = players.map((p) {
                  final pseudo = (p['pseudo'] ?? '').toString();
                  final first = (p['first_name'] ?? '').toString();
                  final last = (p['last_name'] ?? '').toString();
                  final isBot = (p['is_bot'] ?? false) == true;
                  final backendAvatar = (p['avatar'] ?? '').toString();
                  final isCreator =
                      ((p['is_creator'] ?? p['isCreator']) == true);
                  final name =
                      (pseudo.isNotEmpty
                              ? pseudo
                              : ([
                                  first,
                                  last,
                                ].where((s) => s.isNotEmpty).join(' ').trim()))
                          .trim();
                  final isCurrent =
                      name == currentPlayerName && currentPlayerName.isNotEmpty;
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

                setState(() {
                  _gameSession.players = normalized;
                  _gameSession.globalScores = List.filled(
                    normalized.length,
                    0.0,
                  );
                });

                // Afficher le code du nouveau salon
                _showNewRoomCodeDialog(newRoomCode);

                // ⚠️ IMPORTANT: Si on a déjà le quota de joueurs, ne pas démarrer le polling
                // Le dialog se fermera automatiquement et lancera le jeu
                if (normalized.length < _requiredPlayers) {
                  _startRoomPolling();
                }
              } catch (e) {
                print('❌ Erreur lors du chargement des joueurs: $e');
                _showNewRoomCodeDialog(newRoomCode);
                _startRoomPolling();
              }
            } else {
              _showNewRoomCodeDialog(newRoomCode);
              _startRoomPolling();
            }
          }
        }
      } else {
        // Erreur de création - retourner au menu
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur lors de la création du nouveau salon'),
              backgroundColor: Colors.red,
            ),
          );
          await _navigateToUserDashboard();
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la continuation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Timer pour vérifier le nombre de joueurs dans le dialog du code
  Timer? _roomCodeCheckTimer;

  // Afficher le code du nouveau salon
  void _showNewRoomCodeDialog(String roomCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Timer pour vérifier le nombre de joueurs toutes les secondes depuis le backend
            _roomCodeCheckTimer?.cancel();
            _roomCodeCheckTimer = Timer.periodic(const Duration(seconds: 1), (
              timer,
            ) async {
              if (!mounted) {
                timer.cancel();
                return;
              }

              try {
                // Vérifier le nombre de joueurs depuis le backend
                final roomId = _gameSession.roomId ?? '';
                if (roomId.isNotEmpty) {
                  final res = await GameApiService.instance.getRoom(
                    roomId: roomId,
                  );
                  final data = (res['data'] as Map?) ?? res;
                  final players =
                      (data['players'] as List?)
                          ?.cast<Map<String, dynamic>>() ??
                      [];

                  final currentPlayerCount = players.length;
                  final hasFullRoom = currentPlayerCount >= _requiredPlayers;

                  // Mettre à jour la liste des joueurs dans la session
                  if (mounted) {
                    setState(() {
                      // Normaliser les joueurs pour mettre à jour l'affichage
                      final othersPositions = ['right', 'top', 'left'];
                      int idx = 0;
                      final currentPlayerName = widget.currentPlayerName;
                      final normalized = players.map((p) {
                        final pseudo = (p['pseudo'] ?? '').toString();
                        final first = (p['first_name'] ?? '').toString();
                        final last = (p['last_name'] ?? '').toString();
                        final isBot = (p['is_bot'] ?? false) == true;
                        final backendAvatar = (p['avatar'] ?? '').toString();
                        final isCreator =
                            ((p['is_creator'] ?? p['isCreator']) == true);
                        final name =
                            (pseudo.isNotEmpty
                                    ? pseudo
                                    : ([first, last]
                                          .where((s) => s.isNotEmpty)
                                          .join(' ')
                                          .trim()))
                                .trim();
                        final isCurrent =
                            name == currentPlayerName &&
                            currentPlayerName.isNotEmpty;
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

                      _gameSession.players = normalized;
                      _gameSession.globalScores = List.filled(
                        normalized.length,
                        0.0,
                      );
                    });
                  }

                  // Si on a le quota de joueurs, fermer le dialog et démarrer le jeu
                  if (hasFullRoom && !_gameSession.playWithBots) {
                    timer.cancel();
                    _roomCodeCheckTimer = null;
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted && Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                        // Démarrer la distribution des cartes
                        _startCardDistribution();
                      }
                    });
                  } else {
                    // Mettre à jour l'affichage pour montrer le nombre actuel de joueurs
                    if (mounted) {
                      setDialogState(() {});
                    }
                  }
                }
              } catch (e) {
                print('❌ Erreur lors de la vérification des joueurs: $e');
                // Continuer avec le nombre actuel de joueurs dans la session
                final currentPlayerCount = _gameSession.players.length;
                if (mounted) {
                  setDialogState(() {});
                }
              }
            });

            final currentPlayerCount = _gameSession.players.length;
            final hasFullRoom = currentPlayerCount >= _requiredPlayers;

            return AlertDialog(
              backgroundColor: const Color(0xFF2E2B23),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Nouveau salon créé !',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Partagez ce code avec les autres joueurs :',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.yellow, width: 2),
                    ),
                    child: Text(
                      roomCode,
                      style: const TextStyle(
                        color: Colors.yellow,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ⚠️ IMPORTANT: N'afficher "En attente..." que si on n'a PAS le quota
                  if (!_gameSession.playWithBots && !hasFullRoom)
                    Text(
                      'En attente des autres joueurs... (${currentPlayerCount}/$_requiredPlayers)'
                      '${GameConstants.isDevelopment && !_gameSession.playWithBots ? ' • Mode développement (2 joueurs)' : ''}',
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  // Si on a le quota, afficher que le jeu va démarrer
                  if (!_gameSession.playWithBots && hasFullRoom)
                    const Text(
                      'Tous les joueurs requis sont présents ! Le jeu va démarrer...',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _roomCodeCheckTimer?.cancel();
                    _roomCodeCheckTimer = null;
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Nettoyer le timer quand le dialog se ferme
      _roomCodeCheckTimer?.cancel();
      _roomCodeCheckTimer = null;
    });
  }

  void _showScoreboardDialog(
    List<String> players,
    Map<String, int> announced,
    Map<String, int> obtained,
    Map<String, int> scores,
  ) {
    // Somme = total des annonces (règle demandée)
    final int sommeAnnonces = players.fold(
      0,
      (sum, p) => sum + (announced[p] ?? 0),
    );

    // Infos salon (fallbacks si absent)
    final String roomName = (_gameSession.roomName as String?) ?? 'Salon';
    final String roomCode = (_gameSession.roomCode as String?) ?? '-----';
    final int minBet = (_gameSession.minimumBet as int?) ?? 0;

    // Timer pour la fermeture automatique (sera annulé si l'utilisateur ferme manuellement)
    Timer? autoCloseTimer;

    showDialog(
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
                  ..._gameSession.roundsData.take(10).map((round) {
                    final rNum = round['roundNumber'] as int;
                    final rAnnouncements =
                        (round['announcements'] as List<int>);
                    final rResults = (round['results'] as List<double?>);
                    final isCompleted = round['isCompleted'] as bool;
                    final somme = rAnnouncements.fold<int>(0, (s, a) => s + a);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
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
                                  color: isCompleted
                                      ? Colors.white
                                      : Colors.yellow,
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
                  // Ligne SG (score global cumulé)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
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
                              (_gameSession.globalScores[i]).toStringAsFixed(1),
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
                            // Somme colonne: total des annonces du DERNIER round
                            (_gameSession.roundsData.isNotEmpty
                                    ? (_gameSession
                                                  .roundsData
                                                  .last['announcements']
                                              as List<int>)
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

                  const SizedBox(height: 16),
                  // Carte infos salon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4B4941),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            roomName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Code: ' + roomCode,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Mise minimum: ' + minBet.toString() + ' cauris',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Annuler le timer de fermeture automatique
                autoCloseTimer?.cancel();
                // Fermer uniquement le dialog et revenir à la partie
                Navigator.of(context).pop();
              },
              child: const Text(
                'Fermer',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      // Annuler le timer si le dialog est fermé manuellement
      autoCloseTimer?.cancel();
    });

    // ⚠️ IMPORTANT: Fermer automatiquement le tableau des scores après 3 secondes
    autoCloseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    });
  }

  void _showLowTotalMessage() {
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

  void _showNewBidsMessage() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF8B4513),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Nouvelles Annonces',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Le total des annonces est inférieur ou égal à 8.\nNouvelles annonces avec les mêmes cartes...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        );
      },
    );

    // Fermer le dialog après 3 secondes
    Future.delayed(const Duration(seconds: 3), () {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  void _restartAnnouncements() {
    // Effacer les annonces précédentes
    _cardManager.clearCurrentRoundAnnouncements();

    // Remettre le tour au créateur
    _cardManager.currentPlayerTurn =
        _gameSession.players.first['name'] as String;
    // Revenir en phase d'annonces pour afficher 0/0 puis 0/X
    _cardManager.isAnnouncementPhase = true;

    // Réinitialiser l'état d'annonce pour tous les joueurs
    _hasAnnounced = false;
    // Démarrer le timer pour les nouvelles annonces (30s par joueur)
    _startAnnouncementTimerForCurrentPlayer();

    setState(() {
      // Mettre à jour l'interface
    });
  }

  void _undoAction() {
    // Action annulée
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
                  // Tableau de score avec rondes
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[600]!, width: 1),
                    ),
                    child: Column(
                      children: [
                        // En-tête du tableau
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
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
                              // Génération dynamique des noms des joueurs selon l'ordre d'arrivée
                              ..._gameSession.players.map((player) {
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

                        // Génération dynamique des rondes depuis la session
                        ..._gameSession.roundsData.map((round) {
                          final roundLabel = 'R${round['roundNumber']}';
                          final announcements =
                              round['announcements'] as List<int>;
                          final results = round['results'] as List<dynamic>;
                          final isCompleted = round['isCompleted'] as bool;

                          // Afficher les annonces si le round n'est pas terminé, sinon les résultats
                          final displayData = isCompleted
                              ? results
                              : announcements;

                          // Convertir les données en strings
                          final scoreStrings = displayData.map((score) {
                            if (score == null) return '—';
                            return score.toString();
                          }).toList();

                          // Calculer la somme des données non-null
                          final sum = displayData
                              .where((score) => score != null)
                              .fold<double>(0.0, (sum, score) {
                                if (score is double) return sum + score;
                                if (score is int) return sum + score.toDouble();
                                return sum;
                              });
                          scoreStrings.add(sum.toString());

                          return _buildScoreRow(
                            roundLabel,
                            scoreStrings,
                            isCompleted,
                          );
                        }).toList(),

                        // Ligne Score global (SG) - dynamique depuis la session
                        _buildScoreRow('Score global (SG)', [
                          ..._gameSession.globalScores.map(
                            (score) => score.toString(),
                          ),
                          _gameSession.globalScores
                              .fold(0.0, (sum, score) => sum + score)
                              .toString(),
                        ], true),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Informations du salon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _gameSession.roomName ?? 'Salon',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Code: ${_gameSession.roomCode ?? 'N/A'}',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mise minimum: ${_gameSession.minimumBet ?? 50} cauris',
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
                // Fermer uniquement le dialog et revenir à la partie (ne pas quitter le salon)
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

  Widget _buildScoreRow(
    String rowLabel,
    List<String> scores,
    bool isCompleted,
  ) {
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
              rowLabel,
              style: TextStyle(
                color: Colors.yellow,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.left,
            ),
          ),
          // Génération dynamique des colonnes de scores
          ...scores.asMap().entries.map((entry) {
            final index = entry.key;
            final score = entry.value;

            // Vérifier si l'index correspond à un joueur ou à la colonne "Somme"
            Color textColor = Colors.white;
            if (index < _gameSession.players.length) {
              final player = _gameSession.players[index];
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
  }

  // Fonction pour ajouter une nouvelle ronde avec annonces
  void _addNewRound(List<int> announcements) {
    setState(() {
      _gameSession.addRound(announcements);
    });
  }

  // Fonction pour finaliser un round avec les résultats
  void _finalizeRound(int roundIndex, List<int> obtainedTricks) {
    setState(() {
      _gameSession.finalizeRound(roundIndex, obtainedTricks);

      // Sauvegarder en base de données si la partie est terminée
      if (_gameSession.isGameCompleted) {
        _gameSession.saveToDatabase();
      }
    });
  }

  // Fonction pour vérifier la fin de partie
  void _checkGameEnd() {
    if (_gameSession.isGameCompleted) {
      _showGameEndDialog(_gameSession.winnerName!);
    }
  }

  // Fonction pour afficher le dialog de fin de partie
  void _showGameEndDialog(String winnerName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '🎉 Partie Terminée !',
            style: TextStyle(
              color: Colors.yellow,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$winnerName a gagné !',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Score final: ${_gameSession.winnerScore} points',
                style: TextStyle(color: Colors.grey[300], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Retour au menu principal
              },
              child: const Text(
                'Retour au menu',
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

  void _pauseGame() {
    // Jeu mis en pause
  }

  void _leaveRoom() {
    // Afficher le dialog de confirmation avant de quitter
    _showLeaveGameConfirmation();
  }

  // Afficher un dialog de confirmation avant de quitter le jeu
  void _showLeaveGameConfirmation() {
    // En mode bot, pas de mise donc pas besoin d'avertir
    final bool isBotMode = _gameSession.playWithBots;
    final int minBet = (_gameSession.minimumBet as int?) ?? 0;

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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isBotMode && minBet > 0) ...[
                Text(
                  'Si vous quittez le jeu maintenant, votre mise sera perdue.',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Text(
                  'Mise perdue: $minBet cauris',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Un bot vous remplacera automatiquement pour permettre au jeu de continuer.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ] else ...[
                const Text(
                  'Si vous quittez le jeu maintenant, un bot vous remplacera automatiquement.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ],
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

  // Confirmer le départ et remplacer le joueur par un bot (départ définitif)
  Future<void> _confirmLeaveGame() async {
    try {
      final playerName = widget.currentPlayerName;

      // Marquer comme exclu définitivement
      _permanentlyExcludedPlayers.add(playerName);

      // Remplacer le joueur par un bot (départ définitif)
      await _replacePlayerWithBot(playerName, isPermanent: true);

      // Si le joueur avait un remplacement temporaire, le rendre permanent
      if (_temporaryReplacements.containsKey(playerName)) {
        _temporaryReplacements[playerName]!['isPermanent'] = true;
      }

      // Quitter la page
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('❌ Erreur lors du remplacement par un bot: $e');
      // Quitter quand même même en cas d'erreur
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  // Remplacer un joueur humain par un bot
  // isPermanent: true si départ manuel ou déconnexion > 15s, false si déconnexion temporaire
  Future<void> _replacePlayerWithBot(
    String playerName, {
    bool isPermanent = true,
  }) async {
    try {
      final roomId = _gameSession.roomId ?? '';
      if (roomId.isEmpty) {
        print('⚠️ RoomId vide, impossible de remplacer le joueur');
        return;
      }

      // Mettre à jour la liste des joueurs pour marquer ce joueur comme remplacé par un bot
      // Chercher le joueur dans la liste et le remplacer par un bot
      final players = _gameSession.players;
      final playerIndex = players.indexWhere(
        (p) => (p['name'] as String?) == playerName,
      );

      if (playerIndex != -1) {
        final player = players[playerIndex];

        // Créer un nom de bot pour le remplaçant (ex: "Bot_Remplaceur_[NomJoueur]")
        final botName = 'Bot_Remplaceur_${playerName}';

        // ⚠️ IMPORTANT: Sauvegarder l'index AVANT de modifier la liste
        // Cet index sera utilisé pour transférer toutes les statistiques

        // Récupérer les cartes du joueur si elles existent
        final playerCards = _cardManager.getPlayerCards(playerName);

        // Remplacer le joueur par un bot dans la session
        setState(() {
          players[playerIndex] = {
            ...player,
            'name': botName,
            'avatar': '🤖',
            'is_bot': true,
            'isReplacementBot': true, // Marquer comme bot remplaçant
            'replacedPlayerName': playerName, // Nom du joueur remplacé
          };
        });

        // Transférer les cartes du joueur au bot
        if (playerCards.isNotEmpty) {
          // Transférer les cartes : les assigner au bot et retirer de l'ancien joueur
          _cardManager.transferPlayerCards(playerName, botName);
        }

        // Transférer les annonces du joueur au bot si elles existent
        final announcements = _cardManager.getCurrentRoundAnnouncements();
        final playerAnnouncement = announcements.firstWhere(
          (ann) => (ann['player'] as String?) == playerName,
          orElse: () => <String, Object>{},
        );
        if ((playerAnnouncement['announcement'] as int?) != null) {
          // Mettre à jour l'annonce avec le nom du bot
          playerAnnouncement['player'] = botName;
          print(
            '📢 Annonce transférée de $playerName à $botName: ${playerAnnouncement['announcement']} plis',
          );
        }

        // ⚠️ IMPORTANT: Transférer TOUTES les statistiques du joueur au bot
        // 1. Transférer les plis gagnés dans le round en cours
        _cardManager.transferObtainedTricks(playerName, botName);

        // 2. Mettre à jour le nom dans le pli en cours (si le joueur a déjà joué)
        _cardManager.updatePlayerNameInCurrentTrick(playerName, botName);

        // 3. Transférer les scores globaux (SG) du joueur au bot
        // IMPORTANT: Le bot remplace le joueur au même index (playerIndex)
        // Donc pas besoin de chercher botIndex, c'est le même index
        if (playerIndex != -1 &&
            playerIndex < _gameSession.globalScores.length) {
          final playerScore = _gameSession.globalScores[playerIndex];
          // Le score reste au même index, juste le nom du joueur a changé
          // Le score est déjà attribué au bot car il est au même index
          print(
            '💰 Score global conservé pour le bot $botName (même index $playerIndex): $playerScore',
          );
        }

        // 4. Mettre à jour roundsData pour remplacer le nom du joueur par celui du bot
        // Dans chaque round, les statistiques restent au même index (playerIndex)
        // car le bot remplace le joueur au même emplacement dans la liste
        for (var round in _gameSession.roundsData) {
          // Les plis obtenus sont déjà au bon index (playerIndex)
          // Les résultats (scores) sont déjà au bon index (playerIndex)
          // Pas besoin de transférer, tout reste au même index
          print(
            '📊 Statistiques du round conservées au même index $playerIndex pour le bot $botName',
          );
        }

        // 5. Mettre à jour les plis gagnés par le joueur dans les rounds passés
        // (déjà fait via roundsData['obtainedTricks'])

        // Si c'est le tour de ce joueur, donner la main au bot
        if (_cardManager.currentPlayerTurn == playerName) {
          _cardManager.currentPlayerTurn = botName;
        }

        // Si c'est la phase d'annonces et que le joueur remplacé était en attente d'annoncer
        // Le bot fera automatiquement son annonce via _maybeAutoPlayCurrentBot
        if (_cardManager.isAnnouncementPhase &&
            _cardManager.currentPlayerTurn == botName) {
          // Le bot fera automatiquement son annonce
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              final botAnnouncement = _cardManager.getBotAnnouncement(botName);
              _cardManager.makeAnnouncement(botName, botAnnouncement);
              _handleAnnouncementTurnComplete();
            }
          });
        }

        print('✅ Joueur $playerName remplacé par le bot $botName');

        // ⚠️ IMPORTANT: Notifier le backend du remplacement
        try {
          await GameApiService.instance.replacePlayerWithBot(
            roomId: roomId,
            playerName: playerName,
            botName: botName,
            isPermanent: isPermanent,
          );
          print('📡 Backend notifié du remplacement: $playerName → $botName');
        } catch (e) {
          print(
            '⚠️ Erreur notification backend (remplacement continuera côté client): $e',
          );
        }

        setState(() {});
      }
    } catch (e, stackTrace) {
      print('❌ Erreur lors du remplacement du joueur par un bot: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // Détecter les déconnexions et remplacer automatiquement (temporaire pendant 15 secondes)
  Future<void> _handlePlayerDisconnection(String playerName) async {
    // ✅ Vérifier si la partie a commencé (currentRound > 0 signifie que la partie a commencé)
    final hasGameStarted = _gameSession.currentRound > 0 || 
                          _cardManager.isAnnouncementPhase ||
                          _cardManager.getPlayerCards(playerName).isNotEmpty;
    
    // Si le joueur déconnecté n'est pas le joueur actuel, créer un remplacement temporaire
    if (playerName != widget.currentPlayerName) {
      // Si la partie n'a pas encore commencé, permettre la reconnexion sans limite de temps
      if (!hasGameStarted) {
        print('📡 Partie non commencée: $playerName peut se reconnecter à tout moment');
        // Créer un remplacement temporaire (isPermanent = false, pas de timer)
        final botName = 'Bot_Remplaceur_${playerName}';
        _temporaryReplacements[playerName] = {
          'botName': botName,
          'timestamp': DateTime.now(),
          'isPermanent': false,
          'canReconnect': true, // Permettre la reconnexion même après 15 secondes
        };

        // Notifier le backend de la déconnexion
        final roomId = _gameSession.roomId ?? '';
        if (roomId.isNotEmpty) {
          try {
            await GameApiService.instance.notifyPlayerDisconnection(
              roomId: roomId,
              playerName: playerName,
            );
            print('📡 Backend notifié de la déconnexion: $playerName');
          } catch (e) {
            print('⚠️ Erreur notification backend déconnexion: $e');
          }
        }

        // Remplacer temporairement par un bot
        _replacePlayerWithBot(playerName, isPermanent: false);
        // Pas de timer si la partie n'a pas commencé
      } else {
        // Partie commencée - logique normale avec timer de 15 secondes
        final botName = 'Bot_Remplaceur_${playerName}';
        _temporaryReplacements[playerName] = {
          'botName': botName,
          'timestamp': DateTime.now(),
          'isPermanent': false,
          'canReconnect': false,
        };

        // Notifier le backend de la déconnexion
        final roomId = _gameSession.roomId ?? '';
        if (roomId.isNotEmpty) {
          try {
            await GameApiService.instance.notifyPlayerDisconnection(
              roomId: roomId,
              playerName: playerName,
            );
            print('📡 Backend notifié de la déconnexion: $playerName');
          } catch (e) {
            print('⚠️ Erreur notification backend déconnexion: $e');
          }
        }

        // Remplacer temporairement par un bot
        _replacePlayerWithBot(playerName, isPermanent: false);

        // Lancer un timer de 15 secondes
        _reconnectionCheckTimer?.cancel();
        _reconnectionCheckTimer = Timer(const Duration(seconds: 15), () {
          // Après 15 secondes, si le joueur ne s'est pas reconnecté, rendre le remplacement permanent
          if (_temporaryReplacements.containsKey(playerName)) {
            final replacementInfo = _temporaryReplacements[playerName]!;
            if (!(replacementInfo['isPermanent'] as bool? ?? false)) {
              // Rendre permanent
              replacementInfo['isPermanent'] = true;
              _permanentlyExcludedPlayers.add(playerName);
              print(
                '⏰ Remplacement rendu permanent pour $playerName après 15 secondes',
              );
            }
          }
        });
      }
    } else {
      // Le joueur actuel se déconnecte
      // Marquer comme exclu définitivement
      _permanentlyExcludedPlayers.add(playerName);
    }
  }

  // Gérer la reconnexion d'un joueur
  Future<void> _handlePlayerReconnection(String playerName) async {
    // Vérifier si le joueur a un remplacement temporaire
    if (_temporaryReplacements.containsKey(playerName)) {
      final replacementInfo = _temporaryReplacements[playerName]!;
      final isPermanent = (replacementInfo['isPermanent'] as bool?) ?? false;
      final canReconnect = (replacementInfo['canReconnect'] as bool?) ?? false;

      // ✅ Permettre la reconnexion si :
      // 1. Le remplacement n'est pas permanent ET
      // 2. (La partie n'a pas commencé OU canReconnect est true)
      if (!isPermanent && canReconnect) {
        // Reconnexion autorisée - restaurer le joueur
        _reconnectionCheckTimer?.cancel();

        // Notifier le backend de la reconnexion
        final roomId = _gameSession.roomId ?? '';
        if (roomId.isNotEmpty) {
          try {
            await GameApiService.instance.notifyPlayerReconnection(
              roomId: roomId,
              playerName: playerName,
            );
            print('📡 Backend notifié de la reconnexion: $playerName');
          } catch (e) {
            print('⚠️ Erreur notification backend reconnexion: $e');
          }
        }

        _restorePlayer(playerName);
        _temporaryReplacements.remove(playerName);
        print('✅ Joueur $playerName restauré après reconnexion');
      } else if (!isPermanent) {
        // Reconnexion dans les 15 secondes - restaurer le joueur
        _reconnectionCheckTimer?.cancel();

        // Notifier le backend de la reconnexion
        final roomId = _gameSession.roomId ?? '';
        if (roomId.isNotEmpty) {
          try {
            await GameApiService.instance.notifyPlayerReconnection(
              roomId: roomId,
              playerName: playerName,
            );
            print('📡 Backend notifié de la reconnexion: $playerName');
          } catch (e) {
            print('⚠️ Erreur notification backend reconnexion: $e');
          }
        }

        _restorePlayer(playerName);
        _temporaryReplacements.remove(playerName);
        print('✅ Joueur $playerName restauré après reconnexion rapide');
      } else {
        // Reconnexion après 15 secondes - joueur exclu
        print(
          '❌ Joueur $playerName exclu définitivement (reconnexion après 15 secondes)',
        );
      }
    }
  }

  // Restaurer un joueur (annuler le remplacement temporaire)
  Future<void> _restorePlayer(String playerName) async {
    try {
      final players = _gameSession.players;
      final replacementInfo = _temporaryReplacements[playerName];
      if (replacementInfo == null) return;

      final botName = replacementInfo['botName'] as String;

      // Trouver le bot remplaçant
      final botIndex = players.indexWhere(
        (p) => (p['name'] as String?) == botName,
      );
      if (botIndex == -1) return;

      // ⚠️ IMPORTANT: Notifier le backend de la restauration
      final roomId = _gameSession.roomId ?? '';
      if (roomId.isNotEmpty) {
        try {
          await GameApiService.instance.restorePlayer(
            roomId: roomId,
            playerName: playerName,
            botName: botName,
          );
          print('📡 Backend notifié de la restauration: $playerName');
        } catch (e) {
          print('⚠️ Erreur notification backend restauration: $e');
        }
      }

      // Restaurer le joueur original
      setState(() {
        // Restaurer le nom du joueur
        final originalPlayer = players[botIndex];
        players[botIndex] = {
          ...originalPlayer,
          'name': playerName,
          'avatar': '👤',
          'is_bot': false,
          'isReplacementBot': false,
          'replacedPlayerName': null,
        };
      });

      // Transférer les cartes du bot au joueur
      final botCards = _cardManager.getPlayerCards(botName);
      if (botCards.isNotEmpty) {
        _cardManager.transferPlayerCards(botName, playerName);
      }

      // Restaurer les plis gagnés (bot -> joueur)
      _cardManager.transferObtainedTricks(botName, playerName);

      // Restaurer le tour si nécessaire
      if (_cardManager.currentPlayerTurn == botName) {
        _cardManager.currentPlayerTurn = playerName;
      }

      // Mettre à jour les annonces
      final announcements = _cardManager.getCurrentRoundAnnouncements();
      for (var ann in announcements) {
        if ((ann['player'] as String?) == botName) {
          ann['player'] = playerName;
        }
      }

      print('✅ Joueur $playerName restauré, bot $botName retiré');
      setState(() {});
    } catch (e, stackTrace) {
      print('❌ Erreur lors de la restauration du joueur: $e');
      print('Stack trace: $stackTrace');
    }
  }
}
