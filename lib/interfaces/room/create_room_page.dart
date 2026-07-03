import 'package:flutter/material.dart';
import '../game/game_room_router.dart';
import 'waiting_room_page.dart';
import '../../models/room/room_manager.dart';
import '../../services/user/user_service.dart';
import '../../services/game/game_service.dart';
import '../../services/api/game_api_service.dart';
import '../../services/api/payment_api_service.dart';

class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({super.key});

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  int _minimumBet = 10;
  final TextEditingController _betController = TextEditingController();
  
  // Simulation du nombre de salles existantes (dans une vraie app, ceci viendrait de la base de données)
  static int _existingRoomsCount = 0;

  @override
  void initState() {
    super.initState();
    _betController.text = _minimumBet.toString();
  }

  @override
  void dispose() {
    _betController.dispose();
    super.dispose();
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Créer un Salon',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre principal avec type de jeu
            _buildTitle(),
            
            const SizedBox(height: 24),
            
            // Informations utilisateur
            _buildUserInfo(),
            
            const SizedBox(height: 24),
            
            // Configuration du salon
            _buildRoomConfiguration(),
            
            const SizedBox(height: 24),
            
            // Informations du jeu
            _buildGameInfo(),
            
            const SizedBox(height: 24),
            
            // Règles du Callbreak
            _buildCallbreakRules(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Créer un Salon',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Callbreak (Pique)',
          style: TextStyle(
            color: const Color(0xFF228B22), // Vert
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF404040) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFF228B22), // Vert
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (UserService.instance.currentUserPseudo ?? 'U')[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Informations utilisateur
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  UserService.instance.currentUserPseudo ?? 'User',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<int>(
                  valueListenable: UserService.instance.caurisBalance,
                  builder: (context, balance, child) {
                    return Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet,
                          color: Color(0xFFFFD700), // Jaune doré
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$balance Cauris',
                          style: const TextStyle(
                            color: Color(0xFFFFD700), // Jaune doré
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomConfiguration() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF404040) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.settings,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Configuration du Salon',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          Text(
            'Mise Minimum (Cauris)',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Champ de saisie pour la mise
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF404040) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF228B22), // Vert
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _betController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '10',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _minimumBet = int.tryParse(value) ?? 10;
                        });
                      },
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Text(
                    'Cauris',
                    style: TextStyle(
                      color: Color(0xFF228B22), // Vert
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'Montant minimum que chaque joueur doit miser pour participer',
            style: TextStyle(
              color: isDark ? Colors.grey : Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Boutons d'action
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _showInviteFriendsDialog();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF228B22),
                    side: const BorderSide(color: Color(0xFF228B22)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Inviter des Amis',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _createRoom();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF228B22), // Vert
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Créer le Salon',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF404040) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sports_esports,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Informations du Jeu',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Grille 2x2 des informations
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.people,
                  iconColor: Colors.blue,
                  title: 'Joueurs',
                  value: '4 maximum',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.diamond,
                  iconColor: Colors.grey,
                  title: 'Type',
                  value: 'Callbreak (Pique)',
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.timer,
                  iconColor: Colors.grey,
                  title: 'Durée',
                  value: '10 manches max',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.emoji_events,
                  iconColor: const Color(0xFFFFD700), // Jaune doré
                  title: 'Objectif',
                  value: 'Marquer des points',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF404040) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF555555) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF228B22), // Vert
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallbreakRules() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF404040) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.rule,
                color: Colors.brown,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Règles du Callbreak',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildRuleItem('Chaque joueur reçoit 13 cartes'),
          _buildRuleItem('Le joueur qui distribue choisit l\'atout'),
          _buildRuleItem('Les joueurs annoncent leurs plis'),
          _buildRuleItem('Le joueur avec le plus de points gagne'),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 16,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _createRoom() async {
    // Afficher un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Incrémenter le compteur de salles et générer le nom
      _existingRoomsCount++;
      final String roomName = 'Room ${_formatRoomNumber(_existingRoomsCount)}';
      
      // Récupérer le pseudo de l'utilisateur connecté
      final userPseudo = UserService.instance.currentUserPseudo ?? 'User';
      
      // Créer le salon via l'API (backend) - plus de fallback local
      final roomCode = await GameService.instance.createRoom(roomName, _minimumBet);

      // Fermer le dialog de chargement
      Navigator.pop(context);

      if (roomCode != null && roomCode.isNotEmpty) {
        // Utiliser le nom renvoyé par le backend depuis GameSession
        final backendRoomName = GameService.instance.gameSession.roomName ?? roomName;
        _showRoomCreatedDialog(roomCode, backendRoomName);
      } else {
        _showErrorDialog('Erreur lors de la création du salon');
      }
    } catch (e) {
      // Fermer le dialog de chargement
      Navigator.pop(context);
      _showErrorDialog('Erreur de connexion: ${e.toString()}');
    }
  }

  void _showRoomCreatedDialog(String roomCode, String roomName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Titre
                Text(
                  'Salon Créé !',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Message de confirmation
                Text(
                  'Salon "$roomName" créé avec succès !',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 6),
                
                Text(
                  'Code: $roomCode',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Boutons d'action
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _copyRoomCode(roomCode);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF228B22),
                          side: const BorderSide(color: Color(0xFF228B22)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text(
                          'Copier',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _shareRoomCode(roomCode, roomName);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF228B22),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text(
                          'Partager',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Choix de jeu
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final roomId = GameService.instance.gameSession.roomId ?? '';
                          if (roomId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Salon introuvable'), backgroundColor: Colors.red),
                            );
                            return;
                          }
                          try {
                            GameService.instance.gameSession.playWithBots = true;
                            // ✅ Mettre la mise à zéro pour le mode bot
                            GameService.instance.gameSession.minimumBet = 0;
                            await GameApiService.instance.fillBots(roomId: roomId);
                            // Charger la liste des joueurs depuis le backend et mettre à jour la session
                            final roomRes = await GameApiService.instance.getRoom(roomId: roomId);
                            final data = (roomRes['data'] as Map?) ?? roomRes;
                            final players = (data['players'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                            // Normaliser pour GameSession: champs attendus par l'UI
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
                                  : ([first, last].where((s) => s.isNotEmpty).join(' ').trim())).trim();
                              final isCurrent = name == currentName && currentName.isNotEmpty;
                              final displayPos = isCurrent ? 'bottom' : othersPositions[(idx++) % othersPositions.length];
                              return {
                                'name': name.isNotEmpty ? name : 'Joueur',
                                'displayPosition': displayPos,
                                'avatar': backendAvatar.isNotEmpty ? backendAvatar : (isBot ? '🤖' : '👤'),
                                'isCurrentPlayer': isCurrent,
                                'isCreator': isCreator,
                                'score': '0/0',
                                'cards': 13,
                              };
                            }).toList();
                            GameService.instance.gameSession.players = normalized;
                            GameService.instance.gameSession.globalScores = List.filled(normalized.length, 0.0);
                          } catch (_) {}
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GameRoomRouter.buildGameRoomPage(
                                  roomName: roomName,
                                  roomCode: roomCode,
                                  minimumBet: 0, // ✅ Mise à zéro pour le mode bot
                                  currentPlayerName: UserService.instance.currentUserPseudo ?? 'User',
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF228B22),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'JOUER AVEC DES BOTS',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          GameService.instance.gameSession.playWithBots = false;
                          // Débit automatique de la mise minimale pour le créateur
                          final roomIdStr = GameService.instance.gameSession.roomId ?? '';
                          final roomId = int.tryParse(roomIdStr) ?? 0;
                          if (roomId == 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Salon introuvable'), backgroundColor: Colors.red),
                            );
                            return;
                          }
                          // Vérifier le solde
                          final chk = await PaymentApiService.instance.checkBalance(requiredAmount: _minimumBet);
                          if (chk['success'] != true || chk['hasEnough'] != true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Solde insuffisant pour la mise minimale'), backgroundColor: Colors.red),
                            );
                            return;
                          }
                          final debit = await PaymentApiService.instance.debitRoomBet(amount: _minimumBet, roomId: roomId);
                          if (debit['success'] != true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(debit['message'] ?? 'Débit échoué'), backgroundColor: Colors.red),
                            );
                            return;
                          }
                          if (!mounted) return;
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                          // En mode humain, naviguer vers la page d'attente
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WaitingRoomPage(
                                roomName: roomName,
                                roomCode: roomCode,
                                minimumBet: _minimumBet,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'JOUER AVEC DES HUMAINS',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatRoomNumber(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      // Format K (milliers)
      double kValue = number / 1000.0;
      if (kValue == kValue.toInt()) {
        return '${kValue.toInt()}K';
      } else {
        return '${kValue.toStringAsFixed(1)}K';
      }
    } else if (number < 1000000000) {
      // Format M (millions)
      double mValue = number / 1000000.0;
      if (mValue == mValue.toInt()) {
        return '${mValue.toInt()}M';
      } else {
        return '${mValue.toStringAsFixed(1)}M';
      }
    } else {
      // Format B (milliards)
      double bValue = number / 1000000000.0;
      if (bValue == bValue.toInt()) {
        return '${bValue.toInt()}B';
      } else {
        return '${bValue.toStringAsFixed(1)}B';
      }
    }
  }

  String _generateRoomCode() {
    // Générer un code de 6 caractères alphanumériques
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    
    for (int i = 0; i < 6; i++) {
      code += chars[random % chars.length];
      // Simple rotation pour éviter les répétitions
      final newRandom = (random * 7 + i) % chars.length;
      code = code.substring(0, code.length - 1) + chars[newRandom];
    }
    
    return code;
  }

  void _copyRoomCode(String code) {
    // TODO: Implémenter la copie dans le presse-papiers
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code "$code" copié dans le presse-papiers'),
        backgroundColor: const Color(0xFF228B22),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareRoomCode(String code, String roomName) {
    // TODO: Implémenter le partage
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Partage du salon "$roomName" (Code: $code)'),
        backgroundColor: const Color(0xFF228B22),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showInviteFriendsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Simulation de la liste d'amis
    final List<Map<String, dynamic>> friends = [
      {'name': 'Lewis', 'isOnline': true, 'avatar': 'L'},
      {'name': 'Bil', 'isOnline': false, 'avatar': 'B'},
      {'name': 'Jonh', 'isOnline': true, 'avatar': 'J'},
    ];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Inviter des Amis',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  'Choisissez les amis à inviter au salon',
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 20),
                
                // Liste des amis
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF404040) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF228B22),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  friend['avatar'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 12),
                            
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    friend['name'],
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    friend['isOnline'] ? 'En ligne' : 'Hors ligne',
                                    style: TextStyle(
                                      color: friend['isOnline'] ? Colors.green : Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Bouton d'invitation
                            ElevatedButton(
                              onPressed: () {
                                _inviteFriend(friend['name']);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF228B22),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: const Text(
                                'Inviter',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Bouton Fermer
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : Colors.black,
                      side: BorderSide(color: isDark ? Colors.grey : Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Erreur',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _inviteFriend(String friendName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invitation envoyée à $friendName'),
        backgroundColor: const Color(0xFF228B22),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
