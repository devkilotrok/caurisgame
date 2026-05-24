import 'package:flutter/material.dart';
import 'theme_manager.dart';

class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key});

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  String _selectedTheme = ThemeManager.getCurrentTheme(); // Thème actuel

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
          'Apparence',
          style: TextStyle(
            color: isDark ? const Color(0xFFFFD700) : const Color(0xFF228B22),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Titre principal
            _buildTitle(),
            
            const SizedBox(height: 32),
            
            // Options de thème
            _buildThemeOptions(),
            
            const SizedBox(height: 32),
            
            // Prévisualisation
            _buildPreview(),
            
            const SizedBox(height: 32),
            
            // Bouton de confirmation
            _buildConfirmButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
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
        children: [
          Icon(
            Icons.palette,
            color: isDark ? const Color(0xFFFFD700) : const Color(0xFF228B22),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Choisissez votre thème',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Personnalisez l\'apparence de l\'application selon vos préférences',
            style: TextStyle(
              color: isDark ? Colors.grey : Colors.grey.shade600,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOptions() {
    return Column(
      children: [
        // Option Sombre
        _buildThemeOption(
          title: 'Mode Sombre',
          description: 'Thème sombre par défaut',
          icon: Icons.dark_mode,
          iconColor: const Color(0xFFFFD700), // Jaune
          isSelected: _selectedTheme == 'Sombre',
          onTap: () {
            setState(() {
              _selectedTheme = 'Sombre';
            });
          },
        ),
        
        const SizedBox(height: 16),
        
        // Option Clair
        _buildThemeOption(
          title: 'Mode Clair',
          description: 'Thème clair pour une meilleure lisibilité',
          icon: Icons.light_mode,
          iconColor: Colors.orange,
          isSelected: _selectedTheme == 'Clair',
          onTap: () {
            setState(() {
              _selectedTheme = 'Clair';
            });
          },
        ),
      ],
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF404040) : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFD700) : const Color(0xFF404040),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFFFFD700) : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFFFFD700), // Jaune doré
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
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
            'Aperçu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Mini aperçu du thème sélectionné
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: _selectedTheme == 'Sombre' ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedTheme == 'Sombre' ? const Color(0xFF404040) : Colors.grey,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _selectedTheme == 'Sombre' ? Icons.dark_mode : Icons.light_mode,
                  color: _selectedTheme == 'Sombre' ? const Color(0xFFFFD700) : Colors.orange,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedTheme == 'Sombre' ? 'Mode Sombre' : 'Mode Clair',
                  style: TextStyle(
                    color: _selectedTheme == 'Sombre' ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedTheme == 'Sombre' ? 'Fond noir, texte blanc' : 'Fond blanc, texte noir',
                  style: TextStyle(
                    color: _selectedTheme == 'Sombre' ? Colors.grey : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          _applyTheme();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF228B22), // Vert plus foncé
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Appliquer le thème',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _applyTheme() {
    // Appliquer le thème immédiatement
    ThemedApp.updateTheme(context, _selectedTheme);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Thème appliqué',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Le thème $_selectedTheme a été appliqué avec succès !\n\n'
            'L\'application utilise maintenant le thème sélectionné.',
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Retour aux paramètres
              },
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
}
