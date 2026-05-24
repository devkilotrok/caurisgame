import 'package:flutter/material.dart';
import '../../services/api/auth_api_service.dart';
import 'verify_email_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

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
                'Mot de passe oublié',
                style: TextStyle(
                  color: Color(0xFF228B22), // Vert plus foncé
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Sous-titre
              const Text(
                'Réinitialisez votre mot de passe',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Section formulaire
              _buildFormSection(),
              
              const SizedBox(height: 24),
              
              // Section informations
              _buildInfoSection(),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
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
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Champ Email
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Adresse email *',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Entrez votre adresse email',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF3A3A3A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Bouton Envoyer
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleForgotPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF228B22), // Vert plus foncé
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Envoyer l\'email de réinitialisation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Lien Retour à la connexion
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Retour à la page de connexion
            },
            child: const Text(
              'Retour à la connexion',
              style: TextStyle(
                color: Color(0xFFFFD700), // Jaune
                fontSize: 14,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Information email
          Row(
            children: [
              const Icon(
                Icons.email_outlined,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Un email sera envoyé à votre adresse avec les instructions de réinitialisation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Information expiration
          Row(
            children: [
              const Icon(
                Icons.access_time,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Le lien de réinitialisation expire dans 24 heures',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showErrorDialog('Veuillez entrer votre adresse email');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = AuthApiService.instance;
      
      // Demander un code de réinitialisation
      final result = await authService.requestPasswordReset(
        email: email,
      );

      if (result['success'] == true && mounted) {
        // Afficher message de succès
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Email envoyé'),
            content: const Text(
              'Un code de réinitialisation a été envoyé à votre adresse email.\n\nVeuillez vérifier votre boîte de réception.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Rediriger vers la page de vérification de code
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VerifyEmailPage(email: email),
                    ),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else if (mounted) {
        _showErrorDialog(result['message'] ?? 'Erreur lors de l\'envoi de l\'email');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Erreur: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erreur'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
