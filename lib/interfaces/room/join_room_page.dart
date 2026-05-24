import 'package:flutter/material.dart';
import '../game/game_room_router.dart';
import 'waiting_room_page.dart';
import '../../models/room/room_manager.dart';
import '../../services/user/user_service.dart';
import '../../services/game/game_service.dart';
import '../../config/game_constants.dart';
import '../../services/api/payment_api_service.dart';
import '../../services/api/game_api_service.dart';

class JoinRoomPage extends StatefulWidget {
  const JoinRoomPage({super.key});

  @override
  State<JoinRoomPage> createState() => _JoinRoomPageState();
}

class _JoinRoomPageState extends State<JoinRoomPage> {
  final TextEditingController _roomCodeController = TextEditingController();
  
  // Données réelles d'invitations (remplacera la simulation)
  List<Map<String, dynamic>> _invitations = [];

  @override
  void initState() {
    super.initState();
    _loadInvitations();
    // Rafraîchir le solde à chaque affichage de la page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {});
    });
  }

  Future<void> _loadInvitations() async {
    // TODO: Charger les vraies invitations de salon depuis l'API
    // Pour l'instant, la liste reste vide car il n'y a pas d'endpoint spécifique pour les invitations de salon
    // Si un endpoint existe, l'implémenter ici
    try {
      // Exemple de structure attendue pour les invitations :
      // final invitations = await GameApiService.instance.getRoomInvitations();
      // setState(() {
      //   _invitations = invitations;
      // });
      setState(() {});
    } catch (e) {
      print('Erreur lors du chargement des invitations: $e');
      setState(() {});
    }
  }

  Future<int> _getUserBalance() async {
    try {
      final result = await PaymentApiService.instance.getBalance();
      if (result['success'] == true) {
        return result['balance'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      print('Erreur lors de la récupération du solde: $e');
      return 0;
    }
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
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
          'Rejoindre un Salon',
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
            // Titre principal avec instruction
            _buildTitle(),
            
            const SizedBox(height: 24),
            
            // Informations utilisateur
            _buildUserInfo(),
            
            const SizedBox(height: 24),
            
            // Connexion Rapide
            _buildQuickConnect(),
            
            const SizedBox(height: 24),
            
            // Code du Salon
            _buildRoomCodeSection(),
            
            const SizedBox(height: 24),
            
            // Invitations d'amis
            if (_invitations.isNotEmpty) ...[
              _buildInvitationsSection(),
              const SizedBox(height: 24),
            ],
            
            // Instructions
            _buildInstructionsSection(),
            
            const SizedBox(height: 32),
            
            // Bouton Retour
            _buildBackButton(),
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
          'Rejoindre un Salon',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Entrez le code du salon ou rejoignez automatiquement',
          style: TextStyle(
            color: isDark ? Colors.grey : Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF404040) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Text(
            UserService.instance.currentUserPseudo ?? 'User',
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          FutureBuilder<int>(
            future: _getUserBalance(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? Colors.white : Colors.black,
                    ),
                  ),
                );
              }
              final balance = snapshot.data ?? 0;
              return Text(
                'Solde: $balance cauris',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickConnect() {
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
          Text(
            'Connexion Rapide',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'Rejoignez automatiquement le premier salon disponible avec une mise adaptée à votre solde.',
            style: TextStyle(
              color: isDark ? Colors.grey : Colors.grey.shade600,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Bouton Rejoindre Automatiquement
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                _joinAutomatically();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Rejoindre Automatiquement',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCodeSection() {
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
          Text(
            'Code du Salon',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'Entrez le code du salon',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Champ de saisie
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF404040) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF555555) : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: TextField(
              controller: _roomCodeController,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Ex: ABC123',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey.shade500,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              textAlign: TextAlign.center,
              maxLength: 6,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Le code est composé de 6 caractères',
            style: TextStyle(
              color: isDark ? Colors.grey : Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Bouton Rejoindre le Salon
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                _joinWithCode();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF228B22), // Vert
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Rejoindre le Salon',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationsSection() {
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
                Icons.person_add,
                color: Color(0xFFFFD700), // Jaune doré
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Invitations d\'Amis',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Liste des invitations
          ...List.generate(_invitations.length, (index) {
            final invitation = _invitations[index];
            return _buildInvitationCard(invitation, index == _invitations.length - 1);
          }),
        ],
      ),
    );
  }

  Widget _buildInvitationCard(Map<String, dynamic> invitation, bool isLast) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeAgo = _getTimeAgo(invitation['timestamp']);
    
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${invitation['from']} vous invite',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Salon: ${invitation['roomName']} (${invitation['roomCode']})',
                      style: TextStyle(
                        color: const Color(0xFF228B22), // Vert
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Mise: ${invitation['minimumBet']} cauris • $timeAgo',
                      style: TextStyle(
                        color: isDark ? Colors.grey : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Boutons d'action
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _declineInvitation(invitation['id']);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text(
                    'Refuser',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _acceptInvitation(invitation);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF228B22),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text(
                    'Rejoindre',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsSection() {
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
          Text(
            'Comment rejoindre un salon ?',
            style: TextStyle(
              color: const Color(0xFFFFD700), // Jaune doré
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          _buildInstructionStep('1', 'Demandez le code du salon à un ami'),
          _buildInstructionStep('2', 'Entrez le code dans le champ ci-dessus'),
          _buildInstructionStep('3', 'Cliquez sur "Rejoindre le Salon"'),
          _buildInstructionStep(
            '4',
            'Attendez que '
            '${GameConstants.isDevelopment ? GameConstants.temporaryHumanPlayerCount : GameConstants.standardPlayerCount} '
            'joueurs soient connectés'
            '${GameConstants.isDevelopment ? ' (mode développement)' : ''}',
          ),
          _buildInstructionStep('5', 'La partie commence automatiquement'),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF228B22), // Vert
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
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

  Widget _buildBackButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () {
          Navigator.pop(context);
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : Colors.black,
          side: BorderSide(color: isDark ? Colors.grey : Colors.grey.shade400),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Retour au Menu',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes}min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else {
      return 'Il y a ${difference.inDays}j';
    }
  }

  void _joinAutomatically() async {
    // Afficher un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Récupérer le solde de l'utilisateur
      final balanceResult = await PaymentApiService.instance.getBalance();
      final userBalance = balanceResult['balance'] as int? ?? 0;
      
      // Récupérer la liste des salles disponibles depuis l'API
      final availableRooms = await GameApiService.instance.getAvailableRooms();
      
      // Fermer le dialog de chargement
      Navigator.pop(context);
      
      if (availableRooms.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun salon disponible pour le moment'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Filtrer les salles selon le solde de l'utilisateur
      // Trouver une salle avec une mise minimale <= solde et qui n'est pas pleine
      final suitableRooms = availableRooms.where((room) {
        final minBet = (room['minimum_bet'] as int?) ?? 0;
        final playerCount = (room['player_count'] as int?) ?? 0;
        final maxPlayers = (room['max_players'] as int?) ?? 4;
        return minBet <= userBalance && playerCount < maxPlayers;
      }).toList();
      
      if (suitableRooms.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aucun salon disponible avec votre solde actuel ($userBalance cauris)'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Prendre la première salle disponible (ou celle avec la mise minimale la plus proche)
      final selectedRoom = suitableRooms.first;
      final roomCode = (selectedRoom['room_code'] as String?) ?? '';
      
      if (roomCode.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur: Code de salon invalide'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Rejoindre automatiquement le salon
      _roomCodeController.text = roomCode;
      _joinWithCode(fromQuickJoin: true);
    } catch (e) {
      // Fermer le dialog de chargement
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la recherche: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _joinWithCode({bool fromQuickJoin = false}) async {
    final code = _roomCodeController.text.trim().toUpperCase();
    
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un code de salon'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le code doit contenir 6 caractères'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Afficher un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Rejoindre le salon via l'API (backend)
      final ok = await GameService.instance.joinRoom(code);

      // Fermer le dialog de chargement
      Navigator.pop(context);

      if (ok) {
        final session = GameService.instance.gameSession;
        if (fromQuickJoin) {
          session.playWithBots = false;
        }
        // Si partie avec humains, débiter la mise minimale du joueur qui rejoint
        final bool shouldDebit = fromQuickJoin || (session.playWithBots == false);
        if (shouldDebit) {
          final roomId = int.tryParse(session.roomId ?? '') ?? 0;
          final minBet = session.minimumBet ?? 0;
          if (roomId == 0 || minBet <= 0) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Salon ou mise invalide'), backgroundColor: Colors.red),
            );
            return;
          }
          final chk = await PaymentApiService.instance.checkBalance(requiredAmount: minBet);
          if (chk['success'] != true || chk['hasEnough'] != true) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Solde insuffisant pour rejoindre'), backgroundColor: Colors.red),
            );
            return;
          }
          final debit = await PaymentApiService.instance.debitRoomBet(amount: minBet, roomId: roomId);
          if (debit['success'] != true) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(debit['message'] ?? 'Débit échoué'), backgroundColor: Colors.red),
            );
            return;
          }
        }
        // En mode humain, naviguer vers la page d'attente
        // En mode bot, naviguer directement vers le salon
        if (session.playWithBots == false || fromQuickJoin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WaitingRoomPage(
                roomName: session.roomName ?? 'Room',
                roomCode: session.roomCode ?? code,
                minimumBet: session.minimumBet ?? 0,
              ),
            ),
          );
        } else {
          // Mode bot : accès direct au salon
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => GameRoomRouter.buildGameRoomPage(
                roomName: session.roomName ?? 'Room',
                roomCode: session.roomCode ?? code,
                minimumBet: session.minimumBet ?? 0,
                currentPlayerName: UserService.instance.currentUserPseudo ?? 'Vous',
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la connexion'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      // Fermer le dialog de chargement
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de connexion: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _acceptInvitation(Map<String, dynamic> invitation) async {
    // Afficher un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final roomCode = invitation['roomCode'] as String? ?? '';
      if (roomCode.isEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code de salon invalide'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Rejoindre le salon via l'API (backend)
      final ok = await GameService.instance.joinRoom(roomCode);

      // Fermer le dialog de chargement
      Navigator.pop(context);

      if (ok) {
        final session = GameService.instance.gameSession;
        final roomName = invitation['roomName'] as String? ?? session.roomName ?? 'Room';
        final minimumBet = invitation['minimumBet'] as int? ?? session.minimumBet ?? 0;
        
        // Si partie avec humains, débiter la mise minimale
        if (session.playWithBots == false) {
          final roomId = int.tryParse(session.roomId ?? '') ?? 0;
          final minBet = session.minimumBet ?? 0;
          if (roomId == 0 || minBet <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Salon ou mise invalide'), backgroundColor: Colors.red),
            );
            return;
          }
          final chk = await PaymentApiService.instance.checkBalance(requiredAmount: minBet);
          if (chk['success'] != true || chk['hasEnough'] != true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Solde insuffisant pour rejoindre'), backgroundColor: Colors.red),
            );
            return;
          }
          final debit = await PaymentApiService.instance.debitRoomBet(amount: minBet, roomId: roomId);
          if (debit['success'] != true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(debit['message'] ?? 'Débit échoué'), backgroundColor: Colors.red),
            );
            return;
          }
        }
        
        // Supprimer l'invitation de la liste locale
        setState(() {
          _invitations.removeWhere((inv) => inv['id'] == invitation['id']);
        });

        // En mode humain, naviguer vers la page d'attente
        // En mode bot, naviguer directement vers le salon
        if (session.playWithBots == false) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WaitingRoomPage(
                roomName: roomName,
                roomCode: roomCode,
                minimumBet: minimumBet,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => GameRoomRouter.buildGameRoomPage(
                roomName: roomName,
                roomCode: roomCode,
                minimumBet: minimumBet,
                currentPlayerName: UserService.instance.currentUserPseudo ?? 'Vous',
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la connexion'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      // Fermer le dialog de chargement
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de connexion: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _declineInvitation(String invitationId) {
    // TODO: Implémenter le refus d'invitation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invitation refusée'),
        backgroundColor: Colors.red,
      ),
    );
    
    // Supprimer l'invitation de la liste
    setState(() {
      _invitations.removeWhere((inv) => inv['id'] == invitationId);
    });
  }
}
