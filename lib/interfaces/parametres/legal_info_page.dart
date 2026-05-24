import 'package:flutter/material.dart';

class LegalInfoPage extends StatelessWidget {
  const LegalInfoPage({super.key});

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
          'Info légales',
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
            // Grille des options légales
            _buildLegalOptionsGrid(context),
            
            const SizedBox(height: 32),
            
            // Section contact
            _buildContactSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalOptionsGrid(BuildContext context) {
    return Column(
      children: [
        // Première ligne
        Row(
          children: [
            Expanded(
              child: _buildLegalOptionCard(
                title: 'Licences Open Source',
                onTap: () => _showOpenSourceLicenses(context),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildLegalOptionCard(
                title: 'Contrat de licence utilisateur final',
                onTap: () => _showEULA(context),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Deuxième ligne
        Row(
          children: [
            Expanded(
              child: _buildLegalOptionCard(
                title: 'Ressources du jeu',
                onTap: () => _showGameResources(context),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildLegalOptionCard(
                title: 'Politique de confidentialité',
                onTap: () => _showPrivacyPolicy(context),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Troisième ligne
        Row(
          children: [
            Expanded(
              child: _buildLegalOptionCard(
                title: 'À propos de CAURIS DEGUE',
                onTap: () => _showAboutCaurisDegue(context),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildLegalOptionCard(
                title: 'Conditions d\'utilisation',
                onTap: () => _showTermsOfUse(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegalOptionCard({
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
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info,
                color: Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Pour toute question concernant les',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'informations légales, contactez-nous à :',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'info@caurisdegue.com',
            style: TextStyle(
              color: Color(0xFFFFD700), // Jaune doré
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Dialogues pour chaque section légale
  void _showOpenSourceLicenses(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Licences Open Source',
            style: TextStyle(color: Colors.white),
          ),
          content: const SingleChildScrollView(
            child: Text(
              'CAURIS DEGUE Callbreak utilise les technologies open source suivantes :\n\n'
              '• Flutter Framework (Apache License 2.0)\n'
              '• Dart Language (BSD License)\n'
              '• Material Design Icons (Apache License 2.0)\n'
              '• Cupertino Icons (MIT License)\n\n'
              'Toutes les licences open source sont respectées et les crédits appropriés sont attribués aux développeurs originaux.',
              style: TextStyle(color: Colors.white),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Fermer',
                style: TextStyle(color: Color(0xFFFFD700)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEULA(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Contrat de licence utilisateur final',
            style: TextStyle(color: Colors.white),
          ),
          content: const SingleChildScrollView(
            child: Text(
              'CONTRAT DE LICENCE UTILISATEUR FINAL\n\n'
              'CAURIS DEGUE Callbreak\n\n'
              '1. ACCEPTATION DU CONTRAT\n'
              'En utilisant cette application, vous acceptez les termes de ce contrat.\n\n'
              '2. LICENCE D\'UTILISATION\n'
              'CAURIS DEGUE vous accorde une licence limitée, non exclusive et non transférable pour utiliser l\'application.\n\n'
              '3. RESTRICTIONS\n'
              'Vous ne pouvez pas :\n'
              '• Copier, modifier ou distribuer l\'application\n'
              '• Utiliser l\'application à des fins commerciales\n'
              '• Reverse engineer l\'application\n\n'
              '4. PROPRIÉTÉ INTELLECTUELLE\n'
              'Tous les droits de propriété intellectuelle appartiennent à CAURIS DEGUE.',
              style: TextStyle(color: Colors.white),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Fermer',
                style: TextStyle(color: Color(0xFFFFD700)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showGameResources(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Ressources du jeu',
            style: TextStyle(color: Colors.white),
          ),
          content: const SingleChildScrollView(
            child: Text(
              'RESSOURCES DU JEU CAURIS DEGUE CALLBREAK\n\n'
              '1. IMAGES ET ASSETS\n'
              '• Logo CAURIS DEGUE : Propriété exclusive\n'
              '• Icônes de jeu : Conçues par notre équipe\n'
              '• Images de fond : Créations originales\n\n'
              '2. SONS ET MUSIQUE\n'
              '• Effets sonores : Bibliothèque personnalisée\n'
              '• Musique de fond : Compositions originales\n'
              '• Sons d\'interface : Créés spécifiquement pour l\'app\n\n'
              '3. CONTENU TEXTUEL\n'
              '• Règles du jeu : Adaptation du Callbreak classique\n'
              '• Interface utilisateur : Traductions françaises\n'
              '• Textes d\'aide : Rédaction interne\n\n'
              'Toutes les ressources sont protégées par le droit d\'auteur.',
              style: TextStyle(color: Colors.white),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Fermer',
                style: TextStyle(color: Color(0xFFFFD700)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Politique de confidentialité',
            style: TextStyle(color: Colors.white),
          ),
          content: const SingleChildScrollView(
            child: Text(
              'POLITIQUE DE CONFIDENTIALITÉ\n\n'
              'CAURIS DEGUE Callbreak\n\n'
              '1. COLLECTE DE DONNÉES\n'
              'Nous collectons uniquement :\n'
              '• Pseudonyme choisi par l\'utilisateur\n'
              '• Données de jeu (scores, parties)\n'
              '• Informations de compte (email, téléphone)\n\n'
              '2. UTILISATION DES DONNÉES\n'
              'Vos données sont utilisées pour :\n'
              '• Fournir le service de jeu\n'
              '• Gérer votre compte\n'
              '• Améliorer l\'application\n\n'
              '3. PARTAGE DE DONNÉES\n'
              'Nous ne vendons jamais vos données personnelles à des tiers.\n\n'
              '4. SÉCURITÉ\n'
              'Toutes les données sont chiffrées et stockées de manière sécurisée.\n\n'
              '5. VOS DROITS\n'
              'Vous pouvez demander la suppression de vos données à tout moment.',
              style: TextStyle(color: Colors.white),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Fermer',
                style: TextStyle(color: Color(0xFFFFD700)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAboutCaurisDegue(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'À propos de CAURIS DEGUE',
            style: TextStyle(color: Colors.white),
          ),
          content: const SingleChildScrollView(
            child: Text(
              'À PROPOS DE CAURIS DEGUE\n\n'
              'CAURIS DEGUE est une entreprise de développement de jeux basée en Afrique de l\'Ouest, spécialisée dans la création d\'expériences de jeu innovantes et culturellement pertinentes.\n\n'
              'NOTRE MISSION\n'
              'Démocratiser l\'accès aux jeux de cartes traditionnels en les adaptant aux technologies modernes, tout en préservant leur essence culturelle.\n\n'
              'CAURIS DEGUE CALLBREAK\n'
              'Notre premier jeu mobile est une adaptation moderne du Callbreak, un jeu de cartes populaire en Afrique de l\'Ouest. Nous avons ajouté un système de monnaie virtuelle (Cauris) pour rendre le jeu plus engageant.\n\n'
              'NOTRE ÉQUIPE\n'
              '• Développeurs Flutter/Dart expérimentés\n'
              '• Designers UI/UX spécialisés\n'
              '• Experts en jeux de cartes traditionnels\n\n'
              'CONTACT\n'
              'Email : contact@caurisdegue.com\n'
              'Site web : www.caurisdegue.com',
              style: TextStyle(color: Colors.white),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Fermer',
                style: TextStyle(color: Color(0xFFFFD700)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showTermsOfUse(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Conditions d\'utilisation',
            style: TextStyle(color: Colors.white),
          ),
          content: const SingleChildScrollView(
            child: Text(
              'CONDITIONS D\'UTILISATION\n\n'
              'CAURIS DEGUE Callbreak\n\n'
              '1. ACCEPTATION DES CONDITIONS\n'
              'En utilisant cette application, vous acceptez ces conditions d\'utilisation.\n\n'
              '2. UTILISATION DE L\'APPLICATION\n'
              '• Vous devez avoir au moins 18 ans pour utiliser l\'application\n'
              '• Vous êtes responsable de votre compte et de vos actions\n'
              '• Vous ne devez pas utiliser l\'application à des fins illégales\n\n'
              '3. SYSTÈME DE CAURIS\n'
              '• Les Cauris sont une monnaie virtuelle\n'
              '• Les dépôts et retraits sont soumis à validation\n'
              '• Les gains sont répartis selon les règles du jeu\n\n'
              '4. COMPORTEMENT\n'
              '• Respectez les autres joueurs\n'
              '• Pas de triche ou d\'exploitation de bugs\n'
              '• Pas de langage offensant\n\n'
              '5. SUSPENSION DE COMPTE\n'
              'Nous nous réservons le droit de suspendre les comptes qui violent ces conditions.',
              style: TextStyle(color: Colors.white),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Fermer',
                style: TextStyle(color: Color(0xFFFFD700)),
              ),
            ),
          ],
        );
      },
    );
  }
}


