import 'package:flutter/material.dart';
import '../../services/api/auth_api_service.dart';
import '../../services/user/user_service.dart';
import '../home/user_menu_page.dart';

/// Page de vérification d'email avec code
class VerifyEmailPage extends StatefulWidget {
  final String email;
  
  const VerifyEmailPage({
    super.key,
    required this.email,
  });

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
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
              
              // Logo
              _buildLogo(),
              
              const SizedBox(height: 32),
              
              // Titre
              const Text(
                'Vérification d\'email',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Message
              Text(
                'Un code a été envoyé à\n${widget.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF228B22),
                    width: 1,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF228B22),
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Vérifiez votre boîte mail et entrez le code de 6 chiffres reçu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Formulaire
              _buildFormSection(),
              
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

  Widget _buildFormSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Champ Code
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Code de vérification *',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '123456',
                  hintStyle: const TextStyle(
                    color: Colors.grey,
                    fontSize: 24,
                    letterSpacing: 8,
                  ),
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
                maxLength: 6,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Bouton Vérifier
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF228B22),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Vérifier le code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Bouton Renvoyer le code
          TextButton(
            onPressed: _resendCode,
            child: const Text(
              'Renvoyer le code',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 14,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Vérifier le code
  Future<void> _verifyCode() async {
    if (_codeController.text.length != 6) {
      _showErrorDialog('Le code doit contenir 6 chiffres');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final authService = AuthApiService.instance;
      
      final result = await authService.verifyEmailCode(
        email: widget.email,
        code: _codeController.text,
      );

      if (result['success'] == true && mounted) {
        // Sauvegarder le token et connecter l'utilisateur
        final token = result['token'] as String;
        final user = result['user'] as Map<String, dynamic>;
        
        // Vérifier le rôle de l'utilisateur
        final userRole = user['role'] as String?;
        final restrictedRoles = ['superadmin', 'admin', 'manager'];
        
        if (userRole != null && restrictedRoles.contains(userRole.toLowerCase())) {
          _showErrorDialog(
            'Les administrateurs ne peuvent pas accéder à l\'application mobile. Veuillez utiliser le panel web d\'administration.'
          );
          return;
        }
        
        // Stocker dans UserService
        UserService.instance.setAuthToken(token);
        UserService.instance.login(
          user['pseudo'] ?? 'User',
          widget.email,
        );
        
        // Naviguer vers la page d'accueil
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UserMenuPage(
              pseudo: user['pseudo'] ?? 'User',
              caurisBalance: user['cauris_balance'] ?? 0,
            ),
          ),
        );
      } else if (mounted) {
        _showErrorDialog(result['message'] ?? 'Code invalide ou expiré');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Erreur: $e');
      }
    } finally {
      setState(() => _isLoading = false);
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
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Renvoyer le code
  Future<void> _resendCode() async {
    setState(() => _isLoading = true);
    
    try {
      final authService = AuthApiService.instance;
      
      final result = await authService.resendVerificationCode(
        email: widget.email,
      );
      
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Code renvoyé par email'),
              backgroundColor: const Color(0xFFFFD700),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Erreur lors de l\'envoi'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

