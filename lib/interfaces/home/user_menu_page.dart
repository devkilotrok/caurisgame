import 'package:flutter/material.dart';
import 'user_profile_page.dart';
import '../../services/user/user_service.dart';
import '../caisse/caisse_page.dart';
import '../regles/regles_page.dart';
import '../scores/scores_page.dart';
import '../parametres/parametres_page.dart';
import '../room/create_room_page.dart';
import '../room/join_room_page.dart';
import '../friends/friends_page.dart';
import '../chat/chat_page.dart';

class UserMenuPage extends StatelessWidget {
  final String pseudo;
  final int caurisBalance;
  
  const UserMenuPage({
    super.key,
    this.pseudo = 'Alpha',
    this.caurisBalance = 1000,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Logo circulaire
              _buildLogo(),
              
              const SizedBox(height: 24),
              
              // Titre principal
              const Text(
                'CAURIS DEGUE Callbreak',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Section profil
              _buildProfileSection(context),
              
              const SizedBox(height: 24),
              
              // Boutons de menu
              _buildMenuButtons(context),
              
              const SizedBox(height: 24),
              
              // Section Système de Cauris
              _buildCaurisSystemSection(),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A), // Gris foncé
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF404040),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logocauris.jpeg',
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfilePage(
              pseudo: UserService.instance.currentUserPseudo ?? pseudo,
              caurisBalance: caurisBalance,
              firstName: '',
              lastName: '',
              email: UserService.instance.currentUserEmail ?? '',
              phone: '',
              address: '',
            ),
          ),
        );
      },
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFFD700), // Bordure jaune
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person,
                color: Colors.blue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pseudo,
                    style: const TextStyle(
                      color: Color(0xFFFFD700), // Jaune
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$caurisBalance cauris',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButtons(BuildContext context) {
    return Column(
      children: [
        // Profil créé ✓
        _buildMenuButton(
          icon: Icons.person,
          iconColor: Colors.blue,
          text: 'Profil créé ✓',
          onTap: () {
            print('Profil créé');
          },
        ),
        
        const SizedBox(height: 12),
        
                    // Accéder à la caisse
                    _buildMenuButton(
                      icon: Icons.account_balance,
                      iconColor: const Color(0xFFFFD700), // Jaune
                      text: 'Accéder à la caisse',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CaissePage(caurisBalance: caurisBalance),
                          ),
                        );
                      },
                    ),
        
        const SizedBox(height: 12),
        
        // Créer un salon
        _buildMenuButton(
          icon: Icons.home,
          iconColor: const Color(0xFF8B4513), // Marron
          text: 'Créer un salon',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateRoomPage(),
              ),
            );
          },
        ),
        
        const SizedBox(height: 12),
        
        // Rejoindre un salon
        _buildMenuButton(
          icon: Icons.home,
          iconColor: const Color(0xFF8B4513), // Marron
          text: 'Rejoindre un salon',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const JoinRoomPage(),
              ),
            );
          },
        ),
        
        const SizedBox(height: 12),
        
                    // Voir les règles du jeu
                    _buildMenuButton(
                      icon: Icons.description,
                      iconColor: const Color(0xFF8B4513), // Marron
                      text: 'Voir les règles du jeu',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReglesPage(),
                          ),
                        );
                      },
                    ),
        
        const SizedBox(height: 12),
        
                    // Tableau de Scores
                    _buildMenuButton(
                      icon: Icons.bar_chart,
                      iconColor: Colors.red,
                      text: 'Tableau de Scores',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ScoresPage(),
                          ),
                        );
                      },
                    ),
        
        const SizedBox(height: 12),
        
                    // Paramètres
                    _buildMenuButton(
                      icon: Icons.settings,
                      iconColor: Colors.blue,
                      text: 'Paramètres',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ParametresPage(),
                          ),
                        );
                      },
                    ),
        
        const SizedBox(height: 12),
        
        // Mes Amis
        _buildMenuButton(
          icon: Icons.people,
          iconColor: Colors.purple,
          text: 'Mes Amis',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FriendsPage(),
                          ),
                        );
                      },
                    ),
        
        const SizedBox(height: 12),
        
        // Assistance Chat
        _buildMenuButton(
          icon: Icons.chat,
          iconColor: const Color(0xFF228B22), // Vert
          text: 'Assistance Chat',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChatPage(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required Color iconColor,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
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
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaurisSystemSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Système de Cauris',
            style: TextStyle(
              color: Color(0xFFFFD700), // Jaune
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),
          
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• 10 cauris = 1 000 FCFA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '• Dépôt sécurisé via FedaPay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '• Retrait automatique',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '• Système anti-fraude intégré',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
