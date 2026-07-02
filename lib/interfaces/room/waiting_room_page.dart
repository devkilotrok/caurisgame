import 'package:flutter/material.dart';
import 'dart:async';
import '../game/game_room_router.dart';
import '../../services/user/user_service.dart';
import '../../services/game/game_service.dart';
import '../../services/api/game_api_service.dart';
import '../../config/game_constants.dart';

class WaitingRoomPage extends StatefulWidget {
  final String roomName;
  final String roomCode;
  final int minimumBet;

  const WaitingRoomPage({
    super.key,
    required this.roomName,
    required this.roomCode,
    required this.minimumBet,
  });

  @override
  State<WaitingRoomPage> createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends State<WaitingRoomPage> {
  int _currentPlayerCount = 0;
  Timer? _checkTimer;
  bool _isLoading = true;
  String? _errorMessage;

  int get _requiredPlayerCount => GameConstants.requiredPlayerCount(
        playWithBots: GameService.instance.gameSession.playWithBots,
      );

  @override
  void initState() {
    super.initState();
    _checkPlayersCount();
    // Vérifier toutes les 2 secondes
    _checkTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkPlayersCount();
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPlayersCount() async {
    try {
      final session = GameService.instance.gameSession;
      final roomId = session.roomId ?? '';
      
      if (roomId.isEmpty) {
        setState(() {
          _errorMessage = 'Erreur: Salon introuvable';
          _isLoading = false;
        });
        return;
      }

      // Récupérer les informations du salon depuis l'API
      final res = await GameApiService.instance.getRoom(roomId: roomId);
      final data = (res['data'] as Map?) ?? res;
      final players = (data['players'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      
      setState(() {
        _currentPlayerCount = players.length;
        _isLoading = false;
        _errorMessage = null;
      });

      // Si on a le quota de joueurs, naviguer vers le salon
      if (_currentPlayerCount >= _requiredPlayerCount) {
        _checkTimer?.cancel();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => GameRoomRouter.buildGameRoomPage(
                roomName: widget.roomName,
                roomCode: widget.roomCode,
                minimumBet: widget.minimumBet,
                currentPlayerName: UserService.instance.currentUserPseudo ?? 'Vous',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erreur lors de la vérification: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () {
            _checkTimer?.cancel();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'En attente...',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icône d'attente
              Icon(
                Icons.hourglass_empty,
                size: 80,
                color: isDark ? Colors.orange : Colors.orange.shade700,
              ),
              
              const SizedBox(height: 32),
              
              // Titre
              Text(
                'En attente des joueurs',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Informations du salon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF404040) : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.roomName,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Code: ${widget.roomCode}',
                      style: TextStyle(
                        color: isDark ? Colors.grey : Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mise minimum: ${widget.minimumBet} cauris',
                      style: TextStyle(
                        color: isDark ? Colors.grey : Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Compteur de joueurs
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                )
              else ...[
                // Cercle avec le nombre de joueurs
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                    border: Border.all(
                      color: const Color(0xFFFFD700),
                      width: 4,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_currentPlayerCount',
                          style: TextStyle(
                            color: const Color(0xFFFFD700),
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '/ $_requiredPlayerCount',
                          style: TextStyle(
                            color: isDark ? Colors.grey : Colors.grey.shade600,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Message
                Text(
                  '$_currentPlayerCount joueur${_currentPlayerCount > 1 ? 's' : ''} ${_currentPlayerCount > 1 ? 'ont' : 'a'} rejoint',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'En attente que les $_requiredPlayerCount joueurs rejoignent'
                  '${GameConstants.allowTwoHumanWithBotsTest && _requiredPlayerCount == GameConstants.temporaryHumanPlayerCount ? ' (test : 2 humains + 2 bots)' : ''}',
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              const SizedBox(height: 48),
              
              // Indicateur de chargement
              if (!_isLoading && _errorMessage == null)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

