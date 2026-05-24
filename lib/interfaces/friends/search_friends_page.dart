import 'package:flutter/material.dart';
import '../../models/user/user_models.dart';

class SearchFriendsPage extends StatefulWidget {
  const SearchFriendsPage({super.key});

  @override
  State<SearchFriendsPage> createState() => _SearchFriendsPageState();
}

class _SearchFriendsPageState extends State<SearchFriendsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<User> _searchResults = [];
  List<FriendRequest> _sentInvitations = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadSentInvitations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadSentInvitations() {
    // Simulation des invitations envoyées
    _sentInvitations = [
      FriendRequest(
        id: 'sent_1',
        fromUserId: 'current_user',
        fromUserPseudo: 'Vous',
        fromUserAvatar: 'A',
        toUserId: 'user_1',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        message: 'Salut ! Veux-tu être mon ami ?',
      ),
      FriendRequest(
        id: 'sent_2',
        fromUserId: 'current_user',
        fromUserPseudo: 'Vous',
        fromUserAvatar: 'A',
        toUserId: 'user_2',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        message: 'Salut ! Veux-tu être mon ami ?',
      ),
    ];
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
          'Rechercher des Amis',
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
            // Section de recherche
            _buildSearchSection(),
            
            const SizedBox(height: 24),
            
            // Invitations envoyées
            if (_sentInvitations.isNotEmpty) ...[
              _buildSentInvitationsSection(),
              const SizedBox(height: 24),
            ],
            
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
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
                Icons.search,
                color: Color(0xFF228B22),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Rechercher des Amis',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Entrez le pseudo ou l\'email de la personne que vous souhaitez ajouter',
            style: TextStyle(
              color: isDark ? Colors.grey : Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Champ de recherche
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
              controller: _searchController,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Pseudo ou email...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey.shade500,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF228B22)),
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search, color: Color(0xFF228B22)),
                        onPressed: _performSearch,
                      ),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Bouton de recherche
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSearching ? null : _performSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF228B22),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isSearching ? 'Recherche...' : 'Rechercher',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Résultats de recherche dans le même conteneur
          if (_hasSearched) ...[
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF404040)),
            const SizedBox(height: 16),
            
            Text(
              'Résultats de recherche (${_searchResults.length})',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            if (_searchResults.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off,
                      color: isDark ? Colors.grey : Colors.grey.shade400,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun utilisateur trouvé',
                      style: TextStyle(
                        color: isDark ? Colors.grey : Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Essayez avec un autre pseudo ou email',
                      style: TextStyle(
                        color: isDark ? Colors.grey : Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_searchResults.length, (index) {
                final user = _searchResults[index];
                return _buildUserCard(user, index == _searchResults.length - 1);
              }),
          ],
        ],
      ),
    );
  }

  Widget _buildSentInvitationsSection() {
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
                Icons.send,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Invitations Envoyées (${_sentInvitations.length})',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          ...List.generate(_sentInvitations.length, (index) {
            final invitation = _sentInvitations[index];
            return _buildSentInvitationCard(invitation, index == _sentInvitations.length - 1);
          }),
        ],
      ),
    );
  }

  Widget _buildSentInvitationCard(FriendRequest invitation, bool isLast) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeAgo = _getTimeAgo(invitation.timestamp);
    
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
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                invitation.fromUserAvatar,
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
                  'Invitation envoyée à ${invitation.toUserId}', // Dans une vraie app, on aurait le pseudo
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  invitation.message,
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  timeAgo,
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'En attente',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildUserCard(User user, bool isLast) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeAgo = _getTimeAgo(user.lastSeen);
    final isInvitationSent = _sentInvitations.any((inv) => inv.toUserId == user.id);
    
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
      child: Row(
        children: [
          // Avatar avec indicateur en ligne
          Stack(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF228B22),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    user.pseudo[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (user.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.pseudo,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user.email,
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  user.isOnline ? 'En ligne' : 'Dernière connexion: $timeAgo',
                  style: TextStyle(
                    color: user.isOnline ? Colors.green : (isDark ? Colors.grey : Colors.grey.shade600),
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${user.caurisBalance} cauris',
                  style: TextStyle(
                    color: const Color(0xFFFFD700),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Bouton d'action
          if (isInvitationSent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Invitation envoyée',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: () {
                _showConfirmInvitationDialog(user);
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
                'Ajouter',
                style: TextStyle(fontSize: 12),
              ),
            ),
        ],
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

  void _performSearch() async {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un pseudo ou email'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });
    
    // Simulation de la recherche
    await Future.delayed(const Duration(seconds: 1));
    
    // Simulation des résultats de recherche
    final mockResults = [
      User(
        id: 'user_1',
        pseudo: 'Lewis',
        email: 'lewis@example.com',
        caurisBalance: 1500,
        avatar: 'L',
        lastSeen: DateTime.now(),
        isOnline: true,
      ),
      User(
        id: 'user_2',
        pseudo: 'Bil',
        email: 'bil@example.com',
        caurisBalance: 800,
        avatar: 'B',
        lastSeen: DateTime.now().subtract(const Duration(hours: 2)),
        isOnline: false,
      ),
      User(
        id: 'user_3',
        pseudo: 'Jonh',
        email: 'jonh@example.com',
        caurisBalance: 2000,
        avatar: 'J',
        lastSeen: DateTime.now(),
        isOnline: true,
      ),
    ].where((user) => 
      user.pseudo.toLowerCase().contains(query.toLowerCase()) ||
      user.email.toLowerCase().contains(query.toLowerCase())
    ).toList();
    
    setState(() {
      _searchResults = mockResults;
      _isSearching = false;
    });
  }

  void _showConfirmInvitationDialog(User user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar de l'utilisateur
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF228B22),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      user.pseudo[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  'Envoyer une demande d\'amitié ?',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  'Vous êtes sur le point d\'envoyer une demande d\'amitié à',
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  user.pseudo,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                Text(
                  user.email,
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Boutons d'action
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : Colors.black,
                          side: BorderSide(color: isDark ? Colors.grey : Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Annuler'),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _sendFriendRequest(user);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF228B22),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Envoyer'),
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

  void _sendFriendRequest(User user) {
    // Créer une nouvelle invitation
    final newInvitation = FriendRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromUserId: 'current_user',
      fromUserPseudo: 'Vous',
      fromUserAvatar: 'A',
      toUserId: user.id,
      timestamp: DateTime.now(),
      message: 'Salut ! Veux-tu être mon ami ?',
    );
    
    setState(() {
      _sentInvitations.add(newInvitation);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Demande d\'amitié envoyée à ${user.pseudo}'),
        backgroundColor: const Color(0xFF228B22),
      ),
    );
  }
}
