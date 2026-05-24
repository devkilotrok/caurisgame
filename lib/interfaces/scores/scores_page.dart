import 'package:flutter/material.dart';

class ScoresPage extends StatefulWidget {
  const ScoresPage({super.key});

  @override
  State<ScoresPage> createState() => _ScoresPageState();
}

class _ScoresPageState extends State<ScoresPage> {
  // Données dynamiques des joueurs selon le nouveau format
  final List<Map<String, dynamic>> _players = [
    {'name': 'Lewis', 'isCurrentUser': false},
    {'name': 'Bil', 'isCurrentUser': false},
    {'name': 'Vous', 'isCurrentUser': true},
    {'name': 'Jonh', 'isCurrentUser': false},
  ];

  // Scores des rounds selon l'exemple de l'image
  final List<List<String>> _roundScores = [
    ['1', '3.1', '5.1', '3.0'], // Round 1
    ['4.0', '4.0', '2.2', '1.0'], // Round 2
    ['—', '—', '—', '4/0'], // Round 3
  ];

  // Scores globaux (SG) selon l'exemple
  final List<String> _globalScores = ['3.0', '7.1', '7.3', '4.0'];

  // Scores projetés (PS) selon l'exemple
  final List<String> _projectedScores = ['—', '—', '—', '8.0'];

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
          'Tableau de Scores',
          style: TextStyle(
            color: Color(0xFFFFD700), // Jaune doré
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Message d'information
            _buildInfoBox(),
            
            const SizedBox(height: 24),
            
            // Tableau de scores
            _buildScoresTable(),
            
            const SizedBox(height: 24),
            
            // Section "Comment ça marche ?"
            _buildHowItWorksSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF404040),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF555555),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info,
            color: Colors.lightBlue,
            size: 24,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Le tableau de scores s\'affiche automatiquement après chaque round de jeu. Vous pouvez consulter l\'historique des scores ici.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoresTable() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A), // Fond gris foncé au lieu de beige
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF404040),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Titre du tableau
          const Text(
            'Exemple de Tableau de Scores',
            style: TextStyle(
              color: Colors.white, // Blanc au lieu de brun foncé
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Tableau
          _buildTable(),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Table(
      border: TableBorder.all(
        color: const Color(0xFF404040),
        width: 1,
      ),
      children: [
        // En-tête avec noms des joueurs
        TableRow(
          decoration: const BoxDecoration(
            color: Color(0xFF404040), // Fond gris pour l'en-tête
          ),
          children: [
            _buildTableCell('Rondes', isHeader: true),
            ...List.generate(_players.length, (index) {
              return _buildTableCell(_players[index]['name'], isHeader: true);
            }),
            _buildTableCell('Somme', isHeader: true),
          ],
        ),
        
        // Round 1
        TableRow(
          children: [
            _buildTableCell('R1', isHeader: true),
            ...List.generate(_players.length, (index) {
              return _buildTableCell(
                _roundScores[0][index],
                isCurrentUser: _players[index]['isCurrentUser'],
              );
            }),
            _buildTableCell('12'),
          ],
        ),
        
        // Round 2
        TableRow(
          children: [
            _buildTableCell('R2', isHeader: true),
            ...List.generate(_players.length, (index) {
              return _buildTableCell(
                _roundScores[1][index],
                isCurrentUser: _players[index]['isCurrentUser'],
              );
            }),
            _buildTableCell('11'),
          ],
        ),
        
        // Round 3
        TableRow(
          children: [
            _buildTableCell('R3', isHeader: true),
            ...List.generate(_players.length, (index) {
              return _buildTableCell(
                _roundScores[2][index],
                isCurrentUser: _players[index]['isCurrentUser'],
              );
            }),
            _buildTableCell('4'),
          ],
        ),
        
        // Score global (SG)
        TableRow(
          children: [
            _buildTableCell('Score global (SG)', isHeader: true),
            ...List.generate(_players.length, (index) {
              return _buildTableCell(
                _globalScores[index],
                isCurrentUser: _players[index]['isCurrentUser'],
              );
            }),
            _buildTableCell('21.4'),
          ],
        ),
        
        // Score projeté (PS)
        TableRow(
          children: [
            _buildTableCell('Score projeté (PS)', isHeader: true),
            ...List.generate(_players.length, (index) {
              return _buildTableCell(
                _projectedScores[index],
                isCurrentUser: _players[index]['isCurrentUser'],
              );
            }),
            _buildTableCell('—'),
          ],
        ),
      ],
    );
  }

  Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isCurrentUser = false,
  }) {
    Color textColor = Colors.white;
    Color backgroundColor = Colors.transparent;
    
    if (isHeader) {
      textColor = const Color(0xFFFFD700); // Jaune pour les en-têtes
      backgroundColor = const Color(0xFF404040);
    } else if (isCurrentUser) {
      textColor = const Color(0xFFFFD700); // Jaune pour l'utilisateur actuel
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildHowItWorksSection() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comment ça marche ?',
            style: TextStyle(
              color: Color(0xFFFFD700), // Jaune doré
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          _buildBulletPoint('Chaque round affiche les scores de tous les joueurs'),
          _buildBulletPoint('Le score global (SG) est la somme de tous les rounds'),
          _buildBulletPoint('Le score projeté (PS) inclut les annonces en cours'),
          _buildBulletPoint('Le tableau s\'affiche automatiquement après chaque round'),
          _buildBulletPoint('Fermeture automatique après 5 secondes'),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
