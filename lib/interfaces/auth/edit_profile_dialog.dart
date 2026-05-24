import 'package:flutter/material.dart';

class EditProfileDialog extends StatefulWidget {
  final String pseudo;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String address;

  const EditProfileDialog({
    super.key,
    required this.pseudo,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.address,
  });

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late TextEditingController _pseudoController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _pseudoController = TextEditingController(text: widget.pseudo);
    _firstNameController = TextEditingController(text: widget.firstName);
    _lastNameController = TextEditingController(text: widget.lastName);
    _emailController = TextEditingController(text: widget.email);
    _phoneController = TextEditingController(text: widget.phone);
    _addressController = TextEditingController(text: widget.address);
  }

  @override
  void dispose() {
    _pseudoController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.7), // Fond noir semi-transparent
      body: GestureDetector(
        onTap: () {
          Navigator.of(context).pop(); // Fermer en cliquant sur le fond
        },
        child: GestureDetector(
          onTap: () {}, // Empêcher la fermeture en cliquant sur la carte
          child: Container(
            width: double.infinity,
            height: double.infinity,
            margin: const EdgeInsets.all(20), // Marges pour l'effet de carte
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A), // Fond de la carte plus foncé
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.05), // Espace en haut réduit
                    
                    // En-tête avec bouton fermer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 24), // Espace pour centrer le titre
                        const Text(
                          'Modifier le profil',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Icône de profil
                    _buildProfileIcon(),
                    
                    const SizedBox(height: 30),
                    
                    // Champs de saisie
                    _buildProfileFields(),
                    
                    const SizedBox(height: 30),
                    
                    // Boutons d'action
                    _buildActionButtons(),
                    
                    SizedBox(height: MediaQuery.of(context).size.height * 0.05), // Espace en bas réduit
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(60),
        border: Border.all(
          color: const Color(0xFFFFD700), // Bordure jaune
          width: 3,
        ),
      ),
      child: const Icon(
        Icons.person,
        color: Color(0xFFFFD700), // Jaune
        size: 60,
      ),
    );
  }

  Widget _buildProfileFields() {
    return Column(
      children: [
        // Pseudo
        _buildTextField(
          label: 'Pseudo',
          controller: _pseudoController,
          icon: Icons.person,
        ),
        
        const SizedBox(height: 20),
        
        // Prénom
        _buildTextField(
          label: 'Prénom',
          controller: _firstNameController,
          icon: Icons.badge,
        ),
        
        const SizedBox(height: 20),
        
        // Nom
        _buildTextField(
          label: 'Nom',
          controller: _lastNameController,
          icon: Icons.badge_outlined,
        ),
        
        const SizedBox(height: 20),
        
        // Email
        _buildTextField(
          label: 'Email',
          controller: _emailController,
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        
        const SizedBox(height: 20),
        
        // Téléphone
        _buildTextField(
          label: 'Téléphone',
          controller: _phoneController,
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
        ),
        
        const SizedBox(height: 20),
        
        // Adresse
        _buildTextField(
          label: 'Adresse',
          controller: _addressController,
          icon: Icons.location_on,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFFFFD700),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFFFD700)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Bouton Sauvegarder
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              _handleSaveProfile();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF228B22), // Vert foncé
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Sauvegarder les modifications',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Bouton Annuler
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A2A2A), // Gris foncé
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Annuler',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleSaveProfile() {
    final pseudo = _pseudoController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();

    // Validation
    if (pseudo.isEmpty || firstName.isEmpty || lastName.isEmpty || email.isEmpty) {
      _showErrorDialog('Veuillez remplir tous les champs obligatoires');
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showErrorDialog('Veuillez entrer une adresse email valide');
      return;
    }

    // TODO: Appel API pour sauvegarder le profil
    print('Sauvegarde du profil...');
    print('Pseudo: $pseudo');
    print('Prénom: $firstName');
    print('Nom: $lastName');
    print('Email: $email');
    print('Téléphone: $phone');
    print('Adresse: $address');
    
    _showSuccessDialog();
  }

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
            'Erreur',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
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
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
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
            'Succès',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Votre profil a été modifié avec succès',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fermer le message de succès
                Navigator.of(context).pop(); // Fermer la boîte de dialogue
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
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
