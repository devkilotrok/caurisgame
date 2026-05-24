import 'package:flutter/material.dart';
import 'legal_info_page.dart';
import 'appearance_page.dart';

class ParametresPage extends StatefulWidget {
  const ParametresPage({super.key});

  @override
  State<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage> {
  // États des paramètres
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _pushNotifications = true;
  String _language = 'Français';
  String _appearance = 'Modern / Modern';

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
          'Paramètres',
          style: TextStyle(
            color: Color(0xFFFFD700), // Jaune doré
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Version
            _buildVersionInfo(),
            
            const SizedBox(height: 32),
            
            // Paramètres principaux
            _buildMainSettings(),
            
            const SizedBox(height: 24),
            
            // Paramètres d'évaluation et rapport
            _buildEvaluationSettings(),
            
            const SizedBox(height: 24),
            
            // Paramètres système
            _buildSystemSettings(),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF404040),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          const Text(
            'CAURIS DEGUE Callbreak',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'v1.0.0',
            style: TextStyle(
              color: Color(0xFFFFD700), // Jaune doré
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainSettings() {
    return Column(
      children: [
        // Langue et Apparence
        Row(
          children: [
            Expanded(
              child: _buildSettingCard(
                icon: Icons.language,
                iconColor: Colors.blue,
                title: 'Langue (Bêta)',
                value: _language,
                onTap: () {
                  _showLanguageDialog();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSettingCard(
                icon: Icons.palette,
                iconColor: const Color(0xFFFFD700), // Jaune
                title: 'Apparence',
                value: _appearance,
                onTap: () {
                  _showAppearanceDialog();
                },
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Son et Notifications
        Row(
          children: [
            Expanded(
              child: _buildSoundMusicCard(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildNotificationCard(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEvaluationSettings() {
    return Row(
      children: [
        Expanded(
          child: _buildSettingCard(
            icon: Icons.star,
            iconColor: const Color(0xFFFFD700), // Jaune
            title: 'Évaluez-nous',
            value: 'Évaluer maintenant',
            onTap: () {
              _showEvaluationDialog();
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSettingCard(
            icon: Icons.bug_report,
            iconColor: const Color(0xFF228B22), // Vert
            title: 'Rapport de bogue',
            value: 'Rapport',
            onTap: () {
              _showBugReportDialog();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSystemSettings() {
    return Row(
      children: [
        Expanded(
          child: _buildSmallSettingCard(
            icon: Icons.info,
            iconColor: Colors.blue,
            title: 'Info légales',
            onTap: () {
              _showLegalInfoDialog();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSmallSettingCard(
            icon: Icons.sports_esports,
            iconColor: Colors.grey,
            title: 'Infos jeu',
            onTap: () {
              _showGameInfoDialog();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSmallSettingCard(
            icon: Icons.refresh,
            iconColor: Colors.blue,
            title: 'Réinitialiser',
            onTap: () {
              _showResetDialog();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSmallSettingCard(
            icon: Icons.exit_to_app,
            iconColor: Colors.red,
            title: 'Sortie du jeu',
            onTap: () {
              _showExitDialog();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF404040),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFFFFD700), // Jaune doré
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundMusicCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF404040),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.volume_up,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Son | Musique',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _soundEnabled = !_soundEnabled;
                  });
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _soundEnabled ? Colors.blue : const Color(0xFF404040),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _soundEnabled ? Icons.volume_up : Icons.volume_off,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _musicEnabled = !_musicEnabled;
                  });
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _musicEnabled ? const Color(0xFFFFD700) : const Color(0xFF404040),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.music_note,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF404040),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.notifications,
              color: Color(0xFFFFD700), // Jaune
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Notifications push',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: _pushNotifications,
            onChanged: (value) {
              setState(() {
                _pushNotifications = value;
              });
            },
            activeColor: const Color(0xFFFFD700), // Jaune
            activeTrackColor: const Color(0xFFFFD700).withOpacity(0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: const Color(0xFF404040),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallSettingCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF404040),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Dialogues
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Langue',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Fonctionnalité en cours de développement',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFFFFD700)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAppearanceDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AppearancePage(),
      ),
    );
  }

  void _showEvaluationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Évaluez-nous',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Merci de votre intérêt ! Cette fonctionnalité sera disponible prochainement.',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFFFFD700)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showBugReportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Rapport de bogue',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Contactez-nous à : support@caurisdegue.com',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFFFFD700)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showLegalInfoDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LegalInfoPage(),
      ),
    );
  }

  void _showGameInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Informations du jeu',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'CAURIS DEGUE Callbreak\n\nUn jeu de cartes stratégique pour 4 joueurs.\n\nObjectif : Atteindre 150 points en respectant vos annonces.',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFFFFD700)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Réinitialiser',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Êtes-vous sûr de vouloir réinitialiser tous les paramètres ?',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Annuler',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Implémenter la réinitialisation
              },
              child: const Text(
                'Réinitialiser',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Sortie du jeu',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Êtes-vous sûr de vouloir quitter l\'application ?',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Annuler',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              },
              child: const Text(
                'Quitter',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
