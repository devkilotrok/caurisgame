import 'package:flutter/material.dart';
import '../../services/api/auth_api_service.dart';
import 'verify_email_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _pseudoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _pseudoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
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
                    'Créer votre profil',
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
        // Champ Prénom
        _buildTextField(
          label: 'Prénom *',
          controller: _firstNameController,
          placeholder: 'Entrez votre prénom',
        ),
        
        const SizedBox(height: 20),
        
        // Champ Nom
        _buildTextField(
          label: 'Nom *',
          controller: _lastNameController,
          placeholder: 'Entrez votre nom',
        ),
        
        const SizedBox(height: 20),
        
        // Champ Pseudo
        _buildTextField(
          label: 'Pseudo *',
          controller: _pseudoController,
          placeholder: 'Choisissez un pseudo',
        ),
        
        const SizedBox(height: 20),
        
        // Champ Email
        _buildTextField(
          label: 'Email *',
          controller: _emailController,
          placeholder: 'Entrez votre email',
          keyboardType: TextInputType.emailAddress,
        ),
        
        const SizedBox(height: 20),
        
        // Champ Téléphone
        _buildTextField(
          label: 'Téléphone (optionnel)',
          controller: _phoneController,
          placeholder: 'Entrez votre numéro de téléphone',
          keyboardType: TextInputType.phone,
        ),
        
        const SizedBox(height: 20),
        
        // Champ Adresse
        _buildTextField(
          label: 'Adresse (optionnel)',
          controller: _addressController,
          placeholder: 'Entrez votre adresse',
          keyboardType: TextInputType.multiline,
          maxLines: 3,
        ),
        
        const SizedBox(height: 20),
        
        // Champ Mot de passe
        _buildPasswordField(
          label: 'Mot de passe *',
          controller: _passwordController,
          placeholder: 'Au moins 6 caractères',
          isVisible: _isPasswordVisible,
          onToggleVisibility: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
        
        const SizedBox(height: 20),
        
        // Champ Confirmer mot de passe
        _buildPasswordField(
          label: 'Confirmer le mot de passe *',
          controller: _confirmPasswordController,
          placeholder: 'Répétez votre mot de passe',
          isVisible: _isConfirmPasswordVisible,
          onToggleVisibility: () {
            setState(() {
              _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: placeholder,
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
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: !isVisible,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: placeholder,
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
                isVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey,
              ),
              onPressed: onToggleVisibility,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Bouton Créer le profil vert
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () {
              _handleSignup();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF228B22), // Vert plus foncé
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Créer le profil',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Lien Déjà un compte
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Déjà un compte ? ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Retour à la page de connexion
              },
              child: const Text(
                'Se connecter',
                style: TextStyle(
                  color: Color(0xFF228B22), // Vert plus foncé
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Vérification email
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_box,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Vérification email requise',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Informations légales
        _buildLegalInfo(),
      ],
    );
  }

  Widget _buildLegalInfo() {
    return Column(
      children: [
        const Text(
          'En vous inscrivant, vous acceptez nos conditions d\'utilisation et notre politique de confidentialité.',
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

  /// Gérer la création de profil avec envoi d'email
  Future<void> _handleSignup() async {
    // Validation
    if (_emailController.text.isEmpty || 
        _passwordController.text.isEmpty ||
        _pseudoController.text.isEmpty ||
        _firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty) {
      _showErrorDialog('Veuillez remplir tous les champs obligatoires');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorDialog('Les mots de passe ne correspondent pas');
      return;
    }

    if (_passwordController.text.length < 8) {
      _showErrorDialog('Le mot de passe doit contenir au moins 8 caractères');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = AuthApiService.instance;
      
      final result = await authService.registerWithEmail(
        pseudo: _pseudoController.text,
        email: _emailController.text,
        password: _passwordController.text,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phone: _phoneController.text.isEmpty ? null : _phoneController.text,
      );

      if (result['success'] == true) {
        if (mounted) {
          // Rediriger vers la page de vérification
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VerifyEmailPage(
                email: _emailController.text,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          // Afficher un message d'erreur personnalisé
          String errorMessage = result['message'] ?? 'Erreur lors de l\'inscription';
          
          // Si des erreurs de validation détaillées existent
          if (result['errors'] != null) {
            final errors = result['errors'] as Map<String, dynamic>;
            final errorList = errors.values.expand((e) => e as List).toList();
            if (errorList.isNotEmpty) {
              errorMessage = errorList.join('\n');
            }
          }
          
          _showErrorDialog(errorMessage);
        }
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
}
