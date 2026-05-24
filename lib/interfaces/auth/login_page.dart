import 'package:flutter/material.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import '../home/user_menu_page.dart';
import 'package:flutter/services.dart';
import 'dart:io' show exit;
import '../../services/api/auth_api_service.dart';
import '../../services/user/user_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                         MediaQuery.of(context).padding.top - 
                         MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // Logo circulaire
                  _buildLogo(),
                  
                  const SizedBox(height: 24),
                  
                  // Titre principal en vert
                  const Text(
                    'CAURIS DEGUE',
                    style: TextStyle(
                      color: Color(0xFF228B22), // Vert plus foncé
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Sous-titre en vert
                  const Text(
                    'Callbreak',
                    style: TextStyle(
                      color: Color(0xFF228B22), // Vert plus foncé
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Titre de la page
                  const Text(
                    'Connexion',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Champs de saisie
                  _buildInputFields(),
                  
                  const SizedBox(height: 40),
                  
                  // Boutons et liens
                  _buildActionButtons(),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
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

  Widget _buildInputFields() {
    return Column(
      children: [
        // Champ Pseudo ou Email
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pseudo ou Email',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Entrez votre pseudo ou email',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
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
        
        const SizedBox(height: 20),
        
        // Champ Mot de passe
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mot de passe',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Entrez votre mot de passe',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Bouton Se connecter vert
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
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
                    'Se connecter',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Lien Mot de passe oublié
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
            );
          },
          child: const Text(
            'Mot de passe oublié ?',
            style: TextStyle(
              color: Color(0xFFFFD700), // Jaune
              fontSize: 14,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Lien Créer un profil
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Pas encore de compte ? ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignupPage()),
                );
              },
              child: const Text(
                'Créer un profil',
                style: TextStyle(
                  color: Color(0xFF228B22), // Vert plus foncé
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 32),
        
        // Bouton Quitter l'application rouge
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _quitApp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Quitter l\'application',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Informations légales
        _buildLegalInfo(),
      ],
    );
  }

  void _quitApp() {
    try {
      SystemNavigator.pop();
    } catch (_) {
      exit(0);
    }
  }

  Widget _buildLegalInfo() {
    return Column(
      children: [
        const Text(
          'En étant utilisateur, vous acceptez nos conditions d\'utilisation et notre politique de confidentialité.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 12),
        
        const Text(
          'Vous devez avoir 18 ans pour utiliser cette application.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Méthode pour gérer la connexion
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Validation simple
    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog('Veuillez remplir tous les champs');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = AuthApiService.instance;
      
      // Appel API de login
      final result = await authService.login(
        email: email,
        password: password,
      );

      if (result['success'] == true && mounted) {
        // Vérifier le rôle de l'utilisateur
        final userRole = result['user']['role'] as String?;
        final restrictedRoles = ['superadmin', 'admin', 'manager'];
        
        if (userRole != null && restrictedRoles.contains(userRole.toLowerCase())) {
          _showErrorDialog(
            'Les administrateurs ne peuvent pas accéder à l\'application mobile. Veuillez utiliser le panel web d\'administration.'
          );
          return;
        }
        
        // Sauvegarder le token
        UserService.instance.setAuthToken(result['token']);
        
        // Connecter l'utilisateur
        UserService.instance.login(
          result['user']['pseudo'],
          result['user']['email'],
        );

        // Afficher succès et naviguer
        _showSuccessDialog(
          result['user']['pseudo'],
          result['user']['cauris_balance'] ?? 0,
        );
      } else if (mounted) {
        // Vérifier si c'est une erreur de redirection admin
        if (result['redirect'] == true) {
          _showErrorDialog(result['message'] ?? 'Accès refusé');
        } else {
          _showErrorDialog(result['message'] ?? 'Erreur de connexion');
        }
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

  // Boîte de dialogue de succès
  void _showSuccessDialog(String pseudo, int caurisBalance) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Connexion réussie',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Bienvenue $pseudo !',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => UserMenuPage(pseudo: pseudo, caurisBalance: caurisBalance)),
                );
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
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

  // Boîte de dialogue d'erreur
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Erreur de connexion',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
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
}
