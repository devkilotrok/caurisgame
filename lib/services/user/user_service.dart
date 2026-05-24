import 'package:flutter/material.dart';

/// Service pour la gestion de l'utilisateur connecté
/// 
/// 🔄 INTÉGRATION BACKEND :
/// 1. Ajouter un appel API pour login/logout
/// 2. Stocker le token d'authentification JWT
/// 3. Remplacer simulateLogin() par un vrai login via API
/// 4. Voir INTEGRATION_API.md pour les détails
class UserService {
  static UserService? _instance;
  static UserService get instance => _instance ??= UserService._internal();
  
  UserService._internal();

  String? _currentUserPseudo;
  String? _currentUserEmail;
  bool _isLoggedIn = false;
  String? _authToken; // ✅ À AJOUTER pour l'authentification

  String? get currentUserPseudo => _currentUserPseudo;
  String? get currentUserEmail => _currentUserEmail;
  bool get isLoggedIn => _isLoggedIn;
  String? get authToken => _authToken; // ✅ Getter pour le token

  /// Se connecter
  /// 
  /// TODO: INTÉGRER L'API BACKEND
  /// Actuellement: Stockage local uniquement
  /// À changer par: Appel API POST /api/auth/login
  /// 
  /// Exemple d'intégration :
  /// ```dart
  /// final response = await http.post(
  ///   Uri.parse('$apiUrl/auth/login'),
  ///   body: jsonEncode({'email': email, 'password': password}),
  /// );
  /// if (response.statusCode == 200) {
  ///   final data = jsonDecode(response.body);
  ///   _authToken = data['token'];
  ///   _currentUserPseudo = data['user']['pseudo'];
  /// }
  /// ```
  void login(String pseudo, String email) {
    _currentUserPseudo = pseudo;
    _currentUserEmail = email;
    _isLoggedIn = true;
  }

  /// Se déconnecter
  /// 
  /// TODO: INTÉGRER L'API BACKEND
  /// À ajouter: Appel API POST /api/auth/logout
  void logout() {
    _currentUserPseudo = null;
    _currentUserEmail = null;
    _authToken = null; // ✅ Supprimer le token
    _isLoggedIn = false;
  }

  /// Définir le token d'authentification
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// ❌ SIMULATION DE TEST - À SUPPRIMER
  /// Cette méthode ne devrait être utilisée que pour les tests
  void simulateLogin() {
    login('TestUser', 'test@example.com');
  }
}

