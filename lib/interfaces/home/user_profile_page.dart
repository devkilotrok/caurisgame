import 'package:flutter/material.dart';
import '../../services/api/user_api_service.dart';
import '../auth/change_password_dialog.dart';
import '../auth/edit_profile_dialog.dart';
import 'home_page.dart';

class UserProfilePage extends StatefulWidget {
  final String pseudo;
  final int caurisBalance;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String address;
  final String memberSince;
  final int gamesPlayed;
  final int score;
  final int victories;
  final bool isEmailVerified;
  
  const UserProfilePage({
    super.key,
    this.pseudo = 'Alpha',
    this.caurisBalance = 1000,
    this.firstName = 'Alpha',
    this.lastName = 'Alpha',
    this.email = 'Alpha@local.com',
    this.phone = '+33 6 12 34 56 78',
    this.address = '123 Rue de la Paix, Paris, France',
    this.memberSince = '24/10/2025',
    this.gamesPlayed = 0,
    this.score = 0,
    this.victories = 0,
    this.isEmailVerified = false,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  String _firstName = '';
  String _lastName = '';
  String _pseudo = '';
  String _email = '';
  String _phone = '';
  String _address = '';
  bool _emailVerified = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _firstName = widget.firstName;
    _lastName = widget.lastName;
    _pseudo = widget.pseudo;
    _email = widget.email;
    _phone = widget.phone;
    _address = widget.address;
    _emailVerified = widget.isEmailVerified;
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final result = await UserApiService.instance.getProfile();
      if (!mounted) return;
      if (result['success'] == true) {
        final user = result['user'] as Map<String, dynamic>;
        setState(() {
          _firstName = (user['first_name'] ?? user['firstname'] ?? user['firstName'] ?? user['prenom'] ?? _firstName).toString();
          _lastName = (user['last_name'] ?? user['lastname'] ?? user['lastName'] ?? user['nom'] ?? _lastName).toString();
          _pseudo = (user['pseudo'] ?? user['username'] ?? user['user_name'] ?? _pseudo).toString();
          _email = (user['email'] ?? _email).toString();
          _phone = (user['phone'] ?? user['telephone'] ?? _phone).toString();
          _address = (user['address'] ?? user['adresse'] ?? _address).toString();
          // Détermination de la vérification email: accepte plusieurs formats
          final ev = user['email_verified'] ?? user['is_verified'] ?? user['email_verified_at'];
          _emailVerified = ev is bool ? ev : (ev != null && ev.toString().isNotEmpty);
          _loading = false;
        });
      } else {
        setState(() { _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profil',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Section profil (avatar, nom, pseudo)
            _buildProfileHeader(),
            
            const SizedBox(height: 24),
            
            // État de vérification email
            _emailVerified ? _buildVerifiedBadge() : _buildEmailVerificationButton(),
            
            const SizedBox(height: 24),

            // Statistiques (Cauris / Score / Victoires)
            _buildStatsSection(),
            
            const SizedBox(height: 24),
            
            // Informations du compte
            _buildAccountInfoSection(),
            
            const SizedBox(height: 24),
            
            // Actions
            _buildActionsSection(context),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        // Avatar avec initiales
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700), // Jaune
            shape: BoxShape.circle,
          ),
            child: Center(
              child: Text(
                _computeInitials(_firstName, _lastName, _pseudo),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Nom complet (ou pseudo si absent)
        Text(
          _displayName(_firstName, _lastName, _pseudo),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Pseudo (sans @)
        if (_pseudo.isNotEmpty)
          Text(
          _pseudo,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailVerificationButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_outlined,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text(
            'Compte vérifié',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20), // Vert foncé
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            'Compte vérifié',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Row(
      children: [
        // Cauris
        Expanded(
          child: _buildStatCard(
            icon: Icons.account_balance,
            iconColor: const Color(0xFFFFD700),
            value: widget.caurisBalance.toString(),
            label: 'Cauris',
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Score
        Expanded(
          child: _buildStatCard(
            icon: Icons.bar_chart,
            iconColor: Colors.blue,
            value: widget.score.toString(),
            label: 'Score',
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Victoires
        Expanded(
          child: _buildStatCard(
            icon: Icons.emoji_events,
            iconColor: const Color(0xFFFFD700),
            value: widget.victories.toString(),
            label: 'Victoires',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informations du compte',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Email
              _buildInfoRow(
                icon: Icons.email,
                iconColor: Colors.blue,
                label: 'Email',
                value: _email,
              ),
              
              const Divider(color: Colors.grey, height: 24),
              
              // Membre depuis
              _buildInfoRow(
                icon: Icons.calendar_today,
                iconColor: Colors.red,
                label: 'Membre depuis',
                value: widget.memberSince,
              ),
              
              const Divider(color: Colors.grey, height: 24),
              
              // Parties jouées
              _buildInfoRow(
                icon: Icons.games,
                iconColor: Colors.green,
                label: 'Parties jouées',
                value: widget.gamesPlayed.toString(),
              ),
              
              const Divider(color: Colors.grey, height: 24),
              
              // Téléphone
              _buildInfoRow(
                icon: Icons.phone,
                iconColor: Colors.orange,
                label: 'Téléphone',
                value: _phone,
              ),
              
              const Divider(color: Colors.grey, height: 24),
              
              // Adresse
              _buildInfoRow(
                icon: Icons.location_on,
                iconColor: Colors.purple,
                label: 'Adresse',
                value: _address,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 24,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Changer le mot de passe
        _buildActionButton(
          icon: Icons.key,
          iconColor: const Color(0xFFFFD700),
          backgroundColor: Colors.blue,
          text: 'Changer le mot de passe',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChangePasswordDialog(),
                fullscreenDialog: true, // Pour un effet de modal
              ),
            );
          },
        ),
        
        const SizedBox(height: 12),
        
        // Modifier le profil
        _buildActionButton(
          icon: Icons.edit,
          iconColor: const Color(0xFFFFD700),
          backgroundColor: Colors.blue,
          text: 'Modifier le profil',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditProfileDialog(
                  pseudo: _pseudo.isNotEmpty ? _pseudo : widget.pseudo,
                  firstName: _firstName.isNotEmpty ? _firstName : widget.firstName,
                  lastName: _lastName.isNotEmpty ? _lastName : widget.lastName,
                  email: _email.isNotEmpty ? _email : widget.email,
                  phone: _phone.isNotEmpty ? _phone : widget.phone,
                  address: _address.isNotEmpty ? _address : widget.address,
                ),
                fullscreenDialog: true, // Pour un effet de modal
              ),
            );
          },
        ),
        
        const SizedBox(height: 12),
        
        // Déconnexion
        _buildActionButton(
          icon: Icons.logout,
          iconColor: Colors.grey,
          backgroundColor: Colors.red,
          text: 'Déconnexion',
          onTap: () {
            _showLogoutConfirmation(context);
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Déconnexion',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Êtes-vous sûr de vouloir vous déconnecter ?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          actions: [
            // Bouton Annuler
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Annuler',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            // Bouton Déconnexion
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fermer la boîte de dialogue
                _performLogout(context);
              },
              child: const Text(
                'Déconnexion',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _performLogout(BuildContext context) {
    // TODO: Nettoyer les données utilisateur (token, cache, etc.)
    print('Déconnexion effectuée');
    
    // Rediriger vers l'écran de démarrage (HomePage)
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
      (Route<dynamic> route) => false, // Supprimer toutes les pages précédentes
    );
  }
}

String _computeInitials(String firstName, String lastName, String pseudo) {
  String a = '';
  if (firstName.trim().isNotEmpty) a += firstName.trim()[0];
  if (lastName.trim().isNotEmpty) {
    a += lastName.trim()[0];
  } else if (firstName.trim().isEmpty && pseudo.trim().isNotEmpty) {
    a += pseudo.trim()[0];
  }
  if (a.isEmpty) a = 'U';
  return a.toUpperCase();
}

String _displayName(String firstName, String lastName, String pseudo) {
  final hasFirst = firstName.trim().isNotEmpty;
  final hasLast = lastName.trim().isNotEmpty;
  if (hasFirst || hasLast) {
    return [firstName.trim(), lastName.trim()].where((e) => e.isNotEmpty).join(' ');
  }
  return pseudo.isNotEmpty ? pseudo : 'Utilisateur';
}
