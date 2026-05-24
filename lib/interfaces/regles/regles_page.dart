import 'package:flutter/material.dart';

class ReglesPage extends StatefulWidget {
  const ReglesPage({super.key});

  @override
  State<ReglesPage> createState() => _ReglesPageState();
}

class _ReglesPageState extends State<ReglesPage> {
  int _currentSection = 1; // 0: Pause d'appel, 1: Règles, 2: Comment jouer, 3: FAQ, 4: Journaux

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
          'Règles du jeu',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Section principale avec le contenu
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Logo CAURIS DEGUE
                  _buildLogo(),
                  
                  const SizedBox(height: 24),
                  
                  // Titre principal
                  const Text(
                    'Règles',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  const Text(
                    'CAURIS DEGUE CALLBREAK',
                    style: TextStyle(
                      color: Color(0xFFFFD700), // Jaune doré
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Contenu des règles selon la section
                  _buildRulesContent(),
                ],
              ),
            ),
          ),
          
          // Navigation en bas
          _buildBottomNavigation(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
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

  Widget _buildRulesContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A), // Fond gris foncé au lieu de beige
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF404040),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentSection == 0) _buildPauseAppel(),
          if (_currentSection == 1) _buildRegles(),
          if (_currentSection == 2) _buildCommentJouer(),
          if (_currentSection == 3) _buildFAQ(),
          if (_currentSection == 4) _buildJournaux(),
        ],
      ),
    );
  }

  Widget _buildPauseAppel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Pause d\'appel'),
        const SizedBox(height: 24),
        
        const Text(
          'La fonction de pause d\'appel est une fonctionnalité qui permet aux joueurs de mettre en pause une partie en cours.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        
        const SizedBox(height: 16),
        
        const Text(
          'Cette fonction est utile lorsque les joueurs ont besoin de faire une courte pause ou de s\'absenter temporairement du jeu.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        
        const SizedBox(height: 16),
        
        const Text(
          'Pour utiliser la fonction de pause d\'appel, les joueurs doivent cliquer sur le bouton \'Pause\' pendant la partie.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        
        const SizedBox(height: 16),
        
        const Text(
          'Une fois la partie en pause, les autres joueurs seront informés et la partie reprendra une fois que tous les joueurs seront prêts.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        
        const SizedBox(height: 16),
        
        const Text(
          'Il est important de noter que la fonction de pause d\'appel ne doit être utilisée qu\'en cas de besoin réel et non pour abuser du système.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        
        const SizedBox(height: 16),
        
        const Text(
          'Les abus de la fonction de pause d\'appel peuvent entraîner des pénalités pour les joueurs concernés.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildRegles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Joueurs'),
        const SizedBox(height: 12),
        const Text(
          'Le jeu se joue à 4 joueurs avec un jeu de 52 cartes.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        
        const SizedBox(height: 24),
        
        _buildSectionTitle('Distribution des cartes'),
        const SizedBox(height: 12),
        const Text(
          'Les cartes sont distribuées une par une dans le sens inverse des aiguilles . Chaque joueur reçoit exactement 13 cartes.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        
        const SizedBox(height: 24),
        
        _buildSectionTitle('Enchères'),
        const SizedBox(height: 12),
        const Text(
          'Chaque joueur annonce le nombre de plis qu\'il pense pouvoir remporter. Les enchères vont de 2 à 13 plis.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        
        const SizedBox(height: 24),
        
        _buildSectionTitle('Déroulement d\'une manche'),
        const SizedBox(height: 12),
        const Text(
          'Les joueurs doivent suivre la couleur de la première carte jouée à chaque tour. S\'ils n\'ont pas de carte de cette couleur, ils doivent jouer Pique, l\'atout, qui a toujours la valeur la plus élevée.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        
        const SizedBox(height: 24),
        
        _buildSectionTitle('Score'),
        const SizedBox(height: 12),
        const Text(
          'Les points sont attribués en fonction des enchères et des levées remportées. Celui qui obtient le score de 150 points ou le total le plus élevé après 10 manches remporte la partie.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        
        const SizedBox(height: 24),
        
        _buildSectionTitle('Calcul des points'),
        const SizedBox(height: 16),
        
        // Tableau des règles de score
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF404040),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildScoreRow('Plis obtenus = Plis annoncés', 'Score précédent + (Plis annoncés × 10)'),
              _buildDivider(),
              _buildScoreRow('Plis obtenus < Plis annoncés', 'Score précédent - (Plis annoncés × 10)'),
              _buildDivider(),
              _buildScoreRow('Plis obtenus > Plis annoncés (1 ou 2 plis en plus)', 'Score précédent + (Plis annoncés × 10) + (surplus)'),
              _buildDivider(),
              _buildScoreRow('Plis obtenus ≥ Plis annoncés + 3', 'Score précédent - (Plis annoncés × 10)'),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        _buildSectionTitle('Fin de Partie'),
        const SizedBox(height: 12),
        const Text(
          'Un joueur gagne dès qu\'il atteint 150 points. Si plusieurs joueurs atteignent 150 en même temps, celui avec le plus grand surplus l\'emporte. Si 10 manches sont jouées sans vainqueur, le meilleur score gagne.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCommentJouer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Comment jouer'),
        const SizedBox(height: 24),
        
        // 1. Sélection du donneur
        _buildStepTitle('1. Sélection du donneur'),
        const SizedBox(height: 12),
        const Text(
          'Le donneur est choisi automatiquement et sa position change dans le sens inverse des aiguilles d\'une montre après chaque tour. Le donneur mélange et distribue 13 cartes à chaque joueur.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        
        const SizedBox(height: 24),
        
        // 2. Enchères
        _buildStepTitle('2. Enchères'),
        const SizedBox(height: 12),
        const Text(
          'Le joueur à droite du donneur commence à enchérir, avec une enchère minimale de 2. Les joueurs doivent remporter au moins le nombre de plis qu\'ils ont annoncés pour éviter de perdre des points.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        
        const SizedBox(height: 16),
        
        const Text(
          'Cas 1 - Redistribution des cartes :',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Si un joueur n\'a aucun pique (S), la manche est automatiquement redistribuée. Un message affiche le nom du joueur concerné et les cartes sont redistribuées.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        
        const SizedBox(height: 16),
        
        const Text(
          'Cas 2 - Reprise des annonces :',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Si le total des annonces de tous les joueurs est inférieur à 10, chaque joueur reçoit automatiquement +1 à son annonce. Une notification s\'affiche pendant 3 secondes pour informer les joueurs, puis le jeu démarre automatiquement avec les nouvelles annonces.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        
        const SizedBox(height: 24),
        
        // 3. Déroulement
        _buildStepTitle('3. Déroulement'),
        const SizedBox(height: 12),
        const Text(
          'La partie se déroule dans le sens inverse des aiguilles d\'une montre. Les joueurs doivent suivre la couleur de la première carte jouée. S\'ils n\'ont pas de carte de cette couleur, ils peuvent jouer un pique, l\'atout. S\'ils n\'ont pas de pique, ils peuvent jouer n\'importe quelle carte. Le gagnant de chaque manche commence la manche suivante.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFAQ() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('FAQ'),
        const SizedBox(height: 24),
        
        // Question 1
        _buildFAQItem(
          1,
          'Pourquoi appelle-t-on cela un « Callbreak » ?',
          'Le nom « Callbreak » vient de la stratégie fondamentale du jeu : les joueurs tentent de contrer et perturber les annonces des autres. En jouant intelligemment et en perturbant les enchères des adversaires, on gagne un avantage, ce qui rend le nom « Callbreak » parfaitement adapté.',
        ),
        
        const SizedBox(height: 20),
        
        // Question 2
        _buildFAQItem(
          2,
          'Qu\'est-ce qu\'une annonce/enchère ?',
          'Une annonce (ou enchère) est le nombre de sets qu\'un joueur s\'attend à gagner dans un tour. Une fois les cartes distribuées, les enchères commencent avec le joueur à droite du donneur. L\'enchère minimale est de 2, ce qui signifie que chaque joueur doit enchérir au moins 2, peu importe sa main. Comme les cartes restantes sont généralement cachées, les enchères impliquent également un mélange de stratégie et de bluff.',
        ),
        
        const SizedBox(height: 20),
        
        // Question 3
        _buildFAQItem(
          3,
          'Quelle est la pondération des cartes dans le Callbreak ?',
          'L\'ordre des cartes du plus fort au plus faible est : As > Roi > Dame > Valet > 10 > 9 > 8 > 7 > 6 > 5 > 4 > 3 > 2. Il est également spécifié que la couleur Pique est toujours l\'atout, ce qui signifie que les Piques peuvent battre les cartes d\'autres couleurs. Pour plus de détails sur les règles d\'atout, il conseille de consulter la section « Gameplay » du guide « Comment jouer ».',
        ),
        
        const SizedBox(height: 20),
        
        // Question 4
        _buildFAQItem(
          4,
          'Comment les scores sont-ils attribués ?',
          'Les scores sont calculés selon les règles spécifiques du Callbreak. Si un joueur obtient exactement le nombre de plis qu\'il a annoncé, il gagne des points positifs. S\'il obtient moins de plis que son annonce, il perd des points. S\'il obtient plus de plis (1 ou 2 de plus), il gagne des points bonus. Mais s\'il obtient 3 plis ou plus que son annonce, il perd des points. Pour plus de détails, consultez la section « Score » dans les règles du jeu.',
        ),
        
        const SizedBox(height: 20),
        
        // Question 5
        _buildFAQItem(
          5,
          'Que se passe-t-il si un joueur n\'a aucun pique ?',
          'Si un joueur n\'a aucun pique (S), la manche est automatiquement redistribuée. Un message affiche le nom du joueur concerné et les cartes sont redistribuées. Cette règle garantit que chaque joueur a une chance équitable de jouer avec une main contenant au moins un atout.',
        ),
        
        const SizedBox(height: 20),
        
        // Question 6
        _buildFAQItem(
          6,
          'Comment fonctionne le système de cauris ?',
          'Le système de cauris est la monnaie virtuelle du jeu. Les joueurs peuvent déposer de l\'argent réel qui est converti en cauris (10 cauris = 1000 FCFA). Les cauris sont utilisés pour les mises dans les parties. Les gains sont répartis entre le vainqueur (90%) et le créateur du salon (10%). Les joueurs peuvent retirer leurs cauris via le système de caisse intégré.',
        ),
        
        const SizedBox(height: 20),
        
        // Question 7
        _buildFAQItem(
          7,
          'Que faire en cas de déconnexion pendant une partie ?',
          'En cas de déconnexion, le système sauvegarde automatiquement votre partie. Vous pouvez vous reconnecter et reprendre là où vous vous êtes arrêté. Si la déconnexion persiste, contactez le support technique via support@caurisdegue.com avec les détails de votre problème.',
        ),
        
        const SizedBox(height: 20),
        
        // Question 8
        _buildFAQItem(
          8,
          'Comment faire pour recharger mon compte ?',
          'Pour recharger votre compte, vous devez vous rendre dans la section \'Caisse\' de l\'application. Là, vous pourrez choisir entre différentes options de dépôt, comme le paiement mobile ou les virements bancaires. Suivez les instructions à l\'écran pour finaliser votre transaction.',
        ),
        
        const SizedBox(height: 20),
        
        // Question 9
        _buildFAQItem(
          9,
          'Que faire si j\'ai un problème technique pendant une partie ?',
          'En cas de problème technique, nous vous recommandons de vérifier votre connexion internet. Si le problème persiste, vous pouvez contacter notre support technique via la section \'Support\' de l\'application ou par email à support@caurisdegue.com. N\'oubliez pas de fournir le maximum de détails sur le problème rencontré.',
        ),
      ],
    );
  }

  Widget _buildJournaux() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Journaux des modifications'),
        const SizedBox(height: 24),
        
        // Card 1: Règles du jeu
        _buildInfoCard(
          icon: Icons.description,
          iconColor: const Color(0xFFFFD700),
          title: 'Règles du jeu',
          content: 'CAURIS DEGUECallbreak se joue à 4 joueurs avec un jeu de 52 cartes. Chaque joueur annonce le nombre de plis qu\'il pense gagner, puis tente de respecter son annonce. Les points sont calculés selon les plis gagnés et annoncés.',
        ),
        
        const SizedBox(height: 16),
        
        // Card 2: Système de caisse
        _buildInfoCard(
          icon: Icons.account_balance_wallet,
          iconColor: const Color(0xFFFFD700),
          title: 'Système de caisse',
          content: 'Gérez votre argent virtuel avec le système de caisse intégré. Déposez et retirez des fonds, convertissez vos gains en Cauris, et suivez votre historique de transactions.',
        ),
        
        const SizedBox(height: 16),
        
        // Card 3: Développement
        _buildInfoCard(
          icon: Icons.people,
          iconColor: Colors.blue,
          title: 'Développement',
          content: 'Développé par CAURIS DEGUE Game Company avec Flutter et Dart. Cette application est le fruit de nombreuses heures de développement et de tests.',
        ),
        
        const SizedBox(height: 16),
        
        // Card 4: Support
        _buildInfoCard(
          icon: Icons.info,
          iconColor: Colors.lightBlue,
          title: 'Support',
          content: 'Pour toute question, suggestion ou signalement de bug, contactez-nous à : support@caurisdegue.com',
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFFFD700), // Jaune doré au lieu de brun foncé
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStepTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFFFD700), // Jaune doré pour les étapes
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF404040), // Gris plus clair pour les cartes
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF555555),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icône
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
          
          // Contenu
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFFFD700), // Jaune doré pour les titres
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(int questionNumber, String question, String answer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF404040), // Gris plus clair pour les cartes
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF555555),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question
          Text(
            'Q$questionNumber. $question',
            style: const TextStyle(
              color: Color(0xFFFFD700), // Jaune doré pour les questions
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Réponse
          Text(
            'A. $answer',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String condition, String calculation) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              condition,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              calculation,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: const Color(0xFF404040),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        border: Border(
          top: BorderSide(
            color: Color(0xFF404040),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildNavButton('Pause d\'appel', 0),
            const SizedBox(width: 8),
            _buildNavButton('Règles', 1),
            const SizedBox(width: 8),
            _buildNavButton('Comment jouer', 2),
            const SizedBox(width: 8),
            _buildNavButton('FAQ', 3),
            const SizedBox(width: 8),
            _buildNavButton('Journaux', 4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(String text, int index) {
    final isActive = _currentSection == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentSection = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFFD700) : const Color(0xFF404040),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
